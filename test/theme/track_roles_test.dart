import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/features/settings/contrast.dart';
import 'package:tikky_takka/theme/theme.dart';

Color _hex(String hex) =>
    Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));

String _toHex(Color c) {
  final rgb = (c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
  return '#${rgb.toUpperCase()}';
}

/// The designs of docs/design/tokens.json that exist as presets.
const _presets = {
  'Schwarz': ThemePresets.black,
  'Dunkel': ThemePresets.dark,
  'Hell': ThemePresets.light,
};

void main() {
  final tokens =
      jsonDecode(File('docs/design/tokens.json').readAsStringSync())
          as Map<String, dynamic>;
  final designs = tokens['designs'] as Map<String, dynamic>;

  group('track roles match docs/design/tokens.json', () {
    for (final MapEntry(key: name, value: preset) in _presets.entries) {
      test(name, () {
        final design = designs[name] as Map<String, dynamic>;
        final colors = design['spurfarben'] as Map<String, dynamic>;
        expect(colors, hasLength(preset.trackPalette.length));
        var i = 0;
        for (final MapEntry(key: colorName, value: raw) in colors.entries) {
          final want = (raw as Map<String, dynamic>).cast<String, String>();
          final solid = preset.trackPalette[i++];
          final roles = trackRolesFor(
            solid,
            background: preset.colors.background,
            isDark: preset.isDark,
          );
          expect(
            {
              'solid': _toHex(roles.solid),
              'tint': _toHex(roles.tint),
              'strong': _toHex(roles.strong),
              'ink': _toHex(roles.ink),
              'on': _toHex(roles.on),
            },
            want,
            reason: '$name $colorName',
          );
        }
      });

      test('$name: base colours', () {
        final design = designs[name] as Map<String, dynamic>;
        final want = (design['farben'] as Map<String, dynamic>)
            .cast<String, String>();
        final c = preset.colors;
        final have = {
          'background': c.background,
          'text': c.text,
          'textMuted': c.textMuted,
          'border': c.border,
          'primary': c.primary,
          'onPrimary': c.onPrimary,
          'segment': c.segment,
          'danger': c.danger,
          'onDanger': c.onDanger,
          'warning': c.warning,
          'warningText': c.warningText,
        };
        for (final MapEntry(:key, :value) in have.entries) {
          expect(_toHex(value), want[key], reason: '$name $key');
        }
      });
    }
  });

  group('trackRolesFor', () {
    test('every role pair of every preset is readable', () {
      for (final preset in ThemePresets.all) {
        final c = preset.colors;
        for (final solid in preset.trackPalette) {
          final r = trackRolesFor(
            solid,
            background: c.background,
            isDark: preset.isDark,
          );
          final pairs = {
            'ink on tint': contrastRatio(r.ink, r.tint),
            'ink on strong': contrastRatio(r.ink, r.strong),
            'on on solid': contrastRatio(r.on, r.solid),
            'text on strong': contrastRatio(c.text, r.strong),
            'warning text on tint': contrastRatio(c.warningText, r.tint),
            'muted on tint': contrastRatio(c.textMuted, r.tint),
          };
          for (final MapEntry(:key, :value) in pairs.entries) {
            expect(
              value,
              greaterThanOrEqualTo(4.5),
              reason: '${preset.name} ${_toHex(solid)} $key',
            );
          }
        }
      }
    });

    test('any colour gets readable ink, also a custom one', () {
      const samples = [
        '#000000',
        '#FFFFFF',
        '#808080',
        '#FF0000',
        '#00FF00',
        '#0000FF',
        '#FFFF00',
      ];
      for (final preset in ThemePresets.all) {
        for (final hex in samples) {
          final r = trackRolesFor(
            _hex(hex),
            background: preset.colors.background,
            isDark: preset.isDark,
          );
          final reason = '${preset.name} $hex';
          expect(
            contrastRatio(r.ink, r.strong),
            greaterThanOrEqualTo(4.5),
            reason: reason,
          );
          expect(
            contrastRatio(r.on, r.solid),
            greaterThanOrEqualTo(4.5),
            reason: reason,
          );
        }
      }
    });

    test('a translucent colour is treated as opaque', () {
      final r = trackRolesFor(
        const Color(0x806EA8FF),
        background: const Color(0xFF000000),
        isDark: true,
      );
      expect(_toHex(r.solid), '#6EA8FF');
      expect(r.solid.a, 1);
    });
  });

  group('tokens', () {
    test('roles are cached per colour and follow the theme', () {
      final dark = TikkyTokens(
        theme: ThemePresets.black,
        prefs: UiPrefs.defaults,
      );
      final light = TikkyTokens(
        theme: ThemePresets.light,
        prefs: UiPrefs.defaults,
      );
      const blue = Color(0xFF6EA8FF);
      expect(identical(dark.roles(blue), dark.roles(blue)), isTrue);
      expect(_toHex(dark.roles(blue).tint), '#141E2E');
      expect(dark.roles(blue).tint, isNot(light.roles(blue).tint));
    });

    test('role radii follow the base radius', () {
      final t = TikkyTokens(theme: ThemePresets.black, prefs: UiPrefs.defaults);
      expect(t.radii.lane, 20);
      expect(t.radii.pad, 22);
      expect(t.radii.small, 14);
      expect(t.radii.sheet, 28);
      final square = TikkyTokens(
        theme: ThemePresets.black.copyWith(cornerRadius: 0),
        prefs: UiPrefs.defaults,
      );
      expect(square.radii.lane, 0);
      expect(square.radii.pill, 0);
    });
  });

  group('contrastIssues for track colours', () {
    test('warning text that is too weak on a lane is named', () {
      final theme = ThemePresets.light.copyWith(
        colors: ThemePresets.light.colors.copyWith(
          warningText: ThemePresets.light.colors.warning,
        ),
      );
      final issues = contrastIssues(theme);
      expect(issues, isNotEmpty);
      expect(
        issues.every((i) => i.pair == ContrastPair.warningTextOnTint),
        isTrue,
      );
      expect(issues.first.paletteIndex, isNotNull);
    });
  });
}
