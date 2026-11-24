import 'dart:convert';

import '../db/app_database.dart';
import '../domain/domain.dart';

/// Conversions between drift rows and immutable domain objects.

/// Key inside the `extra_json` column of a set that holds its scene
/// (`{"personIds": [...], "substanceIds": [...]}`). The scene has no column
/// of its own; in the domain object it is `TrackSet.scenePersonIds` /
/// `TrackSet.sceneSubstanceIds` and never part of `TrackSet.extra`.
const String setSceneExtraKey = 'scene';
const String _scenePersonsKey = 'personIds';
const String _sceneSubstancesKey = 'substanceIds';

/// The `extra_json` value of [set]: its free-form extra data plus the scene.
String? encodeSetExtra(TrackSet set) => encodeJsonMapOrNull({
  for (final e in set.extra.entries)
    if (e.key != setSceneExtraKey) e.key: e.value,
  if (set.hasScene)
    setSceneExtraKey: {
      _scenePersonsKey: set.scenePersonIds,
      _sceneSubstancesKey: set.sceneSubstanceIds,
    },
});

extension SetRowMapper on SetRow {
  TrackSet toDomain() {
    final stored = decodeJsonMap(extraJson);
    final scene = jsonMap(stored.remove(setSceneExtraKey));
    // Through fromJson-like normalisation: no empty or duplicate ids.
    return TrackSet.fromJson({
      'scenePersonIds': scene[_scenePersonsKey],
      'sceneSubstanceIds': scene[_sceneSubstancesKey],
    }).copyWith(
      id: id,
      name: name,
      sortIndex: sortIndex,
      themeId: () => themeId,
      uiPrefsOverride: () => decodeJsonMapOrNull(uiPrefsOverrideJson),
      archived: archived,
      createdAt: createdAt,
      updatedAt: updatedAt,
      extra: stored,
    );
  }
}

extension TrackSetRowMapper on TrackSet {
  SetRow toRow() => SetRow(
    id: id,
    name: name,
    sortIndex: sortIndex,
    themeId: themeId,
    uiPrefsOverrideJson: encodeJsonMapOrNull(uiPrefsOverride),
    archived: archived,
    createdAt: createdAt,
    updatedAt: updatedAt,
    extraJson: encodeSetExtra(this),
  );
}

extension TrackRowMapper on TrackRow {
  Track toDomain() => Track(
    id: id,
    setId: setId,
    name: name,
    config: TrackConfig.fromJson(
      TrackMode.fromName(mode),
      decodeJsonMap(configJson),
    ),
    colorIndex: colorIndex,
    customColor: customColor,
    alarmSound: alarmSound,
    vibration: vibration,
    sortIndex: sortIndex,
    logEnabled: logEnabled,
    archived: archived,
    createdAt: createdAt,
    updatedAt: updatedAt,
    extra: decodeJsonMap(extraJson),
  );
}

extension TrackToRowMapper on Track {
  TrackRow toRow() => TrackRow(
    id: id,
    setId: setId,
    name: name,
    colorIndex: colorIndex,
    customColor: customColor,
    mode: mode.name,
    configJson: jsonEncode(config.toJson()),
    alarmSound: alarmSound,
    vibration: vibration,
    sortIndex: sortIndex,
    logEnabled: logEnabled,
    archived: archived,
    createdAt: createdAt,
    updatedAt: updatedAt,
    extraJson: encodeJsonMapOrNull(extra),
  );
}

extension SessionRowMapper on SessionRow {
  Session toDomain() => Session(
    id: id,
    trackId: trackId,
    config: TrackConfig.fromJson(
      TrackMode.fromName(mode),
      decodeJsonMap(configJson),
    ),
    startedAt: startedAt,
    endedAt: endedAt,
    note: note,
    createdAt: createdAt,
    updatedAt: updatedAt,
    extra: decodeJsonMap(extraJson),
  );
}

extension SessionToRowMapper on Session {
  SessionRow toRow() => SessionRow(
    id: id,
    trackId: trackId,
    mode: mode.name,
    configJson: jsonEncode(config.toJson()),
    startedAt: startedAt,
    endedAt: endedAt,
    note: note,
    createdAt: createdAt,
    updatedAt: updatedAt,
    extraJson: encodeJsonMapOrNull(extra),
  );
}

extension EventRowMapper on EventRow {
  /// `null` for rows with an event type this app version does not know.
  TrackEvent? toDomain() {
    final eventType = EventType.tryFromName(type);
    if (eventType == null) return null;
    return TrackEvent(
      id: id,
      sessionId: sessionId,
      trackId: trackId,
      type: eventType,
      at: at,
      seq: seq,
      label: label,
      personId: personId,
      substanceId: substanceId,
      amount: amount,
      note: note,
      createdAt: createdAt,
      updatedAt: updatedAt,
      extra: decodeJsonMap(extraJson),
    );
  }
}

extension TrackEventToRowMapper on TrackEvent {
  EventRow toRow() => EventRow(
    id: id,
    sessionId: sessionId,
    trackId: trackId,
    type: type.name,
    at: at,
    seq: seq,
    label: label,
    personId: personId,
    substanceId: substanceId,
    amount: amount,
    note: note,
    createdAt: createdAt,
    updatedAt: updatedAt,
    extraJson: encodeJsonMapOrNull(extra),
  );
}

extension EntryRowMapper on EntryRow {
  Entry toDomain() => Entry(
    id: id,
    at: at,
    personId: personId,
    substanceId: substanceId,
    amount: amount,
    note: note,
    createdAt: createdAt,
    updatedAt: updatedAt,
    extra: decodeJsonMap(extraJson),
  );
}

extension EntryToRowMapper on Entry {
  EntryRow toRow() => EntryRow(
    id: id,
    at: at,
    personId: personId,
    substanceId: substanceId,
    amount: amount,
    note: note,
    createdAt: createdAt,
    updatedAt: updatedAt,
    extraJson: encodeJsonMapOrNull(extra),
  );
}

extension PersonRowMapper on PersonRow {
  Person toDomain() => Person(
    id: id,
    name: name,
    color: color,
    sortIndex: sortIndex,
    archived: archived,
    note: note,
    createdAt: createdAt,
    updatedAt: updatedAt,
    extra: decodeJsonMap(extraJson),
  );
}

extension PersonToRowMapper on Person {
  PersonRow toRow() => PersonRow(
    id: id,
    name: name,
    color: color,
    sortIndex: sortIndex,
    archived: archived,
    note: note,
    createdAt: createdAt,
    updatedAt: updatedAt,
    extraJson: encodeJsonMapOrNull(extra),
  );
}

extension SubstanceRowMapper on SubstanceRow {
  Substance toDomain() => Substance(
    id: id,
    name: name,
    color: color,
    lockoutMs: lockoutMs,
    sortIndex: sortIndex,
    archived: archived,
    note: note,
    createdAt: createdAt,
    updatedAt: updatedAt,
    extra: decodeJsonMap(extraJson),
  );
}

extension SubstanceToRowMapper on Substance {
  SubstanceRow toRow() => SubstanceRow(
    id: id,
    name: name,
    color: color,
    lockoutMs: lockoutMs,
    sortIndex: sortIndex,
    archived: archived,
    note: note,
    createdAt: createdAt,
    updatedAt: updatedAt,
    extraJson: encodeJsonMapOrNull(extra),
  );
}

/// Maps event rows to domain events, dropping unknown types.
List<TrackEvent> eventsFromRows(Iterable<EventRow> rows) => [
  for (final r in rows) ?r.toDomain(),
];
