import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart';

import '../../../../core/domain/domain.dart';
import '../../../../core/engine/engine.dart';
import '../../../../l10n/strings.dart';
import '../../tracks_strings.dart';
import '../timeline_logic.dart';

// Pure layout model of the strip ("Streifen"): time runs left to right,
// one lane per track. Unit tested.
//
// Two steps:
// 1. [buildStripData] turns the sessions of a set into lanes with their
//    sessions, events and lockout bands - in TIME. It runs when the data
//    or a filter changes.
// 2. [layoutStrip] turns that into draw primitives for one viewport - in
//    PIXELS - and only for what the viewport shows. It runs for every
//    frame the painter draws, so it does no sorting and no text work.
//
// Protocol data is only placed, never judged: a lockout band exists only
// where the user set a lockout on the substance, and amounts are not
// touched at all.

/// What a marker stands for.
enum StripMarkerKind {
  /// A tap of a counter: a filled dot.
  tick,

  /// A protocol entry: a filled dot in the colour of the substance.
  entry,

  /// A lap of a stopwatch: a small tick.
  lap,

  /// A reminder that was acknowledged: a check mark.
  ack,

  /// Start, pause, resume, stop - only with "Start und Stopp".
  lifecycle,

  /// A countdown or an interval programme reached its end: a flag. Not
  /// an event of the log; derived from the session.
  finish,
}

/// An event of a lane.
@immutable
final class StripEvent {
  const StripEvent({
    required this.row,
    required this.kind,
    this.label,
    this.colorArgb,
    this.lockoutUntil,
  });

  /// The event with the same text as in the list.
  final TimelineRow row;
  final StripMarkerKind kind;

  /// Short text next to the marker when there is room: the label or the
  /// running count of a tick, the substance of an entry, the label of a
  /// lap.
  final String? label;

  /// Colour of the substance of an entry (ARGB); `null` = the colour of
  /// the track.
  final int? colorArgb;

  /// End of the lockout the USER set on the substance of this entry;
  /// `null` when there is none.
  final int? lockoutUntil;

  int get at => row.at;

  StripEvent withLabel(String? label) => StripEvent(
    row: row,
    kind: kind,
    label: label,
    colorArgb: colorArgb,
    lockoutUntil: lockoutUntil,
  );

  @override
  String toString() => 'StripEvent(${kind.name}, ${row.text} @$at)';
}

/// A session of a lane: when it ran and when it was paused.
final class StripSession {
  StripSession._({
    required this.source,
    required this.startAt,
    required this.endAt,
    required this.lastAt,
    required List<TimeSpan> closed,
    required this.runningSince,
    // ignore: prefer_initializing_formals
  }) : _closed = closed;

  /// [nowMs] only decides how an open session is read (it never lies
  /// before the last event).
  factory StripSession.from(HistorySession item, int nowMs) {
    final end = item.session.endedAt;
    final t = Timeline.build(item.events, end ?? nowMs);
    final start = t.startAt ?? item.session.startedAt;
    final stop = t.stopAt ?? end;
    final spans = List<TimeSpan>.of(t.activeSpans);
    int? runningSince;
    if (stop == null) {
      if (t.isRunning && spans.isNotEmpty) {
        runningSince = spans.removeLast().from;
      } else if (!t.isStarted) {
        // No events at all: an open session that simply runs.
        runningSince = start;
      }
    }
    var last = start;
    for (final e in item.events) {
      if (e.at > last) last = e.at;
    }
    return StripSession._(
      source: item,
      startAt: start,
      endAt: stop,
      lastAt: last,
      closed: [
        for (final s in spans)
          if (s.length > 0) s,
      ],
      runningSince: runningSince,
    );
  }

  final HistorySession source;
  final int startAt;

  /// `null` while the session is open.
  final int? endAt;

  /// Time of the last event (at least [startAt]).
  final int lastAt;
  final List<TimeSpan> _closed;

  /// Start of the stretch that is still counting; `null` when the session
  /// is paused or has ended.
  final int? runningSince;

  TrackConfig get config => source.session.config;
  bool get isOpen => endAt == null;
  bool get isRunning => runningSince != null;

  /// The end of the bar at [nowMs].
  int endOr(int nowMs) => endAt ?? math.max(nowMs, lastAt);

  /// The stretches during which the session counted, up to [nowMs].
  List<TimeSpan> activeSpans(int nowMs) {
    final since = runningSince;
    if (since == null) return _closed;
    return [..._closed, TimeSpan(since, math.max(since, endOr(nowMs)))];
  }

  /// The stretches during which the session was paused, up to [nowMs].
  List<TimeSpan> pausedSpans(int nowMs) {
    final result = <TimeSpan>[];
    var cursor = startAt;
    for (final s in activeSpans(nowMs)) {
      if (s.from > cursor) result.add(TimeSpan(cursor, s.from));
      if (s.to > cursor) cursor = s.to;
    }
    final end = endOr(nowMs);
    if (end > cursor) result.add(TimeSpan(cursor, end));
    return result;
  }

  /// Net counting time from the start until the instant [wallAt].
  int activeAt(int wallAt, int nowMs) {
    var sum = 0;
    for (final s in activeSpans(nowMs)) {
      if (wallAt <= s.from) break;
      sum += math.min(wallAt, s.to) - s.from;
    }
    return sum;
  }

  /// The instant at which the net counting time reached [targetActiveMs];
  /// `null` when it has not (yet) by [nowMs].
  int? wallAtActive(int targetActiveMs, int nowMs) {
    if (targetActiveMs <= 0) return startAt;
    var sum = 0;
    for (final s in activeSpans(nowMs)) {
      if (sum + s.length >= targetActiveMs) {
        return s.from + (targetActiveMs - sum);
      }
      sum += s.length;
    }
    return null;
  }

  int netMs(int nowMs) => activeAt(endOr(nowMs), nowMs);

  int pausedMs(int nowMs) => endOr(nowMs) - startAt - netMs(nowMs);
}

/// A lockout the user set, placed in time: from the entry to the entry
/// plus the lockout.
@immutable
final class StripBandData {
  const StripBandData({
    required this.from,
    required this.to,
    required this.colorArgb,
  });

  final int from;
  final int to;
  final int colorArgb;
}

/// One lane: a track, or below it a person of a protocol or a label of a
/// counter.
final class StripRowData {
  StripRowData({
    required this.id,
    required this.track,
    required this.title,
    required this.sessions,
    required this.events,
    this.isSub = false,
    this.dotArgb,
    this.bands = const [],
  }) : maxBandMs = bands.fold(0, (m, b) => math.max(m, b.to - b.from));

  /// Stable id (for keys): the track id, or `<track id>/p/<person id>` or
  /// `<track id>/l/<label>` for a sub-lane.
  final String id;
  final Track track;

  /// What the fixed gutter shows: the track name, the person, the label.
  final String title;

  /// A sub-lane: indented, lower, with a thin bar.
  final bool isSub;

  /// Colour of the dot in the gutter (the person's colour); `null` = the
  /// colour of the track.
  final int? dotArgb;

  /// Oldest start first.
  final List<StripSession> sessions;

  /// Oldest first.
  final List<StripEvent> events;

  /// Oldest start first.
  final List<StripBandData> bands;

  /// The longest band (to find the bands that reach into a viewport).
  final int maxBandMs;
}

/// Everything the strip shows, in time.
final class StripData {
  const StripData({
    required this.rows,
    required this.firstAt,
    required this.lastAt,
    required this.live,
    required this.eventCount,
    required this.hasActivity,
  });

  static const empty = StripData(
    rows: [],
    firstAt: null,
    lastAt: null,
    live: false,
    eventCount: 0,
    hasActivity: false,
  );

  final List<StripRowData> rows;

  /// Start of the first session (not before the start of the scope) and
  /// the end of the last one; `null` without rows.
  final int? firstAt;
  final int? lastAt;

  /// A session is still open: the content reaches up to "now".
  final bool live;

  /// Events on the lanes (lifecycle only when shown).
  final int eventCount;

  /// Whether the scope holds anything at all - also when every track is
  /// hidden.
  final bool hasActivity;

  bool get isEmpty => rows.isEmpty;

  /// Lanes in the order of [rows] with their heights summed up.
  double contentHeight(StripMetrics metrics) {
    var height = 0.0;
    for (final row in rows) {
      height += row.isSub ? metrics.subLaneHeight : metrics.laneHeight;
    }
    return height;
  }
}

/// The lanes of the strip for [sessions] (what
/// `HistoryRepository.watchSetActivity` delivers).
///
/// * One lane per track of [tracks] (in that order) that has a session,
///   except those in [hiddenTrackIds].
/// * A protocol track gets one sub-lane per person below it (in the order
///   of their first entry). A counter whose taps carry labels gets one
///   sub-lane per label with [expandCounterLabels]; otherwise everything
///   sits on the one lane.
/// * Events before [sinceMs] are left out, like in the list; running
///   numbers still count them. Start, pause, resume and stop become
///   markers only with [showLifecycle] - the bars show them anyway.
/// * A lockout band is made only for an entry whose substance carries a
///   lockout the user set.
StripData buildStripData({
  required List<Track> tracks,
  required Iterable<HistorySession> sessions,
  required int nowMs,
  int? sinceMs,
  Map<String, Person> persons = const {},
  Map<String, Substance> substances = const {},
  bool showLifecycle = false,
  Set<String> hiddenTrackIds = const {},
  bool expandCounterLabels = true,
}) {
  final sessionsByTrack = <String, List<StripSession>>{};
  for (final item in sessions) {
    if (item.track == null) continue;
    sessionsByTrack
        .putIfAbsent(item.session.trackId, () => [])
        .add(StripSession.from(item, nowMs));
  }
  if (sessionsByTrack.isEmpty) return StripData.empty;
  for (final list in sessionsByTrack.values) {
    list.sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  final rows = buildTimelineRows(
    sessions: sessions,
    personNames: {for (final p in persons.values) p.id: p.name},
    substanceNames: {for (final s in substances.values) s.id: s.name},
    newestFirst: false,
  );
  final eventsByTrack = <String, List<StripEvent>>{};
  final perLabel = <String, int>{};
  final perSession = <String, int>{};
  for (final row in rows) {
    final e = row.event;
    final StripEvent event;
    switch (row.kind) {
      case TimelineRowKind.tick:
        final label = e.label;
        if (label == null || label.isEmpty) {
          final n = (perSession[e.sessionId] ?? 0) + 1;
          perSession[e.sessionId] = n;
          event = StripEvent(row: row, kind: StripMarkerKind.tick, label: '$n');
        } else {
          final key = '${e.sessionId}\n$label';
          final n = (perLabel[key] ?? 0) + 1;
          perLabel[key] = n;
          perSession[e.sessionId] = (perSession[e.sessionId] ?? 0) + 1;
          event = StripEvent(row: row, kind: StripMarkerKind.tick, label: '$n');
        }
      case TimelineRowKind.lap:
        event = StripEvent(row: row, kind: StripMarkerKind.lap, label: e.label);
      case TimelineRowKind.entry:
        final substance = e.substanceId == null
            ? null
            : substances[e.substanceId];
        final lockout = substance?.lockoutMs;
        final amount = (e.amount ?? '').trim();
        event = StripEvent(
          row: row,
          kind: StripMarkerKind.entry,
          // The amount is the user's own text: shown, never interpreted.
          label:
              substance?.name ??
              (e.substanceId != null
                  ? Strings.unknown
                  : amount.isEmpty
                  ? null
                  : amount),
          colorArgb: substance?.color,
          lockoutUntil: lockout == null || lockout <= 0 ? null : e.at + lockout,
        );
      case TimelineRowKind.ack:
        event = StripEvent(row: row, kind: StripMarkerKind.ack);
      case TimelineRowKind.lifecycle:
        if (!showLifecycle) continue;
        event = StripEvent(row: row, kind: StripMarkerKind.lifecycle);
    }
    if (sinceMs != null && row.at < sinceMs) continue;
    eventsByTrack.putIfAbsent(row.track.id, () => []).add(event);
  }

  final result = <StripRowData>[];
  var eventCount = 0;
  int? firstAt;
  int? lastAt;
  var live = false;

  for (final track in tracks) {
    if (hiddenTrackIds.contains(track.id)) continue;
    final own = sessionsByTrack[track.id];
    if (own == null || own.isEmpty) continue;
    final events = eventsByTrack[track.id] ?? const <StripEvent>[];
    eventCount += events.length;
    for (final s in own) {
      final start = sinceMs == null ? s.startAt : math.max(s.startAt, sinceMs);
      if (firstAt == null || start < firstAt) firstAt = start;
      final end = s.endAt ?? s.lastAt;
      if (lastAt == null || end > lastAt) lastAt = end;
      if (s.isOpen) live = true;
    }

    if (track.mode == TrackMode.protocol) {
      result.add(
        StripRowData(
          id: track.id,
          track: track,
          title: track.name,
          sessions: own,
          events: [
            for (final e in events)
              if (e.kind == StripMarkerKind.lifecycle) e,
          ],
        ),
      );
      final byPerson = <String?, List<StripEvent>>{};
      for (final e in events) {
        if (e.kind != StripMarkerKind.entry) continue;
        byPerson.putIfAbsent(e.row.event.personId, () => []).add(e);
      }
      for (final entry in byPerson.entries) {
        final personId = entry.key;
        final person = personId == null ? null : persons[personId];
        result.add(
          StripRowData(
            id: '${track.id}/p/${personId ?? ''}',
            track: track,
            title: personId == null
                ? Strings.protocolNoPerson
                : person?.name ?? Strings.unknown,
            isSub: true,
            dotArgb: person?.color,
            sessions: own,
            events: entry.value,
            bands: [
              for (final e in entry.value)
                if (e.lockoutUntil case final until?)
                  StripBandData(
                    from: e.at,
                    to: until,
                    colorArgb: e.colorArgb ?? 0,
                  ),
            ],
          ),
        );
      }
      continue;
    }

    bool labelled(StripEvent e) =>
        e.kind == StripMarkerKind.tick && (e.row.event.label ?? '').isNotEmpty;

    if (track.mode == TrackMode.counter &&
        expandCounterLabels &&
        events.any(labelled)) {
      result.add(
        StripRowData(
          id: track.id,
          track: track,
          title: track.name,
          sessions: own,
          events: [
            for (final e in events)
              if (!labelled(e)) e,
          ],
        ),
      );
      final byLabel = <String, List<StripEvent>>{};
      final config = track.config;
      if (config is CounterConfig) {
        for (final label in config.labels) {
          byLabel[label] = [];
        }
      }
      for (final e in events) {
        if (labelled(e)) {
          byLabel.putIfAbsent(e.row.event.label!, () => []).add(e);
        }
      }
      for (final entry in byLabel.entries) {
        if (entry.value.isEmpty) continue;
        result.add(
          StripRowData(
            id: '${track.id}/l/${entry.key}',
            track: track,
            title: entry.key,
            isSub: true,
            sessions: own,
            events: entry.value,
          ),
        );
      }
      continue;
    }

    result.add(
      StripRowData(
        id: track.id,
        track: track,
        title: track.name,
        sessions: own,
        events: [
          for (final e in events)
            // On a single lane a counted label reads as its name.
            labelled(e) ? e.withLabel(e.row.event.label) : e,
        ],
      ),
    );
  }

  return StripData(
    rows: result,
    firstAt: firstAt,
    lastAt: lastAt,
    live: live,
    eventCount: eventCount,
    hasActivity: true,
  );
}

/// The measures the layout needs, in logical pixels (from the theme
/// tokens, already adjusted for density and text size).
@immutable
final class StripMetrics {
  const StripMetrics({
    required this.laneHeight,
    required this.subLaneHeight,
    required this.barHeight,
    required this.subBarHeight,
    required this.markerRadius,
    required this.markerGap,
    required this.clusterHeight,
    required this.clusterMinWidth,
    required this.labelGap,
    this.cullMargin = 48,
  });

  final double laneHeight;
  final double subLaneHeight;
  final double barHeight;
  final double subBarHeight;
  final double markerRadius;

  /// Markers closer than this (centre to centre) become a cluster.
  final double markerGap;
  final double clusterHeight;
  final double clusterMinWidth;

  /// Space between a marker and its text.
  final double labelGap;

  /// How far outside the viewport something may start and still be
  /// produced (so nothing pops in at the edges).
  final double cullMargin;
}

/// How a piece of a session bar is drawn.
enum StripBarKind {
  /// Counting: filled in the muted track colour.
  active,

  /// Paused: lighter and hatched.
  paused,

  /// A rest phase of an interval: the alternating, lighter shade.
  phaseAlt,
}

@immutable
final class StripBar {
  const StripBar({
    required this.rowIndex,
    required this.rect,
    required this.kind,
    required this.session,
    required this.thin,
    required this.touchesNow,
  });

  final int rowIndex;
  final Rect rect;
  final StripBarKind kind;
  final StripSession session;

  /// The thin bar of a sub-lane.
  final bool thin;

  /// The right edge is "now": the bar is still growing.
  final bool touchesNow;
}

@immutable
final class StripMarker {
  const StripMarker({
    required this.rowIndex,
    required this.center,
    required this.kind,
    required this.labelRoom,
    this.event,
    this.session,
  });

  final int rowIndex;
  final Offset center;
  final StripMarkerKind kind;

  /// Free width to the right of the marker for its text.
  final double labelRoom;

  /// The event; `null` for [StripMarkerKind.finish].
  final StripEvent? event;

  /// The session of a [StripMarkerKind.finish] marker.
  final StripSession? session;
}

/// Markers that would overlap, drawn as one pill with their number.
@immutable
final class StripCluster {
  const StripCluster({
    required this.rowIndex,
    required this.rect,
    required this.events,
  });

  final int rowIndex;
  final Rect rect;

  /// Oldest first.
  final List<StripEvent> events;

  int get count => events.length;
  int get fromMs => events.first.at;
  int get toMs => events.last.at;
}

@immutable
final class StripBand {
  const StripBand({
    required this.rowIndex,
    required this.rect,
    required this.colorArgb,
  });

  final int rowIndex;
  final Rect rect;
  final int colorArgb;
}

/// What a tap or the pointer met.
sealed class StripHit {
  const StripHit();
}

final class StripMarkerHit extends StripHit {
  const StripMarkerHit(this.marker);

  final StripMarker marker;
}

final class StripClusterHit extends StripHit {
  const StripClusterHit(this.cluster);

  final StripCluster cluster;
}

final class StripBarHit extends StripHit {
  const StripBarHit(this.bar);

  final StripBar bar;
}

/// The draw primitives of one viewport.
final class StripLayout {
  const StripLayout({
    required this.rowTops,
    required this.rowHeights,
    required this.bands,
    required this.bars,
    required this.markers,
    required this.clusters,
    required this.nowX,
  });

  /// Top edge and height of every lane (all lanes, also unseen ones).
  final List<double> rowTops;
  final List<double> rowHeights;
  final List<StripBand> bands;
  final List<StripBar> bars;
  final List<StripMarker> markers;
  final List<StripCluster> clusters;

  /// Position of the "now" line; may lie outside the width.
  final double nowX;

  /// What lies at [position]: the nearest marker within [slop], else a
  /// cluster, else a session bar.
  StripHit? hitTest(Offset position, {required double slop}) {
    StripMarker? nearest;
    var best = slop;
    for (final m in markers) {
      final d = (m.center - position).distance;
      if (d <= best) {
        best = d;
        nearest = m;
      }
    }
    if (nearest != null) return StripMarkerHit(nearest);
    for (final c in clusters) {
      if (c.rect.inflate(slop / 2).contains(position)) {
        return StripClusterHit(c);
      }
    }
    StripBar? paused;
    for (final b in bars) {
      // A thin bar is hard to hit: the whole height of its lane counts.
      final top = rowTops[b.rowIndex];
      final lane = Rect.fromLTRB(
        b.rect.left,
        top,
        b.rect.right,
        top + rowHeights[b.rowIndex],
      );
      if (!lane.contains(position)) continue;
      if (b.kind != StripBarKind.paused) return StripBarHit(b);
      paused ??= b;
    }
    return paused == null ? null : StripBarHit(paused);
  }
}

int _lowerBound<T>(List<T> list, num value, int Function(T item) key) {
  var lo = 0;
  var hi = list.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (key(list[mid]) < value) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return lo;
}

/// The primitives for the stretch that starts at [startMs] and is [width]
/// pixels wide at [msPerPx], as seen at [nowMs].
///
/// Only what touches the viewport (plus [StripMetrics.cullMargin]) is
/// produced. Markers of a lane that are closer than
/// [StripMetrics.markerGap] become a [StripCluster]; zooming in takes
/// them apart again.
StripLayout layoutStrip({
  required StripData data,
  required double startMs,
  required double msPerPx,
  required double width,
  required int nowMs,
  required StripMetrics metrics,
}) {
  final tops = <double>[];
  final heights = <double>[];
  var y = 0.0;
  for (final row in data.rows) {
    final h = row.isSub ? metrics.subLaneHeight : metrics.laneHeight;
    tops.add(y);
    heights.add(h);
    y += h;
  }
  double xOf(num ms) => (ms - startMs) / msPerPx;
  final nowX = msPerPx <= 0 ? 0.0 : xOf(nowMs);
  if (width <= 0 || msPerPx <= 0) {
    return StripLayout(
      rowTops: tops,
      rowHeights: heights,
      bands: const [],
      bars: const [],
      markers: const [],
      clusters: const [],
      nowX: nowX,
    );
  }

  final minX = -metrics.cullMargin;
  final maxX = width + metrics.cullMargin;
  final lo = startMs + minX * msPerPx;
  final hi = startMs + maxX * msPerPx;
  final gapMs = metrics.markerGap * msPerPx;

  final bands = <StripBand>[];
  final bars = <StripBar>[];
  final markers = <StripMarker>[];
  final clusters = <StripCluster>[];

  for (var r = 0; r < data.rows.length; r++) {
    final row = data.rows[r];
    final centerY = tops[r] + heights[r] / 2;
    final barH = row.isSub ? metrics.subBarHeight : metrics.barHeight;
    final barTop = centerY - barH / 2;

    // ---- lockout bands (only where the user set a lockout)
    if (row.bands.isNotEmpty) {
      var i = _lowerBound(row.bands, lo - row.maxBandMs, (b) => b.from);
      for (; i < row.bands.length; i++) {
        final band = row.bands[i];
        if (band.from > hi) break;
        if (band.to < lo) continue;
        bands.add(
          StripBand(
            rowIndex: r,
            rect: Rect.fromLTRB(
              math.max(minX, xOf(band.from)),
              tops[r],
              math.min(maxX, xOf(band.to)),
              tops[r] + heights[r],
            ),
            colorArgb: band.colorArgb,
          ),
        );
      }
    }

    // ---- session bars
    final finishes = <StripMarker>[];
    for (final s in row.sessions) {
      if (s.startAt > hi) break;
      final end = s.endOr(nowMs);
      if (end < lo) continue;
      final growing = s.isRunning;

      void bar(int from, int to, StripBarKind kind) {
        if (to < lo || from > hi || to < from) return;
        bars.add(
          StripBar(
            rowIndex: r,
            rect: Rect.fromLTRB(
              math.max(minX, xOf(from)),
              barTop,
              math.min(maxX, xOf(to)),
              barTop + barH,
            ),
            kind: kind,
            session: s,
            thin: row.isSub,
            touchesNow: growing && to >= end,
          ),
        );
      }

      final config = s.config;
      // Interval: work and rest phases alternate along the counting time.
      var work = 0;
      var cycle = 0;
      var total = 0;
      if (config is IntervalConfig && !row.isSub) {
        final rounds = config.rounds < 1 ? 1 : config.rounds;
        work = config.workMs < 0 ? 0 : config.workMs;
        final rest = config.restMs < 0 ? 0 : config.restMs;
        cycle = work + rest;
        total = rounds * work + (rounds - 1) * rest;
        // Phases thinner than a few pixels would only flicker.
        if (rest <= 0 || work <= 0 || math.min(work, rest) / msPerPx < 2) {
          cycle = 0;
        }
      }

      var activeBefore = 0;
      for (final span in s.activeSpans(nowMs)) {
        if (span.to >= lo && span.from <= hi) {
          if (cycle <= 0) {
            bar(span.from, span.to, StripBarKind.active);
          } else {
            var t = math.max(span.from, lo.floor());
            var a = activeBefore + (t - span.from);
            final stop = math.min(span.to, hi.ceil());
            while (t < stop) {
              var next = stop;
              var isWork = true;
              if (a < total) {
                final within = a % cycle;
                isWork = within < work;
                final boundary = math.min(
                  a - within + (isWork ? work : cycle),
                  total,
                );
                next = math.min(stop, t + (boundary - a));
              }
              if (next <= t) break;
              bar(
                t,
                next,
                isWork ? StripBarKind.active : StripBarKind.phaseAlt,
              );
              a += next - t;
              t = next;
            }
          }
        }
        activeBefore += span.length;
      }
      for (final span in s.pausedSpans(nowMs)) {
        bar(span.from, span.to, StripBarKind.paused);
      }

      // ---- where a countdown or an interval programme reached its end
      if (row.isSub) continue;
      void finish(int? at) {
        if (at == null || at < lo || at > hi || at > end) return;
        finishes.add(
          StripMarker(
            rowIndex: r,
            center: Offset(xOf(at), centerY),
            kind: StripMarkerKind.finish,
            labelRoom: 0,
            session: s,
          ),
        );
      }

      if (config is CountdownConfig && config.durationMs > 0) {
        final duration = config.durationMs;
        if (!config.autoRestart) {
          finish(s.wallAtActive(duration, nowMs));
        } else if (duration >= gapMs) {
          // Every completed cycle - unless they would sit on each other.
          var k = math.max(
            1,
            s.activeAt(math.max(s.startAt, lo.floor()), nowMs) ~/ duration,
          );
          while (true) {
            final at = s.wallAtActive(k * duration, nowMs);
            if (at == null || at > hi) break;
            finish(at);
            k++;
          }
        }
      } else if (config is IntervalConfig) {
        final rounds = config.rounds < 1 ? 1 : config.rounds;
        final w = config.workMs < 0 ? 0 : config.workMs;
        final p = config.restMs < 0 ? 0 : config.restMs;
        final whole = rounds * w + (rounds - 1) * p;
        if (whole > 0) finish(s.wallAtActive(whole, nowMs));
      }
    }

    // ---- events: markers, or clusters where they would overlap
    final events = row.events;
    final rowMarkers = <StripMarker>[];
    final rowClusters = <StripCluster>[];
    // (left edge, index into rowMarkers or -1): to measure the label room.
    final lefts = <double>[];
    final owners = <int>[];
    if (events.isNotEmpty) {
      var i = _lowerBound(events, lo, (e) => e.at);
      // A cluster that starts outside the viewport still counts all of
      // its events.
      while (i > 0 &&
          i < events.length &&
          events[i].at - events[i - 1].at < gapMs) {
        i--;
      }
      while (i < events.length) {
        if (events[i].at > hi) break;
        var j = i;
        while (j + 1 < events.length &&
            events[j + 1].at - events[j].at < gapMs) {
          j++;
        }
        if (j == i) {
          final x = xOf(events[i].at);
          lefts.add(x - metrics.markerRadius);
          owners.add(rowMarkers.length);
          rowMarkers.add(
            StripMarker(
              rowIndex: r,
              center: Offset(x, centerY),
              kind: events[i].kind,
              labelRoom: double.infinity,
              event: events[i],
            ),
          );
        } else {
          final left = math.max(minX, xOf(events[i].at));
          final right = math.min(maxX, xOf(events[j].at));
          final middle = (left + right) / 2;
          final half = math.max(
            (right - left) / 2 + metrics.markerRadius,
            metrics.clusterMinWidth / 2,
          );
          final rect = Rect.fromLTRB(
            middle - half,
            centerY - metrics.clusterHeight / 2,
            middle + half,
            centerY + metrics.clusterHeight / 2,
          );
          lefts.add(rect.left);
          owners.add(-1);
          rowClusters.add(
            StripCluster(
              rowIndex: r,
              rect: rect,
              events: events.sublist(i, j + 1),
            ),
          );
        }
        i = j + 1;
      }
    }
    for (var k = 0; k < owners.length; k++) {
      final index = owners[k];
      if (index < 0) continue;
      final m = rowMarkers[index];
      final nextLeft = k + 1 < lefts.length ? lefts[k + 1] : double.infinity;
      rowMarkers[index] = StripMarker(
        rowIndex: m.rowIndex,
        center: m.center,
        kind: m.kind,
        event: m.event,
        labelRoom: math.max(
          0,
          nextLeft -
              (m.center.dx + metrics.markerRadius) -
              2 * metrics.labelGap,
        ),
      );
    }
    markers
      ..addAll(finishes)
      ..addAll(rowMarkers);
    clusters.addAll(rowClusters);
  }

  return StripLayout(
    rowTops: tops,
    rowHeights: heights,
    bands: bands,
    bars: bars,
    markers: markers,
    clusters: clusters,
    nowX: nowX,
  );
}

/// The start and the end of the range the strip can show; `null` when
/// there is nothing.
({int start, int end})? stripExtent(StripData data) {
  final first = data.firstAt;
  final last = data.lastAt;
  if (first == null || last == null) return null;
  return (start: first, end: math.max(first, last));
}

/// Hover / semantics text of a cluster: "12 Einträge".
String stripClusterText(StripCluster cluster) =>
    TracksStrings.stripCluster(cluster.count);
