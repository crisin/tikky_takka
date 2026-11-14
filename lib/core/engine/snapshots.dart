import '../domain/enums.dart';
import '../domain/track_event.dart';
import 'timeline.dart';

/// Everything a lane needs to render a track at one instant. Produced by
/// `deriveSnapshot` - never stored.
sealed class TrackSnapshot {
  const TrackSnapshot({
    required this.state,
    required this.nowMs,
    required this.startedAt,
    required this.stoppedAt,
    required this.elapsedMs,
    required this.pausedMs,
    required this.totalMs,
  });

  TrackMode get mode;

  final RunState state;

  /// The instant this snapshot refers to (stop time for stopped sessions,
  /// otherwise "now", never before the last event).
  final int nowMs;

  /// Wall time of the session start; `null` when idle.
  final int? startedAt;

  /// Wall time of the stop; `null` while open.
  final int? stoppedAt;

  /// Net counting time (pauses excluded).
  final int elapsedMs;

  /// Total paused time.
  final int pausedMs;

  /// Wall time since the start (pauses included).
  final int totalMs;

  bool get isIdle => state == RunState.idle;
  bool get isRunning => state == RunState.running;
  bool get isPaused => state == RunState.paused;
  bool get isRinging => state == RunState.ringing;
  bool get isStopped => state == RunState.stopped;

  /// The session exists and has not been stopped.
  bool get isOpen => !isIdle && !isStopped;

  /// Time is advancing (running or ringing): the lane must repaint.
  bool get isTicking => isRunning || isRinging;
}

/// A completed stopwatch lap.
final class LapInfo {
  const LapInfo({
    required this.index,
    required this.eventId,
    required this.at,
    required this.durationMs,
    required this.totalMs,
    this.label,
  });

  /// 1-based lap number.
  final int index;
  final String eventId;

  /// Wall time at which the lap was taken.
  final int at;

  /// Net duration of this lap.
  final int durationMs;

  /// Net elapsed time of the stopwatch when the lap was taken.
  final int totalMs;
  final String? label;
}

final class StopwatchSnapshot extends TrackSnapshot {
  const StopwatchSnapshot({
    required super.state,
    required super.nowMs,
    required super.startedAt,
    required super.stoppedAt,
    required super.elapsedMs,
    required super.pausedMs,
    required super.totalMs,
    required this.laps,
    required this.currentLapMs,
  });

  @override
  TrackMode get mode => TrackMode.stopwatch;

  /// Completed laps, oldest first.
  final List<LapInfo> laps;

  /// Net time since the last lap (or since the start).
  final int currentLapMs;

  int get lapCount => laps.length;

  /// Number of the lap currently being timed (1-based).
  int get currentLapNumber => laps.length + 1;
}

final class CountdownSnapshot extends TrackSnapshot {
  const CountdownSnapshot({
    required super.state,
    required super.nowMs,
    required super.startedAt,
    required super.stoppedAt,
    required super.elapsedMs,
    required super.pausedMs,
    required super.totalMs,
    required this.durationMs,
    required this.autoRestart,
    required this.remainingMs,
    required this.overtimeMs,
    required this.finished,
    required this.completedCycles,
    required this.dueAt,
    required this.lastFinishedAt,
  });

  @override
  TrackMode get mode => TrackMode.countdown;

  final int durationMs;
  final bool autoRestart;

  /// Time left in the current cycle (0 when finished). Equals [durationMs]
  /// when idle.
  final int remainingMs;

  /// Net time since the countdown reached zero (0 with auto restart).
  final int overtimeMs;

  /// The countdown has reached zero and does not restart by itself.
  final bool finished;

  /// With auto restart: number of completed cycles; otherwise 0 or 1.
  final int completedCycles;

  /// Wall time at which the current cycle ends; `null` unless running.
  final int? dueAt;

  /// Wall time of the most recent completion; `null` if none yet.
  final int? lastFinishedAt;

  /// 0..1 share of the current cycle that has elapsed.
  double get progress {
    if (durationMs <= 0) return 1;
    final p = 1 - remainingMs / durationMs;
    return p < 0 ? 0 : (p > 1 ? 1 : p);
  }
}

enum IntervalPhase { work, rest, done }

final class IntervalSnapshot extends TrackSnapshot {
  const IntervalSnapshot({
    required super.state,
    required super.nowMs,
    required super.startedAt,
    required super.stoppedAt,
    required super.elapsedMs,
    required super.pausedMs,
    required super.totalMs,
    required this.rounds,
    required this.round,
    required this.phase,
    required this.phaseDurationMs,
    required this.phaseElapsedMs,
    required this.phaseRemainingMs,
    required this.totalDurationMs,
    required this.finished,
    required this.nextBoundaryAt,
    required this.finishAt,
  });

  @override
  TrackMode get mode => TrackMode.interval;

  /// Configured number of rounds (at least 1).
  final int rounds;

  /// Current round, 1-based; equals [rounds] when done.
  final int round;
  final IntervalPhase phase;
  final int phaseDurationMs;
  final int phaseElapsedMs;
  final int phaseRemainingMs;

  /// Net duration of the whole programme.
  final int totalDurationMs;
  final bool finished;

  /// Wall time of the next phase change; `null` unless running.
  final int? nextBoundaryAt;

  /// Wall time at which the programme ends (or ended); `null` when paused
  /// before the end, idle, or stopped early.
  final int? finishAt;

  int get remainingTotalMs {
    final r = totalDurationMs - elapsedMs;
    return r < 0 ? 0 : r;
  }

  /// 0..1 share of the whole programme that has elapsed.
  double get progress {
    if (totalDurationMs <= 0) return 1;
    final p = elapsedMs / totalDurationMs;
    return p < 0 ? 0 : (p > 1 ? 1 : p);
  }

  /// 0..1 share of the current phase that has elapsed.
  double get phaseProgress {
    if (phaseDurationMs <= 0) return 1;
    final p = phaseElapsedMs / phaseDurationMs;
    return p < 0 ? 0 : (p > 1 ? 1 : p);
  }
}

/// One counted tap of a counter track.
final class TickInfo {
  const TickInfo({
    required this.index,
    required this.eventId,
    required this.at,
    required this.lapMs,
    this.label,
  });

  /// 1-based running count.
  final int index;
  final String eventId;
  final int at;

  /// Net time since the previous tick (or the start).
  final int lapMs;
  final String? label;
}

final class CounterSnapshot extends TrackSnapshot {
  const CounterSnapshot({
    required super.state,
    required super.nowMs,
    required super.startedAt,
    required super.stoppedAt,
    required super.elapsedMs,
    required super.pausedMs,
    required super.totalMs,
    required this.ticks,
    required this.currentLapMs,
    required this.labelCounts,
    required this.unlabeledCount,
  });

  @override
  TrackMode get mode => TrackMode.counter;

  /// All ticks, oldest first.
  final List<TickInfo> ticks;

  /// Net time since the last tick (or the start).
  final int currentLapMs;

  /// Count per label, in configured label order followed by any other label
  /// found in the log. Labels with a count of 0 are included.
  final Map<String, int> labelCounts;

  /// Ticks stored without a label.
  final int unlabeledCount;

  int get count => ticks.length;
  int? get lastTickAt => ticks.isEmpty ? null : ticks.last.at;

  /// There is a tick that undo can remove.
  bool get canUndo => isOpen && ticks.isNotEmpty;
}

/// A logged acknowledgement of a reminder.
final class AckInfo {
  const AckInfo({
    required this.index,
    required this.eventId,
    required this.at,
    required this.waitedMs,
    required this.delayMs,
  });

  /// 1-based.
  final int index;
  final String eventId;
  final int at;

  /// Net time between the previous anchor (ack or start) and this ack.
  final int waitedMs;

  /// How long after becoming due the reminder was acknowledged (0 when it
  /// was acknowledged early).
  final int delayMs;
}

final class ReminderSnapshot extends TrackSnapshot {
  const ReminderSnapshot({
    required super.state,
    required super.nowMs,
    required super.startedAt,
    required super.stoppedAt,
    required super.elapsedMs,
    required super.pausedMs,
    required super.totalMs,
    required this.intervalMs,
    required this.nagEveryMs,
    required this.anchorAt,
    required this.sinceAnchorMs,
    required this.remainingMs,
    required this.due,
    required this.overdueMs,
    required this.dueAt,
    required this.nagCount,
    required this.nextNagAt,
    required this.acks,
  });

  @override
  TrackMode get mode => TrackMode.reminder;

  final int intervalMs;
  final int nagEveryMs;

  /// Wall time of the last ack, or of the start; `null` when idle.
  final int? anchorAt;

  /// Net time since [anchorAt].
  final int sinceAnchorMs;

  /// Time until due (0 when due). Equals [intervalMs] when idle.
  final int remainingMs;
  final bool due;

  /// Net time since it became due (0 when not due).
  final int overdueMs;

  /// Wall time at which it becomes / became due; `null` when idle, or when
  /// paused / stopped before becoming due.
  final int? dueAt;

  /// Number of nags that have fired since it became due.
  final int nagCount;

  /// Wall time of the next nag; `null` unless due and running.
  final int? nextNagAt;

  /// All acknowledgements, oldest first.
  final List<AckInfo> acks;

  int get ackCount => acks.length;
  int? get lastAckAt => acks.isEmpty ? null : acks.last.at;

  /// 0..1 share of the interval that has elapsed.
  double get progress {
    if (intervalMs <= 0) return 1;
    final p = sinceAnchorMs / intervalMs;
    return p < 0 ? 0 : (p > 1 ? 1 : p);
  }
}

/// A protocol entry as shown in lanes and history.
final class ProtocolEntry {
  const ProtocolEntry({required this.event});

  final TrackEvent event;

  String get eventId => event.id;
  int get at => event.at;
  String? get personId => event.personId;
  String? get substanceId => event.substanceId;
  String? get amount => event.amount;
  String? get note => event.note;
}

/// A user-set lockout that is still running.
final class LockoutStatus {
  const LockoutStatus({
    required this.substanceId,
    required this.lastEntryAt,
    required this.untilAt,
    required this.remainingMs,
  });

  final String substanceId;
  final int lastEntryAt;

  /// Wall time at which the lockout is over.
  final int untilAt;
  final int remainingMs;
}

/// Protocol state of one person inside a session.
final class PersonProtocolStatus {
  const PersonProtocolStatus({
    required this.personId,
    required this.lastEntry,
    required this.sinceMs,
    required this.entryCount,
    required this.lockouts,
  });

  /// `null` groups the entries logged without a person.
  final String? personId;
  final ProtocolEntry lastEntry;

  /// Wall time since [lastEntry] (never negative).
  final int sinceMs;
  final int entryCount;

  /// Lockouts that are not over yet, longest remaining first.
  final List<LockoutStatus> lockouts;

  /// The lockout of the substance of the last entry, if still running.
  LockoutStatus? get lastEntryLockout {
    for (final l in lockouts) {
      if (l.substanceId == lastEntry.substanceId) return l;
    }
    return null;
  }

  /// The lockout that takes longest to expire, if any.
  LockoutStatus? get longestLockout => lockouts.isEmpty ? null : lockouts.first;
}

final class ProtocolSnapshot extends TrackSnapshot {
  const ProtocolSnapshot({
    required super.state,
    required super.nowMs,
    required super.startedAt,
    required super.stoppedAt,
    required super.elapsedMs,
    required super.pausedMs,
    required super.totalMs,
    required this.entries,
    required this.persons,
  });

  @override
  TrackMode get mode => TrackMode.protocol;

  /// All entries, oldest first.
  final List<ProtocolEntry> entries;

  /// One status per person with entries, most recent entry first.
  final List<PersonProtocolStatus> persons;

  int get entryCount => entries.length;
  ProtocolEntry? get lastEntry => entries.isEmpty ? null : entries.last;
}
