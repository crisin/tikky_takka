import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/tracks/tracks_view.dart';
import '../../theme/theme_controllers.dart';
import '../repo/providers.dart';
import 'lock_service.dart';

/// Every provider that caches a value of the settings store.
///
/// A backup import changes the store behind their backs; call this right
/// after `ExportService.importJsonBackup` (which reloads the store) so
/// they read the merged settings. Used by BOTH import entry points - the
/// settings screen and the export sheet - so neither can forget one.
///
/// The app lock is device-local and never imported; it is refreshed all
/// the same, so that the switch always shows what the store holds.
void refreshSettingsAfterImport(WidgetRef ref) {
  ref
    ..invalidate(uiPrefsProvider)
    ..invalidate(themeSettingsProvider)
    ..invalidate(customThemesProvider)
    ..invalidate(activeSetIdProvider)
    ..invalidate(tracksViewsProvider)
    ..invalidate(appLockEnabledProvider);
}
