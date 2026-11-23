import 'dart:ui' show Color;

/// WCAG 2.x contrast ratio between two opaque colours (1.0 .. 21.0).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

/// The five roles one track colour plays (docs/design/DESIGNS.md, 2).
///
/// A track colour is never used as a text colour directly: text in the
/// colour of a track is always [ink].
final class TrackRoles {
  const TrackRoles({
    required this.solid,
    required this.tint,
    required this.strong,
    required this.ink,
    required this.on,
  });

  /// The colour itself: primary button, lamp, bars, a selected button.
  final Color solid;

  /// The surface of a lane or a pad button.
  final Color tint;

  /// Progress fill, secondary button, label buttons, a pressed button.
  final Color strong;

  /// Text in the track colour on [tint] and [strong].
  final Color ink;

  /// Text and icons on [solid].
  final Color on;

  @override
  bool operator ==(Object other) =>
      other is TrackRoles &&
      other.solid == solid &&
      other.tint == tint &&
      other.strong == strong &&
      other.ink == ink &&
      other.on == on;

  @override
  int get hashCode => Object.hash(solid, tint, strong, ink, on);

  @override
  String toString() => 'TrackRoles($solid)';
}

/// How much of the track colour is mixed over the background.
abstract final class TrackRoleMix {
  static const tintOnDark = 0.18;
  static const strongOnDark = 0.34;
  static const tintOnLight = 0.14;
  static const strongOnLight = 0.28;

  /// [TrackRoles.ink] reaches at least this against [TrackRoles.strong].
  static const inkContrast = 4.6;
}

const _black = Color(0xFF000000);
const _white = Color(0xFFFFFFFF);

/// Mixes [amount] (0..1) of [b] into [a], per channel in sRGB, opaque.
///
/// Works on 8-bit channels and rounds halves to the even value, so the
/// results equal the generated values in docs/design/tokens.json.
Color mixColors(Color a, Color b, double amount) {
  int channel(double from, double to) {
    final f = (from * 255).round();
    final t = (to * 255).round();
    final value = f + (t - f) * amount;
    final floor = value.floor();
    final rest = value - floor;
    final rounded = (rest - 0.5).abs() < 1e-9
        ? (floor.isEven ? floor : floor + 1)
        : value.round();
    return rounded.clamp(0, 255);
  }

  return Color.fromARGB(
    255,
    channel(a.r, b.r),
    channel(a.g, b.g),
    channel(a.b, b.b),
  );
}

/// Black or white, whichever reads better on [background].
Color readableOn(Color background) =>
    contrastRatio(_black, background) >= contrastRatio(_white, background)
    ? _black
    : _white;

/// The roles of the track colour [color] in a theme with [background].
/// Pure; works for palette colours and for custom colours alike.
TrackRoles trackRolesFor(
  Color color, {
  required Color background,
  required bool isDark,
}) {
  final solid = mixColors(color, color, 0); // opaque copy
  final tint = mixColors(
    background,
    solid,
    isDark ? TrackRoleMix.tintOnDark : TrackRoleMix.tintOnLight,
  );
  final strong = mixColors(
    background,
    solid,
    isDark ? TrackRoleMix.strongOnDark : TrackRoleMix.strongOnLight,
  );
  // Towards white on dark themes, towards black on light ones, in steps of
  // one percent until the text is readable on the stronger surface.
  final target = isDark ? _white : _black;
  var ink = solid;
  for (var step = 1; step <= 100; step++) {
    if (contrastRatio(ink, strong) >= TrackRoleMix.inkContrast) break;
    ink = mixColors(solid, target, step / 100);
  }
  return TrackRoles(
    solid: solid,
    tint: tint,
    strong: strong,
    ink: ink,
    on: readableOn(solid),
  );
}
