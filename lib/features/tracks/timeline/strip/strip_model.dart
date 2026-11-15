import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart';

import '../../../../core/domain/domain.dart';
import '../../../../core/engine/engine.dart';
import '../../../../l10n/strings.dart';
import '../../tracks_strings.dart';
import '../timeline_logic.dart';
import 'strip_viewport.dart';

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
    this.previousAt,
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

  /// Time of the entry before this one on the same substance lane; `null`
  /// for the first one and on other lanes.
  final int? previousAt;

  int get at => row.at;

  StripEvent withLabel(String? label) => StripEvent(
    row: row,
    kind: kind,
    label: label,
    colorArgb: colorArgb,
    lockoutUntil: lockoutUntil,
    previousAt: previousAt,
  );

  StripEvent withPrevious(int? previousAt) => StripEvent(
    row: row,
    kind: kind,
    label: label,
    colorArgb: colorArgb,
    lockoutUntil: lockoutUntil,
    previousAt: previousAt,
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

  /// The stretches that counted and are over (not the running one).
  List<TimeSpan> get closedSpans => _closed;

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

/// What a lane stands for; decides its height and how it is drawn.
enum StripRowKind {
  /// A track: its name, then a compact bar.
  track,

  /// A person of a protocol: only the name while open (its things
  /// follow); folded, all its entries on one line with a word below each.
  person,

  /// A substance of a person, or a label of a counter: its name, then a
  /// line with the markers.
  thing,
}

/// One lane: a track, a person of a protocol, a substance of that person,
/// or a label of a counter.
final class StripRowData {
  StripRowData({
    required this.id,
    required this.track,
    required this.title,
    required this.sessions,
    required this.events,
    this.kind = StripRowKind.track,
    this.folded = false,
    this.indent = 0,
    this.dotArgb,
    this.bands = const [],
    this.timerFrom,
    this.barFrom,
    this.showGaps = false,
  }) : maxBandMs = bands.fold(0, (m, b) => math.max(m, b.to - b.from)),
       gapEvents = showGaps
           ? [
               for (final e in events)
                 if (e.kind != StripMarkerKind.lifecycle) e,
             ]
           : const [];

  /// Stable id (for keys): the track id, or for a lane below it
  /// `<track id>/p/<person id>` (a person of a protocol),
  /// `<track id>/p/<person id>/s/<substance id>` (a substance of that
  /// person) or `<track id>/l/<label>` (a label of a counter).
  final String id;
  final Track track;

  /// What the line above the lane names: the track, the person, the
  /// substance, the label.
  final String title;
  final StripRowKind kind;

  /// A person whose things are folded onto one line.
  final bool folded;

  /// A lane below a track: lower, with a thin line instead of a bar.
  bool get isSub => kind != StripRowKind.track;

  /// A lane of a person (open or folded).
  bool get isPerson => kind == StripRowKind.person;

  /// How far the name is indented (0 = a track or a person, 1 = a thing).
  final int indent;

  /// The time the timer of the lane counts from: the last entry of a
  /// substance while its protocol has an open session. `null` = no timer.
  final int? timerFrom;

  /// The line of the lane starts here (the first entry of a substance);
  /// `null` = with the session.
  final int? barFrom;

  /// The time between two neighbouring markers is written between them,
  /// and - with [timerFrom] - the time from the last one up to "now".
  final bool showGaps;

  /// The events that take part in [showGaps] (oldest first).
  final List<StripEvent> gapEvents;

  /// End of the lockout the user set that started with the last entry of
  /// the lane; `null` when there is none.
  int? get lockoutUntil => bands.isEmpty ? null : bands.last.to;

  /// Colour of the dot next to the name (the person's, the substance's);
  /// `null` = the colour of the track.
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
      height += metrics.heightOf(row);
    }
    return height;
  }
}

/// The lanes of the strip for [sessions] (what
/// `HistoryRepository.watchSetActivity` delivers).
///
/// * The persons of the protocol tracks come first (see [_protocolRows]),
///   then one lane per other track of [tracks] (in that order) that has a
///   session, except those in [hiddenTrackIds].
/// * A person is open when [openPersons] holds the id of its lane, or
///   when [openPersons] is `null` (nothing remembered yet).
/// * A counter whose taps carry labels gets one lane per label with
///   [expandCounterLabels]; otherwise everything sits on the one lane.
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
  Set<String>? openPersons,
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

  final personRows = <StripRowData>[];
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
      final (own: trackRow, :people) = _protocolRows(
        track: track,
        sessions: own,
        events: events,
        persons: persons,
        substances: substances,
        openPersons: openPersons,
      );
      personRows.addAll(people);
      if (trackRow != null) result.add(trackRow);
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
            kind: StripRowKind.thing,
            indent: 1,
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
    rows: [...personRows, ...result],
    firstAt: firstAt,
    lastAt: lastAt,
    live: live,
    eventCount: eventCount,
    hasActivity: true,
  );
}

/// The lanes of a protocol track: one per person (in the order of their
/// first entry; entries without a person under "Ohne Person"), and below
/// an open person one lane per substance with its own timer.
///
/// * Substances are in the order of their first entry; entries without a
///   substance go to a lane "Ohne Angabe".
/// * A folded person carries all its entries on its own lane, each
///   marker named by its substance.
/// * The timer of a substance lane counts from its last entry, only while
///   the track has an open session; its line starts with its first entry.
/// * The track's own lane (its bar) only stays while it has no entry yet,
///   or carries start and stop.
({StripRowData? own, List<StripRowData> people}) _protocolRows({
  required Track track,
  required List<StripSession> sessions,
  required List<StripEvent> events,
  required Map<String, Person> persons,
  required Map<String, Substance> substances,
  required Set<String>? openPersons,
}) {
  final lifecycle = [
    for (final e in events)
      if (e.kind == StripMarkerKind.lifecycle) e,
  ];
  final live = sessions.any((s) => s.isOpen);
  final byPerson = <String?, Map<String?, List<StripEvent>>>{};
  final allOf = <String?, List<StripEvent>>{};
  for (final e in events) {
    if (e.kind != StripMarkerKind.entry) continue;
    final personId = e.row.event.personId;
    byPerson
        .putIfAbsent(personId, () => {})
        .putIfAbsent(e.row.event.substanceId, () => [])
        .add(e);
    allOf.putIfAbsent(personId, () => []).add(e);
  }
  final own = byPerson.isEmpty || lifecycle.isNotEmpty
      ? StripRowData(
          id: track.id,
          track: track,
          title: track.name,
          sessions: sessions,
          events: lifecycle,
        )
      : null;

  final rows = <StripRowData>[];
  for (final MapEntry(key: personId, value: bySubstance) in byPerson.entries) {
    final personKey = '${track.id}/p/${personId ?? ''}';
    final person = personId == null ? null : persons[personId];
    final open = openPersons == null || openPersons.contains(personKey);
    rows.add(
      StripRowData(
        id: personKey,
        track: track,
        title: personId == null
            ? Strings.protocolNoPerson
            : person?.name ?? Strings.unknown,
        kind: StripRowKind.person,
        folded: !open,
        dotArgb: person?.color,
        sessions: sessions,
        events: open ? const [] : allOf[personId]!,
      ),
    );
    if (!open) continue;
    for (final MapEntry(key: substanceId, value: list) in bySubstance.entries) {
      final substance = substanceId == null ? null : substances[substanceId];
      rows.add(
        StripRowData(
          id: '$personKey/s/${substanceId ?? ''}',
          track: track,
          title: substanceId == null
              ? Strings.protocolNoSubstance
              : substance?.name ?? Strings.unknown,
          kind: StripRowKind.thing,
          indent: 1,
          dotArgb: substance?.color,
          sessions: sessions,
          // The lane names the substance; an amount stays as the text.
          events: [
            for (var i = 0; i < list.length; i++)
              (substanceId == null ? list[i] : list[i].withLabel(null))
                  .withPrevious(i == 0 ? null : list[i - 1].at),
          ],
          bands: [
            for (final e in list)
              if (e.lockoutUntil case final until?)
                StripBandData(
                  from: e.at,
                  to: until,
                  colorArgb: e.colorArgb ?? 0,
                ),
          ],
          timerFrom: live ? list.last.at : null,
          barFrom: list.first.at,
          showGaps: true,
        ),
      );
    }
  }
  return (own: own, people: rows);
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
    this.labelHeight = 0,
    double? personHeight,
    double? foldedHeight,
    this.wordHeight = 0,
    double? trackMarkerRadius,
    this.bandHeight,
    double? gapMinWidth,
    this.cullMargin = 48,
  }) : personHeight = personHeight ?? subLaneHeight,
       foldedHeight = foldedHeight ?? subLaneHeight,
       trackMarkerRadius = trackMarkerRadius ?? markerRadius,
       gapMinWidth = gapMinWidth ?? markerGap * 2;

  /// Whole heights of a track lane and of a thing lane (name line
  /// included).
  final double laneHeight;
  final double subLaneHeight;

  /// The line with the name at the top of every lane.
  final double labelHeight;

  /// An open person (only its name line) and a folded one.
  final double personHeight;
  final double foldedHeight;

  /// The word below a marker of a folded person.
  final double wordHeight;
  final double barHeight;
  final double subBarHeight;

  /// The marker of an entry (and of every lane below a track), and of an
  /// event of a track.
  final double markerRadius;
  final double trackMarkerRadius;

  /// Height of the band of a running lockout; `null` = the whole lane.
  final double? bandHeight;

  /// Stretches narrower than this get no text with their time.
  final double gapMinWidth;

  /// Markers closer than this (centre to centre) become a cluster.
  final double markerGap;
  final double clusterHeight;
  final double clusterMinWidth;

  /// Space between a marker and its text.
  final double labelGap;

  /// How far outside the viewport something may start and still be
  /// produced (so nothing pops in at the edges).
  final double cullMargin;

  double heightOf(StripRowData row) => switch (row.kind) {
    StripRowKind.track => laneHeight,
    StripRowKind.thing => subLaneHeight,
    StripRowKind.person => row.folded ? foldedHeight : personHeight,
  };

  /// The middle of the bar or the line of a lane that starts at [top]:
  /// below its name line (and above the words of a folded person).
  double centerOf(StripRowData row, double top) {
    final below = row.isPerson ? wordHeight : 0.0;
    return top + labelHeight + (heightOf(row) - labelHeight - below) / 2;
  }

  double radiusOf(StripRowData row) =>
      row.isSub ? markerRadius : trackMarkerRadius;
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

/// The time between two neighbouring markers of a lane, or - [live] -
/// from the last one up to "now" (the timer of the lane). The painter
/// writes [ms] between [fromX] and [toX] where the text fits.
@immutable
final class StripGap {
  const StripGap({
    required this.rowIndex,
    required this.fromX,
    required this.toX,
    required this.centerY,
    required this.ms,
    this.live = false,
  });

  final int rowIndex;
  final double fromX;
  final double toX;
  final double centerY;
  final int ms;
  final bool live;

  double get width => toX - fromX;
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
    this.gaps = const [],
  });

  /// Top edge and height of every lane (all lanes, also unseen ones).
  final List<double> rowTops;
  final List<double> rowHeights;
  final List<StripBand> bands;
  final List<StripBar> bars;
  final List<StripMarker> markers;
  final List<StripCluster> clusters;

  /// The times between markers (only on lanes with `showGaps`).
  final List<StripGap> gaps;

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

/// The primitives for the stretch of [scale] that is [width] pixels
/// wide, as seen at [nowMs].
///
/// Only what touches the viewport (plus [StripMetrics.cullMargin]) is
/// produced. Markers of a lane that are closer than
/// [StripMetrics.markerGap] pixels become a [StripCluster]; zooming in
/// takes them apart again. Bars run through the folds of [scale].
StripLayout layoutStrip({
  required StripData data,
  required TimeScale scale,
  required double width,
  required int nowMs,
  required StripMetrics metrics,
}) {
  final tops = <double>[];
  final heights = <double>[];
  var y = 0.0;
  for (final row in data.rows) {
    final h = metrics.heightOf(row);
    tops.add(y);
    heights.add(h);
    y += h;
  }
  final msPerPx = scale.msPerPx;
  double xOf(num ms) => scale.xOf(ms);
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
  final lo = scale.timeAt(minX);
  final hi = scale.timeAt(maxX);
  final gapMs = metrics.markerGap * msPerPx;
  // Closer than this on screen: one cluster.
  bool close(StripEvent a, StripEvent b) =>
      xOf(b.at) - xOf(a.at) < metrics.markerGap;

  final bands = <StripBand>[];
  final bars = <StripBar>[];
  final markers = <StripMarker>[];
  final clusters = <StripCluster>[];
  final gaps = <StripGap>[];
  // Shorter stretches get no text; the painter leaves out what still
  // does not fit.
  final minGapPx = metrics.gapMinWidth;

  for (var r = 0; r < data.rows.length; r++) {
    final row = data.rows[r];
    final centerY = metrics.centerOf(row, tops[r]);
    final barH = row.isSub ? metrics.subBarHeight : metrics.barHeight;
    final barTop = centerY - barH / 2;
    final bandH = metrics.bandHeight;
    final bandTop = bandH == null ? tops[r] : centerY - bandH / 2;
    final bandBottom = bandH == null
        ? tops[r] + heights[r]
        : centerY + bandH / 2;

    // ---- lockout bands: only where the user set a lockout, and only
    // while it still runs
    if (row.bands.isNotEmpty) {
      var i = _lowerBound(row.bands, lo - row.maxBandMs, (b) => b.from);
      for (; i < row.bands.length; i++) {
        final band = row.bands[i];
        if (band.from > hi) break;
        if (band.to < lo || band.to <= nowMs) continue;
        bands.add(
          StripBand(
            rowIndex: r,
            rect: Rect.fromLTRB(
              math.max(minX, xOf(band.from)),
              bandTop,
              math.min(maxX, xOf(band.to)),
              bandBottom,
            ),
            colorArgb: band.colorArgb,
          ),
        );
      }
    }

    // ---- session bars
    final finishes = <StripMarker>[];
    // A person has no line of its own.
    for (final s in row.isPerson ? const <StripSession>[] : row.sessions) {
      if (s.startAt > hi) break;
      final end = s.endOr(nowMs);
      if (end < lo) continue;
      final growing = s.isRunning;

      final barFrom = row.barFrom;
      void bar(int from, int to, StripBarKind kind) {
        if (barFrom != null && from < barFrom) from = barFrom;
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
    final radius = metrics.radiusOf(row);
    final rowMarkers = <StripMarker>[];
    final rowClusters = <StripCluster>[];
    // (left edge, index into rowMarkers or -1): to measure the label room.
    final lefts = <double>[];
    final owners = <int>[];
    if (events.isNotEmpty) {
      var i = _lowerBound(events, lo, (e) => e.at);
      // A cluster that starts outside the viewport still counts all of
      // its events.
      while (i > 0 && i < events.length && close(events[i - 1], events[i])) {
        i--;
      }
      while (i < events.length) {
        if (events[i].at > hi) break;
        var j = i;
        while (j + 1 < events.length && close(events[j], events[j + 1])) {
          j++;
        }
        if (j == i) {
          final x = xOf(events[i].at);
          lefts.add(x - radius);
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
            (right - left) / 2 + radius,
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
          nextLeft - (m.center.dx + radius) - 2 * metrics.labelGap,
        ),
      );
    }
    markers
      ..addAll(finishes)
      ..addAll(rowMarkers);
    clusters.addAll(rowClusters);

    // ---- times between neighbouring markers, and the running timer
    final points = row.gapEvents;
    if (points.isNotEmpty) {
      var k = math.max(0, _lowerBound(points, lo, (e) => e.at) - 1);
      for (; k + 1 < points.length; k++) {
        final a = points[k];
        final b = points[k + 1];
        if (a.at > hi) break;
        if (b.at < lo) continue;
        final fromX = xOf(a.at);
        final toX = xOf(b.at);
        if (toX - fromX < minGapPx) continue;
        gaps.add(
          StripGap(
            rowIndex: r,
            fromX: fromX,
            toX: toX,
            centerY: centerY,
            ms: b.at - a.at,
          ),
        );
      }
      final from = row.timerFrom;
      if (from != null && from <= hi && nowMs >= lo) {
        final fromX = xOf(from);
        if (nowX - fromX >= minGapPx) {
          gaps.add(
            StripGap(
              rowIndex: r,
              fromX: fromX,
              toX: nowX,
              centerY: centerY,
              ms: math.max(0, nowMs - from),
              live: true,
            ),
          );
        }
      }
    }
  }

  return StripLayout(
    rowTops: tops,
    rowHeights: heights,
    bands: bands,
    bars: bars,
    markers: markers,
    clusters: clusters,
    nowX: nowX,
    gaps: gaps,
  );
}

/// The moments of [data] that must stay visible - every event, and the
/// starts, ends and pauses of the sessions - for [computeFolds]. A bar
/// that simply keeps running adds nothing between its ends.
Iterable<int> stripKeepTimes(StripData data) sync* {
  for (final row in data.rows) {
    for (final e in row.events) {
      yield e.at;
    }
    for (final s in row.sessions) {
      yield s.startAt;
      final end = s.endAt;
      if (end != null) yield end;
      for (final span in s.closedSpans) {
        yield span.from;
        yield span.to;
      }
      final since = s.runningSince;
      if (since != null) yield since;
    }
  }
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
