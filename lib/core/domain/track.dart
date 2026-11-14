import 'enums.dart';
import 'json_utils.dart';
import 'track_config.dart';

/// A configurable timer lane ("Spur").
final class Track {
  const Track({
    required this.id,
    required this.setId,
    required this.name,
    required this.config,
    this.colorIndex = 0,
    this.customColor,
    this.alarmSound = true,
    this.vibration = true,
    this.sortIndex = 0,
    this.logEnabled = true,
    this.archived = false,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.extra = const {},
  });

  factory Track.fromJson(JsonMap json) {
    final mode = TrackMode.fromName(jsonStringOrNull(json['mode']));
    return Track(
      id: jsonString(json['id'], ''),
      setId: jsonString(json['setId'], ''),
      name: jsonString(json['name'], ''),
      config: TrackConfig.fromJson(mode, jsonMap(json['config'])),
      colorIndex: jsonInt(json['colorIndex'], 0),
      customColor: jsonIntOrNull(json['customColor']),
      alarmSound: jsonBool(json['alarmSound'], true),
      vibration: jsonBool(json['vibration'], true),
      sortIndex: jsonInt(json['sortIndex'], 0),
      logEnabled: jsonBool(json['logEnabled'], true),
      archived: jsonBool(json['archived'], false),
      createdAt: jsonInt(json['createdAt'], 0),
      updatedAt: jsonInt(json['updatedAt'], 0),
      extra: jsonMap(json['extra']),
    );
  }

  final String id;
  final String setId;
  final String name;

  /// Mode-specific configuration; [mode] is derived from it.
  final TrackConfig config;

  /// Index into the active theme's track palette (wraps around).
  final int colorIndex;

  /// Custom ARGB colour; when set it wins over [colorIndex].
  final int? customColor;

  final bool alarmSound;
  final bool vibration;
  final int sortIndex;

  /// Reserved: everything is always logged for now, there is no UI for this.
  final bool logEnabled;
  final bool archived;

  /// UTC milliseconds.
  final int createdAt;
  final int updatedAt;

  /// Free-form extension data (persisted, part of backups).
  final JsonMap extra;

  TrackMode get mode => config.mode;

  Track copyWith({
    String? id,
    String? setId,
    String? name,
    TrackConfig? config,
    int? colorIndex,
    int? Function()? customColor,
    bool? alarmSound,
    bool? vibration,
    int? sortIndex,
    bool? logEnabled,
    bool? archived,
    int? createdAt,
    int? updatedAt,
    JsonMap? extra,
  }) => Track(
    id: id ?? this.id,
    setId: setId ?? this.setId,
    name: name ?? this.name,
    config: config ?? this.config,
    colorIndex: colorIndex ?? this.colorIndex,
    customColor: customColor == null ? this.customColor : customColor(),
    alarmSound: alarmSound ?? this.alarmSound,
    vibration: vibration ?? this.vibration,
    sortIndex: sortIndex ?? this.sortIndex,
    logEnabled: logEnabled ?? this.logEnabled,
    archived: archived ?? this.archived,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    extra: extra ?? this.extra,
  );

  JsonMap toJson() => {
    'id': id,
    'setId': setId,
    'name': name,
    'mode': mode.name,
    'config': config.toJson(),
    'colorIndex': colorIndex,
    'customColor': customColor,
    'alarmSound': alarmSound,
    'vibration': vibration,
    'sortIndex': sortIndex,
    'logEnabled': logEnabled,
    'archived': archived,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'extra': extra,
  };

  @override
  bool operator ==(Object other) =>
      other is Track &&
      other.id == id &&
      other.setId == setId &&
      other.name == name &&
      other.config == config &&
      other.colorIndex == colorIndex &&
      other.customColor == customColor &&
      other.alarmSound == alarmSound &&
      other.vibration == vibration &&
      other.sortIndex == sortIndex &&
      other.logEnabled == logEnabled &&
      other.archived == archived &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      jsonMapEquals(other.extra, extra);

  @override
  int get hashCode => Object.hash(
    id,
    setId,
    name,
    config,
    colorIndex,
    customColor,
    alarmSound,
    vibration,
    sortIndex,
    logEnabled,
    archived,
    createdAt,
    updatedAt,
  );

  @override
  String toString() => 'Track($id, $name, ${mode.name})';
}
