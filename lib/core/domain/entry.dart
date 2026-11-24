import 'json_utils.dart';

/// One protocol entry: who had what, when.
///
/// An entry belongs to a person and a thing ("Sache", [substanceId]), not
/// to a set, a track or a session. Everything the protocol shows (time
/// since, running lockouts, counts of the day) is derived from entries.
final class Entry {
  const Entry({
    required this.id,
    required this.at,
    required this.personId,
    required this.substanceId,
    this.amount,
    this.note,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.extra = const {},
  });

  factory Entry.fromJson(JsonMap json) => Entry(
    id: jsonString(json['id'], ''),
    at: jsonInt(json['at'], 0),
    personId: jsonString(json['personId'], ''),
    substanceId: jsonString(json['substanceId'], ''),
    amount: jsonStringOrNull(json['amount']),
    note: jsonStringOrNull(json['note']),
    createdAt: jsonInt(json['createdAt'], 0),
    updatedAt: jsonInt(json['updatedAt'], 0),
    extra: jsonMap(json['extra']),
  );

  final String id;

  /// Wall time (UTC milliseconds). User-editable.
  final int at;
  final String personId;
  final String substanceId;

  /// Free text as typed by the user; never summed up.
  final String? amount;
  final String? note;
  final int createdAt;
  final int updatedAt;
  final JsonMap extra;

  Entry copyWith({
    String? id,
    int? at,
    String? personId,
    String? substanceId,
    String? Function()? amount,
    String? Function()? note,
    int? createdAt,
    int? updatedAt,
    JsonMap? extra,
  }) => Entry(
    id: id ?? this.id,
    at: at ?? this.at,
    personId: personId ?? this.personId,
    substanceId: substanceId ?? this.substanceId,
    amount: amount == null ? this.amount : amount(),
    note: note == null ? this.note : note(),
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    extra: extra ?? this.extra,
  );

  JsonMap toJson() => {
    'id': id,
    'at': at,
    'personId': personId,
    'substanceId': substanceId,
    'amount': amount,
    'note': note,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'extra': extra,
  };

  @override
  bool operator ==(Object other) =>
      other is Entry &&
      other.id == id &&
      other.at == at &&
      other.personId == personId &&
      other.substanceId == substanceId &&
      other.amount == amount &&
      other.note == note &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      jsonMapEquals(other.extra, extra);

  @override
  int get hashCode =>
      Object.hash(id, at, personId, substanceId, amount, note, createdAt);

  @override
  String toString() => 'Entry($id, $personId, $substanceId @$at)';
}
