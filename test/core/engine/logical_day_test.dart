import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/engine/engine.dart';

/// The logical day of the timeline: it starts at 06:00 by default.
void main() {
  const six = 6 * 60;
  int at(int y, int m, int d, int h, [int min = 0]) =>
      DateTime(y, m, d, h, min).millisecondsSinceEpoch;

  test('01:30 belongs to the day before, 06:00 starts the new one', () {
    expect(
      logicalDayOf(at(2026, 11, 15, 1, 30), six),
      const LocalDay(2026, 11, 14),
    );
    expect(
      logicalDayOf(at(2026, 11, 15, 5, 59), six),
      const LocalDay(2026, 11, 14),
    );
    expect(
      logicalDayOf(at(2026, 11, 15, 6), six),
      const LocalDay(2026, 11, 15),
    );
    expect(
      logicalDayOf(at(2026, 11, 15, 23, 59), six),
      const LocalDay(2026, 11, 15),
    );
    // Over the turn of a month and a year.
    expect(logicalDayOf(at(2027, 1, 1, 2), six), const LocalDay(2026, 12, 31));
    // A day that starts at midnight is the calendar day.
    expect(
      logicalDayOf(at(2026, 11, 15, 1, 30), 0),
      const LocalDay(2026, 11, 15),
    );
  });

  test('start and end of a logical day; next and previous', () {
    const day = LocalDay(2026, 11, 14);
    expect(logicalDayStartMs(day, six), at(2026, 11, 14, 6));
    expect(logicalDayEndMs(day, six), at(2026, 11, 15, 6));
    expect(logicalDayShift(day, 1), const LocalDay(2026, 11, 15));
    expect(
      logicalDayShift(const LocalDay(2026, 3, 1), -1),
      const LocalDay(2026, 2, 28),
    );
    for (final ms in [at(2026, 11, 14, 6), at(2026, 11, 15, 5, 59)]) {
      expect(logicalDayOf(ms, six), day);
    }
  });

  test('days with a clock change last 23 or 25 hours', () {
    for (final day in const [LocalDay(2026, 3, 28), LocalDay(2026, 10, 24)]) {
      final from = logicalDayStartMs(day, six);
      final to = logicalDayEndMs(day, six);
      // As long as the local zone says, whatever zone the test runs in.
      final shift =
          DateTime(
            day.year,
            day.month,
            day.day + 1,
            6,
          ).timeZoneOffset.inMilliseconds -
          DateTime(
            day.year,
            day.month,
            day.day,
            6,
          ).timeZoneOffset.inMilliseconds;
      expect(to - from, 24 * 3600 * 1000 - shift);
      expect(logicalDayOf(to - 1, six), day);
      expect(logicalDayOf(to, six), logicalDayShift(day, 1));
    }
  });
}
