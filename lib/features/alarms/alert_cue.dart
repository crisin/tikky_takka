import '../../core/engine/snapshots.dart';

/// Why a track wants the user's attention inside the app.
enum AlertCueKind {
  /// A countdown reached zero and rings until dismissed.
  countdownDone,

  /// An auto-restarting countdown completed a cycle.
  countdownCycle,

  /// An interval work phase began.
  intervalWork,

  /// An interval rest phase began.
  intervalRest,

  /// The interval programme is finished and rings until dismissed.
  intervalDone,

  /// A reminder is due and nags until acknowledged.
  reminderDue,
}

/// The alert position of one track at one instant, derived from its
/// snapshot. It describes the STATE shown by the ringing banner and the
/// lanes; the audible / haptic cue and its repetition are the job of
/// `RingMonitor` (features/tracks).
final class AlertCue {
  const AlertCue({
    required this.kind,
    required this.ringing,
    required this.sinceMs,
    required this.step,
  });

  final AlertCueKind kind;

  /// The track waits for the user (dismiss / acknowledge). `false` for
  /// phase changes and countdown cycles, which just pass by.
  final bool ringing;

  /// Wall time (UTC ms) at which this state began: the due time, or the
  /// start of the interval phase.
  final int sinceMs;

  /// Position inside the session; grows with every phase, cycle or nag.
  final int step;

  @override
  bool operator ==(Object other) =>
      other is AlertCue &&
      other.kind == kind &&
      other.ringing == ringing &&
      other.sinceMs == sinceMs &&
      other.step == step;

  @override
  int get hashCode => Object.hash(kind, ringing, sinceMs, step);

  @override
  String toString() =>
      'AlertCue(${kind.name}, ringing: $ringing, since: $sinceMs, '
      'step: $step)';
}

/// Derives the alert cue of a snapshot; `null` when the track has nothing
/// to alert about (idle, paused, stopped, not due, non-alarm mode).
///
/// Running intervals and auto-restart countdowns always have a
/// (non-ringing) cue, so that the first phase change or cycle is detected
/// as a change.
AlertCue? alertCueFor(TrackSnapshot snapshot) {
  switch (snapshot) {
    case CountdownSnapshot s:
      if (s.isRinging) {
        return AlertCue(
          kind: AlertCueKind.countdownDone,
          ringing: true,
          sinceMs: s.lastFinishedAt ?? s.nowMs - s.overtimeMs,
          step: 1,
        );
      }
      if (s.autoRestart && s.isRunning) {
        return AlertCue(
          kind: AlertCueKind.countdownCycle,
          ringing: false,
          sinceMs: s.lastFinishedAt ?? s.startedAt ?? s.nowMs,
          step: s.completedCycles,
        );
      }
      return null;
    case IntervalSnapshot s:
      if (s.isRinging) {
        final finishedAt = s.finishAt ?? s.nowMs;
        return AlertCue(
          kind: AlertCueKind.intervalDone,
          ringing: true,
          sinceMs: finishedAt,
          step: s.rounds * 2,
        );
      }
      if (s.isRunning) {
        final rest = s.phase == IntervalPhase.rest;
        return AlertCue(
          kind: rest ? AlertCueKind.intervalRest : AlertCueKind.intervalWork,
          ringing: false,
          sinceMs: s.nowMs - s.phaseElapsedMs,
          step: (s.round - 1) * 2 + (rest ? 1 : 0),
        );
      }
      return null;
    case ReminderSnapshot s:
      if (!s.isRinging) return null;
      return AlertCue(
        kind: AlertCueKind.reminderDue,
        ringing: true,
        sinceMs: s.dueAt ?? s.nowMs - s.overdueMs,
        step: s.nagCount,
      );
    case StopwatchSnapshot() || CounterSnapshot() || ProtocolSnapshot():
      return null;
  }
}
