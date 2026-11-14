// Renders the app icon for every platform from one drawing.
//
//   flutter test tools/app_icon/render_app_icons_test.dart
//
// Writes into ios/, android/, macos/, web/ and windows/. Not part of the
// regular test run (it lives outside test/); rerun it after changing the
// drawing below.
//
// The motif is the strip timeline: three lanes with bars of different
// lengths (several timers at once) and the white "now" line crossing them.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _background = Color(0xFF161618);
const _lanes = [Color(0xFF6EA8FF), Color(0xFF5BD19B), Color(0xFFFFB454)];
const _now = Color(0xFFF2F2EE);

/// Draws the motif into a 1024 x 1024 box. [scale] shrinks it around the
/// centre (adaptive / maskable icons keep their content in a safe zone).
void _paintMotif(Canvas canvas, {double scale = 1, Color? only}) {
  canvas.save();
  canvas.translate(512, 512);
  canvas.scale(scale);
  canvas.translate(-512, -512);

  const barHeight = 128.0;
  const radius = Radius.circular(barHeight / 2);
  // (left, right, centre y) per lane.
  const bars = [
    (184.0, 720.0, 312.0),
    (312.0, 840.0, 512.0),
    (184.0, 560.0, 712.0),
  ];
  for (var i = 0; i < bars.length; i++) {
    final (l, r, y) = bars[i];
    canvas.drawRRect(
      RRect.fromLTRBR(l, y - barHeight / 2, r, y + barHeight / 2, radius),
      Paint()..color = only ?? _lanes[i],
    );
  }

  // The "now" line, cut out of the bars by a gap in the background colour.
  const x = 640.0;
  final line = RRect.fromLTRBR(
    x - 22,
    176,
    x + 22,
    848,
    const Radius.circular(22),
  );
  if (only == null) {
    canvas.drawRRect(line.inflate(22), Paint()..color = _background);
  } else {
    canvas.drawRRect(line.inflate(22), Paint()..blendMode = BlendMode.clear);
  }
  canvas.drawRRect(line, Paint()..color = only ?? _now);
  canvas.restore();
}

enum _Shape { square, roundedSquare, transparent }

Future<Uint8List> _render(
  int size, {
  _Shape shape = _Shape.square,
  double motifScale = 1,
  double inset = 0,
  Color? only,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(size / 1024);
  canvas.saveLayer(const Rect.fromLTWH(0, 0, 1024, 1024), Paint());
  switch (shape) {
    case _Shape.square:
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 1024, 1024),
        Paint()..color = _background,
      );
    case _Shape.roundedSquare:
      final box = const Rect.fromLTWH(0, 0, 1024, 1024).deflate(inset);
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, Radius.circular(box.width * 0.225)),
        Paint()..color = _background,
      );
    case _Shape.transparent:
      break;
  }
  canvas.save();
  if (inset > 0) {
    canvas.translate(512, 512);
    canvas.scale((1024 - 2 * inset) / 1024);
    canvas.translate(-512, -512);
  }
  _paintMotif(canvas, scale: motifScale, only: only);
  canvas.restore();
  canvas.restore();
  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

Future<void> _write(String path, Future<Uint8List> png) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(await png);
}

/// A Windows .ico holding PNG images (supported since Windows Vista).
Future<void> _writeIco(String path, List<int> sizes) async {
  final pngs = [for (final s in sizes) await _render(s)];
  final header = BytesBuilder()
    ..add(_u16(0))
    ..add(_u16(1))
    ..add(_u16(sizes.length));
  var offset = 6 + 16 * sizes.length;
  for (var i = 0; i < sizes.length; i++) {
    final s = sizes[i] >= 256 ? 0 : sizes[i];
    header
      ..addByte(s)
      ..addByte(s)
      ..addByte(0)
      ..addByte(0)
      ..add(_u16(1))
      ..add(_u16(32))
      ..add(_u32(pngs[i].length))
      ..add(_u32(offset));
    offset += pngs[i].length;
  }
  for (final p in pngs) {
    header.add(p);
  }
  await File(path).writeAsBytes(header.toBytes());
}

List<int> _u16(int v) => [v & 0xFF, (v >> 8) & 0xFF];
List<int> _u32(int v) => [
  v & 0xFF,
  (v >> 8) & 0xFF,
  (v >> 16) & 0xFF,
  (v >> 24) & 0xFF,
];

void main() {
  testWidgets('render app icons', (tester) async {
    await tester.runAsync(() async {
      // iOS: opaque full squares, the system rounds the corners.
      const ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
      const iosIcons = {
        'Icon-App-1024x1024@1x.png': 1024,
        'Icon-App-20x20@1x.png': 20,
        'Icon-App-20x20@2x.png': 40,
        'Icon-App-20x20@3x.png': 60,
        'Icon-App-29x29@1x.png': 29,
        'Icon-App-29x29@2x.png': 58,
        'Icon-App-29x29@3x.png': 87,
        'Icon-App-40x40@1x.png': 40,
        'Icon-App-40x40@2x.png': 80,
        'Icon-App-40x40@3x.png': 120,
        'Icon-App-60x60@2x.png': 120,
        'Icon-App-60x60@3x.png': 180,
        'Icon-App-76x76@1x.png': 76,
        'Icon-App-76x76@2x.png': 152,
        'Icon-App-83.5x83.5@2x.png': 167,
      };
      for (final MapEntry(:key, :value) in iosIcons.entries) {
        await _write('$ios/$key', _render(value));
      }

      // Android: legacy launcher icon (rounded square) plus the adaptive
      // icon's foreground (108 dp, motif inside the 66 dp safe zone) and a
      // monochrome layer for themed icons (Android 13+).
      const res = 'android/app/src/main/res';
      const densities = {
        'mdpi': 1.0,
        'hdpi': 1.5,
        'xhdpi': 2.0,
        'xxhdpi': 3.0,
        'xxxhdpi': 4.0,
      };
      for (final MapEntry(key: d, value: f) in densities.entries) {
        await _write(
          '$res/mipmap-$d/ic_launcher.png',
          _render(
            (48 * f).round(),
            shape: _Shape.roundedSquare,
            inset: 1024 / 48 * 2,
          ),
        );
        await _write(
          '$res/mipmap-$d/ic_launcher_foreground.png',
          _render(
            (108 * f).round(),
            shape: _Shape.transparent,
            motifScale: 0.62,
          ),
        );
        await _write(
          '$res/mipmap-$d/ic_launcher_monochrome.png',
          _render(
            (108 * f).round(),
            shape: _Shape.transparent,
            motifScale: 0.62,
            only: const Color(0xFFFFFFFF),
          ),
        );
      }

      // macOS: the icon brings its own rounded shape and margin.
      const mac = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';
      for (final s in [16, 32, 64, 128, 256, 512, 1024]) {
        await _write(
          '$mac/app_icon_$s.png',
          _render(s, shape: _Shape.roundedSquare, inset: 100),
        );
      }

      // Web: plain and maskable (content inside the 80 % safe circle).
      await _write('web/favicon.png', _render(32, shape: _Shape.roundedSquare));
      await _write(
        'web/icons/Icon-192.png',
        _render(192, shape: _Shape.roundedSquare),
      );
      await _write(
        'web/icons/Icon-512.png',
        _render(512, shape: _Shape.roundedSquare),
      );
      await _write(
        'web/icons/Icon-maskable-192.png',
        _render(192, motifScale: 0.75),
      );
      await _write(
        'web/icons/Icon-maskable-512.png',
        _render(512, motifScale: 0.75),
      );

      await _writeIco('windows/runner/resources/app_icon.ico', [
        16,
        24,
        32,
        48,
        64,
        256,
      ]);
    });
  });
}
