import 'notification_plan.dart';

/// What the OS reports when the user taps a notification or one of its
/// action buttons. Decode with `alarmActionFromResponse`.
typedef NotificationReply = ({String? payload, String? actionId});

/// The scheduled instant has passed before the OS accepted the request.
final class NotificationInPast implements Exception {
  const NotificationInPast();

  @override
  String toString() => 'NotificationInPast';
}

/// Android refused an exact alarm because the permission is missing.
final class ExactAlarmsDenied implements Exception {
  const ExactAlarmsDenied();

  @override
  String toString() => 'ExactAlarmsDenied';
}

/// The thin, plugin-shaped seam under the alarm service.
///
/// `LocalNotificationsAlarmService` holds all decisions (what replaces
/// what, fallbacks, budgets, error handling) and talks to the OS only
/// through this interface, so that logic runs in unit tests against a fake.
/// The production implementation is `PluginNotificationBackend`.
///
/// Unlike `AlarmService`, methods here MAY throw; the service catches.
abstract class NotificationBackend {
  /// Initialises the plugin, channels and action categories. Returns
  /// `false` when notifications cannot be used on this device. Called once.
  Future<bool> init(void Function(NotificationReply reply) onReply);

  /// The tap that launched the app from a terminated state, if any.
  Future<NotificationReply?> launchReply();

  /// Upper bound of pending notifications the OS keeps for the whole app
  /// (iOS: 64); `null` when unlimited.
  int? get maxPending;

  Future<bool> notificationsGranted();

  /// Android 12+: exact alarms allowed. `true` where not applicable.
  Future<bool> exactAlarmsGranted();

  /// Shows the system prompt if the platform has one; returns the result.
  Future<bool> requestNotifications();

  /// Android 12+: opens the "Alarme & Erinnerungen" system page when the
  /// permission is missing. `true` where not applicable.
  Future<bool> requestExactAlarms();

  /// Schedules [spec] at `spec.fireAtMs`.
  ///
  /// Throws [NotificationInPast] when that instant has passed and
  /// [ExactAlarmsDenied] when [exact] was requested without permission.
  Future<void> schedule(NotificationSpec spec, {required bool exact});

  /// Shows [spec] right away.
  Future<void> showNow(NotificationSpec spec);

  /// Cancels the pending notification [id] and removes it if shown.
  Future<void> cancel(int id);

  /// Cancels and removes everything of this app.
  Future<void> cancelAll();
}
