import 'package:flutter/foundation.dart';

import '../../../core/domain/domain.dart';
import '../../../core/engine/engine.dart';
import '../../../core/repo/models.dart';
import '../../../l10n/formatters.dart';
import '../../../l10n/strings.dart';
import '../../../theme/ui_prefs.dart';
import '../../protocol/protocol_logic.dart';
import '../lane_view.dart';
import '../tracks_strings.dart';

// Pure logic of the tap pad ("Tippfeld"): which buttons there are, how they
// are laid out, what a tap does and what a button shows. No widgets, no
// providers - everything here is unit tested.

/// A second tap on the SAME button within this time is ignored (a finger
/// that bounces). Taps on different buttons are never dropped.
const int padSameButtonGuardMs = 150;

/// How many buttons the keys 1-9 and 0 reach.
const int padShortcutCount = 10;

/// What a button of the pad stands for.
enum PadButtonKind {
  /// A counter, or one quick label of a counter: tap = tick.
  counter,

  /// A stopwatch: start, lap, resume.
  stopwatch,

  /// Countdown, interval or reminder: start, dismiss / acknowledge.
  timer,

  /// A person of the scene: shows where that person stands and opens the
  /// page "Was?".
  person,

  /// A substance for a person: tap = entry.
  substance,

  /// "Anderes": the page with the person's other substances and a field
  /// for a new one.
  other,
}

/// One button of the pad. [id] is stable for as long as the thing behind
/// it exists, so buttons can keep their places.
@immutable
final class PadButton {
  const PadButton._({
    required this.id,
    required this.kind,
    Track? track,
    this.label,
    this.personId,
    this.substanceId,
  }) : trackOrNull = track;

  factory PadButton.counter(Track track, {String? label}) => PadButton._(
    id: label == null ? 'c:${track.id}' : 'c:${track.id}:$label',
    kind: PadButtonKind.counter,
    track: track,
    label: label,
  );

  factory PadButton.stopwatch(Track track) => PadButton._(
    id: 's:${track.id}',
    kind: PadButtonKind.stopwatch,
    track: track,
  );

  factory PadButton.timer(Track track) =>
      PadButton._(id: 't:${track.id}', kind: PadButtonKind.timer, track: track);

  factory PadButton.person(String personId) => PadButton._(
    id: 'p:$personId',
    kind: PadButtonKind.person,
    personId: personId,
  );

  factory PadButton.substance({
    required String personId,
    required String substanceId,
  }) => PadButton._(
    id: 'x:$personId:$substanceId',
    kind: PadButtonKind.substance,
    personId: personId,
    substanceId: substanceId,
  );

  factory PadButton.other(String personId) => PadButton._(
    id: 'o:$personId',
    kind: PadButtonKind.other,
    personId: personId,
  );

  final String id;
  final PadButtonKind kind;

  /// The track of a counter, stopwatch or timer button; `null` for the
  /// protocol buttons, which belong to a person and not to a track.
  final Track? trackOrNull;

  /// The track of a counter, stopwatch or timer button. Only for those.
  Track get track => trackOrNull!;

  /// Quick label of a counter button; `null` for a counter without labels.
  final String? label;

  /// Person of a person / substance / "Anderes" button.
  final String? personId;
  final String? substanceId;

  @override
  bool operator ==(Object other) =>
      other is PadButton &&
      other.id == id &&
      other.kind == kind &&
      other.trackOrNull == trackOrNull &&
      other.label == label &&
      other.personId == personId &&
      other.substanceId == substanceId;

  @override
  int get hashCode =>
      Object.hash(id, kind, trackOrNull, label, personId, substanceId);

  @override
  String toString() => 'PadButton($id)';
}

/// The page "Was?" of [personId]: the things of the scene in the order of
/// the scene, the same for every person and always at the same place,
/// followed by "Anderes". At most [limit] things.
///
/// The pad never invents a field: without things in the scene the page
/// has only "Anderes".
List<PadButton> buildSubstancePad({
  required String personId,
  required List<String> sceneSubstanceIds,
  required List<Substance> substances,
  int limit = captureSubstanceLimit,
}) {
  final available = {for (final s in substances) s.id};
  final seen = <String>{};
  final ids = [
    for (final id in sceneSubstanceIds)
      if (available.contains(id) && seen.add(id)) id,
  ];
  return [
    for (final id in ids.take(limit))
      PadButton.substance(personId: personId, substanceId: id),
    PadButton.other(personId),
  ];
}

/// The page "Anderes": every thing of [substances] that is not already on
/// the page "Was?" ([shownIds]). First what this person had most often
/// ([use], the most recent first when the counts are equal), then the rest
/// in the order of the user's list.
List<PadButton> buildOtherPad({
  required String personId,
  required List<Substance> substances,
  required Set<String> shownIds,
  Iterable<SubstanceUse> use = const [],
}) {
  final own = {
    for (final u in use)
      if (u.personId == personId && u.substanceId != null) u.substanceId!: u,
  };
  final rest = [
    for (final s in substances)
      if (!shownIds.contains(s.id)) s,
  ];
  final order = {for (var i = 0; i < rest.length; i++) rest[i].id: i};
  rest.sort((a, b) {
    final ua = own[a.id];
    final ub = own[b.id];
    if (ua != null && ub != null) {
      final byCount = ub.count.compareTo(ua.count);
      if (byCount != 0) return byCount;
      final byLast = ub.lastAt.compareTo(ua.lastAt);
      if (byLast != 0) return byLast;
    } else if (ua != null) {
      return -1;
    } else if (ub != null) {
      return 1;
    }
    return order[a.id]!.compareTo(order[b.id]!);
  });
  return [
    for (final s in rest)
      PadButton.substance(personId: personId, substanceId: s.id),
  ];
}

/// The buttons of the main pad ("das Brett"):
///
/// * first the persons of the scene, in the order of the scene: one tile
///   per person; with exactly one person that person's things right away
///   ([buildSubstancePad]);
/// * then the tracks in their order: a counter with quick labels gets one
///   button per label, every other counter, stopwatch and timer one.
///
/// A set without persons in its scene has no protocol on the pad.
List<PadButton> buildMainPad({
  required List<Track> tracks,
  required List<Person> persons,
  required List<String> scenePersonIds,
  required List<String> sceneSubstanceIds,
  required List<Substance> substances,
}) {
  final known = {for (final p in persons) p.id};
  final seen = <String>{};
  final scene = [
    for (final id in scenePersonIds)
      if (known.contains(id) && seen.add(id)) id,
  ];
  final result = <PadButton>[];
  if (scene.length == 1) {
    result.addAll(
      buildSubstancePad(
        personId: scene.single,
        sceneSubstanceIds: sceneSubstanceIds,
        substances: substances,
      ),
    );
  } else {
    for (final id in scene) {
      result.add(PadButton.person(id));
    }
  }
  for (final track in tracks) {
    switch (track.config) {
      case CounterConfig(:final labels):
        if (labels.isEmpty) {
          result.add(PadButton.counter(track));
        } else {
          final seenLabels = <String>{};
          for (final label in labels) {
            if (seenLabels.add(label)) {
              result.add(PadButton.counter(track, label: label));
            }
          }
        }
      case StopwatchConfig():
        result.add(PadButton.stopwatch(track));
      case CountdownConfig() || IntervalConfig() || ReminderConfig():
        result.add(PadButton.timer(track));
      case ProtocolConfig():
        // No longer a track of its own: the protocol is the scene.
        break;
    }
  }
  return result;
}

/// Keeps the buttons of the main pad where they are while it is open: the
/// buttons of [shownIds] that still exist stay in their order, new ones go
/// to the end, gone ones leave. Nothing moves under a finger because a
/// track was reordered or somebody joined the scene.
List<PadButton> mergePadButtons({
  required List<String> shownIds,
  required List<PadButton> fresh,
}) {
  final byId = {for (final b in fresh) b.id: b};
  final taken = <String>{};
  final result = <PadButton>[];
  for (final id in shownIds) {
    final button = byId[id];
    if (button != null && taken.add(id)) result.add(button);
  }
  for (final button in fresh) {
    if (taken.add(button.id)) result.add(button);
  }
  return result;
}

// ------------------------------------------------------------------ layout

/// How the buttons fill the pad.
@immutable
final class PadLayout {
  const PadLayout({
    required this.columns,
    required this.rows,
    required this.rowHeight,
    required this.scrolls,
  });

  final int columns;
  final int rows;

  /// Height of one row of buttons.
  final double rowHeight;

  /// The buttons do not fit: the pad scrolls with rows of the minimum
  /// height.
  final bool scrolls;

  @override
  bool operator ==(Object other) =>
      other is PadLayout &&
      other.columns == columns &&
      other.rows == rows &&
      other.rowHeight == rowHeight &&
      other.scrolls == scrolls;

  @override
  int get hashCode => Object.hash(columns, rows, rowHeight, scrolls);

  @override
  String toString() =>
      'PadLayout($columns x $rows, rowHeight: $rowHeight, scrolls: $scrolls)';
}

/// Chooses columns and rows so that [count] buttons FILL a pad of
/// [width] x [height]:
///
/// * a column is at least [minButtonWidth] wide, a row at least
///   [minButtonHeight] high, with [gap] between buttons;
/// * of all grids that fit, the one with the best button shape wins
///   (buttons about one and a half times as wide as high are the easiest
///   to hit; with equal shape fewer columns win);
/// * when nothing fits, the pad scrolls: as many columns as the width
///   allows, rows of the minimum height.
PadLayout computePadLayout({
  required int count,
  required double width,
  required double height,
  required double minButtonHeight,
  required double minButtonWidth,
  required double gap,
  int minColumns = 1,
}) {
  if (count <= 0) {
    return PadLayout(
      columns: 1,
      rows: 0,
      rowHeight: minButtonHeight,
      scrolls: false,
    );
  }
  var maxColumns = ((width + gap) / (minButtonWidth + gap)).floor();
  if (maxColumns < 1) maxColumns = 1;
  if (maxColumns > count) maxColumns = count;
  // At least [minColumns] where the width and the count allow it.
  final fewest = minColumns.clamp(1, maxColumns);

  const preferredAspect = 1.5;
  PadLayout? best;
  var bestScore = -1.0;
  for (var columns = fewest; columns <= maxColumns; columns++) {
    final rows = (count + columns - 1) ~/ columns;
    final rowHeight = (height - gap * (rows - 1)) / rows;
    if (rowHeight < minButtonHeight) continue;
    final buttonWidth = (width - gap * (columns - 1)) / columns;
    final byWidth = buttonWidth / preferredAspect;
    final score = byWidth < rowHeight ? byWidth : rowHeight;
    if (score > bestScore) {
      bestScore = score;
      best = PadLayout(
        columns: columns,
        rows: rows,
        rowHeight: rowHeight,
        scrolls: false,
      );
    }
  }
  if (best != null) return best;
  return PadLayout(
    columns: maxColumns,
    rows: (count + maxColumns - 1) ~/ maxColumns,
    rowHeight: minButtonHeight,
    scrolls: true,
  );
}

// -------------------------------------------------------------------- taps

/// What a tap on a button does.
enum PadTapAction {
  /// Counter: count one (the first tap starts the session).
  tick,

  /// Stopwatch / timer that is idle.
  start,

  /// Running stopwatch.
  lap,

  /// Paused stopwatch.
  resume,

  /// Ringing countdown / interval.
  dismiss,

  /// Due reminder.
  ack,

  /// Protocol: write the entry.
  entry,

  /// Protocol: show the substance buttons of the person.
  openPerson,

  /// Protocol: open the page "Anderes".
  openOther,

  /// Nothing (a running or paused timer: pausing is done in the lanes).
  none,
}

/// Decides what a tap on [button] does while its track is in [state].
PadTapAction padTapAction(PadButton button, RunState state) {
  switch (button.kind) {
    case PadButtonKind.counter:
      return PadTapAction.tick;
    case PadButtonKind.stopwatch:
      return switch (state) {
        RunState.idle || RunState.stopped => PadTapAction.start,
        RunState.running => PadTapAction.lap,
        RunState.paused => PadTapAction.resume,
        RunState.ringing => PadTapAction.none,
      };
    case PadButtonKind.timer:
      return switch (state) {
        RunState.idle || RunState.stopped => PadTapAction.start,
        RunState.ringing =>
          button.track.mode == TrackMode.reminder
              ? PadTapAction.ack
              : PadTapAction.dismiss,
        RunState.running || RunState.paused => PadTapAction.none,
      };
    case PadButtonKind.person:
      return PadTapAction.openPerson;
    case PadButtonKind.substance:
      return PadTapAction.entry;
    case PadButtonKind.other:
      return PadTapAction.openOther;
  }
}

// ------------------------------------------------------------------- faces

Iterable<TrackEvent> _events(PadButton button, OpenSession? open) {
  final track = button.trackOrNull;
  if (track == null) return const <TrackEvent>[];
  return laneSession(track, open)?.events ?? const <TrackEvent>[];
}

bool _counts(PadButton button, TrackEvent e) =>
    button.kind == PadButtonKind.counter &&
    e.type == EventType.tick &&
    (button.label == null || e.label == button.label);

/// How often a counter button was tapped in the open session.
int padCount(PadButton button, OpenSession? open) {
  var n = 0;
  for (final e in _events(button, open)) {
    if (_counts(button, e)) n++;
  }
  return n;
}

/// When the button last did something in the open session (wall time).
int? padLastTapAt(PadButton button, OpenSession? open) {
  int? last;
  final any =
      button.kind == PadButtonKind.stopwatch ||
      button.kind == PadButtonKind.timer;
  for (final e in _events(button, open)) {
    if (!any && !_counts(button, e)) continue;
    if (last == null || e.at > last) last = e.at;
  }
  return last;
}

/// The big value of a track button: the count or the time.
String padValue(
  PadButton button,
  OpenSession? open,
  int nowMs, {
  UiPrefs prefs = UiPrefs.defaults,
}) {
  switch (button.kind) {
    case PadButtonKind.counter:
      return Strings.countValue(padCount(button, open));
    case PadButtonKind.stopwatch || PadButtonKind.timer:
      return buildLaneView(
        track: button.track,
        open: open,
        nowMs: nowMs,
        prefs: prefs,
      ).time.digits;
    case PadButtonKind.person || PadButtonKind.substance || PadButtonKind.other:
      return '';
  }
}

/// "vor 12 min" since [lastAt]; empty without one.
String padSince(int? lastAt, int nowMs) {
  if (lastAt == null) return '';
  final ms = nowMs > lastAt ? nowMs - lastAt : 0;
  return Strings.ago(Fmt.compact(ms));
}

/// The small line of a track button.
String padSubText(PadButton button, OpenSession? open, int nowMs) {
  switch (button.kind) {
    case PadButtonKind.counter:
      return padSince(padLastTapAt(button, open), nowMs);
    case PadButtonKind.person || PadButtonKind.substance:
      return '';
    case PadButtonKind.other:
      return TracksStrings.padMore;
    case PadButtonKind.stopwatch:
      final snapshot = laneSnapshot(button.track, open, nowMs);
      return switch (snapshot.state) {
        RunState.idle || RunState.stopped => TracksStrings.padTapToStart,
        RunState.paused => TracksStrings.padTapToResume,
        RunState.running || RunState.ringing =>
          snapshot is StopwatchSnapshot && snapshot.lapCount > 0
              ? TracksStrings.padLapSince(
                  snapshot.lapCount,
                  padSince(snapshot.laps.last.at, nowMs),
                )
              : TracksStrings.padTapForLap,
      };
    case PadButtonKind.timer:
      final snapshot = laneSnapshot(button.track, open, nowMs);
      return switch (snapshot.state) {
        RunState.idle || RunState.stopped => TracksStrings.padTapToStart,
        RunState.running => Strings.statusRunning,
        RunState.paused => Strings.statusPaused,
        RunState.ringing =>
          button.track.mode == TrackMode.reminder
              ? TracksStrings.padTapToAck
              : TracksStrings.padTapToDismiss,
      };
  }
}

/// Whether the face of a track button changes with the clock.
bool padIsLive(PadButton button, OpenSession? open, int nowMs) {
  switch (button.kind) {
    case PadButtonKind.person || PadButtonKind.substance || PadButtonKind.other:
      return false;
    case PadButtonKind.counter:
      return padLastTapAt(button, open) != null;
    case PadButtonKind.stopwatch || PadButtonKind.timer:
      return laneSnapshot(button.track, open, nowMs).isTicking;
  }
}

// ---------------------------------------------------------------- protocol

/// How often the person of a thing button had that thing today
/// ([counts]: `entryCountsOfDay`).
int padEntryCount(PadButton button, Map<String, Map<String, int>> counts) =>
    counts[button.personId]?[button.substanceId] ?? 0;

/// What a person tile shows: the time since the decisive entry, a line
/// below it, whether that line is a running lockout of the user's own.
typedef PadPersonFace = ({String digits, String line, bool warn, bool any});

/// The face of a person tile for [stand] (see [personStand]).
///
/// [onlySubstanceId]: the thing the board is narrowed to, if any.
PadPersonFace padPersonFace(
  PersonStand stand,
  Map<String, Substance> substances, {
  String? onlySubstanceId,
}) {
  final since = stand.sinceMs;
  if (since == null) {
    final only = substances[onlySubstanceId]?.name;
    return (
      digits: TracksStrings.padNoEntry,
      line: only == null
          ? TracksStrings.padNothingYet
          : TracksStrings.padNothingOf(only),
      warn: false,
      any: false,
    );
  }
  final thing = substances[stand.substanceId]?.name ?? Strings.unknown;
  final lockout = stand.lockout;
  return (
    digits: Fmt.clock(since),
    line: lockout == null
        ? TracksStrings.padSinceThing(thing)
        : TracksStrings.padLockoutOf(
            thing,
            formatRemaining(lockout.remainingMs),
          ),
    warn: lockout != null,
    any: true,
  );
}

/// The most recent entry of [personId] among [facts], or `null`.
LastEntryFact? padLatestFact(String personId, Iterable<LastEntryFact> facts) {
  LastEntryFact? latest;
  for (final f in facts) {
    if (f.personId != personId || f.substanceId == null) continue;
    if (latest == null || f.at > latest.at) latest = f;
  }
  return latest;
}

/// A lockout the user set that is still running.
@immutable
final class PadLockout {
  const PadLockout({required this.remainingMs, required this.passed});

  final int remainingMs;

  /// 0 ... 1: how much of the lockout has passed.
  final double passed;
}

/// The running lockout of a thing button, or `null`. Shown, never
/// enforced; a thing without a lockout of the user's own never has one.
PadLockout? padLockout(
  PadButton button, {
  required Iterable<LastEntryFact> facts,
  required Map<String, int> lockouts,
  required int nowMs,
}) {
  final substanceId = button.substanceId;
  if (button.kind != PadButtonKind.substance || substanceId == null) {
    return null;
  }
  final total = lockouts[substanceId];
  if (total == null || total <= 0) return null;
  final remaining = lockoutRemainingFor(
    facts,
    personId: button.personId,
    substanceId: substanceId,
    nowMs: nowMs,
    lockouts: lockouts,
  );
  if (remaining == null || remaining <= 0) return null;
  return PadLockout(
    remainingMs: remaining,
    passed: (1 - remaining / total).clamp(0, 1).toDouble(),
  );
}
