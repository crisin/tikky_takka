import 'package:flutter/foundation.dart';

import '../../../../l10n/formatters.dart';

// Pure logic of the time axis of the strip: which ticks, where, with
// which text. Unit tested. All times are UTC milliseconds; ticks sit on
// round LOCAL times.

const int _secondMs = 1000;
const int _minuteMs = 60 * _secondMs;
const int _hourMs = 60 * _minuteMs;

/// Length of a regular day; the step "one day" walks from local midnight
/// to local midnight instead (daylight saving).
const int stripDayMs = 24 * _hourMs;

/// The distances between two ticks the axis chooses from, below one day.
const List<int> stripAxisSteps = [
  _secondMs,
  2 * _secondMs,
  5 * _secondMs,
  10 * _secondMs,
  15 * _secondMs,
  30 * _secondMs,
  _minuteMs,
  2 * _minuteMs,
  5 * _minuteMs,
  10 * _minuteMs,
  15 * _minuteMs,
  30 * _minuteMs,
  _hourMs,
  2 * _hourMs,
  3 * _hourMs,
  6 * _hourMs,
  12 * _hourMs,
];

/// Whole days the axis chooses from beyond that.
const List<int> _daySteps = [1, 2, 7, 14, 28];

/// The smallest step whose ticks are at least [minSpacingPx] apart at
/// [msPerPx]: seconds when zoomed in, then minutes, hours and days.
int pickAxisStep(double msPerPx, double minSpacingPx) {
  final needed = msPerPx * minSpacingPx;
  for (final step in stripAxisSteps) {
    if (step >= needed) return step;
  }
  for (final days in _daySteps) {
    if (days * stripDayMs >= needed) return days * stripDayMs;
  }
  // Further out: whole multiples of four weeks.
  final blocks = (needed / (28 * stripDayMs)).ceil();
  return blocks * 28 * stripDayMs;
}

/// One tick of the axis.
@immutable
final class StripTick {
  const StripTick({
    required this.ms,
    required this.x,
    required this.label,
    this.isDay = false,
  });

  final int ms;

  /// Horizontal position in logical pixels.
  final double x;

  /// "14:05", "14:05:30", or the date for [isDay].
  final String label;

  /// Local midnight: the day separator, labelled with the date.
  final bool isDay;

  @override
  String toString() => 'StripTick($label @${x.toStringAsFixed(1)})';
}

/// The ticks of the visible stretch.
@immutable
final class StripAxis {
  const StripAxis({required this.stepMs, required this.ticks});

  final int stepMs;

  /// Left to right. Only ticks inside the width.
  final List<StripTick> ticks;

  /// The day separators among the ticks.
  Iterable<StripTick> get days => ticks.where((t) => t.isDay);
}

const _weekdays = ['Mo.', 'Di.', 'Mi.', 'Do.', 'Fr.', 'Sa.', 'So.'];

/// "Sa. 14.11.": the short date at a day separator.
String stripDayLabel(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${_weekdays[d.weekday - 1]} ${d.day}.${d.month}.';
}

int _midnight(int year, int month, int day) =>
    DateTime(year, month, day).millisecondsSinceEpoch;

/// The axis for the stretch that starts at [startMs] and is [width]
/// pixels wide at [msPerPx].
///
/// * Below one day the ticks count from local midnight of each day, so
///   they sit on round times; the tick at midnight is the day separator
///   and carries the date instead of "00:00".
/// * From one day on every tick is a local midnight.
/// * Labels show seconds only when the step is below one minute and
///   honour [use24h].
StripAxis computeAxis({
  required double startMs,
  required double msPerPx,
  required double width,
  required double minSpacingPx,
  bool use24h = true,
}) {
  if (width <= 0 || msPerPx <= 0) {
    return const StripAxis(stepMs: _secondMs, ticks: []);
  }
  final step = pickAxisStep(msPerPx, minSpacingPx);
  final endMs = startMs + width * msPerPx;
  final ticks = <StripTick>[];
  final first = DateTime.fromMillisecondsSinceEpoch(startMs.floor());

  void add(int ms, {required bool isDay}) {
    if (ms < startMs || ms > endMs) return;
    ticks.add(
      StripTick(
        ms: ms,
        x: (ms - startMs) / msPerPx,
        isDay: isDay,
        label: isDay
            ? stripDayLabel(ms)
            : Fmt.time(ms, use24h: use24h, seconds: step < _minuteMs),
      ),
    );
  }

  if (step >= stripDayMs) {
    final days = step ~/ stripDayMs;
    // Aligned to a fixed day count, so the ticks do not jump while
    // panning.
    final index = DateTime.utc(
      first.year,
      first.month,
      first.day,
    ).difference(DateTime.utc(1970)).inDays;
    var offset = -(index % days);
    while (true) {
      final ms = _midnight(first.year, first.month, first.day + offset);
      if (ms > endMs) break;
      add(ms, isDay: true);
      offset += days;
    }
    return StripAxis(stepMs: step, ticks: ticks);
  }

  var dayOffset = 0;
  while (true) {
    final dayStart = _midnight(first.year, first.month, first.day + dayOffset);
    if (dayStart > endMs) break;
    final nextDay = _midnight(
      first.year,
      first.month,
      first.day + dayOffset + 1,
    );
    var k = dayStart >= startMs ? 0 : ((startMs - dayStart) / step).ceil();
    while (true) {
      final ms = dayStart + k * step;
      if (ms >= nextDay || ms > endMs) break;
      add(ms, isDay: k == 0);
      k++;
    }
    dayOffset++;
  }
  return StripAxis(stepMs: step, ticks: ticks);
}
