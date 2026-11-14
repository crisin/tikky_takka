/// Alarms: the service interface, the real implementation on top of OS
/// notifications and the pure notification planning.
///
/// Wiring (the only line needed in `productionOverrides()` in `main.dart`):
///
/// ```dart
/// alarmServiceProvider.overrideWithValue(createAlarmService()),
/// ```
///
/// `AlarmService.init()` and the rescheduling from the event log are called
/// by `appBootstrapProvider`; notification taps are routed by
/// `alarmActionRouterProvider`.
library;

import '../../clock.dart';
import 'alarm_service.dart';
import 'local_notifications_alarm_service.dart';
import 'plugin_notification_backend.dart';

export 'alarm_service.dart';
export 'alarm_strings.dart';
export 'local_notifications_alarm_service.dart';
export 'notification_backend.dart';
export 'notification_plan.dart';
export 'plugin_notification_backend.dart'
    show AlarmPlatformConfig, PluginNotificationBackend;

/// The alarm service for the platform the app runs on: OS notifications on
/// Android, iOS, macOS and Windows, a no-op everywhere else (Linux, web).
///
/// Creating it has no side effects; all plugin work starts in
/// `AlarmService.init()`, which never throws.
AlarmService createAlarmService({Clock clock = const SystemClock()}) {
  if (!PluginNotificationBackend.isSupported()) {
    return const NoopAlarmService();
  }
  return LocalNotificationsAlarmService(clock: clock);
}
