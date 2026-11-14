import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/track.dart';
import 'package:tikky_takka/core/domain/track_config.dart';
import 'package:tikky_takka/core/services/alarms/alarm_service.dart';
import 'package:tikky_takka/core/services/alarms/notification_backend.dart';
import 'package:tikky_takka/core/services/alarms/notification_plan.dart';
import 'package:tikky_takka/core/services/alarms/plugin_notification_backend.dart';
import 'package:tikky_takka/l10n/strings.dart';

NotificationSpec _spec(
  AlarmKind kind, {
  bool sound = true,
  bool vibration = true,
  List<int> at = const [60000, 120000],
}) {
  final track = Track(
    id: 't1',
    setId: 'set',
    name: 'Spur',
    config: const ReminderConfig(),
    alarmSound: sound,
    vibration: vibration,
  );
  return buildNotificationPlan(
    track: track,
    alarms: [
      for (var i = 0; i < at.length; i++)
        PlannedAlarm(trackId: 't1', at: at[i], kind: kind, index: i, round: 1),
    ],
    nowMs: 0,
  ).first;
}

void main() {
  group('platform support', () {
    test('Android, iOS, macOS and Windows only', () {
      expect(PluginNotificationBackend.isSupported(TargetPlatform.android), isTrue);
      expect(PluginNotificationBackend.isSupported(TargetPlatform.iOS), isTrue);
      expect(PluginNotificationBackend.isSupported(TargetPlatform.macOS), isTrue);
      expect(PluginNotificationBackend.isSupported(TargetPlatform.windows), isTrue);
      expect(PluginNotificationBackend.isSupported(TargetPlatform.linux), isFalse);
      expect(PluginNotificationBackend.isSupported(TargetPlatform.fuchsia), isFalse);
    });

    test('an unsupported platform is refused before touching the plugin',
        () async {
      final backend = PluginNotificationBackend(platform: TargetPlatform.linux);
      expect(await backend.init((_) {}), isFalse);
      expect(backend.maxPending, isNull);
    });

    test('only Apple platforms have a pending budget', () {
      expect(
        PluginNotificationBackend(platform: TargetPlatform.iOS).maxPending,
        AlarmPlatformConfig.darwinMaxPending,
      );
      expect(
        PluginNotificationBackend(platform: TargetPlatform.macOS).maxPending,
        AlarmPlatformConfig.darwinMaxPending,
      );
      expect(
        PluginNotificationBackend(platform: TargetPlatform.android).maxPending,
        isNull,
      );
      expect(
        PluginNotificationBackend(platform: TargetPlatform.windows).maxPending,
        isNull,
      );
      expect(AlarmPlatformConfig.darwinMaxPending, lessThan(64));
    });
  });

  group('initialisation settings', () {
    final settings = initializationSettings();

    test('Android uses the bundled status bar icon', () {
      expect(settings.android?.defaultIcon, 'ic_stat_tikky');
    });

    test('Apple: no prompt at start-up, one category per action', () {
      for (final darwin in [settings.iOS!, settings.macOS!]) {
        expect(darwin.requestAlertPermission, isFalse);
        expect(darwin.requestSoundPermission, isFalse);
        expect(darwin.requestBadgePermission, isFalse);
        final categories = {
          for (final c in darwin.notificationCategories) c.identifier: c,
        };
        expect(categories.keys, {
          AlarmActionIds.dismissCategory,
          AlarmActionIds.acknowledgeCategory,
        });
        final dismiss = categories[AlarmActionIds.dismissCategory]!.actions;
        expect(dismiss.single.identifier, AlarmActionIds.dismiss);
        expect(dismiss.single.title, Strings.notifActionDismiss);
        final ack = categories[AlarmActionIds.acknowledgeCategory]!.actions;
        expect(ack.single.identifier, AlarmActionIds.acknowledge);
        expect(ack.single.title, Strings.notifActionAck);
        // Handled by the running app, not by a background isolate.
        for (final action in [dismiss.single, ack.single]) {
          expect(
            action.options,
            contains(DarwinNotificationActionOption.foreground),
          );
        }
      }
    });

    test('Windows identity is well-formed', () {
      final windows = settings.windows!;
      expect(windows.appName, Strings.appName);
      expect(windows.appUserModelId, isNotEmpty);
      expect(
        windows.guid,
        matches(
          RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'),
        ),
      );
    });
  });

  group('Android', () {
    test('one channel per sound / vibration combination', () {
      for (final channel in AlarmChannel.values) {
        final android = androidChannel(channel);
        expect(android.id, channel.id);
        expect(android.name, channel.label);
        expect(android.playSound, channel.playSound);
        expect(android.enableVibration, channel.vibrate);
        expect(android.vibrationPattern == null, !channel.vibrate);
        expect(android.importance, Importance.high);
        expect(android.audioAttributesUsage, AudioAttributesUsage.alarm);
      }
    });

    test('a due reminder: channel, timing, button that opens the app', () {
      final spec = _spec(AlarmKind.reminderDue);
      final details = androidDetailsFor(spec);
      expect(details.channelId, AlarmChannel.soundAndVibration.id);
      expect(details.playSound, isTrue);
      expect(details.enableVibration, isTrue);
      expect(details.importance, Importance.high);
      expect(details.priority, Priority.high);
      expect(details.category, AndroidNotificationCategory.reminder);
      expect(details.when, 60000);
      // Removed when the next nag arrives.
      expect(details.timeoutAfter, 60000);
      final action = details.actions!.single;
      expect(action.id, AlarmActionIds.acknowledge);
      expect(action.title, Strings.notifActionAck);
      expect(action.showsUserInterface, isTrue);
      expect(action.cancelNotification, isTrue);
    });

    test('a finished countdown is an alarm with "Stopp"', () {
      final details = androidDetailsFor(
        _spec(AlarmKind.countdownDone, at: const [60000]),
      );
      expect(details.category, AndroidNotificationCategory.alarm);
      expect(details.timeoutAfter, isNull);
      expect(details.actions!.single.id, AlarmActionIds.dismiss);
      expect(details.actions!.single.title, Strings.notifActionDismiss);
    });

    test('phase changes carry no button; switches reach the details', () {
      final details = androidDetailsFor(
        _spec(AlarmKind.intervalRest, sound: false, vibration: false),
      );
      expect(details.actions, isNull);
      expect(details.channelId, AlarmChannel.silent.id);
      expect(details.playSound, isFalse);
      expect(details.enableVibration, isFalse);
      expect(details.vibrationPattern, isNull);
    });
  });

  group('iOS / macOS', () {
    test('sound switch, grouping per track and action category', () {
      final due = darwinDetailsFor(_spec(AlarmKind.reminderNag));
      expect(due.presentSound, isTrue);
      expect(due.presentBanner, isTrue);
      expect(due.presentList, isTrue);
      expect(due.threadIdentifier, 't1');
      expect(due.categoryIdentifier, AlarmActionIds.acknowledgeCategory);

      final done = darwinDetailsFor(
        _spec(AlarmKind.intervalDone, sound: false),
      );
      expect(done.presentSound, isFalse);
      expect(done.categoryIdentifier, AlarmActionIds.dismissCategory);

      final phase = darwinDetailsFor(_spec(AlarmKind.intervalWork));
      expect(phase.categoryIdentifier, isNull);
    });
  });

  group('Windows', () {
    test('the button argument names track and action', () {
      final details = windowsDetailsFor(_spec(AlarmKind.reminderDue));
      final action = details.actions.single;
      expect(action.content, Strings.notifActionAck);
      final decoded = AlarmPayload.decode(action.arguments);
      expect(decoded?.trackId, 't1');
      expect(decoded?.type, AlarmActionType.acknowledge);
      // What Windows reports for the click maps back to the same action.
      final reported = alarmActionFromResponse(
        payload: action.arguments,
        actionId: action.arguments,
      );
      expect(reported?.type, AlarmActionType.acknowledge);
      expect(details.scenario, WindowsNotificationScenario.reminder);
      expect(details.audio?.isSilent, isFalse);
    });

    test('phase changes are short and plain; silence is honoured', () {
      final phase = windowsDetailsFor(_spec(AlarmKind.intervalWork));
      expect(phase.actions, isEmpty);
      expect(phase.scenario, isNull);
      expect(phase.duration, WindowsNotificationDuration.short);
      final silent = windowsDetailsFor(
        _spec(AlarmKind.countdownDone, sound: false),
      );
      expect(silent.audio?.isSilent, isTrue);
      expect(silent.actions.single.content, Strings.notifActionDismiss);
    });
  });

  group('replyOf', () {
    test('taps and buttons are passed on, dismissals are not', () {
      const NotificationReply tap = (payload: 'p', actionId: null);
      expect(
        replyOf(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: 'p',
          ),
        ),
        tap,
      );
      expect(
        replyOf(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
            payload: 'p',
            actionId: 'a',
          ),
        ),
        (payload: 'p', actionId: 'a'),
      );
      expect(
        replyOf(
          const NotificationResponse(
            notificationResponseType:
                NotificationResponseType.notificationDismissed,
            payload: 'p',
          ),
        ),
        isNull,
      );
    });
  });

  test('details bundle every platform', () {
    final details = detailsFor(_spec(AlarmKind.countdownDone));
    expect(details.android, isNotNull);
    expect(details.iOS, isNotNull);
    expect(details.macOS, isNotNull);
    expect(details.windows, isNotNull);
  });
}
