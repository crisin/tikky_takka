import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'clock.dart';

/// The one shared ticker behind all lanes: a [ValueListenable] of "now"
/// (UTC milliseconds from the app [Clock]).
///
/// * A single periodic timer drives every lane; it only runs while there is
///   at least one listener and the app is in the foreground.
/// * Listen with [NowBuilder] around the smallest possible subtree (the time
///   text), so nothing else rebuilds.
/// * Nothing is ever counted here: the value is just the clock reading and
///   is fed into the pure engine functions.
/// * While ticking in the foreground it compares how far the wall clock
///   moved with how far a monotonic clock moved. A difference of
///   [clockJumpThresholdMs] or more means the system time was changed
///   (by the user or the network); that is reported on [clockJumps]. The
///   event log is never rewritten: the app resyncs its alarms and tells
///   the user that running timers may be off.
class NowTicker extends ChangeNotifier implements ValueListenable<int> {
  NowTicker(this._clock, {this.interval = const Duration(milliseconds: 100)})
    : _value = _clock.nowMs(),
      _lastWallMs = _clock.nowMs(),
      _lastMonotonicMs = _clock.monotonicMs();

  /// Smallest disagreement between wall clock and monotonic clock that
  /// counts as "the system time was changed". Well above timer jitter and
  /// the small corrections of network time.
  static const int clockJumpThresholdMs = 2000;

  final Clock _clock;

  int _lastWallMs;
  int _lastMonotonicMs;
  final StreamController<int> _clockJumps = StreamController<int>.broadcast();

  /// Emits whenever the wall clock jumped while the app was in the
  /// foreground: the size of the jump in milliseconds (positive = forward).
  /// Time that merely passed - also in the background - is never a jump.
  Stream<int> get clockJumps => _clockJumps.stream;

  void _rebaseline() {
    _lastWallMs = _clock.nowMs();
    _lastMonotonicMs = _clock.monotonicMs();
  }

  void _detectJump(int wallMs) {
    final monotonicMs = _clock.monotonicMs();
    final jump = (wallMs - _lastWallMs) - (monotonicMs - _lastMonotonicMs);
    _lastWallMs = wallMs;
    _lastMonotonicMs = monotonicMs;
    if (_suspended || _clockJumps.isClosed) return;
    if (jump.abs() >= clockJumpThresholdMs) _clockJumps.add(jump);
  }

  /// Tick period. 100 ms is enough for a tenths display.
  final Duration interval;

  int _value;
  Timer? _timer;
  int _listeners = 0;
  bool _suspended = false;
  bool _disposed = false;

  /// The most recent clock reading. While the timer is not running (no
  /// listeners, or suspended) this reads the clock directly, so the value
  /// is never stale.
  @override
  int get value => _timer == null ? _clock.nowMs() : _value;

  /// Stops ticking while the app is in the background (called by the app
  /// shell on lifecycle changes). Resuming emits a fresh value at once.
  set suspended(bool suspended) {
    if (_suspended == suspended) return;
    _suspended = suspended;
    // The monotonic clock may stand still while the device sleeps: what
    // happened in the background is never compared.
    if (!suspended) _rebaseline();
    // Notify before the timer restarts: restarting re-reads the clock.
    if (!suspended) tickNow();
    _updateTimer();
  }

  bool get suspended => _suspended;

  /// Reads the clock and notifies listeners immediately (e.g. right after a
  /// command, so the lane does not wait for the next tick).
  void tickNow() {
    if (_disposed) return;
    final now = _clock.nowMs();
    _detectJump(now);
    if (now == _value) return;
    _value = now;
    notifyListeners();
  }

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _listeners++;
    _updateTimer();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (_listeners > 0) _listeners--;
    _updateTimer();
  }

  void _updateTimer() {
    final shouldRun = _listeners > 0 && !_suspended && !_disposed;
    if (shouldRun && _timer == null) {
      _value = _clock.nowMs();
      _timer = Timer.periodic(interval, (_) => tickNow());
    } else if (!shouldRun && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    unawaited(_clockJumps.close());
    super.dispose();
  }
}

/// The shared "now" ticker.
final nowTickerProvider = Provider<NowTicker>((ref) {
  final ticker = NowTicker(ref.watch(clockProvider));
  ref.onDispose(ticker.dispose);
  return ticker;
});

/// Rebuilds [builder] on every tick of the shared ticker with the current
/// time in UTC milliseconds.
///
/// Wrap ONLY what shows time (digits, progress bar, sub-line). With
/// [enabled] false the builder runs once with the current time and does not
/// subscribe - use it for idle and paused lanes so they cost nothing.
class NowBuilder extends ConsumerWidget {
  const NowBuilder({
    required this.builder,
    this.enabled = true,
    this.child,
    super.key,
  });

  final Widget Function(BuildContext context, int nowMs, Widget? child) builder;
  final bool enabled;
  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticker = ref.watch(nowTickerProvider);
    if (!enabled) return builder(context, ticker.value, child);
    return ValueListenableBuilder<int>(
      valueListenable: ticker,
      builder: builder,
      child: child,
    );
  }
}
