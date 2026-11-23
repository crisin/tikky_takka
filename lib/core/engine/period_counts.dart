import '../domain/domain.dart';
import 'history_math.dart';
import 'logical_day.dart';

// Counting protocol entries per logical day, for the week and the month
// of the timeline (Pult 3.3, 3.4). Only counts - nothing is judged.

/// The protocol entries of [sessions] grouped by the logical day they
/// belong to (a day starts [dayStartMinutes] after midnight), oldest
/// first. Sessions without a track are left out.
Map<LocalDay, List<TrackEvent>> entriesByLogicalDay(
  Iterable<HistorySession> sessions,
  int dayStartMinutes,
) {
  final result = <LocalDay, List<TrackEvent>>{};
  for (final item in sessions) {
    if (item.track?.mode != TrackMode.protocol) continue;
    for (final e in item.events) {
      if (e.type != EventType.entry) continue;
      result.putIfAbsent(logicalDayOf(e.at, dayStartMinutes), () => []).add(e);
    }
  }
  for (final list in result.values) {
    list.sort((a, b) => a.at.compareTo(b.at));
  }
  return result;
}

/// What an entry was, to count it per thing: the substance, else the
/// amount (`s:` / `a:` prefixed).
String entryThingKey(TrackEvent e) {
  final substance = e.substanceId;
  if (substance != null) return 's:$substance';
  return 'a:${(e.amount ?? '').trim()}';
}

/// How often each thing came in [entries], most first; the same count in
/// the order of the first entry.
List<(String, int)> thingTotals(Iterable<TrackEvent> entries) {
  final counts = <String, int>{};
  for (final e in entries) {
    final key = entryThingKey(e);
    counts[key] = (counts[key] ?? 0) + 1;
  }
  final keys = counts.keys.toList();
  final sorted = [...keys]
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : keys.indexOf(a) - keys.indexOf(b);
    });
  return [for (final k in sorted) (k, counts[k]!)];
}

/// ISO 8601 week number of the week starting on [monday].
int isoWeekNumber(LocalDay monday) {
  // The Thursday of a week decides which year the week belongs to.
  final thursday = DateTime.utc(monday.year, monday.month, monday.day + 3);
  final firstDay = DateTime.utc(thursday.year);
  return thursday.difference(firstDay).inDays ~/ 7 + 1;
}

/// The three figures of a month.
final class MonthFigures {
  const MonthFigures({
    required this.count,
    required this.daysWithEntry,
    required this.longestPauseDays,
  });

  final int count;
  final int daysWithEntry;

  /// The most days in a row without an entry.
  final int longestPauseDays;
}

/// The figures of the days from [first] to [last] (both included; for the
/// month going on: up to today) out of [counts] per day.
MonthFigures monthFigures(
  Map<LocalDay, int> counts,
  LocalDay first,
  LocalDay last,
) {
  var count = 0;
  var days = 0;
  var pause = 0;
  var longest = 0;
  for (var d = first; d.compareTo(last) <= 0; d = logicalDayShift(d, 1)) {
    final n = counts[d] ?? 0;
    count += n;
    if (n > 0) {
      days++;
      pause = 0;
    } else {
      pause++;
      if (pause > longest) longest = pause;
    }
  }
  return MonthFigures(
    count: count,
    daysWithEntry: days,
    longestPauseDays: longest,
  );
}

/// One of four steps of a day in the calendar: 0 without an entry, else
/// 1 to 3 by [count] against the most of the month ([max]).
int countLevel(int count, int max) {
  if (count <= 0 || max <= 0) return 0;
  // The most of the month is always the full step.
  if (count >= max) return 3;
  return (1 + (count - 1) * 3 ~/ max).clamp(1, 3);
}
