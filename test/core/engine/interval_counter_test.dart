import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';

import '../../support/events.dart';

void main() {
  group('interval', () {
    const config = IntervalConfig(
      workMs: 30 * sec,
      restMs: 10 * sec,
      rounds: 3,
    );

    test('total duration has no rest after the last round', () {
      expect(config.totalMs, 3 * 30 * sec + 2 * 10 * sec);
      expect(
        const IntervalConfig(workMs: 20 * sec, restMs: 0, rounds: 4).totalMs,
        80 * sec,
      );
    });

    test('idle', () {
      final s = deriveInterval(config, const [], 0);
      expect(s.state, RunState.idle);
      expect(s.round, 1);
      expect(s.phase, IntervalPhase.work);
      expect(s.phaseRemainingMs, 30 * sec);
      expect(s.progress, 0);
      expect(s.totalDurationMs, 110 * sec);
    });

    test('derives round and phase', () {
      final log = EventLog()..start(0);
      IntervalSnapshot at(int ms) => deriveInterval(config, log.events, ms);

      var s = at(0);
      expect(
        (s.round, s.phase, s.phaseRemainingMs),
        (1, IntervalPhase.work, 30 * sec),
      );

      s = at(29 * sec);
      expect(
        (s.round, s.phase, s.phaseRemainingMs),
        (1, IntervalPhase.work, 1 * sec),
      );
      expect(s.nextBoundaryAt, 30 * sec);

      s = at(30 * sec);
      expect(
        (s.round, s.phase, s.phaseRemainingMs),
        (1, IntervalPhase.rest, 10 * sec),
      );

      s = at(45 * sec);
      expect(
        (s.round, s.phase, s.phaseElapsedMs),
        (2, IntervalPhase.work, 5 * sec),
      );
      expect(s.phaseProgress, closeTo(5 / 30, 1e-9));
      expect(s.finishAt, 110 * sec);

      s = at(75 * sec);
      expect((s.round, s.phase), (2, IntervalPhase.rest));

      s = at(80 * sec);
      expect((s.round, s.phase), (3, IntervalPhase.work));
      expect(s.remainingTotalMs, 30 * sec);
      expect(s.state, RunState.running);
    });

    test('finishes after the last work phase and rings', () {
      final log = EventLog()..start(0);
      final s = deriveInterval(config, log.events, 110 * sec);
      expect(s.finished, isTrue);
      expect(s.phase, IntervalPhase.done);
      expect(s.round, 3);
      expect(s.state, RunState.ringing);
      expect(s.progress, 1);
      expect(s.phaseRemainingMs, 0);
      expect(s.finishAt, 110 * sec);
      expect(s.nextBoundaryAt, isNull);

      log.stop(120 * sec);
      expect(deriveInterval(config, log.events, hour).state, RunState.stopped);
    });

    test('rest 0: rounds follow each other directly', () {
      const noRest = IntervalConfig(workMs: 20 * sec, restMs: 0, rounds: 3);
      final log = EventLog()..start(0);
      IntervalSnapshot at(int ms) => deriveInterval(noRest, log.events, ms);

      expect((at(19 * sec).round, at(19 * sec).phase), (1, IntervalPhase.work));
      expect((at(20 * sec).round, at(20 * sec).phase), (2, IntervalPhase.work));
      expect((at(59 * sec).round, at(59 * sec).phase), (3, IntervalPhase.work));
      expect(at(59 * sec).phaseRemainingMs, 1 * sec);
      expect(at(60 * sec).finished, isTrue);
      // No snapshot between the rounds ever reports a rest phase.
      for (var ms = 0; ms < 60 * sec; ms += 500) {
        expect(at(ms).phase, IntervalPhase.work);
      }
    });

    test('pauses stretch the programme', () {
      final log = EventLog()
        ..start(0)
        ..pause(35 * sec)
        ..resume(100 * sec);
      final paused = deriveInterval(config, log.events.take(2), 60 * sec);
      expect(paused.state, RunState.paused);
      expect((paused.round, paused.phase), (1, IntervalPhase.rest));
      expect(paused.phaseRemainingMs, 5 * sec);
      expect(paused.nextBoundaryAt, isNull);
      expect(paused.finishAt, isNull);

      final s = deriveInterval(config, log.events, 106 * sec);
      expect((s.round, s.phase), (2, IntervalPhase.work));
      expect(s.phaseElapsedMs, 1 * sec);
      expect(s.finishAt, 175 * sec);
    });

    test('single round', () {
      const one = IntervalConfig(workMs: 5 * sec, restMs: 60 * sec, rounds: 1);
      final log = EventLog()..start(0);
      expect(deriveInterval(one, log.events, 4 * sec).finished, isFalse);
      expect(deriveInterval(one, log.events, 5 * sec).finished, isTrue);
    });

    test('degenerate configs do not crash', () {
      final log = EventLog()..start(0);
      const zero = IntervalConfig(workMs: 0, restMs: 0, rounds: 5);
      expect(deriveInterval(zero, log.events, 10).finished, isTrue);
      expect(deriveInterval(zero, const [], 10).state, RunState.idle);

      const negative = IntervalConfig(workMs: -1, restMs: -1, rounds: 0);
      final s = deriveInterval(negative, log.events, 10);
      expect(s.finished, isTrue);
      expect(s.rounds, 1);

      const restOnly = IntervalConfig(workMs: 0, restMs: 10 * sec, rounds: 3);
      final r = deriveInterval(restOnly, log.events, 15 * sec);
      expect(r.finished, isFalse);
      expect((r.round, r.phase), (2, IntervalPhase.rest));
      expect(deriveInterval(restOnly, log.events, 20 * sec).finished, isTrue);
    });
  });

  group('counter', () {
    const config = CounterConfig();

    test('idle', () {
      final s = deriveCounter(config, const [], 0);
      expect(s.state, RunState.idle);
      expect(s.count, 0);
      expect(s.canUndo, isFalse);
      expect(s.lastTickAt, isNull);
    });

    test('first tap is start + tick => count 1', () {
      final log = EventLog()
        ..start(1000)
        ..tick(1000);
      final s = deriveCounter(config, log.events, 4000);
      expect(s.count, 1);
      expect(s.ticks.single.lapMs, 0);
      expect(s.currentLapMs, 3000);
      expect(s.totalMs, 3000);
      expect(s.canUndo, isTrue);
      expect(s.state, RunState.running);
    });

    test('each tick increments and starts a new lap', () {
      final log = EventLog()
        ..start(0)
        ..tick(0)
        ..tick(7 * sec)
        ..tick(19 * sec);
      final s = deriveCounter(config, log.events, 25 * sec);
      expect(s.count, 3);
      expect(s.ticks.map((t) => t.index), [1, 2, 3]);
      expect(s.ticks.map((t) => t.lapMs), [0, 7 * sec, 12 * sec]);
      expect(s.currentLapMs, 6 * sec);
      expect(s.elapsedMs, 25 * sec);
      expect(s.lastTickAt, 19 * sec);
      expect(s.unlabeledCount, 3);
    });

    test('undo = the last tick event is gone', () {
      final log = EventLog()
        ..start(0)
        ..tick(0)
        ..tick(7 * sec)
        ..tick(19 * sec);
      final undone = log.events.sublist(0, 3);
      final s = deriveCounter(config, undone, 25 * sec);
      expect(s.count, 2);
      expect(s.currentLapMs, 18 * sec);

      // Undoing every tick keeps the session (the start is never removed).
      final onlyStart = log.events.sublist(0, 1);
      final empty = deriveCounter(config, onlyStart, 25 * sec);
      expect(empty.count, 0);
      expect(empty.state, RunState.running);
      expect(empty.canUndo, isFalse);
      expect(empty.currentLapMs, 25 * sec);
    });

    test('labels: per-label counts in configured order', () {
      const labelled = CounterConfig(
        labels: ['Eichhörnchen', 'Reiher', 'Hund'],
      );
      final log = EventLog()
        ..start(0)
        ..tick(0, label: 'Hund')
        ..tick(1 * sec, label: 'Eichhörnchen')
        ..tick(2 * sec, label: 'Hund')
        ..tick(3 * sec, label: 'Katze')
        ..tick(4 * sec);
      final s = deriveCounter(labelled, log.events, 5 * sec);
      expect(s.count, 5);
      expect(s.labelCounts.keys.toList(), [
        'Eichhörnchen',
        'Reiher',
        'Hund',
        'Katze',
      ]);
      expect(s.labelCounts, {
        'Eichhörnchen': 1,
        'Reiher': 0,
        'Hund': 2,
        'Katze': 1,
      });
      expect(s.unlabeledCount, 1);
      expect(s.ticks[3].label, 'Katze');
    });

    test('laps are net of pauses; stop freezes', () {
      final log = EventLog()
        ..start(0)
        ..tick(0)
        ..pause(5 * sec)
        ..resume(65 * sec)
        ..tick(70 * sec)
        ..stop(80 * sec);
      final s = deriveCounter(config, log.events, hour);
      expect(s.ticks[1].lapMs, 10 * sec);
      expect(s.currentLapMs, 10 * sec);
      expect(s.state, RunState.stopped);
      expect(s.canUndo, isFalse);
      expect(s.totalMs, 80 * sec);
      expect(s.elapsedMs, 20 * sec);
    });
  });
}
