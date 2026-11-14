import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen on ("Bildschirm anlassen"). The app shell drives this
/// from the UI preferences.
abstract class KeepAwakeService {
  /// Never throws; unsupported platforms ignore the call.
  Future<void> setEnabled(bool enabled);
}

/// Implementation on top of `wakelock_plus`.
class WakelockKeepAwake implements KeepAwakeService {
  const WakelockKeepAwake();

  @override
  Future<void> setEnabled(bool enabled) async {
    try {
      await WakelockPlus.toggle(enable: enabled);
    } catch (_) {
      // Not available on this platform / in tests.
    }
  }
}

/// Does nothing (tests).
class NoopKeepAwake implements KeepAwakeService {
  const NoopKeepAwake();

  @override
  Future<void> setEnabled(bool enabled) async {}
}

final keepAwakeServiceProvider = Provider<KeepAwakeService>(
  (ref) => const WakelockKeepAwake(),
);
