import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/track.dart';
import '../../engine/alarm_plan.dart';

export '../../engine/alarm_plan.dart' show AlarmKind, PlannedAlarm;

/// What the OS currently allows.
final class AlarmPermissionStatus {
  const AlarmPermissionStatus({
    required this.supported,
    required this.notificationsGranted,
    required this.exactAlarmsGranted,
  });

  /// Nothing can be scheduled on this platform.
  static const unsupported = AlarmPermissionStatus(
    supported: false,
    notificationsGranted: false,
    exactAlarmsGranted: false,
  );

  /// The platform can schedule local notifications at all.
  final bool supported;

  /// Notification permission (Android 13+, iOS, macOS). `true` where no
  /// permission is needed.
  final bool notificationsGranted;

  /// Exact alarm permission (Android 12+). `true` where not applicable.
  final bool exactAlarmsGranted;

  bool get allGranted =>
      supported && notificationsGranted && exactAlarmsGranted;
}

/// What the user did with a notification.
enum AlarmActionType {
  /// Tapped the notification body: bring the track into view.
  open,

  /// "Stopp" action on a finished countdown / interval.
  dismiss,

  /// "Erledigt" action on a due reminder.
  acknowledge,
}

final class AlarmAction {
  const AlarmAction({required this.trackId, required this.type});

  final String trackId;
  final AlarmActionType type;
}

/// Schedules OS-level alarms so that timers ring while the app is closed.
///
/// The repositories call this after every state change:
/// * [scheduleForTrack] with the complete, freshly computed plan of a track
///   (REPLACES everything previously scheduled for that track);
/// * [cancelForTrack] when the track is paused, stopped, reset or deleted.
///
/// Implementations must never throw into the caller for platform problems:
/// swallow and log, timers keep working in-app regardless.
abstract class AlarmService {
  /// Track id of the test alarm of the diagnostics page.
  static const testTrackId = 'diagnostics-test-alarm';

  /// One-time setup (plugin init, channels, time zone). Safe to call twice.
  Future<void> init();

  /// Current permission state without prompting.
  Future<AlarmPermissionStatus> permissionStatus();

  /// Runs the platform permission flow (notification permission, Android
  /// exact alarms) and returns the resulting state.
  Future<AlarmPermissionStatus> requestPermissions();

  /// Replaces all pending alarms of [track] by [alarms] (may be empty).
  /// [track] supplies name, colour and the sound / vibration switches.
  Future<void> scheduleForTrack(Track track, List<PlannedAlarm> alarms);

  /// Cancels all pending (and shown) alarms of the track.
  Future<void> cancelForTrack(String trackId);

  /// Cancels everything this app scheduled.
  Future<void> cancelAll();

  /// Privacy switch, driven by the app lock: with [hidden] the
  /// notifications do not reveal their text (the track name) on a secure
  /// lock screen. A change re-applies everything that is scheduled.
  Future<void> setContentHidden(bool hidden);

  /// Notification taps and action buttons, including the one that launched
  /// the app. The app shell routes these to the track commands.
  Stream<AlarmAction> get actions;

  /// Diagnostics: one notification after [delay] that belongs to no track
  /// ([testTrackId]). It survives [cancelAll] (the app reschedules
  /// everything on each trip to the background) until it is due, so it
  /// can be tested with the app closed. Taps on it are not reported.
  Future<void> scheduleTestAlarm(Duration delay);
}

/// Does nothing. Used in tests and on platforms without notification
/// support.
class NoopAlarmService implements AlarmService {
  const NoopAlarmService();

  @override
  Future<void> init() async {}

  @override
  Future<AlarmPermissionStatus> permissionStatus() async =>
      AlarmPermissionStatus.unsupported;

  @override
  Future<AlarmPermissionStatus> requestPermissions() async =>
      AlarmPermissionStatus.unsupported;

  @override
  Future<void> scheduleForTrack(Track track, List<PlannedAlarm> alarms) async {}

  @override
  Future<void> cancelForTrack(String trackId) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> setContentHidden(bool hidden) async {}

  @override
  Stream<AlarmAction> get actions => const Stream.empty();

  @override
  Future<void> scheduleTestAlarm(Duration delay) async {}
}

/// Records every call. Handy for repository and widget tests.
class RecordingAlarmService implements AlarmService {
  /// Currently scheduled plan per track id.
  final Map<String, List<PlannedAlarm>> scheduled = {};

  /// Chronological call log, e.g. `schedule:<id>:<n>`, `cancel:<id>`,
  /// `cancelAll`.
  final List<String> log = [];

  /// The last value passed to [setContentHidden].
  bool contentHidden = false;

  final StreamController<AlarmAction> _actions = StreamController.broadcast();

  /// Simulates a notification action.
  void emit(AlarmAction action) => _actions.add(action);

  @override
  Future<void> init() async => log.add('init');

  @override
  Future<AlarmPermissionStatus> permissionStatus() async =>
      const AlarmPermissionStatus(
        supported: true,
        notificationsGranted: true,
        exactAlarmsGranted: true,
      );

  @override
  Future<AlarmPermissionStatus> requestPermissions() => permissionStatus();

  @override
  Future<void> scheduleForTrack(Track track, List<PlannedAlarm> alarms) async {
    log.add('schedule:${track.id}:${alarms.length}');
    if (alarms.isEmpty) {
      scheduled.remove(track.id);
    } else {
      scheduled[track.id] = List.unmodifiable(alarms);
    }
  }

  @override
  Future<void> cancelForTrack(String trackId) async {
    log.add('cancel:$trackId');
    scheduled.remove(trackId);
  }

  @override
  Future<void> cancelAll() async {
    log.add('cancelAll');
    scheduled.clear();
  }

  /// Not part of [log]: tests of the scheduling calls stay unaffected.
  @override
  Future<void> setContentHidden(bool hidden) async => contentHidden = hidden;

  @override
  Future<void> scheduleTestAlarm(Duration delay) async =>
      log.add('test:${delay.inSeconds}');

  @override
  Stream<AlarmAction> get actions => _actions.stream;
}

/// The alarm service in use.
///
/// Defaults to [NoopAlarmService]. The real implementation is registered in
/// `main.dart` (`productionOverrides`) via
/// `alarmServiceProvider.overrideWithValue(...)`.
final alarmServiceProvider = Provider<AlarmService>(
  (ref) => const NoopAlarmService(),
);
