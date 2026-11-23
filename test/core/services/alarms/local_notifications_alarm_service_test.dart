import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/clock.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';
import 'package:tikky_takka/core/services/alarms/alarms.dart';

import '../../../support/events.dart';
import 'fake_notification_backend.dart';

Track _track(String id, TrackConfig config, {String? name}) =>
    Track(id: id, setId: 'set', name: name ?? id, config: config);

/// The plan of a track that was started at [startMs], seen at [nowMs].
List<PlannedAlarm> _alarms(Track track, {int startMs = 0, required int nowMs}) {
  final log = EventLog(trackId: track.id)..start(startMs);
  return planAlarms(
    trackId: track.id,
    config: track.config,
    events: log.events,
    nowMs: nowMs,
  );
}

void main() {
  late FakeNotificationBackend backend;
  late FakeClock clock;
  late List<Object> errors;
  late LocalNotificationsAlarmService service;

  LocalNotificationsAlarmService create({bool askOnFirstSchedule = false}) =>
      LocalNotificationsAlarmService(
        backend: backend,
        clock: clock,
        requestPermissionOnFirstSchedule: askOnFirstSchedule,
        onError: (error, _) => errors.add(error),
      );

  setUp(() {
    backend = FakeNotificationBackend();
    clock = FakeClock(1000);
    errors = [];
    service = create();
  });

  final timer = _track('timer', const CountdownConfig(durationMs: 10 * min));
  final tabata = _track(
    'tabata',
    const IntervalConfig(workMs: 30 * sec, restMs: 10 * sec, rounds: 3),
  );
  final drink = _track(
    'drink',
    const ReminderConfig(intervalMs: 30 * min, nagEveryMs: min),
  );

  group('init', () {
    test('is idempotent and never throws', () async {
      await service.init();
      await service.init();
      expect(backend.initCalls, 1);
      expect(await service.isReady, isTrue);

      backend = FakeNotificationBackend()..initError = StateError('no dll');
      service = create();
      await service.init();
      await service.init();
      expect(backend.initCalls, 1);
      expect(await service.isReady, isFalse);
      expect(errors, hasLength(1));
    });

    test('an unusable backend turns the service into a no-op', () async {
      backend.initResult = false;
      await service.init();
      await service.scheduleForTrack(timer, _alarms(timer, nowMs: 1000));
      await service.cancelForTrack('timer');
      await service.cancelAll();
      expect(backend.log, isEmpty);
      expect(
        await service.permissionStatus(),
        same(AlarmPermissionStatus.unsupported),
      );
      expect(
        await service.requestPermissions(),
        same(AlarmPermissionStatus.unsupported),
      );
      expect(errors, isEmpty);
    });

    test('scheduling initialises on demand', () async {
      await service.scheduleForTrack(timer, _alarms(timer, nowMs: 1000));
      expect(backend.initCalls, 1);
      expect(backend.pending, hasLength(1));
    });
  });

  group('scheduleForTrack', () {
    test('hands the plan to the OS under the ids of the track', () async {
      await service.scheduleForTrack(tabata, _alarms(tabata, nowMs: 1000));
      expect(backend.pending.keys, [
        for (var i = 0; i < 5; i++) AlarmIds.forSlot('tabata', i),
      ]);
      expect(backend.pending.values.map((s) => s.kind), [
        AlarmKind.intervalRest,
        AlarmKind.intervalWork,
        AlarmKind.intervalRest,
        AlarmKind.intervalWork,
        AlarmKind.intervalDone,
      ]);
      expect(backend.pending.values.map((s) => s.fireAtMs), [
        30 * sec,
        40 * sec,
        70 * sec,
        80 * sec,
        110 * sec,
      ]);
      expect(backend.shown, isEmpty);
      expect(errors, isEmpty);
    });

    test('replaces everything the track had before', () async {
      await service.scheduleForTrack(tabata, _alarms(tabata, nowMs: 1000));
      // Unknown state after a process start: the whole block is cleared.
      expect(backend.cancelledIds, AlarmIds.all('tabata'));
      backend.log.clear();

      clock.setMs(75 * sec);
      await service.scheduleForTrack(tabata, _alarms(tabata, nowMs: 75 * sec));
      // Now exactly the five ids handed out before are cancelled ...
      expect(backend.cancelledIds, [
        for (var i = 0; i < 5; i++) AlarmIds.forSlot('tabata', i),
      ]);
      // ... and only what is still ahead is scheduled, from slot 0.
      expect(backend.pending.keys, [
        AlarmIds.forSlot('tabata', 0),
        AlarmIds.forSlot('tabata', 1),
      ]);
      expect(backend.pending.values.map((s) => s.fireAtMs), [
        80 * sec,
        110 * sec,
      ]);
    });

    test('tracks do not disturb each other', () async {
      await service.scheduleForTrack(timer, _alarms(timer, nowMs: 1000));
      await service.scheduleForTrack(drink, _alarms(drink, nowMs: 1000));
      expect(backend.pending, hasLength(17));
      await service.scheduleForTrack(timer, _alarms(timer, nowMs: 1000));
      expect(backend.pending, hasLength(17));
      await service.cancelForTrack('drink');
      expect(backend.pending.keys, [AlarmIds.forSlot('timer', 0)]);
    });

    test('an empty plan cancels the track', () async {
      await service.scheduleForTrack(timer, _alarms(timer, nowMs: 1000));
      await service.scheduleForTrack(timer, const []);
      expect(backend.pending, isEmpty);
    });

    test('uses the clock, not the plan time, to drop stale alarms', () async {
      final alarms = _alarms(tabata, nowMs: 1000);
      clock.setMs(45 * sec); // the plan is 44 s old when it arrives
      await service.scheduleForTrack(tabata, alarms);
      expect(backend.pending.values.map((s) => s.fireAtMs), [
        70 * sec,
        80 * sec,
        110 * sec,
      ]);
    });

    test('concurrent calls are applied one after the other', () async {
      final first = service.scheduleForTrack(
        tabata,
        _alarms(tabata, nowMs: 1000),
      );
      final second = service.cancelForTrack('tabata');
      final third = service.scheduleForTrack(
        timer,
        _alarms(timer, nowMs: 1000),
      );
      await Future.wait([first, second, third]);
      expect(backend.pending.keys, [AlarmIds.forSlot('timer', 0)]);
    });
  });

  group('exact alarms', () {
    test('exact when allowed, inexact otherwise', () async {
      await service.scheduleForTrack(timer, _alarms(timer, nowMs: 1000));
      expect(backend.exactById.values, [true]);

      backend.exact = false;
      await service.scheduleForTrack(timer, _alarms(timer, nowMs: 1000));
      expect(backend.exactById.values, [false]);
      expect(errors, isEmpty);
    });

    test('falls back to inexact when the OS refuses after all', () async {
      backend.refuseExactWhenScheduling = true;
      await service.scheduleForTrack(tabata, _alarms(tabata, nowMs: 1000));
      expect(backend.pending, hasLength(5));
      expect(backend.exactById.values.toSet(), {false});
      // One refused attempt, then inexact for the rest of the plan.
      expect(backend.count('schedule:'), 6);
      expect(errors, isEmpty);
    });

    test('a failing permission query means inexact, not no alarm', () async {
      backend.failPermissionQueries = true;
      await service.scheduleForTrack(timer, _alarms(timer, nowMs: 1000));
      expect(backend.exactById.values, [false]);
      expect(errors, hasLength(1));
    });
  });

  group('robustness', () {
    test('an instant that just passed is shown right away', () async {
      backend.inPast.add(AlarmIds.forSlot('timer', 0));
      await service.scheduleForTrack(timer, _alarms(timer, nowMs: 1000));
      expect(backend.pending, isEmpty);
      expect(backend.shown.single.kind, AlarmKind.countdownDone);
      expect(errors, isEmpty);
    });

    test('one failing notification does not cost the others', () async {
      backend.failing.add(AlarmIds.forSlot('tabata', 1));
      await service.scheduleForTrack(tabata, _alarms(tabata, nowMs: 1000));
      expect(backend.pending, hasLength(4));
      expect(
        backend.pending.keys,
        isNot(contains(AlarmIds.forSlot('tabata', 1))),
      );
      expect(errors, hasLength(1));

      // The next replacement cancels only what was really handed out.
      backend.log.clear();
      backend.failing.clear();
      await service.cancelForTrack('tabata');
      expect(backend.cancelledIds, [
        AlarmIds.forSlot('tabata', 0),
        AlarmIds.forSlot('tabata', 2),
        AlarmIds.forSlot('tabata', 3),
        AlarmIds.forSlot('tabata', 4),
      ]);
    });

    test('cancel problems are swallowed', () async {
      backend.failCancel = true;
      await service.scheduleForTrack(timer, _alarms(timer, nowMs: 1000));
      await service.cancelForTrack('timer');
      expect(backend.count('schedule:'), 1);
      expect(errors, isNotEmpty);
    });
  });

  group('cancelAll', () {
    test('clears the OS and makes later replacements cheap', () async {
      await service.scheduleForTrack(timer, _alarms(timer, nowMs: 1000));
      await service.scheduleForTrack(drink, _alarms(drink, nowMs: 1000));
      await service.cancelAll();
      expect(backend.pending, isEmpty);

      backend.log.clear();
      await service.scheduleForTrack(tabata, _alarms(tabata, nowMs: 1000));
      // Nothing can be left of an untouched track after a clean sweep.
      expect(backend.cancelledIds, isEmpty);
      expect(backend.pending, hasLength(5));
    });

    test('falls back to cancelling the known ids', () async {
      await service.scheduleForTrack(timer, _alarms(timer, nowMs: 1000));
      backend.failCancelAll = true;
      backend.log.clear();
      await service.cancelAll();
      expect(backend.cancelledIds, [AlarmIds.forSlot('timer', 0)]);
      expect(backend.pending, isEmpty);
      expect(errors, hasLength(1));
    });
  });

  group('test alarm (diagnostics)', () {
    test(
      'rings once after the delay and outlives cancelAll until due',
      () async {
        await service.scheduleTestAlarm(const Duration(seconds: 10));
        final spec = backend.pending.values.single;
        expect(spec.fireAtMs, 1000 + 10 * sec);
        expect(spec.title, contains(AlarmStrings.testAlarmName));

        // The app reschedules everything when it goes to the background.
        await service.cancelAll();
        expect(backend.pending.values.single.fireAtMs, 1000 + 10 * sec);

        // Once due, a sweep removes it for good.
        clock.advanceMs(11 * sec);
        await service.cancelAll();
        expect(backend.pending, isEmpty);
      },
    );

    test('taps on it are not reported as track actions', () async {
      await service.init();
      final seen = <AlarmAction>[];
      final subscription = service.actions.listen(seen.add);
      backend.tap(payload: AlarmPayload.encode(AlarmService.testTrackId));
      await pumpEventQueue();
      expect(seen, isEmpty);
      await subscription.cancel();
    });
  });

  group('pending budget (iOS)', () {
    final drink2 = _track(
      'drink2',
      const ReminderConfig(intervalMs: 20 * min, nagEveryMs: min),
    );

    test(
      'later tracks get what is left and catch up when room is freed',
      () async {
        backend.maxPending = 20;
        await service.scheduleForTrack(drink, _alarms(drink, nowMs: 1000));
        await service.scheduleForTrack(drink2, _alarms(drink2, nowMs: 1000));
        List<NotificationSpec> of(String id) => [
          for (final spec in backend.pending.values)
            if (spec.trackId == id) spec,
        ];
        expect(of('drink'), hasLength(16));
        // The earliest alarms of the second track fit, the late nags do not.
        expect(of('drink2'), hasLength(4));
        expect(of('drink2').first.kind, AlarmKind.reminderDue);
        expect(backend.pending.length, lessThanOrEqualTo(20));

        await service.cancelForTrack('drink');
        expect(of('drink'), isEmpty);
        expect(of('drink2'), hasLength(16));
      },
    );

    test('nothing at all when the budget is used up', () async {
      backend.maxPending = 16;
      await service.scheduleForTrack(drink, _alarms(drink, nowMs: 1000));
      await service.scheduleForTrack(timer, _alarms(timer, nowMs: 1000));
      expect(
        backend.pending.values.where((s) => s.trackId == 'timer'),
        isEmpty,
      );
      // Re-planning the big track with less frees room for the small one.
      await service.scheduleForTrack(
        drink,
        _alarms(drink, nowMs: 1000).take(3).toList(),
      );
      expect(
        backend.pending.values.where((s) => s.trackId == 'timer'),
        hasLength(1),
      );
      expect(backend.pending, hasLength(4));
    });
  });

  group('permissions', () {
    test('status mirrors the OS', () async {
      backend
        ..notifications = false
        ..exact = false;
      var status = await service.permissionStatus();
      expect(status.supported, isTrue);
      expect(status.notificationsGranted, isFalse);
      expect(status.exactAlarmsGranted, isFalse);
      expect(status.allGranted, isFalse);
      backend
        ..notifications = true
        ..exact = true;
      status = await service.permissionStatus();
      expect(status.allGranted, isTrue);
      expect(backend.log, isEmpty, reason: 'status never prompts');
    });

    test('request runs both steps and re-applies the plans', () async {
      backend
        ..notifications = false
        ..exact = false;
      await service.scheduleForTrack(timer, _alarms(timer, nowMs: 1000));
      expect(backend.exactById.values, [false]);
      backend.log.clear();

      final status = await service.requestPermissions();
      expect(status.allGranted, isTrue);
      expect(backend.log.take(2), [
        'requestNotifications',
        'requestExactAlarms',
      ]);
      // Scheduled again, now exact.
      expect(backend.count('schedule:'), 1);
      expect(backend.exactById.values, [true]);
    });

    test('exact alarms are not requested without notifications', () async {
      backend
        ..notifications = false
        ..exact = false
        ..grantNotificationsOnRequest = false;
      final status = await service.requestPermissions();
      expect(status.notificationsGranted, isFalse);
      expect(backend.log, ['requestNotifications']);
    });

    test('exact alarms are not requested when already allowed', () async {
      backend.notifications = false;
      await service.requestPermissions();
      expect(backend.log, ['requestNotifications']);
    });

    test('the first scheduled alarm asks for notifications, once', () async {
      service = create(askOnFirstSchedule: true);
      backend.notifications = false;
      await service.scheduleForTrack(timer, _alarms(timer, nowMs: 1000));
      await pumpEventQueue();
      expect(backend.count('requestNotifications'), 1);
      // iOS drops alarms scheduled without permission: applied again.
      expect(backend.count('schedule:'), 2);
      expect(backend.count('requestExactAlarms'), 0, reason: 'never unasked');

      await service.scheduleForTrack(drink, _alarms(drink, nowMs: 1000));
      await pumpEventQueue();
      expect(backend.count('requestNotifications'), 1);
    });

    test('no prompt when permission is there or the user said no', () async {
      service = create(askOnFirstSchedule: true);
      await service.scheduleForTrack(timer, _alarms(timer, nowMs: 1000));
      await pumpEventQueue();
      expect(backend.count('requestNotifications'), 0);

      backend = FakeNotificationBackend()
        ..notifications = false
        ..grantNotificationsOnRequest = false;
      service = create(askOnFirstSchedule: true);
      await service.scheduleForTrack(timer, _alarms(timer, nowMs: 1000));
      await pumpEventQueue();
      expect(backend.count('requestNotifications'), 1);
      expect(backend.count('schedule:'), 1, reason: 'nothing to re-apply');
    });

    test('cancelling never prompts', () async {
      service = create(askOnFirstSchedule: true);
      backend.notifications = false;
      await service.cancelForTrack('timer');
      await service.cancelAll();
      await service.scheduleForTrack(timer, const []);
      await pumpEventQueue();
      expect(backend.count('requestNotifications'), 0);
    });
  });

  group('actions', () {
    test('taps and buttons become alarm actions', () async {
      await service.init();
      final seen = <AlarmAction>[];
      final subscription = service.actions.listen(seen.add);
      final payload = AlarmPayload.encode('timer');
      backend
        ..tap(payload: payload)
        ..tap(payload: payload, actionId: AlarmActionIds.dismiss)
        ..tap(payload: payload, actionId: AlarmActionIds.acknowledge)
        ..tap(payload: 'not ours')
        ..tap();
      await pumpEventQueue();
      expect(seen.map((a) => a.type), [
        AlarmActionType.open,
        AlarmActionType.dismiss,
        AlarmActionType.acknowledge,
      ]);
      expect(seen.map((a) => a.trackId).toSet(), {'timer'});
      await subscription.cancel();
    });

    test(
      'the tap that launched the app waits for the first listener',
      () async {
        backend.launch = (
          payload: AlarmPayload.encode('drink'),
          actionId: AlarmActionIds.acknowledge,
        );
        await service.init();
        await pumpEventQueue();

        final seen = <AlarmAction>[];
        final subscription = service.actions.listen(seen.add);
        await pumpEventQueue();
        expect(seen.single.trackId, 'drink');
        expect(seen.single.type, AlarmActionType.acknowledge);

        // Delivered once only.
        await subscription.cancel();
        final again = <AlarmAction>[];
        final second = service.actions.listen(again.add);
        await pumpEventQueue();
        expect(again, isEmpty);
        await second.cancel();
      },
    );

    test('a failing launch lookup does not break init', () async {
      backend.launchError = StateError('not ready');
      await service.init();
      expect(await service.isReady, isTrue);
      expect(errors, hasLength(1));
    });

    test('dispose closes the stream', () async {
      await service.init();
      final done = expectLater(service.actions, emitsDone);
      await service.dispose();
      await done;
      backend.tap(payload: AlarmPayload.encode('timer'));
    });
  });

  test('createAlarmService never throws and yields a usable service', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final created = createAlarmService();
    // No plugin is registered in unit tests: init must swallow that.
    await created.init();
    await created.scheduleForTrack(timer, _alarms(timer, nowMs: 1000));
    await created.cancelForTrack('timer');
    await created.cancelAll();
    final status = await created.permissionStatus();
    expect(status.supported, isFalse);
  });
}
