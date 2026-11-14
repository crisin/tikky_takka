import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

/// Scroll behaviour for the whole app.
///
/// Physics stay platform-native (bouncing on iOS / macOS, clamping with
/// stretch overscroll on Android, plain clamping on desktop - Flutter picks
/// these from the platform). On top of that, lists can be dragged with a
/// mouse or trackpad, which desktop users expect for reordering and wheels.
class AdaptiveScrollBehavior extends MaterialScrollBehavior {
  const AdaptiveScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.unknown,
  };
}

/// Pushes a full page with the platform's native transition and back
/// gesture: predictive back on Android, edge-swipe on iOS, fade-forward on
/// desktop (configured in the theme's `pageTransitionsTheme`).
Future<T?> pushAdaptivePage<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool fullscreenDialog = false,
}) {
  return Navigator.of(context).push<T>(
    MaterialPageRoute<T>(builder: builder, fullscreenDialog: fullscreenDialog),
  );
}
