import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/domain.dart';
import '../../core/engine/engine.dart';
import '../../core/now_ticker.dart';
import '../../core/repo/models.dart';
import '../../core/repo/providers.dart';
import '../../core/services/haptics.dart';

/// How often the in-app cue (haptics + system sound) repeats while a
/// finished countdown / interval or a due reminder waits for the user.
/// The one place that defines the cadence.
const int ringRepeatEveryMs = 5000;

/// Decides when a track makes itself heard while the app is open.
///
/// Pure bookkeeping: feed it the open sessions and "now" and it reports the
/// tracks that should ring at this instant:
///
/// * the moment something becomes due - a countdown reaching zero (or
///   completing a cycle), an interval changing phase or finishing, a
///   reminder becoming due or nagging again;
/// * and then again every [repeatEveryMs] for as long as the track WAITS
///   for the user (finished countdown / interval not dismissed, due
///   reminder not acknowledged) - until it is stopped or acknowledged.
///
/// What is already ringing when a session is first seen (app start, return
/// from the background after [clear]) is not reported as a fresh ring: the
/// OS notification has done that. It simply joins the repeating cadence,
/// i.e. it is reported [repeatEveryMs] later.
final class RingTracker {
  RingTracker({this.repeatEveryMs = ringRepeatEveryMs});

  /// Cadence of the repeated cue; `<= 0` switches the repetition off.
  final int repeatEveryMs;

  final Map<String, _Seen> _seen = {};

  /// Returns the ids of the tracks that ring at [nowMs].
  List<String> update(Map<String, OpenSession> sessions, int nowMs) {
    final rang = <String>[];
    _seen.removeWhere((trackId, _) => !sessions.containsKey(trackId));
    for (final entry in sessions.entries) {
      final open = entry.value;
      if (!open.session.mode.hasAlarms) continue;
      final snapshot = deriveSnapshot(
        config: open.session.config,
        events: open.events,
        nowMs: nowMs,
      );
      final key = '${open.session.id}|${_generation(snapshot)}';
      final level = ringLevel(snapshot);
      final waiting = snapshot.isRinging;
      final before = _seen[entry.key];
      final sameRun = before != null && before.key == key;

      var ring = sameRun && level > before.level && snapshot.isTicking;
      var lastRingAt = sameRun ? before.lastRingAt : null;
      if (!ring && waiting && repeatEveryMs > 0) {
        if (lastRingAt == null) {
          // First seen while already waiting: the cadence starts now.
          lastRingAt = nowMs;
        } else if (nowMs - lastRingAt >= repeatEveryMs || nowMs < lastRingAt) {
          ring = true;
        }
      }
      if (ring) {
        rang.add(entry.key);
        lastRingAt = nowMs;
      }
      _seen[entry.key] = _Seen(key, level, waiting ? lastRingAt : null);
    }
    return rang;
  }

  /// An acknowledged reminder starts counting from zero again.
  static int _generation(TrackSnapshot snapshot) =>
      snapshot is ReminderSnapshot ? snapshot.ackCount : 0;

  /// A number that grows every time the track should make itself heard.
  static int ringLevel(TrackSnapshot snapshot) => switch (snapshot) {
    CountdownSnapshot() => snapshot.completedCycles,
    IntervalSnapshot() =>
      snapshot.finished
          ? snapshot.rounds * 2
          : (snapshot.round - 1) * 2 +
                (snapshot.phase == IntervalPhase.rest ? 1 : 0),
    ReminderSnapshot() => snapshot.due ? 1 + snapshot.nagCount : 0,
    _ => 0,
  };

  /// Forgets everything: the next [update] is a new baseline. Used when the
  /// app returns from the background, where the OS notifications did the
  /// ringing - nothing that became due meanwhile is a "just finished".
  void clear() => _seen.clear();
}

final class _Seen {
  const _Seen(this.key, this.level, this.lastRingAt);

  /// Session id + generation.
  final String key;
  final int level;

  /// When the track last rang while waiting for the user; `null` when it
  /// is not waiting.
  final int? lastRingAt;
}

/// What happens in the app when a track rings while it is open.
abstract class RingFeedback {
  Future<void> ring(Track track);
}

/// System haptics plus the system alert sound. The alert sound only exists
/// on desktop platforms; on phones the OS notification carries the sound.
class SystemRingFeedback implements RingFeedback {
  const SystemRingFeedback(this._haptics);

  final Haptics _haptics;

  @override
  Future<void> ring(Track track) async {
    unawaited(_haptics.alarm(track));
    if (!track.alarmSound) return;
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {
      // No system sound on this platform.
    }
  }
}

final ringFeedbackProvider = Provider<RingFeedback>(
  (ref) => SystemRingFeedback(ref.watch(hapticsProvider)),
);

/// Watches the open sessions through the shared ticker and gives sound /
/// haptic feedback the moment a track rings, and again every
/// [ringRepeatEveryMs] while it waits to be dismissed / acknowledged
/// (see [RingTracker]). The per-track sound and vibration switches and the
/// haptics preference are honoured by [RingFeedback].
///
/// Only while the app is in the foreground: in the background the OS
/// notifications ring. On return the tracker starts from a new baseline,
/// so what finished meanwhile does not ring as "just finished" - it simply
/// continues with the repeating cue.
///
/// Follows the ticker only while a countdown, interval or reminder is open.
///
/// The open sessions are listened to on the provider container, not
/// through the widget: widget subscriptions are paused while the subtree
/// is not shown (`TickerMode` off, e.g. behind the lock screen), and a
/// track that was dismissed from its notification meanwhile must stop
/// ringing at once.
class RingMonitor extends ConsumerStatefulWidget {
  const RingMonitor({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<RingMonitor> createState() => _RingMonitorState();
}

class _RingMonitorState extends ConsumerState<RingMonitor>
    with WidgetsBindingObserver {
  final RingTracker _tracker = RingTracker();
  NowTicker? _subscribedTo;
  Map<String, OpenSession> _sessions = const {};

  /// The app is not in the foreground: nothing rings in-app.
  bool _background = false;

  ProviderSubscription<AsyncValue<Map<String, OpenSession>>>? _sessionsSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _background =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    _sessionsSub = ProviderScope.containerOf(context, listen: false)
        .listen<AsyncValue<Map<String, OpenSession>>>(
          openSessionsProvider,
          (previous, next) => _onSessions(next.value),
          fireImmediately: true,
        );
  }

  void _onSessions(Map<String, OpenSession>? value) {
    if (!mounted) return;
    final sessions = value ?? const <String, OpenSession>{};
    if (identical(sessions, _sessions)) return;
    _sessions = sessions;
    final ticker = ref.read(nowTickerProvider);
    // Take note of the new log right away, so that e.g. an acknowledged
    // reminder is not mistaken for a new ring.
    if (!_background) {
      final rang = _tracker.update(sessions, ticker.value);
      if (rang.isNotEmpty) scheduleMicrotask(() => _fire(rang));
    }
    _followTicker(ticker);
  }

  void _followTicker(NowTicker ticker) {
    final needsTicker = _sessions.values.any((s) => s.session.mode.hasAlarms);
    _subscribe(needsTicker ? ticker : null);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused ||
          AppLifecycleState.hidden ||
          AppLifecycleState.detached:
        _background = true;
        _tracker.clear();
      case AppLifecycleState.resumed:
        if (!_background) return;
        _background = false;
        // New baseline: whatever became due in the background has been
        // announced by its notification.
        _tracker
          ..clear()
          ..update(_sessions, ref.read(nowTickerProvider).value);
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _subscribe(NowTicker? ticker) {
    if (identical(ticker, _subscribedTo)) return;
    _subscribedTo?.removeListener(_check);
    _subscribedTo = ticker;
    ticker?.addListener(_check);
  }

  void _check() {
    if (!mounted || _background) return;
    final now = ref.read(nowTickerProvider).value;
    _fire(_tracker.update(_sessions, now));
  }

  void _fire(List<String> rang) {
    if (rang.isEmpty || !mounted || _background) return;
    final feedback = ref.read(ringFeedbackProvider);
    for (final trackId in rang) {
      final track = ref.read(trackProvider(trackId));
      if (track == null || track.archived) continue;
      unawaited(feedback.ring(track));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionsSub?.close();
    _sessionsSub = null;
    _subscribedTo?.removeListener(_check);
    _subscribedTo = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the track lookup warm for [_fire].
    ref.watch(allTracksProvider);
    _followTicker(ref.watch(nowTickerProvider));
    return widget.child;
  }
}
