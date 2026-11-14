import 'dart:ui' show Color;

import '../../theme/tikky_theme.dart';

/// WCAG 2.x contrast ratio between two opaque colours (1.0 .. 21.0).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

/// The colour pairs of a theme that must stay readable.
enum ContrastPair {
  textOnBackground,
  textOnSurface,
  mutedOnSurface,
  mutedOnBackground,
  onPrimaryOnPrimary,
}

/// A pair whose contrast is below the recommended minimum.
final class ContrastIssue {
  const ContrastIssue({
    required this.pair,
    required this.ratio,
    required this.minimum,
  });

  final ContrastPair pair;

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
  return [
    for (final (pair, foreground, background, minimum) in checks)
      if (contrastRatio(foreground, background) < minimum)
        ContrastIssue(
          pair: pair,
          ratio: contrastRatio(foreground, background),
          minimum: minimum,
        ),
  ];
}
