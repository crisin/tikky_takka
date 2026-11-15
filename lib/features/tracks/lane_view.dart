import 'package:flutter/foundation.dart';

import '../../core/domain/domain.dart';
import '../../core/engine/engine.dart';
import '../../core/repo/models.dart';
import '../../l10n/formatters.dart';
import '../../l10n/strings.dart';
import '../../theme/ui_prefs.dart';
import 'tracks_strings.dart';

/// What the round primary button of a lane does right now.
enum LanePrimary { start, pause, resume, dismiss, ack, tick, none }

/// The secondary button of a lane (at most one at a time).
///
/// [plusMinute]: "+1′" of a ringing timer; [snooze]: "+10′" of a due
/// reminder; [nextRound]: "nächste Runde" of a running interval.
enum LaneSecondaryKind {
  lap,
  restart,
  reset,
  undo,
  stop,
  ackEarly,
  plusMinute,
  snooze,
  nextRound,
}

/// How a lane looks: its surface, outline and lamp.
///
/// * [running]: surface in the track colour, lamp lit;
/// * [paused]: outline in the track colour, lamp hollow;
/// * [ringing]: a countdown / interval that rings, surface in the alarm
///   colour;
/// * [due]: a reminder that is due, surface plus a warning outline;
/// * [idle]: ready to start, a thin neutral outline, one line.
enum LaneLook { running, paused, ringing, due, idle }

/// The rounds of an interval lane as a row of segments.
@immutable
final class LaneSegments {
  const LaneSegments({required this.current, required this.total});

  /// 1-based number of the running round; `total + 1` when finished.
  final int current;
  final int total;

  @override
  bool operator ==(Object other) =>
      other is LaneSegments && other.current == current && other.total == total;

  @override
  int get hashCode => Object.hash(current, total);

  @override
  String toString() => 'LaneSegments($current / $total)';
}

@immutable
final class LaneSecondary {
  const LaneSecondary(this.kind, {required this.enabled});

  final LaneSecondaryKind kind;
  final bool enabled;

  @override
  bool operator ==(Object other) =>
      other is LaneSecondary && other.kind == kind && other.enabled == enabled;

  @override
  int get hashCode => Object.hash(kind, enabled);

  @override
  String toString() => 'LaneSecondary(${kind.name}, enabled: $enabled)';
}

/// The part of a lane that changes with time: digits, progress, sub-line.
/// Value equality lets the lane skip rebuilds when a tick changes nothing
/// visible (e.g. nine out of ten ticks without tenths).
@immutable
final class LaneTime {
  const LaneTime({
    required this.digits,
    required this.subLine,
    this.secondaryDigits,
    this.progress,
    this.segments,
    this.alert = false,
    this.blinkOn = false,
  });

  /// The large time or count.
  final String digits;

  /// Smaller figure next to the digits (lap time of a counter).
  final String? secondaryDigits;

  /// Muted status line.
  final String subLine;

  /// 0..1 share of the current run that has elapsed; the lane is filled
  /// with the rest. `null` when the mode has none.
  final double? progress;

  /// The rounds of an interval; `null` for every other lane.
  final LaneSegments? segments;

  /// The lane is ringing / due.
  final bool alert;

  /// Blink phase of a ringing lane (derived from "now", no animation).
  final bool blinkOn;

  @override
  bool operator ==(Object other) =>
      other is LaneTime &&
      other.digits == digits &&
      other.secondaryDigits == secondaryDigits &&
      other.subLine == subLine &&
      other.progress == progress &&
      other.segments == segments &&
      other.alert == alert &&
      other.blinkOn == blinkOn;

  @override
  int get hashCode => Object.hash(
    digits,
    secondaryDigits,
    subLine,
    progress,
    segments,
    alert,
    blinkOn,
  );

  @override
  String toString() => 'LaneTime($digits, $secondaryDigits, $subLine)';
}

/// The part of a lane that only changes with its state: buttons, surface
/// and outline.
@immutable
final class LaneControls {
  const LaneControls({
    required this.state,
    required this.look,
    required this.primary,
    this.secondary,
    this.canStop = false,
    this.labelCounts = const {},
    this.status = '',
  });

  final RunState state;
  final LaneLook look;
  final LanePrimary primary;

  /// The one secondary button; `null` = none (a ready lane).
  final LaneSecondary? secondary;

  /// A run is open and can be stopped: long press on the primary button,
  /// the "Stopp" button of a paused lane, the screen reader action.
  final bool canStop;

  /// Counter with quick labels: label -> count, in configured order. Empty
  /// for every other lane.
  final Map<String, int> labelCounts;

  /// Status word for screen readers ("Läuft", "Pausiert", ...).
  final String status;

  bool get ringing => state == RunState.ringing;
  bool get hasLabels => labelCounts.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is LaneControls &&
      other.state == state &&
      other.look == look &&
      other.primary == primary &&
      other.status == status &&
      other.canStop == canStop &&
      other.secondary == secondary &&
      mapEquals(other.labelCounts, labelCounts);

  @override
  int get hashCode => Object.hash(
    state,
    look,
    primary,
    status,
    canStop,
    secondary,
    Object.hashAll(labelCounts.keys),
    Object.hashAll(labelCounts.values),
  );

  @override
  String toString() => 'LaneControls(${state.name}, ${primary.name})';
}

/// Everything a lane shows at one instant.
@immutable
final class LaneView {
  const LaneView({
    required this.snapshot,
    required this.time,
    required this.controls,
  });

  final TrackSnapshot snapshot;
  final LaneTime time;
  final LaneControls controls;

  /// Time is advancing: the lane has to follow the shared ticker.
  bool get ticking => snapshot.isTicking;
}

/// The open session of [track] if it belongs to the track's current mode;
/// a session left over from another mode is ignored (the editor stops it
/// when the mode changes).
OpenSession? laneSession(Track track, OpenSession? open) =>
    open != null && open.session.mode == track.mode ? open : null;

/// Derives the snapshot a lane is based on.
TrackSnapshot laneSnapshot(Track track, OpenSession? open, int nowMs) {
  final session = laneSession(track, open);
  return deriveSnapshot(
    config: session?.session.config ?? track.config,
    events: session?.events ?? const <TrackEvent>[],
    nowMs: nowMs,
  );
}

/// Pure: track + open session + now + preferences => what the lane shows.
LaneView buildLaneView({
  required Track track,
  required OpenSession? open,
  required int nowMs,
  UiPrefs prefs = UiPrefs.defaults,
  int blinkMs = 600,
}) {
  final snapshot = laneSnapshot(track, open, nowMs);
  final blinkOn =
      snapshot.isRinging && blinkMs > 0 && (nowMs ~/ blinkMs).isEven;
  final (time, controls) = switch (snapshot) {
    StopwatchSnapshot() => _stopwatch(track, snapshot, prefs),
    CountdownSnapshot() => _countdown(snapshot, prefs, blinkOn),
    IntervalSnapshot() => _interval(snapshot, prefs, blinkOn),
    CounterSnapshot() => _counter(track, open, snapshot, prefs),
    ReminderSnapshot() => _reminder(snapshot, prefs, blinkOn),
    ProtocolSnapshot() => (
      LaneTime(digits: '${snapshot.entryCount}', subLine: ''),
      LaneControls(
        state: snapshot.state,
        look: _look(snapshot),
        primary: LanePrimary.none,
        canStop: snapshot.isOpen,
      ),
    ),
  };
  return LaneView(snapshot: snapshot, time: time, controls: controls);
}

String _status(TrackSnapshot s, {bool due = false}) => switch (s.state) {
  RunState.idle => Strings.statusIdle,
  RunState.running => Strings.statusRunning,
  RunState.paused => Strings.statusPaused,
  RunState.ringing => due ? Strings.statusDue : Strings.statusRinging,
  RunState.stopped => Strings.statusStopped,
};

LaneLook _look(TrackSnapshot s, {bool due = false}) => switch (s.state) {
  RunState.idle || RunState.stopped => LaneLook.idle,
  RunState.running => LaneLook.running,
  RunState.paused => LaneLook.paused,
  RunState.ringing => due ? LaneLook.due : LaneLook.ringing,
};

/// The "Stopp" button of a paused lane.
const _stopWhenPaused = LaneSecondary(LaneSecondaryKind.stop, enabled: true);

/// "neu starten" while open, "Stopp" while paused.
LaneSecondary? _restartOrStop(TrackSnapshot s) => switch (s.state) {
  RunState.running || RunState.ringing => const LaneSecondary(
    LaneSecondaryKind.restart,
    enabled: true,
  ),
  RunState.paused => _stopWhenPaused,
  RunState.idle || RunState.stopped => null,
};

String _join(Iterable<String?> parts) => [
  for (final p in parts)
    if (p != null && p.isNotEmpty) p,
].join(TracksStrings.separator);

double _quantize(double progress) => (progress * 1000).round() / 1000;

LanePrimary _startPause(TrackSnapshot s, {required LanePrimary onRinging}) =>
    switch (s.state) {
      RunState.idle || RunState.stopped => LanePrimary.start,
      RunState.running => LanePrimary.pause,
      RunState.paused => LanePrimary.resume,
      RunState.ringing => onRinging,
    };

(LaneTime, LaneControls) _stopwatch(
  Track track,
  StopwatchSnapshot s,
  UiPrefs prefs,
) {
  final config = track.config;
  final exclusive = config is StopwatchConfig && config.exclusive;
  final String subLine;
  if (s.isIdle) {
    subLine = _join([
      Strings.statusIdle,
      if (exclusive) TracksStrings.exclusiveTag,
    ]);
  } else if (s.lapCount > 0) {
    subLine = _join([
      if (s.isPaused) Strings.statusPaused,
      '${Strings.lapNumber(s.currentLapNumber)} ${Fmt.clock(s.currentLapMs)}',
      Strings.lastLap(Fmt.clock(s.laps.last.durationMs)),
    ]);
  } else {
    subLine = _join([_status(s), if (exclusive) TracksStrings.exclusiveTag]);
  }
  return (
    LaneTime(
      digits: Fmt.clock(s.elapsedMs, tenths: prefs.showTenths),
      subLine: subLine,
    ),
    LaneControls(
      state: s.state,
      look: _look(s),
      status: _status(s),
      primary: _startPause(s, onRinging: LanePrimary.pause),
      canStop: s.isOpen,
      secondary: switch (s.state) {
        RunState.running || RunState.ringing => const LaneSecondary(
          LaneSecondaryKind.lap,
          enabled: true,
        ),
        RunState.paused => _stopWhenPaused,
        RunState.idle || RunState.stopped => null,
      },
    ),
  );
}

(LaneTime, LaneControls) _countdown(
  CountdownSnapshot s,
  UiPrefs prefs,
  bool blinkOn,
) {
  final String subLine;
  switch (s.state) {
    case RunState.idle || RunState.stopped:
      subLine = _join([
        Strings.statusIdle,
        if (s.autoRestart) TracksStrings.autoRestartTag,
      ]);
    case RunState.running:
      final dueAt = s.dueAt;
      subLine = _join([
        if (dueAt != null)
          TracksStrings.until(Fmt.time(dueAt, use24h: prefs.use24h))
        else
          Strings.statusRunning,
        if (s.autoRestart && s.completedCycles > 0)
          Strings.cyclesDone(s.completedCycles),
      ]);
    case RunState.paused:
      subLine = _join([
        Strings.statusPaused,
        if (s.autoRestart && s.completedCycles > 0)
          Strings.cyclesDone(s.completedCycles),
      ]);
    case RunState.ringing:
      final finishedAt = s.lastFinishedAt;
      subLine = _join([
        Strings.statusRinging,
        if (finishedAt != null) Fmt.time(finishedAt, use24h: prefs.use24h),
      ]);
  }
  final digits = s.finished
      ? '${TracksStrings.overtimePrefix}${Fmt.clock(s.overtimeMs)}'
      : Fmt.remaining(s.remainingMs, tenths: prefs.showTenths);
  return (
    LaneTime(
      digits: digits,
      subLine: subLine,
      progress: _quantize(s.progress),
      alert: s.isRinging,
      blinkOn: blinkOn,
    ),
    LaneControls(
      state: s.state,
      look: _look(s),
      status: _status(s),
      primary: _startPause(s, onRinging: LanePrimary.dismiss),
      canStop: s.isOpen,
      // Ringing: "+1′" (rings again in a minute); otherwise as usual.
      secondary: s.isRinging && s.finished
          ? const LaneSecondary(LaneSecondaryKind.plusMinute, enabled: true)
          : _restartOrStop(s),
    ),
  );
}

(LaneTime, LaneControls) _interval(
  IntervalSnapshot s,
  UiPrefs prefs,
  bool blinkOn,
) {
  String phaseName() => switch (s.phase) {
    IntervalPhase.work => Strings.phaseWork,
    IntervalPhase.rest => Strings.phaseRest,
    IntervalPhase.done => Strings.phaseDone,
  };
  final String subLine;
  if (s.isIdle) {
    final work = Fmt.clock(s.phaseDurationMs);
    // The idle snapshot carries the work phase; the rest length follows
    // from the total duration.
    final restTotal = s.totalDurationMs - s.rounds * s.phaseDurationMs;
    final rest = s.rounds > 1 ? restTotal ~/ (s.rounds - 1) : 0;
    subLine = rest > 0
        ? TracksStrings.intervalProgramme(s.rounds, work, Fmt.clock(rest))
        : TracksStrings.intervalProgrammeNoRest(s.rounds, work);
  } else if (s.finished) {
    subLine = Strings.phaseDone;
  } else {
    subLine = _join([
      if (s.isPaused) Strings.statusPaused,
      Strings.roundOf(s.round, s.rounds),
      phaseName(),
    ]);
  }
  return (
    LaneTime(
      digits: s.finished
          ? Fmt.clock(0)
          : Fmt.remaining(s.phaseRemainingMs, tenths: prefs.showTenths),
      subLine: subLine,
      // The fill follows the digits: the share of the current phase.
      progress: s.finished ? 1 : _quantize(s.phaseProgress),
      segments: s.isIdle || s.rounds < 2
          ? null
          : LaneSegments(
              current: s.finished ? s.rounds + 1 : s.round,
              total: s.rounds,
            ),
      alert: s.isRinging,
      blinkOn: blinkOn,
    ),
    LaneControls(
      state: s.state,
      look: _look(s),
      status: s.finished ? Strings.phaseDone : _status(s),
      primary: _startPause(s, onRinging: LanePrimary.dismiss),
      canStop: s.isOpen,
      // Running: "nächste Runde" (not in the last round); ringing at the
      // end: "neu starten".
      secondary: s.isRunning
          ? LaneSecondary(LaneSecondaryKind.nextRound, enabled: s.canSkip)
          : _restartOrStop(s),
    ),
  );
}

(LaneTime, LaneControls) _counter(
  Track track,
  OpenSession? open,
  CounterSnapshot s,
  UiPrefs prefs,
) {
  final session = laneSession(track, open);
  final config = session?.session.config ?? track.config;
  final labels = config is CounterConfig ? config.labels : const <String>[];
  return (
    LaneTime(
      digits: Strings.countValue(s.count),
      secondaryDigits: s.isOpen ? Fmt.clock(s.currentLapMs) : null,
      subLine: s.isOpen
          ? _join([
              if (s.isPaused) Strings.statusPaused,
              Strings.totalTime(Fmt.clock(s.elapsedMs)),
            ])
          : TracksStrings.tapToCount,
    ),
    LaneControls(
      state: s.state,
      look: _look(s),
      status: _status(s),
      primary: labels.isEmpty ? LanePrimary.tick : LanePrimary.none,
      canStop: s.isOpen,
      secondary: s.isOpen
          ? LaneSecondary(LaneSecondaryKind.undo, enabled: s.canUndo)
          : null,
      labelCounts: {for (final l in labels) l: s.labelCounts[l] ?? 0},
    ),
  );
}

(LaneTime, LaneControls) _reminder(
  ReminderSnapshot s,
  UiPrefs prefs,
  bool blinkOn,
) {
  final acks = s.ackCount > 0 ? TracksStrings.ackCount(s.ackCount) : null;
  final dueAt = s.dueAt;
  final String subLine;
  switch (s.state) {
    case RunState.idle || RunState.stopped:
      subLine = TracksStrings.every(Fmt.compact(s.intervalMs));
    case RunState.running:
      subLine = _join([
        if (dueAt != null)
          TracksStrings.nextDueAt(Fmt.time(dueAt, use24h: prefs.use24h))
        else
          Strings.statusRunning,
        acks,
      ]);
    case RunState.paused:
      subLine = _join([Strings.statusPaused, acks]);
    case RunState.ringing:
      subLine = _join([
        if (dueAt != null)
          TracksStrings.dueSince(Fmt.time(dueAt, use24h: prefs.use24h))
        else
          Strings.statusDue,
        acks,
      ]);
  }
  return (
    LaneTime(
      digits: s.due && !s.isIdle
          ? '${TracksStrings.overtimePrefix}${Fmt.clock(s.overdueMs)}'
          : Fmt.remaining(s.remainingMs, tenths: prefs.showTenths),
      subLine: subLine,
      progress: _quantize(s.progress),
      alert: s.isRinging,
      blinkOn: blinkOn,
    ),
    LaneControls(
      state: s.state,
      look: _look(s, due: true),
      status: _status(s, due: true),
      primary: _startPause(s, onRinging: LanePrimary.ack),
      canStop: s.isOpen,
      secondary: switch (s.state) {
        RunState.running => const LaneSecondary(
          LaneSecondaryKind.ackEarly,
          enabled: true,
        ),
        RunState.paused => _stopWhenPaused,
        // The primary button acknowledges; "+10′" puts it off.
        RunState.ringing => const LaneSecondary(
          LaneSecondaryKind.snooze,
          enabled: true,
        ),
        RunState.idle || RunState.stopped => null,
      },
    ),
  );
}

/// Memoises the last [LaneView] of one lane, so the two selectors of a lane
/// (time and controls) derive the snapshot only once per tick.
final class LaneModel {
  LaneModel({
    required this.track,
    required this.open,
    required this.prefs,
    required this.blinkMs,
  });

  final Track track;
  final OpenSession? open;
  final UiPrefs prefs;
  final int blinkMs;

  int? _at;
  LaneView? _view;

  LaneView at(int nowMs) {
    final cached = _view;
    if (cached != null && _at == nowMs) return cached;
    final view = buildLaneView(
      track: track,
      open: open,
      nowMs: nowMs,
      prefs: prefs,
      blinkMs: blinkMs,
    );
    _at = nowMs;
    _view = view;
    return view;
  }
}
