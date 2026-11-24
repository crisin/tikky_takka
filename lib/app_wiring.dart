import 'package:flutter_riverpod/misc.dart' show Override;

import 'core/services/export_service.dart';
import 'core/services/export_service_impl.dart';
import 'features/history/export_sheet.dart';
import 'features/settings/data_actions.dart';
import 'features/settings/lock_gate.dart';
import 'features/settings/settings_hooks.dart';

/// The settings screen's entry points into the other features: the export
/// sheet (history), the person / substance lists (protocol) and the app
/// lock tile.
///
/// The "Benachrichtigungen" section keeps the settings feature's own
/// permission rows: they are driven by `alarmServiceProvider` and are the
/// complete implementation, not a placeholder.
final appSettingsHooks = SettingsHooks(
  openExport: (context, ref) => showExportSheet(context),
  openImport: runDefaultImport,
  privacyTiles: (context) => const [AppLockTile()],
);

/// Everything that connects the features to each other and needs no
/// plugin: used by the production app (`productionOverrides()` in
/// main.dart) and by widget tests of the complete app.
///
/// The export service reads through the repositories; handing a file to
/// the OS is the only plugin work and happens when the user exports.
///
/// [exportDelivery] replaces the share sheet / save dialog (tests).
List<Override> featureWiringOverrides({ExportDelivery? exportDelivery}) => [
  settingsHooksProvider.overrideWithValue(appSettingsHooks),
  exportServiceProvider.overrideWith(
    (ref) => ExportServiceImpl.fromRef(ref, delivery: exportDelivery),
  ),
];
