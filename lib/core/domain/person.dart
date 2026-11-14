import 'json_utils.dart';

/// A user-managed person for protocol entries ("wer").
final class Person {
  const Person({
    required this.id,
    required this.name,
    this.color = 0xFF888888,
    this.sortIndex = 0,
    this.archived = false,
    this.note,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.extra = const {},
  });

  factory Person.fromJson(JsonMap json) => Person(
    id: jsonString(json['id'], ''),
    name: jsonString(json['name'], ''),
    color: jsonColor(json['color'], 0xFF888888),
    sortIndex: jsonInt(json['sortIndex'], 0),
    archived: jsonBool(json['archived'], false),
    note: jsonStringOrNull(json['note']),
    createdAt: jsonInt(json['createdAt'], 0),
    updatedAt: jsonInt(json['updatedAt'], 0),
    extra: jsonMap(json['extra']),
  );

  final String id;
  final String name;

  /// ARGB colour.
  final int color;
  final int sortIndex;
  final bool archived;
  final String? note;
  final int createdAt;
  final int updatedAt;
  final JsonMap extra;

  Person copyWith({
    String? id,
    String? name,
    int? color,
    int? sortIndex,
    bool? archived,
    String? Function()? note,
    int? createdAt,
    int? updatedAt,
    JsonMap? extra,
  }) => Person(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color ?? this.color,
    sortIndex: sortIndex ?? this.sortIndex,
    archived: archived ?? this.archived,
    note: note == null ? this.note : note(),
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    extra: extra ?? this.extra,
  );

  JsonMap toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'sortIndex': sortIndex,
    'archived': archived,
    'note': note,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'extra': extra,
  };

  @override
  bool operator ==(Object other) =>
      other is Person &&
      other.id == id &&
      other.name == name &&
      other.color == color &&
      other.sortIndex == sortIndex &&
      other.archived == archived &&
      other.note == note &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      jsonMapEquals(other.extra, extra);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    color,
    sortIndex,
    archived,
    note,
    createdAt,
    updatedAt,
  );

  @override
  String toString() => 'Person($id, $name)';
}

/// A user-managed substance for protocol entries ("was").
///
/// [lockoutMs] ("frühestens wieder in ...") is optional and always set by
/// the user. The app never ships or suggests any dosing or interval value.
final class Substance {
  const Substance({
    required this.id,
    required this.name,
    this.color = 0xFF888888,
    this.lockoutMs,
    this.sortIndex = 0,
    this.archived = false,
    this.note,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.extra = const {},
  });

  factory Substance.fromJson(JsonMap json) => Substance(
    id: jsonString(json['id'], ''),
    name: jsonString(json['name'], ''),
    color: jsonColor(json['color'], 0xFF888888),
    lockoutMs: jsonIntOrNull(json['lockoutMs']),
    sortIndex: jsonInt(json['sortIndex'], 0),
    archived: jsonBool(json['archived'], false),
    note: jsonStringOrNull(json['note']),
    createdAt: jsonInt(json['createdAt'], 0),
    updatedAt: jsonInt(json['updatedAt'], 0),
    extra: jsonMap(json['extra']),
  );

  final String id;
  final String name;

  /// ARGB colour.
  final int color;

  /// User-set minimum gap before the next entry; `null` = no lockout.
  final int? lockoutMs;
  final int sortIndex;
  final bool archived;
  final String? note;
  final int createdAt;
  final int updatedAt;
  final JsonMap extra;

  Substance copyWith({
    String? id,
    String? name,
    int? color,
    int? Function()? lockoutMs,
    int? sortIndex,
    bool? archived,
    String? Function()? note,
    int? createdAt,
    int? updatedAt,
    JsonMap? extra,
  }) => Substance(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color ?? this.color,
    lockoutMs: lockoutMs == null ? this.lockoutMs : lockoutMs(),
    sortIndex: sortIndex ?? this.sortIndex,
    archived: archived ?? this.archived,
    note: note == null ? this.note : note(),
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    extra: extra ?? this.extra,
  );

  JsonMap toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'lockoutMs': lockoutMs,
    'sortIndex': sortIndex,
    'archived': archived,
    'note': note,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'extra': extra,
  };

  @override
  bool operator ==(Object other) =>
      other is Substance &&
      other.id == id &&
      other.name == name &&
      other.color == color &&
      other.lockoutMs == lockoutMs &&
      other.sortIndex == sortIndex &&
      other.archived == archived &&
      other.note == note &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      jsonMapEquals(other.extra, extra);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    color,
    lockoutMs,
    sortIndex,
    archived,
    note,
    createdAt,
    updatedAt,
  );

  @override
  String toString() => 'Substance($id, $name)';
}
