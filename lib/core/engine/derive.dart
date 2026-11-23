import '../domain/enums.dart';
import '../domain/track_config.dart';
import '../domain/track_event.dart';
import 'snapshots.dart';
import 'timeline.dart';

/// Derives what a track shows at [nowMs] from its event log.
///
/// Pure: same input, same output. [events] are the events of ONE session (the
/// open one for a lane, any one for history) in any order; an empty list
/// yields the idle snapshot. [lockoutMsBySubstance] is only used by protocol
/// tracks and maps substance id to the user-set lockout.
TrackSnapshot deriveSnapshot({
  required TrackConfig config,
  required Iterable<TrackEvent> events,
  required int nowMs,
  Map<String, int> lockoutMsBySubstance = const {},
}) => switch (config) {
  StopwatchConfig() => deriveStopwatch(config, events, nowMs),
  CountdownConfig() => deriveCountdown(config, events, nowMs),
  IntervalConfig() => deriveInterval(config, events, nowMs),
  CounterConfig() => deriveCounter(config, events, nowMs),
  ReminderConfig() => deriveReminder(config, events, nowMs),
  ProtocolConfig() => deriveProtocol(
    config,
    events,
    nowMs,
    lockoutMsBySubstance: lockoutMsBySubstance,
  ),
};

StopwatchSnapshot deriveStopwatch(
  StopwatchConfig config,
  Iterable<TrackEvent> events,
  int nowMs,
) {
  final t = Timeline.build(events, nowMs);
  final laps = <LapInfo>[];
  var lastTotal = 0;
  for (final e in t.events) {
    if (e.type != EventType.lap) continue;
    final total = t.activeMsAt(e.at);
    laps.add(
      LapInfo(
        index: laps.length + 1,
        eventId: e.id,
        at: e.at,
        durationMs: total - lastTotal,
        totalMs: total,
        label: e.label,
      ),
    );
    lastTotal = total;
  }
  final elapsed = t.activeMs;
  return StopwatchSnapshot(
    state: t.baseState,
    nowMs: t.endAt,
    startedAt: t.startAt,
    stoppedAt: t.stopAt,
    elapsedMs: elapsed,
    pausedMs: t.pausedMs,
    totalMs: t.wallMs,
    laps: List.unmodifiable(laps),
    currentLapMs: elapsed - lastTotal,
  );
}

CountdownSnapshot deriveCountdown(
  CountdownConfig config,
  Iterable<TrackEvent> events,
  int nowMs,
) {
  final t = Timeline.build(events, nowMs);
  final duration = config.durationMs < 0 ? 0 : config.durationMs;
  final elapsed = t.activeMs;
  // A zero-length countdown cannot cycle; treat it as a plain one.
  final auto = config.autoRestart && duration > 0;

  var state = t.baseState;
  int remaining;
  var overtime = 0;
  var finished = false;
  var cycles = 0;
  int? dueAt;
  int? lastFinishedAt;

  if (!t.isStarted) {
    remaining = duration;
  } else if (auto) {
    cycles = elapsed ~/ duration;
    remaining = duration - elapsed % duration;
    if (t.isRunning) dueAt = t.endAt + remaining;
    if (cycles > 0) lastFinishedAt = t.wallAtActive(cycles * duration);
  } else {
    // "+1′" moves the end: from the later of the end and the tap.
    final target = extendedTarget(t, duration);
    finished = elapsed >= target;
    if (finished) {
      remaining = 0;
      overtime = elapsed - target;
      cycles = 1;
      lastFinishedAt = t.wallAtActive(target);
      if (state == RunState.running) state = RunState.ringing;
    } else {
      remaining = target - elapsed;
      if (t.isRunning) dueAt = t.endAt + remaining;
    }
  }

  return CountdownSnapshot(
    state: state,
    nowMs: t.endAt,
    startedAt: t.startAt,
    stoppedAt: t.stopAt,
    elapsedMs: elapsed,
    pausedMs: t.pausedMs,
    totalMs: t.wallMs,
    durationMs: duration,
    autoRestart: auto,
    remainingMs: remaining,
    overtimeMs: overtime,
    finished: finished,
    completedCycles: cycles,
    dueAt: dueAt,
    lastFinishedAt: lastFinishedAt,
  );
}

IntervalSnapshot deriveInterval(
  IntervalConfig config,
  Iterable<TrackEvent> events,
  int nowMs,
) {
  final t = Timeline.build(events, nowMs);
  final rounds = config.rounds < 1 ? 1 : config.rounds;
  final work = config.workMs < 0 ? 0 : config.workMs;
  final rest = config.restMs < 0 ? 0 : config.restMs;
  final total = rounds * work + (rounds - 1) * rest;
  final cycle = work + rest;
  // "nächste Runde" jumps ahead: the counting time plus what was skipped.
  var skipped = 0;
  int? skippedToEndAt;
  for (final e in t.events) {
    if (e.type != EventType.skip || cycle <= 0) continue;
    final at = t.activeMsAt(e.at) + skipped;
    if (at >= total) continue;
    final next = (at ~/ cycle + 1) * cycle;
    final to = next < total ? next : total;
    skipped += to - at;
    if (to >= total) skippedToEndAt = e.at;
  }
  final elapsed = t.activeMs + skipped;

  var state = t.baseState;
  var round = 1;
  var phase = IntervalPhase.work;
  var phaseDuration = work;
  var phaseElapsed = 0;
  var finished = false;
  int? nextBoundaryAt;
  int? finishAt;

  if (t.isStarted) {
    if (elapsed >= total) {
      finished = true;
      round = rounds;
      phase = IntervalPhase.done;
      phaseDuration = 0;
      phaseElapsed = 0;
      finishAt = skippedToEndAt ?? t.wallAtActive(total - skipped);
      if (state == RunState.running) state = RunState.ringing;
    } else {
      // total > elapsed >= 0 implies cycle > 0.
      final index = elapsed ~/ cycle;
      final within = elapsed % cycle;
      round = index + 1;
      if (within < work) {
        phase = IntervalPhase.work;
        phaseDuration = work;
        phaseElapsed = within;
      } else {
        phase = IntervalPhase.rest;
        phaseDuration = rest;
        phaseElapsed = within - work;
      }
      if (t.isRunning) {
        nextBoundaryAt = t.endAt + (phaseDuration - phaseElapsed);
        finishAt = t.endAt + (total - elapsed);
      }
    }
  }

  return IntervalSnapshot(
    state: state,
    nowMs: t.endAt,
    startedAt: t.startAt,
    stoppedAt: t.stopAt,
    elapsedMs: elapsed,
    pausedMs: t.pausedMs,
    totalMs: t.wallMs,
    rounds: rounds,
    round: round,
    phase: phase,
    phaseDurationMs: phaseDuration,
    phaseElapsedMs: phaseElapsed,
    phaseRemainingMs: phaseDuration - phaseElapsed,
    totalDurationMs: total,
    finished: finished,
    nextBoundaryAt: nextBoundaryAt,
    finishAt: finishAt,
  );
}

CounterSnapshot deriveCounter(
  CounterConfig config,
  Iterable<TrackEvent> events,
  int nowMs,
) {
  final t = Timeline.build(events, nowMs);
  final ticks = <TickInfo>[];
  final labelCounts = <String, int>{for (final l in config.labels) l: 0};
  var unlabeled = 0;
  var lastActive = 0;
  for (final e in t.events) {
    if (e.type != EventType.tick) continue;
    final active = t.activeMsAt(e.at);
    ticks.add(
      TickInfo(
        index: ticks.length + 1,
        eventId: e.id,
        at: e.at,
        lapMs: active - lastActive,
        label: e.label,
      ),
    );
    lastActive = active;
    final label = e.label;
    if (label == null || label.isEmpty) {
      unlabeled++;
    } else {
      labelCounts[label] = (labelCounts[label] ?? 0) + 1;
    }
  }
  final elapsed = t.activeMs;
  return CounterSnapshot(
    state: t.baseState,
    nowMs: t.endAt,
    startedAt: t.startAt,
    stoppedAt: t.stopAt,
    elapsedMs: elapsed,
    pausedMs: t.pausedMs,
    totalMs: t.wallMs,
    ticks: List.unmodifiable(ticks),
    currentLapMs: elapsed - lastActive,
    labelCounts: Map.unmodifiable(labelCounts),
    unlabeledCount: unlabeled,
  );
}

ReminderSnapshot deriveReminder(
  ReminderConfig config,
  Iterable<TrackEvent> events,
  int nowMs,
) {
  final t = Timeline.build(events, nowMs);
  final interval = config.intervalMs < 0 ? 0 : config.intervalMs;
  final nag = config.nagEveryMs < 0 ? 0 : config.nagEveryMs;

  if (!t.isStarted) {
    return ReminderSnapshot(
      state: RunState.idle,
      nowMs: t.endAt,
      startedAt: null,
      stoppedAt: null,
      elapsedMs: 0,
      pausedMs: 0,
      totalMs: 0,
      intervalMs: interval,
      nagEveryMs: nag,
      anchorAt: null,
      sinceAnchorMs: 0,
      remainingMs: interval,
      due: false,
      overdueMs: 0,
      dueAt: null,
      nagCount: 0,
      nextNagAt: null,
      acks: const [],
    );
  }

  final acks = <AckInfo>[];
  var anchorActive = 0;
  var anchorAt = t.startAt!;
  // When it is due, in counting time; "+10′" moves it, an ack resets it.
  var target = interval;
  for (final e in t.events) {
    if (e.type == EventType.extend) {
      if (e.extendMs <= 0) continue;
      final at = t.activeMsAt(e.at);
      target = (target > at ? target : at) + e.extendMs;
      continue;
    }
    if (e.type != EventType.ack) continue;
    final active = t.activeMsAt(e.at);
    final waited = active - anchorActive;
    acks.add(
      AckInfo(
        index: acks.length + 1,
        eventId: e.id,
        at: e.at,
        waitedMs: waited,
        delayMs: waited > interval ? waited - interval : 0,
      ),
    );
    anchorActive = active;
    anchorAt = e.at;
    target = active + interval;
  }

  final elapsed = t.activeMs;
  final since = elapsed - anchorActive;
  final due = elapsed >= target;
  final overdue = due ? elapsed - target : 0;
  var state = t.baseState;
  if (due && state == RunState.running) state = RunState.ringing;

  return ReminderSnapshot(
    state: state,
    nowMs: t.endAt,
    startedAt: t.startAt,
    stoppedAt: t.stopAt,
    elapsedMs: elapsed,
    pausedMs: t.pausedMs,
    totalMs: t.wallMs,
    intervalMs: interval,
    nagEveryMs: nag,
    anchorAt: anchorAt,
    sinceAnchorMs: since,
    remainingMs: due ? 0 : target - elapsed,
    due: due,
    overdueMs: overdue,
    dueAt: t.wallAtActive(target),
    nagCount: due && nag > 0 ? overdue ~/ nag : 0,
    nextNagAt: due && nag > 0 && t.isRunning
        ? t.endAt + (nag - overdue % nag)
        : null,
    acks: List.unmodifiable(acks),
  );
}

/// When a person last logged a substance on a track - over ALL sessions
/// of the track, open or closed. `null` ids are entries without a person /
/// without a substance.
final class LastEntryFact {
  const LastEntryFact({
    required this.personId,
    required this.substanceId,
    required this.at,
  });

  final String? personId;
  final String? substanceId;

  /// Wall time (UTC ms) of the most recent such entry.
  final int at;

  @override
  bool operator ==(Object other) =>
      other is LastEntryFact &&
      other.personId == personId &&
      other.substanceId == substanceId &&
      other.at == at;

  @override
  int get hashCode => Object.hash(personId, substanceId, at);

  @override
  String toString() => 'LastEntryFact($personId, $substanceId @$at)';
}

/// The user-set lockouts that are still running at [nowMs], per person
/// (`null` = entries without a person), longest remaining first.
///
/// Works on the last entries of the whole TRACK, not of one session: a
/// lockout does not end because the session was closed ("Sitzung
/// beenden") or a new one was started. Persons without a running lockout
/// are not in the map. Like everywhere else nothing is invented: a
/// substance without a positive entry in [lockoutMsBySubstance] never
/// locks.
Map<String?, List<LockoutStatus>> deriveLockouts(
  Iterable<LastEntryFact> lastEntries,
  int nowMs, {
  Map<String, int> lockoutMsBySubstance = const {},
}) {
  // Several facts for the same pair: the latest one counts.
  final latest = <String?, Map<String, int>>{};
  for (final fact in lastEntries) {
    final substance = fact.substanceId;
    if (substance == null) continue;
    final bySubstance = latest.putIfAbsent(fact.personId, () => {});
    final known = bySubstance[substance];
    if (known == null || fact.at > known) bySubstance[substance] = fact.at;
  }
  final result = <String?, List<LockoutStatus>>{};
  for (final person in latest.entries) {
    final lockouts = _runningLockouts(
      person.value,
      nowMs,
      lockoutMsBySubstance,
    );
    if (lockouts.isNotEmpty) result[person.key] = lockouts;
  }
  return result;
}

/// The most recent entry time per person from [lastEntries].
Map<String?, int> lastEntryAtByPerson(Iterable<LastEntryFact> lastEntries) {
  final result = <String?, int>{};
  for (final fact in lastEntries) {
    final known = result[fact.personId];
    if (known == null || fact.at > known) result[fact.personId] = fact.at;
  }
  return result;
}

List<LockoutStatus> _runningLockouts(
  Map<String, int> lastBySubstance,
  int reference,
  Map<String, int> lockoutMsBySubstance,
) {
  final lockouts = <LockoutStatus>[];
  for (final s in lastBySubstance.entries) {
    final lockoutMs = lockoutMsBySubstance[s.key];
    if (lockoutMs == null || lockoutMs <= 0) continue;
    final until = s.value + lockoutMs;
    if (until <= reference) continue;
    lockouts.add(
      LockoutStatus(
        substanceId: s.key,
        lastEntryAt: s.value,
        untilAt: until,
        remainingMs: until - reference,
      ),
    );
  }
  lockouts.sort((a, b) => b.remainingMs.compareTo(a.remainingMs));
  return List.unmodifiable(lockouts);
}

/// The protocol state of ONE session. Its lockouts only know the entries
/// of that session; what the lane shows comes from [deriveLockouts], which
/// looks at the whole track.
ProtocolSnapshot deriveProtocol(
  ProtocolConfig config,
  Iterable<TrackEvent> events,
  int nowMs, {
  Map<String, int> lockoutMsBySubstance = const {},
}) {
  final t = Timeline.build(events, nowMs);
  // Entry times are user-editable, so they are taken as logged (not clamped
  // into the session) and "since" is measured against the real now.
  final reference = t.stopAt ?? nowMs;
  final entries = [
    for (final e in sortEvents(events))
      if (e.type == EventType.entry) ProtocolEntry(event: e),
  ];

  final byPerson = <String?, List<ProtocolEntry>>{};
  for (final entry in entries) {
    byPerson.putIfAbsent(entry.personId, () => []).add(entry);
  }

  final persons = <PersonProtocolStatus>[];
  for (final group in byPerson.entries) {
    final list = group.value;
    final last = list.last;
    final lastBySubstance = <String, int>{};
    for (final entry in list) {
      final substance = entry.substanceId;
      if (substance != null) lastBySubstance[substance] = entry.at;
    }
    final lockouts = _runningLockouts(
      lastBySubstance,
      reference,
      lockoutMsBySubstance,
    );
    final since = reference - last.at;
    persons.add(
      PersonProtocolStatus(
        personId: group.key,
        lastEntry: last,
        sinceMs: since < 0 ? 0 : since,
        entryCount: list.length,
        lockouts: lockouts,
      ),
    );
  }
  persons.sort((a, b) => b.lastEntry.at.compareTo(a.lastEntry.at));

  return ProtocolSnapshot(
    state: t.baseState,
    nowMs: t.endAt,
    startedAt: t.startAt,
    stoppedAt: t.stopAt,
    elapsedMs: t.activeMs,
    pausedMs: t.pausedMs,
    totalMs: t.wallMs,
    entries: List.unmodifiable(entries),
    persons: List.unmodifiable(persons),
  );
}

/// The counting time at which a countdown of [durationMs] ends, after the
/// `extend` events ("+1′") of [t]: each one adds its time to the later of
/// the end so far and the moment it was tapped.
int extendedTarget(Timeline t, int durationMs) {
  var target = durationMs;
  for (final e in t.events) {
    if (e.type != EventType.extend || e.extendMs <= 0) continue;
    final at = t.activeMsAt(e.at);
    target = (target > at ? target : at) + e.extendMs;
  }
  return target;
}
