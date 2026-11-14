import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repo/settings_store.dart';
import 'alarms/alarm_service.dart';

/// Device authentication (biometrics / device PIN) for the optional app
/// lock.
///
/// The `local_auth` implementation is `LocalAuthLockService` in
/// `lock_service_impl.dart`; it is registered in `main.dart`
/// (`productionOverrides`) with `lockServiceProvider.overrideWithValue(...)`.
/// Without that override the app runs with [NoopLockService]: the lock is
/// reported as unsupported, the setting is disabled and the app never
/// locks.
abstract class LockService {
  /// Whether this device can authenticate at all (has biometrics or a
  /// device credential, and the platform is supported). When `false` the
  /// setting is hidden / disabled and the app never locks.
  ///
  /// `false` must be a DEFINITE answer. When the check itself fails
  /// (plugin error, platform hiccup) this THROWS: an enabled lock then
  /// stays closed and offers a retry instead of silently opening.
  Future<bool> isSupported();

  /// Shows the system prompt. Returns `true` when the user authenticated.
  /// Must not throw: failures and cancellation are `false`.
  Future<bool> authenticate({required String reason});
}

/// No lock available: never supported, always "authenticated". Used in
/// tests and on unsupported platforms.
class NoopLockService implements LockService {
  const NoopLockService();

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<bool> authenticate({required String reason}) async => true;
}

/// The lock service in use. Defaults to [NoopLockService].
final lockServiceProvider = Provider<LockService>(
  (ref) => const NoopLockService(),
);

/// Whether the device supports the app lock.
///
/// Three outcomes: `true`, a definite `false` (the lock gate is disabled),
/// or an ERROR when the check itself failed. An error is never read as
/// "not supported": the gate stays closed and offers a retry
/// (`ref.invalidate(lockSupportedProvider)`). No automatic retries.
final lockSupportedProvider = FutureProvider<bool>(
  (ref) => ref.watch(lockServiceProvider).isSupported(),
  retry: (_, _) => null,
);

/// The "App-Sperre" switch. Persisted in the settings store.
class AppLockController extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(settingsStoreProvider).getBool(SettingsKeys.appLock);

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref
        .read(settingsStoreProvider)
        .setBool(SettingsKeys.appLock, enabled);
    // With the lock on, notifications must not show track names on the
    // lock screen; pending ones are rescheduled accordingly.
    try {
      await ref.read(alarmServiceProvider).setContentHidden(enabled);
    } catch (_) {
      // Alarm trouble never blocks the setting.
    }
  }
}

final appLockEnabledProvider = NotifierProvider<AppLockController, bool>(
  AppLockController.new,
);

/// What the system prompt is doing, shared by everything that asks for
/// authentication (the lock gate and the settings switch).
final class LockPromptState {
  const LockPromptState({
    this.active = false,
    this.successes = 0,
    this.failures = 0,
  });

  /// A system prompt is on screen right now.
  final bool active;

  /// Number of prompts the user passed since app start.
  final int successes;

  /// Number of prompts that failed or were cancelled since app start.
  final int failures;

  @override
  bool operator ==(Object other) =>
      other is LockPromptState &&
      other.active == active &&
      other.successes == successes &&
      other.failures == failures;

  @override
  int get hashCode => Object.hash(active, successes, failures);
}

/// Runs the system authentication prompt through the [LockService].
///
/// All callers go through here so that the lock gate knows about every
/// prompt: a prompt started by the settings switch must not make the gate
/// ask a second time, and any passed prompt unlocks the app.
class LockPromptController extends Notifier<LockPromptState> {
  Future<bool>? _pending;

  @override
  LockPromptState build() => const LockPromptState();

  /// Shows the prompt (or joins the one already on screen). Never throws;
  /// failure and cancellation are `false`.
  Future<bool> authenticate({required String reason}) =>
      _pending ??= _run(reason);

  Future<bool> _run(String reason) async {
    state = LockPromptState(
      active: true,
      successes: state.successes,
      failures: state.failures,
    );
    var ok = false;
    try {
      ok = await ref.read(lockServiceProvider).authenticate(reason: reason);
    } catch (_) {
      ok = false;
    } finally {
      _pending = null;
    }
    if (!ref.mounted) return ok;
    state = LockPromptState(
      successes: state.successes + (ok ? 1 : 0),
      failures: state.failures + (ok ? 0 : 1),
    );
    return ok;
  }
}

final lockPromptProvider =
    NotifierProvider<LockPromptController, LockPromptState>(
      LockPromptController.new,
    );
