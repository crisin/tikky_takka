import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/core/services/lock_service.dart';
import 'package:tikky_takka/core/services/screen_security.dart';
import 'package:tikky_takka/features/settings/lock_gate.dart';
import 'package:tikky_takka/features/tracks/tracks_screen.dart';
import 'package:tikky_takka/l10n/strings.dart';

import '../../support/test_app.dart';

/// A device whose support check can fail (throw), say no, or say yes.
class _Lock implements LockService {
  Object? checkError;
  bool supported = true;
  bool allow = true;
  int checks = 0;
  int prompts = 0;

  @override
  Future<bool> isSupported() async {
    checks++;
    final error = checkError;
    if (error != null) throw error;
    return supported;
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    prompts++;
    return allow;
  }
}

class _RecordingScreenSecurity implements ScreenSecurity {
  final List<bool> calls = [];

  @override
  Future<void> setSecure(bool secure) async => calls.add(secure);
}

void main() {
  Future<TestApp> start(
    WidgetTester tester,
    _Lock lock, {
    bool lockEnabled = true,
    _RecordingScreenSecurity? security,
  }) async {
    final app = await TestApp.create(
      tester,
      lockService: lock,
      extraOverrides: [
        if (security != null)
          screenSecurityProvider.overrideWithValue(security),
      ],
    );
    if (lockEnabled) {
      await tester.runAsync(
        () => app.settings.setBool(SettingsKeys.appLock, true),
      );
    }
    await app.pumpApp(tester);
    return app;
  }

  Future<void> settle(WidgetTester tester, TestApp app) async {
    await app.settle(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await app.settle(tester, rounds: 3);
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(LockGate)));

  testWidgets('an exception from the support check does NOT unlock: the '
      'app stays covered and offers a retry', (tester) async {
    final lock = _Lock()..checkError = PlatformException(code: 'boom');
    final app = await start(tester, lock);

    // Covered: the app content is not shown, no prompt was (or could be)
    // shown, and there is a way out that is not "unlock".
    expect(find.byType(TracksScreen), findsNothing);
    expect(find.text(LockStrings.checkFailed), findsOneWidget);
    expect(find.text(LockStrings.retry), findsOneWidget);
    expect(find.text(Strings.unlock), findsNothing);
    expect(lock.prompts, 0);
    expect(lock.checks, 1, reason: 'no silent retry loop');

    // Retrying while the check still fails changes nothing.
    await tester.tap(find.text(LockStrings.retry));
    await settle(tester, app);
    expect(lock.checks, 2);
    expect(find.byType(TracksScreen), findsNothing);
    expect(find.text(LockStrings.retry), findsOneWidget);

    // The check works again: the normal prompt runs and opens the app.
    lock.checkError = null;
    await tester.tap(find.text(LockStrings.retry));
    await settle(tester, app);
    expect(lock.checks, 3);
    expect(lock.prompts, 1);
    expect(find.byType(TracksScreen), findsOneWidget);
    expect(find.text(LockStrings.checkFailed), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed check followed by a refused prompt stays locked', (
    tester,
  ) async {
    final lock = _Lock()
      ..checkError = StateError('plugin')
      ..allow = false;
    final app = await start(tester, lock);
    lock.checkError = null;
    await tester.tap(find.text(LockStrings.retry));
    await settle(tester, app);

    expect(lock.prompts, 1);
    expect(find.byType(TracksScreen), findsNothing);
    expect(find.text(LockStrings.unlockFailed), findsOneWidget);
    expect(find.text(Strings.unlock), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('only a definite "not supported" disables the gate', (
    tester,
  ) async {
    final lock = _Lock()..supported = false;
    await start(tester, lock);

    expect(find.byType(TracksScreen), findsOneWidget);
    expect(find.text(Strings.appLocked), findsNothing);
    expect(lock.prompts, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a supported device is asked on launch and opens on success', (
    tester,
  ) async {
    final lock = _Lock();
    await start(tester, lock);
    expect(lock.prompts, 1);
    expect(find.byType(TracksScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with the lock off a failing check covers nothing', (
    tester,
  ) async {
    final lock = _Lock()..checkError = StateError('plugin');
    await start(tester, lock, lockEnabled: false);
    expect(find.byType(TracksScreen), findsOneWidget);
    expect(lock.prompts, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the window is marked secure exactly while the lock is '
      'enabled', (tester) async {
    final security = _RecordingScreenSecurity();
    final app = await start(tester, _Lock(), security: security);
    expect(security.calls, [true]);

    await tester.runAsync(
      () =>
          containerOf(tester).read(appLockEnabledProvider.notifier).set(false),
    );
    await settle(tester, app);
    expect(security.calls, [true, false]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without the lock the window is not secure', (tester) async {
    final security = _RecordingScreenSecurity();
    await start(tester, _Lock(), lockEnabled: false, security: security);
    expect(security.calls, [false]);
  });

  testWidgets('notifications hide their text while the lock is enabled: '
      'from launch, and as soon as the setting changes', (tester) async {
    final app = await start(tester, _Lock());
    expect(app.alarms.contentHidden, isTrue);

    final lock = containerOf(tester).read(appLockEnabledProvider.notifier);
    await tester.runAsync(() => lock.set(false));
    await settle(tester, app);
    expect(app.alarms.contentHidden, isFalse);

    await tester.runAsync(() => lock.set(true));
    await settle(tester, app);
    expect(app.alarms.contentHidden, isTrue);
    expect(tester.takeException(), isNull);
  });

  test('the platform screen security is a silent no-op off Android', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // No handler is registered for the channel: must not throw anywhere.
    await const PlatformScreenSecurity().setSecure(true);
    await const NoopScreenSecurity().setSecure(true);
  });

  test(
    'lockSupportedProvider: an exception is an error, never "false"',
    () async {
      final lock = _Lock()..checkError = StateError('plugin');
      final container = ProviderContainer(
        overrides: [lockServiceProvider.overrideWithValue(lock)],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(lockSupportedProvider.future),
        throwsStateError,
      );
      expect(container.read(lockSupportedProvider).hasError, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(lock.checks, 1, reason: 'no automatic retries');

      lock.checkError = null;
      container.invalidate(lockSupportedProvider);
      expect(await container.read(lockSupportedProvider.future), isTrue);
    },
  );
}
