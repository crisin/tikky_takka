import 'dart:ui' show Color;

import '../../theme/tikky_theme.dart';
import '../../theme/track_roles.dart';

/// The colour pairs of a theme that must stay readable.
enum ContrastPair {
  textOnBackground,
  textOnSurface,
  mutedOnSurface,
  mutedOnBackground,
  onPrimaryOnPrimary,

  // Per track colour (see TrackRoles); the issue names the palette entry.
  inkOnTint,
  inkOnStrong,
  onOnSolid,
  textOnStrong,
  warningTextOnTint,
}

/// A pair whose contrast is below the recommended minimum.
final class ContrastIssue {
  const ContrastIssue({
    required this.pair,
    required this.ratio,
    required this.minimum,
    this.paletteIndex,
  });

  final ContrastPair pair;

  /// The entry of the track palette the pair belongs to; `null` for the
  /// pairs of the base colours.
  final int? paletteIndex;

  /// Measured contrast ratio.
  final double ratio;

  /// Recommended minimum for this pair.
  final double minimum;

  @override
  String toString() => 'ContrastIssue(${pair.name}, $ratio < $minimum)';
}

/// Minimum contrast for regular text (WCAG AA).
const double minTextContrast = 4.5;

/// Minimum contrast for large text, muted secondary text and icons
/// (WCAG AA for large text / UI components).
const double minLargeContrast = 3;

/// All readability problems of [theme], most important first. Empty when
/// the theme is fine. Pure.
List<ContrastIssue> contrastIssues(TikkyTheme theme) {
  final c = theme.colors;
  final checks = <(ContrastPair, Color, Color, double)>[
    (ContrastPair.textOnBackground, c.text, c.background, minTextContrast),
    (ContrastPair.textOnSurface, c.text, c.surface, minTextContrast),
    (ContrastPair.mutedOnSurface, c.textMuted, c.surface, minLargeContrast),
    (
      ContrastPair.mutedOnBackground,
      c.textMuted,
      c.background,
      minLargeContrast,
    ),
    (ContrastPair.onPrimaryOnPrimary, c.onPrimary, c.primary, minLargeContrast),
  ];
  final issues = [
    for (final (pair, foreground, background, minimum) in checks)
      if (contrastRatio(foreground, background) < minimum)
        ContrastIssue(
          pair: pair,
          ratio: contrastRatio(foreground, background),
          minimum: minimum,
        ),
  ];
  for (var i = 0; i < theme.trackPalette.length; i++) {
    final r = trackRolesFor(
      theme.trackPalette[i],
      background: c.background,
      isDark: theme.isDark,
    );
    final roleChecks = <(ContrastPair, Color, Color)>[
      (ContrastPair.inkOnTint, r.ink, r.tint),
      (ContrastPair.inkOnStrong, r.ink, r.strong),
      (ContrastPair.onOnSolid, r.on, r.solid),
      (ContrastPair.textOnStrong, c.text, r.strong),
      (ContrastPair.warningTextOnTint, c.warningText, r.tint),
    ];
    for (final (pair, foreground, background) in roleChecks) {
      final ratio = contrastRatio(foreground, background);
      if (ratio < minTextContrast) {
        issues.add(
          ContrastIssue(
            pair: pair,
            ratio: ratio,
            minimum: minTextContrast,
            paletteIndex: i,
          ),
        );
      }
    }
  }
  return issues;
}
