import 'enums.dart';
import 'json_utils.dart';

/// A single timestamped entry of the event log. Everything the app shows is
/// derived from a list of these.
final class TrackEvent {
  const TrackEvent({
    required this.id,
    required this.sessionId,
    required this.trackId,
    required this.type,
    required this.at,
    this.seq = 0,
    this.label,
    this.personId,
    this.substanceId,
    this.amount,
    this.note,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.extra = const {},
  });

  /// Returns `null` when the event type is unknown (e.g. written by a newer
  /// app version).
  static TrackEvent? tryFromJson(JsonMap json) {
    final type = EventType.tryFromName(jsonStringOrNull(json['type']));
    if (type == null) return null;
    return TrackEvent(
      id: jsonString(json['id'], ''),
      sessionId: jsonString(json['sessionId'], ''),
      trackId: jsonString(json['trackId'], ''),
      type: type,
      at: jsonInt(json['at'], 0),
      seq: jsonInt(json['seq'], 0),
      label: jsonStringOrNull(json['label']),
      personId: jsonStringOrNull(json['personId']),
      substanceId: jsonStringOrNull(json['substanceId']),
      amount: jsonStringOrNull(json['amount']),
      note: jsonStringOrNull(json['note']),
      createdAt: jsonInt(json['createdAt'], 0),
      updatedAt: jsonInt(json['updatedAt'], 0),
      extra: jsonMap(json['extra']),
    );
  }

  final String id;
  final String sessionId;
  final String trackId;
  final EventType type;

  /// UTC milliseconds.
  final int at;

  /// Insertion order inside the session; tie-breaker for equal [at].
  final int seq;

  /// Quick label of a counter tick (or free label for laps).
  final String? label;
  final String? personId;
  final String? substanceId;

  /// Free text, never interpreted by the app.
  final String? amount;
  final String? note;
  final int createdAt;
  final int updatedAt;
  final JsonMap extra;

  TrackEvent copyWith({
    String? id,
    String? sessionId,
    String? trackId,
    EventType? type,
    int? at,
    int? seq,
    String? Function()? label,
    String? Function()? personId,
    String? Function()? substanceId,
    String? Function()? amount,
    String? Function()? note,
    int? createdAt,
    int? updatedAt,
    JsonMap? extra,
  }) => TrackEvent(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    trackId: trackId ?? this.trackId,
    type: type ?? this.type,
    at: at ?? this.at,
    seq: seq ?? this.seq,
    label: label == null ? this.label : label(),
    personId: personId == null ? this.personId : personId(),
    substanceId: substanceId == null ? this.substanceId : substanceId(),
    amount: amount == null ? this.amount : amount(),
    note: note == null ? this.note : note(),
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    extra: extra ?? this.extra,
  );

  JsonMap toJson() => {
    'id': id,
    'sessionId': sessionId,
    'trackId': trackId,
    'type': type.name,
    'at': at,
    'seq': seq,
    'label': label,
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
      other is TrackEvent &&
      other.id == id &&
      other.sessionId == sessionId &&
      other.trackId == trackId &&
      other.type == type &&
      other.at == at &&
      other.seq == seq &&
      other.label == label &&
      other.personId == personId &&
      other.substanceId == substanceId &&
      other.amount == amount &&
      other.note == note &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      jsonMapEquals(other.extra, extra);

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    trackId,
    type,
    at,
    seq,
    label,
    personId,
    substanceId,
    amount,
    note,
    createdAt,
    updatedAt,
  );

  @override
  String toString() => 'TrackEvent(${type.name} @$at, session: $sessionId)';
}
