import 'enums.dart';
import 'json_utils.dart';
import 'track_config.dart';

/// One run of a track: from the first start until stop / reset.
///
/// A session carries a snapshot of the track's [config] taken when it was
/// started (and kept in sync while it is open), so history is derived with
/// the configuration that was actually in effect.
final class Session {
  const Session({
    required this.id,
    required this.trackId,
    required this.config,
    required this.startedAt,
    this.endedAt,
    this.note,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.extra = const {},
  });

  factory Session.fromJson(JsonMap json) {
    final mode = TrackMode.fromName(jsonStringOrNull(json['mode']));
    return Session(
      id: jsonString(json['id'], ''),
      trackId: jsonString(json['trackId'], ''),
      config: TrackConfig.fromJson(mode, jsonMap(json['config'])),
      startedAt: jsonInt(json['startedAt'], 0),
      endedAt: jsonIntOrNull(json['endedAt']),
      note: jsonStringOrNull(json['note']),
      createdAt: jsonInt(json['createdAt'], 0),
      updatedAt: jsonInt(json['updatedAt'], 0),
      extra: jsonMap(json['extra']),
    );
  }

  final String id;
  final String trackId;
  final TrackConfig config;

  /// UTC milliseconds of the start event.
  final int startedAt;

  /// UTC milliseconds of the stop event; `null` while the session is open.
  final int? endedAt;
  final String? note;
  final int createdAt;
  final int updatedAt;
  final JsonMap extra;

  TrackMode get mode => config.mode;
  bool get isOpen => endedAt == null;

  Session copyWith({
    String? id,
    String? trackId,
    TrackConfig? config,
    int? startedAt,
    int? Function()? endedAt,
    String? Function()? note,
    int? createdAt,
    int? updatedAt,
    JsonMap? extra,
  }) => Session(
    id: id ?? this.id,
    trackId: trackId ?? this.trackId,
    config: config ?? this.config,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt == null ? this.endedAt : endedAt(),
    note: note == null ? this.note : note(),
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    extra: extra ?? this.extra,
  );

  JsonMap toJson() => {
    'id': id,
    'trackId': trackId,
    'mode': mode.name,
    'config': config.toJson(),
    'startedAt': startedAt,
    'endedAt': endedAt,
    'note': note,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'extra': extra,
  };

  @override
  bool operator ==(Object other) =>
      other is Session &&
      other.id == id &&
      other.trackId == trackId &&
      other.config == config &&
      other.startedAt == startedAt &&
      other.endedAt == endedAt &&
      other.note == note &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      jsonMapEquals(other.extra, extra);

  @override
  int get hashCode => Object.hash(
    id,
    trackId,
    config,
    startedAt,
    endedAt,
    note,
    createdAt,
    updatedAt,
  );

  @override
  String toString() => 'Session($id, track: $trackId, ${mode.name})';
}
