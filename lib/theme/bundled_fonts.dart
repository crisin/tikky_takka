import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// The fonts the app ships (declared in pubspec.yaml under `fonts:`).
abstract final class BundledFonts {
  /// Martian Mono: the digits of the designs Schwarz, Dunkel, Hell and
  /// Neon. A variable font (weight and width); every glyph has the same
  /// width, so running digits do not jump.
  static const martianMono = 'MartianMono';

  /// Family name and licence asset of every bundled font.
  static const licenses = {martianMono: 'assets/fonts/MartianMono-OFL.txt'};
}

/// Adds the licence texts of the bundled fonts to the licence page
/// (settings, "Lizenzen"). The SIL Open Font License asks for the text to
/// travel with the font.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry(key: family, value: asset)
        in BundledFonts.licenses.entries) {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString(asset));
    }
  });
}
