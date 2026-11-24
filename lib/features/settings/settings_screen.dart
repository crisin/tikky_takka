import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../core/domain/domain.dart';
import '../../core/repo/providers.dart';
import '../../l10n/strings.dart';
import '../../theme/theme.dart';
import 'data_actions.dart';
import 'default_tiles.dart';
import 'dev_screen.dart';
import 'diagnostics_screen.dart';
import 'display_settings_screen.dart';
import 'set_overrides_screen.dart';
import 'settings_hooks.dart';
import 'settings_strings.dart';
import 'theme_actions.dart';
import 'theme_list_screen.dart';
import 'widgets/setting_rows.dart';
import 'widgets/settings_icons.dart';
import 'widgets/ui_pref_field.dart';

/// The "Einstellungen" destination: appearance (theme mode, dynamic
/// colour, theme editor, lane display), behaviour, per-set overrides, data
/// (export / import, persons, substances), notifications, privacy and
/// about.
///
/// Screens owned by other features are reached through
/// `settingsHooksProvider` (see settings_hooks.dart).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hooks = ref.watch(settingsHooksProvider);
    return AdaptivePageScaffold(
      title: const Text(Strings.settingsTitle),
      largeTitle: true,
      body: SettingsBody(
        children: [
          const _AppearanceSection(),
          const _BehaviourSection(),
          const _SetsSection(),
          _DataSection(hooks: hooks),
          AdaptiveSection(
            header: Strings.settingsNotifications,
            children:
                hooks.notificationTiles?.call(context) ??
                const [DefaultNotificationTiles()],
          ),
          AdaptiveSection(
            header: Strings.settingsPrivacy,
            children:
                hooks.privacyTiles?.call(context) ??
                const [DefaultAppLockTile()],
          ),
          ...?hooks.extraSections?.call(context),
          _AboutSection(version: hooks.appVersion),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- appearance

class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  Future<void> _pickMode(
    BuildContext context,
    WidgetRef ref,
    ThemeSettings settings,
    List<TikkyTheme> themes,
  ) async {
    final choice = await showThemeChoiceSheet(
      context,
      themes: themes,
      selectedId: settings.followSystem
          ? null
          : (findTheme(themes, settings.themeId) ?? ThemePresets.light).id,
      title: Strings.theme,
      nullLabel: Strings.themeSystem,
      message: Strings.themeSystemHint,
    );
    if (choice == null) return;
    final notifier = ref.read(themeSettingsProvider.notifier);
    final id = choice.themeId;
    if (id == null) {
      await notifier.setFollowSystem(true);
    } else {
      await notifier.selectTheme(id);
    }
  }

  Future<void> _pickSystemTheme(
    BuildContext context,
    WidgetRef ref,
    ThemeSettings settings,
    List<TikkyTheme> themes, {
    required bool dark,
  }) async {
    final fallback = dark ? ThemePresets.dark : ThemePresets.light;
    final current = dark ? settings.darkThemeId : settings.lightThemeId;
    final choice = await showThemeChoiceSheet(
      context,
      themes: themes,
      selectedId: (findTheme(themes, current) ?? fallback).id,
      title: dark ? Strings.themeDarkForSystem : Strings.themeLightForSystem,
    );
    final id = choice?.themeId;
    if (id == null) return;
    final notifier = ref.read(themeSettingsProvider.notifier);
    if (dark) {
      await notifier.setDarkTheme(id);
    } else {
      await notifier.setLightTheme(id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeSettingsProvider);
    final themes = ref.watch(allThemesProvider);
    final dynamicAvailable = ref.watch(dynamicColorAvailableProvider);

    return AdaptiveSection(
      header: Strings.settingsAppearance,
      children: [
        AdaptiveTile(
          key: const ValueKey('settings.themeMode'),
          leading: Icon(SettingsIcons.brightness(context)),
          title: Strings.theme,
          value: settings.followSystem
              ? Strings.themeSystem
              : themeNameFor(
                  themes,
                  settings.themeId,
                  fallback: ThemePresets.light,
                ),
          onTap: () => _pickMode(context, ref, settings, themes),
        ),
        if (settings.followSystem) ...[
          AdaptiveTile(
            key: const ValueKey('settings.lightTheme'),
            title: Strings.themeLightForSystem,
            value: themeNameFor(
              themes,
              settings.lightThemeId,
              fallback: ThemePresets.light,
            ),
            onTap: () =>
                _pickSystemTheme(context, ref, settings, themes, dark: false),
          ),
          AdaptiveTile(
            key: const ValueKey('settings.darkTheme'),
            title: Strings.themeDarkForSystem,
            value: themeNameFor(
              themes,
              settings.darkThemeId,
              fallback: ThemePresets.dark,
            ),
            onTap: () =>
                _pickSystemTheme(context, ref, settings, themes, dark: true),
          ),
        ],
        if (dynamicAvailable)
          AdaptiveSwitchTile(
            key: const ValueKey('settings.dynamicColor'),
            title: Strings.dynamicColor,
            subtitle: Strings.dynamicColorHint,
            value: settings.useDynamicColor,
            onChanged: ref
                .read(themeSettingsProvider.notifier)
                .setUseDynamicColor,
          ),
        AdaptiveTile(
          key: const ValueKey('settings.themes'),
          leading: Icon(AdaptiveIcons.palette(context)),
          title: SettingsStrings.themeManage,
          subtitle: SettingsStrings.themeManageHint,
          onTap: () => pushAdaptivePage<void>(
            context,
            builder: (_) => const ThemeListScreen(),
          ),
        ),
        AdaptiveTile(
          key: const ValueKey('settings.display'),
          leading: Icon(SettingsIcons.display(context)),
          title: SettingsStrings.displaySettings,
          subtitle: SettingsStrings.displaySettingsHint,
          onTap: () => pushAdaptivePage<void>(
            context,
            builder: (_) => const DisplaySettingsScreen(),
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- behaviour

class _BehaviourSection extends ConsumerWidget {
  const _BehaviourSection();

  static const _keys = [
    UiPrefsKeys.haptics,
    UiPrefsKeys.keepScreenOn,
    UiPrefsKeys.use24h,
    UiPrefsKeys.dayStartMinutes,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(uiPrefsProvider);
    final notifier = ref.read(uiPrefsProvider.notifier);
    return AdaptiveSection(
      header: Strings.settingsBehaviour,
      children: [
        for (final key in _keys)
          UiPrefField(
            key: ValueKey('pref.$key'),
            fieldKey: key,
            prefs: prefs,
            onChanged: notifier.set,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------- sets

class _SetsSection extends ConsumerWidget {
  const _SetsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tikky;
    final sets = ref.watch(setsProvider).value ?? const <TrackSet>[];
    return AdaptiveSection(
      header: SettingsStrings.sectionSets,
      footer: SettingsStrings.sectionSetsFooter,
      children: [
        if (sets.isEmpty)
          Padding(
            padding: EdgeInsets.all(t.space.page),
            child: Text(SettingsStrings.noSets, style: t.text.bodyMuted),
          ),
        for (final set in sets)
          AdaptiveTile(
            key: ValueKey('settings.set.${set.id}'),
            leading: Icon(SettingsIcons.sets(context)),
            title: set.name,
            value: setHasOverrides(set)
                ? SettingsStrings.overrideActive
                : SettingsStrings.overrideInherited,
            onTap: () => pushAdaptivePage<void>(
              context,
              builder: (_) => SetOverridesScreen(initialSet: set),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------- data

class _DataSection extends ConsumerWidget {
  const _DataSection({required this.hooks});

  final SettingsHooks hooks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(uiPrefsProvider);

    void unavailable() => showInfoSnackBar(context, Strings.comingSoon);
    VoidCallback open(SettingsNavigation? hook) =>
        hook == null ? unavailable : () => hook(context, ref);

    return AdaptiveSection(
      header: Strings.settingsData,
      children: [
        // Builders give the export tiles their own context: the anchor of
        // the share popover on tablets.
        Builder(
          builder: (context) => AdaptiveTile(
            key: const ValueKey('settings.export'),
            leading: Icon(AdaptiveIcons.export(context)),
            title: SettingsStrings.dataExport,
            subtitle: SettingsStrings.dataExportHint,
            onTap: () => (hooks.openExport ?? runDefaultExport)(context, ref),
          ),
        ),
        AdaptiveTile(
          key: const ValueKey('settings.import'),
          leading: Icon(AdaptiveIcons.import(context)),
          title: SettingsStrings.dataImport,
          subtitle: SettingsStrings.dataImportHint,
          onTap: () => (hooks.openImport ?? runDefaultImport)(context, ref),
        ),
        UiPrefField(
          key: const ValueKey('pref.${UiPrefsKeys.csvSeparator}'),
          fieldKey: UiPrefsKeys.csvSeparator,
          prefs: prefs,
          onChanged: ref.read(uiPrefsProvider.notifier).set,
        ),
        AdaptiveTile(
          key: const ValueKey('settings.persons'),
          leading: Icon(AdaptiveIcons.person(context)),
          title: Strings.persons,
          subtitle: SettingsStrings.dataPersonsHint,
          onTap: open(hooks.openPersons),
        ),
        AdaptiveTile(
          key: const ValueKey('settings.substances'),
          leading: Icon(SettingsIcons.substances(context)),
          title: Strings.substances,
          subtitle: SettingsStrings.dataSubstancesHint,
          onTap: open(hooks.openSubstances),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------- about

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    return AdaptiveSection(
      header: Strings.settingsAbout,
      footer: Strings.aboutLocalOnly,
      children: [
        AdaptiveTile(
          leading: Icon(SettingsIcons.info(context)),
          title: Strings.appName,
          subtitle: SettingsStrings.aboutTagline,
        ),
        AdaptiveTile(title: Strings.version, value: version),
        AdaptiveTile(
          key: const ValueKey('settings.diagnostics'),
          leading: Icon(SettingsIcons.diagnostics(context)),
          title: SettingsStrings.diagnostics,
          subtitle: SettingsStrings.diagnosticsHint,
          onTap: () => pushAdaptivePage<void>(
            context,
            builder: (_) => DiagnosticsScreen(version: version),
          ),
        ),
        AdaptiveTile(
          key: const ValueKey('settings.dev'),
          leading: Icon(SettingsIcons.developer(context)),
          title: SettingsStrings.dev,
          subtitle: SettingsStrings.devHint,
          onTap: () => pushAdaptivePage<void>(
            context,
            builder: (_) => const DevScreen(),
          ),
        ),
        AdaptiveTile(
          key: const ValueKey('settings.licenses'),
          leading: Icon(SettingsIcons.licenses(context)),
          title: SettingsStrings.licenses,
          onTap: () => showLicensePage(
            context: context,
            applicationName: Strings.appName,
            applicationVersion: version,
          ),
        ),
      ],
    );
  }
}
