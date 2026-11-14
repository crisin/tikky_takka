import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/theme/theme.dart';

double _width(String text, {required int weight}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: BundledFonts.martianMono,
        fontSize: 100,
        fontVariations: [FontVariation('wght', weight.toDouble())],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  addTearDown(painter.dispose);
  return painter.width;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final bytes = File('assets/fonts/MartianMono.ttf').readAsBytesSync();
    final loader = FontLoader(BundledFonts.martianMono)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  });

  test('every bundled font is declared with its licence', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final MapEntry(key: family, value: asset)
        in BundledFonts.licenses.entries) {
      expect(pubspec, contains('family: $family'));
      expect(pubspec, contains('- $asset'));
      expect(
        File(asset).readAsStringSync(),
        contains('SIL OPEN FONT LICENSE Version 1.1'),
      );
    }
  });

  test('Martian Mono: digits and time signs all have the same width', () {
    for (final weight in [400, 500, 700]) {
      final widths = {
        for (final glyph in '0123456789:+-.,×'.split(''))
          glyph: _width(glyph, weight: weight),
      };
      final zero = widths['0']!;
      // The test font would give every glyph a square of the font size.
      expect(zero, isNot(100), reason: 'the real font is loaded');
      expect(
        widths.values.every((w) => (w - zero).abs() < 0.01),
        isTrue,
        reason: 'weight $weight: $widths',
      );
    }
  });

  test('Martian Mono: a running time keeps its width', () {
    expect(_width('1:42:07', weight: 500), _width('8:11:11', weight: 500));
  });
}
