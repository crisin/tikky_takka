import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/domain/track.dart';
import 'theme_presets.dart';
import 'tikky_theme.dart';
import 'ui_prefs.dart';

/// Spacing scale (logical pixels), already adjusted for the density
/// preference.
@immutable
final class TikkySpacing {
  const TikkySpacing._(this._factor);

  final double _factor;

  double get xxs => 2 * _factor;
  double get xs => 4 * _factor;
  double get sm => 8 * _factor;
  double get md => 12 * _factor;
  double get lg => 16 * _factor;
  double get xl => 24 * _factor;
  double get xxl => 32 * _factor;
  double get xxxl => 48 * _factor;

  /// Standard horizontal page padding.
  double get page => 16 * _factor;
}

/// Sizes of recurring elements (logical pixels), already adjusted for the
/// density, digit-size and button-size preferences.
@immutable
final class TikkySizes {
  const TikkySizes._(this._theme, this._prefs);

  final TikkyTheme _theme;
  final UiPrefs _prefs;

  double get _density => switch (_prefs.density) {
    UiDensity.compact => 0.85,
    UiDensity.normal => 1,
    UiDensity.roomy => 1.2,
  };

  /// Hairline / outline width.
  double get hairline => _theme.borderWidth;

  /// Width of the colour bar at the leading edge of a lane.
  double get colorBar => 4;

  /// Height of the thin progress bar of countdown / interval lanes.
  double get progressBar => 3;

  /// Minimum height of a lane row.
  double get laneMinHeight => 76 * _density;

  /// Minimum width of a lane tile / grid column on wide layouts.
  double get tileMinWidth => 300;

  /// Minimum height of a lane tile.
  double get tileMinHeight => 148 * _density;

  /// Diameter of the round primary button of a lane.
  double get primaryButton => 56 * _prefs.buttonScale;

  /// Size of the small secondary icon buttons of a lane.
  double get secondaryButton => 40 * _prefs.buttonScale;

  /// Extra large tap target (protocol entry sheet, usable while impaired).
  double get bigTapTarget => 64 * _prefs.buttonScale;

  /// Smallest allowed tap target.
  double get minTapTarget => 48;

  /// Smallest height of a button of the tap pad ("Tippfeld").
  double get padButtonMinHeight => 72 * _prefs.buttonScale;

  /// Smallest width of a button of the tap pad.
  double get padButtonMinWidth => 104 * _prefs.buttonScale;

  /// Fixed height of the undo bar at the top of the tap pad.
  double get undoBarHeight => 56;

  double get iconSm => 18;
  double get iconMd => 22;
  double get iconLg => 28;
  double get iconXl => 44;

  /// Icon inside the primary button.
  double get primaryIcon => 28 * _prefs.buttonScale;

  /// Icon inside a secondary button.
  double get secondaryIcon => 20 * _prefs.buttonScale;

  /// Font size of the large time / count of a lane.
  double get digitsLarge => 38 * _prefs.digitScale;

  /// Font size of secondary figures (lap time, per-label counts).
  double get digitsMedium => 22 * _prefs.digitScale;

  /// Font size of small figures inside sub-lines and lists.
  double get digitsSmall => 15 * _prefs.digitScale;

  /// Diameter of colour swatches (palette, person / substance dots).
  double get swatch => 28;
  double get dot => 10;

  /// From this width on the app uses the navigation rail and a grid.
  double get wideBreakpoint => TikkyTokens.wideBreakpoint;

  /// Maximum width of single-column content on wide screens.
  double get maxContentWidth => 720;

  /// Maximum width of bottom sheets and dialogs on wide screens.
  double get sheetMaxWidth => 560;
}

/// Text styles. Colours and font family are already applied.
@immutable
final class TikkyTextStyles {
  const TikkyTextStyles._({
    required this.digitsLarge,
    required this.digitsMedium,
    required this.digitsSmall,
    required this.laneTitle,
    required this.subLine,
    required this.title,
    required this.headline,
    required this.body,
    required this.bodyMuted,
    required this.label,
    required this.caption,
    required this.button,
  });

  /// The large time / count of a lane.
  final TextStyle digitsLarge;

  /// Secondary figures (lap time, per-label counts).
  final TextStyle digitsMedium;

  /// Small figures in sub-lines and lists.
  final TextStyle digitsSmall;

  /// Small muted "name + mode" line of a lane.
  final TextStyle laneTitle;

  /// Muted sub-line of a lane (lap info, status).
  final TextStyle subLine;

  /// Screen and sheet titles.
  final TextStyle title;

  /// Section headings, day headers.
  final TextStyle headline;
  final TextStyle body;
  final TextStyle bodyMuted;

  /// Form labels, chips, list tile titles.
  final TextStyle label;

  /// Smallest text (footnotes, hints).
  final TextStyle caption;
  final TextStyle button;
}

/// Measures and opacities of the strip timeline ("Streifen"): time runs
/// left to right, one lane per track. Lane sizes follow the density
/// preference.
@immutable
final class TikkyStripTokens {
  const TikkyStripTokens._(this._density);

  final double _density;

  /// Height of the lane of a track.
  double get lane => 44 * _density;

  /// Height of a sub-lane (a person of a protocol, a label of a counter).
  double get subLane => 32 * _density;

  /// Height of the time axis above the lanes.
  double get axis => 30;

  /// Thickness of a session bar in a lane / in a sub-lane.
  double get bar => 20 * _density;
  double get subBar => 12 * _density;

  /// Diameter of an event marker.
  double get marker => 11;

  /// How far around a marker a tap or the pointer still counts.
  double get hitSlop => 14;

  /// Markers closer than this (centre to centre) become a cluster.
  double get markerGap => 16;

  /// Height and smallest width of the pill of a cluster.
  double get clusterHeight => 20;
  double get clusterMinWidth => 26;

  /// Space between a marker and its text, the least room a text needs
  /// and the most it takes.
  double get labelGap => 4;
  double get labelMinWidth => 24;
  double get labelMaxWidth => 140;

  /// Padding around an axis label when choosing the tick spacing.
  double get tickPadding => 28;

  /// Width of the fixed track names: wide, and on a phone.
  double get gutter => 184;
  double get gutterNarrow => 96;

  /// Below this width of the whole strip the narrow gutter is used.
  double get narrowBreakpoint => 560;

  /// Indent of the name of a sub-lane.
  double get subIndent => 14;

  /// Width of the "now" line and of a lap tick.
  double get nowLine => 1.5;

  /// Distance of the hatch lines of a paused stretch.
  double get hatchSpacing => 6;

  /// Largest width of the hover text.
  double get tooltipMaxWidth => 260;

  /// Opacity of a session bar, a paused stretch, the rest phases of an
  /// interval, the thin bar of a sub-lane, and a lockout band.
  double get barOpacity => 0.42;
  double get pauseOpacity => 0.14;
  double get phaseAltOpacity => 0.24;
  double get subBarOpacity => 0.22;
  double get bandOpacity => 0.18;

  /// Opacity of the vertical gridlines.
  double get gridOpacity => 0.6;

  /// Where the "now" line sits while it is followed (share of the width).
  double get followAnchor => 0.82;

  /// Free room on both sides of "Alles zeigen" (share of the range).
  double get fitPadding => 0.06;

  /// One step of the zoom buttons and keys; share of the width an arrow
  /// key moves; wheel distance that doubles the zoom.
  double get zoomStep => 1.6;
  double get keyPanShare => 0.2;
  double get wheelZoomDistance => 240;

  /// The closest zoom shows this many milliseconds across the width.
  int get minSpanMs => 10 * 1000;

  /// "Alles zeigen" never shows less than this.
  int get fitMinSpanMs => 60 * 1000;

  /// Zooming out always reaches at least this.
  int get maxSpanFloorMs => 10 * 60 * 1000;
}

/// Radii derived from the theme's corner radius.
@immutable
final class TikkyRadii {
  const TikkyRadii._(this._base);

  final double _base;

  double get sm => _base * 0.5;
  double get md => _base;
  double get lg => _base * 1.5;

  BorderRadius get smAll => BorderRadius.circular(sm);
  BorderRadius get mdAll => BorderRadius.circular(md);
  BorderRadius get lgAll => BorderRadius.circular(lg);

  /// Rounded top corners (bottom sheets).
  BorderRadius get sheetTop => BorderRadius.vertical(top: Radius.circular(lg));
}

/// Animation timings.
@immutable
final class TikkyMotion {
  const TikkyMotion._();

  Duration get fast => const Duration(milliseconds: 120);
  Duration get normal => const Duration(milliseconds: 200);
  Duration get slow => const Duration(milliseconds: 320);
  Curve get curve => Curves.easeOutCubic;

  /// Blink period of a ringing lane.
  Duration get ringBlink => const Duration(milliseconds: 600);

  /// How long the "Rückgängig" snackbar stays.
  Duration get undoWindow => const Duration(seconds: 5);

  /// How long an inline undo bar (tap pad, protocol lane) offers
  /// "Rückgängig" unless another action replaces it first.
  Duration get inlineUndoWindow => const Duration(seconds: 10);

  /// How long a button of the tap pad lights up after a tap.
  Duration get tapFlash => const Duration(milliseconds: 180);

  /// How long a one-tap protocol entry stays marked on its button before
  /// the lane goes back to the person choice. Taps are ignored meanwhile.
  Duration get captureConfirm => const Duration(milliseconds: 900);
}

/// All design tokens, exposed to widgets as a [ThemeExtension].
///
/// Feature widgets take EVERY colour, size, radius, font and spacing from
/// here (`context.tikky`) - never from literals:
///
/// ```dart
/// final t = context.tikky;
/// Container(
///   padding: EdgeInsets.all(t.space.md),
///   decoration: t.surfaceDecoration(),
///   child: Text('12:34', style: t.text.digitsLarge),
/// );
/// ```
@immutable
class TikkyTokens extends ThemeExtension<TikkyTokens> {
  TikkyTokens({
    required this.theme,
    required this.prefs,
    TargetPlatform? platform,
  }) : platform = platform ?? defaultTargetPlatform,
       space = TikkySpacing._(switch (prefs.density) {
         UiDensity.compact => 0.8,
         UiDensity.normal => 1,
         UiDensity.roomy => 1.25,
       }),
       sizes = TikkySizes._(theme, prefs),
       radii = TikkyRadii._(theme.cornerRadius),
       strip = TikkyStripTokens._(switch (prefs.density) {
         UiDensity.compact => 0.85,
         UiDensity.normal => 1,
         UiDensity.roomy => 1.2,
       }),
       motion = const TikkyMotion._() {
    text = _buildText();
  }

  /// Tokens used when no theme is installed (tests, previews).
  static final TikkyTokens fallback = TikkyTokens(
    theme: ThemePresets.light,
    prefs: UiPrefs.defaults,
  );

  /// Width from which the wide layout (rail + grid) is used.
  static const double wideBreakpoint = 720;

  final TikkyTheme theme;
  final UiPrefs prefs;
  final TargetPlatform platform;

  final TikkySpacing space;
  final TikkySizes sizes;
  final TikkyRadii radii;
  final TikkyMotion motion;

  /// The strip timeline.
  final TikkyStripTokens strip;
  late final TikkyTextStyles text;

  /// Semantic colours.
  TikkyColors get colors => theme.colors;

  bool get isDark => theme.isDark;

  /// The colour of a track (custom colour or palette entry).
  Color trackColor(Track track) => theme.trackColor(track);

  /// Colour for a palette index (wraps around).
  Color paletteColor(int index) => theme.paletteColor(index);

  /// Readable content colour (text or inverse) on top of [background].
  Color onColor(Color background) => background.computeLuminance() > 0.5
      ? const Color(0xFF000000)
      : const Color(0xFFFFFFFF);

  /// A hairline in the border colour.
  BorderSide get hairline => BorderSide(
    color: colors.border,
    width: sizes.hairline,
    style: sizes.hairline <= 0 ? BorderStyle.none : BorderStyle.solid,
  );

  /// Flat surface with a hairline outline and the theme radius: lanes,
  /// cards, tiles.
  BoxDecoration surfaceDecoration({Color? color, bool outlined = true}) =>
      BoxDecoration(
        color: color ?? colors.surface,
        borderRadius: radii.mdAll,
        border: outlined && sizes.hairline > 0
            ? Border.all(color: colors.border, width: sizes.hairline)
            : null,
      );

  /// Font family for regular text; `null` = platform default.
  String? get fontFamily => TikkyFonts.family(theme.fontFamily, platform);

  List<String> get fontFamilyFallback => TikkyFonts.fallback(theme.fontFamily);

  TikkyTextStyles _buildText() {
    final family = fontFamily;
    final fallbackFamilies = fontFamilyFallback;
    TextStyle base(
      double size,
      FontWeight weight,
      Color color, {
      double? height,
      double? letterSpacing,
    }) => TextStyle(
      fontFamily: family,
      fontFamilyFallback: fallbackFamilies.isEmpty ? null : fallbackFamilies,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );

    final digit = theme.digitStyle;
    final digitFamily = digit.monospace
        ? TikkyFonts.family(TikkyFonts.mono, platform)
        : family;
    final digitFallback = digit.monospace
        ? TikkyFonts.fallback(TikkyFonts.mono)
        : fallbackFamilies;
    final digitWeight =
        FontWeight.values[(digit.weight ~/ 100 - 1).clamp(0, 8)];
    TextStyle digits(double size, Color color) => TextStyle(
      fontFamily: digitFamily,
      fontFamilyFallback: digitFallback.isEmpty ? null : digitFallback,
      fontSize: size,
      fontWeight: digitWeight,
      color: color,
      height: 1.1,
      fontFeatures: digit.tabular ? const [FontFeature.tabularFigures()] : null,
    );

    return TikkyTextStyles._(
      digitsLarge: digits(sizes.digitsLarge, colors.text),
      digitsMedium: digits(sizes.digitsMedium, colors.text),
      digitsSmall: digits(sizes.digitsSmall, colors.textMuted),
      laneTitle: base(13, FontWeight.w500, colors.textMuted, height: 1.2),
      subLine: base(13, FontWeight.w400, colors.textMuted, height: 1.25),
      title: base(20, FontWeight.w600, colors.text, height: 1.2),
      headline: base(16, FontWeight.w600, colors.text, height: 1.25),
      body: base(15, FontWeight.w400, colors.text, height: 1.35),
      bodyMuted: base(15, FontWeight.w400, colors.textMuted, height: 1.35),
      label: base(14, FontWeight.w500, colors.text, height: 1.25),
      caption: base(12, FontWeight.w400, colors.textMuted, height: 1.3),
      button: base(15, FontWeight.w600, colors.text, height: 1.2),
    );
  }

  @override
  TikkyTokens copyWith({
    TikkyTheme? theme,
    UiPrefs? prefs,
    TargetPlatform? platform,
  }) => TikkyTokens(
    theme: theme ?? this.theme,
    prefs: prefs ?? this.prefs,
    platform: platform ?? this.platform,
  );

  /// Tokens are discrete: switching themes snaps at the midpoint.
  @override
  TikkyTokens lerp(covariant TikkyTokens? other, double t) =>
      other == null || t < 0.5 ? this : other;

  @override
  bool operator ==(Object other) =>
      other is TikkyTokens &&
      other.theme == theme &&
      other.prefs == prefs &&
      other.platform == platform;

  @override
  int get hashCode => Object.hash(theme, prefs, platform);
}

/// `context.tikky` - the design tokens of the surrounding theme.
extension TikkyContext on BuildContext {
  TikkyTokens get tikky =>
      Theme.of(this).extension<TikkyTokens>() ?? TikkyTokens.fallback;
}
