import 'package:flutter/foundation.dart';

import '../../../core/domain/domain.dart';
import '../../../core/engine/engine.dart';
import '../../../l10n/strings.dart';
import '../tracks_strings.dart';

// Pure aggregation behind the "Zusammenfassung" of the tracks screen.
//
// Protocol entries are COUNTED, nothing else: no totals of amounts (they
// are free text), no rating, no comparison with anything.

/// How the lines of a group are ordered.
enum SummarySort {
  /// Most frequent first.
  count,

  /// Most recent first.
  last,
}

/// One counted thing: a quick label of a counter, or a substance of a
/// person.
@immutable
final class SummaryLine {
  const SummaryLine({
    required this.label,
    required this.count,
    required this.firstAt,
    required this.lastAt,
  });

  final String label;
  final int count;

  /// Wall time (UTC ms) of the first and the last occurrence.
  final int firstAt;
  final int lastAt;

  /// The average time between two occurrences; `null` with fewer than
  /// two.
  int? get averageGapMs => count < 2 ? null : (lastAt - firstAt) ~/ (count - 1);

  @override
  bool operator ==(Object other) =>
      other is SummaryLine &&
      other.label == label &&
      other.count == count &&
      other.firstAt == firstAt &&
      other.lastAt == lastAt;

  @override
  int get hashCode => Object.hash(label, count, firstAt, lastAt);

  @override
  String toString() => 'SummaryLine($label x$count, $firstAt..$lastAt)';
}

enum SummaryGroupKind { counter, stopwatch, protocolPerson }

/// The totals of one track (counter, stopwatch) or of one person on a
/// protocol track.
@immutable
final class SummaryGroup {
  const SummaryGroup({
    required this.kind,
    required this.track,
    required this.title,
    this.lines = const [],
    this.netMs = 0,
    this.lapCount = 0,
  });

  final SummaryGroupKind kind;
  final Track track;

  /// The track's name, or "Track · Person".
  final String title;

  /// Counter: one line per label. Protocol: one line per substance.
  final List<SummaryLine> lines;

  /// Stopwatch: net time of the sessions in range.
  final int netMs;

  /// Stopwatch: laps taken in range.
  final int lapCount;

  /// Sum of the counts of all lines.
  int get total => lines.fold(0, (sum, line) => sum + line.count);

  /// The most recent occurrence of any line; `null` without lines.
  int? get lastAt {
    int? last;
    for (final line in lines) {
      if (last == null || line.lastAt > last) last = line.lastAt;
    }
    return last;
  }
}

final class _Tally {
  int count = 0;
  int firstAt = 0;
  int lastAt = 0;

  void add(int at) {
    if (count == 0 || at < firstAt) firstAt = at;
    if (count == 0 || at > lastAt) lastAt = at;
    count++;
  }

  SummaryLine line(String label) =>
      SummaryLine(label: label, count: count, firstAt: firstAt, lastAt: lastAt);
}

int _compareLines(SummaryLine a, SummaryLine b, SummarySort sort) {
  final primary = switch (sort) {
    SummarySort.count => b.count.compareTo(a.count),
    SummarySort.last => b.lastAt.compareTo(a.lastAt),
  };
  if (primary != 0) return primary;
  final secondary = switch (sort) {
    SummarySort.count => b.lastAt.compareTo(a.lastAt),
    SummarySort.last => b.count.compareTo(a.count),
  };
  if (secondary != 0) return secondary;
  return a.label.compareTo(b.label);
}

List<SummaryLine> _sorted(Map<String, _Tally> tallies, SummarySort sort) =>
    [for (final e in tallies.entries) e.value.line(e.key)]
      ..sort((a, b) => _compareLines(a, b, sort));

/// Grouped totals of [sessions] (what
/// `HistoryRepository.watchSetActivity` delivers) for events at or after
/// [sinceMs] (`null` = all):
///
/// * counter: per label the count, first and last time and the average
///   gap; ticks without a label count as "Ohne Label";
/// * stopwatch: net time of the sessions and the number of laps;
/// * protocol: per person per substance the count, first and last time.
///
/// Groups follow the order of the tracks; the persons of a protocol track
/// and the lines of every group are ordered by [sort]. Tracks without
/// anything in range are left out; countdown, interval and reminder
/// tracks have no totals here.
List<SummaryGroup> buildSummary({
  required Iterable<HistorySession> sessions,
  int? sinceMs,
  SummarySort sort = SummarySort.count,
  Map<String, String> personNames = const {},
  Map<String, String> substanceNames = const {},
}) {
  bool inRange(TrackEvent e) => sinceMs == null || e.at >= sinceMs;

  final tracks = <String, Track>{};
  final counters = <String, Map<String, _Tally>>{};
  final stopwatchNet = <String, int>{};
  final stopwatchLaps = <String, int>{};
  // track id -> person id ('' = none) -> substance label -> tally
  final protocol = <String, Map<String, Map<String, _Tally>>>{};

  for (final item in sessions) {
    final track = item.track;
    if (track == null) continue;
    tracks[track.id] = track;
    switch (item.session.mode) {
      case TrackMode.counter:
        final byLabel = counters.putIfAbsent(track.id, () => {});
        for (final e in item.events) {
          if (e.type != EventType.tick || !inRange(e)) continue;
          final label = e.label;
          byLabel
              .putIfAbsent(
                label == null || label.isEmpty
                    ? TracksStrings.summaryNoLabel
                    : label,
                _Tally.new,
              )
              .add(e.at);
        }
      case TrackMode.stopwatch:
        stopwatchNet[track.id] =
            (stopwatchNet[track.id] ?? 0) + item.summary.netMs;
        stopwatchLaps[track.id] =
            (stopwatchLaps[track.id] ?? 0) +
            item.events
                .where((e) => e.type == EventType.lap && inRange(e))
                .length;
      case TrackMode.protocol:
        final byPerson = protocol.putIfAbsent(track.id, () => {});
        for (final e in item.events) {
          if (e.type != EventType.entry || !inRange(e)) continue;
          final substanceId = e.substanceId;
          byPerson
              .putIfAbsent(e.personId ?? '', () => {})
              .putIfAbsent(
                substanceId == null
                    ? Strings.protocolNoSubstance
                    : substanceNames[substanceId] ?? Strings.unknown,
                _Tally.new,
              )
              .add(e.at);
        }
      case TrackMode.countdown || TrackMode.interval || TrackMode.reminder:
        break;
    }
  }

  final ordered = tracks.values.toList()
    ..sort((a, b) {
      final byIndex = a.sortIndex.compareTo(b.sortIndex);
      return byIndex != 0 ? byIndex : a.name.compareTo(b.name);
    });

  final groups = <SummaryGroup>[];
  for (final track in ordered) {
    final byLabel = counters[track.id];
    if (byLabel != null && byLabel.isNotEmpty) {
      groups.add(
        SummaryGroup(
          kind: SummaryGroupKind.counter,
          track: track,
          title: track.name,
          lines: _sorted(byLabel, sort),
        ),
      );
    }
    if (stopwatchNet.containsKey(track.id)) {
      groups.add(
        SummaryGroup(
          kind: SummaryGroupKind.stopwatch,
          track: track,
          title: track.name,
          netMs: stopwatchNet[track.id] ?? 0,
          lapCount: stopwatchLaps[track.id] ?? 0,
        ),
      );
    }
    final byPerson = protocol[track.id];
    if (byPerson != null) {
      final personGroups =
          [
            for (final e in byPerson.entries)
              if (e.value.isNotEmpty)
                SummaryGroup(
                  kind: SummaryGroupKind.protocolPerson,
                  track: track,
                  title: TracksStrings.summaryPersonGroup(
                    track.name,
                    e.key.isEmpty
                        ? Strings.protocolNoPerson
                        : personNames[e.key] ?? Strings.unknown,
                  ),
                  lines: _sorted(e.value, sort),
                ),
          ]..sort((a, b) {
            final primary = switch (sort) {
              SummarySort.count => b.total.compareTo(a.total),
              SummarySort.last => (b.lastAt ?? 0).compareTo(a.lastAt ?? 0),
            };
            return primary != 0 ? primary : a.title.compareTo(b.title);
          });
      groups.addAll(personGroups);
    }
  }
  return groups;
}
