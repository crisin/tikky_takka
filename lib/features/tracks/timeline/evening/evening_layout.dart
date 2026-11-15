import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../../core/domain/domain.dart';
import '../../../../core/engine/engine.dart';
import '../../../../l10n/strings.dart';
import '../strip/strip_model.dart';

// Pure layout of "Abend" (Pult 3.2): the time runs downwards, one column
// per person with its entries as small chips, on the left the time axis
// and a narrow column with the bars of the other tracks. Unit tested.
//
// Protocol data is only placed and counted, never judged.

/// The measures the layout needs, in logical pixels (from the tokens).
@immutable
final class EveningMetrics {
  const EveningMetrics({
    required this.axisWidth,
    required this.trackBar,
    required this.trackGap,
    required this.minTracksWidth,
    required this.chipHeight,
    required this.chipInset,
    required this.slotGap,
    required this.minPxPerHour,
    required this.minColumnWidth,
  });

  /// The column with the hours on the left.
  final double axisWidth;

  /// Width of the bar of a track, the space between two, and the least
  /// width of the column of the tracks.
  final double trackBar;
  final double trackGap;
  final double minTracksWidth;

  /// Height of an entry chip and its distance from the left edge of its
  /// column.
  final double chipHeight;
  final double chipInset;

  /// Two chips of a column closer than this (vertically) take the two
  /// places side by side.
  final double slotGap;

  /// The scale never gets closer than this; then the evening scrolls.
  final double minPxPerHour;
  final double minColumnWidth;
}

/// An entry as a chip of a person's column.
@immutable
final class EveningChip {
  const EveningChip({
    required this.event,
    required this.thing,
    required this.label,
    required this.colorArgb,
    required this.y,
    required this.x,
  });

  final TrackEvent event;

  /// What the entry was: the substance id, or the amount (`s:` / `a:`
  /// prefixed), so a chain can be found.
  final String thing;
  final String label;

  /// The colour of the substance; `null` = none.
  final int? colorArgb;

  /// Middle of the chip (from the top of the scale) and its left edge.
  final double y;
  final double x;
}

/// The column of one person.
@immutable
final class EveningColumn {
  const EveningColumn({
    required this.personId,
    required this.name,
    required this.colorArgb,
    required this.counts,
    required this.left,
    required this.width,
    required this.chips,
  });

  /// `null` for the entries without a person.
  final String? personId;
  final String name;
  final int? colorArgb;

  /// "Kippe 4 · Bier 3": per thing how often, most first.
  final List<(String, int)> counts;
  final double left;
  final double width;

  /// Oldest first.
  final List<EveningChip> chips;
}

/// The bar of a track in the column of the tracks.
@immutable
final class EveningTrackBar {
  const EveningTrackBar({
    required this.track,
    required this.x,
    required this.spans,
    required this.marks,
    required this.running,
  });

  final Track track;
  final double x;

  /// (top, bottom) of every stretch that counted.
  final List<(double, double)> spans;

  /// Laps and taps: thin lines across the bar.
  final List<double> marks;

  /// The last stretch still counts.
  final bool running;
}

/// An hour line of the scale.
@immutable
final class EveningHour {
  const EveningHour(this.ms, this.y);

  final int ms;
  final double y;
}

/// Everything "Abend" draws for one logical day.
final class EveningLayout {
  const EveningLayout({
    required this.startMs,
    required this.endMs,
    required this.height,
    required this.width,
    required this.tracksWidth,
    required this.columns,
    required this.trackBars,
    required this.hours,
    required this.firstAt,
  });

  static const empty = EveningLayout(
    startMs: 0,
    endMs: 0,
    height: 0,
    width: 0,
    tracksWidth: 0,
    columns: [],
    trackBars: [],
    hours: [],
    firstAt: null,
  );

  final int startMs;
  final int endMs;
  final double height;

  /// Whole width (more than the screen when there are many persons).
  final double width;
  final double tracksWidth;
  final List<EveningColumn> columns;
  final List<EveningTrackBar> trackBars;
  final List<EveningHour> hours;

  /// The first entry or start of the evening; `null` = nothing happened.
  final int? firstAt;

  bool get isEmpty => firstAt == null;

  double yOf(num ms) =>
      endMs <= startMs ? 0 : (ms - startMs) * height / (endMs - startMs);
}

/// What an entry was, to find its chain: the substance, else the amount.
String eveningThingOf(TrackEvent e) {
  final substance = e.substanceId;
  if (substance != null) return 's:$substance';
  return 'a:${(e.amount ?? '').trim()}';
}

const int _hourMs = 60 * 60 * 1000;
const int _halfHourMs = 30 * 60 * 1000;

/// Lays out the logical day from [fromMs] to [toMs] of [sessions] (what
/// `watchSetActivity` delivers for that range) in [width] x [height].
///
/// * The scale starts at the half hour before the first entry or start
///   and ends at the full hour after the last one - or after "now" while
///   the day is still going on. It fills [height]; below
///   [EveningMetrics.minPxPerHour] it grows and scrolls.
/// * One column per person in the order of their first entry; entries
///   without a person get a column "Ohne Person" at the end.
/// * Chips closer than [EveningMetrics.slotGap] take the second place of
///   their column.
EveningLayout layoutEvening({
  required Iterable<HistorySession> sessions,
  required int fromMs,
  required int toMs,
  required int nowMs,
  required double width,
  required double height,
  required EveningMetrics metrics,
  Map<String, Person> persons = const {},
  Map<String, Substance> substances = const {},
  Set<String> hiddenTrackIds = const {},
}) {
  final entries = <TrackEvent>[];
  final others = <HistorySession>[];
  int? first;
  int? last;
  void see(int at) {
    if (first == null || at < first!) first = at;
    if (last == null || at > last!) last = at;
  }

  for (final item in sessions) {
    final track = item.track;
    if (track == null || hiddenTrackIds.contains(track.id)) continue;
    if (track.mode == TrackMode.protocol) {
      for (final e in item.events) {
        if (e.type != EventType.entry) continue;
        if (e.at < fromMs || e.at >= toMs) continue;
        entries.add(e);
        see(e.at);
      }
      continue;
    }
    final start = item.session.startedAt;
    final end = item.session.endedAt ?? nowMs;
    if (end < fromMs || start >= toMs) continue;
    others.add(item);
    see(math.max(start, fromMs));
    see(math.min(end, toMs));
  }
  final firstAt = first;
  if (firstAt == null) return EveningLayout.empty;
  entries.sort(compareEvents);

  final live = nowMs >= fromMs && nowMs < toMs;
  final startMs = math.max(fromMs, firstAt - firstAt % _halfHourMs);
  var lastAt = last!;
  if (live) lastAt = math.max(lastAt, nowMs);
  // The full hour after the last moment (local hours, like the labels).
  final lastDate = DateTime.fromMillisecondsSinceEpoch(lastAt);
  final ceil = DateTime(
    lastDate.year,
    lastDate.month,
    lastDate.day,
    lastDate.hour + 1,
  ).millisecondsSinceEpoch;
  final endMs = math.min(toMs, math.max(ceil, startMs + _hourMs));
  final hoursSpan = (endMs - startMs) / _hourMs;
  final fullHeight = math.max(height, hoursSpan * metrics.minPxPerHour);
  double yOf(num ms) => (ms - startMs) * fullHeight / (endMs - startMs);

  // ---- the hours
  final hours = <EveningHour>[];
  final startDate = DateTime.fromMillisecondsSinceEpoch(startMs);
  for (var h = 0; ; h++) {
    final ms = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      startDate.hour + h,
    ).millisecondsSinceEpoch;
    if (ms > endMs) break;
    if (ms > startMs) hours.add(EveningHour(ms, yOf(ms)));
  }

  // ---- the column of the tracks
  others.sort((a, b) => a.session.startedAt.compareTo(b.session.startedAt));
  final trackOrder = <String>[];
  final byTrack = <String, List<HistorySession>>{};
  for (final item in others) {
    final id = item.track!.id;
    if (!byTrack.containsKey(id)) trackOrder.add(id);
    byTrack.putIfAbsent(id, () => []).add(item);
  }
  final tracksWidth = trackOrder.isEmpty
      ? 0.0
      : math.max(
          metrics.minTracksWidth,
          metrics.trackGap +
              trackOrder.length * (metrics.trackBar + metrics.trackGap),
        );
  final bars = <EveningTrackBar>[];
  for (var i = 0; i < trackOrder.length; i++) {
    final items = byTrack[trackOrder[i]]!;
    final spans = <(double, double)>[];
    final marks = <double>[];
    var running = false;
    for (final item in items) {
      final s = StripSession.from(item, nowMs);
      for (final span in s.activeSpans(nowMs)) {
        final a = math.max(span.from, startMs);
        final b = math.min(span.to, endMs);
        if (b <= a) continue;
        spans.add((yOf(a), yOf(b)));
      }
      if (s.isRunning) running = true;
      for (final e in item.events) {
        if (e.type != EventType.lap && e.type != EventType.tick) continue;
        if (e.at <= startMs || e.at >= endMs) continue;
        marks.add(yOf(e.at));
      }
    }
    bars.add(
      EveningTrackBar(
        track: items.first.track!,
        x:
            metrics.axisWidth +
            metrics.trackGap * 2 +
            i * (metrics.trackBar + metrics.trackGap),
        spans: spans,
        marks: marks,
        running: running,
      ),
    );
  }

  // ---- one column per person
  final order = <String?>[];
  final byPerson = <String?, List<TrackEvent>>{};
  for (final e in entries) {
    if (!byPerson.containsKey(e.personId)) order.add(e.personId);
    byPerson.putIfAbsent(e.personId, () => []).add(e);
  }
  // Without a person: at the end.
  if (order.remove(null)) order.add(null);
  final left0 = metrics.axisWidth + tracksWidth;
  final columnWidth = order.isEmpty
      ? 0.0
      : math.max(metrics.minColumnWidth, (width - left0) / order.length);

  String labelOf(TrackEvent e) {
    final id = e.substanceId;
    if (id != null) return substances[id]?.name ?? Strings.unknown;
    final amount = (e.amount ?? '').trim();
    return amount.isEmpty ? Strings.protocolNoSubstance : amount;
  }

  final columns = <EveningColumn>[];
  for (var c = 0; c < order.length; c++) {
    final personId = order[c];
    final list = byPerson[personId]!;
    final left = left0 + c * columnWidth;
    final slots = [left + metrics.chipInset];
    slots.add(left + metrics.chipInset + (columnWidth - metrics.chipInset) / 2);
    final lastY = [double.negativeInfinity, double.negativeInfinity];
    final chips = <EveningChip>[];
    final counts = <String, int>{};
    for (final e in list) {
      final y = yOf(e.at);
      var slot = 0;
      if (y - lastY[0] < metrics.slotGap) {
        slot = y - lastY[1] >= metrics.slotGap
            ? 1
            : (lastY[0] <= lastY[1] ? 0 : 1);
      }
      lastY[slot] = y;
      final label = labelOf(e);
      counts[label] = (counts[label] ?? 0) + 1;
      chips.add(
        EveningChip(
          event: e,
          thing: eveningThingOf(e),
          label: label,
          colorArgb: e.substanceId == null
              ? null
              : substances[e.substanceId]?.color,
          y: y,
          x: slots[slot],
        ),
      );
    }
    final person = personId == null ? null : persons[personId];
    // Most first; the same count in the order of the first entry.
    final keys = counts.keys.toList();
    final sorted = [...keys]
      ..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : keys.indexOf(a) - keys.indexOf(b);
      });
    columns.add(
      EveningColumn(
        personId: personId,
        name: personId == null
            ? Strings.protocolNoPerson
            : person?.name ?? Strings.unknown,
        colorArgb: person?.color,
        counts: [for (final k in sorted) (k, counts[k]!)],
        left: left,
        width: columnWidth,
        chips: chips,
      ),
    );
  }

  return EveningLayout(
    startMs: startMs,
    endMs: endMs,
    height: fullHeight,
    width: math.max(width, left0 + order.length * columnWidth),
    tracksWidth: tracksWidth,
    columns: columns,
    trackBars: bars,
    hours: hours,
    firstAt: firstAt,
  );
}

/// The entries of one thing of [column] (oldest first) - the chain that a
/// tap on a chip shows - and the end of the lockout the user set on it,
/// counted from its last entry; `null` when there is none.
({List<TrackEvent> entries, int? lockoutUntil}) eveningChain(
  EveningColumn column,
  String thing, {
  Map<String, Substance> substances = const {},
}) {
  final entries = [
    for (final c in column.chips)
      if (c.thing == thing) c.event,
  ];
  if (entries.isEmpty) return (entries: entries, lockoutUntil: null);
  final id = entries.last.substanceId;
  final lockout = id == null ? null : substances[id]?.lockoutMs;
  return (
    entries: entries,
    lockoutUntil: lockout == null || lockout <= 0
        ? null
        : entries.last.at + lockout,
  );
}
