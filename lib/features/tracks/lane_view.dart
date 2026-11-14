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

/// The small secondary buttons of a lane.
enum LaneSecondaryKind { lap, restart, reset, undo, stop, ackEarly }

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
    this.alert = false,
    this.blinkOn = false,
  });

  /// The large time or count.
  final String digits;

  /// Smaller figure next to the digits (lap time of a counter).
  final String? secondaryDigits;

  /// Muted status line.
  final String subLine;

  /// 0..1 for the thin progress bar; `null` when the mode has none.
  final double? progress;

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
      other.alert == alert &&
      other.blinkOn == blinkOn;

  @override
  int get hashCode =>
      Object.hash(digits, secondaryDigits, subLine, progress, alert, blinkOn);

  @override
  String toString() => 'LaneTime($digits, $secondaryDigits, $subLine)';
}

/// The part of a lane that only changes with its state: buttons and the
/// ringing frame.
@immutable
final class LaneControls {
  const LaneControls({
    required this.state,
    required this.primary,
    required this.secondary,
    this.labelCounts = const {},
    this.status = '',
  });

  final RunState state;
  final LanePrimary primary;
  final List<LaneSecondary> secondary;

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
      other.primary == primary &&
      other.status == status &&
      listEquals(other.secondary, secondary) &&
      mapEquals(other.labelCounts, labelCounts);

  @override
  int get hashCode => Object.hash(
    state,
    primary,
    status,
    Object.hashAll(secondary),
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
        primary: LanePrimary.none,
        secondary: const [],
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
    subLine = _join([
      _status(s),
      if (exclusive) TracksStrings.exclusiveTag,
    ]);
  }
  return (
    LaneTime(
      digits: Fmt.clock(s.elapsedMs, tenths: prefs.showTenths),
      subLine: subLine,
    ),
    LaneControls(
      state: s.state,
      status: _status(s),
      primary: _startPause(s, onRinging: LanePrimary.pause),
      secondary: [
        LaneSecondary(LaneSecondaryKind.lap, enabled: s.isRunning),
        LaneSecondary(LaneSecondaryKind.reset, enabled: s.isOpen),
      ],
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
      status: _status(s),
      primary: _startPause(s, onRinging: LanePrimary.dismiss),
      secondary: [
        LaneSecondary(LaneSecondaryKind.restart, enabled: s.isOpen),
        LaneSecondary(
          LaneSecondaryKind.reset,
          enabled: s.isOpen && !s.isRinging,
        ),
      ],
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
      progress: _quantize(s.progress),
      alert: s.isRinging,
      blinkOn: blinkOn,
    ),
    LaneControls(
      state: s.state,
      status: s.finished ? Strings.phaseDone : _status(s),
      primary: _startPause(s, onRinging: LanePrimary.dismiss),
      secondary: [
        LaneSecondary(LaneSecondaryKind.restart, enabled: s.isOpen),
        LaneSecondary(
          LaneSecondaryKind.reset,
          enabled: s.isOpen && !s.isRinging,
        ),
      ],
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
      status: _status(s),
      primary: labels.isEmpty ? LanePrimary.tick : LanePrimary.none,
      secondary: [
        LaneSecondary(LaneSecondaryKind.undo, enabled: s.canUndo),
        LaneSecondary(LaneSecondaryKind.stop, enabled: s.isOpen),
      ],
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
      status: _status(s, due: true),
      primary: _startPause(s, onRinging: LanePrimary.ack),
      secondary: [
        LaneSecondary(
          LaneSecondaryKind.ackEarly,
          enabled: s.isOpen && !s.isRinging,
        ),
        LaneSecondary(LaneSecondaryKind.reset, enabled: s.isOpen),
      ],
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
