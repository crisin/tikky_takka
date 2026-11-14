import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Source of "now" for the whole app.
///
/// Never call `DateTime.now()` outside of this file: every consumer takes a
/// [Clock] (directly or through [clockProvider]) so that the engine and the
/// repositories stay unit-testable.
abstract class Clock {
  const Clock();

  /// Current instant as UTC milliseconds since the Unix epoch.
  int nowMs();

  /// Milliseconds on a MONOTONIC clock with an arbitrary origin: it only
  /// ever moves forward at real speed and is not affected when the user,
  /// the network or a time-zone / DST rule changes the wall clock.
  ///
  /// Only differences are meaningful. `NowTicker` compares them with the
  /// differences of [nowMs] to notice a wall-clock jump. The default is the
  /// wall clock itself (no jump is ever detected).
  int monotonicMs() => nowMs();

  /// Current instant as a UTC [DateTime].
  DateTime nowUtc() =>
      DateTime.fromMillisecondsSinceEpoch(nowMs(), isUtc: true);

  /// Current instant as a local [DateTime].
  DateTime nowLocal() => DateTime.fromMillisecondsSinceEpoch(nowMs());
}

/// Wall clock of the device.
class SystemClock extends Clock {
  const SystemClock();

  static final Stopwatch _monotonic = Stopwatch()..start();

  @override
  int nowMs() => DateTime.now().millisecondsSinceEpoch;

  @override
  int monotonicMs() => _monotonic.elapsedMilliseconds;
}

/// Manually driven clock for tests.
class FakeClock extends Clock {
  FakeClock([this._ms = 0]);

  /// Creates a fake clock positioned at the given UTC date.
  FakeClock.at(DateTime start) : _ms = start.millisecondsSinceEpoch;

  int _ms;
  int _monotonicMs = 0;

  @override
  int nowMs() => _ms;

  @override
  int monotonicMs() => _monotonicMs;

  /// Jumps to an absolute instant (may move backwards to simulate clock
  /// changes). This is a WALL-CLOCK JUMP: real time ([monotonicMs]) does
  /// not move.
  void setMs(int ms) => _ms = ms;

  /// Lets time pass: wall clock and monotonic clock move together.
  void advanceMs(int ms) {
    _ms += ms;
    if (ms > 0) _monotonicMs += ms;
  }

  void advance(Duration d) => advanceMs(d.inMilliseconds);
}

/// The app-wide clock. Override in tests with a [FakeClock].
final clockProvider = Provider<Clock>((ref) => const SystemClock());
