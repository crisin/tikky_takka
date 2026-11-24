import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';
import 'package:tikky_takka/core/repo/repo.dart';

import '../../support/events.dart';
import '../../support/test_env.dart';

void main() {
  final env = useTestEnv();

  group('stopwatch commands', () {
    test('start, pause, resume, lap, stop are logged as events', () async {
      final e = env();
      final set = await e.makeSet();
      final track = await e.makeTrack(set, const StopwatchConfig());

      expect(await e.commands.startTrack(track.id), TrackAction.started);
      e.clock.advanceMs(10 * sec);
      expect(await e.commands.lap(track.id), isNotNull);
      e.clock.advanceMs(5 * sec);
      expect(await e.commands.pauseTrack(track.id), TrackAction.paused);
      e.clock.advanceMs(60 * sec);
      // Lap while paused is refused.
      expect(await e.commands.lap(track.id), isNull);
      expect(await e.commands.resumeTrack(track.id), TrackAction.resumed);
      e.clock.advanceMs(5 * sec);

      final snapshot = await e.snapshot(track.id) as StopwatchSnapshot;
      expect(snapshot.state, RunState.running);
      expect(snapshot.elapsedMs, 20 * sec);
      expect(snapshot.lapCount, 1);
      expect(await e.eventTypes(track.id), [
        EventType.start,
        EventType.lap,
        EventType.pause,
        EventType.resume,
      ]);

      final sessionId = await e.commands.stopTrack(track.id);
      expect(sessionId, isNotNull);
      expect(await e.commands.getOpenSession(track.id), isNull);
      final closed = await e.history.getSession(sessionId!);
      expect(closed!.session.isOpen, isFalse);
      expect(closed.session.endedAt, e.clock.nowMs());
      expect(closed.summary.netMs, 20 * sec);
      expect(closed.events.last.type, EventType.stop);
    });

    test('commands in the wrong state do nothing', () async {
      final e = env();
      final set = await e.makeSet();
      final track = await e.makeTrack(set, const StopwatchConfig());

      expect(await e.commands.pauseTrack(track.id), TrackAction.none);
      expect(await e.commands.resumeTrack(track.id), TrackAction.none);
      expect(await e.commands.lap(track.id), isNull);
      expect(await e.commands.stopTrack(track.id), isNull);
      expect(await e.commands.startTrack('missing'), TrackAction.none);
      expect(await e.commands.toggleTrack('missing'), TrackAction.none);

      await e.commands.startTrack(track.id);
      // Starting a running track does not create a second session.
      expect(await e.commands.startTrack(track.id), TrackAction.none);
      expect(await e.eventTypes(track.id), [EventType.start]);
      expect((await e.commands.getOpenSessions()).length, 1);
    });

    test('start on a paused track resumes it', () async {
      final e = env();
      final track = await e.makeTrack(
        await e.makeSet(),
        const StopwatchConfig(),
      );
      await e.commands.startTrack(track.id);
      await e.commands.pauseTrack(track.id);
      expect(await e.commands.startTrack(track.id), TrackAction.resumed);
    });

    test('toggle cycles start -> pause -> resume', () async {
      final e = env();
      final track = await e.makeTrack(
        await e.makeSet(),
        const StopwatchConfig(),
      );
      expect(await e.commands.toggleTrack(track.id), TrackAction.started);
      e.clock.advanceMs(sec);
      expect(await e.commands.toggleTrack(track.id), TrackAction.paused);
      e.clock.advanceMs(sec);
      expect(await e.commands.toggleTrack(track.id), TrackAction.resumed);
    });

    test('a clock that jumps backwards cannot reorder the log', () async {
      final e = env();
      final track = await e.makeTrack(
        await e.makeSet(),
        const StopwatchConfig(),
      );
      await e.commands.startTrack(track.id);
      e.clock.advanceMs(10 * sec);
      await e.commands.pauseTrack(track.id);
      e.clock.advanceMs(-hour);
      await e.commands.resumeTrack(track.id);
      final open = await e.commands.getOpenSession(track.id);
      final times = [for (final ev in open!.events) ev.at];
      expect(times, [...times]..sort());
      expect(open.events.map((ev) => ev.seq), [0, 1, 2]);
      final snapshot = await e.snapshot(track.id);
      expect(snapshot!.elapsedMs, 10 * sec);
      expect(snapshot.state, RunState.running);
    });

    test(
      'exclusive stopwatch pauses other exclusive ones in the set',
      () async {
        final e = env();
        final set = await e.makeSet();
        final other = await e.makeSet('Other');
        const exclusive = StopwatchConfig(exclusive: true);
        final a = await e.makeTrack(set, exclusive, name: 'A');
        final b = await e.makeTrack(set, exclusive, name: 'B');
        final free = await e.makeTrack(
          set,
          const StopwatchConfig(),
          name: 'Free',
        );
        final elsewhere = await e.makeTrack(
          other,
          exclusive,
          name: 'Elsewhere',
        );

        await e.commands.startTrack(a.id);
        await e.commands.startTrack(free.id);
        await e.commands.startTrack(elsewhere.id);
        e.clock.advanceMs(5 * sec);
        await e.commands.startTrack(b.id);

        expect((await e.snapshot(a.id))!.state, RunState.paused);
        expect((await e.snapshot(b.id))!.state, RunState.running);
        // Non-exclusive tracks and other sets are untouched.
        expect((await e.snapshot(free.id))!.state, RunState.running);
        expect((await e.snapshot(elsewhere.id))!.state, RunState.running);

        // Resuming A pauses B again.
        e.clock.advanceMs(5 * sec);
        expect(await e.commands.toggleTrack(a.id), TrackAction.resumed);
        expect((await e.snapshot(a.id))!.state, RunState.running);
        expect((await e.snapshot(b.id))!.state, RunState.paused);
        expect((await e.snapshot(b.id))!.elapsedMs, 5 * sec);
      },
    );
  });

  group('countdown, interval and alarms', () {
    test(
      'start schedules the alarm, pause cancels, resume reschedules',
      () async {
        final e = env();
        final track = await e.makeTrack(
          await e.makeSet(),
          const CountdownConfig(durationMs: 10 * min),
        );
        final start = e.clock.nowMs();

        await e.commands.startTrack(track.id);
        expect(e.alarms.scheduled[track.id]!.single.at, start + 10 * min);
        expect(
          e.alarms.scheduled[track.id]!.single.kind,
          AlarmKind.countdownDone,
        );

        e.clock.advanceMs(4 * min);
        await e.commands.pauseTrack(track.id);
        expect(e.alarms.scheduled, isEmpty);
        expect(e.alarms.log.last, 'cancel:${track.id}');

        e.clock.advanceMs(20 * min);
        await e.commands.resumeTrack(track.id);
        expect(e.alarms.scheduled[track.id]!.single.at, start + 30 * min);

        await e.commands.stopTrack(track.id);
        expect(e.alarms.scheduled, isEmpty);
      },
    );

    test('toggle on a ringing countdown dismisses it', () async {
      final e = env();
      final track = await e.makeTrack(
        await e.makeSet(),
        const CountdownConfig(durationMs: 1 * min),
      );
      await e.commands.startTrack(track.id);
      e.clock.advanceMs(90 * sec);
      expect((await e.snapshot(track.id))!.state, RunState.ringing);
      expect(await e.commands.toggleTrack(track.id), TrackAction.stopped);
      expect(await e.commands.getOpenSession(track.id), isNull);
      final sessions = await e.history.getSessions(HistoryFilter.all);
      expect(sessions.single.summary.netMs, 90 * sec);
      expect(sessions.single.summary.completedRounds, 1);
    });

    test('interval schedules every boundary', () async {
      final e = env();
      final track = await e.makeTrack(
        await e.makeSet(),
        const IntervalConfig(workMs: 30 * sec, restMs: 10 * sec, rounds: 2),
      );
      final start = e.clock.nowMs();
      await e.commands.startTrack(track.id);
      expect(e.alarms.scheduled[track.id]!.map((a) => (a.at - start, a.kind)), [
        (30 * sec, AlarmKind.intervalRest),
        (40 * sec, AlarmKind.intervalWork),
        (70 * sec, AlarmKind.intervalDone),
      ]);
    });

    test('editing a running timer updates the session and its alarm', () async {
      final e = env();
      final track = await e.makeTrack(
        await e.makeSet(),
        const CountdownConfig(durationMs: 10 * min),
      );
      final start = e.clock.nowMs();
      await e.commands.startTrack(track.id);
      await e.tracks.updateTrack(
        track.copyWith(config: const CountdownConfig(durationMs: 3 * min)),
      );
      final open = await e.commands.getOpenSession(track.id);
      expect(open!.session.config, const CountdownConfig(durationMs: 3 * min));
      expect(e.alarms.scheduled[track.id]!.single.at, start + 3 * min);
    });

    test('rescheduleAllAlarms rebuilds everything from the log', () async {
      final e = env();
      final set = await e.makeSet();
      final timer = await e.makeTrack(
        set,
        const CountdownConfig(durationMs: 10 * min),
      );
      final pausedTimer = await e.makeTrack(
        set,
        const CountdownConfig(durationMs: 10 * min),
        name: 'paused',
      );
      final watch = await e.makeTrack(set, const StopwatchConfig());
      final start = e.clock.nowMs();
      await e.commands.startTrack(timer.id);
      await e.commands.startTrack(pausedTimer.id);
      await e.commands.pauseTrack(pausedTimer.id);
      await e.commands.startTrack(watch.id);

      // Simulate an app restart: the OS forgot everything.
      e.alarms.scheduled.clear();
      e.alarms.log.clear();
      e.clock.advanceMs(1 * min);
      await e.commands.rescheduleAllAlarms();

      expect(e.alarms.log.first, 'cancelAll');
      expect(e.alarms.scheduled.keys, [timer.id]);
      expect(e.alarms.scheduled[timer.id]!.single.at, start + 10 * min);
    });

    test('deleting or archiving a track cancels its alarms', () async {
      final e = env();
      final set = await e.makeSet();
      final a = await e.makeTrack(set, const CountdownConfig(durationMs: min));
      final b = await e.makeTrack(set, const CountdownConfig(durationMs: min));
      await e.commands.startTrack(a.id);
      await e.commands.startTrack(b.id);
      expect(e.alarms.scheduled.length, 2);

      // Archiving ends the running session (it must not keep running
      // invisibly), so restoring the track alone schedules nothing ...
      final stopped = await e.tracks.setArchived(a.id, archived: true);
      expect(stopped, isNotNull);
      expect(e.alarms.scheduled.keys, [b.id]);
      await e.tracks.setArchived(a.id, archived: false);
      expect(e.alarms.scheduled.keys, [b.id]);
      // ... and the complete undo (restore + reopen) brings the alarm back.
      expect(await e.commands.reopenSession(stopped!), isTrue);
      expect(e.alarms.scheduled.length, 2);

      await e.tracks.deleteTrack(b.id);
      expect(e.alarms.scheduled.keys, [a.id]);
      expect(await e.commands.getOpenSession(b.id), isNull);
    });
  });

  group('counter commands', () {
    test('first tap creates start + tick, further taps count up', () async {
      final e = env();
      final track = await e.makeTrack(await e.makeSet(), const CounterConfig());
      expect(await e.commands.toggleTrack(track.id), TrackAction.ticked);
      expect(await e.eventTypes(track.id), [EventType.start, EventType.tick]);
      expect(((await e.snapshot(track.id))! as CounterSnapshot).count, 1);

      e.clock.advanceMs(7 * sec);
      await e.commands.tick(track.id);
      e.clock.advanceMs(3 * sec);
      final snapshot = (await e.snapshot(track.id))! as CounterSnapshot;
      expect(snapshot.count, 2);
      expect(snapshot.ticks.last.lapMs, 7 * sec);
      expect(snapshot.currentLapMs, 3 * sec);
      expect(snapshot.totalMs, 10 * sec);
    });

    test('startTrack on a counter also counts 1', () async {
      final e = env();
      final track = await e.makeTrack(await e.makeSet(), const CounterConfig());
      expect(await e.commands.startTrack(track.id), TrackAction.started);
      expect(((await e.snapshot(track.id))! as CounterSnapshot).count, 1);
    });

    test('labels are stored per tick', () async {
      final e = env();
      final track = await e.makeTrack(
        await e.makeSet(),
        const CounterConfig(labels: ['Reiher', 'Hund']),
      );
      await e.commands.tick(track.id, label: 'Hund');
      await e.commands.tick(track.id, label: 'Reiher');
      await e.commands.tick(track.id, label: 'Hund');
      final snapshot = (await e.snapshot(track.id))! as CounterSnapshot;
      expect(snapshot.labelCounts, {'Reiher': 1, 'Hund': 2});
    });

    test('undo removes the last tick but never the start', () async {
      final e = env();
      final track = await e.makeTrack(await e.makeSet(), const CounterConfig());
      await e.commands.tick(track.id);
      await e.commands.tick(track.id, label: 'x');

      final removed = await e.commands.undoTick(track.id);
      expect(removed!.label, 'x');
      expect(((await e.snapshot(track.id))! as CounterSnapshot).count, 1);

      expect(await e.commands.undoTick(track.id), isNotNull);
      expect(await e.commands.undoTick(track.id), isNull);
      expect(await e.eventTypes(track.id), [EventType.start]);
      expect(((await e.snapshot(track.id))! as CounterSnapshot).count, 0);

      // The removed tick can be put back.
      await e.history.restoreEvent(removed);
      expect(((await e.snapshot(track.id))! as CounterSnapshot).count, 1);
    });

    test('tick is refused on other modes', () async {
      final e = env();
      final track = await e.makeTrack(
        await e.makeSet(),
        const StopwatchConfig(),
      );
      expect(await e.commands.tick(track.id), isNull);
      expect(await e.commands.undoTick(track.id), isNull);
    });
  });

  group('reminder commands', () {
    test('ack is logged, re-anchors and reschedules', () async {
      final e = env();
      final track = await e.makeTrack(
        await e.makeSet(),
        const ReminderConfig(intervalMs: 30 * min, nagEveryMs: 1 * min),
      );
      final start = e.clock.nowMs();
      await e.commands.startTrack(track.id);
      final plan = e.alarms.scheduled[track.id]!;
      expect(plan.first.at, start + 30 * min);
      expect(plan.first.kind, AlarmKind.reminderDue);
      expect(plan[1].kind, AlarmKind.reminderNag);
      expect(plan.length, AlarmSync.maxAlarmsPerTrack);

      e.clock.advanceMs(34 * min);
      expect((await e.snapshot(track.id))!.state, RunState.ringing);
      expect(await e.commands.toggleTrack(track.id), TrackAction.acknowledged);

      final snapshot = (await e.snapshot(track.id))! as ReminderSnapshot;
      expect(snapshot.state, RunState.running);
      expect(snapshot.acks.single.delayMs, 4 * min);
      expect(snapshot.dueAt, start + 64 * min);
      expect(e.alarms.scheduled[track.id]!.first.at, start + 64 * min);
    });

    test('ack without an open session does nothing', () async {
      final e = env();
      final track = await e.makeTrack(
        await e.makeSet(),
        const ReminderConfig(),
      );
      expect(await e.commands.ack(track.id), isNull);
    });
  });

  group('"+1′", "+10′" and "nächste Runde"', () {
    test('"+1′" only for a ringing timer; it is stored with its time and '
        'reschedules', () async {
      final e = env();
      final track = await e.makeTrack(
        await e.makeSet(),
        const CountdownConfig(durationMs: 10 * min),
      );
      final start = e.clock.nowMs();
      await e.commands.startTrack(track.id);
      // Not yet ringing: nothing to put off.
      expect(await e.commands.extend(track.id, min), isNull);

      e.clock.advanceMs(10 * min + 30 * sec);
      final event = await e.commands.extend(track.id, min);
      expect(event?.type, EventType.extend);
      expect(event?.extendMs, min);
      final s = (await e.snapshot(track.id))! as CountdownSnapshot;
      expect(s.state, RunState.running);
      expect(s.dueAt, start + 11 * min + 30 * sec);
      expect(e.alarms.scheduled[track.id]!.single.at, s.dueAt);
    });

    test('"+10′" for a due reminder, also when it is paused', () async {
      final e = env();
      final track = await e.makeTrack(
        await e.makeSet(),
        const ReminderConfig(intervalMs: 30 * min),
      );
      final start = e.clock.nowMs();
      await e.commands.startTrack(track.id);
      expect(await e.commands.extend(track.id, 10 * min), isNull);

      e.clock.advanceMs(31 * min);
      await e.commands.pauseTrack(track.id);
      expect(await e.commands.extend(track.id, 10 * min), isNotNull);
      final s = (await e.snapshot(track.id))! as ReminderSnapshot;
      expect(s.state, RunState.running);
      expect(s.dueAt, start + 41 * min);
      expect(e.alarms.scheduled[track.id]!.first.at, start + 41 * min);
    });

    test(
      '"nächste Runde" while an interval runs, not in its last round',
      () async {
        final e = env();
        final track = await e.makeTrack(
          await e.makeSet(),
          const IntervalConfig(workMs: 30 * sec, restMs: 10 * sec, rounds: 2),
        );
        expect(await e.commands.skipRound(track.id), isNull);
        await e.commands.startTrack(track.id);
        e.clock.advanceMs(5 * sec);
        expect((await e.commands.skipRound(track.id))?.type, EventType.skip);
        final s = (await e.snapshot(track.id))! as IntervalSnapshot;
        expect(s.round, 2);
        expect(s.phaseElapsedMs, 0);
        // The last round: no jump.
        expect(await e.commands.skipRound(track.id), isNull);
        // Wrong mode: nothing.
        final other = await e.makeTrack(
          await e.makeSet(),
          const StopwatchConfig(),
        );
        await e.commands.startTrack(other.id);
        expect(await e.commands.skipRound(other.id), isNull);
        expect(await e.commands.extend(other.id, min), isNull);
      },
    );
  });

  group('stop, reset, reopen', () {
    test('reset logs the run by default and can be undone', () async {
      final e = env();
      final track = await e.makeTrack(
        await e.makeSet(),
        const StopwatchConfig(),
      );
      await e.commands.startTrack(track.id);
      e.clock.advanceMs(5 * sec);
      final before = await e.commands.resetTrack(track.id);
      expect(before, isNotNull);
      expect(await e.commands.getOpenSession(track.id), isNull);
      expect((await e.history.getSessions(HistoryFilter.all)).length, 1);

      e.clock.advanceMs(5 * sec);
      expect(await e.commands.reopenSession(before!.session.id), isTrue);
      final open = await e.commands.getOpenSession(track.id);
      expect(open!.events.map((ev) => ev.type), [EventType.start]);
      expect((await e.snapshot(track.id))!.elapsedMs, 10 * sec);
      expect(await e.history.getSessions(HistoryFilter.all), isEmpty);
    });

    test('reopen is refused while another session is open', () async {
      final e = env();
      final track = await e.makeTrack(
        await e.makeSet(),
        const StopwatchConfig(),
      );
      await e.commands.startTrack(track.id);
      final first = await e.commands.stopTrack(track.id);
      await e.commands.startTrack(track.id);
      expect(await e.commands.reopenSession(first!), isFalse);
      expect(await e.commands.reopenSession('missing'), isFalse);
    });

    test(
      'reset with discard removes the session; restore brings it back',
      () async {
        final e = env();
        final track = await e.makeTrack(
          await e.makeSet(),
          const CountdownConfig(durationMs: 10 * min),
        );
        await e.commands.startTrack(track.id);
        e.clock.advanceMs(sec);
        final discarded = await e.commands.resetTrack(track.id, discard: true);
        expect(discarded!.events.length, 1);
        expect(await e.commands.getOpenSession(track.id), isNull);
        expect(
          await e.history.getSessions(
            HistoryFilter.all.copyWith(includeOpen: true),
          ),
          isEmpty,
        );
        expect(e.alarms.scheduled, isEmpty);

        await e.history.restoreSession(discarded);
        expect(await e.commands.getOpenSession(track.id), isNotNull);
        expect(e.alarms.scheduled[track.id], isNotNull);
      },
    );

    test('restart stops and starts a fresh session', () async {
      final e = env();
      final track = await e.makeTrack(
        await e.makeSet(),
        const CountdownConfig(durationMs: 1 * min),
      );
      await e.commands.startTrack(track.id);
      e.clock.advanceMs(2 * min);
      expect(await e.commands.restartTrack(track.id), TrackAction.started);
      expect((await e.snapshot(track.id))!.elapsedMs, 0);
      expect((await e.history.getSessions(HistoryFilter.all)).length, 1);
    });
  });

  group('startAll / pauseAll', () {
    test('act on the timers of the given set only', () async {
      final e = env();
      final set = await e.makeSet();
      final other = await e.makeSet('Other');
      final watch = await e.makeTrack(set, const StopwatchConfig());
      final timer = await e.makeTrack(
        set,
        const CountdownConfig(durationMs: 10 * min),
      );
      final interval = await e.makeTrack(set, const IntervalConfig());
      final reminder = await e.makeTrack(set, const ReminderConfig());
      final counter = await e.makeTrack(set, const CounterConfig());
      final protocol = await e.makeTrack(set, const ProtocolConfig());
      final archived = await e.makeTrack(
        set,
        const StopwatchConfig(),
        name: 'archived',
      );
      await e.tracks.setArchived(archived.id, archived: true);
      final foreign = await e.makeTrack(other, const StopwatchConfig());

      expect(await e.commands.startAll(set.id), 4);
      final open = await e.commands.getOpenSessions();
      expect(open.keys.toSet(), {watch.id, timer.id, interval.id, reminder.id});
      expect(open.containsKey(counter.id), isFalse);
      expect(open.containsKey(protocol.id), isFalse);
      expect(open.containsKey(foreign.id), isFalse);
      expect(e.alarms.scheduled.keys.toSet(), {
        timer.id,
        interval.id,
        reminder.id,
      });

      // Nothing left to start.
      expect(await e.commands.startAll(set.id), 0);

      e.clock.advanceMs(5 * sec);
      expect(await e.commands.pauseAll(set.id), 4);
      for (final id in [watch.id, timer.id, interval.id, reminder.id]) {
        expect((await e.snapshot(id))!.state, RunState.paused);
      }
      expect(e.alarms.scheduled, isEmpty);
      expect(await e.commands.pauseAll(set.id), 0);

      e.clock.advanceMs(5 * sec);
      expect(await e.commands.startAll(set.id), 4);
      expect((await e.snapshot(watch.id))!.elapsedMs, 5 * sec);
      expect((await e.snapshot(watch.id))!.state, RunState.running);
    });

    test('pauseAll leaves ringing timers and counters alone', () async {
      final e = env();
      final set = await e.makeSet();
      final timer = await e.makeTrack(
        set,
        const CountdownConfig(durationMs: 1 * min),
      );
      final counter = await e.makeTrack(set, const CounterConfig());
      await e.commands.startTrack(timer.id);
      await e.commands.tick(counter.id);
      e.clock.advanceMs(2 * min);
      expect(await e.commands.pauseAll(set.id), 0);
      expect((await e.snapshot(timer.id))!.state, RunState.ringing);
      expect((await e.snapshot(counter.id))!.state, RunState.running);
    });

    test('startAll skips mutually exclusive stopwatches', () async {
      final e = env();
      final set = await e.makeSet();
      const exclusive = StopwatchConfig(exclusive: true);
      final a = await e.makeTrack(set, exclusive, name: 'A');
      final b = await e.makeTrack(set, exclusive, name: 'B');
      final free = await e.makeTrack(set, const StopwatchConfig());
      expect(await e.commands.startAll(set.id), 1);
      expect((await e.commands.getOpenSessions()).keys, [free.id]);

      // A single exclusive stopwatch is started like any other.
      final solo = await e.makeSet('Solo');
      final only = await e.makeTrack(solo, exclusive);
      expect(await e.commands.startAll(solo.id), 1);
      expect((await e.snapshot(only.id))!.state, RunState.running);
      expect(await e.commands.getOpenSession(a.id), isNull);
      expect(await e.commands.getOpenSession(b.id), isNull);
    });
  });

  group('watchOpenSessions', () {
    test('emits on every change of the log', () async {
      final e = env();
      final track = await e.makeTrack(
        await e.makeSet(),
        const StopwatchConfig(),
      );
      final seen = <int>[];
      final sub = e.commands.watchOpenSessions().listen(
        (map) => seen.add(map[track.id]?.events.length ?? 0),
      );
      await pumpEventQueue();
      await e.commands.startTrack(track.id);
      await pumpEventQueue();
      await e.commands.lap(track.id);
      await pumpEventQueue();
      await e.commands.stopTrack(track.id);
      await pumpEventQueue();
      await sub.cancel();
      expect(seen.first, 0);
      expect(seen, containsAllInOrder([0, 1, 2, 0]));
    });
  });
}
