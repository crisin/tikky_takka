import '../core/engine/history_math.dart';
import 'strings.dart';

/// Formatting of durations, times and dates (German). Pure and free of
/// locale initialisation, so it works in tests without set-up.
abstract final class Fmt {
  static String _two(int n) => n.toString().padLeft(2, '0');

  /// Stopwatch style, rounding DOWN: `02:03`, `1:02:03`, with [tenths]
  /// `02:03.4`. Negative values show as zero.
  static String clock(int ms, {bool tenths = false, bool alwaysHours = false}) {
    final value = ms < 0 ? 0 : ms;
    final totalSeconds = value ~/ 1000;
    final h = totalSeconds ~/ 3600;
    final m = totalSeconds % 3600 ~/ 60;
    final s = totalSeconds % 60;
    final base = h > 0 || alwaysHours
        ? '$h:${_two(m)}:${_two(s)}'
        : '${_two(m)}:${_two(s)}';
    return tenths ? '$base.${value % 1000 ~/ 100}' : base;
  }

  /// Countdown style: like [clock], but without [tenths] it rounds UP to
  /// the next full second, so a 10 minute timer shows `10:00` at the start
  /// and reaches `00:00` exactly when it is done.
  static String remaining(int ms, {bool tenths = false}) {
    final value = ms < 0 ? 0 : ms;
    if (tenths) return clock(value, tenths: true);
    return clock((value + 999) ~/ 1000 * 1000);
  }

  /// Always `hh:mm:ss` (CSV export).
  static String hms(int ms) {
    final totalSeconds = (ms < 0 ? 0 : ms) ~/ 1000;
    return '${_two(totalSeconds ~/ 3600)}:'
        '${_two(totalSeconds % 3600 ~/ 60)}:'
        '${_two(totalSeconds % 60)}';
  }

  /// Human duration with at most two units: `5 s`, `42 min`, `1 h 42 min`,
  /// `2 T 3 h`.
  static String compact(int ms) {
    final totalSeconds = (ms < 0 ? 0 : ms) ~/ 1000;
    final days = totalSeconds ~/ 86400;
    final hours = totalSeconds % 86400 ~/ 3600;
    final minutes = totalSeconds % 3600 ~/ 60;
    final seconds = totalSeconds % 60;
    if (days > 0) {
      return hours > 0
          ? '$days ${Strings.unitDaysShort} $hours ${Strings.unitHoursShort}'
          : '$days ${Strings.unitDaysShort}';
    }
    if (hours > 0) {
      return minutes > 0
          ? '$hours ${Strings.unitHoursShort} '
                '$minutes ${Strings.unitMinutesShort}'
          : '$hours ${Strings.unitHoursShort}';
    }
    if (minutes > 0) {
      return seconds > 0 && minutes < 10
          ? '$minutes ${Strings.unitMinutesShort} '
                '$seconds ${Strings.unitSecondsShort}'
          : '$minutes ${Strings.unitMinutesShort}';
    }
    return '$seconds ${Strings.unitSecondsShort}';
  }

  /// Like [compact] but in whole minutes, never with seconds: `1 h 42 min`,
  /// `42 min`, and `0 min` below one minute.
  static String coarse(int ms) {
    final totalMinutes = (ms < 0 ? 0 : ms) ~/ 60000;
    final days = totalMinutes ~/ 1440;
    final hours = totalMinutes % 1440 ~/ 60;
    final minutes = totalMinutes % 60;
    if (days > 0) {
      return hours > 0
          ? '$days ${Strings.unitDaysShort} $hours ${Strings.unitHoursShort}'
          : '$days ${Strings.unitDaysShort}';
    }
    if (hours > 0) {
      return minutes > 0
          ? '$hours ${Strings.unitHoursShort} '
                '$minutes ${Strings.unitMinutesShort}'
          : '$hours ${Strings.unitHoursShort}';
    }
    return '$minutes ${Strings.unitMinutesShort}';
  }

  /// `vor 1 h 42 min`, or `gerade eben` below one minute.
  static String ago(int ms) =>
      ms < 60000 ? Strings.justNow : Strings.ago(coarse(ms));

  /// Time of day of a UTC instant in local time: `21:05` or `9:05 PM`.
  static String time(int ms, {bool use24h = true, bool seconds = false}) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final sec = seconds ? ':${_two(d.second)}' : '';
    if (use24h) return '${_two(d.hour)}:${_two(d.minute)}$sec';
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$hour12:${_two(d.minute)}$sec ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  static const _weekdays = ['Mo.', 'Di.', 'Mi.', 'Do.', 'Fr.', 'Sa.', 'So.'];
  static const _months = [
    'Jan.',
    'Feb.',
    'März',
    'Apr.',
    'Mai',
    'Juni',
    'Juli',
    'Aug.',
    'Sept.',
    'Okt.',
    'Nov.',
    'Dez.',
  ];

  /// `11.11.2026`
  static String date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${_two(d.day)}.${_two(d.month)}.${d.year}';
  }

  /// `11.11.2026, 21:05`
  static String dateTime(int ms, {bool use24h = true}) =>
      '${date(ms)}, ${time(ms, use24h: use24h)}';

  /// `Mi., 11. Nov. 2026`
  static String dayLong(LocalDay day) {
    final d = day.start;
    return '${_weekdays[d.weekday - 1]}, ${d.day}. ${_months[d.month - 1]} '
        '${d.year}';
  }

  /// `Heute`, `Gestern`, or [dayLong]. [todayMs] is "now" from the app
  /// clock.
  static String dayHeader(LocalDay day, {required int todayMs}) {
    final today = LocalDay.fromMs(todayMs);
    if (day == today) return Strings.today;
    final t = today.start;
    final y = DateTime(t.year, t.month, t.day - 1);
    if (day == LocalDay(y.year, y.month, y.day)) return Strings.yesterday;
    return dayLong(day);
  }

  /// ISO 8601 in LOCAL time without offset: `2026-11-11T21:05:00`. Exports
  /// use [isoLocalWithOffset].
  static String isoLocal(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-'
        '${_two(d.day)}T${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';
  }

  /// ISO 8601 in LOCAL time WITH the UTC offset of that instant, for
  /// exports: `2026-11-11T21:05:00+01:00`. Unambiguous across time zones
  /// and daylight-saving changes.
  static String isoLocalWithOffset(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${isoLocal(ms)}${isoOffset(d.timeZoneOffset)}';
  }

  /// `+01:00`, `-03:30`, `+00:00`.
  static String isoOffset(Duration offset) {
    final minutes = offset.inMinutes;
    final abs = minutes.abs();
    return '${minutes < 0 ? '-' : '+'}${_two(abs ~/ 60)}:${_two(abs % 60)}';
  }

  /// File-name safe local timestamp: `2026-11-11_2105`.
  static String fileStamp(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${_two(d.month)}-${_two(d.day)}_'
        '${_two(d.hour)}${_two(d.minute)}';
  }
}
