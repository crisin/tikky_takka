import '../domain/enums.dart';
import '../domain/track_config.dart';
import '../domain/track_event.dart';
import 'timeline.dart';

/// Aggregated figures of one session, for history and export.
final class SessionSummary {
  const SessionSummary({
    required this.mode,
    required this.startAt,
    required this.endAt,
    required this.isOpen,
    required this.netMs,
    required this.pausedMs,
    required this.wallMs,
    required this.pauseCount,
    required this.lapCount,
    required this.tickCount,
    required this.entryCount,
    required this.ackCount,
    required this.completedRounds,
  });

  final TrackMode mode;

  /// Wall time of the start; `null` for a session without events.
  final int? startAt;

  /// Wall time of the stop; `null` while open.
  final int? endAt;
  final bool isOpen;

  /// Net duration (pauses excluded).
  final int netMs;
  final int pausedMs;

  /// Start to end (or now), pauses included.
  final int wallMs;
  final int pauseCount;
  final int lapCount;
  final int tickCount;
  final int entryCount;
  final int ackCount;

  /// Countdown: completed cycles. Interval: completed work phases.
  final int completedRounds;

  /// The "laps / count" figure of the session for its mode.
  int get count => switch (mode) {
    TrackMode.stopwatch => lapCount,
    TrackMode.countdown => completedRounds,
    TrackMode.interval => completedRounds,
    TrackMode.counter => tickCount,
    TrackMode.reminder => ackCount,
    TrackMode.protocol => entryCount,
  };
}

/// Summarises one session. Pure; [nowMs] only matters for open sessions.
SessionSummary summarizeSession({
  required TrackConfig config,
  required Iterable<TrackEvent> events,
  required int nowMs,
}) {
  final t = Timeline.build(events, nowMs);
  var pauses = 0;
  var laps = 0;
  var ticks = 0;
  var acks = 0;
  var paused = false;
  for (final e in t.events) {
    switch (e.type) {
      case EventType.pause:
        if (!paused) pauses++;
        paused = true;
      case EventType.resume:
        paused = false;
      case EventType.start:
        paused = false;
      case EventType.lap:
        laps++;
      case EventType.tick:
        ticks++;
      case EventType.ack:
        acks++;
      case EventType.entry ||
          EventType.stop ||
          EventType.extend ||
          EventType.skip:
        break;
    }
  }
  // Entries count even when their (editable) time lies outside the session.
  final entries = events.where((e) => e.type == EventType.entry).length;

  final net = t.activeMs;
  var rounds = 0;
  switch (config) {
    case CountdownConfig(:final durationMs, :final autoRestart):
      if (t.isStarted) {
        if (durationMs <= 0) {
          rounds = 1;
        } else if (autoRestart) {
          rounds = net ~/ durationMs;
        } else {
          rounds = net >= durationMs ? 1 : 0;
        }
      }
    case IntervalConfig():
      final r = config.rounds < 1 ? 1 : config.rounds;
      final work = config.workMs < 0 ? 0 : config.workMs;
      final rest = config.restMs < 0 ? 0 : config.restMs;
      final cycle = work + rest;
      if (t.isStarted) {
        if (net >= config.totalMs || cycle == 0) {
          rounds = r;
        } else {
          rounds = net ~/ cycle + (net % cycle >= work ? 1 : 0);
          if (rounds > r) rounds = r;
        }
      }
    case StopwatchConfig() ||
        CounterConfig() ||
        ReminderConfig() ||
        ProtocolConfig():
      break;
  }

  return SessionSummary(
    mode: config.mode,
    startAt: t.startAt,
    endAt: t.stopAt,
    isOpen: t.isStarted && !t.isStopped,
    netMs: net,
    pausedMs: t.pausedMs,
    wallMs: t.wallMs,
    pauseCount: pauses,
    lapCount: laps,
    tickCount: ticks,
    entryCount: entries,
    ackCount: acks,
    completedRounds: rounds,
  );
}

/// An event together with the figures the "Ereignisse" export shows next to
/// it.
final class EventAnnotation {
  const EventAnnotation({
    required this.event,
    required this.elapsedMs,
    this.runningCount,
    this.lapMs,
  });

  final TrackEvent event;

  /// Net session time at the event.
  final int elapsedMs;

  /// 1-based running number among events of the same kind (lap, tick, entry,
  /// ack); `null` for start / pause / resume / stop.
  final int? runningCount;

  /// Lap: net lap duration. Tick: net time since the previous tick (or the
  /// start). Ack: net time since the previous ack (or the start). Otherwise
  /// `null`.
  final int? lapMs;
}

/// Annotates all events of one session, in chronological order. Events that
/// the timeline ignores (e.g. after the stop) are still listed, without
/// figures.
List<EventAnnotation> annotateEvents(Iterable<TrackEvent> events) {
  final sorted = sortEvents(events);
  if (sorted.isEmpty) return const [];
  final t = Timeline.build(sorted, sorted.last.at);
  final processedIds = {for (final e in t.events) e.id};

  final counts = <EventType, int>{};
  final lastActive = <EventType, int>{};
  final result = <EventAnnotation>[];
  for (final e in sorted) {
    final active = t.activeMsAt(e.at);
    final counted =
        e.type == EventType.lap ||
        e.type == EventType.tick ||
        e.type == EventType.entry ||
        e.type == EventType.ack;
    final timed =
        e.type == EventType.lap ||
        e.type == EventType.tick ||
        e.type == EventType.ack;
    if (!counted || (!processedIds.contains(e.id) && timed)) {
      result.add(EventAnnotation(event: e, elapsedMs: active));
      continue;
    }
    final n = (counts[e.type] ?? 0) + 1;
    counts[e.type] = n;
    int? lapMs;
    if (timed) {
      lapMs = active - (lastActive[e.type] ?? 0);
      lastActive[e.type] = active;
    }
    result.add(
      EventAnnotation(
        event: e,
        elapsedMs: active,
        runningCount: n,
        lapMs: lapMs,
      ),
    );
  }
  return result;
}
