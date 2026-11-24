import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
// The message classes live in the platform packages that `local_auth`
// pulls in; they are needed to give the system prompt German buttons.
// ignore: depend_on_referenced_packages
import 'package:local_auth_android/local_auth_android.dart'
    show AndroidAuthMessages, AuthMessages;
// ignore: depend_on_referenced_packages
import 'package:local_auth_darwin/local_auth_darwin.dart' show IOSAuthMessages;
// ignore: depend_on_referenced_packages
import 'package:local_auth_darwin/types/auth_messages_macos.dart'
    show MacOSAuthMessages;

import 'lock_service.dart';

/// Texts of the system authentication prompt (German). Kept here because
/// the prompt belongs to the OS, not to a widget.
abstract final class LockPromptStrings {
  static const title = 'App-Sperre';
  static const hint = 'Identität bestätigen';
  static const cancel = 'Abbrechen';
}

/// [LockService] backed by `local_auth` (v3): biometrics with fallback to
/// the device PIN / pattern / passcode, Windows Hello on Windows.
///
/// Register in `productionOverrides()`:
///
/// ```dart
/// lockServiceProvider.overrideWithValue(LocalAuthLockService()),
/// ```
///
/// [authenticate] never throws: every plugin failure (lockout,
/// cancellation, ...) is "not authenticated". [isSupported] answers `false`
/// only when that is certain (no implementation for the platform, or the
/// device reports that it cannot authenticate) and THROWS when the check
/// itself fails, so that a plugin hiccup can never open a locked app.
class LocalAuthLockService implements LockService {
  LocalAuthLockService({LocalAuthentication? auth, this.platform})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// Overrides the detected platform (tests); `null` = the real one.
  final TargetPlatform? platform;

  /// The prompt that is currently on screen, shared by concurrent callers:
  /// the plugin refuses a second prompt (`authInProgress`).
  Future<bool>? _pending;

  /// Platforms `local_auth` has an implementation for.
  bool get _platformSupported {
    if (kIsWeb) return false;
    return switch (platform ?? defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      TargetPlatform.linux || TargetPlatform.fuchsia => false,
    };
  }

  @override
  Future<bool> isSupported() async {
    if (!_platformSupported) return false;
    // True when the device can authenticate at all: biometrics OR a
    // device credential. A phone without any screen lock reports false.
    // Deliberately not caught: an exception is "unknown", not "no".
    return _auth.isDeviceSupported();
  }

  @override
  Future<bool> authenticate({required String reason}) {
    return _pending ??= _authenticate(reason)
        .whenComplete(() => _pending = null);
  }

  Future<bool> _authenticate(String reason) async {
    if (!_platformSupported) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: LockPromptStrings.title,
            signInHint: LockPromptStrings.hint,
            cancelButton: LockPromptStrings.cancel,
          ),
          IOSAuthMessages(cancelButton: LockPromptStrings.cancel),
          MacOSAuthMessages(cancelButton: LockPromptStrings.cancel),
        ],
        // Device PIN / pattern / passcode is an accepted fallback.
        biometricOnly: false,
        // Unlocking the app is not a payment: no extra confirmation step
        // after a successful face unlock.
        sensitiveTransaction: false,
        // If the app is backgrounded while the prompt is up, the plugin
        // retries on return instead of failing.
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    } catch (_) {
      // MissingPluginException, PlatformException, UnsupportedError, ...
      return false;
    }
  }
}
