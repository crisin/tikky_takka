import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../l10n/strings.dart';
import 'alarm_service.dart' show AlarmActionType;
import 'notification_backend.dart';
import 'notification_plan.dart';

/// Platform constants of the notification set-up.
abstract final class AlarmPlatformConfig {
  /// Android small icon: `android/app/src/main/res/drawable/ic_stat_tikky.xml`
  /// (kept in release builds by `res/raw/keep.xml`).
  static const androidIcon = 'ic_stat_tikky';

  /// Windows toast identity of the app (unpackaged and MSIX builds).
  static const windowsAppUserModelId = 'TikkyTakka.TikkyTakka.App';

  /// Windows COM activator id of the app. Never change it after a release:
  /// scheduled toasts are bound to it.
  static const windowsGuid = 'bdf14d2b-42b6-4bc8-aa45-5536df7effe9';

  /// The plugin error code for a refused exact alarm on Android 12+.
  static const exactAlarmsErrorCode = 'exact_alarms_not_permitted';

  /// iOS keeps at most 64 pending local notifications per app; stay a
  /// little below.
  static const darwinMaxPending = 60;

  /// Vibration pattern of an alarm notification on Android
  /// (wait, buzz, pause, buzz ... in milliseconds).
  static const androidVibrationPattern = [0, 350, 200, 350, 200, 600];
}

/// The production [NotificationBackend] on top of
/// `flutter_local_notifications` (Android, iOS, macOS, Windows).
///
/// Scheduling uses absolute UTC instants (`tz.UTC`). The plugin hands the
/// wall-clock time plus the zone name to the OS; with UTC that pair is
/// never ambiguous, whereas a local wall-clock time is ambiguous in the
/// repeated hour at the end of daylight saving time and would fire an hour
/// early there. No time zone database and no device time zone lookup is
/// needed for that.
class PluginNotificationBackend implements NotificationBackend {
  PluginNotificationBackend({
    FlutterLocalNotificationsPlugin? plugin,
    TargetPlatform? platform,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _platform = platform ?? defaultTargetPlatform;

  final FlutterLocalNotificationsPlugin _plugin;
  final TargetPlatform _platform;

  /// Whether this backend can do anything on the current platform. Linux
  /// has no scheduler behind the plugin, the web no scheduling at all.
  static bool isSupported([TargetPlatform? platform]) {
    if (kIsWeb) return false;
    return switch (platform ?? defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      TargetPlatform.linux || TargetPlatform.fuchsia => false,
    };
  }

  bool get _isAndroid => _platform == TargetPlatform.android;
  bool get _isIOS => _platform == TargetPlatform.iOS;
  bool get _isMacOS => _platform == TargetPlatform.macOS;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  MacOSFlutterLocalNotificationsPlugin? get _macos => _plugin
      .resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin
      >();

  @override
  int? get maxPending =>
      _isIOS || _isMacOS ? AlarmPlatformConfig.darwinMaxPending : null;

  @override
  Future<bool> init(void Function(NotificationReply reply) onReply) async {
    if (!isSupported(_platform)) return false;
    final ok = await _plugin.initialize(
      settings: initializationSettings(),
      onDidReceiveNotificationResponse: (response) {
        final reply = replyOf(response);
        if (reply != null) onReply(reply);
      },
    );
    if (ok == false) return false;
    if (_isAndroid) {
      final android = _android;
      if (android != null) {
        for (final channel in AlarmChannel.values) {
          await android.createNotificationChannel(androidChannel(channel));
        }
      }
    }
    return true;
  }

  @override
  Future<NotificationReply?> launchReply() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    final response = details.notificationResponse;
    return response == null ? null : replyOf(response);
  }

  @override
  Future<bool> notificationsGranted() async {
    if (_isAndroid) return await _android?.areNotificationsEnabled() ?? false;
    if (_isIOS) return (await _ios?.checkPermissions())?.isEnabled ?? false;
    if (_isMacOS) return (await _macos?.checkPermissions())?.isEnabled ?? false;
    return true;
  }

  @override
  Future<bool> exactAlarmsGranted() async {
    if (!_isAndroid) return true;
    return await _android?.canScheduleExactNotifications() ?? false;
  }

  @override
  Future<bool> requestNotifications() async {
    if (_isAndroid) {
      return await _android?.requestNotificationsPermission() ?? false;
    }
    if (_isIOS) {
      return await _ios?.requestPermissions(alert: true, sound: true) ?? false;
    }
    if (_isMacOS) {
      return await _macos?.requestPermissions(alert: true, sound: true) ??
          false;
    }
    return true;
  }

  @override
  Future<bool> requestExactAlarms() async {
    if (!_isAndroid) return true;
    return await _android?.requestExactAlarmsPermission() ?? false;
  }

  @override
  Future<void> schedule(NotificationSpec spec, {required bool exact}) async {
    try {
      await _plugin.zonedSchedule(
        id: spec.id,
        scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(
          tz.UTC,
          spec.fireAtMs,
        ),
        notificationDetails: detailsFor(spec),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        title: spec.title,
        body: spec.body,
        payload: spec.payload,
      );
    } on ArgumentError {
      // The only argument that can be invalid here is the date: the plugin
      // refuses instants that are not in the future.
      throw const NotificationInPast();
    } on PlatformException catch (e) {
      if (e.code == AlarmPlatformConfig.exactAlarmsErrorCode) {
        throw const ExactAlarmsDenied();
      }
      rethrow;
    }
  }

  @override
  Future<void> showNow(NotificationSpec spec) => _plugin.show(
    id: spec.id,
    title: spec.title,
    body: spec.body,
    notificationDetails: detailsFor(spec),
    payload: spec.payload,
  );

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}

// ------------------------------------------------- pure plugin mappings

/// Converts a plugin response; `null` for events that are not a tap
/// (dismissal callbacks).
NotificationReply? replyOf(NotificationResponse response) {
  switch (response.notificationResponseType) {
    case NotificationResponseType.selectedNotification:
    case NotificationResponseType.selectedNotificationAction:
      return (payload: response.payload, actionId: response.actionId);
    case NotificationResponseType.notificationDismissed:
      return null;
  }
}

/// Plugin initialisation for every supported platform.
///
/// iOS / macOS: no permission prompt at start-up (the alarm service asks
/// when the first alarm is scheduled) and one category per action button.
/// Actions bring the app to the foreground, so they are handled by the
/// running app (main isolate) with the open database.
InitializationSettings initializationSettings() {
  final darwin = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestSoundPermission: false,
    requestBadgePermission: false,
    notificationCategories: [
      DarwinNotificationCategory(
        AlarmActionIds.dismissCategory,
        actions: [
          DarwinNotificationAction.plain(
            AlarmActionIds.dismiss,
            Strings.notifActionDismiss,
            options: const {DarwinNotificationActionOption.foreground},
          ),
        ],
      ),
      DarwinNotificationCategory(
        AlarmActionIds.acknowledgeCategory,
        actions: [
          DarwinNotificationAction.plain(
            AlarmActionIds.acknowledge,
            Strings.notifActionAck,
            options: const {DarwinNotificationActionOption.foreground},
          ),
        ],
      ),
    ],
  );
  return InitializationSettings(
    android: const AndroidInitializationSettings(
      AlarmPlatformConfig.androidIcon,
    ),
    iOS: darwin,
    macOS: darwin,
    windows: const WindowsInitializationSettings(
      appName: Strings.appName,
      appUserModelId: AlarmPlatformConfig.windowsAppUserModelId,
      guid: AlarmPlatformConfig.windowsGuid,
    ),
  );
}

/// The Android channel behind an [AlarmChannel].
///
/// Sound goes through the alarm stream: a timer the user started must be
/// audible even when the ringer is muted; whoever wants silence switches
/// "Ton beim Alarm" off on the track.
AndroidNotificationChannel androidChannel(AlarmChannel channel) =>
    AndroidNotificationChannel(
      channel.id,
      channel.label,
      description: Strings.notifChannelDescription,
      importance: Importance.high,
      playSound: channel.playSound,
      enableVibration: channel.vibrate,
      vibrationPattern: channel.vibrate ? _vibrationPattern() : null,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );

Int64List _vibrationPattern() =>
    Int64List.fromList(AlarmPlatformConfig.androidVibrationPattern);

String _actionLabel(AlarmActionType action) => switch (action) {
  AlarmActionType.dismiss => Strings.notifActionDismiss,
  AlarmActionType.acknowledge => Strings.notifActionAck,
  AlarmActionType.open => Strings.appName,
};

/// Platform details of one notification.
NotificationDetails detailsFor(NotificationSpec spec) => NotificationDetails(
  android: androidDetailsFor(spec),
  iOS: darwinDetailsFor(spec),
  macOS: darwinDetailsFor(spec),
  windows: windowsDetailsFor(spec),
);

AndroidNotificationDetails androidDetailsFor(NotificationSpec spec) {
  final action = spec.action;
  final actionId = AlarmActionIds.of(action);
  return AndroidNotificationDetails(
    spec.channel.id,
    spec.channel.label,
    channelDescription: Strings.notifChannelDescription,
    importance: Importance.high,
    priority: Priority.high,
    playSound: spec.playSound,
    enableVibration: spec.vibrate,
    vibrationPattern: spec.vibrate ? _vibrationPattern() : null,
    audioAttributesUsage: AudioAttributesUsage.alarm,
    category: spec.isReminder
        ? AndroidNotificationCategory.reminder
        : AndroidNotificationCategory.alarm,
    // With the app lock on, a secure lock screen shows that Tikky Takka
    // has a notification, but not which track rang.
    visibility: spec.hideOnLockScreen
        ? NotificationVisibility.private
        : NotificationVisibility.public,
    when: spec.dueAtMs,
    ticker: spec.title,
    timeoutAfter: spec.timeoutAfterMs,
    actions: action == null || actionId == null
        ? null
        : [
            AndroidNotificationAction(
              actionId,
              _actionLabel(action),
              // Open the app: the command runs in the main isolate against
              // the open database and the lanes update at once.
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
  );
}

DarwinNotificationDetails darwinDetailsFor(NotificationSpec spec) =>
    DarwinNotificationDetails(
      presentBanner: true,
      presentList: true,
      presentBadge: false,
      presentSound: spec.playSound,
      threadIdentifier: spec.trackId,
      categoryIdentifier: AlarmActionIds.categoryOf(spec.action),
      interruptionLevel: InterruptionLevel.active,
    );

WindowsNotificationDetails windowsDetailsFor(NotificationSpec spec) {
  final action = spec.action;
  return WindowsNotificationDetails(
    actions: [
      if (action != null)
        WindowsAction(
          content: _actionLabel(action),
          // Windows hands back only this string for a button press.
          arguments: AlarmPayload.encode(spec.trackId, action),
        ),
    ],
    audio: spec.playSound
        ? WindowsNotificationAudio.preset(
            sound: spec.needsAttention
                ? WindowsNotificationSound.reminder
                : WindowsNotificationSound.defaultSound,
          )
        : WindowsNotificationAudio.silent(),
    // "reminder" keeps the toast on screen until the user reacts; it needs
    // a button, which every such notification has.
    scenario: spec.needsAttention && action != null
        ? WindowsNotificationScenario.reminder
        : null,
    duration: spec.needsAttention
        ? WindowsNotificationDuration.long
        : WindowsNotificationDuration.short,
  );
}
