import 'dart:ui' show Brightness, Color;

import '../core/domain/json_utils.dart';
import '../core/domain/track_set.dart';
import 'theme_presets.dart';
import 'tikky_theme.dart';
import 'ui_prefs.dart';

/// Which theme the app uses. Immutable, JSON (de)serialisable.
final class ThemeSettings {
  const ThemeSettings({
    this.followSystem = true,
    this.themeId = ThemePresets.lightId,
    this.lightThemeId = ThemePresets.lightId,
    this.darkThemeId = ThemePresets.darkId,
    this.useDynamicColor = false,
  });

  factory ThemeSettings.fromJson(JsonMap json) => ThemeSettings(
    followSystem: jsonBool(json['followSystem'], true),
    themeId: jsonString(json['themeId'], ThemePresets.lightId),
    lightThemeId: jsonString(json['lightThemeId'], ThemePresets.lightId),
    darkThemeId: jsonString(json['darkThemeId'], ThemePresets.darkId),
    useDynamicColor: jsonBool(json['useDynamicColor'], false),
  );

  static const defaults = ThemeSettings();

  /// "System" mode: follow the OS light / dark setting, using
  /// [lightThemeId] / [darkThemeId].
  final bool followSystem;

  /// The fixed theme used when [followSystem] is off.
  final String themeId;

  /// Theme used in system mode while the OS is light.
  final String lightThemeId;

  /// Theme used in system mode while the OS is dark.
  final String darkThemeId;

  /// Replace the accent by the Material You colour where available
  /// (Android 12+).
  final bool useDynamicColor;

  ThemeSettings copyWith({
    bool? followSystem,
    String? themeId,
    String? lightThemeId,
    String? darkThemeId,
    bool? useDynamicColor,
  }) => ThemeSettings(
    followSystem: followSystem ?? this.followSystem,
    themeId: themeId ?? this.themeId,
    lightThemeId: lightThemeId ?? this.lightThemeId,
    darkThemeId: darkThemeId ?? this.darkThemeId,
    useDynamicColor: useDynamicColor ?? this.useDynamicColor,
  );

  JsonMap toJson() => {
    'followSystem': followSystem,
    'themeId': themeId,
    'lightThemeId': lightThemeId,
    'darkThemeId': darkThemeId,
    'useDynamicColor': useDynamicColor,
  };

  @override
  bool operator ==(Object other) =>
      other is ThemeSettings &&
      other.followSystem == followSystem &&
      other.themeId == themeId &&
      other.lightThemeId == lightThemeId &&
      other.darkThemeId == darkThemeId &&
      other.useDynamicColor == useDynamicColor;

  @override
  int get hashCode => Object.hash(
    followSystem,
    themeId,
    lightThemeId,
    darkThemeId,
    useDynamicColor,
  );
}

/// Accent colours supplied by the OS (Material You).
final class DynamicPalette {
  const DynamicPalette({
    required this.lightPrimary,
    required this.lightOnPrimary,
    required this.darkPrimary,
    required this.darkOnPrimary,
  });

  final Color lightPrimary;
  final Color lightOnPrimary;
  final Color darkPrimary;
  final Color darkOnPrimary;
}

/// Finds a theme by id among [themes]; `null` if it does not exist.
TikkyTheme? findTheme(Iterable<TikkyTheme> themes, String? id) {
  if (id == null) return null;
  for (final t in themes) {
    if (t.id == id) return t;
  }
  return null;
}

/// Resolves the app-wide theme. Pure.
///
/// Unknown ids (e.g. a deleted custom theme) fall back to the preset that
/// matches the wanted brightness. [dynamicPalette] is applied only when
/// [ThemeSettings.useDynamicColor] is on.
TikkyTheme resolveAppTheme({
  required ThemeSettings settings,
  required Iterable<TikkyTheme> themes,
  required Brightness platformBrightness,
  DynamicPalette? dynamicPalette,
}) {
  final TikkyTheme theme;
  if (settings.followSystem) {
    final dark = platformBrightness == Brightness.dark;
    theme =
        findTheme(
          themes,
          dark ? settings.darkThemeId : settings.lightThemeId,
        ) ??
        ThemePresets.forBrightness(platformBrightness);
  } else {
    theme = findTheme(themes, settings.themeId) ?? ThemePresets.light;
  }
  if (!settings.useDynamicColor || dynamicPalette == null) return theme;
  return applyDynamicPalette(theme, dynamicPalette);
}

/// Replaces the accent of [theme] by the OS palette.
TikkyTheme applyDynamicPalette(TikkyTheme theme, DynamicPalette palette) =>
    theme.copyWith(
      colors: theme.colors.copyWith(
        primary: theme.isDark ? palette.darkPrimary : palette.lightPrimary,
        onPrimary: theme.isDark
            ? palette.darkOnPrimary
            : palette.lightOnPrimary,
      ),
    );

/// The theme for a set: its own `themeId` if it names an existing theme,
/// otherwise [appTheme]. Pure.
TikkyTheme resolveSetTheme({
  required TrackSet? set,
  required Iterable<TikkyTheme> themes,
  required TikkyTheme appTheme,
}) => findTheme(themes, set?.themeId) ?? appTheme;

/// The UI preferences for a set: [appPrefs] with the set's partial override
/// applied. Pure.
UiPrefs resolveSetPrefs({required TrackSet? set, required UiPrefs appPrefs}) =>
    appPrefs.applyOverride(set?.uiPrefsOverride);
