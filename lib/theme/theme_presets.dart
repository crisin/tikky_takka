import 'dart:ui' show Brightness, Color;

import '../l10n/strings.dart';
import 'tikky_theme.dart';

/// The built-in themes. Presets are read-only: the editor duplicates them
/// into custom themes.
abstract final class ThemePresets {
  static const lightId = 'preset.light';
  static const darkId = 'preset.dark';
  static const blackId = 'preset.black';

  /// Track colours tuned for light backgrounds.
  static const List<Color> paletteOnLight = [
    Color(0xFF2F6FED), // blue
    Color(0xFFE5484D), // red
    Color(0xFF2E9E6B), // green
    Color(0xFFE38B14), // orange
    Color(0xFF8E4EC6), // violet
    Color(0xFF0E9AA7), // teal
    Color(0xFFD6409F), // pink
    Color(0xFF8D6E3F), // brown
    Color(0xFF6E7781), // slate
    Color(0xFFB7A200), // olive
  ];

  /// Track colours tuned for dark backgrounds.
  static const List<Color> paletteOnDark = [
    Color(0xFF6EA8FF),
    Color(0xFFFF7A7F),
    Color(0xFF5BD19B),
    Color(0xFFFFB454),
    Color(0xFFBF8CF2),
    Color(0xFF4FD1DC),
    Color(0xFFF27CC4),
    Color(0xFFC9A46B),
    Color(0xFF9AA5B1),
    Color(0xFFE2CF45),
  ];

  /// "Hell".
  static const light = TikkyTheme(
    id: lightId,
    name: Strings.themeLight,
    brightness: Brightness.light,
    colors: TikkyColors(
      background: Color(0xFFF6F6F4),
      surface: Color(0xFFFFFFFF),
      surfaceAlt: Color(0xFFEEEEEB),
      primary: Color(0xFF1F1F1D),
      onPrimary: Color(0xFFFFFFFF),
      text: Color(0xFF1A1A18),
      textMuted: Color(0xFF6F6F6A),
      border: Color(0xFFDEDEDA),
      danger: Color(0xFFD13438),
      success: Color(0xFF2E8B57),
      warning: Color(0xFFC77700),
    ),
    trackPalette: paletteOnLight,
  );

  /// "Dunkel".
  static const dark = TikkyTheme(
    id: darkId,
    name: Strings.themeDark,
    brightness: Brightness.dark,
    colors: TikkyColors(
      background: Color(0xFF151517),
      surface: Color(0xFF1E1E21),
      surfaceAlt: Color(0xFF29292D),
      primary: Color(0xFFF2F2EE),
      onPrimary: Color(0xFF151517),
      text: Color(0xFFF0F0EC),
      textMuted: Color(0xFF9B9BA1),
      border: Color(0xFF34343A),
      danger: Color(0xFFFF6B6E),
      success: Color(0xFF5BD19B),
      warning: Color(0xFFFFB454),
    ),
    trackPalette: paletteOnDark,
  );

  /// "Schwarz" - true black for OLED displays.
  static const black = TikkyTheme(
    id: blackId,
    name: Strings.themeBlack,
    brightness: Brightness.dark,
    colors: TikkyColors(
      background: Color(0xFF000000),
      surface: Color(0xFF000000),
      surfaceAlt: Color(0xFF141416),
      primary: Color(0xFFFFFFFF),
      onPrimary: Color(0xFF000000),
      text: Color(0xFFF2F2F2),
      textMuted: Color(0xFF8A8A90),
      border: Color(0xFF26262A),
      danger: Color(0xFFFF6B6E),
      success: Color(0xFF5BD19B),
      warning: Color(0xFFFFB454),
    ),
    trackPalette: paletteOnDark,
  );

  /// All presets in display order.
  static const List<TikkyTheme> all = [light, dark, black];

  static bool isPresetId(String id) =>
      id == lightId || id == darkId || id == blackId;

  /// The preset with [id], or `null`.
  static TikkyTheme? byId(String? id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// The default preset for a brightness (base for custom / imported
  /// themes).
  static TikkyTheme forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}
