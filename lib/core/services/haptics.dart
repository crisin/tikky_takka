import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/theme_controllers.dart';
import '../domain/track.dart';

/// System haptics, honouring the "Haptisches Feedback" preference.
///
/// All methods are fire-and-forget and never throw; on platforms without
/// haptics they do nothing.
class Haptics {
  const Haptics({required this.enabled});

  final bool enabled;

  Future<void> _run(Future<void> Function() feedback) async {
    if (!enabled) return;
    try {
      await feedback();
    } catch (_) {
      // No haptics on this platform.
    }
  }

  /// Light tick for selections, toggles, reordering.
  Future<void> selection() => _run(HapticFeedback.selectionClick);

  /// The primary lane button: start / pause / resume.
  Future<void> primary() => _run(HapticFeedback.lightImpact);

  /// A counted tap, lap or saved protocol entry.
  Future<void> tick() => _run(HapticFeedback.mediumImpact);

  /// Stop, reset, delete.
  Future<void> heavy() => _run(HapticFeedback.heavyImpact);

  /// Something became due while the app is open. Skipped when the track has
  /// vibration switched off.
  Future<void> alarm([Track? track]) {
    if (track != null && !track.vibration) return Future.value();
    return _run(() async {
      await HapticFeedback.heavyImpact();
      await HapticFeedback.vibrate();
    });
  }
}

/// Haptics configured from the UI preferences.
final hapticsProvider = Provider<Haptics>(
  (ref) => Haptics(enabled: ref.watch(uiPrefsProvider.select((p) => p.haptics))),
);
