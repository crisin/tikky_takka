import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../core/services/alarms/alarm_service.dart';
import '../../core/services/lock_service.dart';
import '../../l10n/strings.dart';
import '../../theme/theme.dart';
import 'settings_strings.dart';

/// FALLBACK app lock switch, shown while `SettingsHooks.privacyTiles` is not
/// wired to the privacy feature's own tile.
///
/// Bound to `appLockEnabledProvider`; disabled with a hint where
/// `lockSupportedProvider` reports that the device cannot authenticate.
/// Switching the lock ON asks for authentication first, so nobody locks
/// themselves out with a lock they cannot open.
class DefaultAppLockTile extends ConsumerWidget {
  const DefaultAppLockTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supported = ref.watch(lockSupportedProvider).value ?? false;
    final enabled = ref.watch(appLockEnabledProvider);

    Future<void> change(bool value) async {
      final notifier = ref.read(appLockEnabledProvider.notifier);
      if (value) {
        final ok = await ref
            .read(lockServiceProvider)
            .authenticate(reason: Strings.appLockReason);
        if (!ok) return;
      }
      await notifier.set(value);
    }

    return AdaptiveSwitchTile(
      title: Strings.appLock,
      subtitle: supported ? Strings.appLockHint : Strings.appLockUnavailable,
      leading: Icon(AdaptiveIcons.lock(context)),
      value: supported && enabled,
      onChanged: supported ? change : null,
    );
  }
}

/// FALLBACK rows of the "Benachrichtigungen" section, shown while
/// `SettingsHooks.notificationTiles` is not wired: the notification and
/// exact-alarm permissions as reported by the alarm service. Tapping a
/// missing permission runs the platform's permission flow.
class DefaultNotificationTiles extends ConsumerStatefulWidget {
  const DefaultNotificationTiles({super.key});

  @override
  ConsumerState<DefaultNotificationTiles> createState() =>
      _DefaultNotificationTilesState();
}

class _DefaultNotificationTilesState
    extends ConsumerState<DefaultNotificationTiles>
    with WidgetsBindingObserver {
  AlarmPermissionStatus? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may have changed the permission in the system settings.
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() => _load((alarms) => alarms.permissionStatus());

  Future<void> _request() => _load((alarms) => alarms.requestPermissions());

  Future<void> _load(
    Future<AlarmPermissionStatus> Function(AlarmService alarms) query,
  ) async {
    AlarmPermissionStatus status;
    try {
      status = await query(ref.read(alarmServiceProvider));
    } catch (_) {
      status = AlarmPermissionStatus.unsupported;
    }
    if (mounted) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final status = _status;
    if (status == null) {
      return const AdaptiveTile(
        title: Strings.notificationsPermission,
        value: SettingsStrings.notificationsChecking,
      );
    }
    if (!status.supported) {
      return const AdaptiveTile(
        title: Strings.settingsNotifications,
        subtitle: Strings.notificationsUnsupported,
      );
    }

    Widget row(String title, String hint, {required bool granted}) =>
        AdaptiveTile(
          title: title,
          subtitle: granted
              ? hint
              : '$hint ${SettingsStrings.notificationsRequest}',
          value: granted ? Strings.permissionGranted : Strings.permissionMissing,
          onTap: granted ? null : _request,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row(
          Strings.notificationsPermission,
          Strings.notificationsPermissionHint,
          granted: status.notificationsGranted,
        ),
        Divider(height: t.sizes.hairline, indent: t.space.page),
        row(
          Strings.exactAlarmsPermission,
          Strings.exactAlarmsPermissionHint,
          granted: status.exactAlarmsGranted,
        ),
      ],
    );
  }
}
