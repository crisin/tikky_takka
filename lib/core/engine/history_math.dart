import '../domain/session.dart';
import '../domain/track.dart';
import '../domain/track_event.dart';
import '../domain/track_set.dart';
import 'summary.dart';

/// A session with everything history and export need to show it.
final class HistorySession {
  const HistorySession({
    required this.session,
    required this.events,
    required this.summary,
    this.track,
    this.set,
  });

  final Session session;

  /// Events of the session in chronological order.
  final List<TrackEvent> events;
  final SessionSummary summary;

  /// `null` if the track no longer exists.
  final Track? track;

  /// `null` if the set no longer exists.
  final TrackSet? set;
}

/// A calendar day (local time), comparable and usable as a map key.
final class LocalDay implements Comparable<LocalDay> {
  const LocalDay(this.year, this.month, this.day);

  /// The local calendar day containing the UTC instant [ms].
  factory LocalDay.fromMs(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return LocalDay(d.year, d.month, d.day);
  }

  final int year;
  final int month;
  final int day;

  /// Local midnight at the start of this day.
  DateTime get start => DateTime(year, month, day);

  /// UTC milliseconds of the start of this day.
  int get startMs => start.millisecondsSinceEpoch;

  /// UTC milliseconds of the start of the next day (DST safe).
  int get endMs => DateTime(year, month, day + 1).millisecondsSinceEpoch;

  /// The Monday of the ISO week this day belongs to.
  LocalDay get weekStart {
    final s = start;
    final monday = DateTime(s.year, s.month, s.day - (s.weekday - 1));
    return LocalDay(monday.year, monday.month, monday.day);
  }

  @override
  int compareTo(LocalDay other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalDay &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}

/// The sessions that started on one day.
final class HistoryDay {
  const HistoryDay({
    required this.day,
    required this.sessions,
    required this.totalNetMs,
  });

  final LocalDay day;

  /// Newest first.
  final List<HistorySession> sessions;

  /// Sum of the net durations of [sessions].
  final int totalNetMs;
}

/// Groups sessions by the local day they STARTED on (a session running over
/// midnight counts fully for its start day). Newest day first, newest
/// session first inside a day.
List<HistoryDay> groupSessionsByDay(Iterable<HistorySession> sessions) {
  final byDay = <LocalDay, List<HistorySession>>{};
  for (final s in sessions) {
    byDay.putIfAbsent(LocalDay.fromMs(s.session.startedAt), () => []).add(s);
  }
  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final day in days)
      HistoryDay(
        day: day,
        sessions: byDay[day]!
          ..sort((a, b) => b.session.startedAt.compareTo(a.session.startedAt)),
        totalNetMs: byDay[day]!.fold(0, (sum, s) => sum + s.summary.netMs),
      ),
  ];
}

/// Net time of one track in one period (a day, or a week identified by its
/// Monday).
final class TrackPeriodSum {
  const TrackPeriodSum({
    required this.period,
    required this.trackId,
    required this.netMs,
    required this.sessionCount,
    this.track,
  });

  /// The day, or the Monday of the week.
  final LocalDay period;
  final String trackId;
  final int netMs;
  final int sessionCount;
  final Track? track;
}

/// Daily net sums per track; newest day first, then by track sort order.
List<TrackPeriodSum> sumPerTrackPerDay(Iterable<HistorySession> sessions) =>
    _sumPerPeriod(sessions, (day) => day);

/// Weekly (Monday based) net sums per track; newest week first, then by
/// track sort order.
List<TrackPeriodSum> sumPerTrackPerWeek(Iterable<HistorySession> sessions) =>
    _sumPerPeriod(sessions, (day) => day.weekStart);

List<TrackPeriodSum> _sumPerPeriod(
  Iterable<HistorySession> sessions,
  LocalDay Function(LocalDay day) periodOf,
) {
  final net = <(LocalDay, String), int>{};
  final count = <(LocalDay, String), int>{};
  final tracks = <String, Track?>{};
  for (final s in sessions) {
    final key = (
      periodOf(LocalDay.fromMs(s.session.startedAt)),
      s.session.trackId,
    );
    net[key] = (net[key] ?? 0) + s.summary.netMs;
    count[key] = (count[key] ?? 0) + 1;
    tracks[s.session.trackId] ??= s.track;
  }
  final keys = net.keys.toList()
    ..sort((a, b) {
      final byPeriod = b.$1.compareTo(a.$1);
      if (byPeriod != 0) return byPeriod;
      final ta = tracks[a.$2];
      final tb = tracks[b.$2];
      final bySort = (ta?.sortIndex ?? 0).compareTo(tb?.sortIndex ?? 0);
      if (bySort != 0) return bySort;
      return a.$2.compareTo(b.$2);
    });
  return [
    for (final key in keys)
      TrackPeriodSum(
        period: key.$1,
        trackId: key.$2,
        netMs: net[key]!,
        sessionCount: count[key]!,
        track: tracks[key.$2],
      ),
  ];
}
