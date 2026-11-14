import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../core/domain/domain.dart';
import '../../core/engine/engine.dart';
import '../../core/now_ticker.dart';
import '../../core/repo/repo.dart';
import '../../core/services/haptics.dart';
import '../../l10n/formatters.dart';
import 'lane_undo.dart';
import 'lane_view.dart';
import 'tracks_strings.dart';

/// Everything the lane buttons, the app bar and the keyboard shortcuts do:
/// run the command, give haptic feedback, refresh the shared ticker and
/// offer "Rückgängig" where something ended.
///
/// No confirmation dialogs anywhere - destructive actions are undoable.
class LaneActions {
  LaneActions(this._ref);

  final Ref _ref;

  TrackCommands get _commands => _ref.read(trackCommandsProvider);
  Haptics get _haptics => _ref.read(hapticsProvider);

  void _refresh() => _ref.read(nowTickerProvider).tickNow();

  /// The round primary button (and the 1-9 shortcuts): start / pause /
  /// resume / dismiss / ack / count, depending on mode and state.
  Future<TrackAction> toggle(Track track) async {
    final action = await _commands.toggleTrack(track.id);
    switch (action) {
      case TrackAction.none:
        break;
      case TrackAction.started || TrackAction.paused || TrackAction.resumed:
        _haptics.primary();
      case TrackAction.ticked || TrackAction.lapped:
        _haptics.tick();
      case TrackAction.stopped || TrackAction.acknowledged:
        _haptics.heavy();
    }
    _refresh();
    return action;
  }

  Future<void> lap(Track track) async {
    final event = await _commands.lap(track.id);
    if (event != null) _haptics.tick();
    _refresh();
  }

  /// Counts one, optionally with a quick label.
  Future<void> tick(Track track, {String? label}) async {
    final event = await _commands.tick(track.id, label: label);
    if (event != null) _haptics.tick();
    _refresh();
  }

  Future<void> undoTick(Track track) async {
    final removed = await _commands.undoTick(track.id);
    if (removed != null) _haptics.selection();
    _refresh();
  }

  /// Acknowledges a reminder (also before it is due).
  Future<void> ack(Track track) async {
    final event = await _commands.ack(track.id);
    if (event != null) _haptics.heavy();
    _refresh();
  }

  /// Dismisses a ringing countdown / interval.
  Future<void> dismiss(Track track) async {
    final sessionId = await _commands.stopTrack(track.id);
    if (sessionId != null) _haptics.heavy();
    _refresh();
  }

  Future<void> restart(Track track) async {
    final action = await _commands.restartTrack(track.id);
    if (action != TrackAction.none) _haptics.primary();
    _refresh();
  }

  /// Ends the run and puts the lane back to idle. The run stays in the
  /// history; "Rückgängig" in the bar above the lanes lets it continue as
  /// if nothing had happened.
  Future<void> stop(Track track) async {
    final before = await _commands.resetTrack(track.id);
    _refresh();
    if (before == null) return;
    _haptics.heavy();
    final now = _ref.read(nowTickerProvider).value;
    final snapshot = deriveSnapshot(
      config: before.session.config,
      events: before.events,
      nowMs: now,
    );
    _ref
        .read(laneUndoProvider.notifier)
        .offer(
          message: TracksStrings.trackStopped(track.name),
          detail: switch (snapshot) {
            CounterSnapshot(:final count) => TracksStrings.ticksKept(count),
            StopwatchSnapshot(:final elapsedMs) => TracksStrings.timeKept(
              Fmt.clock(elapsedMs),
            ),
            _ => null,
          },
          onUndo: () async {
            await _commands.reopenSession(before.session.id);
            _refresh();
          },
        );
  }

  /// The secondary button of a lane.
  Future<void> secondary(Track track, LaneSecondaryKind kind) => switch (kind) {
    LaneSecondaryKind.lap => lap(track),
    LaneSecondaryKind.restart => restart(track),
    LaneSecondaryKind.reset || LaneSecondaryKind.stop => stop(track),
    LaneSecondaryKind.undo => undoTick(track),
    LaneSecondaryKind.ackEarly => ack(track),
  };

  /// Whether a start / pause capable track of [tracks] is running at
  /// [nowMs] ("Alle pausieren" would do something).
  static bool anyRunning(
    List<Track> tracks,
    Map<String, OpenSession> sessions,
    int nowMs,
  ) {
    for (final track in tracks) {
      if (!track.mode.supportsStartPause) continue;
      final open = laneSession(track, sessions[track.id]);
      if (open == null) continue;
      if (laneSnapshot(track, open, nowMs).isRunning) return true;
    }
    return false;
  }

  /// "Alle pausieren" when something runs in the set, otherwise "Alle
  /// starten". Returns the number of tracks that changed.
  Future<int> toggleAll(BuildContext context, String setId) async {
    final tracks =
        _ref.read(tracksInSetProvider(setId)).value ?? const <Track>[];
    final sessions =
        _ref.read(openSessionsProvider).value ?? const <String, OpenSession>{};
    final now = _ref.read(nowTickerProvider).value;
    final pause = anyRunning(tracks, sessions, now);
    final changed = pause
        ? await _commands.pauseAll(setId)
        : await _commands.startAll(setId);
    _refresh();
    if (changed > 0) {
      _haptics.primary();
    } else if (!pause && context.mounted) {
      showInfoSnackBar(context, TracksStrings.nothingToStart);
    }
    return changed;
  }
}

final laneActionsProvider = Provider<LaneActions>(LaneActions.new);
