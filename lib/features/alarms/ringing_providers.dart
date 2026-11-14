import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/track.dart';
import '../../core/engine/derive.dart';
import '../../core/now_ticker.dart';
import '../../core/repo/models.dart';
import '../../core/repo/providers.dart';
import 'alert_cue.dart';

/// The alert cues of all tracks whose open session can ring, keyed by track
/// id. Derived from the event log and the shared "now" ticker:
///
/// * recomputed whenever a session changes (start, pause, ack, stop ...);
/// * while at least one such session is running or ringing it follows the
///   shared ticker, but only publishes a new map when a cue actually
///   changed (a countdown crossed zero, the next interval phase began, a
///   reminder nags again), so listeners are not woken on every tick;
/// * costs nothing when no countdown, interval or reminder is active.
///
/// Lanes should not watch this whole map; use [trackRingingProvider].
final alertCuesProvider =
    NotifierProvider<AlertCuesNotifier, Map<String, AlertCue>>(
      AlertCuesNotifier.new,
    );

class AlertCuesNotifier extends Notifier<Map<String, AlertCue>> {
  @override
  Map<String, AlertCue> build() {
    final sessions = ref.watch(openSessionsProvider).value ?? const {};
    final ticker = ref.watch(nowTickerProvider);

    final candidates = [
      for (final open in sessions.values)
        if (open.session.mode.hasAlarms) open,
    ];
    if (candidates.isEmpty) return const {};

    final nowMs = ticker.value;
    final advancing = candidates.any(
      (open) => deriveSnapshot(
        config: open.session.config,
        events: open.events,
        nowMs: nowMs,
      ).isTicking,
    );
    if (advancing) {
      void onTick() {
        final next = _evaluate(candidates, ticker.value);
        if (!mapEquals(next, state)) state = next;
      }

      ticker.addListener(onTick);
      ref.onDispose(() => ticker.removeListener(onTick));
    }
    return _evaluate(candidates, nowMs);
  }

  /// Re-reads the clock right now (e.g. after the app came back to the
  /// foreground) instead of waiting for the next tick.
  void refresh() => ref.invalidateSelf();

  static Map<String, AlertCue> _evaluate(
    List<OpenSession> sessions,
    int nowMs,
  ) {
    final cues = <String, AlertCue>{};
    for (final open in sessions) {
      final cue = alertCueFor(
        deriveSnapshot(
          config: open.session.config,
          events: open.events,
          nowMs: nowMs,
        ),
      );
      if (cue != null) cues[open.trackId] = cue;
    }
    return cues;
  }
}

/// A track that is ringing right now.
final class RingingTrack {
  const RingingTrack({required this.track, required this.cue});

  final Track track;
  final AlertCue cue;

  String get trackId => track.id;
  AlertCueKind get kind => cue.kind;

  /// Wall time (UTC ms) since which it rings.
  int get sinceMs => cue.sinceMs;

  /// Reminders are acknowledged ("Erledigt"), everything else is stopped
  /// ("Stopp"). Either way `TrackCommands.toggleTrack` does the right
  /// thing for a ringing track.
  bool get isReminder => cue.kind == AlertCueKind.reminderDue;

  @override
  bool operator ==(Object other) =>
      other is RingingTrack && other.track == track && other.cue == cue;

  @override
  int get hashCode => Object.hash(track, cue);
}

/// Every track that is ringing or due right now (finished countdown,
/// finished interval, due reminder), longest-ringing first. Archived
/// tracks are left out.
final ringingTracksProvider = Provider<List<RingingTrack>>((ref) {
  final cues = ref.watch(alertCuesProvider);
  if (cues.isEmpty) return const [];
  final tracks = ref.watch(allTracksProvider).value ?? const <Track>[];
  final ringing = [
    for (final track in tracks)
      if (!track.archived && (cues[track.id]?.ringing ?? false))
        RingingTrack(track: track, cue: cues[track.id]!),
  ]..sort((a, b) => a.sinceMs.compareTo(b.sinceMs));
  return List.unmodifiable(ringing);
});

/// The ids of the ringing tracks.
final ringingTrackIdsProvider = Provider<Set<String>>((ref) {
  final cues = ref.watch(alertCuesProvider);
  return {
    for (final entry in cues.entries)
      if (entry.value.ringing) entry.key,
  };
});

/// Whether one track is ringing. Cheap for lanes: rebuilds only when this
/// track starts or stops ringing.
final trackRingingProvider = Provider.family<bool, String>(
  (ref, trackId) => ref.watch(
    alertCuesProvider.select((cues) => cues[trackId]?.ringing ?? false),
  ),
);

/// The alert cue of one track (`null` when there is none); changes with
/// every phase, cycle and nag.
final trackAlertCueProvider = Provider.family<AlertCue?, String>(
  (ref, trackId) =>
      ref.watch(alertCuesProvider.select((cues) => cues[trackId])),
);

/// Number of ringing tracks, e.g. for a badge on the "Spuren" destination.
final ringingCountProvider = Provider<int>(
  (ref) => ref.watch(ringingTrackIdsProvider).length,
);
