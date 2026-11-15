import 'package:flutter/foundation.dart';

import '../../../core/domain/domain.dart';
import '../../../core/engine/engine.dart';
import '../../../l10n/formatters.dart';
import '../../../l10n/strings.dart';
import '../tracks_strings.dart';

// Pure logic of the timeline ("Zeitleiste") of the tracks screen: the
// range, the rows, the filters and the gap markers. Unit tested.

/// What the timeline and the summary cover.
enum TimelineScope {
  /// The events of all sessions of the set that are open right now.
  open,

  /// Everything since local midnight.
  today,

  /// Everything of the last 24 hours.
  last24h,
}

const int _dayMs = 24 * 60 * 60 * 1000;

/// A marker is shown between two rows that are further apart than this.
const int timelineGapThresholdMs = 5 * 60 * 1000;

/// The start of [scope] at [nowMs] (UTC ms); `null` = no lower bound (the
/// open sessions, however long they have been running).
int? timelineSince(TimelineScope scope, int nowMs) => switch (scope) {
  TimelineScope.open => null,
  TimelineScope.today => LocalDay.fromMs(nowMs).startMs,
  TimelineScope.last24h => nowMs - _dayMs,
};

/// What a row stands for.
enum TimelineRowKind {
  tick,
  lap,
  entry,
  ack,

  /// Start, pause, resume, stop: shown smaller and muted, hidden by
  /// default.
  lifecycle,
}

/// One event of the timeline with its text.
@immutable
final class TimelineRow {
  const TimelineRow({
    required this.event,
    required this.track,
    required this.kind,
    required this.text,
  });

  final TrackEvent event;
  final Track track;
  final TimelineRowKind kind;

  /// What happened, in plain German: "Reiher · 3", "Runde 2 · 01:23.4",
  /// "Jacke · GBL · 1 ml", "Erledigt · 2 min nach Fälligkeit",
  /// "Gestartet".
  final String text;

  int get at => event.at;
  String? get note => event.note;
  bool get isLifecycle => kind == TimelineRowKind.lifecycle;

  @override
  String toString() => 'TimelineRow(${track.name}: $text @$at)';
}

/// An entry of the list: a row, or the marker between two rows.
sealed class TimelineItem {
  const TimelineItem();
}

final class TimelineEventItem extends TimelineItem {
  const TimelineEventItem(this.row);

  final TimelineRow row;
}

/// "12 min später": more than the threshold passed between the row above
/// and the row below.
final class TimelineGapItem extends TimelineItem {
  const TimelineGapItem(this.ms);

  /// The time between the two rows (always positive).
  final int ms;
}

String _join(Iterable<String?> parts) => [
  for (final p in parts)
    if (p != null && p.trim().isNotEmpty) p.trim(),
].join(TracksStrings.separator);

/// The rows of one session, oldest first.
List<TimelineRow> _rowsOfSession(
  HistorySession item,
  Track track, {
  required Map<String, String> personNames,
  required Map<String, String> substanceNames,
}) {
  final events = item.events;
  if (events.isEmpty) return const [];
  final annotations = annotateEvents(events);
  // The delay of each acknowledgement comes from the reminder engine.
  final snapshot = item.session.mode == TrackMode.reminder
      ? deriveSnapshot(
          config: item.session.config,
          events: events,
          nowMs: annotations.last.event.at,
        )
      : null;
  final acks = {
    if (snapshot is ReminderSnapshot)
      for (final ack in snapshot.acks) ack.eventId: ack,
  };
  final perLabel = <String, int>{};
  final rows = <TimelineRow>[];
  for (final a in annotations) {
    final e = a.event;
    final TimelineRowKind kind;
    final String text;
    switch (e.type) {
      case EventType.tick:
        kind = TimelineRowKind.tick;
        final label = e.label;
        if (label == null || label.isEmpty) {
          text = TracksStrings.timelineTickPlain(a.runningCount ?? 0);
        } else {
          final n = (perLabel[label] ?? 0) + 1;
          perLabel[label] = n;
          text = TracksStrings.timelineTick(label, n);
        }
      case EventType.lap:
        kind = TimelineRowKind.lap;
        final lapMs = a.lapMs;
        text = _join([
          lapMs == null || a.runningCount == null
              ? Strings.eventTypeName(e.type)
              : TracksStrings.timelineLap(
                  a.runningCount!,
                  Fmt.clock(lapMs, tenths: true),
                ),
          e.label,
        ]);
      case EventType.entry:
        kind = TimelineRowKind.entry;
        final personId = e.personId;
        final substanceId = e.substanceId;
        final substance = substanceId == null
            ? null
            : substanceNames[substanceId] ?? Strings.unknown;
        text = _join([
          personId == null
              ? Strings.protocolNoPerson
              : personNames[personId] ?? Strings.unknown,
          // The amount is the user's own free text; it is shown, never
          // interpreted.
          substance == null && (e.amount ?? '').trim().isEmpty
              ? Strings.protocolNoSubstance
              : substance,
          e.amount,
        ]);
      case EventType.ack:
        kind = TimelineRowKind.ack;
        final delay = acks[e.id]?.delayMs ?? 0;
        text = delay < 1000
            ? TracksStrings.timelineAck
            : TracksStrings.timelineAckDelayed(Fmt.compact(delay));
      case EventType.start:
        kind = TimelineRowKind.lifecycle;
        text = TracksStrings.timelineStarted;
      case EventType.pause:
        kind = TimelineRowKind.lifecycle;
        text = TracksStrings.timelinePaused;
      case EventType.resume:
        kind = TimelineRowKind.lifecycle;
        text = TracksStrings.timelineResumed;
      case EventType.stop:
        kind = TimelineRowKind.lifecycle;
        text = TracksStrings.timelineStopped;
      case EventType.extend:
        kind = TimelineRowKind.lifecycle;
        text = TracksStrings.timelineExtended(Fmt.compact(e.extendMs));
      case EventType.skip:
        kind = TimelineRowKind.lifecycle;
        text = TracksStrings.timelineSkipped;
    }
    rows.add(TimelineRow(event: e, track: track, kind: kind, text: text));
  }
  return rows;
}

/// One chronological list across all tracks of [sessions] (what
/// `HistoryRepository.watchSetActivity` delivers).
///
/// * Running numbers (count per label, lap number) are counted inside the
///   session, like on the lane - also for events before [sinceMs].
/// * Only events at or after [sinceMs] are listed (`null` = all).
/// * Sessions whose track no longer exists are left out.
List<TimelineRow> buildTimelineRows({
  required Iterable<HistorySession> sessions,
  int? sinceMs,
  Map<String, String> personNames = const {},
  Map<String, String> substanceNames = const {},
  bool newestFirst = true,
}) {
  final rows = <TimelineRow>[];
  for (final item in sessions) {
    final track = item.track;
    if (track == null) continue;
    for (final row in _rowsOfSession(
      item,
      track,
      personNames: personNames,
      substanceNames: substanceNames,
    )) {
      if (sinceMs == null || row.at >= sinceMs) rows.add(row);
    }
  }
  rows.sort((a, b) {
    final byEvent = compareEvents(a.event, b.event);
    return newestFirst ? -byEvent : byEvent;
  });
  return rows;
}

/// Applies the filter chips: lifecycle rows only with [showLifecycle],
/// nothing of the tracks in [hiddenTrackIds].
List<TimelineRow> filterTimelineRows(
  Iterable<TimelineRow> rows, {
  bool showLifecycle = false,
  Set<String> hiddenTrackIds = const {},
}) => [
  for (final row in rows)
    if ((showLifecycle || !row.isLifecycle) &&
        !hiddenTrackIds.contains(row.track.id))
      row,
];

/// Puts a [TimelineGapItem] between two consecutive rows that are more
/// than [thresholdMs] apart. Works for both sort directions.
List<TimelineItem> withGapMarkers(
  List<TimelineRow> rows, {
  int thresholdMs = timelineGapThresholdMs,
}) {
  final items = <TimelineItem>[];
  for (var i = 0; i < rows.length; i++) {
    if (i > 0) {
      final gap = (rows[i].at - rows[i - 1].at).abs();
      if (gap > thresholdMs) items.add(TimelineGapItem(gap));
    }
    items.add(TimelineEventItem(rows[i]));
  }
  return items;
}

/// The label choices of the event editor for a tick of [track]: the
/// track's quick labels, plus [current] when it is not one of them (an
/// old label must stay selectable).
List<String> tickLabelChoices(Track track, String? current) {
  final config = track.config;
  final labels = <String>[if (config is CounterConfig) ...config.labels];
  if (current != null && current.isNotEmpty && !labels.contains(current)) {
    labels.add(current);
  }
  return labels;
}
