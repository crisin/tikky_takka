import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/core/services/alarms/alarm_service.dart';
import 'package:tikky_takka/core/services/haptics.dart';
import 'package:tikky_takka/features/tracks/ring_monitor.dart';

import 'tracks_harness.dart';

/// The in-app cue: repeats while a track waits for the user, only in the
/// foreground, and honours the sound / vibration / haptics switches.
void main() {
  const cadence = Duration(milliseconds: ringRepeatEveryMs);

  Future<void> lifecycle(TracksHarness h, AppLifecycleState state) async {
    h.tester.binding.handleAppLifecycleStateChanged(state);
    await h.settle();
  }

  testWidgets('a finished countdown keeps ringing at the cadence until it '
      'is dismissed', (tester) async {
    final h = await TracksHarness.start(tester);
    final timer = h.timer;
    await h.tap(h.primary(timer));
    await h.advance(const Duration(minutes: 10, seconds: 1));
    expect(h.rings.rung, [timer.id]);

    await h.advance(const Duration(seconds: 2));
    expect(h.rings.rung, hasLength(1), reason: 'not on every tick');
    await h.advance(const Duration(seconds: 3));
    expect(h.rings.rung, hasLength(2));
    await h.advance(cadence);
    await h.advance(cadence);
    expect(h.rings.rung, [timer.id, timer.id, timer.id, timer.id]);

    // The primary button of a ringing countdown stops it.
    await h.tap(h.primary(timer));
    expect(await h.snapshot(timer), isNull);
    await h.advance(cadence);
    await h.advance(cadence);
    expect(h.rings.rung, hasLength(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a due reminder repeats until it is acknowledged, also when '
      'that happens from the notification', (tester) async {
    final h = await TracksHarness.start(tester);
    final reminder = await h.addTrack(
      const ReminderConfig(intervalMs: 60000, nagEveryMs: 0),
      name: 'Trinken',
    );
    await h.run(
      () => h.container.read(trackCommandsProvider).startTrack(reminder.id),
    );
    await h.advance(const Duration(seconds: 61));
    expect(h.rings.rung, [reminder.id]);
    await h.advance(cadence);
    expect(h.rings.rung, hasLength(2));

    // "Erledigt" on the OS notification.
    h.app.alarms.emit(
      AlarmAction(trackId: reminder.id, type: AlarmActionType.acknowledge),
    );
    await h.settle();
    await h.advance(cadence);
    await h.advance(cadence);
    expect(h.rings.rung, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('nothing rings in the background, and what finished there is '
      'not a fresh ring on return: the repeating cue just continues', (
    tester,
  ) async {
    final h = await TracksHarness.start(tester);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    final timer = h.timer;
    await h.tap(h.primary(timer));
    await h.advance(const Duration(minutes: 5));

    await lifecycle(h, AppLifecycleState.inactive);
    await lifecycle(h, AppLifecycleState.hidden);
    await lifecycle(h, AppLifecycleState.paused);
    // Finishes while the app is away: the OS notification rings.
    await h.advance(const Duration(minutes: 6));
    expect(h.rings.rung, isEmpty);

    await lifecycle(h, AppLifecycleState.hidden);
    await lifecycle(h, AppLifecycleState.inactive);
    await lifecycle(h, AppLifecycleState.resumed);
    await h.advance(const Duration(milliseconds: 300));
    expect(h.rings.rung, isEmpty, reason: 'no "just finished" burst');

    await h.advance(cadence);
    expect(h.rings.rung, [timer.id]);
    await h.advance(cadence);
    expect(h.rings.rung, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  group('SystemRingFeedback', () {
    late List<MethodCall> calls;

    Track track({bool sound = true, bool vibration = true}) => Track(
      id: 't',
      setId: 's',
      name: 'Timer',
      config: const CountdownConfig(durationMs: 1000),
      alarmSound: sound,
      vibration: vibration,
    );

    Future<List<String>> ring(Track track, {bool haptics = true}) async {
      calls.clear();
      await SystemRingFeedback(Haptics(enabled: haptics)).ring(track);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      return [for (final call in calls) call.method];
    }

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            calls.add(call);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('sound and vibration when both are on', () async {
      final methods = await ring(track());
      expect(methods, contains('SystemSound.play'));
      expect(methods, contains('HapticFeedback.vibrate'));
    });

    test(
      'the track switches and the haptics preference are honoured',
      () async {
        expect(
          await ring(track(sound: false)),
          isNot(contains('SystemSound.play')),
        );
        expect(
          await ring(track(sound: false)),
          contains('HapticFeedback.vibrate'),
        );

        final noVibration = await ring(track(vibration: false));
        expect(noVibration, contains('SystemSound.play'));
        expect(noVibration, isNot(contains('HapticFeedback.vibrate')));

        final noHaptics = await ring(track(), haptics: false);
        expect(noHaptics, contains('SystemSound.play'));
        expect(noHaptics, isNot(contains('HapticFeedback.vibrate')));

        expect(await ring(track(sound: false, vibration: false)), isEmpty);
      },
    );
  });
}
