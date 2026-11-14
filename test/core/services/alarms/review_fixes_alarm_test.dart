import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show NotificationVisibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/clock.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';
import 'package:tikky_takka/core/services/alarms/alarms.dart';
import 'package:tikky_takka/core/services/alarms/plugin_notification_backend.dart'
    show androidDetailsFor;
import 'package:tikky_takka/l10n/strings.dart';

import '../../../support/events.dart';
import 'fake_notification_backend.dart';

Track _track(String id, TrackConfig config) =>
    Track(id: id, setId: 'set', name: 'Geheim', config: config);

List<PlannedAlarm> _alarms(
  Track track, {
  required int nowMs,
  int maxCount = 16,
}) => planAlarms(
  trackId: track.id,
  config: track.config,
  events: (EventLog(trackId: track.id)..start(0)).events,
  nowMs: nowMs,
  maxCount: maxCount,
);

/// Regression tests: a plan that is cut at the cap announces it in its
/// last notification, and the app lock makes notifications private.
void main() {
  final drink = _track(
    'drink',
    const ReminderConfig(intervalMs: 30 * min, nagEveryMs: min),
  );
  final loop = _track(
    'loop',
    const CountdownConfig(durationMs: min, autoRestart: true),
  );
  final timer = _track('timer', const CountdownConfig(durationMs: 10 * min));

  group('planAlarms marks where a capped plan ends', () {
    test('endless series (cycles, nags): the last alarm', () {
      for (final track in [drink, loop]) {
        final plan = _alarms(track, nowMs: sec);
        expect(plan, hasLength(16));
        expect(plan.map((a) => a.planEndsHere), [
          for (var i = 0; i < 16; i++) i == 15,
        ], reason: track.id);
      }
      expect(_alarms(loop, nowMs: sec, maxCount: 3).last.planEndsHere, isTrue);
    });

    test('complete plans carry no mark', () {
      expect(_alarms(timer, nowMs: sec).single.planEndsHere, isFalse);
      final once = _track(
        'once',
        const ReminderConfig(intervalMs: 30 * min, nagEveryMs: 0),
      );
      expect(_alarms(once, nowMs: sec).single.planEndsHere, isFalse);
      final short = _track(
        'short',
        const IntervalConfig(workMs: 30 * sec, restMs: 10 * sec, rounds: 3),
      );
      final plan = _alarms(short, nowMs: sec);
      expect(plan.last.kind, AlarmKind.intervalDone);
      expect(plan.any((a) => a.planEndsHere), isFalse);
    });

    test('a long interval: the last phase alarm before the gap; the final '
        '"done" is kept and unmarked', () {
      final long = _track(
        'long',
        const IntervalConfig(workMs: 30 * sec, restMs: 10 * sec, rounds: 40),
      );
      final plan = _alarms(long, nowMs: sec);
      expect(plan, hasLength(16));
      expect(plan.last.kind, AlarmKind.intervalDone);
      expect(plan.last.planEndsHere, isFalse);
      expect(plan.map((a) => a.planEndsHere), [
        for (var i = 0; i < 16; i++) i == 14,
      ]);

      // An interval that fits exactly is not "cut".
      final fits = _track(
        'fits',
        const IntervalConfig(workMs: 30 * sec, restMs: 0, rounds: 16),
      );
      final exact = _alarms(fits, nowMs: sec);
      expect(exact, hasLength(16));
      expect(exact.any((a) => a.planEndsHere), isFalse);
    });
  });

  group('buildNotificationPlan', () {
    test('the last notification of a capped plan asks to open the app', () {
      final specs = buildNotificationPlan(
        track: loop,
        alarms: _alarms(loop, nowMs: sec),
        nowMs: sec,
      );
      expect(specs, hasLength(16));
      expect(specs.last.lastOfCutPlan, isTrue);
      expect(specs.last.body, AlarmStrings.openAppForMore);
      expect(specs.last.body, contains('Tikky Takka öffnen'));
      // The headline still says what happened.
      expect(specs.last.title, Strings.notifCountdownCycle('Geheim', 16));
      expect(specs.take(15).any((s) => s.lastOfCutPlan), isFalse);
      expect(specs[14].body, AlarmStrings.nextCycleRunning);
    });

    test('a plan cut by the OS budget says so on its last slot', () {
      final specs = buildNotificationPlan(
        track: drink,
        alarms: _alarms(drink, nowMs: sec),
        nowMs: sec,
        maxCount: 4,
      );
      expect(specs, hasLength(4));
      expect(specs.map((s) => s.lastOfCutPlan), [false, false, false, true]);
      expect(specs.last.body, AlarmStrings.openAppForMore);

      final long = _track(
        'long',
        const IntervalConfig(workMs: 30 * sec, restMs: 10 * sec, rounds: 3),
      );
      final interval = buildNotificationPlan(
        track: long,
        alarms: _alarms(long, nowMs: sec),
        nowMs: sec,
        maxCount: 3,
      );
      expect(interval.last.kind, AlarmKind.intervalDone);
      expect(interval.map((s) => s.lastOfCutPlan), [false, true, false]);
    });

    test('a complete plan has no notice', () {
      final specs = buildNotificationPlan(
        track: timer,
        alarms: _alarms(timer, nowMs: sec),
        nowMs: sec,
      );
      expect(specs.single.lastOfCutPlan, isFalse);
      expect(specs.single.body, isNot(AlarmStrings.openAppForMore));
    });
  });

  group('lock screen privacy', () {
    test('Android visibility follows hideOnLockScreen', () {
      NotificationSpec spec({required bool hidden}) => buildNotificationPlan(
        track: timer,
        alarms: _alarms(timer, nowMs: sec),
        nowMs: sec,
        hideOnLockScreen: hidden,
      ).single;

      expect(
        androidDetailsFor(spec(hidden: false)).visibility,
        NotificationVisibility.public,
      );
      expect(
        androidDetailsFor(spec(hidden: true)).visibility,
        NotificationVisibility.private,
      );
    });

    test('the service schedules private notifications while the app lock '
        'is on and re-applies pending ones when it changes', () async {
      final backend = FakeNotificationBackend();
      final service = LocalNotificationsAlarmService(
        backend: backend,
        clock: FakeClock(1000),
        requestPermissionOnFirstSchedule: false,
      );
      await service.scheduleForTrack(timer, _alarms(timer, nowMs: 1000));
      expect(backend.pending.values.single.hideOnLockScreen, isFalse);

      await service.setContentHidden(true);
      expect(backend.pending.values.single.hideOnLockScreen, isTrue);
      final schedules = backend.count('schedule:');
      // Unchanged value: nothing is rescheduled.
      await service.setContentHidden(true);
      expect(backend.count('schedule:'), schedules);

      // New plans follow the switch too.
      await service.scheduleForTrack(drink, _alarms(drink, nowMs: 1000));
      expect(backend.pending.values.every((s) => s.hideOnLockScreen), isTrue);

      await service.setContentHidden(false);
      expect(backend.pending.values.any((s) => s.hideOnLockScreen), isFalse);
      expect(backend.pending, hasLength(17));
    });
  });
}
