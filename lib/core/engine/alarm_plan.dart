import '../domain/track_config.dart';
import '../domain/track_event.dart';
import 'derive.dart';
import 'snapshots.dart';
import 'timeline.dart';

/// Why an alarm fires.
enum AlarmKind {
  /// A countdown reached zero and rings until dismissed.
  countdownDone,

  /// An auto-restarting countdown completed a cycle.
  countdownCycle,

  /// An interval work phase begins (the next round starts).
  intervalWork,

  /// An interval rest phase begins.
  intervalRest,

  /// The interval programme is finished.
  intervalDone,

  /// A reminder became due.
  reminderDue,

  /// A due reminder nags again.
  reminderNag,
}

/// One OS notification to schedule for a track.
final class PlannedAlarm {
  const PlannedAlarm({
    required this.trackId,
    required this.at,
    required this.kind,
    required this.index,
    this.round,
    this.planEndsHere = false,
  });

  final String trackId;

  /// Wall time (UTC milliseconds) at which the alarm fires.
  final int at;
  final AlarmKind kind;

  /// Position inside the plan of the track (0-based). Stable enough to build
  /// a notification id from `(track, index)`.
  final int index;

  /// Interval: the round that starts / the round whose rest starts.
  /// Countdown cycles: the number of the completed cycle. Nags: nag number.
  final int? round;

  /// The plan was cut off at the cap right after this alarm although the
  /// track keeps ringing (endless cycles / nags, a long interval
  /// programme): nothing further is scheduled until the app rebuilds the
  /// plan. The notification of this alarm says so instead of the alarms
  /// silently running dry.
  final bool planEndsHere;

  @override
  bool operator ==(Object other) =>
      other is PlannedAlarm &&
      other.trackId == trackId &&
      other.at == at &&
      other.kind == kind &&
      other.index == index &&
      other.round == round &&
      other.planEndsHere == planEndsHere;

  @override
  int get hashCode =>
      Object.hash(trackId, at, kind, index, round, planEndsHere);

  @override
  String toString() =>
      'PlannedAlarm(${kind.name} @$at #$index${planEndsHere ? ' END' : ''})';
}

/// Computes the future alarms of the OPEN session of a track.
///
/// Returns an empty list when nothing has to be scheduled (idle, paused,
/// stopped, non-alarm mode). Only instants strictly after [nowMs] are
/// returned, ordered by time, at most [maxCount].
///
/// When the cap cuts a plan short, the last alarm before the gap is marked
/// with [PlannedAlarm.planEndsHere]. (The app also rebuilds all plans when
/// it goes to the background, so the [maxCount] slots start from then.)
List<PlannedAlarm> planAlarms({
  required String trackId,
  required TrackConfig config,
  required Iterable<TrackEvent> events,
  required int nowMs,
  int maxCount = 16,
}) {
  if (maxCount <= 0) return const [];
  final times = <(int, AlarmKind, int?)>[];
  // The series has no end (cycles, nags): whatever is last is a cut.
  var endless = false;
  // Interval: the instant of the last phase alarm before the dropped ones.
  int? cutAfterAt;

  switch (config) {
    case CountdownConfig():
      final s = deriveCountdown(config, events, nowMs);
      if (s.state != RunState.running) break;
      final due = s.dueAt;
      if (due == null) break;
      if (s.autoRestart) {
        endless = true;
        for (var i = 0; i < maxCount; i++) {
          times.add((
            due + i * s.durationMs,
            AlarmKind.countdownCycle,
            s.completedCycles + i + 1,
          ));
        }
      } else {
        times.add((due, AlarmKind.countdownDone, null));
      }
    case IntervalConfig():
      final s = deriveInterval(config, events, nowMs);
      if (s.state != RunState.running || s.finished) break;
      final work = config.workMs < 0 ? 0 : config.workMs;
      final rest = config.restMs < 0 ? 0 : config.restMs;
      // Walk the remaining phase boundaries.
      var at = s.nextBoundaryAt ?? s.nowMs;
      var round = s.round;
      var phase = s.phase;
      while (true) {
        // Never drop the final "done" alarm when the plan is truncated.
        if (times.length >= maxCount - 1) {
          final naturalEnd = phase == IntervalPhase.work && round >= s.rounds;
          if (!naturalEnd && times.isNotEmpty) cutAfterAt = times.last.$1;
          times.add((s.finishAt ?? at, AlarmKind.intervalDone, s.rounds));
          break;
        }
        if (phase == IntervalPhase.work) {
          if (round >= s.rounds) {
            times.add((at, AlarmKind.intervalDone, round));
            break;
          }
          if (rest > 0) {
            times.add((at, AlarmKind.intervalRest, round));
            phase = IntervalPhase.rest;
            at += rest;
          } else {
            round++;
            times.add((at, AlarmKind.intervalWork, round));
            at += work;
          }
        } else {
          round++;
          times.add((at, AlarmKind.intervalWork, round));
          phase = IntervalPhase.work;
          at += work;
        }
      }
    case ReminderConfig():
      final s = deriveReminder(config, events, nowMs);
      if (s.state != RunState.running && s.state != RunState.ringing) break;
      final due = s.dueAt;
      if (due == null) break;
      if (!s.due) times.add((due, AlarmKind.reminderDue, null));
      if (s.nagEveryMs > 0) {
        endless = true;
        var n = s.nagCount + 1;
        while (times.length < maxCount) {
          times.add((due + n * s.nagEveryMs, AlarmKind.reminderNag, n));
          n++;
        }
      }
    case StopwatchConfig() || CounterConfig() || ProtocolConfig():
      break;
  }

  final kept = <(int, AlarmKind, int?)>[];
  for (final time in times) {
    if (time.$1 <= nowMs) continue;
    if (kept.length >= maxCount) break;
    kept.add(time);
  }
  return [
    for (var i = 0; i < kept.length; i++)
      PlannedAlarm(
        trackId: trackId,
        at: kept[i].$1,
        kind: kept[i].$2,
        index: i,
        round: kept[i].$3,
        planEndsHere:
            (endless && i == kept.length - 1) ||
            (cutAfterAt != null &&
                kept[i].$1 == cutAfterAt &&
                kept[i].$2 != AlarmKind.intervalDone &&
                (i + 1 >= kept.length || kept[i + 1].$1 != cutAfterAt)),
      ),
  ];
}
