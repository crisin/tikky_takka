import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';

import '../../support/events.dart';

void main() {
  group('reminder', () {
    const config = ReminderConfig(intervalMs: 30 * min, nagEveryMs: 1 * min);

    test('idle', () {
      final s = deriveReminder(config, const [], 0);
      expect(s.state, RunState.idle);
      expect(s.remainingMs, 30 * min);
      expect(s.due, isFalse);
      expect(s.dueAt, isNull);
      expect(s.anchorAt, isNull);
    });

    test('first due time counts from the start', () {
      final log = EventLog()..start(1000);
      final s = deriveReminder(config, log.events, 1000 + 10 * min);
      expect(s.state, RunState.running);
      expect(s.due, isFalse);
      expect(s.remainingMs, 20 * min);
      expect(s.dueAt, 1000 + 30 * min);
      expect(s.anchorAt, 1000);
      expect(s.progress, closeTo(1 / 3, 1e-9));
      expect(s.nextNagAt, isNull);
    });

    test('rings and nags until acknowledged', () {
      final log = EventLog()..start(0);
      final atDue = deriveReminder(config, log.events, 30 * min);
      expect(atDue.state, RunState.ringing);
      expect(atDue.due, isTrue);
      expect(atDue.overdueMs, 0);
      expect(atDue.nagCount, 0);
      expect(atDue.nextNagAt, 31 * min);

      final later = deriveReminder(config, log.events, 30 * min + 150 * sec);
      expect(later.state, RunState.ringing);
      expect(later.overdueMs, 150 * sec);
      expect(later.nagCount, 2);
      expect(later.nextNagAt, 33 * min);
      expect(later.remainingMs, 0);
      expect(later.dueAt, 30 * min);
    });

    test('ack is logged with its delay and re-anchors the next due time', () {
      final log = EventLog()
        ..start(0)
        ..ack(34 * min);
      final s = deriveReminder(config, log.events, 40 * min);
      expect(s.state, RunState.running);
      expect(s.due, isFalse);
      expect(s.ackCount, 1);
      expect(s.acks.single.delayMs, 4 * min);
      expect(s.acks.single.waitedMs, 34 * min);
      expect(s.lastAckAt, 34 * min);
      expect(s.anchorAt, 34 * min);
      // Counts from the ack, not from the original due time.
      expect(s.dueAt, 64 * min);
      expect(s.remainingMs, 24 * min);

      final dueAgain = deriveReminder(config, log.events, 65 * min);
      expect(dueAgain.state, RunState.ringing);
      expect(dueAgain.overdueMs, 1 * min);
      expect(dueAgain.nagCount, 1);
    });

    test('early ack has no delay and still re-anchors', () {
      final log = EventLog()
        ..start(0)
        ..ack(10 * min)
        ..ack(45 * min);
      final s = deriveReminder(config, log.events, 50 * min);
      expect(s.acks[0].delayMs, 0);
      expect(s.acks[0].waitedMs, 10 * min);
      expect(s.acks[1].delayMs, 5 * min);
      expect(s.acks[1].index, 2);
      expect(s.dueAt, 75 * min);
    });

    test('pause freezes the countdown to due', () {
      final log = EventLog()
        ..start(0)
        ..pause(20 * min);
      final paused = deriveReminder(config, log.events, 3 * hour);
      expect(paused.state, RunState.paused);
      expect(paused.due, isFalse);
      expect(paused.remainingMs, 10 * min);
      expect(paused.dueAt, isNull);

      log.resume(3 * hour);
      final resumed = deriveReminder(config, log.events, 3 * hour + 1 * min);
      expect(resumed.remainingMs, 9 * min);
      expect(resumed.dueAt, 3 * hour + 10 * min);
    });

    test('nagEveryMs 0 disables nagging', () {
      const quiet = ReminderConfig(intervalMs: 1 * min, nagEveryMs: 0);
      final log = EventLog()..start(0);
      final s = deriveReminder(quiet, log.events, 10 * min);
      expect(s.due, isTrue);
      expect(s.nagCount, 0);
      expect(s.nextNagAt, isNull);
    });

    test('stopped reminder no longer rings', () {
      final log = EventLog()
        ..start(0)
        ..stop(45 * min);
      final s = deriveReminder(config, log.events, 5 * hour);
      expect(s.state, RunState.stopped);
      expect(s.due, isTrue);
      expect(s.overdueMs, 15 * min);
      expect(s.nextNagAt, isNull);
    });

    test('zero interval is due immediately', () {
      const zero = ReminderConfig(intervalMs: 0);
      final log = EventLog()..start(500);
      final s = deriveReminder(zero, log.events, 500);
      expect(s.due, isTrue);
      expect(s.state, RunState.ringing);
      expect(s.progress, 1);
    });
  });

  group('protocol', () {
    const config = ProtocolConfig();
    const lockouts = {'sub-a': 2 * hour, 'sub-b': 30 * min, 'sub-zero': 0};

    test('idle', () {
      final s = deriveProtocol(config, const [], 0);
      expect(s.state, RunState.idle);
      expect(s.entries, isEmpty);
      expect(s.persons, isEmpty);
      expect(s.lastEntry, isNull);
    });

    test('last entry per person and time since', () {
      final log = EventLog()
        ..start(0)
        ..entry(0, person: 'alex', substance: 'sub-a', amount: '1')
        ..entry(20 * min, person: 'kim', substance: 'sub-b')
        ..entry(60 * min, person: 'alex', substance: 'sub-b', amount: 'halb');
      final now = 60 * min + 102 * min;
      final s = deriveProtocol(config, log.events, now);
      expect(s.entryCount, 3);
      expect(s.state, RunState.running);
      // Most recent entry first.
      expect(s.persons.map((p) => p.personId), ['alex', 'kim']);
      final alex = s.persons[0];
      expect(alex.entryCount, 2);
      expect(alex.lastEntry.amount, 'halb');
      expect(alex.lastEntry.substanceId, 'sub-b');
      expect(alex.sinceMs, 102 * min);
      final kim = s.persons[1];
      expect(kim.sinceMs, now - 20 * min);
      // No lockout data supplied: nothing is ever invented.
      expect(alex.lockouts, isEmpty);
      expect(kim.lockouts, isEmpty);
    });

    test('user-set lockouts: remaining per substance, expired ones vanish', () {
      final log = EventLog()
        ..start(0)
        ..entry(0, person: 'alex', substance: 'sub-a')
        ..entry(60 * min, person: 'alex', substance: 'sub-b')
        ..entry(61 * min, person: 'alex', substance: 'sub-zero')
        ..entry(62 * min, person: 'alex', substance: 'sub-unknown');

      final early = deriveProtocol(
        config,
        log.events,
        70 * min,
        lockoutMsBySubstance: lockouts,
      ).persons.single;
      expect(early.lockouts.map((l) => l.substanceId), ['sub-a', 'sub-b']);
      expect(early.lockouts[0].remainingMs, 50 * min);
      expect(early.lockouts[0].untilAt, 2 * hour);
      expect(early.lockouts[1].remainingMs, 20 * min);
      expect(early.longestLockout!.substanceId, 'sub-a');
      // Last entry was 'sub-unknown', which has no lockout.
      expect(early.lastEntryLockout, isNull);

      final mid = deriveProtocol(
        config,
        log.events,
        100 * min,
        lockoutMsBySubstance: lockouts,
      ).persons.single;
      expect(mid.lockouts.map((l) => l.substanceId), ['sub-a']);
      expect(mid.lockouts.single.remainingMs, 20 * min);

      final late = deriveProtocol(
        config,
        log.events,
        2 * hour,
        lockoutMsBySubstance: lockouts,
      ).persons.single;
      expect(late.lockouts, isEmpty);
      expect(late.longestLockout, isNull);
    });

    test('a newer entry of the same substance restarts its lockout', () {
      final log = EventLog()
        ..start(0)
        ..entry(0, person: 'alex', substance: 'sub-b')
        ..entry(25 * min, person: 'alex', substance: 'sub-b');
      final p = deriveProtocol(
        config,
        log.events,
        40 * min,
        lockoutMsBySubstance: lockouts,
      ).persons.single;
      expect(p.lockouts.single.lastEntryAt, 25 * min);
      expect(p.lockouts.single.remainingMs, 15 * min);
      expect(p.lastEntryLockout!.remainingMs, 15 * min);
    });

    test('lockouts are per person', () {
      final log = EventLog()
        ..start(0)
        ..entry(0, person: 'alex', substance: 'sub-a')
        ..entry(10 * min, person: 'kim', substance: 'sub-b');
      final s = deriveProtocol(
        config,
        log.events,
        20 * min,
        lockoutMsBySubstance: lockouts,
      );
      final byId = {for (final p in s.persons) p.personId: p};
      expect(byId['alex']!.lockouts.single.substanceId, 'sub-a');
      expect(byId['kim']!.lockouts.single.substanceId, 'sub-b');
    });

    test('entries without a person form their own group', () {
      final log = EventLog()
        ..start(0)
        ..entry(0, substance: 'sub-a')
        ..entry(5 * min, person: 'alex');
      final s = deriveProtocol(config, log.events, 10 * min);
      expect(s.persons.map((p) => p.personId), ['alex', null]);
    });

    test('edited entry times are respected, even out of order', () {
      final log = EventLog()
        ..start(60 * min)
        ..entry(60 * min, person: 'alex', substance: 'sub-a')
        // Back-dated to before the session start by a later edit.
        ..entry(10 * min, person: 'kim', substance: 'sub-b')
        // Accidentally dated into the future.
        ..entry(5 * hour, person: 'sam');
      final s = deriveProtocol(
        config,
        log.events,
        90 * min,
        lockoutMsBySubstance: lockouts,
      );
      expect(s.entries.map((e) => e.personId), ['kim', 'alex', 'sam']);
      final byId = {for (final p in s.persons) p.personId: p};
      expect(byId['kim']!.sinceMs, 80 * min);
      expect(byId['kim']!.lockouts, isEmpty);
      expect(byId['alex']!.sinceMs, 30 * min);
      // Never negative.
      expect(byId['sam']!.sinceMs, 0);
    });

    test('stopped session measures against the stop time', () {
      final log = EventLog()
        ..start(0)
        ..entry(0, person: 'alex', substance: 'sub-a')
        ..stop(30 * min);
      final s = deriveProtocol(
        config,
        log.events,
        10 * hour,
        lockoutMsBySubstance: lockouts,
      );
      expect(s.state, RunState.stopped);
      expect(s.persons.single.sinceMs, 30 * min);
      expect(s.persons.single.lockouts.single.remainingMs, 90 * min);
    });
  });
}
