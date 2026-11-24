import 'dart:ui' show Brightness, Color, PlatformDispatcher;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeData;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/domain/json_utils.dart';
import '../core/domain/track_set.dart';
import '../core/repo/providers.dart';
import '../core/repo/settings_store.dart';
import '../l10n/strings.dart';
import 'theme_builder.dart';
import 'theme_presets.dart';
import 'theme_settings.dart';
import 'tikky_theme.dart';
import 'ui_prefs.dart';

// ------------------------------------------------------------ theme settings

/// Which theme is selected (system mode, fixed theme, dynamic colour).
/// Persisted in the settings store.
class ThemeSettingsController extends Notifier<ThemeSettings> {
  @override
  ThemeSettings build() {
    final json = ref
        .watch(settingsStoreProvider)
        .getJson(SettingsKeys.themeSettings);
    return json == null ? ThemeSettings.defaults : ThemeSettings.fromJson(json);
  }

  Future<void> set(ThemeSettings settings) async {
    state = settings;
    await ref
        .read(settingsStoreProvider)
        .setJson(SettingsKeys.themeSettings, settings.toJson());
  }

  /// Turns "System" mode (follow OS light / dark) on or off.
  Future<void> setFollowSystem(bool follow) =>
      set(state.copyWith(followSystem: follow));

  /// Selects a fixed theme and leaves system mode.
  Future<void> selectTheme(String themeId) =>
      set(state.copyWith(followSystem: false, themeId: themeId));

  /// Theme used in system mode while the OS is light.
  Future<void> setLightTheme(String themeId) =>
      set(state.copyWith(lightThemeId: themeId));

  /// Theme used in system mode while the OS is dark.
  Future<void> setDarkTheme(String themeId) =>
      set(state.copyWith(darkThemeId: themeId));

  Future<void> setUseDynamicColor(bool use) =>
      set(state.copyWith(useDynamicColor: use));
}

final themeSettingsProvider =
    NotifierProvider<ThemeSettingsController, ThemeSettings>(
      ThemeSettingsController.new,
    );

// -------------------------------------------------------------- custom themes

/// The user's own themes. Persisted in the settings store.
class CustomThemesController extends Notifier<List<TikkyTheme>> {
  @override
  List<TikkyTheme> build() {
    final json = ref
        .watch(settingsStoreProvider)
        .getJson(SettingsKeys.customThemes);
    final list = json?['themes'];
    return List.unmodifiable([
      if (list is List)
        for (final entry in list)
          if (entry is Map) _decode(jsonMap(entry)),
    ]);
  }

  TikkyTheme _decode(JsonMap json) {
    final brightness = json['brightness'] == 'dark'
        ? Brightness.dark
        : Brightness.light;
    return TikkyTheme.fromJson(
      json,
      fallback: ThemePresets.forBrightness(brightness),
    );
  }

  Future<void> _persist(List<TikkyTheme> themes) async {
    state = List.unmodifiable(themes);
    await ref.read(settingsStoreProvider).setJson(SettingsKeys.customThemes, {
      'themes': [for (final t in themes) t.toJson()],
    });
  }

  /// Copies [source] (preset or custom) into a new editable custom theme
  /// and returns it.
  Future<TikkyTheme> duplicate(TikkyTheme source, {String? name}) async {
    final copy = source.copyWith(
      id: ref.read(idGeneratorProvider)(),
      name: name ?? Strings.themeCopyName(source.name),
    );
    await _persist([...state, copy]);
    return copy;
  }

  /// Saves a custom theme (inserts it, or replaces the one with the same
  /// id). Presets are read-only: returns `false` for a preset id.
  Future<bool> save(TikkyTheme theme) async {
    if (ThemePresets.isPresetId(theme.id)) return false;
    final exists = state.any((t) => t.id == theme.id);
    await _persist([
      for (final t in state)
        if (t.id == theme.id) theme else t,
      if (!exists) theme,
    ]);
    return true;
  }

  Future<bool> rename(String id, String name) async {
    final theme = findTheme(state, id);
    if (theme == null) return false;
    return save(theme.copyWith(name: name));
  }

  /// Deletes a custom theme and returns it (for undo via [save]). Places
  /// that still reference the id fall back to a preset automatically.
  Future<TikkyTheme?> delete(String id) async {
    final theme = findTheme(state, id);
    if (theme == null) return null;
    await _persist([
      for (final t in state)
        if (t.id != id) t,
    ]);
    return theme;
  }

  /// The JSON file content for a theme (preset or custom); `null` if the id
  /// is unknown.
  String? exportFile(String id) =>
      (ThemePresets.byId(id) ?? findTheme(state, id))?.toFileContent();

  /// Imports a theme file as a NEW custom theme (it always gets a fresh id,
  /// so an import never overwrites anything). Returns `null` when [source]
  /// is not a valid theme file.
  Future<TikkyTheme?> importFile(String source) async {
    final parsed = TikkyTheme.tryParseFile(
      source,
      fallbackFor: ThemePresets.forBrightness,
    );
    if (parsed == null) return null;
    final theme = parsed.copyWith(id: ref.read(idGeneratorProvider)());
    await _persist([...state, theme]);
    return theme;
  }
}

final customThemesProvider =
    NotifierProvider<CustomThemesController, List<TikkyTheme>>(
      CustomThemesController.new,
    );

/// Presets followed by custom themes.
final allThemesProvider = Provider<List<TikkyTheme>>(
  (ref) => [...ThemePresets.all, ...ref.watch(customThemesProvider)],
);

// ------------------------------------------------------------------- UI prefs

/// App-wide UI preferences. Persisted in the settings store.
class UiPrefsController extends Notifier<UiPrefs> {
  @override
  UiPrefs build() {
    final json = ref.watch(settingsStoreProvider).getJson(SettingsKeys.uiPrefs);
    return json == null ? UiPrefs.defaults : UiPrefs.fromJson(json);
  }

  Future<void> set(UiPrefs prefs) async {
    state = prefs;
    await ref
        .read(settingsStoreProvider)
        .setJson(SettingsKeys.uiPrefs, prefs.toJson());
  }

  /// `ref.read(uiPrefsProvider.notifier).change((p) => p.copyWith(...))`
  Future<void> change(UiPrefs Function(UiPrefs prefs) update) =>
      set(update(state));
}

final uiPrefsProvider = NotifierProvider<UiPrefsController, UiPrefs>(
  UiPrefsController.new,
);

// ------------------------------------------------------- system light / dark

/// The OS brightness. The app shell keeps it up to date from
/// `didChangePlatformBrightness`.
class PlatformBrightnessController extends Notifier<Brightness> {
  @override
  Brightness build() => PlatformDispatcher.instance.platformBrightness;

  void set(Brightness brightness) {
    if (state != brightness) state = brightness;
  }
}

final platformBrightnessProvider =
    NotifierProvider<PlatformBrightnessController, Brightness>(
      PlatformBrightnessController.new,
    );

// -------------------------------------------------------------- dynamic color

/// Material You accent colours from the OS; `null` where unavailable (every
/// platform except Android 12+). Never throws.
final dynamicPaletteProvider = FutureProvider<DynamicPalette?>((ref) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  try {
    final palette = await DynamicColorPlugin.getCorePalette();
    if (palette == null) return null;
    return DynamicPalette(
      lightPrimary: Color(palette.primary.get(40)),
      lightOnPrimary: Color(palette.primary.get(100)),
      darkPrimary: Color(palette.primary.get(80)),
      darkOnPrimary: Color(palette.primary.get(20)),
    );
  } catch (_) {
    return null;
  }
});

/// Whether the "Systemfarben verwenden" switch should be offered.
final dynamicColorAvailableProvider = Provider<bool>(
  (ref) => ref.watch(dynamicPaletteProvider).value != null,
);

// ----------------------------------------------------------------- resolution

/// The app-wide theme tokens (system mode and dynamic colour resolved).
final appThemeProvider = Provider<TikkyTheme>(
  (ref) => resolveAppTheme(
    settings: ref.watch(themeSettingsProvider),
    themes: ref.watch(allThemesProvider),
    platformBrightness: ref.watch(platformBrightnessProvider),
    dynamicPalette: ref.watch(dynamicPaletteProvider).value,
  ),
);

/// The app-wide Material theme (with `TikkyTokens` and the Cupertino theme).
final appThemeDataProvider = Provider<ThemeData>(
  (ref) => buildMaterialTheme(
    ref.watch(appThemeProvider),
    ref.watch(uiPrefsProvider),
  ),
);

TrackSet? _setById(Ref ref, String? setId) {
  if (setId == null) return null;
  final sets = ref.watch(allSetsProvider).value ?? const <TrackSet>[];
  for (final set in sets) {
    if (set.id == setId) return set;
  }
  return null;
}

/// Theme tokens for a set (its override, else the app theme). Pass `null`
/// for "no set".
final themeForSetProvider = Provider.family<TikkyTheme, String?>(
  (ref, setId) => resolveSetTheme(
    set: _setById(ref, setId),
    themes: ref.watch(allThemesProvider),
    appTheme: ref.watch(appThemeProvider),
  ),
);

/// UI preferences for a set (app prefs with the set's partial override).
final uiPrefsForSetProvider = Provider.family<UiPrefs, String?>(
  (ref, setId) => resolveSetPrefs(
    set: _setById(ref, setId),
    appPrefs: ref.watch(uiPrefsProvider),
  ),
);

/// Material theme for a set.
final themeDataForSetProvider = Provider.family<ThemeData, String?>(
  (ref, setId) => buildMaterialTheme(
    ref.watch(themeForSetProvider(setId)),
    ref.watch(uiPrefsForSetProvider(setId)),
  ),
);

/// UI preferences in effect on the tracks screen (active set's override
/// applied).
final activeUiPrefsProvider = Provider<UiPrefs>(
  (ref) => ref.watch(uiPrefsForSetProvider(ref.watch(activeSetProvider)?.id)),
);

/// Theme tokens in effect on the tracks screen (active set's override
/// applied).
final activeThemeProvider = Provider<TikkyTheme>(
  (ref) => ref.watch(themeForSetProvider(ref.watch(activeSetProvider)?.id)),
);
