import 'package:drift/drift.dart';

import '../clock.dart';
import '../db/app_database.dart';
import '../domain/domain.dart';
import 'history_repository.dart';
import 'mappers.dart';
import 'models.dart';
import 'session_store.dart';
import 'settings_store.dart';

/// Reads and merges whole-database snapshots for the JSON backup.
///
/// The export feature turns [BackupData] into a file (and back); this class
/// only talks to the database.
class BackupRepository {
  BackupRepository(this._db, this._clock, this._history, this._alarmSync);

  final AppDatabase _db;
  final Clock _clock;
  final HistoryRepository _history;
  final AlarmSync _alarmSync;

  /// Collects the data for a backup.
  ///
  /// * Sets, tracks and settings are always complete (they are
  ///   configuration), except that protocol tracks are left out unless
  ///   [includeProtocol] is set.
  /// * Sessions and their events honour [filter]; open sessions are
  ///   included so a backup captures running timers.
  /// * Sessions and events of protocol tracks, persons and substances are
  ///   ONLY included with [includeProtocol] (explicit opt-in). Without it
  ///   the sets are written without their scene (the ids of who is here
  ///   and what is on today), so nothing of the protocol data leaks.
  Future<BackupData> readAll({
    HistoryFilter filter = HistoryFilter.all,
    bool includeProtocol = false,
  }) async {
    final sets = [
      for (final r in await _db.select(_db.trackSets).get())
        if (includeProtocol)
          r.toDomain()
        else
          r.toDomain().copyWith(
            scenePersonIds: const [],
            sceneSubstanceIds: const [],
          ),
    ];
    final tracks = [
      for (final r in await _db.select(_db.tracks).get())
        if (includeProtocol || r.mode != TrackMode.protocol.name) r.toDomain(),
    ];
    final history = await _history.getSessions(
      filter.copyWith(includeProtocol: includeProtocol, includeOpen: true),
    );
    final persons = includeProtocol
        ? [for (final r in await _db.select(_db.persons).get()) r.toDomain()]
        : const <Person>[];
    final substances = includeProtocol
        ? [for (final r in await _db.select(_db.substances).get()) r.toDomain()]
        : const <Substance>[];
    final settings = {
      for (final r in await _db.select(_db.settings).get())
        if (!SettingsKeys.isInternal(r.key)) r.key: r.value,
    };
    return BackupData(
      exportedAt: _clock.nowMs(),
      sets: sets,
      tracks: tracks,
      sessions: [for (final h in history) h.session],
      events: [for (final h in history) ...h.events],
      persons: persons,
      substances: substances,
      settings: settings,
    );
  }

  /// Merges a backup into the database by id. Nothing is ever deleted:
  ///
  /// * rows with unknown ids are inserted;
  /// * rows with known ids are replaced only when the backup's `updatedAt`
  ///   is strictly newer, otherwise kept;
  /// * a backup without any person and substance (written without protocol
  ///   data, so its sets carry no scene) never changes the scene of a set
  ///   that already exists here;
  /// * settings are only imported with [importSettings]; existing keys are
  ///   kept unless [overwriteSettings] is set. Device-local settings (the
  ///   "seed done" flag and the APP LOCK, see `SettingsKeys.isDeviceLocal`)
  ///   are never imported;
  /// * events the user deleted one by one on this device stay deleted
  ///   (`EventTombstones`);
  /// * afterwards every touched session is reconciled with its events:
  ///   `endedAt` is set exactly when the log holds a `stop`, so sessions
  ///   and events that were merged independently cannot contradict each
  ///   other (a track that can neither start nor reset).
  ///
  /// Afterwards the caller must refresh the in-memory settings with
  /// `SettingsStore.reload()`. Alarms are rescheduled here.
  Future<ImportReport> merge(
    BackupData data, {
    bool importSettings = true,
    bool overwriteSettings = false,
  }) async {
    final inserted = <String, int>{};
    final updated = <String, int>{};
    final skipped = <String, int>{};

    Future<void> mergeRows<Tbl extends Table, Row extends Insertable<Row>>({
      required String key,
      required TableInfo<Tbl, Row> table,
      required Iterable<Row> rows,
      required String Function(Row row) idOf,
      required int Function(Row row) updatedAtOf,
      required Future<Row?> Function(String id) find,
    }) async {
      var ins = 0;
      var upd = 0;
      var skip = 0;
      for (final row in rows) {
        final id = idOf(row);
        if (id.isEmpty) {
          skip++;
          continue;
        }
        final existing = await find(id);
        if (existing == null) {
          await _db.into(table).insert(row);
          ins++;
        } else if (updatedAtOf(row) > updatedAtOf(existing)) {
          await _db.update(table).replace(row);
          upd++;
        } else {
          skip++;
        }
      }
      inserted[key] = ins;
      updated[key] = upd;
      skipped[key] = skip;
    }

    await _db.transaction(() async {
      final tombstones = await EventTombstones.load(_db);
      final deletedLocally = tombstones.isEmpty
          ? 0
          : data.events.where((e) => tombstones.contains(e.id)).length;
      final withoutProtocol = data.persons.isEmpty && data.substances.isEmpty;
      final setRows = <SetRow>[];
      for (final set in data.sets) {
        var incoming = set;
        if (withoutProtocol && !set.hasScene) {
          final local = await (_db.select(
            _db.trackSets,
          )..where((t) => t.id.equals(set.id))).getSingleOrNull();
          final scene = local?.toDomain();
          if (scene != null && scene.hasScene) {
            incoming = set.copyWith(
              scenePersonIds: scene.scenePersonIds,
              sceneSubstanceIds: scene.sceneSubstanceIds,
            );
          }
        }
        setRows.add(incoming.toRow());
      }
      await mergeRows<$TrackSetsTable, SetRow>(
        key: 'sets',
        table: _db.trackSets,
        rows: setRows,
        idOf: (r) => r.id,
        updatedAtOf: (r) => r.updatedAt,
        find: (id) => (_db.select(
          _db.trackSets,
        )..where((t) => t.id.equals(id))).getSingleOrNull(),
      );
      await mergeRows<$TracksTable, TrackRow>(
        key: 'tracks',
        table: _db.tracks,
        rows: data.tracks.map((t) => t.toRow()),
        idOf: (r) => r.id,
        updatedAtOf: (r) => r.updatedAt,
        find: (id) => (_db.select(
          _db.tracks,
        )..where((t) => t.id.equals(id))).getSingleOrNull(),
      );
      await mergeRows<$SessionsTable, SessionRow>(
        key: 'sessions',
        table: _db.sessions,
        rows: data.sessions.map((s) => s.toRow()),
        idOf: (r) => r.id,
        updatedAtOf: (r) => r.updatedAt,
        find: (id) => (_db.select(
          _db.sessions,
        )..where((t) => t.id.equals(id))).getSingleOrNull(),
      );
      await mergeRows<$EventsTable, EventRow>(
        key: 'events',
        table: _db.events,
        rows: [
          for (final e in data.events)
            if (!tombstones.contains(e.id)) e.toRow(),
        ],
        idOf: (r) => r.id,
        updatedAtOf: (r) => r.updatedAt,
        find: (id) => (_db.select(
          _db.events,
        )..where((t) => t.id.equals(id))).getSingleOrNull(),
      );
      await mergeRows<$PersonsTable, PersonRow>(
        key: 'persons',
        table: _db.persons,
        rows: data.persons.map((p) => p.toRow()),
        idOf: (r) => r.id,
        updatedAtOf: (r) => r.updatedAt,
        find: (id) => (_db.select(
          _db.persons,
        )..where((t) => t.id.equals(id))).getSingleOrNull(),
      );
      await mergeRows<$SubstancesTable, SubstanceRow>(
        key: 'substances',
        table: _db.substances,
        rows: data.substances.map((s) => s.toRow()),
        idOf: (r) => r.id,
        updatedAtOf: (r) => r.updatedAt,
        find: (id) => (_db.select(
          _db.substances,
        )..where((t) => t.id.equals(id))).getSingleOrNull(),
      );

      var ins = 0;
      var upd = 0;
      var skip = 0;
      if (importSettings) {
        final now = _clock.nowMs();
        for (final entry in data.settings.entries) {
          if (SettingsKeys.isDeviceLocal(entry.key)) {
            skip++;
            continue;
          }
          final existing = await (_db.select(
            _db.settings,
          )..where((s) => s.key.equals(entry.key))).getSingleOrNull();
          final row = SettingRow(
            key: entry.key,
            value: entry.value,
            updatedAt: now,
          );
          if (existing == null) {
            await _db.into(_db.settings).insert(row);
            ins++;
          } else if (overwriteSettings && existing.value != entry.value) {
            await _db.update(_db.settings).replace(row);
            upd++;
          } else {
            skip++;
          }
        }
      } else {
        skip = data.settings.length;
      }
      inserted['settings'] = ins;
      updated['settings'] = upd;
      skipped['settings'] = skip;

      skipped['events'] = (skipped['events'] ?? 0) + deletedLocally;

      await _reconcileSessions({
        for (final s in data.sessions) s.id,
        for (final e in data.events) e.sessionId,
      });
      await _closeDuplicateOpenSessions();
    });

    await _alarmSync.syncAll();
    return ImportReport(inserted: inserted, updated: updated, skipped: skipped);
  }

  /// Brings `endedAt` of the given sessions in line with their event logs.
  ///
  /// Session rows and event rows are merged independently (each by its own
  /// `updatedAt`), so a row can stay open although its `stop` event came in
  /// with the backup, or be closed without one:
  ///
  /// * a `stop` in the log: the session is closed at that instant;
  /// * a closed row without `stop`: the missing `stop` is added at
  ///   `endedAt`. The session is NOT reopened - an import never makes an
  ///   old timer start running again.
  Future<void> _reconcileSessions(Set<String> sessionIds) async {
    final store = SessionStore(_db);
    final now = _clock.nowMs();
    for (final id in sessionIds) {
      final row = await (_db.select(
        _db.sessions,
      )..where((s) => s.id.equals(id))).getSingleOrNull();
      if (row == null) continue;
      final events = await store.eventsOf(id);
      TrackEvent? stop;
      var maxSeq = -1;
      for (final e in events) {
        if (e.seq > maxSeq) maxSeq = e.seq;
        if (stop == null && e.type == EventType.stop) stop = e;
      }
      final endedAt = row.endedAt;
      if (stop != null) {
        if (endedAt == stop.at) continue;
        await (_db.update(_db.sessions)..where((s) => s.id.equals(id))).write(
          SessionsCompanion(endedAt: Value(stop.at), updatedAt: Value(now)),
        );
      } else if (endedAt != null) {
        await _db
            .into(_db.events)
            .insertOnConflictUpdate(
              TrackEvent(
                id: '$id-stop',
                sessionId: id,
                trackId: row.trackId,
                type: EventType.stop,
                at: endedAt,
                seq: maxSeq + 1,
                createdAt: now,
                updatedAt: now,
              ).toRow(),
            );
      }
    }
  }

  /// A merge can leave a track with two open sessions (one local, one from
  /// the backup). The most recently started one stays open; the others are
  /// closed at their last event so nothing is lost and nothing runs twice.
  Future<void> _closeDuplicateOpenSessions() async {
    final store = SessionStore(_db);
    final open =
        await (_db.select(_db.sessions)
              ..where((s) => s.endedAt.isNull())
              ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
            .get();
    final seen = <String>{};
    final now = _clock.nowMs();
    for (final row in open) {
      if (seen.add(row.trackId)) continue;
      var lastAt = row.startedAt;
      var maxSeq = -1;
      for (final e in await store.eventsOf(row.id)) {
        if (e.at > lastAt) lastAt = e.at;
        if (e.seq > maxSeq) maxSeq = e.seq;
      }
      await _db
          .into(_db.events)
          .insertOnConflictUpdate(
            TrackEvent(
              id: '${row.id}-stop',
              sessionId: row.id,
              trackId: row.trackId,
              type: EventType.stop,
              at: lastAt,
              seq: maxSeq + 1,
              createdAt: now,
              updatedAt: now,
            ).toRow(),
          );
      await (_db.update(_db.sessions)..where((s) => s.id.equals(row.id))).write(
        SessionsCompanion(endedAt: Value(lastAt), updatedAt: Value(now)),
      );
    }
  }
}
