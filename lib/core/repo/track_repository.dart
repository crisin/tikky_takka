import 'dart:convert';

import 'package:drift/drift.dart';

import '../clock.dart';
import '../db/app_database.dart';
import '../domain/domain.dart';
import 'mappers.dart';
import 'models.dart';
import 'session_store.dart';
import 'watch.dart';

/// CRUD and ordering for tracks.
class TrackRepository {
  TrackRepository(this._db, this._clock, this._newId, this._alarmSync)
    : _writer = SessionWriter(_db, _clock, _newId);

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _newId;
  final AlarmSync _alarmSync;
  final SessionWriter _writer;

  /// Tracks of a set ordered by `sortIndex`.
  Future<List<Track>> getTracks(
    String setId, {
    bool includeArchived = false,
  }) async {
    final query = _db.select(_db.tracks)
      ..where((t) => t.setId.equals(setId))
      ..orderBy([
        (t) => OrderingTerm.asc(t.sortIndex),
        (t) => OrderingTerm.asc(t.createdAt),
      ]);
    if (!includeArchived) query.where((t) => t.archived.equals(false));
    return [for (final r in await query.get()) r.toDomain()];
  }

  Stream<List<Track>> watchTracks(
    String setId, {
    bool includeArchived = false,
  }) => watchTables(_db, [
    _db.tracks,
  ], () => getTracks(setId, includeArchived: includeArchived));

  /// Every track of every set (archived ones included by default), ordered
  /// by set and `sortIndex`. For history filters and name lookups.
  Future<List<Track>> getAllTracks({bool includeArchived = true}) async {
    final query = _db.select(_db.tracks)
      ..orderBy([
        (t) => OrderingTerm.asc(t.setId),
        (t) => OrderingTerm.asc(t.sortIndex),
        (t) => OrderingTerm.asc(t.createdAt),
      ]);
    if (!includeArchived) query.where((t) => t.archived.equals(false));
    return [for (final r in await query.get()) r.toDomain()];
  }

  Stream<List<Track>> watchAllTracks({bool includeArchived = true}) =>
      watchTables(_db, [
        _db.tracks,
      ], () => getAllTracks(includeArchived: includeArchived));

  Future<Track?> getTrack(String id) async {
    final row = await (_db.select(
      _db.tracks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.toDomain();
  }

  /// Creates a track at the end of its set. Without [colorIndex] the next
  /// palette colour is used.
  Future<Track> createTrack({
    required String setId,
    required String name,
    required TrackConfig config,
    int? colorIndex,
    int? customColor,
    bool alarmSound = true,
    bool vibration = true,
  }) async {
    return _db.transaction(() async {
      final siblings = await getTracks(setId, includeArchived: true);
      final nextSort = siblings.isEmpty
          ? 0
          : siblings.map((t) => t.sortIndex).reduce((a, b) => a > b ? a : b) +
                1;
      final now = _clock.nowMs();
      final track = Track(
        id: _newId(),
        setId: setId,
        name: name,
        config: config,
        colorIndex: colorIndex ?? siblings.length,
        customColor: customColor,
        alarmSound: alarmSound,
        vibration: vibration,
        sortIndex: nextSort,
        createdAt: now,
        updatedAt: now,
      );
      await _db.into(_db.tracks).insert(track.toRow());
      return track;
    });
  }

  /// Saves all fields of [track] (matched by id) and bumps `updatedAt`.
  ///
  /// A configuration change is copied into the open session of the track
  /// (same mode only) and its alarms are rescheduled, so editing e.g. the
  /// duration of a running timer takes effect immediately.
  ///
  /// When this makes a RUNNING stopwatch exclusive, the other running
  /// exclusive stopwatches of its set are paused (the same rule as on
  /// start / resume).
  Future<void> updateTrack(Track track) async {
    final paused = await _db.transaction(() async {
      final now = _clock.nowMs();
      await _db
          .update(_db.tracks)
          .replace(track.copyWith(updatedAt: now).toRow());
      await (_db.update(_db.sessions)..where(
            (s) =>
                s.trackId.equals(track.id) &
                s.endedAt.isNull() &
                s.mode.equals(track.mode.name),
          ))
          .write(
            SessionsCompanion(
              configJson: Value(jsonEncode(track.config.toJson())),
              updatedAt: Value(now),
            ),
          );
      return _writer.enforceExclusive(track);
    });
    await _alarmSync.syncTrack(track.id);
    for (final id in paused) {
      await _alarmSync.syncTrack(id);
    }
  }

  /// Copies a track (configuration only, no sessions) to the end of its set.
  Future<Track?> duplicateTrack(String id, {String? name}) async {
    final source = await getTrack(id);
    if (source == null) return null;
    return createTrack(
      setId: source.setId,
      name: name ?? source.name,
      config: source.config,
      colorIndex: source.colorIndex,
      customColor: source.customColor,
      alarmSound: source.alarmSound,
      vibration: source.vibration,
    );
  }

  /// Rewrites `sortIndex` so the tracks of [setId] appear in the order of
  /// [orderedIds]. Tracks missing from the list keep their relative order
  /// after it.
  Future<void> reorderTracks(String setId, List<String> orderedIds) async {
    await _db.transaction(() async {
      final existing = await getTracks(setId, includeArchived: true);
      final known = {for (final t in existing) t.id};
      final ordered = [
        for (final id in orderedIds)
          if (known.contains(id)) id,
      ];
      final rest = [
        for (final t in existing)
          if (!ordered.contains(t.id)) t.id,
      ];
      final now = _clock.nowMs();
      var index = 0;
      for (final id in [...ordered, ...rest]) {
        await (_db.update(_db.tracks)..where((t) => t.id.equals(id))).write(
          TracksCompanion(sortIndex: Value(index++), updatedAt: Value(now)),
        );
      }
    });
  }

  /// Moves a track to the end of another set (its history moves with it).
  ///
  /// A running exclusive stopwatch pauses the other running exclusive
  /// stopwatches of the set it joins.
  Future<void> moveTrackToSet(String trackId, String setId) async {
    final paused = await _db.transaction(() async {
      final siblings = await getTracks(setId, includeArchived: true);
      final nextSort = siblings.isEmpty
          ? 0
          : siblings.map((t) => t.sortIndex).reduce((a, b) => a > b ? a : b) +
                1;
      await (_db.update(_db.tracks)..where((t) => t.id.equals(trackId))).write(
        TracksCompanion(
          setId: Value(setId),
          sortIndex: Value(nextSort),
          updatedAt: Value(_clock.nowMs()),
        ),
      );
      final moved = await getTrack(trackId);
      return moved == null
          ? const <String>[]
          : await _writer.enforceExclusive(moved);
    });
    for (final id in paused) {
      await _alarmSync.syncTrack(id);
    }
  }

  /// Hides (or restores) a track without touching its history.
  ///
  /// Archiving ENDS the open session of the track (a hidden track must not
  /// keep running, counting or ringing) and cancels its alarms; the run
  /// stays in the history. Returns the id of the session that was ended,
  /// or `null` - pass it to `TrackCommands.reopenSession` after restoring
  /// the track to undo an archive completely.
  Future<String?> setArchived(String id, {required bool archived}) async {
    final stopped = await _db.transaction(() async {
      await (_db.update(_db.tracks)..where((t) => t.id.equals(id))).write(
        TracksCompanion(
          archived: Value(archived),
          updatedAt: Value(_clock.nowMs()),
        ),
      );
      if (!archived) return null;
      // Every open session, should an import have left more than one.
      String? last;
      for (var i = 0; i < 8; i++) {
        final sessionId = await _writer.stop(id);
        if (sessionId == null) break;
        last ??= sessionId;
      }
      return last;
    });
    await _alarmSync.syncTrack(id);
    return stopped;
  }

  /// Permanently deletes a track with all its sessions and events. There is
  /// no undo: prefer [setArchived] where the history should stay.
  Future<void> deleteTrack(String id) async {
    await _db.transaction(() async {
      await (_db.delete(_db.events)..where((e) => e.trackId.equals(id))).go();
      await (_db.delete(_db.sessions)..where((s) => s.trackId.equals(id))).go();
      await (_db.delete(_db.tracks)..where((t) => t.id.equals(id))).go();
    });
    await _alarmSync.cancelTrack(id);
  }
}
