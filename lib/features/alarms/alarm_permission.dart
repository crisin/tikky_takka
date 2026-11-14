import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/alarms/alarm_service.dart';

/// The OS permission state for background alarms, for settings rows and the
/// permission banner.
///
/// * `ref.watch(alarmPermissionProvider)` - current state without prompting.
/// * `ref.read(alarmPermissionProvider.notifier).request()` - runs the
///   platform flow (Android 13+ notification prompt, Android 12+ exact
///   alarm page, iOS / macOS prompt).
/// * `ref.read(alarmPermissionProvider.notifier).refresh()` - re-reads the
///   state, e.g. after the app came back from the system settings.
final alarmPermissionProvider =
    AsyncNotifierProvider<AlarmPermissionController, AlarmPermissionStatus>(
      AlarmPermissionController.new,
    );

class AlarmPermissionController extends AsyncNotifier<AlarmPermissionStatus> {
  @override
  Future<AlarmPermissionStatus> build() =>
      ref.watch(alarmServiceProvider).permissionStatus();

  Future<AlarmPermissionStatus> refresh() async {
    final status = await ref.read(alarmServiceProvider).permissionStatus();
    if (ref.mounted) state = AsyncData(status);
    return status;
  }

  Future<AlarmPermissionStatus> request() async {
    final status = await ref.read(alarmServiceProvider).requestPermissions();
    if (ref.mounted) state = AsyncData(status);
    return status;
  }
}
