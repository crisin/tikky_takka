import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/domain/track.dart';
import 'bundled_fonts.dart';
import 'theme_presets.dart';
import 'tikky_theme.dart';
import 'track_roles.dart';
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

  /// Horizontal page padding of the lane list and the tap pad.
  double get pageLanes => 12 * _factor;
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
  double get laneMinHeight => 84 * _density;

  /// Height of a lane that shows its surface (running, paused, ringing,
  /// due) and of one that is ready (outline only).
  double get laneHeightActive => 101 * _density;
  double get laneHeightIdle => 66 * _density;

  /// Diameter of the lamp in the head line of a lane.
  double get lamp => 8;

  /// Height of the bottom pill and diameter of the plus button beside it.
  double get navPill => 56;

  /// Below this window height (a phone held sideways) the head of the
  /// tracks screen is compact: a smaller title, no count below it.
  double get compactHeight => 560;

  /// Minimum width of a lane tile / grid column on wide layouts.
  double get tileMinWidth => 300;

  /// Minimum height of a lane tile.
  double get tileMinHeight => 148 * _density;

  /// Diameter of the round primary button of a lane.
  double get primaryButton => 60 * _prefs.buttonScale;

  /// The primary button of a ready lane (outline only).
  double get primaryButtonIdle => 48 * _prefs.buttonScale;

  /// Diameter of the secondary button of a lane.
  double get secondaryButton => 48 * _prefs.buttonScale;

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

  /// Thickness of the time bar at the lower edge of an undo bar.
  double get undoTimeBar => 3;

  /// Outline of a ready lane, a paused one and a due one.
  double get laneOutlineIdle => 1;
  double get laneOutlinePaused => 1.5;
  double get laneOutlineDue => 2;

  /// Outline of the primary button of a ready lane, of the lamp of a
  /// paused / ready lane and of a secondary button on a ringing lane.
  double get laneButtonOutline => 1.5;

  /// The widest the time of a ready lane gets before it shrinks.
  double get laneDigitsIdleMax => 120;

  /// Height of a round segment of an interval lane.
  double get laneSegment => 8;

  /// Height of a person tile in a protocol lane, diameter of its initial,
  /// and the width below which the tiles go one per row.
  double get personTile => 60 * _prefs.buttonScale;
  double get personAvatar => 32;
  double get personTileMinWidth => 140;

  /// The initial of a person on the tap pad and in the head of its page.
  double get padAvatar => 40;

  /// Height of a field on the page "Anderes" of the tap pad.
  double get padOtherField => 88 * _prefs.buttonScale;

  /// The bar under "Abstand: noch ..." on a field of the tap pad.
  double get padLockoutBar => 4;

  /// Outline of a field of the tap pad that was just tapped.
  double get padHitOutline => 2;

  /// Outline of a ready field and of "Anderes" on the tap pad.
  double get padOutline => 1.5;

  /// Dash and gap of the outline of "Anderes".
  double get padDash => 6;

  /// Height of a folded row of the entry sheet (Wer, Was, Notiz).
  double get sheetRow => 56;

  /// Width of a step button of the time in the entry sheet (-5, +1, ...).
  double get timeStep => 52;

  double get iconSm => 20;
  double get iconMd => 24;
  double get iconLg => 28;
  double get iconXl => 44;

  /// Icon inside the primary button.
  double get primaryIcon => 28 * _prefs.buttonScale;

  /// Icon inside a secondary button.
  double get secondaryIcon => 20 * _prefs.buttonScale;

  /// Font size of the large time / count of a lane.
  double get digitsLarge => 32 * _prefs.digitScale;

  /// Font size of the time on the focus page.
  double get digitsFocus => 56 * _prefs.digitScale;

  /// Font size of secondary figures (lap time, per-label counts, the time
  /// of a ready lane and on pad buttons).
  double get digitsMedium => 22 * _prefs.digitScale;

  /// Font size of small figures inside sub-lines and lists.
  double get digitsSmall => 17 * _prefs.digitScale;

  /// Diameter of colour swatches (palette, person / substance dots).
  double get swatch => 28;
  double get dot => 12;

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
    required this.laneName,
    required this.laneMode,
    required this.laneSub,
    required this.laneDigits,
    required this.laneDigitsIdle,
    required this.laneLabelCount,
    required this.laneLabel,
    required this.labelStrong,
    required this.padName,
    required this.padNameLarge,
    required this.padCount,
    required this.padHint,
    required this.padDigits,
    required this.padInitial,
    required this.sheetTitle,
    required this.chip,
    required this.rowValue,
    required this.laneButton,
    required this.stripName,
    required this.stripThing,
    required this.stripDigits,
    required this.stripWord,
    required this.cardDigits,
    required this.cardNote,
    required this.navLabel,
    required this.pageTitle,
    required this.pageTitleCompact,
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

  /// Head line of a lane: the name, the mode next to it, the line under
  /// the digits. Coloured by the lane (`roles(..).ink`).
  final TextStyle laneName;
  final TextStyle laneMode;
  final TextStyle laneSub;

  /// The time / count of an active lane and of a ready one.
  final TextStyle laneDigits;
  final TextStyle laneDigitsIdle;

  /// The count on a label button of a counter, and its label.
  final TextStyle laneLabelCount;
  final TextStyle laneLabel;

  /// A pill button, the first line of an undo bar.
  final TextStyle labelStrong;

  /// The name on a field of the tap pad; larger on the page "Was?".
  final TextStyle padName;
  final TextStyle padNameLarge;

  /// "×3" on a field of the tap pad, and its small line. Coloured by the
  /// field (`roles(..).ink`).
  final TextStyle padCount;
  final TextStyle padHint;

  /// The time on a field of a stopwatch or timer.
  final TextStyle padDigits;

  /// The initial of a person on the tap pad.
  final TextStyle padInitial;

  /// The title of the entry sheet ("Wasser · Krille").
  final TextStyle sheetTitle;

  /// A choice chip of a sheet ("Jetzt", "0,5 l").
  final TextStyle chip;

  /// The value of a folded row of a sheet ("Wer  Krille").
  final TextStyle rowValue;

  /// Text on a round button of a lane ("+1′", "+10′").
  final TextStyle laneButton;

  /// The strip: the name of a lane, the name of a thing, a live value
  /// next to a name, and the word below a marker.
  final TextStyle stripName;
  final TextStyle stripThing;
  final TextStyle stripDigits;
  final TextStyle stripWord;

  /// A person card above the strip: the time since, and the line below.
  final TextStyle cardDigits;
  final TextStyle cardNote;

  /// An entry of the navigation pill.
  final TextStyle navLabel;

  /// The large title at the top of the tracks screen (the set's name).
  final TextStyle pageTitle;
  final TextStyle pageTitleCompact;

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

  /// The line above every lane with its name (and its live value).
  double get label => 16 * _density;

  /// Height of the lane of a track: its name, then a compact bar.
  double get lane => 32 * _density;

  /// Height of the lane of a thing (a substance of a person, a label of a
  /// counter): its name, then the line with the markers.
  double get subLane => 40 * _density;

  /// The name line of an open person, and of a folded one with all its
  /// things on one line and the word below every marker.
  double get personHead => 20 * _density;
  double get personFolded => 68 * _density;

  /// The word below a marker of a folded person.
  double get word => 16;

  /// Height of the time axis above the lanes.
  double get axis => 30;

  /// Thickness of a session bar in a lane / the line of a thing.
  double get bar => 12 * _density;
  double get subBar => 2;

  /// Diameter of the marker of an entry, and of an event of a track.
  double get marker => 16;
  double get trackMarker => 10;

  /// How far around a marker a tap or the pointer still counts: a tap
  /// area of 48 x 48.
  double get hitSlop => 24;

  /// Markers closer than this (centre to centre) become a cluster.
  double get markerGap => 18;

  /// Height and smallest width of the pill of a cluster.
  double get clusterHeight => 20;
  double get clusterMinWidth => 26;

  /// Space between a marker and its text, the least room a text needs
  /// and the most it takes.
  double get labelGap => 4;
  double get labelMinWidth => 24;
  double get labelMaxWidth => 140;

  /// The time between two markers is written from this much room on.
  double get gapText => 56;

  /// Height of the band in the warning colour while a lockout runs.
  double get warnBand => 22;

  /// Padding around an axis label when choosing the tick spacing.
  double get tickPadding => 28;

  /// Space at the left of a name; a thing's name is indented further.
  double get nameInset => 12;
  double get subIndent => 16;

  /// The colour dot before the name of a track or a person, and the
  /// space after it.
  double get nameDot => 8;
  double get nameGap => 6;

  /// The initial of a person on a card above the strip; below this
  /// height of the timeline the cards are left out.
  double get cardAvatar => 28;
  double get cardsMinHeight => 320;

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
  double get subBarOpacity => 0.5;
  double get bandOpacity => 0.18;

  /// Opacity of the vertical gridlines.
  double get gridOpacity => 0.6;

  /// Where the "now" line sits while it is followed (share of the width).
  double get followAnchor => 0.85;

  /// A stretch without any event of at least [foldMinGapMs] is drawn
  /// [fold] pixels wide; never the last [foldKeepRecentMs] before "now";
  /// [foldPadMs] stay open next to the events on both sides.
  double get fold => 24;
  int get foldMinGapMs => 20 * 60 * 1000;
  int get foldKeepRecentMs => 10 * 60 * 1000;
  int get foldPadMs => 2 * 60 * 1000;

  /// Distance of the hatch lines of a fold.
  double get foldHatchSpacing => 6;

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

  // Radii by role ("Pult"). With the default base of 12 these are the
  // drawn 20 / 22 / 14 / 28; a theme with square corners keeps them square.

  /// A lane.
  double get lane => _base * 20 / 12;

  /// A pad button, a card.
  double get pad => _base * 22 / 12;

  /// Label buttons, tiles inside a lane, input fields.
  double get small => _base * 14 / 12;

  /// The top corners of a sheet.
  double get sheet => _base * 28 / 12;

  /// Pills and round buttons; square when the theme has no rounding.
  double get pill => _base <= 0 ? 0 : 999;

  BorderRadius get laneAll => BorderRadius.circular(lane);
  BorderRadius get padAll => BorderRadius.circular(pad);
  BorderRadius get smallAll => BorderRadius.circular(small);
  BorderRadius get pillAll => BorderRadius.circular(pill);
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

  /// Half a period of the lamp of a running lane, and how far it dims.
  Duration get lampPulse => const Duration(seconds: 1);
  double get lampDim => 0.35;

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

  final Map<int, TrackRoles> _roles = {};

  /// The five roles of a track colour in this theme (surface, fill, text,
  /// ...). Text in a track colour is always `roles(c).ink`, never `c`.
  TrackRoles roles(Color color) => _roles.putIfAbsent(
    color.toARGB32(),
    () => trackRolesFor(color, background: colors.background, isDark: isDark),
  );

  /// The roles of the colour of [track].
  TrackRoles trackRoles(Track track) => roles(trackColor(track));

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

  /// Letter spacing of the lane digits, as a share of their size.
  static const double _laneDigitTracking = -0.05;

  /// Font family for regular text; `null` = platform default.
  String? get fontFamily => TikkyFonts.family(theme.fontFamily, platform);

  List<String> get fontFamilyFallback => TikkyFonts.fallback(theme.fontFamily);

  /// The text sizes follow the iOS text styles at the default size
  /// (Apple HIG): body and headline 17, callout 16, subhead 15, footnote
  /// 13, title 2 22. The system text size scales them further.
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

    // The lanes show their digits in Martian Mono (bundled), unless the
    // theme asks for the platform's monospace font.
    final laneFamily = digit.monospace ? digitFamily : BundledFonts.martianMono;
    final laneFallback = digit.monospace
        ? digitFallback
        : TikkyFonts.fallback(TikkyFonts.mono);
    TextStyle laneDigits(double size, double lineHeight, Color color) =>
        TextStyle(
          fontFamily: laneFamily,
          fontFamilyFallback: laneFallback.isEmpty ? null : laneFallback,
          fontSize: size,
          fontWeight: FontWeight.w500,
          color: color,
          height: lineHeight,
          letterSpacing: size * _laneDigitTracking,
          fontFeatures: digit.tabular
              ? const [FontFeature.tabularFigures()]
              : null,
        );

    return TikkyTextStyles._(
      laneName: base(14, FontWeight.w600, colors.text, height: 17 / 14),
      laneMode: base(14, FontWeight.w400, colors.text, height: 17 / 14),
      laneSub: base(13, FontWeight.w400, colors.textMuted, height: 16 / 13),
      laneDigits: laneDigits(sizes.digitsLarge, 38 / 32, colors.text),
      laneDigitsIdle: laneDigits(sizes.digitsMedium, 26 / 22, colors.textMuted),
      laneLabelCount: laneDigits(15, 1.2, colors.text),
      laneLabel: base(15, FontWeight.w600, colors.text, height: 1.2),
      labelStrong: base(15, FontWeight.w600, colors.text, height: 1.2),
      padName: base(
        22,
        FontWeight.w700,
        colors.text,
        height: 1.2,
        letterSpacing: 22 * -0.01,
      ),
      padNameLarge: base(
        28,
        FontWeight.w700,
        colors.text,
        height: 1.2,
        letterSpacing: 28 * -0.01,
      ),
      padCount: laneDigits(18 * prefs.digitScale, 1.2, colors.text),
      padHint: base(14, FontWeight.w400, colors.text, height: 1.25),
      padDigits: laneDigits(sizes.digitsMedium, 26 / 22, colors.text),
      padInitial: base(18, FontWeight.w700, colors.text, height: 1),
      sheetTitle: base(
        20,
        FontWeight.w700,
        colors.text,
        height: 1.2,
        letterSpacing: 20 * -0.01,
      ),
      chip: base(14, FontWeight.w600, colors.text, height: 1.2),
      rowValue: base(16, FontWeight.w600, colors.text, height: 1.25),
      laneButton: base(14, FontWeight.w700, colors.text, height: 1),
      stripName: base(13, FontWeight.w600, colors.text, height: 16 / 13),
      stripThing: base(12, FontWeight.w500, colors.textMuted, height: 16 / 12),
      stripDigits: laneDigits(11, 16 / 11, colors.text),
      stripWord: base(11, FontWeight.w400, colors.textMuted, height: 15 / 11),
      cardDigits: laneDigits(20 * prefs.digitScale, 24 / 20, colors.text),
      cardNote: base(12, FontWeight.w400, colors.textMuted, height: 15 / 12),
      navLabel: base(15, FontWeight.w600, colors.text, height: 1.2),
      pageTitle: base(
        30,
        FontWeight.w700,
        colors.text,
        height: 34 / 30,
        letterSpacing: 30 * -0.02,
      ),
      pageTitleCompact: base(
        24,
        FontWeight.w700,
        colors.text,
        height: 28 / 24,
        letterSpacing: 24 * -0.02,
      ),
      digitsLarge: digits(sizes.digitsLarge, colors.text),
      digitsMedium: digits(sizes.digitsMedium, colors.text),
      digitsSmall: digits(sizes.digitsSmall, colors.textMuted),
      laneTitle: base(15, FontWeight.w500, colors.textMuted, height: 1.2),
      subLine: base(15, FontWeight.w400, colors.textMuted, height: 1.25),
      title: base(22, FontWeight.w600, colors.text, height: 1.2),
      headline: base(17, FontWeight.w600, colors.text, height: 1.25),
      body: base(17, FontWeight.w400, colors.text, height: 1.35),
      bodyMuted: base(17, FontWeight.w400, colors.textMuted, height: 1.35),
      label: base(16, FontWeight.w500, colors.text, height: 1.25),
      caption: base(13, FontWeight.w400, colors.textMuted, height: 1.3),
      button: base(17, FontWeight.w600, colors.text, height: 1.2),
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
