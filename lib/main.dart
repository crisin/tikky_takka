import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'app.dart';
import 'app_wiring.dart';
import 'core/db/app_database.dart';
import 'core/repo/settings_store.dart';
import 'core/services/alarms/alarms.dart';
import 'core/services/lock_service.dart';
import 'core/services/lock_service_impl.dart';
import 'core/services/screen_security.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind the system bars (Android); a no-op elsewhere.
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));

  final db = AppDatabase.defaults();
  final settings = await SettingsStore.load(db);

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        settingsStoreProvider.overrideWithValue(settings),
        ...productionOverrides(),
      ],
      child: const TikkyApp(),
    ),
  );
}

/// The real service implementations and the feature wiring.
///
/// * alarms: OS notifications (`flutter_local_notifications`) on Android,
///   iOS, macOS and Windows, a no-op elsewhere. `AlarmService.init()` is
///   called by `appBootstrapProvider` on start-up, followed by
///   `rescheduleAllAlarms()`; when the plugin cannot be initialised the
///   service turns itself into a no-op.
/// * app lock: `local_auth`; reports "not supported" where the device or
///   platform cannot authenticate, which disables the setting. On Android
///   the window is marked secure while the lock is enabled.
/// * export: CSV / JSON through the repositories, delivered with the share
///   sheet (phones) or the save dialog (desktop).
/// * settings hooks: export sheet, persons / substances, app lock tile.
///
/// None of the constructors touches a plugin; all platform work is guarded
/// inside the implementations. Widget tests do not use this list: they run
/// with the no-op / recording services (see test/support/test_app.dart).
List<Override> productionOverrides() => [
  ...featureWiringOverrides(),
  alarmServiceProvider.overrideWithValue(createAlarmService()),
  lockServiceProvider.overrideWithValue(LocalAuthLockService()),
  screenSecurityProvider.overrideWithValue(const PlatformScreenSecurity()),
];
