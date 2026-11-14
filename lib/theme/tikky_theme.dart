import 'dart:convert';
import 'dart:ui' show Brightness, Color;

import 'package:flutter/foundation.dart' show TargetPlatform;

import '../core/domain/json_utils.dart';
import '../core/domain/track.dart';

/// The semantic colours of a theme.
final class TikkyColors {
  const TikkyColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.primary,
    required this.onPrimary,
    required this.text,
    required this.textMuted,
    required this.border,
    required this.danger,
    required this.success,
    required this.warning,
  });

  factory TikkyColors.fromJson(JsonMap json, TikkyColors fallback) =>
      TikkyColors(
        background: _color(json['background'], fallback.background),
        surface: _color(json['surface'], fallback.surface),
        surfaceAlt: _color(json['surfaceAlt'], fallback.surfaceAlt),
        primary: _color(json['primary'], fallback.primary),
        onPrimary: _color(json['onPrimary'], fallback.onPrimary),
        text: _color(json['text'], fallback.text),
        textMuted: _color(json['textMuted'], fallback.textMuted),
        border: _color(json['border'], fallback.border),
        danger: _color(json['danger'], fallback.danger),
        success: _color(json['success'], fallback.success),
        warning: _color(json['warning'], fallback.warning),
      );

  /// Screen background.
  final Color background;

  /// Lanes, cards, sheets, bars.
  final Color surface;

  /// Slightly set-off surface (pressed states, chips, progress track).
  final Color surfaceAlt;

  /// Accent: primary button, selection, progress.
  final Color primary;

  /// Content on top of [primary].
  final Color onPrimary;

  /// Main text and icons.
  final Color text;

  /// Secondary text (lane names, sub-lines).
  final Color textMuted;

  /// Hairlines and outlines.
  final Color border;

  /// Destructive actions, ringing state.
  final Color danger;
  final Color success;
  final Color warning;

  TikkyColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? primary,
    Color? onPrimary,
    Color? text,
    Color? textMuted,
    Color? border,
    Color? danger,
    Color? success,
    Color? warning,
  }) => TikkyColors(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceAlt: surfaceAlt ?? this.surfaceAlt,
    primary: primary ?? this.primary,
    onPrimary: onPrimary ?? this.onPrimary,
    text: text ?? this.text,
    textMuted: textMuted ?? this.textMuted,
    border: border ?? this.border,
    danger: danger ?? this.danger,
    success: success ?? this.success,
    warning: warning ?? this.warning,
  );

  JsonMap toJson() => {
    'background': colorToJson(background.toARGB32()),
    'surface': colorToJson(surface.toARGB32()),
    'surfaceAlt': colorToJson(surfaceAlt.toARGB32()),
    'primary': colorToJson(primary.toARGB32()),
    'onPrimary': colorToJson(onPrimary.toARGB32()),
    'text': colorToJson(text.toARGB32()),
    'textMuted': colorToJson(textMuted.toARGB32()),
    'border': colorToJson(border.toARGB32()),
    'danger': colorToJson(danger.toARGB32()),
    'success': colorToJson(success.toARGB32()),
    'warning': colorToJson(warning.toARGB32()),
  };

  List<int> get _values => [
    background.toARGB32(),
    surface.toARGB32(),
    surfaceAlt.toARGB32(),
    primary.toARGB32(),
    onPrimary.toARGB32(),
    text.toARGB32(),
    textMuted.toARGB32(),
    border.toARGB32(),
    danger.toARGB32(),
    success.toARGB32(),
    warning.toARGB32(),
  ];

  @override
  bool operator ==(Object other) =>
      other is TikkyColors && jsonListEquals(other._values, _values);

  @override
  int get hashCode => Object.hashAll(_values);
}

Color _color(Object? json, Color fallback) =>
    Color(jsonColor(json, fallback.toARGB32()));

/// How the large time / count digits are drawn.
final class DigitStyle {
  const DigitStyle({
    this.tabular = true,
    this.monospace = false,
    this.weight = 400,
  });

  factory DigitStyle.fromJson(JsonMap json) => DigitStyle(
    tabular: jsonBool(json['tabular'], true),
    monospace: jsonBool(json['monospace'], false),
    weight: _snapWeight(jsonInt(json['weight'], 400)),
  );

  /// Tabular figures: every digit has the same width, so time does not
  /// jitter while it runs.
  final bool tabular;

  /// Use the platform's monospace font for digits.
  final bool monospace;

  /// Font weight, 100..900 in steps of 100.
  final int weight;

  static int _snapWeight(int w) {
    final snapped = (w / 100).round() * 100;
    return snapped < 100 ? 100 : (snapped > 900 ? 900 : snapped);
  }

  DigitStyle copyWith({bool? tabular, bool? monospace, int? weight}) =>
      DigitStyle(
        tabular: tabular ?? this.tabular,
        monospace: monospace ?? this.monospace,
        weight: weight == null ? this.weight : _snapWeight(weight),
      );

  JsonMap toJson() => {
    'tabular': tabular,
    'monospace': monospace,
    'weight': weight,
  };

  @override
  bool operator ==(Object other) =>
      other is DigitStyle &&
      other.tabular == tabular &&
      other.monospace == monospace &&
      other.weight == weight;

  @override
  int get hashCode => Object.hash(tabular, monospace, weight);
}

/// Font choices. Only fonts that ship with the operating systems are used;
/// nothing is bundled or downloaded.
abstract final class TikkyFonts {
  /// The platform's default UI font.
  static const system = 'system';
  static const serif = 'serif';
  static const mono = 'mono';
  static const condensed = 'condensed';

  /// All selectable ids, in display order.
  static const choices = [system, serif, mono, condensed];

  /// The font family for a choice on [platform]; `null` = platform default.
  static String? family(String id, TargetPlatform platform) {
    final apple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    final windows = platform == TargetPlatform.windows;
    return switch (id) {
      serif => apple || windows ? 'Georgia' : 'serif',
      mono => apple ? 'Menlo' : (windows ? 'Consolas' : 'monospace'),
      condensed =>
        apple
            ? 'Avenir Next Condensed'
            : (windows ? 'Bahnschrift' : 'sans-serif-condensed'),
      _ => null,
    };
  }

  /// Fallback families tried after [family].
  static List<String> fallback(String id) => switch (id) {
    serif => const ['Georgia', 'Times New Roman', 'serif'],
    mono => const ['Menlo', 'Consolas', 'Courier New', 'monospace'],
    condensed => const ['Arial Narrow', 'sans-serif-condensed'],
    _ => const [],
  };
}

/// A complete, JSON-serialisable set of design tokens.
///
/// Widgets never read this directly: they use `context.tikky` (see
/// tokens.dart), which also folds in the UI preferences.
final class TikkyTheme {
  const TikkyTheme({
    required this.id,
    required this.name,
    required this.brightness,
    required this.colors,
    required this.trackPalette,
    this.fontFamily = TikkyFonts.system,
    this.digitStyle = const DigitStyle(),
    this.cornerRadius = 12,
    this.borderWidth = 1,
  });

  /// Value of the `type` field in exported theme files.
  static const String fileType = 'tikky_theme';

  /// Version of the theme JSON layout.
  static const int formatVersion = 1;

  /// Decodes a theme. Missing or malformed tokens fall back to [fallback]
  /// (pass the preset matching the brightness for best results).
  factory TikkyTheme.fromJson(JsonMap json, {required TikkyTheme fallback}) {
    final palette = <Color>[
      if (json['trackPalette'] case final List<Object?> list)
        for (final c in list)
          if (c is String || c is int) Color(jsonColor(c, 0xFF888888)),
    ];
    final font = jsonString(json['fontFamily'], fallback.fontFamily);
    return TikkyTheme(
      id: jsonString(json['id'], fallback.id),
      name: jsonString(json['name'], fallback.name),
      brightness: switch (json['brightness']) {
        'light' => Brightness.light,
        'dark' => Brightness.dark,
        _ => fallback.brightness,
      },
      colors: TikkyColors.fromJson(jsonMap(json['colors']), fallback.colors),
      trackPalette: List.unmodifiable(
        palette.isEmpty ? fallback.trackPalette : palette,
      ),
      fontFamily: TikkyFonts.choices.contains(font) ? font : TikkyFonts.system,
      digitStyle: json['digitStyle'] is Map
          ? DigitStyle.fromJson(jsonMap(json['digitStyle']))
          : fallback.digitStyle,
      cornerRadius: jsonDouble(
        json['cornerRadius'],
        fallback.cornerRadius,
      ).clamp(0, 40).toDouble(),
      borderWidth: jsonDouble(
        json['borderWidth'],
        fallback.borderWidth,
      ).clamp(0, 4).toDouble(),
    );
  }

  /// Parses an exported theme file. Returns `null` when [source] is not a
  /// theme file of this app. [fallbackFor] supplies the preset used for
  /// missing tokens, given the brightness found in the file.
  static TikkyTheme? tryParseFile(
    String source, {
    required TikkyTheme Function(Brightness brightness) fallbackFor,
  }) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final json = jsonMap(decoded);
    if (json['type'] != fileType) return null;
    final version = jsonInt(json['version'], 0);
    if (version < 1 || version > formatVersion) return null;
    final brightness = json['brightness'] == 'dark'
        ? Brightness.dark
        : Brightness.light;
    return TikkyTheme.fromJson(json, fallback: fallbackFor(brightness));
  }

  /// Unique id. Presets use `preset.*`, custom themes a UUID.
  final String id;
  final String name;
  final Brightness brightness;
  final TikkyColors colors;

  /// Colours tracks cycle through (`Track.colorIndex`). Never empty.
  final List<Color> trackPalette;

  /// One of [TikkyFonts.choices].
  final String fontFamily;
  final DigitStyle digitStyle;

  /// Base corner radius in logical pixels.
  final double cornerRadius;

  /// Hairline / outline width in logical pixels.
  final double borderWidth;

  bool get isDark => brightness == Brightness.dark;

  /// Palette colour for an index (wraps around, tolerates negatives).
  Color paletteColor(int index) {
    if (trackPalette.isEmpty) return colors.primary;
    return trackPalette[index % trackPalette.length];
  }

  /// The colour of a track: its custom colour, else its palette colour.
  Color trackColor(Track track) {
    final custom = track.customColor;
    return custom != null ? Color(custom) : paletteColor(track.colorIndex);
  }

  TikkyTheme copyWith({
    String? id,
    String? name,
    Brightness? brightness,
    TikkyColors? colors,
    List<Color>? trackPalette,
    String? fontFamily,
    DigitStyle? digitStyle,
    double? cornerRadius,
    double? borderWidth,
  }) => TikkyTheme(
    id: id ?? this.id,
    name: name ?? this.name,
    brightness: brightness ?? this.brightness,
    colors: colors ?? this.colors,
    trackPalette: trackPalette == null
        ? this.trackPalette
        : List.unmodifiable(trackPalette),
    fontFamily: fontFamily ?? this.fontFamily,
    digitStyle: digitStyle ?? this.digitStyle,
    cornerRadius: cornerRadius ?? this.cornerRadius,
    borderWidth: borderWidth ?? this.borderWidth,
  );

  JsonMap toJson() => {
    'type': fileType,
    'version': formatVersion,
    'id': id,
    'name': name,
    'brightness': isDark ? 'dark' : 'light',
    'colors': colors.toJson(),
    'trackPalette': [for (final c in trackPalette) colorToJson(c.toARGB32())],
    'fontFamily': fontFamily,
    'digitStyle': digitStyle.toJson(),
    'cornerRadius': cornerRadius,
    'borderWidth': borderWidth,
  };

  /// Pretty-printed JSON for a theme file.
  String toFileContent() => const JsonEncoder.withIndent('  ').convert(toJson());

  @override
  bool operator ==(Object other) =>
      other is TikkyTheme &&
      other.id == id &&
      other.name == name &&
      other.brightness == brightness &&
      other.colors == colors &&
      jsonListEquals(
        [for (final c in other.trackPalette) c.toARGB32()],
        [for (final c in trackPalette) c.toARGB32()],
      ) &&
      other.fontFamily == fontFamily &&
      other.digitStyle == digitStyle &&
      other.cornerRadius == cornerRadius &&
      other.borderWidth == borderWidth;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    brightness,
    colors,
    Object.hashAll([for (final c in trackPalette) c.toARGB32()]),
    fontFamily,
    digitStyle,
    cornerRadius,
    borderWidth,
  );

  @override
  String toString() => 'TikkyTheme($id, $name)';
}
