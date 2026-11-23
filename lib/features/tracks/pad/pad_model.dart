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

  /// A person of a protocol track: opens that person's substance buttons.
  person,

  /// A substance for a person: tap = entry.
  substance,

  /// "+": the full entry sheet of a protocol track.
  more,

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
    required this.track,
    this.label,
    this.personId,
    this.substanceId,
  });

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

  factory PadButton.person(Track track, String personId) => PadButton._(
    id: 'p:${track.id}:$personId',
    kind: PadButtonKind.person,
    track: track,
    personId: personId,
  );

  factory PadButton.substance(
    Track track, {
    required String? personId,
    required String substanceId,
  }) => PadButton._(
    id: 'x:${track.id}:${personId ?? '-'}:$substanceId',
    kind: PadButtonKind.substance,
    track: track,
    personId: personId,
    substanceId: substanceId,
  );

  factory PadButton.more(Track track, {String? personId}) => PadButton._(
    id: 'm:${track.id}:${personId ?? '-'}',
    kind: PadButtonKind.more,
    track: track,
    personId: personId,
  );

  factory PadButton.other(Track track, {String? personId}) => PadButton._(
    id: 'o:${track.id}:${personId ?? '-'}',
    kind: PadButtonKind.other,
    track: track,
    personId: personId,
  );

  final String id;
  final PadButtonKind kind;
  final Track track;

  /// Quick label of a counter button; `null` for a counter without labels.
  final String? label;

  /// Person of a person / substance / "+" button.
  final String? personId;
  final String? substanceId;

  /// Substance buttons of one person on one track form a group that is
  /// limited to [captureSubstanceLimit] buttons.
  String get substanceGroup => '${track.id}:${personId ?? '-'}';

  @override
  bool operator ==(Object other) =>
      other is PadButton &&
      other.id == id &&
      other.kind == kind &&
      other.track == track &&
      other.label == label &&
      other.personId == personId &&
      other.substanceId == substanceId;

  @override
  int get hashCode =>
      Object.hash(id, kind, track, label, personId, substanceId);

  @override
  String toString() => 'PadButton($id)';
}

/// The substance buttons of [personId] on [track] (the same top-5 logic
/// as the protocol lane, see [topSubstanceIds]) followed by "Anderes".
List<PadButton> buildSubstancePad({
  required Track track,
  required String? personId,
  required List<String> sceneSubstanceIds,
  required List<Substance> substances,
  required Iterable<SubstanceUse> use,
  int limit = captureSubstanceLimit,
}) {
  final ids = topSubstanceIds(
    sceneSubstanceIds: sceneSubstanceIds,
    use: use,
    personId: personId,
    available: {for (final s in substances) s.id},
    limit: limit,
  );
  return [
    for (final id in ids)
      PadButton.substance(track, personId: personId, substanceId: id),
    PadButton.other(track, personId: personId),
  ];
}

/// The substances of the page "Anderes": every substance of [substances]
/// that is not already a button on the page "Was?" ([shownIds]), in the
/// order of the user's list.
List<PadButton> buildOtherPad({
  required Track track,
  required String? personId,
  required List<Substance> substances,
  required Set<String> shownIds,
}) => [
  for (final s in substances)
    if (!shownIds.contains(s.id))
      PadButton.substance(track, personId: personId, substanceId: s.id),
];

/// The buttons of the main pad, in track order:
///
/// * counter with quick labels: one button per label, without: one button;
/// * stopwatch, countdown, interval, reminder: one button;
/// * protocol: one button per person of the scene (per person of the list
///   without a scene) and "+". A scene with exactly ONE person shows that
///   person's substance buttons right here instead.
///
/// [persons] and [substances] are the user's current lists (not archived),
/// [useByTrack] the substance use per protocol track id. With [limit]
/// `null` every available substance is offered - that is the set of
/// buttons that MAY be on the pad (see [mergePadButtons]).
List<PadButton> buildMainPad({
  required List<Track> tracks,
  required List<Person> persons,
  required List<String> scenePersonIds,
  required List<String> sceneSubstanceIds,
  required List<Substance> substances,
  Map<String, List<SubstanceUse>> useByTrack = const {},
  int? limit = captureSubstanceLimit,
}) {
  final known = {for (final p in persons) p.id};
  final scene = [
    for (final id in scenePersonIds)
      if (known.contains(id)) id,
  ];
  final result = <PadButton>[];
  for (final track in tracks) {
    switch (track.config) {
      case CounterConfig(:final labels):
        if (labels.isEmpty) {
          result.add(PadButton.counter(track));
        } else {
          final seen = <String>{};
          for (final label in labels) {
            if (seen.add(label)) {
              result.add(PadButton.counter(track, label: label));
            }
          }
        }
      case StopwatchConfig():
        result.add(PadButton.stopwatch(track));
      case CountdownConfig() || IntervalConfig() || ReminderConfig():
        result.add(PadButton.timer(track));
      case ProtocolConfig():
        if (scene.length == 1) {
          result.addAll(
            buildSubstancePad(
              track: track,
              personId: scene.single,
              sceneSubstanceIds: sceneSubstanceIds,
              substances: substances,
              use: useByTrack[track.id] ?? const [],
              limit: limit ?? substances.length,
            ),
          );
        } else {
          for (final id in scene.isEmpty ? known : scene) {
            result.add(PadButton.person(track, id));
          }
          result.add(PadButton.more(track));
        }
    }
  }
  return result;
}

/// Keeps the buttons of an open pad where they are.
///
/// * A button of [shownIds] stays at its place for as long as it is still
///   among [candidates] (everything that may be on the pad); it is never
///   dropped just because another substance became more used.
/// * Buttons of [fresh] (what a newly opened pad would show) that are not
///   on the pad yet are appended at the END - nothing that is already
///   there moves. A substance group never grows beyond [substanceLimit].
/// * With empty [shownIds] the result is [fresh].
List<PadButton> mergePadButtons({
  required List<String> shownIds,
  required List<PadButton> fresh,
  required List<PadButton> candidates,
  int substanceLimit = captureSubstanceLimit,
}) {
  final byId = {
    for (final b in candidates) b.id: b,
    for (final b in fresh) b.id: b,
  };
  final result = <PadButton>[];
  final taken = <String>{};
  final perGroup = <String, int>{};
  void add(PadButton button) {
    result.add(button);
    taken.add(button.id);
    if (button.kind == PadButtonKind.substance) {
      perGroup[button.substanceGroup] =
          (perGroup[button.substanceGroup] ?? 0) + 1;
    }
  }

  for (final id in shownIds) {
    final button = byId[id];
    if (button != null && !taken.contains(id)) add(button);
  }
  for (final button in fresh) {
    if (taken.contains(button.id)) continue;
    if (button.kind == PadButtonKind.substance &&
        (perGroup[button.substanceGroup] ?? 0) >= substanceLimit) {
      continue;
    }
    add(button);
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

  /// Protocol: open the full entry sheet.
  openSheet,

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
    case PadButtonKind.more:
      return PadTapAction.openSheet;
    case PadButtonKind.other:
      return PadTapAction.openOther;
  }
}

// ------------------------------------------------------------------- faces

Iterable<TrackEvent> _events(PadButton button, OpenSession? open) =>
    laneSession(button.track, open)?.events ?? const <TrackEvent>[];

bool _counts(PadButton button, TrackEvent e) => switch (button.kind) {
  PadButtonKind.counter =>
    e.type == EventType.tick &&
        (button.label == null || e.label == button.label),
  PadButtonKind.person =>
    e.type == EventType.entry && e.personId == button.personId,
  PadButtonKind.substance =>
    e.type == EventType.entry &&
        e.personId == button.personId &&
        e.substanceId == button.substanceId,
  PadButtonKind.stopwatch ||
  PadButtonKind.timer ||
  PadButtonKind.more ||
  PadButtonKind.other => false,
};

/// The count on a counter / person / substance button: its ticks or
/// entries in the open session.
int padCount(PadButton button, OpenSession? open) {
  var n = 0;
  for (final e in _events(button, open)) {
    if (_counts(button, e)) n++;
  }
  return n;
}

/// When the button was last tapped (the event it last wrote), or `null`:
/// the last tick of the label, the last entry of the person / substance,
/// the last event of a stopwatch or timer.
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

/// The large figure of a button at [nowMs]: the count, or the time of a
/// stopwatch / timer (the same digits as on its lane).
String padValue(
  PadButton button,
  OpenSession? open,
  int nowMs, {
  UiPrefs prefs = UiPrefs.defaults,
}) {
  switch (button.kind) {
    case PadButtonKind.counter ||
        PadButtonKind.person ||
        PadButtonKind.substance:
      return Strings.countValue(padCount(button, open));
    case PadButtonKind.stopwatch || PadButtonKind.timer:
      return buildLaneView(
        track: button.track,
        open: open,
        nowMs: nowMs,
        prefs: prefs,
      ).time.digits;
    case PadButtonKind.more:
      return TracksStrings.padMoreSymbol;
    case PadButtonKind.other:
      return '';
  }
}

/// "vor 12 s" - the time since [lastAt], rounded down to what a glance
/// can read (seconds below ten minutes, minutes above).
String padSince(int? lastAt, int nowMs) {
  if (lastAt == null) return '';
  final ms = nowMs > lastAt ? nowMs - lastAt : 0;
  return Strings.ago(Fmt.compact(ms));
}

/// The small line of a button at [nowMs]: the time since its last tap,
/// or what a tap on a stopwatch / timer would do.
String padSubText(PadButton button, OpenSession? open, int nowMs) {
  switch (button.kind) {
    case PadButtonKind.counter ||
        PadButtonKind.person ||
        PadButtonKind.substance:
      return padSince(padLastTapAt(button, open), nowMs);
    case PadButtonKind.more || PadButtonKind.other:
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

/// Whether the texts of [button] change with time right now (so only then
/// the button follows the shared ticker).
bool padIsLive(PadButton button, OpenSession? open, int nowMs) {
  switch (button.kind) {
    case PadButtonKind.more || PadButtonKind.other:
      return false;
    case PadButtonKind.counter ||
        PadButtonKind.person ||
        PadButtonKind.substance:
      return padLastTapAt(button, open) != null;
    case PadButtonKind.stopwatch || PadButtonKind.timer:
      return laneSnapshot(button.track, open, nowMs).isTicking;
  }
}

/// The last entry of the person of a person button in the open session,
/// for "Kippe · vor 8 min"; `null` for other buttons or without entry.
TrackEvent? padLastEntry(PadButton button, OpenSession? open) =>
    button.kind == PadButtonKind.person
    ? lastEntryOfPerson(_events(button, open), button.personId)
    : null;

/// The user's own lockout of a substance button at [nowMs]: what is left
/// and how much of it has passed (0..1, for the bar). `null` while none
/// runs. Shown, never enforced.
@immutable
final class PadLockout {
  const PadLockout({required this.remainingMs, required this.passed});

  final int remainingMs;
  final double passed;
}

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
