import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/domain/domain.dart';
import '../../../core/now_ticker.dart';
import '../../../core/repo/repo.dart';
import '../../../core/repo/session_store.dart';
import '../../../core/services/haptics.dart';
import '../../protocol/protocol_logic.dart';
import '../lane_view.dart';
import '../tracks_strings.dart';
import 'pad_model.dart';

/// What a tap on the pad wrote, for the undo bar.
final class PadResult {
  const PadResult({
    required this.what,
    required this.at,
    this.undo,
    this.entry,
  });

  /// "Reiher", "Stoppuhr · Runde 3", "Jacke · GBL".
  final String what;

  /// When it happened (UTC ms).
  final int at;

  /// Takes exactly this action back; `null` when that is not cleanly
  /// possible (starting or resuming an exclusive stopwatch also pauses
  /// the others).
  final Future<void> Function()? undo;

  /// The protocol entry that was written, for "Ändern".
  final AddedEntry? entry;
}

/// The write side of the tap pad. Every tap is ONE command (one database
/// transaction); nothing asks, nothing confirms.
///
/// What a tap does is decided here from the state in the database at the
/// moment the command runs, not from what the button showed a moment ago.
class PadActions {
  PadActions(this._ref);

  final Ref _ref;

  TrackCommands get _commands => _ref.read(trackCommandsProvider);
  HistoryRepository get _history => _ref.read(historyRepositoryProvider);
  Haptics get _haptics => _ref.read(hapticsProvider);
  Clock get _clock => _ref.read(clockProvider);

  void _refresh() => _ref.read(nowTickerProvider).tickNow();

  /// Runs the tap on [button]. Returns `null` when nothing was written
  /// (wrong state, the track is gone, a running timer).
  ///
  /// Only for buttons that write: counter, stopwatch, timer, substance.
  Future<PadResult?> tap(
    PadButton button, {
    String personName = '',
    String substanceName = '',
  }) async {
    final track = button.track;
    final open = await _commands.getOpenSession(track.id);
    final now = _clock.nowMs();
    final state = laneSnapshot(track, open, now).state;
    final PadResult? result;
    switch (padTapAction(button, state)) {
      case PadTapAction.tick:
        result = await _tick(button, hadSession: open != null);
      case PadTapAction.start:
        result = await _start(track);
      case PadTapAction.lap:
        result = await _lap(track);
      case PadTapAction.resume:
        result = await _resume(track);
      case PadTapAction.dismiss:
        result = await _dismiss(track);
      case PadTapAction.ack:
        result = await _ack(track);
      case PadTapAction.entry:
        result = await _entry(button, personName, substanceName);
      case PadTapAction.openPerson ||
          PadTapAction.openSheet ||
          PadTapAction.openOther ||
          PadTapAction.none:
        result = null;
    }
    _refresh();
    return result;
  }

  /// Runs [result]'s undo, with feedback.
  Future<void> undo(PadResult result) async {
    final undo = result.undo;
    if (undo == null) return;
    await undo();
    await _haptics.selection();
    _refresh();
  }

  Future<PadResult?> _tick(PadButton button, {required bool hadSession}) async {
    final track = button.track;
    final event = await _commands.tick(track.id, label: button.label);
    if (event == null) return null;
    await _haptics.tick();
    return PadResult(
      what: button.label ?? track.name,
      at: event.at,
      undo: () async {
        await _history.deleteEvent(event.id);
        // The tick had started the session: without it there is none.
        if (!hadSession) await _discardIfOnlyStarted(track.id, event.sessionId);
      },
    );
  }

  Future<PadResult?> _start(Track track) async {
    final action = await _commands.startTrack(track.id);
    if (action == TrackAction.none) return null;
    final open = await _commands.getOpenSession(track.id);
    await _haptics.primary();
    final sessionId = open?.session.id;
    final clean =
        action == TrackAction.started &&
        sessionId != null &&
        !SessionWriter.isExclusive(track);
    return PadResult(
      what: TracksStrings.padStarted(track.name),
      at: open?.session.startedAt ?? _clock.nowMs(),
      undo: clean ? () => _discardIfOnlyStarted(track.id, sessionId) : null,
    );
  }

  Future<PadResult?> _lap(Track track) async {
    final event = await _commands.lap(track.id);
    if (event == null) return null;
    final open = await _commands.getOpenSession(track.id);
    final laps = open?.events.where((e) => e.type == EventType.lap).length ?? 1;
    await _haptics.tick();
    return PadResult(
      what: TracksStrings.padLap(track.name, laps),
      at: event.at,
      undo: () async {
        await _history.deleteEvent(event.id);
      },
    );
  }

  Future<PadResult?> _resume(Track track) async {
    final action = await _commands.resumeTrack(track.id);
    if (action != TrackAction.resumed) return null;
    final open = await _commands.getOpenSession(track.id);
    TrackEvent? resume;
    for (final e in open?.events ?? const <TrackEvent>[]) {
      if (e.type == EventType.resume) resume = e;
    }
    await _haptics.primary();
    final event = resume;
    return PadResult(
      what: TracksStrings.padResumed(track.name),
      at: event?.at ?? _clock.nowMs(),
      undo: event == null || SessionWriter.isExclusive(track)
          ? null
          : () async {
              await _history.deleteEvent(event.id);
            },
    );
  }

  Future<PadResult?> _dismiss(Track track) async {
    final sessionId = await _commands.stopTrack(track.id);
    if (sessionId == null) return null;
    await _haptics.heavy();
    return PadResult(
      what: TracksStrings.padDismissed(track.name),
      at: _clock.nowMs(),
      undo: () async {
        await _commands.reopenSession(sessionId);
      },
    );
  }

  Future<PadResult?> _ack(Track track) async {
    final event = await _commands.ack(track.id);
    if (event == null) return null;
    await _haptics.heavy();
    return PadResult(
      what: TracksStrings.padAcked(track.name),
      at: event.at,
      undo: () async {
        await _history.deleteEvent(event.id);
      },
    );
  }

  /// A protocol entry: person, substance, now. Never an amount.
  Future<PadResult?> _entry(
    PadButton button,
    String personName,
    String substanceName,
  ) async {
    final protocol = _ref.read(protocolActionsProvider);
    final added = await protocol.addEntry(
      button.track.id,
      personId: button.personId,
      substanceId: button.substanceId,
    );
    if (added == null) return null;
    await _haptics.tick();
    return PadResult(
      what: TracksStrings.padEntry(personName, substanceName),
      at: added.event.at,
      undo: () => protocol.undoAdd(added),
      entry: added,
    );
  }

  /// Undo of a tap that had opened the session: removes the session again
  /// - but only when it is still the same one and nothing but its start
  /// (and pauses) is left in it.
  Future<void> _discardIfOnlyStarted(String trackId, String sessionId) async {
    final open = await _commands.getOpenSession(trackId);
    if (open == null || open.session.id != sessionId) return;
    const lifecycle = {EventType.start, EventType.pause, EventType.resume};
    if (open.events.any((e) => !lifecycle.contains(e.type))) return;
    await _commands.resetTrack(trackId, discard: true);
  }
}

final padActionsProvider = Provider<PadActions>(PadActions.new);

/// Lets the keyboard shortcuts of the tracks screen reach the pad that is
/// on screen: the pad registers its handler here while it is mounted.
class PadKeyBridge {
  /// Handles a digit (`1`-`9`, `0` = tenth button), Backspace or Escape;
  /// returns whether the key was used.
  bool Function(PadKey key)? handler;
}

/// A key the pad reacts to.
sealed class PadKey {
  const PadKey();
}

/// The n-th button (0-based).
final class PadKeyButton extends PadKey {
  const PadKeyButton(this.index);

  final int index;
}

final class PadKeyUndo extends PadKey {
  const PadKeyUndo();
}

final class PadKeyBack extends PadKey {
  const PadKeyBack();
}

final padKeyBridgeProvider = Provider<PadKeyBridge>((ref) => PadKeyBridge());
