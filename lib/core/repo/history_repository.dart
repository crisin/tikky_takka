import 'package:drift/drift.dart';

import '../clock.dart';
import '../db/app_database.dart';
import '../domain/domain.dart';
import '../engine/engine.dart';
import 'mappers.dart';
import 'models.dart';
import 'session_store.dart';
import 'watch.dart';

/// History queries and after-the-fact editing of sessions and events.
class HistoryRepository {
  HistoryRepository(this._db, this._clock, this._alarmSync)
    : _store = SessionStore(_db);

  final AppDatabase _db;
  final Clock _clock;
  final AlarmSync _alarmSync;
  final SessionStore _store;

  // -------------------------------------------------------------- queries

  /// Sessions matching [filter], newest first, each with its track, set,
  /// events and summary.
  Future<List<HistorySession>> getSessions(HistoryFilter filter) async {
    final tracks = {
      for (final r in await _db.select(_db.tracks).get()) r.id: r.toDomain(),
    };
    final sets = {
      for (final r in await _db.select(_db.trackSets).get())
        r.id: r.toDomain(),
    };

    final query = _db.select(_db.sessions)
      ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]);
    if (!filter.includeOpen) query.where((s) => s.endedAt.isNotNull());
    if (!filter.includeProtocol) {
      query.where((s) => s.mode.equals(TrackMode.protocol.name).not());
    }
    final from = filter.fromMs;
    if (from != null) {
      query.where((s) => s.startedAt.isBiggerOrEqualValue(from));
    }
    final to = filter.toMs;
    if (to != null) query.where((s) => s.startedAt.isSmallerThanValue(to));

    final rows = [
      for (final row in await query.get())
        if (_matches(filter, row.trackId, tracks)) row,
    ];
    final events = await _store.eventsOfSessions(rows.map((r) => r.id));
    final now = _clock.nowMs();
    return [
      for (final row in rows)
        _build(row.toDomain(), events[row.id] ?? const [], tracks, sets, now),
    ];
  }

  /// Like [getSessions], re-emitting whenever the underlying data changes.
  Stream<List<HistorySession>> watchSessions(HistoryFilter filter) =>
      watchTables(_db, [
        _db.sessions,
        _db.events,
        _db.tracks,
        _db.trackSets,
      ], () => getSessions(filter));

  /// What is going on in ONE set: its open sessions and, with [sinceMs],
  /// also the sessions that ended at or after that instant - oldest start
  /// first, each with all its events.
  ///
  /// This is the scoped read behind the timeline of the tracks screen: it
  /// never touches sessions that ended before the range, so its cost
  /// follows what happened recently, not the size of the history.
  Future<List<HistorySession>> getSetActivity(
    String setId, {
    int? sinceMs,
  }) async {
    final tracks = {
      for (final r in await (_db.select(
        _db.tracks,
      )..where((t) => t.setId.equals(setId))).get())
        r.id: r.toDomain(),
    };
    if (tracks.isEmpty) return const [];
    final setRow = await (_db.select(
      _db.trackSets,
    )..where((s) => s.id.equals(setId))).getSingleOrNull();
    final sets = <String, TrackSet>{
      if (setRow != null) setRow.id: setRow.toDomain(),
    };
    final query = _db.select(_db.sessions)
      ..where((s) => s.trackId.isIn(tracks.keys))
      ..where(
        (s) => sinceMs == null
            ? s.endedAt.isNull()
            : s.endedAt.isNull() | s.endedAt.isBiggerOrEqualValue(sinceMs),
      )
      ..orderBy([(s) => OrderingTerm.asc(s.startedAt)]);
    final rows = await query.get();
    final events = await _store.eventsOfSessions(rows.map((r) => r.id));
    final now = _clock.nowMs();
    return [
      for (final row in rows)
        _build(row.toDomain(), events[row.id] ?? const [], tracks, sets, now),
    ];
  }

  /// Like [getSetActivity], re-emitting whenever the underlying data
  /// changes. [sinceMs] is asked again for every load, so a moving range
  /// ("the last 24 hours") stays current.
  Stream<List<HistorySession>> watchSetActivity(
    String setId, {
    int? Function()? sinceMs,
  }) => watchTables(
    _db,
    [_db.sessions, _db.events, _db.tracks, _db.trackSets],
    () => getSetActivity(setId, sinceMs: sinceMs?.call()),
  );

  /// One session with its events (open sessions included), or `null`.
  Future<HistorySession?> getSession(String sessionId) async {
    final session = await _store.session(sessionId);
    if (session == null) return null;
    final track = await _store.track(session.trackId);
    final setRow = track == null
        ? null
        : await (_db.select(
            _db.trackSets,
          )..where((s) => s.id.equals(track.setId))).getSingleOrNull();
    final tracks = <String, Track>{};
    if (track != null) tracks[track.id] = track;
    final sets = <String, TrackSet>{};
    if (setRow != null) sets[setRow.id] = setRow.toDomain();
    return _build(
      session,
      await _store.eventsOf(sessionId),
      tracks,
      sets,
      _clock.nowMs(),
    );
  }

  Stream<HistorySession?> watchSession(String sessionId) => watchTables(_db, [
    _db.sessions,
    _db.events,
    _db.tracks,
    _db.trackSets,
  ], () => getSession(sessionId));

  /// When each person last logged each substance on a track, over ALL its
  /// sessions (open and closed): one aggregate query, the input of
  /// `deriveLockouts`.
  Future<List<LastEntryFact>> getLastEntries(String trackId) async {
    final events = _db.events;
    final lastAt = events.at.max();
    final query = _db.selectOnly(events)
      ..addColumns([events.personId, events.substanceId, lastAt])
      ..where(
        events.trackId.equals(trackId) &
            events.type.equals(EventType.entry.name),
      )
      ..groupBy([events.personId, events.substanceId]);
    return [
      for (final row in await query.get())
        if (row.read(lastAt) case final at?)
          LastEntryFact(
            personId: row.read(events.personId),
            substanceId: row.read(events.substanceId),
            at: at,
          ),
    ];
  }

  /// Like [getLastEntries], re-emitting whenever an event is written.
  Stream<List<LastEntryFact>> watchLastEntries(String trackId) =>
      watchTables(_db, [_db.events], () => getLastEntries(trackId));

  /// How often each person logged each substance on a track, over ALL its
  /// sessions (open and closed): one aggregate query.
  Future<List<SubstanceUse>> getSubstanceUse(String trackId) async {
    final events = _db.events;
    final lastAt = events.at.max();
    final count = events.id.count();
    final query = _db.selectOnly(events)
      ..addColumns([events.personId, events.substanceId, lastAt, count])
      ..where(
        events.trackId.equals(trackId) &
            events.type.equals(EventType.entry.name),
      )
      ..groupBy([events.personId, events.substanceId]);
    return [
      for (final row in await query.get())
        if (row.read(lastAt) case final at?)
          SubstanceUse(
            personId: row.read(events.personId),
            substanceId: row.read(events.substanceId),
            count: row.read(count) ?? 0,
            lastAt: at,
          ),
    ];
  }

  /// Like [getSubstanceUse], re-emitting whenever an event is written.
  Stream<List<SubstanceUse>> watchSubstanceUse(String trackId) =>
      watchTables(_db, [_db.events], () => getSubstanceUse(trackId));

  /// Daily net sums per track for the sessions matching [filter].
  Future<List<TrackPeriodSum>> getDailySums(HistoryFilter filter) async =>
      sumPerTrackPerDay(await getSessions(filter));

  /// Weekly (Monday based) net sums per track for the sessions matching
  /// [filter].
  Future<List<TrackPeriodSum>> getWeeklySums(HistoryFilter filter) async =>
      sumPerTrackPerWeek(await getSessions(filter));

  // -------------------------------------------------------------- editing

  /// Sets or clears the note of a session.
  Future<void> updateSessionNote(String sessionId, String? note) async {
    final trimmed = note?.trim();
    await (_db.update(
      _db.sessions,
    )..where((s) => s.id.equals(sessionId))).write(
      SessionsCompanion(
        note: Value(trimmed == null || trimmed.isEmpty ? null : trimmed),
        updatedAt: Value(_clock.nowMs()),
      ),
    );
  }

  /// Deletes a session with its events. Returns what was removed so the UI
  /// can offer undo through [restoreSession]; `null` if it did not exist.
  Future<DeletedSession?> deleteSession(String sessionId) async {
    final deleted = await _db.transaction(() async {
      final session = await _store.session(sessionId);
      if (session == null) return null;
      final events = await _store.eventsOf(sessionId);
      await (_db.delete(
        _db.events,
      )..where((e) => e.sessionId.equals(sessionId))).go();
      await (_db.delete(
        _db.sessions,
      )..where((s) => s.id.equals(sessionId))).go();
      return DeletedSession(session: session, events: events);
    });
    if (deleted != null && deleted.session.isOpen) {
      await _alarmSync.syncTrack(deleted.session.trackId);
    }
    return deleted;
  }

  /// Puts a deleted session and its events back, unchanged.
  ///
  /// If the session was open and the track has started another session in
  /// the meantime, the restored one is closed at its last event instead, so
  /// a track never has two open sessions.
  Future<void> restoreSession(DeletedSession deleted) async {
    await _db.transaction(() async {
      var session = deleted.session;
      final events = List<TrackEvent>.of(deleted.events);
      if (session.isOpen &&
          await _store.openSessionOf(session.trackId) != null) {
        final now = _clock.nowMs();
        var lastAt = session.startedAt;
        var maxSeq = -1;
        for (final e in events) {
          if (e.at > lastAt) lastAt = e.at;
          if (e.seq > maxSeq) maxSeq = e.seq;
        }
        events.add(
          TrackEvent(
            id: '${session.id}-stop',
            sessionId: session.id,
            trackId: session.trackId,
            type: EventType.stop,
            at: lastAt,
            seq: maxSeq + 1,
            createdAt: now,
            updatedAt: now,
          ),
        );
        session = session.copyWith(endedAt: () => lastAt, updatedAt: now);
      }
      await _db.into(_db.sessions).insertOnConflictUpdate(session.toRow());
      for (final e in events) {
        await _db.into(_db.events).insertOnConflictUpdate(e.toRow());
      }
      await EventTombstones.remove(_db, [for (final e in events) e.id]);
    });
    await _alarmSync.syncTrack(deleted.session.trackId);
  }

  /// Saves an edited event (time, label, person, substance, amount, note).
  /// The event keeps its id, session, track and type. Session bounds and
  /// alarms are brought back in line. Returns `false` if the event no
  /// longer exists.
  Future<bool> updateEvent(TrackEvent event) async {
    String? trackId;
    final ok = await _db.transaction(() async {
      final existingRow = await (_db.select(
        _db.events,
      )..where((e) => e.id.equals(event.id))).getSingleOrNull();
      final existing = existingRow?.toDomain();
      if (existing == null) return false;
      final updated = event.copyWith(
        sessionId: existing.sessionId,
        trackId: existing.trackId,
        type: existing.type,
        seq: existing.seq,
        createdAt: existing.createdAt,
        updatedAt: _clock.nowMs(),
      );
      await _db.update(_db.events).replace(updated.toRow());
      await _syncSessionBounds(existing.sessionId);
      trackId = existing.trackId;
      return true;
    });
    if (trackId != null) await _alarmSync.syncTrack(trackId!);
    return ok;
  }

  /// Deletes a single event (lap, tick, entry, ack, pause, resume) and
  /// returns it for undo through [restoreEvent].
  ///
  /// `start` and `stop` events define the session and cannot be deleted
  /// here (delete the session, or use `TrackCommands.reopenSession`);
  /// `null` is returned for them and for unknown ids.
  Future<TrackEvent?> deleteEvent(String eventId) async {
    final deleted = await _db.transaction(() async {
      final row = await (_db.select(
        _db.events,
      )..where((e) => e.id.equals(eventId))).getSingleOrNull();
      final event = row?.toDomain();
      if (event == null) return null;
      if (event.type == EventType.start || event.type == EventType.stop) {
        return null;
      }
      await (_db.delete(_db.events)..where((e) => e.id.equals(eventId))).go();
      // An older backup must not bring the event back.
      await EventTombstones.add(_db, [eventId], _clock.nowMs());
      await _touchSession(event.sessionId);
      return event;
    });
    if (deleted != null) await _alarmSync.syncTrack(deleted.trackId);
    return deleted;
  }

  /// Puts a deleted event back, unchanged. Does nothing if its session no
  /// longer exists.
  Future<void> restoreEvent(TrackEvent event) async {
    final restored = await _db.transaction(() async {
      if (await _store.session(event.sessionId) == null) return false;
      await _db.into(_db.events).insertOnConflictUpdate(event.toRow());
      await EventTombstones.remove(_db, [event.id]);
      await _touchSession(event.sessionId);
      return true;
    });
    if (restored) await _alarmSync.syncTrack(event.trackId);
  }

  // -------------------------------------------------------------- helpers

  bool _matches(HistoryFilter filter, String trackId, Map<String, Track> all) {
    if (filter.trackIds.isNotEmpty && !filter.trackIds.contains(trackId)) {
      return false;
    }
    final setId = filter.setId;
    if (setId != null && all[trackId]?.setId != setId) return false;
    return true;
  }

  HistorySession _build(
    Session session,
    List<TrackEvent> events,
    Map<String, Track> tracks,
    Map<String, TrackSet> sets,
    int nowMs,
  ) {
    final track = tracks[session.trackId];
    return HistorySession(
      session: session,
      events: List.unmodifiable(events),
      summary: summarizeSession(
        config: session.config,
        events: events,
        nowMs: nowMs,
      ),
      track: track,
      set: track == null ? null : sets[track.setId],
    );
  }

  Future<void> _touchSession(String sessionId) async {
    await (_db.update(_db.sessions)..where((s) => s.id.equals(sessionId)))
        .write(SessionsCompanion(updatedAt: Value(_clock.nowMs())));
  }

  /// Re-derives `startedAt` / `endedAt` of a session from its start and
  /// stop events after an edit.
  Future<void> _syncSessionBounds(String sessionId) async {
    final session = await _store.session(sessionId);
    if (session == null) return;
    final events = await _store.eventsOf(sessionId);
    var startedAt = session.startedAt;
    var endedAt = session.endedAt;
    for (final e in events) {
      if (e.type == EventType.start) {
        startedAt = e.at;
        break;
      }
    }
    if (endedAt != null) {
      for (final e in events) {
        if (e.type == EventType.stop) {
          endedAt = e.at;
          break;
        }
      }
    }
    await (_db.update(
      _db.sessions,
    )..where((s) => s.id.equals(sessionId))).write(
      SessionsCompanion(
        startedAt: Value(startedAt),
        endedAt: Value(endedAt),
        updatedAt: Value(_clock.nowMs()),
      ),
    );
  }
}
