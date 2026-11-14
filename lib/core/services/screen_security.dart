import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keeps the app's content out of screenshots and the recent-apps overview
/// while the app lock is enabled.
///
/// Only Android has such a switch (`FLAG_SECURE`, set by `MainActivity`
/// through a tiny method channel); everywhere else this does nothing. iOS
/// is covered by the lock gate itself, which hides the app as soon as it
/// becomes inactive.
abstract class ScreenSecurity {
  /// Never throws.
  Future<void> setSecure(bool secure);
}

/// Does nothing. Used in tests and on platforms without the feature.
class NoopScreenSecurity implements ScreenSecurity {
  const NoopScreenSecurity();

  @override
  Future<void> setSecure(bool secure) async {}
}

/// Talks to `MainActivity` on Android; a no-op on every other platform.
class PlatformScreenSecurity implements ScreenSecurity {
  const PlatformScreenSecurity();

  static const MethodChannel _channel = MethodChannel('tikky_takka/window');

  @override
  Future<void> setSecure(bool secure) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setSecure', secure);
    } catch (_) {
      // Older native side or no activity: the lock gate still covers the
      // app, only the screenshot protection is missing.
    }
  }
}

/// The screen security in use. Defaults to [NoopScreenSecurity]; the real
/// one is registered in `main.dart` (`productionOverrides`).
final screenSecurityProvider = Provider<ScreenSecurity>(
  (ref) => const NoopScreenSecurity(),
);
