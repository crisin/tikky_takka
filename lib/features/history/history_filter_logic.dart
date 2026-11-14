import '../../core/domain/domain.dart';
import '../../core/engine/engine.dart';
import '../../core/repo/models.dart';
import '../../l10n/formatters.dart';
import '../../l10n/strings.dart';
import 'history_strings.dart';

/// The date range choices of the history filter.
enum DatePreset {
  all,
  today,
  yesterday,
  thisWeek,
  last7Days,
  thisMonth,
  lastMonth,
  custom;

  /// The presets offered in the picker, in display order ([custom] last).
  static const List<DatePreset> choices = [
    all,
    today,
    yesterday,
    thisWeek,
    last7Days,
    thisMonth,
    lastMonth,
    custom,
  ];

  String get label => switch (this) {
    DatePreset.all => Strings.allTime,
    DatePreset.today => Strings.today,
    DatePreset.yesterday => Strings.yesterday,
    DatePreset.thisWeek => HistoryStrings.presetThisWeek,
    DatePreset.last7Days => HistoryStrings.presetLast7Days,
    DatePreset.thisMonth => HistoryStrings.presetThisMonth,
    DatePreset.lastMonth => HistoryStrings.presetLastMonth,
    DatePreset.custom => HistoryStrings.presetCustom,
  };
}

/// A half-open time span in UTC milliseconds: [fromMs] inclusive, [toMs]
/// exclusive; `null` = open on that side. Matches `HistoryFilter`.
final class DateSpan {
  const DateSpan(this.fromMs, this.toMs);

  static const DateSpan unbounded = DateSpan(null, null);

  final int? fromMs;
  final int? toMs;

  @override
  bool operator ==(Object other) =>
      other is DateSpan && other.fromMs == fromMs && other.toMs == toMs;

  @override
  int get hashCode => Object.hash(fromMs, toMs);

  @override
  String toString() => 'DateSpan($fromMs, $toMs)';
}

/// Pure date arithmetic and descriptions for the history filter. All
/// boundaries are local midnights (DST safe: built from calendar fields,
/// never by adding 24 hours).
abstract final class HistoryFilterLogic {
  static int _midnight(int year, int month, int day) =>
      DateTime(year, month, day).millisecondsSinceEpoch;

  /// The span of [preset] relative to [nowMs]. [DatePreset.custom] has no
  /// span of its own and yields [DateSpan.unbounded].
  static DateSpan spanOf(DatePreset preset, int nowMs) {
    final today = LocalDay.fromMs(nowMs);
    final y = today.year;
    final m = today.month;
    final d = today.day;
    switch (preset) {
      case DatePreset.all || DatePreset.custom:
        return DateSpan.unbounded;
      case DatePreset.today:
        return DateSpan(_midnight(y, m, d), _midnight(y, m, d + 1));
      case DatePreset.yesterday:
        return DateSpan(_midnight(y, m, d - 1), _midnight(y, m, d));
      case DatePreset.thisWeek:
        final monday = today.weekStart;
        return DateSpan(
          monday.startMs,
          _midnight(monday.year, monday.month, monday.day + 7),
        );
      case DatePreset.last7Days:
        return DateSpan(_midnight(y, m, d - 6), _midnight(y, m, d + 1));
      case DatePreset.thisMonth:
        return DateSpan(_midnight(y, m, 1), _midnight(y, m + 1, 1));
      case DatePreset.lastMonth:
        return DateSpan(_midnight(y, m - 1, 1), _midnight(y, m, 1));
    }
  }

  /// The span from the start of [firstDay] to the end of [lastDay] (both
  /// inclusive, in any order).
  static DateSpan spanOfDays(DateTime firstDay, DateTime lastDay) {
    final a = firstDay.isAfter(lastDay) ? lastDay : firstDay;
    final b = firstDay.isAfter(lastDay) ? firstDay : lastDay;
    return DateSpan(
      _midnight(a.year, a.month, a.day),
      _midnight(b.year, b.month, b.day + 1),
    );
  }

  /// Which preset [filter]'s date range corresponds to right now;
  /// [DatePreset.custom] when it matches none.
  static DatePreset presetOf(HistoryFilter filter, int nowMs) {
    final span = DateSpan(filter.fromMs, filter.toMs);
    for (final preset in DatePreset.choices) {
      if (preset == DatePreset.custom) continue;
      if (spanOf(preset, nowMs) == span) return preset;
    }
    return DatePreset.custom;
  }

  /// The last day covered by a span ending (exclusively) at [toMs].
  static DateTime lastDayOf(int toMs) {
    final end = DateTime.fromMillisecondsSinceEpoch(toMs);
    final exact =
        end.hour == 0 &&
        end.minute == 0 &&
        end.second == 0 &&
        end.millisecond == 0;
    return DateTime(end.year, end.month, exact ? end.day - 1 : end.day);
  }

  /// Short text for the date range of [filter]: the preset name, or the
  /// dates of a custom range.
  static String describeDates(HistoryFilter filter, int nowMs) {
    final preset = presetOf(filter, nowMs);
    if (preset != DatePreset.custom) return preset.label;
    final from = filter.fromMs;
    final to = filter.toMs;
    final toText = to == null
        ? null
        : Fmt.date(lastDayOf(to).millisecondsSinceEpoch);
    if (from == null) return HistoryStrings.dateUntil(toText!);
    if (toText == null) return HistoryStrings.dateFrom(Fmt.date(from));
    final fromText = Fmt.date(from);
    return fromText == toText
        ? fromText
        : HistoryStrings.dateRange(fromText, toText);
  }

  /// Text for the set restriction of [filter].
  static String describeSet(HistoryFilter filter, Iterable<TrackSet> sets) {
    final id = filter.setId;
    if (id == null) return Strings.allSets;
    for (final set in sets) {
      if (set.id == id) return set.name;
    }
    return Strings.unknown;
  }

  /// Text for the track restriction of [filter]: the name of a single
  /// track, or how many are selected.
  static String describeTracks(HistoryFilter filter, Iterable<Track> tracks) {
    final ids = filter.trackIds;
    if (ids.isEmpty) return Strings.allTracks;
    if (ids.length == 1) {
      for (final track in tracks) {
        if (track.id == ids.first) return track.name;
      }
    }
    return HistoryStrings.tracksSelected(ids.length);
  }

  /// One line describing every active restriction, or `null` when the
  /// filter is unrestricted ("Heute · Büro · 2 Spuren").
  static String? describe(
    HistoryFilter filter, {
    required int nowMs,
    required Iterable<TrackSet> sets,
    required Iterable<Track> tracks,
  }) {
    if (filter.isUnrestricted) return null;
    return HistoryStrings.joined([
      if (filter.fromMs != null || filter.toMs != null)
        describeDates(filter, nowMs),
      if (filter.setId != null) describeSet(filter, sets),
      if (filter.trackIds.isNotEmpty) describeTracks(filter, tracks),
    ]);
  }

  /// [filter] restricted to [setId] (or to all sets with `null`). Selected
  /// tracks that are not part of the new set are dropped.
  static HistoryFilter withSet(
    HistoryFilter filter,
    String? setId,
    Iterable<Track> tracks,
  ) {
    if (setId == null) return filter.copyWith(setId: () => null);
    final inSet = {
      for (final track in tracks)
        if (track.setId == setId) track.id,
    };
    return filter.copyWith(
      setId: () => setId,
      trackIds: filter.trackIds.intersection(inSet),
    );
  }

  /// ISO 8601 week number of the week starting on [monday].
  static int isoWeekNumber(LocalDay monday) {
    // The Thursday of a week decides which year the week belongs to.
    final thursday = DateTime.utc(monday.year, monday.month, monday.day + 3);
    final firstDay = DateTime.utc(thursday.year);
    return thursday.difference(firstDay).inDays ~/ 7 + 1;
  }

  /// The Sunday closing the week that starts on [monday].
  static LocalDay weekEnd(LocalDay monday) {
    final end = DateTime(monday.year, monday.month, monday.day + 6);
    return LocalDay(end.year, end.month, end.day);
  }
}
