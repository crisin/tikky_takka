import 'package:drift/drift.dart';

import '../clock.dart';
import '../db/app_database.dart';
import '../domain/domain.dart';
import '../engine/engine.dart';
import '../services/alarms/alarm_service.dart';
import 'mappers.dart';
import 'models.dart';

/// Low-level session / event access shared by the repositories.
class SessionStore {
  SessionStore(this.db);

  final AppDatabase db;

  Future<Track?> track(String id) async {
    final row = await (db.select(
      db.tracks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.toDomain();
  }

  Future<Session?> session(String id) async {
    final row = await (db.select(
      db.sessions,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    return row?.toDomain();
  }

  /// The open session of a track (the most recently started one should
  /// several exist after an import).
  Future<Session?> openSessionOf(String trackId) async {
    final rows =
        await (db.select(db.sessions)
              ..where((s) => s.trackId.equals(trackId) & s.endedAt.isNull())
              ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.first.toDomain();
  }

  /// Events of a session in chronological order.
  Future<List<TrackEvent>> eventsOf(String sessionId) async {
    final rows =
        await (db.select(db.events)
              ..where((e) => e.sessionId.equals(sessionId))
              ..orderBy([
                (e) => OrderingTerm.asc(e.at),
                (e) => OrderingTerm.asc(e.seq),
              ]))
            .get();
    return eventsFromRows(rows);
  }

  /// Events of several sessions, grouped by session id, each list in
  /// chronological order.
  Future<Map<String, List<TrackEvent>>> eventsOfSessions(
    Iterable<String> sessionIds,
  ) async {
    final ids = sessionIds.toList();
    final result = <String, List<TrackEvent>>{for (final id in ids) id: []};
    // Stay well below SQLite's bound-parameter limit.
    const chunk = 500;
    for (var i = 0; i < ids.length; i += chunk) {
      final part = ids.sublist(
        i,
        i + chunk > ids.length ? ids.length : i + chunk,
      );
      final rows =
          await (db.select(db.events)
                ..where((e) => e.sessionId.isIn(part))
                ..orderBy([
                  (e) => OrderingTerm.asc(e.at),
                  (e) => OrderingTerm.asc(e.seq),
                ]))
              .get();
      for (final row in rows) {
        final event = row.toDomain();
        if (event != null) result[row.sessionId]!.add(event);
      }
    }
    return result;
  }

  /// All open sessions keyed by track id.
  Future<Map<String, OpenSession>> openSessions() async {
    final rows =
        await (db.select(db.sessions)
              ..where((s) => s.endedAt.isNull())
              ..orderBy([(s) => OrderingTerm.asc(s.startedAt)]))
            .get();
    if (rows.isEmpty) return const {};
    final events = await eventsOfSessions(rows.map((r) => r.id));
    return {
      // Ordered by start, so a later session of the same track wins.
      for (final row in rows)
        row.trackId: OpenSession(
          session: row.toDomain(),
          events: List.unmodifiable(events[row.id] ?? const []),
        ),
    };
  }
}

/// The event-appending primitives shared by the timer commands and the
/// repositories (archiving stops a track, switching "exclusive" on pauses
/// the others). Call inside a transaction.
class SessionWriter {
  SessionWriter(this.db, this._clock, this._newId) : store = SessionStore(db);

  final AppDatabase db;
  final Clock _clock;
  final IdGenerator _newId;
  final SessionStore store;

  static bool isExclusive(Track track) {
    final config = track.config;
    return config is StopwatchConfig && config.exclusive;
  }

  Future<OpenSession?> openSession(String trackId) async {
    final session = await store.openSessionOf(trackId);
    if (session == null) return null;
    return OpenSession(
      session: session,
      events: await store.eventsOf(session.id),
    );
  }

  TrackSnapshot snapshot(OpenSession open) => deriveSnapshot(
    config: open.session.config,
    events: open.events,
    nowMs: _clock.nowMs(),
  );

  /// Non-archived tracks of a set, ordered.
  Future<List<Track>> activeTracks(String setId) async {
    final rows =
        await (db.select(db.tracks)
              ..where((t) => t.setId.equals(setId) & t.archived.equals(false))
              ..orderBy([(t) => OrderingTerm.asc(t.sortIndex)]))
            .get();
    return [for (final r in rows) r.toDomain()];
  }

  /// Appends an event to the session and bumps the session's `updatedAt`
  /// (so that a backup merge sees the session as changed).
  ///
  /// Without an explicit [at] the time is "now", but never before the last
  /// event of the session: a clock that jumps backwards cannot reorder the
  /// log.
  Future<TrackEvent> append(
    OpenSession open,
    EventType type, {
    int? at,
    String? label,
    String? personId,
    String? substanceId,
    String? amount,
    String? note,
  }) async {
    final now = _clock.nowMs();
    var lastAt = open.session.startedAt;
    var maxSeq = -1;
    for (final e in open.events) {
      if (e.at > lastAt) lastAt = e.at;
      if (e.seq > maxSeq) maxSeq = e.seq;
    }
    final event = TrackEvent(
      id: _newId(),
      sessionId: open.session.id,
      trackId: open.session.trackId,
      type: type,
      at: at ?? (now < lastAt ? lastAt : now),
      seq: maxSeq + 1,
      label: label,
      personId: personId,
      substanceId: substanceId,
      amount: amount,
      note: note,
      createdAt: now,
      updatedAt: now,
    );
    await db.into(db.events).insert(event.toRow());
    await touchSession(open.session.id);
    return event;
  }

  /// Marks the session as changed "now".
  Future<void> touchSession(String sessionId) async {
    await (db.update(db.sessions)..where((s) => s.id.equals(sessionId))).write(
      SessionsCompanion(updatedAt: Value(_clock.nowMs())),
    );
  }

  /// Pauses the open session of the track when it is running or ringing.
  Future<TrackAction> pause(String trackId) async {
    final open = await openSession(trackId);
    if (open == null) return TrackAction.none;
    if (!snapshot(open).isTicking) return TrackAction.none;
    await append(open, EventType.pause);
    return TrackAction.paused;
  }

  /// Appends `stop` to the open session of the track and closes it.
  /// Returns the id of the closed session, or `null` if none was open.
  Future<String?> stop(String trackId) async {
    final open = await openSession(trackId);
    if (open == null) return null;
    final stop = await append(open, EventType.stop);
    await closeSession(open.session.id, stop.at);
    return open.session.id;
  }

  Future<void> closeSession(String sessionId, int endedAt) async {
    await (db.update(db.sessions)..where((s) => s.id.equals(sessionId))).write(
      SessionsCompanion(
        endedAt: Value(endedAt),
        updatedAt: Value(_clock.nowMs()),
      ),
    );
  }

  /// Pauses the other running exclusive stopwatches of the set of [track]
  /// (nothing when [track] is not an exclusive stopwatch). Returns the ids
  /// of the paused tracks.
  Future<List<String>> pauseOtherExclusive(Track track) async {
    if (!isExclusive(track)) return const [];
    final paused = <String>[];
    for (final other in await activeTracks(track.setId)) {
      if (other.id == track.id || !isExclusive(other)) continue;
      if (await pause(other.id) == TrackAction.paused) paused.add(other.id);
    }
    return paused;
  }

  /// [pauseOtherExclusive], but only when [track] itself is running right
  /// now: used when a running stopwatch becomes exclusive or joins a set.
  Future<List<String>> enforceExclusive(Track track) async {
    if (!isExclusive(track) || track.archived) return const [];
    final open = await openSession(track.id);
    if (open == null || !snapshot(open).isRunning) return const [];
    return pauseOtherExclusive(track);
  }
}

/// Remembers the ids of events the user deleted one by one (undone tick,
/// deleted lap / entry, the `stop` removed by reopening a session), so that
/// merging an OLDER backup does not bring them back - which would re-count
/// a tick or close a reopened session again.
///
/// Stored without a schema change as one small row per id in the settings
/// table (`tombstone.event.<id>`); the rows are device-local: they are
/// neither exported nor imported and are invisible to `SettingsStore`.
/// Whole deleted sessions and tracks are deliberately NOT remembered:
/// importing a backup stays the way to get those back.
abstract final class EventTombstones {
  static const String prefix = 'tombstone.event.';

  /// Upper bound of remembered ids; the oldest are forgotten first.
  static const int maxCount = 5000;

  static bool isKey(String key) => key.startsWith(prefix);

  static Future<void> add(
    AppDatabase db,
    Iterable<String> eventIds,
    int nowMs,
  ) async {
    var added = false;
    for (final id in eventIds) {
      await db
          .into(db.settings)
          .insertOnConflictUpdate(
            SettingRow(key: '$prefix$id', value: '1', updatedAt: nowMs),
          );
      added = true;
    }
    if (added) await _prune(db);
  }

  static Future<void> remove(AppDatabase db, Iterable<String> eventIds) async {
    for (final id in eventIds) {
      await (db.delete(
        db.settings,
      )..where((s) => s.key.equals('$prefix$id'))).go();
    }
  }

  /// The remembered event ids.
  static Future<Set<String>> load(AppDatabase db) async {
    final rows = await (db.select(
      db.settings,
    )..where((s) => s.key.like('$prefix%'))).get();
    return {for (final r in rows) r.key.substring(prefix.length)};
  }

  static Future<void> _prune(AppDatabase db) async {
    final rows =
        await (db.select(db.settings)
              ..where((s) => s.key.like('$prefix%'))
              ..orderBy([
                (s) => OrderingTerm.desc(s.updatedAt),
                (s) => OrderingTerm.desc(s.key),
              ])
              ..limit(1 << 30, offset: maxCount))
            .get();
    for (final row in rows) {
      await (db.delete(db.settings)..where((s) => s.key.equals(row.key))).go();
    }
  }
}

/// Keeps OS alarms in line with the event log.
class AlarmSync {
  AlarmSync(this._store, this._clock, this._alarms);

  final SessionStore _store;
  final Clock _clock;
  final AlarmService _alarms;

  /// Maximum number of OS notifications planned per track.
  static const int maxAlarmsPerTrack = 16;

  /// Recomputes and (re)schedules the alarms of one track from its open
  /// session; cancels them when nothing is due in the future.
  Future<void> syncTrack(String trackId) async {
    try {
      final track = await _store.track(trackId);
      final session = track == null || track.archived
          ? null
          : await _store.openSessionOf(trackId);
      if (track == null || session == null || !session.mode.hasAlarms) {
        await _alarms.cancelForTrack(trackId);
        return;
      }
      final plan = planAlarms(
        trackId: trackId,
        config: session.config,
        events: await _store.eventsOf(session.id),
        nowMs: _clock.nowMs(),
        maxCount: maxAlarmsPerTrack,
      );
      if (plan.isEmpty) {
        await _alarms.cancelForTrack(trackId);
      } else {
        await _alarms.scheduleForTrack(track, plan);
      }
    } catch (_) {
      // Alarm problems must never break a timer command; the in-app state
      // is derived from the log and stays correct.
    }
  }

  Future<void> cancelTrack(String trackId) async {
    try {
      await _alarms.cancelForTrack(trackId);
    } catch (_) {}
  }

  /// Cancels everything and reschedules all open sessions. Called on app
  /// start and after a backup import.
  Future<void> syncAll() async {
    try {
      await _alarms.cancelAll();
    } catch (_) {}
    final open = await _store.openSessions();
    for (final entry in open.entries) {
      if (entry.value.session.mode.hasAlarms) await syncTrack(entry.key);
    }
  }
}
