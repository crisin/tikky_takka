import 'package:drift/drift.dart';

import '../clock.dart';
import '../db/app_database.dart';
import '../domain/domain.dart';
import '../engine/engine.dart';
import 'mappers.dart';
import 'models.dart';
import 'session_store.dart';
import 'watch.dart';

/// The timer commands: everything a lane button does.
///
/// Every command appends timestamped events to the log (never mutates
/// counters), keeps at most one open session per track and (re)schedules or
/// cancels the OS alarms of the affected tracks.
///
/// Commands are forgiving: called in a state where they make no sense they do
/// nothing and report [TrackAction.none] / `null`.
class TrackCommands {
  TrackCommands(this._db, this._clock, this._newId, this._alarmSync)
    : _store = SessionStore(_db),
      _writer = SessionWriter(_db, _clock, _newId);

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _newId;
  final AlarmSync _alarmSync;
  final SessionStore _store;
  final SessionWriter _writer;

  // ---------------------------------------------------------------- reads

  /// All open sessions keyed by track id; re-emits on every change of the
  /// log. This is the single live query behind all lanes.
  Stream<Map<String, OpenSession>> watchOpenSessions() =>
      watchTables(_db, [_db.sessions, _db.events], _store.openSessions);

  Future<Map<String, OpenSession>> getOpenSessions() => _store.openSessions();

  Future<OpenSession?> getOpenSession(String trackId) async {
    final session = await _store.openSessionOf(trackId);
    if (session == null) return null;
    return OpenSession(
      session: session,
      events: await _store.eventsOf(session.id),
    );
  }

  // ------------------------------------------------------------- commands

  /// Starts the track, or resumes it when paused.
  ///
  /// * No open session: creates one with a `start` event. Counter tracks
  ///   also get their first `tick` (use [tick] to pass a label).
  /// * Paused: appends `resume`.
  /// * An exclusive stopwatch pauses every other running exclusive
  ///   stopwatch of the same set.
  Future<TrackAction> startTrack(String trackId) async {
    final affected = <String>{trackId};
    final action = await _db.transaction(() async {
      final track = await _store.track(trackId);
      if (track == null) return TrackAction.none;
      final result = await _startOrResume(track);
      if (result != TrackAction.none) {
        affected.addAll(await _pauseOtherExclusive(track));
      }
      return result;
    });
    await _syncAlarms(affected);
    return action;
  }

  /// Pauses a running (or ringing) track.
  Future<TrackAction> pauseTrack(String trackId) async {
    final action = await _db.transaction(() => _pause(trackId));
    await _syncAlarms({trackId});
    return action;
  }

  /// Resumes a paused track. Does nothing when it is not paused.
  Future<TrackAction> resumeTrack(String trackId) async {
    final affected = <String>{trackId};
    final action = await _db.transaction(() async {
      final track = await _store.track(trackId);
      if (track == null) return TrackAction.none;
      final open = await getOpenSession(trackId);
      if (open == null || !_snapshot(open).isPaused) return TrackAction.none;
      await _append(open, EventType.resume);
      affected.addAll(await _pauseOtherExclusive(track));
      return TrackAction.resumed;
    });
    await _syncAlarms(affected);
    return action;
  }

  /// What the round primary button of a lane does:
  ///
  /// | mode | idle | running | paused | ringing |
  /// |---|---|---|---|---|
  /// | stopwatch, countdown, interval | start | pause | resume | stop |
  /// | reminder | start | pause | resume | ack |
  /// | counter | tick | tick | tick | - |
  /// | protocol | nothing (the lane opens the entry sheet) |
  Future<TrackAction> toggleTrack(String trackId) async {
    final track = await _store.track(trackId);
    if (track == null) return TrackAction.none;
    switch (track.mode) {
      case TrackMode.counter:
        return await tick(trackId) == null
            ? TrackAction.none
            : TrackAction.ticked;
      case TrackMode.protocol:
        return TrackAction.none;
      case TrackMode.stopwatch ||
          TrackMode.countdown ||
          TrackMode.interval ||
          TrackMode.reminder:
        break;
    }
    final open = await getOpenSession(trackId);
    if (open == null) return startTrack(trackId);
    final snapshot = _snapshot(open);
    switch (snapshot.state) {
      case RunState.idle || RunState.stopped:
        return startTrack(trackId);
      case RunState.running:
        return pauseTrack(trackId);
      case RunState.paused:
        return resumeTrack(trackId);
      case RunState.ringing:
        if (track.mode == TrackMode.reminder) {
          return await ack(trackId) == null
              ? TrackAction.none
              : TrackAction.acknowledged;
        }
        return await stopTrack(trackId) == null
            ? TrackAction.none
            : TrackAction.stopped;
    }
  }

  /// Records a lap on a running stopwatch. Returns the lap event.
  Future<TrackEvent?> lap(String trackId, {String? label}) {
    return _db.transaction(() async {
      final open = await getOpenSession(trackId);
      if (open == null || open.session.mode != TrackMode.stopwatch) return null;
      if (!_snapshot(open).isRunning) return null;
      return _append(open, EventType.lap, label: label);
    });
  }

  /// Counts one on a counter track. The first tick creates the session
  /// (`start` + `tick`, count 1); a paused counter is resumed first.
  Future<TrackEvent?> tick(String trackId, {String? label}) {
    return _db.transaction(() async {
      final track = await _store.track(trackId);
      if (track == null || track.mode != TrackMode.counter) return null;
      var open = await _writableOpenSession(trackId);
      if (open == null) {
        open = await _createSession(track);
      } else if (_snapshot(open).isPaused) {
        final resume = await _append(open, EventType.resume);
        open = OpenSession(
          session: open.session,
          events: [...open.events, resume],
        );
      }
      return _append(open, EventType.tick, label: label);
    });
  }

  /// Removes the most recent tick of the open counter session (never the
  /// start). Returns the removed event, or `null` if there was none.
  Future<TrackEvent?> undoTick(String trackId) {
    return _db.transaction(() async {
      final open = await getOpenSession(trackId);
      if (open == null) return null;
      final ticks = open.events.where((e) => e.type == EventType.tick);
      if (ticks.isEmpty) return null;
      final last = ticks.last;
      await (_db.delete(_db.events)..where((e) => e.id.equals(last.id))).go();
      await EventTombstones.add(_db, [last.id], _clock.nowMs());
      await _writer.touchSession(open.session.id);
      return last;
    });
  }

  /// Acknowledges a reminder (also allowed before it is due). The next due
  /// time counts from this ack. Returns the ack event.
  Future<TrackEvent?> ack(String trackId) async {
    final event = await _db.transaction(() async {
      final open = await getOpenSession(trackId);
      if (open == null || open.session.mode != TrackMode.reminder) return null;
      final snapshot = _snapshot(open);
      if (!snapshot.isOpen) return null;
      OpenSession current = open;
      if (snapshot.isPaused) {
        final resume = await _append(open, EventType.resume);
        current = OpenSession(
          session: open.session,
          events: [...open.events, resume],
        );
      }
      return _append(current, EventType.ack);
    });
    await _syncAlarms({trackId});
    return event;
  }

  /// Adds a protocol entry. Creates the session when the track has none.
  /// [at] defaults to now (pass it to back-date an entry).
  Future<TrackEvent?> addEntry(
    String trackId, {
    String? personId,
    String? substanceId,
    String? amount,
    String? note,
    int? at,
  }) {
    return _db.transaction(() async {
      final track = await _store.track(trackId);
      if (track == null || track.mode != TrackMode.protocol) return null;
      final open =
          await _writableOpenSession(trackId) ??
          await _createSession(track, at: at);
      return _append(
        open,
        EventType.entry,
        at: at,
        personId: personId,
        substanceId: substanceId,
        amount: _blankToNull(amount),
        note: _blankToNull(note),
      );
    });
  }

  /// Ends the open session of the track (dismisses a ringing timer): appends
  /// `stop` and closes the session, which then shows up in the history.
  /// Returns the id of the closed session, or `null` if none was open.
  Future<String?> stopTrack(String trackId) async {
    final sessionId = await _db.transaction(() => _stop(trackId));
    await _syncAlarms({trackId});
    return sessionId;
  }

  /// Puts the lane back to its idle state.
  ///
  /// By default this is [stopTrack]: the run is logged and stays in the
  /// history (undo with [reopenSession] and the returned session id). With
  /// [discard] the open session and its events are deleted instead (undo
  /// with `HistoryRepository.restoreSession` and the returned value).
  ///
  /// Returns the session as it was before the reset, or `null` if the track
  /// had no open session.
  Future<DeletedSession?> resetTrack(
    String trackId, {
    bool discard = false,
  }) async {
    final result = await _db.transaction(() async {
      final open = await getOpenSession(trackId);
      if (open == null) return null;
      if (!discard) {
        await _stop(trackId);
        return DeletedSession(session: open.session, events: open.events);
      }
      await (_db.delete(
        _db.events,
      )..where((e) => e.sessionId.equals(open.session.id))).go();
      await (_db.delete(
        _db.sessions,
      )..where((s) => s.id.equals(open.session.id))).go();
      return DeletedSession(session: open.session, events: open.events);
    });
    await _syncAlarms({trackId});
    return result;
  }

  /// Stops the open session (if any) and immediately starts a fresh one.
  ///
  /// One transaction (a failure cannot leave the track stopped but not
  /// restarted) and one alarm sync.
  Future<TrackAction> restartTrack(String trackId) async {
    final affected = <String>{trackId};
    final action = await _db.transaction(() async {
      await _stop(trackId);
      final track = await _store.track(trackId);
      if (track == null) return TrackAction.none;
      final result = await _startOrResume(track);
      if (result != TrackAction.none) {
        affected.addAll(await _pauseOtherExclusive(track));
      }
      return result;
    });
    await _syncAlarms(affected);
    return action;
  }

  /// Undo for [stopTrack] / [resetTrack]: removes the `stop` event of a
  /// closed session and reopens it. Fails (returns `false`) when the track
  /// already has another open session.
  Future<bool> reopenSession(String sessionId) async {
    String? trackId;
    final ok = await _db.transaction(() async {
      final session = await _store.session(sessionId);
      if (session == null || session.isOpen) return false;
      if (await _store.openSessionOf(session.trackId) != null) return false;
      // Remember the removed stop(s): an older backup must not close the
      // session again.
      await EventTombstones.add(_db, [
        for (final e in await _store.eventsOf(sessionId))
          if (e.type == EventType.stop) e.id,
      ], _clock.nowMs());
      await (_db.delete(_db.events)..where(
            (e) =>
                e.sessionId.equals(sessionId) &
                e.type.equals(EventType.stop.name),
          ))
          .go();
      await (_db.update(
        _db.sessions,
      )..where((s) => s.id.equals(sessionId))).write(
        SessionsCompanion(
          endedAt: const Value(null),
          updatedAt: Value(_clock.nowMs()),
        ),
      );
      trackId = session.trackId;
      return true;
    });
    if (trackId != null) await _syncAlarms({trackId!});
    return ok;
  }

  /// "Alle starten": starts / resumes every stopwatch, countdown, interval
  /// and reminder of the set that is idle or paused. Counters and protocol
  /// tracks are tap-driven and skipped; ringing tracks are left alone.
  ///
  /// Exclusive stopwatches exclude each other, so they are only started
  /// when the set has exactly one of them. Returns the number of tracks
  /// that changed.
  Future<int> startAll(String setId) async {
    final affected = <String>{};
    await _db.transaction(() async {
      final tracks = await _activeTracks(setId);
      final exclusiveCount = tracks.where(_isExclusive).length;
      for (final track in tracks) {
        if (!track.mode.supportsStartPause) continue;
        if (_isExclusive(track) && exclusiveCount > 1) continue;
        final action = await _startOrResume(track);
        if (action != TrackAction.none) affected.add(track.id);
      }
    });
    await _syncAlarms(affected);
    return affected.length;
  }

  /// "Alle pausieren": pauses every running stopwatch, countdown, interval
  /// and reminder of the set. Returns the number of tracks that changed.
  Future<int> pauseAll(String setId) async {
    final affected = <String>{};
    await _db.transaction(() async {
      for (final track in await _activeTracks(setId)) {
        if (!track.mode.supportsStartPause) continue;
        final open = await getOpenSession(track.id);
        if (open == null || !_snapshot(open).isRunning) continue;
        await _append(open, EventType.pause);
        affected.add(track.id);
      }
    });
    await _syncAlarms(affected);
    return affected.length;
  }

  /// Rebuilds all OS alarms from the event log. Call on app start.
  Future<void> rescheduleAllAlarms() => _alarmSync.syncAll();

  // -------------------------------------------------------------- helpers

  TrackSnapshot _snapshot(OpenSession open) => _writer.snapshot(open);

  bool _isExclusive(Track track) => SessionWriter.isExclusive(track);

  Future<List<Track>> _activeTracks(String setId) =>
      _writer.activeTracks(setId);

  Future<void> _syncAlarms(Iterable<String> trackIds) async {
    for (final id in trackIds) {
      await _alarmSync.syncTrack(id);
    }
  }

  String? _blankToNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// The open session of the track for a command that is about to write.
  ///
  /// Self-healing: a session row that is still open although its log
  /// already holds a `stop` (inconsistent import) is closed for good and
  /// `null` is returned, so the track can start again instead of being
  /// stuck.
  Future<OpenSession?> _writableOpenSession(String trackId) async {
    final open = await getOpenSession(trackId);
    if (open == null) return null;
    final stoppedAt = _snapshot(open).stoppedAt;
    if (stoppedAt == null) return open;
    await _writer.closeSession(open.session.id, stoppedAt);
    return getOpenSession(trackId);
  }

  Future<TrackAction> _startOrResume(Track track) async {
    final open = await _writableOpenSession(track.id);
    if (open == null) {
      final created = await _createSession(track);
      if (track.mode == TrackMode.counter) {
        await _append(created, EventType.tick);
      }
      return TrackAction.started;
    }
    if (_snapshot(open).isPaused) {
      await _append(open, EventType.resume);
      return TrackAction.resumed;
    }
    return TrackAction.none;
  }

  Future<TrackAction> _pause(String trackId) => _writer.pause(trackId);

  Future<String?> _stop(String trackId) => _writer.stop(trackId);

  /// Pauses the other running exclusive stopwatches of the set of [track].
  /// Returns the ids of the paused tracks.
  Future<List<String>> _pauseOtherExclusive(Track track) =>
      _writer.pauseOtherExclusive(track);

  /// Creates the session of [track] with its `start` event.
  Future<OpenSession> _createSession(Track track, {int? at}) async {
    final now = _clock.nowMs();
    final startAt = at ?? now;
    final session = Session(
      id: _newId(),
      trackId: track.id,
      config: track.config,
      startedAt: startAt,
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.sessions).insert(session.toRow());
    final start = TrackEvent(
      id: _newId(),
      sessionId: session.id,
      trackId: track.id,
      type: EventType.start,
      at: startAt,
      seq: 0,
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.events).insert(start.toRow());
    return OpenSession(session: session, events: [start]);
  }

  Future<TrackEvent> _append(
    OpenSession open,
    EventType type, {
    int? at,
    String? label,
    String? personId,
    String? substanceId,
    String? amount,
    String? note,
  }) => _writer.append(
    open,
    type,
    at: at,
    label: label,
    personId: personId,
    substanceId: substanceId,
    amount: amount,
    note: note,
  );
}
