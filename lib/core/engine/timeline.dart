import '../domain/enums.dart';
import '../domain/track_event.dart';

/// Coarse state of a track / session, derived from its events.
enum RunState {
  /// No events at all: nothing has been started.
  idle,

  /// Started and counting.
  running,

  /// Started and currently paused.
  paused,

  /// Running and demanding attention: countdown finished, interval programme
  /// finished or reminder due. Ends with stop (dismiss) or ack.
  ringing,

  /// The session has a stop event.
  stopped,
}

/// Returns a new list ordered by time, then insertion sequence, then id.
///
/// The input is never modified. Sorting is deterministic for any input.
List<TrackEvent> sortEvents(Iterable<TrackEvent> events) {
  final list = List<TrackEvent>.of(events);
  list.sort(compareEvents);
  return list;
}

int compareEvents(TrackEvent a, TrackEvent b) {
  final byAt = a.at.compareTo(b.at);
  if (byAt != 0) return byAt;
  final bySeq = a.seq.compareTo(b.seq);
  if (bySeq != 0) return bySeq;
  final byType = a.type.index.compareTo(b.type.index);
  if (byType != 0) return byType;
  return a.id.compareTo(b.id);
}

/// A half-open span of wall-clock time `[from, to)`.
final class TimeSpan {
  const TimeSpan(this.from, this.to);

  final int from;
  final int to;

  int get length => to > from ? to - from : 0;

  @override
  bool operator ==(Object other) =>
      other is TimeSpan && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'TimeSpan($from, $to)';
}

/// Normalised view of the start / pause / resume / stop events of a session.
///
/// Defensive rules (clock jumps, odd event orders, hand-edited data):
/// * events are processed in [sortEvents] order;
/// * the session starts at the first `start` event; without one, at the
///   first event of any type;
/// * events that sort before the start are treated as happening at the start;
/// * a `pause` while paused and a `resume` while running are ignored, an
///   extra `start` acts as `resume`;
/// * everything after the first `stop` is ignored;
/// * "now" never lies before the last processed event, so durations are
///   never negative.
final class Timeline {
  Timeline._({
    required this.events,
    required this.startAt,
    required this.stopAt,
    required this.endAt,
    required this.activeSpans,
    required this.isPaused,
  });

  /// Builds the timeline for [events] as seen at [nowMs].
  factory Timeline.build(Iterable<TrackEvent> events, int nowMs) {
    final sorted = sortEvents(events);
    if (sorted.isEmpty) {
      return Timeline._(
        events: const [],
        startAt: null,
        stopAt: null,
        endAt: nowMs,
        activeSpans: const [],
        isPaused: false,
      );
    }

    var startIndex = sorted.indexWhere((e) => e.type == EventType.start);
    if (startIndex < 0) startIndex = 0;
    final startAt = sorted[startIndex].at;

    // Events before the start are clamped onto the start; the start event
    // itself is moved to the front so it is processed first.
    final normalised = <TrackEvent>[
      sorted[startIndex],
      for (var i = 0; i < sorted.length; i++)
        if (i != startIndex)
          sorted[i].at < startAt ? sorted[i].copyWith(at: startAt) : sorted[i],
    ];

    final processed = <TrackEvent>[];
    final spans = <TimeSpan>[];
    var runningSince = startAt;
    var paused = false;
    int? stopAt;

    for (var i = 0; i < normalised.length; i++) {
      final e = normalised[i];
      switch (e.type) {
        case EventType.start when i == 0:
          break;
        case EventType.start || EventType.resume:
          if (paused) {
            paused = false;
            runningSince = e.at;
          }
        case EventType.pause:
          if (!paused) {
            paused = true;
            spans.add(TimeSpan(runningSince, e.at));
          }
        case EventType.stop:
          stopAt = e.at;
        case EventType.lap ||
            EventType.tick ||
            EventType.entry ||
            EventType.ack ||
            EventType.extend ||
            EventType.skip:
          break;
      }
      processed.add(e);
      if (stopAt != null) break;
    }

    final lastAt = processed.last.at;
    final endAt = stopAt ?? (nowMs < lastAt ? lastAt : nowMs);
    if (!paused) spans.add(TimeSpan(runningSince, endAt));

    return Timeline._(
      events: List.unmodifiable(processed),
      startAt: startAt,
      stopAt: stopAt,
      endAt: endAt,
      activeSpans: List.unmodifiable(spans),
      isPaused: paused && stopAt == null,
    );
  }

  /// Sanitised events in processing order (up to and including the stop).
  final List<TrackEvent> events;

  /// Wall time of the session start; `null` when there are no events.
  final int? startAt;

  /// Wall time of the stop event; `null` while open.
  final int? stopAt;

  /// The instant the derivation refers to: the stop time for stopped
  /// sessions, otherwise the (defensively clamped) "now".
  final int endAt;

  /// Wall-clock spans during which the session was counting.
  final List<TimeSpan> activeSpans;

  /// Open and currently paused.
  final bool isPaused;

  bool get isStarted => startAt != null;
  bool get isStopped => stopAt != null;
  bool get isRunning => isStarted && !isStopped && !isPaused;

  /// Net counting time from the start until [endAt].
  int get activeMs => activeMsAt(endAt);

  /// Wall time from the start until [endAt].
  int get wallMs => startAt == null ? 0 : endAt - startAt!;

  /// Total paused time until [endAt].
  int get pausedMs => wallMs - activeMs;

  /// Net counting time from the start until the wall-clock instant [wallAt]
  /// (clamped into the session).
  int activeMsAt(int wallAt) {
    var sum = 0;
    for (final s in activeSpans) {
      if (wallAt <= s.from) break;
      sum += (wallAt < s.to ? wallAt : s.to) - s.from;
    }
    return sum;
  }

  /// Wall-clock instant at which the net counting time reaches
  /// [targetActiveMs].
  ///
  /// For targets in the future this assumes the session keeps running
  /// uninterrupted and returns `null` when it is paused or stopped (the
  /// target would never be reached).
  int? wallAtActive(int targetActiveMs) {
    if (startAt == null) return null;
    if (targetActiveMs <= 0) return startAt;
    var sum = 0;
    for (final s in activeSpans) {
      final len = s.length;
      if (sum + len >= targetActiveMs) return s.from + (targetActiveMs - sum);
      sum += len;
    }
    if (!isRunning) return null;
    return endAt + (targetActiveMs - sum);
  }

  /// Base state without mode-specific "ringing".
  RunState get baseState {
    if (!isStarted) return RunState.idle;
    if (isStopped) return RunState.stopped;
    if (isPaused) return RunState.paused;
    return RunState.running;
  }
}
