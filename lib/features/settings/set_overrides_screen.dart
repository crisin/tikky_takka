import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../core/domain/domain.dart';
import '../../core/repo/providers.dart';
import '../../l10n/strings.dart';
import '../../theme/theme.dart';
import 'display_settings_screen.dart';
import 'settings_strings.dart';
import 'theme_actions.dart';
import 'widgets/setting_rows.dart';
import 'widgets/theme_preview.dart';
import 'widgets/ui_pref_field.dart';

/// Whether [set] deviates from the app-wide look in any way.
bool setHasOverrides(TrackSet set) =>
    set.themeId != null || (set.uiPrefsOverride?.isNotEmpty ?? false);

/// "Für dieses Set anpassen": an own theme and individual UI preferences
/// for one set, with a live preview. Only fields the user touched are
/// stored; everything else keeps following the app-wide settings.
class SetOverridesScreen extends ConsumerStatefulWidget {
  const SetOverridesScreen({required this.initialSet, super.key});

  final TrackSet initialSet;

  /// The fields a set may override.
  static const List<String> overridableKeys = [
    ...laneAppearanceKeys,
    ...laneSizeKeys,
    UiPrefsKeys.keepScreenOn,
  ];

  @override
  ConsumerState<SetOverridesScreen> createState() => _SetOverridesScreenState();
}

class _SetOverridesScreenState extends ConsumerState<SetOverridesScreen> {
  /// Working copy: updated synchronously, persisted right after.
  late TrackSet _set = widget.initialSet;

  JsonMap get _override => _set.uiPrefsOverride ?? const {};

  /// Stores the theme id and override map of [next], on top of the latest
  /// stored version of the set (so a rename made elsewhere is not undone).
  void _save(TrackSet next) {
    setState(() => _set = next);
    final stored = ref.read(allSetsProvider).value ?? const <TrackSet>[];
    final latest = stored.where((s) => s.id == next.id).firstOrNull ?? next;
    unawaited(
      ref
          .read(setRepositoryProvider)
          .updateSet(
            latest.copyWith(
              themeId: () => next.themeId,
              uiPrefsOverride: () => next.uiPrefsOverride,
            ),
          ),
    );
  }

  void _setOverride(JsonMap map) => _save(
    _set.copyWith(uiPrefsOverride: () => map.isEmpty ? null : map),
  );

  void _changeField(String key, UiPrefs next) =>
      _setOverride({..._override, key: next.toJson()[key]});

  void _resetField(String key) => _setOverride({..._override}..remove(key));

  Future<void> _pickTheme(List<TikkyTheme> themes) async {
    final choice = await showThemeChoiceSheet(
      context,
      themes: themes,
      selectedId: findTheme(themes, _set.themeId)?.id,
      title: Strings.setOverrideTheme,
      nullLabel: Strings.useAppDefault,
    );
    if (choice == null || !mounted) return;
    _save(_set.copyWith(themeId: () => choice.themeId));
  }

  void _resetAll() {
    final previous = _set;
    _save(_set.copyWith(themeId: () => null, uiPrefsOverride: () => null));
    showUndoSnackBar(
      context,
      message: SettingsStrings.overridesRemoved,
      onUndo: () {
        if (mounted) _save(previous);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Kept alive so that [_save] always builds on the latest stored set.
    ref.watch(allSetsProvider);
    final themes = ref.watch(allThemesProvider);
    final appTheme = ref.watch(appThemeProvider);
    final appPrefs = ref.watch(uiPrefsProvider);
    final theme = resolveSetTheme(
      set: _set,
      themes: themes,
      appTheme: appTheme,
    );
    final prefs = resolveSetPrefs(set: _set, appPrefs: appPrefs);
    final ownTheme = findTheme(themes, _set.themeId);

    Widget field(String key) => UiPrefField(
      key: ValueKey('override.$key'),
      fieldKey: key,
      prefs: prefs,
      overridden: _override.containsKey(key),
      onChanged: (next) => _changeField(key, next),
      onReset: () => _resetField(key),
    );

    return AdaptivePageScaffold(
      title: Text(_set.name, overflow: TextOverflow.ellipsis),
      body: PreviewLayout(
        theme: theme,
        prefs: prefs,
        child: SettingsBody(
          children: [
            AdaptiveSection(
              header: Strings.theme,
              footer: SettingsStrings.setThemeHint,
              children: [
                AdaptiveTile(
                  title: Strings.setOverrideTheme,
                  value: ownTheme?.name ?? SettingsStrings.overrideInherited,
                  onTap: () => _pickTheme(themes),
                ),
              ],
            ),
            AdaptiveSection(
              header: Strings.setOverridePrefs,
              footer: SettingsStrings.setPrefsFooter,
              children: [
                for (final key in SetOverridesScreen.overridableKeys)
                  field(key),
              ],
            ),
            if (setHasOverrides(_set))
              AdaptiveSection(
                children: [
                  AdaptiveTile(
                    title: SettingsStrings.overrideResetAll,
                    destructive: true,
                    onTap: _resetAll,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
