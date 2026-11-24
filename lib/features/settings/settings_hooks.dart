import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens a screen or sheet that another feature owns.
typedef SettingsNavigation = Future<void> Function(
  BuildContext context,
  WidgetRef ref,
);

/// INTEGRATION HOOKS of the settings screen.
///
/// The settings screen offers entry points to things other features build:
/// the export sheet, backup import, the person / substance lists and the
/// app lock tile. Those features are wired in HERE, in one of two ways:
///
/// 1. override the provider (e.g. in `productionOverrides()` in main.dart):
///
/// ```dart
/// settingsHooksProvider.overrideWithValue(
///   SettingsHooks(
///     openExport: (context, ref) => showExportSheet(context),
///     openPersons: (context, ref) =>
///         pushAdaptivePage(context, builder: (_) => const PersonsScreen()),
///     openSubstances: (context, ref) =>
///         pushAdaptivePage(context, builder: (_) => const SubstancesScreen()),
///     privacyTiles: (context) => const [AppLockTile()],
///   ),
/// ),
/// ```
///
/// 2. or change the default returned by [settingsHooksProvider] below.
///
/// Every hook is optional. What happens while a hook is `null`:
/// * [openExport]: a plain action sheet builds the three exports through
///   `exportServiceProvider` (everything, protocol tracks excluded);
/// * [openImport]: `ExportService.pickJsonFile` + `importJsonBackup`;
/// * [openPersons] / [openSubstances]: the tile tells the user that the
///   area is not available yet;
/// * [privacyTiles]: a simple switch bound to `appLockEnabledProvider`
///   (disabled when `lockSupportedProvider` says the device cannot lock);
/// * [notificationTiles]: permission rows driven by `alarmServiceProvider`.
@immutable
final class SettingsHooks {
  const SettingsHooks({
    this.openExport,
    this.openImport,
    this.openPersons,
    this.openSubstances,
    this.privacyTiles,
    this.notificationTiles,
    this.extraSections,
    this.appVersion = defaultAppVersion,
  });

  /// Kept in sync with `version:` in pubspec.yaml by hand; no package for
  /// reading it at run time is installed (see [appVersion]).
  static const defaultAppVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );

  /// Opens the export sheet (CSV sessions / events, JSON backup).
  final SettingsNavigation? openExport;

  /// Starts the JSON backup import.
  final SettingsNavigation? openImport;

  /// Opens the "Personen" management screen.
  final SettingsNavigation? openPersons;

  /// Opens the "Substanzen" management screen.
  final SettingsNavigation? openSubstances;

  /// Rows of the "Privatsphäre" section (the app lock tile).
  final List<Widget> Function(BuildContext context)? privacyTiles;

  /// Rows of the "Benachrichtigungen" section.
  final List<Widget> Function(BuildContext context)? notificationTiles;

  /// Whole extra sections, shown before "Über".
  final List<Widget> Function(BuildContext context)? extraSections;

  /// Version text shown in the "Über" section.
  final String appVersion;
}

/// The hooks in use. Defaults to "nothing wired": the settings screen then
/// falls back to the behaviour described on [SettingsHooks].
final settingsHooksProvider = Provider<SettingsHooks>(
  (ref) => const SettingsHooks(),
);
