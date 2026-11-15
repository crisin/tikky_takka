import 'history_math.dart';

// The "logical" day of the timeline: it starts at a set time after
// midnight (06:00 by default), so what happens after midnight still
// belongs to the evening before. Pure functions over local calendar
// dates, so days with a clock change are 23 or 25 hours long.

/// The logical day the instant [ms] belongs to, when a day starts
/// [dayStartMinutes] after local midnight.
LocalDay logicalDayOf(int ms, int dayStartMinutes) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  if (d.hour * 60 + d.minute >= dayStartMinutes) {
    return LocalDay(d.year, d.month, d.day);
  }
  final before = DateTime(d.year, d.month, d.day - 1);
  return LocalDay(before.year, before.month, before.day);
}

/// Start of the logical [day] (UTC milliseconds).
int logicalDayStartMs(LocalDay day, int dayStartMinutes) => DateTime(
  day.year,
  day.month,
  day.day,
  dayStartMinutes ~/ 60,
  dayStartMinutes % 60,
).millisecondsSinceEpoch;

/// End of the logical [day]: the start of the next one.
int logicalDayEndMs(LocalDay day, int dayStartMinutes) => DateTime(
  day.year,
  day.month,
  day.day + 1,
  dayStartMinutes ~/ 60,
  dayStartMinutes % 60,
).millisecondsSinceEpoch;

/// The logical day [days] after [day] (before, when negative).
LocalDay logicalDayShift(LocalDay day, int days) {
  final d = DateTime(day.year, day.month, day.day + days);
  return LocalDay(d.year, d.month, d.day);
}
