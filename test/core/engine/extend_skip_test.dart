import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';

import '../../support/events.dart';

/// "+1′" (timer), "+10′" (reminder) and "nächste Runde" (interval) are
/// events of their own; everything shown follows from them.
void main() {
  group('timer "+1′"', () {
    const config = CountdownConfig(durationMs: 10 * min);

    test('a ringing timer rings again one minute after the tap', () {
      // Rang at 10:00, "+1′" at 10:42.
      final log = EventLog()
        ..start(0)
        ..extend(10 * min + 42 * sec, min);
      final before = deriveCountdown(config, log.events, 11 * min);
      expect(before.state, RunState.running);
      expect(before.finished, isFalse);
      expect(before.remainingMs, 42 * sec);
      expect(before.dueAt, 11 * min + 42 * sec);

      final after = deriveCountdown(config, log.events, 12 * min);
      expect(after.state, RunState.ringing);
      expect(after.overtimeMs, 18 * sec);
      expect(after.lastFinishedAt, 11 * min + 42 * sec);
    });

    test('before the end it adds to the end; pauses do not count', () {
      final log = EventLog()
        ..start(0)
        ..extend(5 * min, min)
        ..pause(6 * min)
        ..resume(8 * min);
      final s = deriveCountdown(config, log.events, 9 * min);
      // 7 of 11 minutes have counted.
      expect(s.remainingMs, 4 * min);
      expect(s.dueAt, 13 * min);
      // The fill keeps counting against the set duration.
      expect(s.progress, closeTo(0.6, 0.001));
    });

    test('the alarm plan follows', () {
      final log = EventLog()
        ..start(0)
        ..extend(10 * min + 42 * sec, min);
      final plan = planAlarms(
        trackId: 't1',
        config: config,
        events: log.events,
        nowMs: 11 * min,
      );
      expect(plan.single.at, 11 * min + 42 * sec);
      expect(plan.single.kind, AlarmKind.countdownDone);
    });

    test('an event without time adds nothing', () {
      final log = EventLog()
        ..start(0)
        ..add(EventType.extend, 11 * min);
      final s = deriveCountdown(config, log.events, 12 * min);
      expect(s.finished, isTrue);
      expect(s.overtimeMs, 2 * min);
    });
  });

  group('reminder "+10′"', () {
    const config = ReminderConfig(intervalMs: 45 * min, nagEveryMs: 5 * min);

    test('a due reminder is due again ten minutes after the tap; the next '
        'ack starts the rhythm again', () {
      final log = EventLog()
        ..start(0)
        ..extend(48 * min, 10 * min);
      final put = deriveReminder(config, log.events, 50 * min);
      expect(put.due, isFalse);
      expect(put.state, RunState.running);
      expect(put.remainingMs, 8 * min);
      expect(put.dueAt, 58 * min);
      expect(put.nagCount, 0);

      final again = deriveReminder(config, log.events, 64 * min);
      expect(again.due, isTrue);
      expect(again.overdueMs, 6 * min);
      expect(again.nagCount, 1);

      log.ack(64 * min);
      final acked = deriveReminder(config, log.events, 70 * min);
      expect(acked.due, isFalse);
      expect(acked.dueAt, 109 * min);
      expect(acked.acks.single.delayMs, 19 * min);
    });

    test('the alarm plan follows', () {
      final log = EventLog()
        ..start(0)
        ..extend(48 * min, 10 * min);
      final plan = planAlarms(
        trackId: 't1',
        config: config,
        events: log.events,
        nowMs: 50 * min,
        maxCount: 3,
      );
      expect(plan.first.at, 58 * min);
      expect(plan.first.kind, AlarmKind.reminderDue);
      expect(plan[1].at, 63 * min);
    });
  });

  group('interval "nächste Runde"', () {
    // 3 x 30 s work / 10 s rest = 110 s.
    const config = IntervalConfig(
      workMs: 30 * sec,
      restMs: 10 * sec,
      rounds: 3,
    );

    test('jumps to the start of the next round, from work or rest', () {
      final log = EventLog()
        ..start(0)
        ..skip(12 * sec);
      final s = deriveInterval(config, log.events, 15 * sec);
      expect(s.round, 2);
      expect(s.phase, IntervalPhase.work);
      expect(s.phaseElapsedMs, 3 * sec);
      expect(s.canSkip, isTrue);
      expect(s.finishAt, 15 * sec + 67 * sec);

      // From the rest of round 2 to round 3: the last one.
      log.skip(50 * sec);
      final last = deriveInterval(config, log.events, 51 * sec);
      expect(last.round, 3);
      expect(last.phaseElapsedMs, sec);
      expect(last.canSkip, isFalse);
    });

    test('the alarm plan follows', () {
      final log = EventLog()
        ..start(0)
        ..skip(12 * sec);
      final plan = planAlarms(
        trackId: 't1',
        config: config,
        events: log.events,
        nowMs: 15 * sec,
      );
      // Round 2 ends its work 30 s after the jump.
      expect(plan.first.at, 42 * sec);
      expect(plan.first.kind, AlarmKind.intervalRest);
      expect(plan.last.kind, AlarmKind.intervalDone);
      expect(plan.last.at, 82 * sec);
    });

    test('a jump in the last round ends the programme at that moment', () {
      final log = EventLog()
        ..start(0)
        ..skip(85 * sec);
      final s = deriveInterval(config, log.events, 90 * sec);
      expect(s.finished, isTrue);
      expect(s.state, RunState.ringing);
      expect(s.finishAt, 85 * sec);
    });
  });
}
