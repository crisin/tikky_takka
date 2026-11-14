import 'dart:ui' show Color;

/// `#RRGGBB` (upper case) for an opaque colour; alpha is dropped.
String colorToHex(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Parses `#RGB`, `#RRGGBB` or `#AARRGGBB` (the `#` is optional, case does
/// not matter, surrounding blanks are ignored). The result is always
/// opaque: theme colours have no transparency. Returns `null` for anything
/// else.
Color? parseHexColor(String input) {
  var text = input.trim();
  if (text.startsWith('#')) text = text.substring(1);
  if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(text)) return null;
  if (text.length == 3) {
    text = text.split('').map((c) => '$c$c').join();
  } else if (text.length == 8) {
    text = text.substring(2);
  } else if (text.length != 6) {
    return null;
  }
  return Color(0xFF000000 | int.parse(text, radix: 16));
}

/// Lower-case file name part for a theme name: letters and digits kept,
/// everything else becomes `-`. Never empty.
String fileSlug(String name) {
  const umlauts = {'ä': 'ae', 'ö': 'oe', 'ü': 'ue', 'ß': 'ss'};
  final buffer = StringBuffer();
  for (final rune in name.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    if (umlauts.containsKey(char)) {
      buffer.write(umlauts[char]);
    } else if (RegExp(r'[a-z0-9]').hasMatch(char)) {
      buffer.write(char);
    } else {
      buffer.write('-');
    }
  }
  final slug = buffer
      .toString()
      .replaceAll(RegExp('-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return slug.isEmpty ? 'design' : slug;
}
