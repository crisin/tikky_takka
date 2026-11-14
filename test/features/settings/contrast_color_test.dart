import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/features/settings/color_utils.dart';
import 'package:tikky_takka/features/settings/contrast.dart';
import 'package:tikky_takka/features/settings/settings_strings.dart';
import 'package:tikky_takka/theme/theme.dart';

void main() {
  group('contrastRatio', () {
    test('black on white is 21:1, same colours are 1:1', () {
      const black = Color(0xFF000000);
      const white = Color(0xFFFFFFFF);
      expect(contrastRatio(black, white), closeTo(21, 0.01));
      expect(contrastRatio(white, black), closeTo(21, 0.01));
      expect(contrastRatio(white, white), closeTo(1, 0.0001));
    });

    test('is symmetric', () {
      const a = Color(0xFF2F6FED);
      const b = Color(0xFFF6F6F4);
      expect(contrastRatio(a, b), closeTo(contrastRatio(b, a), 0.0001));
    });
  });

  group('contrastIssues', () {
    test('the presets are readable', () {
      for (final preset in ThemePresets.all) {
        expect(contrastIssues(preset), isEmpty, reason: preset.name);
      }
    });

    test('text that matches the surface is reported', () {
      final theme = ThemePresets.light.copyWith(
        colors: ThemePresets.light.colors.copyWith(
          text: ThemePresets.light.colors.surface,
        ),
      );
      final issues = contrastIssues(theme);
      expect(
        issues.map((i) => i.pair),
        containsAll([
          ContrastPair.textOnSurface,
          ContrastPair.textOnBackground,
        ]),
      );
      final onSurface = issues.firstWhere(
        (i) => i.pair == ContrastPair.textOnSurface,
      );
      expect(onSurface.ratio, closeTo(1, 0.001));
      expect(onSurface.minimum, minTextContrast);
    });

    test('muted text and the accent pair use the lower threshold', () {
      // 3.5:1 against white: fine for muted text, too low for body text.
      const grey = Color(0xFF888888);
      expect(contrastRatio(grey, const Color(0xFFFFFFFF)), inInclusiveRange(3, 4.5));
      final muted = ThemePresets.light.copyWith(
        colors: ThemePresets.light.colors.copyWith(
          textMuted: grey,
          background: const Color(0xFFFFFFFF),
        ),
      );
      expect(contrastIssues(muted), isEmpty);

      final accent = ThemePresets.light.copyWith(
        colors: ThemePresets.light.colors.copyWith(
          onPrimary: ThemePresets.light.colors.primary,
        ),
      );
      expect(
        contrastIssues(accent).map((i) => i.pair),
        [ContrastPair.onPrimaryOnPrimary],
      );
    });
  });

  group('hex colours', () {
    test('colorToHex drops alpha and pads', () {
      expect(colorToHex(const Color(0xFF2F6FED)), '#2F6FED');
      expect(colorToHex(const Color(0x8000000A)), '#00000A');
    });

    test('parseHexColor accepts the common spellings', () {
      expect(parseHexColor('#2F6FED')!.toARGB32(), 0xFF2F6FED);
      expect(parseHexColor('2f6fed')!.toARGB32(), 0xFF2F6FED);
      expect(parseHexColor('  #abc ')!.toARGB32(), 0xFFAABBCC);
      // Alpha is ignored: theme colours are opaque.
      expect(parseHexColor('#802F6FED')!.toARGB32(), 0xFF2F6FED);
    });

    test('parseHexColor rejects everything else', () {
      for (final bad in ['', '#', '#12', '#12345', '#1234567', 'blau', '#GGGGGG']) {
        expect(parseHexColor(bad), isNull, reason: bad);
      }
    });

    test('round trip', () {
      for (final color in ThemePresets.paletteOnLight) {
        expect(parseHexColor(colorToHex(color)), color);
      }
    });
  });

  group('strings', () {
    test('fileSlug makes safe file names', () {
      expect(fileSlug('Mein Blau!'), 'mein-blau');
      expect(fileSlug('Größe / Übung'), 'groesse-uebung');
      expect(fileSlug('***'), 'design');
    });

    test('number formatting is German', () {
      expect(SettingsStrings.percent(1.15), '115 %');
      expect(SettingsStrings.pixels(12), '12 px');
      expect(SettingsStrings.pixels(1.5), '1,5 px');
      expect(
        SettingsStrings.contrastLine('Text auf Fläche', 2.13, 4.5),
        'Text auf Fläche: 2,1:1 (empfohlen mindestens 4,5:1)',
      );
    });
  });
}
