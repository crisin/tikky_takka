import 'json_utils.dart';

/// A group of tracks (e.g. "Küche", "Training", "Festival"). One set is
/// active at a time.
final class TrackSet {
  const TrackSet({
    required this.id,
    required this.name,
    this.sortIndex = 0,
    this.themeId,
    this.uiPrefsOverride,
    this.scenePersonIds = const [],
    this.sceneSubstanceIds = const [],
    this.archived = false,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.extra = const {},
  });

  factory TrackSet.fromJson(JsonMap json) => TrackSet(
    id: jsonString(json['id'], ''),
    name: jsonString(json['name'], ''),
    sortIndex: jsonInt(json['sortIndex'], 0),
    themeId: jsonStringOrNull(json['themeId']),
    uiPrefsOverride: jsonMapOrNull(json['uiPrefsOverride']),
    scenePersonIds: _distinct(jsonStringList(json['scenePersonIds'])),
    sceneSubstanceIds: _distinct(jsonStringList(json['sceneSubstanceIds'])),
    archived: jsonBool(json['archived'], false),
    createdAt: jsonInt(json['createdAt'], 0),
    updatedAt: jsonInt(json['updatedAt'], 0),
    extra: jsonMap(json['extra']),
  );

  final String id;
  final String name;
  final int sortIndex;

  /// Optional theme override: id of a preset or custom theme. `null` means
  /// "use the app theme".
  final String? themeId;

  /// Optional partial UI preference override. Keys are the JSON keys of
  /// `UiPrefs` (see `UiPrefsKeys` in lib/theme/ui_prefs.dart); only keys that
  /// are present override the app-wide value. `null` means "no override".
  final JsonMap? uiPrefsOverride;

  /// The scene of this set, part 1: ids of the persons who are here ("wer
  /// ist dabei"). Empty = not set. Only what the user picked.
  final List<String> scenePersonIds;

  /// The scene of this set, part 2: ids of today's main substances ("was
  /// ist heute dran"), in the order the user chose. Empty = not set.
  final List<String> sceneSubstanceIds;

  /// Whether the user set up a scene for this set.
  bool get hasScene =>
      scenePersonIds.isNotEmpty || sceneSubstanceIds.isNotEmpty;

  static List<String> _distinct(List<String> ids) {
    final seen = <String>{};
    return [
      for (final id in ids)
        if (id.isNotEmpty && seen.add(id)) id,
    ];
  }

  final bool archived;

  /// UTC milliseconds.
  final int createdAt;
  final int updatedAt;

  /// Free-form extension data (persisted, part of backups).
  final JsonMap extra;

  TrackSet copyWith({
    String? id,
    String? name,
    int? sortIndex,
    String? Function()? themeId,
    JsonMap? Function()? uiPrefsOverride,
    List<String>? scenePersonIds,
    List<String>? sceneSubstanceIds,
    bool? archived,
    int? createdAt,
    int? updatedAt,
    JsonMap? extra,
  }) => TrackSet(
    id: id ?? this.id,
    name: name ?? this.name,
    sortIndex: sortIndex ?? this.sortIndex,
    themeId: themeId == null ? this.themeId : themeId(),
    uiPrefsOverride: uiPrefsOverride == null
        ? this.uiPrefsOverride
        : uiPrefsOverride(),
    scenePersonIds: scenePersonIds ?? this.scenePersonIds,
    sceneSubstanceIds: sceneSubstanceIds ?? this.sceneSubstanceIds,
    archived: archived ?? this.archived,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    extra: extra ?? this.extra,
  );

  JsonMap toJson() => {
    'id': id,
    'name': name,
    'sortIndex': sortIndex,
    'themeId': themeId,
    'uiPrefsOverride': uiPrefsOverride,
    'scenePersonIds': scenePersonIds,
    'sceneSubstanceIds': sceneSubstanceIds,
    'archived': archived,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'extra': extra,
  };

  @override
  bool operator ==(Object other) =>
      other is TrackSet &&
      other.id == id &&
      other.name == name &&
      other.sortIndex == sortIndex &&
      other.themeId == themeId &&
      jsonMapEquals(other.uiPrefsOverride, uiPrefsOverride) &&
      jsonListEquals(other.scenePersonIds, scenePersonIds) &&
      jsonListEquals(other.sceneSubstanceIds, sceneSubstanceIds) &&
      other.archived == archived &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      jsonMapEquals(other.extra, extra);

  @override
  int get hashCode =>
      Object.hash(id, name, sortIndex, themeId, archived, createdAt, updatedAt);

  @override
  String toString() => 'TrackSet($id, $name)';
}
