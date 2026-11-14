import 'dart:convert';

/// Small, dependency-free helpers shared by the JSON (de)serialisable domain
/// and theme classes. All readers are lenient: wrong or missing values fall
/// back to the supplied default instead of throwing, so old or hand-edited
/// files never crash the app.

typedef JsonMap = Map<String, Object?>;

int jsonInt(Object? v, int fallback) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

int? jsonIntOrNull(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double jsonDouble(Object? v, double fallback) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

bool jsonBool(Object? v, bool fallback) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    if (v == 'true' || v == '1') return true;
    if (v == 'false' || v == '0') return false;
  }
  return fallback;
}

String jsonString(Object? v, String fallback) => v is String ? v : fallback;

String? jsonStringOrNull(Object? v) => v is String ? v : null;

List<String> jsonStringList(Object? v) {
  if (v is List) {
    return [
      for (final e in v)
        if (e is String) e,
    ];
  }
  return const [];
}

JsonMap jsonMap(Object? v) {
  if (v is Map) {
    return {
      for (final e in v.entries)
        if (e.key is String) e.key as String: e.value,
    };
  }
  return <String, Object?>{};
}

JsonMap? jsonMapOrNull(Object? v) => v is Map ? jsonMap(v) : null;

/// Decodes a JSON object string; returns an empty map for null, empty or
/// malformed input.
JsonMap decodeJsonMap(String? source) {
  if (source == null || source.isEmpty) return <String, Object?>{};
  try {
    return jsonMap(jsonDecode(source));
  } on FormatException {
    return <String, Object?>{};
  }
}

/// Like [decodeJsonMap] but keeps `null` / empty input as `null`.
JsonMap? decodeJsonMapOrNull(String? source) {
  if (source == null || source.isEmpty) return null;
  return decodeJsonMap(source);
}

/// Encodes a map, or returns `null` for a null / empty map (keeps optional
/// database columns empty).
String? encodeJsonMapOrNull(JsonMap? map) {
  if (map == null || map.isEmpty) return null;
  return jsonEncode(map);
}

/// Parses `#AARRGGBB`, `#RRGGBB` (opaque) or a plain integer into ARGB.
int jsonColor(Object? v, int fallback) {
  if (v is int) return v & 0xFFFFFFFF;
  if (v is String) {
    var s = v.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.startsWith('0x') || s.startsWith('0X')) s = s.substring(2);
    final parsed = int.tryParse(s, radix: 16);
    if (parsed == null) return fallback;
    if (s.length <= 6) return 0xFF000000 | parsed;
    return parsed & 0xFFFFFFFF;
  }
  return fallback;
}

/// Formats an ARGB integer as `#AARRGGBB`.
String colorToJson(int argb) =>
    '#${(argb & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0').toUpperCase()}';

bool jsonListEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!jsonDeepEquals(a[i], b[i])) return false;
  }
  return true;
}

bool jsonMapEquals<K, V>(Map<K, V>? a, Map<K, V>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || !jsonDeepEquals(a[key], b[key])) return false;
  }
  return true;
}

/// Structural equality for JSON-like values (maps, lists, scalars).
bool jsonDeepEquals(Object? a, Object? b) {
  if (a is Map && b is Map) return jsonMapEquals(a, b);
  if (a is List && b is List) return jsonListEquals(a, b);
  return a == b;
}

/// Order-independent hash for JSON-like values, consistent with
/// [jsonDeepEquals].
int jsonDeepHash(Object? v) {
  if (v is Map) {
    var h = 0;
    for (final e in v.entries) {
      h ^= Object.hash(jsonDeepHash(e.key), jsonDeepHash(e.value));
    }
    return h;
  }
  if (v is List) return Object.hashAll(v.map(jsonDeepHash));
  return v.hashCode;
}
