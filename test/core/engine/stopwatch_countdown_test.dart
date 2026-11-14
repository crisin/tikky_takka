import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';

import '../../support/events.dart';

void main() {
  group('stopwatch', () {
    const config = StopwatchConfig();

    test('idle', () {
      final s = deriveStopwatch(config, const [], 5000);
      expect(s.state, RunState.idle);
      expect(s.elapsedMs, 0);
      expect(s.laps, isEmpty);
      expect(s.currentLapMs, 0);
      expect(s.startedAt, isNull);
      expect(s.isOpen, isFalse);
      expect(s.isTicking, isFalse);
    });

    test('counts up while running', () {
      final log = EventLog()..start(1000);
      expect(deriveStopwatch(config, log.events, 1000).elapsedMs, 0);
      expect(deriveStopwatch(config, log.events, 61000).elapsedMs, 60000);
      final s = deriveStopwatch(config, log.events, 61000);
      expect(s.state, RunState.running);
      expect(s.isTicking, isTrue);
      expect(s.startedAt, 1000);
    });

    test('pause / resume maths', () {
      final log = EventLog()
        ..start(0)
        ..pause(10 * sec)
        ..resume(25 * sec);
      final paused = deriveStopwatch(config, log.events.take(2), 20 * sec);
      expect(paused.state, RunState.paused);
      expect(paused.elapsedMs, 10 * sec);
      expect(paused.pausedMs, 10 * sec);
      expect(paused.totalMs, 20 * sec);
      expect(paused.isTicking, isFalse);

      final resumed = deriveStopwatch(config, log.events, 30 * sec);
      expect(resumed.state, RunState.running);
      expect(resumed.elapsedMs, 15 * sec);
      expect(resumed.pausedMs, 15 * sec);
    });

    test('laps are net of pauses', () {
      final log = EventLog()
        ..start(0)
        ..lap(10 * sec, label: 'warm-up')
        ..pause(15 * sec)
        ..resume(45 * sec)
        ..lap(50 * sec);
      final s = deriveStopwatch(config, log.events, 53 * sec);
      expect(s.lapCount, 2);
      expect(s.laps[0].index, 1);
      expect(s.laps[0].durationMs, 10 * sec);
      expect(s.laps[0].totalMs, 10 * sec);
      expect(s.laps[0].label, 'warm-up');
      expect(s.laps[1].durationMs, 10 * sec);
      expect(s.laps[1].totalMs, 20 * sec);
      expect(s.currentLapMs, 3 * sec);
      expect(s.currentLapNumber, 3);
      expect(s.elapsedMs, 23 * sec);
    });

    test('stopped session is frozen', () {
      final log = EventLog()
        ..start(0)
        ..lap(4 * sec)
        ..stop(9 * sec);
      final s = deriveStopwatch(config, log.events, hour);
      expect(s.state, RunState.stopped);
      expect(s.elapsedMs, 9 * sec);
      expect(s.currentLapMs, 5 * sec);
      expect(s.stoppedAt, 9 * sec);
      expect(s.isOpen, isFalse);
    });

    test('deriveSnapshot dispatches on the config type', () {
      final log = EventLog()..start(0);
      final s = deriveSnapshot(config: config, events: log.events, nowMs: 5);
      expect(s, isA<StopwatchSnapshot>());
      expect(s.mode, TrackMode.stopwatch);
    });
  });

  group('countdown', () {
    const config = CountdownConfig(durationMs: 10 * min);

    test('idle shows the full duration', () {
      final s = deriveCountdown(config, const [], 0);
      expect(s.state, RunState.idle);
      expect(s.remainingMs, 10 * min);
      expect(s.progress, 0);
      expect(s.finished, isFalse);
      expect(s.dueAt, isNull);
    });

    test('counts down and knows when it is due', () {
      final log = EventLog()..start(1000);
      final s = deriveCountdown(config, log.events, 1000 + 4 * min);
      expect(s.state, RunState.running);
      expect(s.remainingMs, 6 * min);
      expect(s.dueAt, 1000 + 10 * min);
      expect(s.progress, closeTo(0.4, 1e-9));
      expect(s.overtimeMs, 0);
    });

    test('pause shifts the due time', () {
      final log = EventLog()
        ..start(0)
        ..pause(2 * min);
      final paused = deriveCountdown(config, log.events, 30 * min);
      expect(paused.state, RunState.paused);
      expect(paused.remainingMs, 8 * min);
      expect(paused.dueAt, isNull);
      expect(paused.finished, isFalse);

      log.resume(30 * min);
      final resumed = deriveCountdown(config, log.events, 31 * min);
      expect(resumed.state, RunState.running);
      expect(resumed.remainingMs, 7 * min);
      expect(resumed.dueAt, 38 * min);
    });

    test('rings from the due time until dismissed', () {
      final log = EventLog()..start(0);
      final justBefore = deriveCountdown(config, log.events, 10 * min - 1);
      expect(justBefore.state, RunState.running);
      expect(justBefore.remainingMs, 1);

      final atDue = deriveCountdown(config, log.events, 10 * min);
      expect(atDue.state, RunState.ringing);
      expect(atDue.finished, isTrue);
      expect(atDue.remainingMs, 0);
      expect(atDue.progress, 1);
      expect(atDue.lastFinishedAt, 10 * min);

      final later = deriveCountdown(config, log.events, 13 * min);
      expect(later.state, RunState.ringing);
      expect(later.overtimeMs, 3 * min);
      expect(later.completedCycles, 1);
      expect(later.isTicking, isTrue);

      log.stop(14 * min);
      final dismissed = deriveCountdown(config, log.events, hour);
      expect(dismissed.state, RunState.stopped);
      expect(dismissed.finished, isTrue);
      expect(dismissed.overtimeMs, 4 * min);
    });

    test('finish time accounts for pauses', () {
      final log = EventLog()
        ..start(0)
        ..pause(4 * min)
        ..resume(9 * min);
      final s = deriveCountdown(config, log.events, 20 * min);
      expect(s.state, RunState.ringing);
      expect(s.lastFinishedAt, 15 * min);
      expect(s.overtimeMs, 5 * min);
    });

    test('stopped early is not finished', () {
      final log = EventLog()
        ..start(0)
        ..stop(3 * min);
      final s = deriveCountdown(config, log.events, hour);
      expect(s.state, RunState.stopped);
      expect(s.finished, isFalse);
      expect(s.remainingMs, 7 * min);
    });

    group('autoRestart', () {
      const auto = CountdownConfig(durationMs: 5 * min, autoRestart: true);

      test('cycles instead of ringing', () {
        final log = EventLog()..start(0);
        final first = deriveCountdown(auto, log.events, 2 * min);
        expect(first.completedCycles, 0);
        expect(first.remainingMs, 3 * min);
        expect(first.lastFinishedAt, isNull);

        final third = deriveCountdown(auto, log.events, 12 * min);
        expect(third.state, RunState.running);
        expect(third.finished, isFalse);
        expect(third.completedCycles, 2);
        expect(third.remainingMs, 3 * min);
        expect(third.dueAt, 15 * min);
        expect(third.lastFinishedAt, 10 * min);
        expect(third.progress, closeTo(0.4, 1e-9));
      });

      test('exactly on a boundary starts the next cycle', () {
        final log = EventLog()..start(0);
        final s = deriveCountdown(auto, log.events, 10 * min);
        expect(s.completedCycles, 2);
        expect(s.remainingMs, 5 * min);
        expect(s.state, RunState.running);
      });

      test('pauses shift cycles', () {
        final log = EventLog()
          ..start(0)
          ..pause(4 * min)
          ..resume(14 * min);
        final s = deriveCountdown(auto, log.events, 16 * min);
        expect(s.completedCycles, 1);
        expect(s.lastFinishedAt, 15 * min);
        expect(s.remainingMs, 4 * min);
      });
    });

    test('zero or negative duration finishes immediately, even with auto', () {
      for (final d in [0, -5]) {
        final c = CountdownConfig(durationMs: d, autoRestart: true);
        final log = EventLog()..start(100);
        final s = deriveCountdown(c, log.events, 200);
        expect(s.state, RunState.ringing);
        expect(s.finished, isTrue);
        expect(s.remainingMs, 0);
        expect(s.autoRestart, isFalse);
        expect(s.progress, 1);
      }
    });
  });
}
