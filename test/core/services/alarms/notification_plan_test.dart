import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';
import 'package:tikky_takka/core/services/alarms/alarm_service.dart';
import 'package:tikky_takka/core/services/alarms/notification_plan.dart';
import 'package:tikky_takka/core/services/alarms/alarm_strings.dart';
import 'package:tikky_takka/l10n/strings.dart';

import '../../../support/events.dart';

Track _track(
  TrackConfig config, {
  String id = 't1',
  String name = 'Nudeln',
  bool sound = true,
  bool vibration = true,
}) => Track(
  id: id,
  setId: 'set',
  name: name,
  config: config,
  alarmSound: sound,
  vibration: vibration,
);

/// Event log + config + now => the notifications handed to the OS.
List<NotificationSpec> _plan(
  Track track,
  EventLog log,
  int nowMs, {
  int maxCount = AlarmIds.slotsPerTrack,
}) => buildNotificationPlan(
  track: track,
  alarms: planAlarms(
    trackId: track.id,
    config: track.config,
    events: log.events,
    nowMs: nowMs,
  ),
  nowMs: nowMs,
  maxCount: maxCount,
);

void main() {
  group('AlarmIds', () {
    test('are derived from the FNV-1a hash of the track id', () {
      // Published FNV-1a 32 bit test vectors.
      expect(AlarmIds.base('a'), (0xE40C292C & 0x07FFFFFF) * 16);
      expect(AlarmIds.base('foobar'), (0xBF9CF968 & 0x07FFFFFF) * 16);
      expect(AlarmIds.base(''), (0x811C9DC5 & 0x07FFFFFF) * 16);
    });

    test('are stable, consecutive per track and fit into 31 bits', () {
      const ids = [
        '',
        'a',
        'id-0001',
        '3f2b8c1e-7d44-4a57-9b1a-0c5a2f6e9d10',
        'Spur mit Umlauten äöü ✓',
      ];
      for (final id in ids) {
        final all = AlarmIds.all(id);
        expect(all, hasLength(AlarmIds.slotsPerTrack));
        expect(AlarmIds.all(id), all, reason: 'stable');
        for (var slot = 0; slot < all.length; slot++) {
          expect(all[slot], AlarmIds.base(id) + slot);
          expect(all[slot], AlarmIds.forSlot(id, slot));
          expect(all[slot], inInclusiveRange(0, 0x7FFFFFFF));
        }
      }
    });

    test('blocks of different tracks do not overlap', () {
      final seen = <int>{};
      for (var i = 0; i < 500; i++) {
        final all = AlarmIds.all('id-${i.toString().padLeft(4, '0')}');
        expect(seen.intersection(all.toSet()), isEmpty);
        seen.addAll(all);
      }
    });

    test('rejects slots outside the block', () {
      expect(() => AlarmIds.forSlot('a', -1), throwsRangeError);
      expect(() => AlarmIds.forSlot('a', 16), throwsRangeError);
    });
  });

  group('AlarmPayload', () {
    test('round-trips track id and action', () {
      for (final type in AlarmActionType.values) {
        final decoded = AlarmPayload.decode(
          AlarmPayload.encode('id:with:colons', type),
        );
        expect(decoded?.trackId, 'id:with:colons');
        expect(decoded?.type, type);
      }
      expect(AlarmPayload.encode('x'), 'tt1:open:x');
    });

    test('ignores foreign and broken payloads', () {
      for (final payload in [
        null,
        '',
        'x',
        'tt1',
        'tt1:open',
        'tt1:open:',
        'tt1:explode:x',
        'tt2:open:x',
        'item x',
      ]) {
        expect(AlarmPayload.decode(payload), isNull, reason: '$payload');
      }
    });
  });

  group('alarmActionFromResponse', () {
    final payload = AlarmPayload.encode('t1');

    test('tap on the body opens the track', () {
      final action = alarmActionFromResponse(payload: payload);
      expect(action?.trackId, 't1');
      expect(action?.type, AlarmActionType.open);
      // iOS reports an empty action id for the default action.
      expect(
        alarmActionFromResponse(payload: payload, actionId: '')?.type,
        AlarmActionType.open,
      );
    });

    test('Android / iOS action ids select the action', () {
      final dismiss = alarmActionFromResponse(
        payload: payload,
        actionId: AlarmActionIds.dismiss,
      );
      expect(dismiss?.trackId, 't1');
      expect(dismiss?.type, AlarmActionType.dismiss);
      final ack = alarmActionFromResponse(
        payload: payload,
        actionId: AlarmActionIds.acknowledge,
      );
      expect(ack?.type, AlarmActionType.acknowledge);
    });

    test('Windows hands back the button argument as payload and action', () {
      final argument = AlarmPayload.encode('t1', AlarmActionType.acknowledge);
      final action = alarmActionFromResponse(
        payload: argument,
        actionId: argument,
      );
      expect(action?.trackId, 't1');
      expect(action?.type, AlarmActionType.acknowledge);
      // A click on the toast body: both are the launch payload.
      expect(
        alarmActionFromResponse(payload: payload, actionId: payload)?.type,
        AlarmActionType.open,
      );
    });

    test('notifications of someone else are ignored', () {
      expect(alarmActionFromResponse(), isNull);
      expect(
        alarmActionFromResponse(
          payload: 'item x',
          actionId: AlarmActionIds.dismiss,
        ),
        isNull,
      );
    });
  });

  group('AlarmChannel', () {
    test('follows the sound and vibration switches of the track', () {
      const config = CountdownConfig();
      expect(AlarmChannel.of(_track(config)), AlarmChannel.soundAndVibration);
      expect(
        AlarmChannel.of(_track(config, vibration: false)),
        AlarmChannel.soundOnly,
      );
      expect(
        AlarmChannel.of(_track(config, sound: false)),
        AlarmChannel.vibrationOnly,
      );
      expect(
        AlarmChannel.of(_track(config, sound: false, vibration: false)),
        AlarmChannel.silent,
      );
    });

    test('channel ids are unique and match their flags', () {
      expect(
        AlarmChannel.values.map((c) => c.id).toSet(),
        hasLength(AlarmChannel.values.length),
      );
      expect(AlarmChannel.soundOnly.playSound, isTrue);
      expect(AlarmChannel.soundOnly.vibrate, isFalse);
      expect(AlarmChannel.vibrationOnly.playSound, isFalse);
      expect(AlarmChannel.vibrationOnly.vibrate, isTrue);
      expect(AlarmChannel.silent.playSound, isFalse);
      expect(AlarmChannel.silent.vibrate, isFalse);
    });
  });

  test('ceilToSecond rounds up to the next full second', () {
    expect(ceilToSecond(0), 0);
    expect(ceilToSecond(1), 1000);
    expect(ceilToSecond(999), 1000);
    expect(ceilToSecond(1000), 1000);
    expect(ceilToSecond(1001), 2000);
  });

  group('countdown', () {
    const start = 1700000000250; // deliberately not on a full second
    final track = _track(const CountdownConfig(durationMs: 10 * min));

    test('running: one notification at the due time, with "Stopp"', () {
      final log = EventLog()..start(start);
      final specs = _plan(track, log, start + 5 * sec);
      expect(specs, hasLength(1));
      final spec = specs.single;
      expect(spec.kind, AlarmKind.countdownDone);
      expect(spec.id, AlarmIds.forSlot('t1', 0));
      expect(spec.slot, 0);
      expect(spec.trackId, 't1');
      expect(spec.dueAtMs, start + 10 * min);
      // Never early: rounded up to the second the OS can hit.
      expect(spec.fireAtMs, 1700000601000);
      expect(spec.fireAtMs, greaterThanOrEqualTo(spec.dueAtMs));
      expect(spec.title, Strings.notifCountdownDone('Nudeln'));
      expect(spec.body, '${Strings.modeName(TrackMode.countdown)} · 10 min');
      expect(spec.action, AlarmActionType.dismiss);
      expect(spec.needsAttention, isTrue);
      expect(spec.isReminder, isFalse);
      expect(spec.supersededAtMs, isNull);
      expect(spec.timeoutAfterMs, isNull);
      expect(AlarmPayload.decode(spec.payload)?.trackId, 't1');
      expect(AlarmPayload.decode(spec.payload)?.type, AlarmActionType.open);
      expect(spec.channel, AlarmChannel.soundAndVibration);
    });

    test('pause moves the due time by the paused span', () {
      final log = EventLog()
        ..start(start)
        ..pause(start + 2 * min)
        ..resume(start + 5 * min);
      final spec = _plan(track, log, start + 6 * min).single;
      expect(spec.dueAtMs, start + 13 * min);
      expect(spec.fireAtMs, ceilToSecond(start + 13 * min));
    });

    test('nothing while idle, paused, ringing or stopped', () {
      expect(_plan(track, EventLog(), start), isEmpty);
      final paused = EventLog()
        ..start(start)
        ..pause(start + min);
      expect(_plan(track, paused, start + 2 * min), isEmpty);
      final running = EventLog()..start(start);
      expect(_plan(track, running, start + 10 * min), isEmpty);
      expect(_plan(track, running, start + 11 * min), isEmpty);
      final stopped = EventLog()
        ..start(start)
        ..stop(start + min);
      expect(_plan(track, stopped, start + 2 * min), isEmpty);
    });

    test('auto restart: one notification per upcoming cycle', () {
      final auto = _track(
        const CountdownConfig(durationMs: 5 * min, autoRestart: true),
      );
      final log = EventLog()..start(0);
      final specs = _plan(auto, log, 7 * min);
      expect(specs, hasLength(16));
      expect(specs.first.kind, AlarmKind.countdownCycle);
      expect(specs.first.fireAtMs, 10 * min);
      expect(specs.first.title, Strings.notifCountdownCycle('Nudeln', 2));
      expect(specs[1].fireAtMs, 15 * min);
      expect(specs.last.fireAtMs, 85 * min);
      expect(specs.map((s) => s.action).toSet(), {AlarmActionType.dismiss});
      expect(specs.every((s) => !s.needsAttention), isTrue);
      // Each cycle notification makes way for the next one.
      expect(specs.first.timeoutAfterMs, 5 * min);
      expect(specs.last.timeoutAfterMs, isNull);
    });

    test('the sound and vibration switches pick the channel', () {
      final quiet = _track(
        const CountdownConfig(durationMs: min),
        sound: false,
        vibration: false,
      );
      final spec = _plan(quiet, EventLog()..start(0), 1).single;
      expect(spec.channel, AlarmChannel.silent);
      expect(spec.playSound, isFalse);
      expect(spec.vibrate, isFalse);
    });

    test('an unnamed track is announced by its mode', () {
      final unnamed = _track(const CountdownConfig(durationMs: min), name: ' ');
      final spec = _plan(unnamed, EventLog()..start(0), 1).single;
      expect(
        spec.title,
        Strings.notifCountdownDone(Strings.modeName(TrackMode.countdown)),
      );
    });
  });

  group('interval', () {
    final track = _track(
      const IntervalConfig(workMs: 30 * sec, restMs: 10 * sec, rounds: 3),
      name: 'Tabata',
    );

    test('every phase boundary and the end, in order', () {
      final log = EventLog()..start(0);
      final specs = _plan(track, log, 5 * sec);
      expect(specs.map((s) => s.kind), [
        AlarmKind.intervalRest,
        AlarmKind.intervalWork,
        AlarmKind.intervalRest,
        AlarmKind.intervalWork,
        AlarmKind.intervalDone,
      ]);
      expect(specs.map((s) => s.fireAtMs), [
        30 * sec,
        40 * sec,
        70 * sec,
        80 * sec,
        110 * sec,
      ]);
      expect(specs.map((s) => s.id), [
        for (var i = 0; i < 5; i++) AlarmIds.forSlot('t1', i),
      ]);
      expect(specs.map((s) => s.title), [
        Strings.notifIntervalRest('Tabata', 1),
        Strings.notifIntervalWork('Tabata', 2),
        Strings.notifIntervalRest('Tabata', 2),
        Strings.notifIntervalWork('Tabata', 3),
        Strings.notifIntervalDone('Tabata'),
      ]);
      expect(specs.map((s) => s.body), [
        'Pause · 10 s',
        'Runde 2 von 3 · 30 s',
        'Pause · 10 s',
        'Runde 3 von 3 · 30 s',
        '3 Runden · 1 min 50 s',
      ]);
      // Only the end needs the user; phase changes carry no button.
      expect(specs.map((s) => s.action), [
        null,
        null,
        null,
        null,
        AlarmActionType.dismiss,
      ]);
      expect(specs.map((s) => s.needsAttention), [
        false,
        false,
        false,
        false,
        true,
      ]);
      // A phase notification lives until the next phase begins.
      expect(specs.map((s) => s.supersededAtMs), [
        40 * sec,
        70 * sec,
        80 * sec,
        110 * sec,
        null,
      ]);
      expect(specs.map((s) => s.timeoutAfterMs), [
        10 * sec,
        30 * sec,
        10 * sec,
        30 * sec,
        null,
      ]);
    });

    test('mid-programme: only what is still ahead, slots start at 0', () {
      final log = EventLog()..start(0);
      final specs = _plan(track, log, 75 * sec);
      expect(specs.map((s) => s.kind), [
        AlarmKind.intervalWork,
        AlarmKind.intervalDone,
      ]);
      expect(specs.map((s) => s.fireAtMs), [80 * sec, 110 * sec]);
      expect(specs.map((s) => s.slot), [0, 1]);
    });

    test('a pause shifts all remaining boundaries', () {
      final log = EventLog()
        ..start(0)
        ..pause(20 * sec)
        ..resume(50 * sec);
      final specs = _plan(track, log, 51 * sec);
      expect(specs.map((s) => s.fireAtMs), [
        60 * sec,
        70 * sec,
        100 * sec,
        110 * sec,
        140 * sec,
      ]);
    });

    test('without rest every round start is announced', () {
      final noRest = _track(
        const IntervalConfig(workMs: 20 * sec, restMs: 0, rounds: 3),
      );
      final specs = _plan(noRest, EventLog()..start(0), 1);
      expect(specs.map((s) => s.kind), [
        AlarmKind.intervalWork,
        AlarmKind.intervalWork,
        AlarmKind.intervalDone,
      ]);
      expect(specs.map((s) => s.fireAtMs), [20 * sec, 40 * sec, 60 * sec]);
    });

    test('long programmes keep the final alarm when cut to 16', () {
      final long = _track(
        const IntervalConfig(workMs: 30 * sec, restMs: 10 * sec, rounds: 20),
      );
      final specs = _plan(long, EventLog()..start(0), 1);
      expect(specs, hasLength(16));
      expect(specs.last.kind, AlarmKind.intervalDone);
      expect(specs.last.fireAtMs, (20 * 30 + 19 * 10) * sec);
      expect(specs.last.id, AlarmIds.forSlot('t1', 15));
    });

    test('a smaller budget keeps the earliest phases and the end', () {
      final specs = _plan(track, EventLog()..start(0), 1, maxCount: 3);
      expect(specs.map((s) => s.kind), [
        AlarmKind.intervalRest,
        AlarmKind.intervalWork,
        AlarmKind.intervalDone,
      ]);
      expect(specs.map((s) => s.slot), [0, 1, 2]);
      // The gap to the end is bridged by the timeout of the last phase.
      expect(specs[1].supersededAtMs, 110 * sec);
    });

    test('nothing once finished or with a zero budget', () {
      final log = EventLog()..start(0);
      expect(_plan(track, log, 110 * sec), isEmpty);
      expect(_plan(track, log, 1, maxCount: 0), isEmpty);
    });
  });

  group('reminder', () {
    final track = _track(
      const ReminderConfig(intervalMs: 30 * min, nagEveryMs: min),
      name: 'Trinken',
    );

    test('due time plus nag repeats, all with "Erledigt"', () {
      final log = EventLog()..start(0);
      final specs = _plan(track, log, sec);
      expect(specs, hasLength(16));
      expect(specs.first.kind, AlarmKind.reminderDue);
      expect(specs.first.fireAtMs, 30 * min);
      expect(specs.first.title, Strings.notifReminderDue('Trinken'));
      expect(specs.first.body, 'Erinnerung · alle 30 min');
      expect(specs.skip(1).map((s) => s.kind).toSet(), {AlarmKind.reminderNag});
      expect(specs.map((s) => s.fireAtMs), [
        for (var i = 0; i < 16; i++) (30 + i) * min,
      ]);
      expect(specs[1].title, Strings.notifReminderNag('Trinken'));
      expect(specs[1].body, 'Seit 1 min fällig');
      expect(specs[14].body, 'Seit 14 min fällig');
      // The nags go on for ever but only 16 fit: the last one says so.
      expect(specs[15].body, AlarmStrings.openAppForMore);
      expect(specs.map((s) => s.lastOfCutPlan), [
        for (var i = 0; i < 16; i++) i == 15,
      ]);
      expect(specs.map((s) => s.action).toSet(), {AlarmActionType.acknowledge});
      expect(specs.every((s) => s.isReminder && s.needsAttention), isTrue);
      // Each nag replaces the previous notification; the last one stays.
      expect(specs.take(15).map((s) => s.timeoutAfterMs).toSet(), {min});
      expect(specs.last.timeoutAfterMs, isNull);
    });

    test('the next due time counts from the last ack', () {
      final log = EventLog()
        ..start(0)
        ..ack(40 * min);
      final specs = _plan(track, log, 41 * min);
      expect(specs.first.kind, AlarmKind.reminderDue);
      expect(specs.first.fireAtMs, 70 * min);
      expect(specs[1].fireAtMs, 71 * min);
    });

    test('already due: only the nags that are still ahead', () {
      final log = EventLog()..start(0);
      final specs = _plan(track, log, 30 * min + 90 * sec);
      expect(specs, hasLength(16));
      expect(specs.map((s) => s.kind).toSet(), {AlarmKind.reminderNag});
      expect(specs.first.fireAtMs, 32 * min);
      expect(specs.first.body, 'Seit 2 min fällig');
    });

    test('without nagging there is exactly one notification', () {
      final once = _track(
        const ReminderConfig(intervalMs: 30 * min, nagEveryMs: 0),
      );
      final specs = _plan(once, EventLog()..start(0), sec);
      expect(specs.single.kind, AlarmKind.reminderDue);
      expect(_plan(once, EventLog()..start(0), 31 * min), isEmpty);
    });

    test('nothing while paused', () {
      final log = EventLog()
        ..start(0)
        ..pause(10 * min);
      expect(_plan(track, log, 50 * min), isEmpty);
    });
  });

  group('buildNotificationPlan', () {
    final track = _track(const CountdownConfig(durationMs: min));

    PlannedAlarm alarm(int at, AlarmKind kind, int index) =>
        PlannedAlarm(trackId: 't1', at: at, kind: kind, index: index);

    test('drops alarms that are not in the future and sorts the rest', () {
      final specs = buildNotificationPlan(
        track: track,
        alarms: [
          alarm(9000, AlarmKind.reminderNag, 2),
          alarm(5000, AlarmKind.reminderDue, 1),
          alarm(4000, AlarmKind.reminderNag, 0),
          alarm(3999, AlarmKind.reminderNag, 3),
        ],
        nowMs: 4000,
      );
      expect(specs.map((s) => s.dueAtMs), [5000, 9000]);
      expect(specs.map((s) => s.slot), [0, 1]);
    });

    test('never returns more than one block of ids', () {
      final specs = buildNotificationPlan(
        track: track,
        alarms: [
          for (var i = 0; i < 40; i++)
            alarm(1000 * (i + 1), AlarmKind.reminderNag, i),
        ],
        nowMs: 0,
        maxCount: 99,
      );
      expect(specs, hasLength(AlarmIds.slotsPerTrack));
      expect(specs.map((s) => s.id).toSet(), AlarmIds.all('t1').toSet());
    });

    test('alarms in the same second do not time each other out', () {
      final specs = buildNotificationPlan(
        track: track,
        alarms: [
          alarm(1100, AlarmKind.intervalRest, 0),
          alarm(1900, AlarmKind.intervalWork, 1),
          alarm(5000, AlarmKind.intervalDone, 2),
        ],
        nowMs: 0,
      );
      expect(specs.map((s) => s.fireAtMs), [2000, 2000, 5000]);
      expect(specs.map((s) => s.supersededAtMs), [5000, 5000, null]);
    });

    test('a body is left out when the config does not fit the alarm', () {
      final spec = buildNotificationPlan(
        track: track,
        alarms: [alarm(1000, AlarmKind.intervalDone, 0)],
        nowMs: 0,
      ).single;
      expect(spec.body, isNull);
      expect(spec.title, Strings.notifIntervalDone('Nudeln'));
    });

    test('specs have value equality', () {
      List<NotificationSpec> build() => buildNotificationPlan(
        track: track,
        alarms: [alarm(1000, AlarmKind.countdownDone, 0)],
        nowMs: 0,
      );
      expect(build(), build());
      expect(build().single.hashCode, build().single.hashCode);
    });
  });

  group('truncateAlarms', () {
    PlannedAlarm alarm(int index, AlarmKind kind) =>
        PlannedAlarm(trackId: 't', at: index * 1000, kind: kind, index: index);

    test('keeps short plans untouched', () {
      final alarms = [alarm(1, AlarmKind.reminderDue)];
      expect(truncateAlarms(alarms, 5), same(alarms));
      expect(truncateAlarms(alarms, 0), isEmpty);
    });

    test('keeps the interval end, drops late nags', () {
      final interval = [
        alarm(1, AlarmKind.intervalRest),
        alarm(2, AlarmKind.intervalWork),
        alarm(3, AlarmKind.intervalRest),
        alarm(4, AlarmKind.intervalDone),
      ];
      expect(truncateAlarms(interval, 2).map((a) => a.index), [1, 4]);
      expect(truncateAlarms(interval, 1).map((a) => a.index), [1]);
      final nags = [
        alarm(1, AlarmKind.reminderDue),
        alarm(2, AlarmKind.reminderNag),
        alarm(3, AlarmKind.reminderNag),
      ];
      expect(truncateAlarms(nags, 2).map((a) => a.index), [1, 2]);
    });
  });
}
