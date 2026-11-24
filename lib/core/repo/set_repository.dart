import 'package:drift/drift.dart';

import '../../l10n/strings.dart';
import '../clock.dart';
import '../db/app_database.dart';
import '../domain/domain.dart';
import 'mappers.dart';
import 'models.dart';
import 'session_store.dart';
import 'settings_store.dart';
import 'watch.dart';

/// CRUD for track sets, plus the first-launch seed data.
class SetRepository {
  SetRepository(this._db, this._clock, this._newId, this._alarmSync);

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _newId;
  final AlarmSync _alarmSync;

  Future<List<TrackSet>> getSets({bool includeArchived = false}) async {
    final query = _db.select(_db.trackSets)
      ..orderBy([
        (s) => OrderingTerm.asc(s.sortIndex),
        (s) => OrderingTerm.asc(s.createdAt),
      ]);
    if (!includeArchived) query.where((s) => s.archived.equals(false));
    return [for (final r in await query.get()) r.toDomain()];
  }

  /// Sets ordered by `sortIndex`.
  Stream<List<TrackSet>> watchSets({bool includeArchived = false}) =>
      watchTables(_db, [
        _db.trackSets,
      ], () => getSets(includeArchived: includeArchived));

  Future<TrackSet?> getSet(String id) async {
    final row = await (_db.select(
      _db.trackSets,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    return row?.toDomain();
  }

  /// Creates a set at the end of the list.
  Future<TrackSet> createSet({
    required String name,
    String? themeId,
    JsonMap? uiPrefsOverride,
  }) async {
    final now = _clock.nowMs();
    final maxSort = _db.trackSets.sortIndex.max();
    final currentMax = await (_db.selectOnly(
      _db.trackSets,
    )..addColumns([maxSort])).map((r) => r.read(maxSort)).getSingle();
    final set = TrackSet(
      id: _newId(),
      name: name,
      sortIndex: (currentMax ?? -1) + 1,
      themeId: themeId,
      uiPrefsOverride: uiPrefsOverride,
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.trackSets).insert(set.toRow());
    return set;
  }

  /// Saves all fields of [set] (matched by id) and bumps `updatedAt`.
  Future<void> updateSet(TrackSet set) async {
    await _db
        .update(_db.trackSets)
        .replace(set.copyWith(updatedAt: _clock.nowMs()).toRow());
  }

  /// Stores the scene of a set: who is here ([personIds]) and today's main
  /// substances ([substanceIds], in the user's order). Two empty lists clear
  /// the scene. Everything else of the set is left as stored.
  Future<void> updateScene(
    String id, {
    required List<String> personIds,
    required List<String> substanceIds,
  }) async {
    await _db.transaction(() async {
      final current = await getSet(id);
      if (current == null) return;
      final next = current.copyWith(
        scenePersonIds: personIds,
        sceneSubstanceIds: substanceIds,
      );
      await (_db.update(_db.trackSets)..where((s) => s.id.equals(id))).write(
        TrackSetsCompanion(
          extraJson: Value(encodeSetExtra(next)),
          updatedAt: Value(_clock.nowMs()),
        ),
      );
    });
  }

  Future<void> renameSet(String id, String name) async {
    await (_db.update(_db.trackSets)..where((s) => s.id.equals(id))).write(
      TrackSetsCompanion(name: Value(name), updatedAt: Value(_clock.nowMs())),
    );
  }

  Future<void> setArchived(String id, {required bool archived}) async {
    await (_db.update(_db.trackSets)..where((s) => s.id.equals(id))).write(
      TrackSetsCompanion(
        archived: Value(archived),
        updatedAt: Value(_clock.nowMs()),
      ),
    );
  }

  /// Rewrites `sortIndex` so the sets appear in the order of [orderedIds].
  /// Ids that are missing from the list keep their relative order after it.
  Future<void> reorderSets(List<String> orderedIds) async {
    await _db.transaction(() async {
      final existing = await getSets(includeArchived: true);
      final rest = [
        for (final s in existing)
          if (!orderedIds.contains(s.id)) s.id,
      ];
      final now = _clock.nowMs();
      var index = 0;
      for (final id in [...orderedIds, ...rest]) {
        await (_db.update(_db.trackSets)..where((s) => s.id.equals(id))).write(
          TrackSetsCompanion(sortIndex: Value(index++), updatedAt: Value(now)),
        );
      }
    });
  }

  /// Permanently deletes a set with all its tracks, sessions and events.
  /// There is no undo: prefer [setArchived] where the history should stay.
  Future<void> deleteSet(String id) async {
    final trackIds = <String>[];
    await _db.transaction(() async {
      final tracks = await (_db.select(
        _db.tracks,
      )..where((t) => t.setId.equals(id))).get();
      trackIds.addAll(tracks.map((t) => t.id));
      if (trackIds.isNotEmpty) {
        await (_db.delete(
          _db.events,
        )..where((e) => e.trackId.isIn(trackIds))).go();
        await (_db.delete(
          _db.sessions,
        )..where((s) => s.trackId.isIn(trackIds))).go();
        await (_db.delete(_db.tracks)..where((t) => t.setId.equals(id))).go();
      }
      await (_db.delete(_db.trackSets)..where((s) => s.id.equals(id))).go();
    });
    for (final trackId in trackIds) {
      await _alarmSync.cancelTrack(trackId);
    }
  }

  /// Writes the first-launch content (set "Allgemein" with a stopwatch, a
  /// 10 minute timer and a counter) exactly once. Returns `true` when data
  /// was written.
  Future<bool> ensureSeedData() async {
    return _db.transaction(() async {
      final flag = await (_db.select(
        _db.settings,
      )..where((s) => s.key.equals(SettingsKeys.seedDone))).getSingleOrNull();
      if (flag != null) return false;
      final now = _clock.nowMs();
      await _db
          .into(_db.settings)
          .insert(
            SettingRow(
              key: SettingsKeys.seedDone,
              value: 'true',
              updatedAt: now,
            ),
          );
      final anySet = await (_db.select(_db.trackSets)..limit(1)).get();
      if (anySet.isNotEmpty) return false;

      final set = TrackSet(
        id: _newId(),
        name: Strings.seedSetName,
        createdAt: now,
        updatedAt: now,
      );
      await _db.into(_db.trackSets).insert(set.toRow());
      const configs = <(String, TrackConfig)>[
        (Strings.seedStopwatchName, StopwatchConfig()),
        (Strings.seedTimerName, CountdownConfig(durationMs: 10 * 60 * 1000)),
        (Strings.seedCounterName, CounterConfig()),
      ];
      for (var i = 0; i < configs.length; i++) {
        final track = Track(
          id: _newId(),
          setId: set.id,
          name: configs[i].$1,
          config: configs[i].$2,
          colorIndex: i,
          sortIndex: i,
          createdAt: now,
          updatedAt: now,
        );
        await _db.into(_db.tracks).insert(track.toRow());
      }
      return true;
    });
  }
}
