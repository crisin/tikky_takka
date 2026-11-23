import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'app.dart';
import 'app_wiring.dart';
import 'core/db/app_database.dart';
import 'core/repo/settings_store.dart';
import 'core/services/alarms/alarms.dart';
import 'core/services/diagnostics_log.dart';
import 'core/services/lock_service.dart';
import 'core/services/lock_service_impl.dart';
import 'core/services/screen_security.dart';
import 'theme/bundled_fonts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _recordErrors(DiagnosticsLog.instance);
  registerFontLicenses();
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

/// Uncaught errors also go to the diagnostics page in the settings (on a
/// phone there is no console to read them from).
void _recordErrors(DiagnosticsLog log) {
  final presentError = FlutterError.onError;
  FlutterError.onError = (details) {
    log.record('Flutter', details.exceptionAsString(), details.stack);
    presentError?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    log.record('Unbehandelt', error, stack);
    return false;
  };
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
  alarmServiceProvider.overrideWithValue(
    createAlarmService(onError: DiagnosticsLog.instance.handlerFor('Alarme')),
  ),
  lockServiceProvider.overrideWithValue(LocalAuthLockService()),
  screenSecurityProvider.overrideWithValue(const PlatformScreenSecurity()),
];
