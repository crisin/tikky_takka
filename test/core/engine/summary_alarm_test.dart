import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';

import '../../support/events.dart';

void main() {
  group('summarizeSession', () {
    test('stopwatch: net, paused, laps', () {
      final log = EventLog()
        ..start(0)
        ..lap(10 * sec)
        ..pause(20 * sec)
        ..resume(50 * sec)
        ..lap(55 * sec)
        ..stop(60 * sec);
      final s = summarizeSession(
        config: const StopwatchConfig(),
        events: log.events,
        nowMs: hour,
      );
      expect(s.startAt, 0);
      expect(s.endAt, 60 * sec);
      expect(s.isOpen, isFalse);
      expect(s.netMs, 30 * sec);
      expect(s.pausedMs, 30 * sec);
      expect(s.wallMs, 60 * sec);
      expect(s.pauseCount, 1);
      expect(s.lapCount, 2);
      expect(s.count, 2);
    });

    test('open session uses now', () {
      final log = EventLog()..start(0);
      final s = summarizeSession(
        config: const StopwatchConfig(),
        events: log.events,
        nowMs: 5 * sec,
      );
      expect(s.isOpen, isTrue);
      expect(s.endAt, isNull);
      expect(s.netMs, 5 * sec);
    });

    test('empty session', () {
      final s = summarizeSession(
        config: const CounterConfig(),
        events: const [],
        nowMs: 5,
      );
      expect(s.startAt, isNull);
      expect(s.isOpen, isFalse);
      expect(s.netMs, 0);
      expect(s.count, 0);
    });

    test('count per mode', () {
      final counter = EventLog()
        ..start(0)
        ..tick(0)
        ..tick(1)
        ..tick(2)
        ..stop(3);
      expect(
        summarizeSession(
          config: const CounterConfig(),
          events: counter.events,
          nowMs: 9,
        ).count,
        3,
      );

      final reminder = EventLog()
        ..start(0)
        ..ack(10)
        ..ack(20)
        ..stop(30);
      expect(
        summarizeSession(
          config: const ReminderConfig(),
          events: reminder.events,
          nowMs: 99,
        ).count,
        2,
      );

      final protocol = EventLog()
        ..start(100)
        ..entry(100, person: 'a')
        // Back-dated before the start: still counted.
        ..entry(50, person: 'b')
        ..stop(200);
      expect(
        summarizeSession(
          config: const ProtocolConfig(),
          events: protocol.events,
          nowMs: 999,
        ).count,
        2,
      );
    });

    test('countdown and interval completed rounds', () {
      final run = EventLog()
        ..start(0)
        ..stop(12 * min);
      expect(
        summarizeSession(
          config: const CountdownConfig(durationMs: 10 * min),
          events: run.events,
          nowMs: hour,
        ).completedRounds,
        1,
      );
      expect(
        summarizeSession(
          config: const CountdownConfig(durationMs: 15 * min),
          events: run.events,
          nowMs: hour,
        ).completedRounds,
        0,
      );
      expect(
        summarizeSession(
          config: const CountdownConfig(durationMs: 5 * min, autoRestart: true),
          events: run.events,
          nowMs: hour,
        ).completedRounds,
        2,
      );

      const interval = IntervalConfig(
        workMs: 30 * sec,
        restMs: 10 * sec,
        rounds: 3,
      );
      int rounds(int stopAt) {
        final log = EventLog()
          ..start(0)
          ..stop(stopAt);
        return summarizeSession(
          config: interval,
          events: log.events,
          nowMs: hour,
        ).completedRounds;
      }

      expect(rounds(29 * sec), 0);
      expect(rounds(30 * sec), 1);
      expect(rounds(45 * sec), 1);
      expect(rounds(70 * sec), 2);
      expect(rounds(110 * sec), 3);
      expect(rounds(500 * sec), 3);
    });
  });

  group('annotateEvents', () {
    test('running count and lap durations', () {
      final log = EventLog()
        ..start(0)
        ..tick(0, label: 'a')
        ..tick(5 * sec)
        ..pause(6 * sec)
        ..resume(16 * sec)
        ..tick(20 * sec)
        ..stop(30 * sec);
      final rows = annotateEvents(log.events);
      expect(rows.map((r) => r.event.type), [
        EventType.start,
        EventType.tick,
        EventType.tick,
        EventType.pause,
        EventType.resume,
        EventType.tick,
        EventType.stop,
      ]);
      expect(rows.map((r) => r.runningCount), [
        null,
        1,
        2,
        null,
        null,
        3,
        null,
      ]);
      expect(rows.map((r) => r.lapMs), [
        null,
        0,
        5 * sec,
        null,
        null,
        // Net of the 10 s pause: 6 s + 4 s active, minus the 5 s of tick 2.
        5 * sec,
        null,
      ]);
      expect(rows.last.elapsedMs, 20 * sec);
    });

    test('laps, acks and entries are numbered independently', () {
      final log = EventLog()
        ..start(0)
        ..lap(10)
        ..ack(20)
        ..entry(25, person: 'a')
        ..lap(30)
        ..entry(35, person: 'b');
      final rows = annotateEvents(log.events);
      expect(rows.map((r) => r.runningCount), [null, 1, 1, 1, 2, 2]);
      expect(rows.map((r) => r.lapMs), [null, 10, 20, null, 20, null]);
    });

    test('empty input and events after the stop', () {
      expect(annotateEvents(const []), isEmpty);
      final log = EventLog()
        ..start(0)
        ..stop(10)
        ..tick(20);
      final rows = annotateEvents(log.events);
      expect(rows.length, 3);
      expect(rows.last.runningCount, isNull);
    });
  });

  group('planAlarms', () {
    List<PlannedAlarm> plan(
      TrackConfig config,
      EventLog log,
      int now, {
      int maxCount = 16,
    }) => planAlarms(
      trackId: 't1',
      config: config,
      events: log.events,
      nowMs: now,
      maxCount: maxCount,
    );

    test('nothing for idle, paused, stopped and non-alarm modes', () {
      const countdown = CountdownConfig(durationMs: 10 * min);
      expect(plan(countdown, EventLog(), 0), isEmpty);
      final paused = EventLog()
        ..start(0)
        ..pause(1 * min);
      expect(plan(countdown, paused, 2 * min), isEmpty);
      final stopped = EventLog()
        ..start(0)
        ..stop(1 * min);
      expect(plan(countdown, stopped, 2 * min), isEmpty);
      final running = EventLog()..start(0);
      expect(plan(const StopwatchConfig(), running, 5), isEmpty);
      expect(plan(const CounterConfig(), running, 5), isEmpty);
      expect(plan(const ProtocolConfig(), running, 5), isEmpty);
      expect(plan(countdown, running, 5, maxCount: 0), isEmpty);
    });

    test('countdown: one alarm at the due time', () {
      const config = CountdownConfig(durationMs: 10 * min);
      final log = EventLog()
        ..start(0)
        ..pause(2 * min)
        ..resume(5 * min);
      final alarms = plan(config, log, 6 * min);
      expect(alarms, [
        const PlannedAlarm(
          trackId: 't1',
          at: 13 * min,
          kind: AlarmKind.countdownDone,
          index: 0,
        ),
      ]);
      // Already ringing: nothing left to schedule.
      expect(plan(config, log, 14 * min), isEmpty);
    });

    test('countdown autoRestart: upcoming cycle ends', () {
      const config = CountdownConfig(durationMs: 5 * min, autoRestart: true);
      final log = EventLog()..start(0);
      final alarms = plan(config, log, 12 * min, maxCount: 3);
      expect(alarms.map((a) => a.at), [15 * min, 20 * min, 25 * min]);
      expect(alarms.map((a) => a.round), [3, 4, 5]);
      expect(alarms.every((a) => a.kind == AlarmKind.countdownCycle), isTrue);
      expect(alarms.map((a) => a.index), [0, 1, 2]);
    });

    test('interval: every phase boundary, ending with done', () {
      const config = IntervalConfig(
        workMs: 30 * sec,
        restMs: 10 * sec,
        rounds: 3,
      );
      final log = EventLog()..start(0);
      final alarms = plan(config, log, 5 * sec);
      expect(alarms.map((a) => (a.at, a.kind, a.round)), [
        (30 * sec, AlarmKind.intervalRest, 1),
        (40 * sec, AlarmKind.intervalWork, 2),
        (70 * sec, AlarmKind.intervalRest, 2),
        (80 * sec, AlarmKind.intervalWork, 3),
        (110 * sec, AlarmKind.intervalDone, 3),
      ]);

      final midway = plan(config, log, 75 * sec);
      expect(midway.map((a) => (a.at, a.kind)), [
        (80 * sec, AlarmKind.intervalWork),
        (110 * sec, AlarmKind.intervalDone),
      ]);
      expect(plan(config, log, 110 * sec), isEmpty);
    });

    test('interval with rest 0 announces each new round', () {
      const config = IntervalConfig(workMs: 20 * sec, restMs: 0, rounds: 3);
      final log = EventLog()..start(0);
      final alarms = plan(config, log, 1 * sec);
      expect(alarms.map((a) => (a.at, a.kind, a.round)), [
        (20 * sec, AlarmKind.intervalWork, 2),
        (40 * sec, AlarmKind.intervalWork, 3),
        (60 * sec, AlarmKind.intervalDone, 3),
      ]);
    });

    test('interval truncation always keeps the final done alarm', () {
      const config = IntervalConfig(
        workMs: 30 * sec,
        restMs: 10 * sec,
        rounds: 50,
      );
      final log = EventLog()..start(0);
      final alarms = plan(config, log, 1 * sec, maxCount: 4);
      expect(alarms.length, 4);
      expect(alarms.last.kind, AlarmKind.intervalDone);
      expect(alarms.last.at, config.totalMs);
      expect(alarms.first.at, 30 * sec);
    });

    test('reminder: due time followed by nags', () {
      const config = ReminderConfig(intervalMs: 30 * min, nagEveryMs: 1 * min);
      final log = EventLog()..start(0);
      final alarms = plan(config, log, 10 * min, maxCount: 4);
      expect(alarms.map((a) => (a.at, a.kind)), [
        (30 * min, AlarmKind.reminderDue),
        (31 * min, AlarmKind.reminderNag),
        (32 * min, AlarmKind.reminderNag),
        (33 * min, AlarmKind.reminderNag),
      ]);
    });

    test('reminder already due: only future nags', () {
      const config = ReminderConfig(intervalMs: 30 * min, nagEveryMs: 1 * min);
      final log = EventLog()..start(0);
      final alarms = plan(config, log, 32 * min + 30 * sec, maxCount: 3);
      expect(alarms.map((a) => a.at), [33 * min, 34 * min, 35 * min]);
      expect(alarms.every((a) => a.kind == AlarmKind.reminderNag), isTrue);
      expect(alarms.first.round, 3);
    });

    test('reminder after an ack counts from the ack', () {
      const config = ReminderConfig(intervalMs: 30 * min, nagEveryMs: 0);
      final log = EventLog()
        ..start(0)
        ..ack(40 * min);
      final alarms = plan(config, log, 41 * min);
      expect(alarms.single.at, 70 * min);
      expect(alarms.single.kind, AlarmKind.reminderDue);
    });

    test('reminder without nagging and already due schedules nothing', () {
      const config = ReminderConfig(intervalMs: 1 * min, nagEveryMs: 0);
      final log = EventLog()..start(0);
      expect(plan(config, log, 5 * min), isEmpty);
    });
  });

  group('history maths', () {
    HistorySession session(
      String id,
      String trackId,
      DateTime start,
      int netMs, {
      int sortIndex = 0,
    }) {
      final startMs = start.millisecondsSinceEpoch;
      final log = EventLog(sessionId: id, trackId: trackId)
        ..start(startMs)
        ..stop(startMs + netMs);
      final s = Session(
        id: id,
        trackId: trackId,
        config: const StopwatchConfig(),
        startedAt: startMs,
        endedAt: startMs + netMs,
      );
      return HistorySession(
        session: s,
        events: log.events,
        summary: summarizeSession(
          config: s.config,
          events: log.events,
          nowMs: startMs + netMs,
        ),
        track: Track(
          id: trackId,
          setId: 'set',
          name: trackId,
          config: const StopwatchConfig(),
          sortIndex: sortIndex,
        ),
      );
    }

    test('LocalDay basics', () {
      final day = LocalDay.fromMs(
        DateTime(2026, 11, 11, 23, 59).millisecondsSinceEpoch,
      );
      expect(day, const LocalDay(2026, 11, 11));
      expect(day.toString(), '2026-11-11');
      expect(day.startMs, DateTime(2026, 11, 11).millisecondsSinceEpoch);
      expect(day.endMs, DateTime(2026, 11, 12).millisecondsSinceEpoch);
      // 2026-11-11 is a Wednesday.
      expect(day.weekStart, const LocalDay(2026, 11, 9));
      expect(
        const LocalDay(2026, 11, 9).weekStart,
        const LocalDay(2026, 11, 9),
      );
      expect(
        const LocalDay(2026, 11, 15).weekStart,
        const LocalDay(2026, 11, 9),
      );
      expect(const LocalDay(2026, 3, 1).weekStart, const LocalDay(2026, 2, 23));
      expect(
        const LocalDay(2026, 1, 2).compareTo(const LocalDay(2025, 12, 31)),
        greaterThan(0),
      );
    });

    test('groups by start day with day totals, newest first', () {
      final sessions = [
        session('a', 'work', DateTime(2026, 11, 10, 9), 2 * hour),
        session('b', 'work', DateTime(2026, 11, 10, 14), 3 * hour),
        session('c', 'break', DateTime(2026, 11, 11, 8), 30 * min),
        // Runs over midnight: counts fully for its start day.
        session('d', 'work', DateTime(2026, 11, 11, 23), 4 * hour),
      ];
      final days = groupSessionsByDay(sessions);
      expect(days.map((d) => d.day), const [
        LocalDay(2026, 11, 11),
        LocalDay(2026, 11, 10),
      ]);
      expect(days[0].totalNetMs, 4 * hour + 30 * min);
      expect(days[0].sessions.map((s) => s.session.id), ['d', 'c']);
      expect(days[1].totalNetMs, 5 * hour);
      expect(groupSessionsByDay(const []), isEmpty);
    });

    test('daily and weekly sums per track', () {
      final sessions = [
        session('a', 'work', DateTime(2026, 11, 9, 9), 2 * hour, sortIndex: 1),
        session('b', 'work', DateTime(2026, 11, 9, 14), 3 * hour, sortIndex: 1),
        session('c', 'break', DateTime(2026, 11, 9, 12), 30 * min),
        session('d', 'work', DateTime(2026, 11, 11, 9), 4 * hour, sortIndex: 1),
        session('e', 'work', DateTime(2026, 11, 16, 9), 1 * hour, sortIndex: 1),
      ];
      final daily = sumPerTrackPerDay(sessions);
      expect(daily.map((s) => (s.period.toString(), s.trackId, s.netMs)), [
        ('2026-11-16', 'work', 1 * hour),
        ('2026-11-11', 'work', 4 * hour),
        ('2026-11-09', 'break', 30 * min),
        ('2026-11-09', 'work', 5 * hour),
      ]);
      expect(daily.last.sessionCount, 2);
      expect(daily.last.track!.name, 'work');

      final weekly = sumPerTrackPerWeek(sessions);
      expect(weekly.map((s) => (s.period.toString(), s.trackId, s.netMs)), [
        ('2026-11-16', 'work', 1 * hour),
        ('2026-11-09', 'break', 30 * min),
        ('2026-11-09', 'work', 9 * hour),
      ]);
      expect(weekly.last.sessionCount, 3);
    });
  });
}
