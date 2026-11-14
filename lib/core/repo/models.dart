import '../domain/domain.dart';

/// Generates unique ids (UUID v4 in production).
typedef IdGenerator = String Function();

/// The open (not yet stopped) session of a track with its events.
final class OpenSession {
  const OpenSession({required this.session, required this.events});

  final Session session;

  /// Chronological (`at`, then `seq`).
  final List<TrackEvent> events;

  String get trackId => session.trackId;
}

/// What a command did to a track; lets the UI pick haptics / snackbars.
enum TrackAction {
  /// Nothing happened (wrong state, unknown track, ...).
  none,
  started,
  paused,
  resumed,
  stopped,
  acknowledged,
  ticked,
  lapped,
}

/// Selects sessions for history and export.
final class HistoryFilter {
  const HistoryFilter({
    this.trackIds = const {},
    this.setId,
    this.fromMs,
    this.toMs,
    this.includeProtocol = true,
    this.includeOpen = false,
  });

  /// No restriction (closed sessions only).
  static const all = HistoryFilter();

  /// Restrict to these tracks; empty = all tracks.
  final Set<String> trackIds;

  /// Restrict to the tracks of this set; `null` = all sets.
  final String? setId;

  /// Sessions that started at or after this instant (UTC ms, inclusive).
  final int? fromMs;

  /// Sessions that started before this instant (UTC ms, exclusive).
  final int? toMs;

  /// Whether sessions of protocol tracks are included. History shows them
  /// (`true`); export passes its explicit opt-in switch here.
  final bool includeProtocol;

  /// Whether sessions that are still running are included.
  final bool includeOpen;

  bool get isUnrestricted =>
      trackIds.isEmpty && setId == null && fromMs == null && toMs == null;

  HistoryFilter copyWith({
    Set<String>? trackIds,
    String? Function()? setId,
    int? Function()? fromMs,
    int? Function()? toMs,
    bool? includeProtocol,
    bool? includeOpen,
  }) => HistoryFilter(
    trackIds: trackIds ?? this.trackIds,
    setId: setId == null ? this.setId : setId(),
    fromMs: fromMs == null ? this.fromMs : fromMs(),
    toMs: toMs == null ? this.toMs : toMs(),
    includeProtocol: includeProtocol ?? this.includeProtocol,
    includeOpen: includeOpen ?? this.includeOpen,
  );

  @override
  bool operator ==(Object other) =>
      other is HistoryFilter &&
      other.trackIds.length == trackIds.length &&
      other.trackIds.containsAll(trackIds) &&
      other.setId == setId &&
      other.fromMs == fromMs &&
      other.toMs == toMs &&
      other.includeProtocol == includeProtocol &&
      other.includeOpen == includeOpen;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(trackIds),
    setId,
    fromMs,
    toMs,
    includeProtocol,
    includeOpen,
  );
}

/// How often a person logged a substance on a track, over ALL its sessions
/// (open and closed), and when last. `null` ids are entries without a
/// person / without a substance. Orders the one-tap substance buttons.
final class SubstanceUse {
  const SubstanceUse({
    required this.personId,
    required this.substanceId,
    required this.count,
    required this.lastAt,
  });

  final String? personId;
  final String? substanceId;
  final int count;

  /// Wall time (UTC ms) of the most recent such entry.
  final int lastAt;

  @override
  bool operator ==(Object other) =>
      other is SubstanceUse &&
      other.personId == personId &&
      other.substanceId == substanceId &&
      other.count == count &&
      other.lastAt == lastAt;

  @override
  int get hashCode => Object.hash(personId, substanceId, count, lastAt);

  @override
  String toString() =>
      'SubstanceUse($personId, $substanceId x$count @$lastAt)';
}

/// A removed session with its events, kept by the UI to offer "Rückgängig".
final class DeletedSession {
  const DeletedSession({required this.session, required this.events});

  final Session session;
  final List<TrackEvent> events;
}

/// Everything stored in the database, for the JSON backup.
final class BackupData {
  const BackupData({
    this.schemaVersion = currentSchemaVersion,
    this.exportedAt = 0,
    this.sets = const [],
    this.tracks = const [],
    this.sessions = const [],
    this.events = const [],
    this.persons = const [],
    this.substances = const [],
    this.settings = const {},
  });

  /// Version of the backup JSON layout written by this app version.
  static const int currentSchemaVersion = 1;

  /// Value of the `app` field in the backup JSON.
  static const String appId = 'tikky_takka';

  /// Parses a decoded backup. Throws [FormatException] when the JSON is not
  /// a backup of this app or was written by a newer, incompatible version.
  factory BackupData.fromJson(JsonMap json) {
    if (json['app'] != appId) {
      throw const FormatException('Not a Tikky Takka backup');
    }
    final version = jsonInt(json['schemaVersion'], 0);
    if (version < 1 || version > currentSchemaVersion) {
      throw FormatException('Unsupported backup schema version $version');
    }
    List<JsonMap> maps(Object? v) => [
      if (v is List)
        for (final e in v)
          if (e is Map) jsonMap(e),
    ];
    final settings = jsonMap(json['settings']);
    return BackupData(
      schemaVersion: version,
      exportedAt: jsonInt(json['exportedAt'], 0),
      sets: [for (final m in maps(json['sets'])) TrackSet.fromJson(m)],
      tracks: [for (final m in maps(json['tracks'])) Track.fromJson(m)],
      sessions: [for (final m in maps(json['sessions'])) Session.fromJson(m)],
      events: [
        for (final m in maps(json['events'])) ?TrackEvent.tryFromJson(m),
      ],
      persons: [for (final m in maps(json['persons'])) Person.fromJson(m)],
      substances: [
        for (final m in maps(json['substances'])) Substance.fromJson(m),
      ],
      settings: {
        for (final e in settings.entries)
          if (e.value is String) e.key: e.value! as String,
      },
    );
  }

  final int schemaVersion;

  /// UTC milliseconds.
  final int exportedAt;
  final List<TrackSet> sets;
  final List<Track> tracks;
  final List<Session> sessions;
  final List<TrackEvent> events;
  final List<Person> persons;
  final List<Substance> substances;

  /// Raw key-value settings (custom themes, theme selection, UI prefs, ...).
  final Map<String, String> settings;

  JsonMap toJson() => {
    'app': appId,
    'schemaVersion': schemaVersion,
    'exportedAt': exportedAt,
    'sets': [for (final s in sets) s.toJson()],
    'tracks': [for (final t in tracks) t.toJson()],
    'sessions': [for (final s in sessions) s.toJson()],
    'events': [for (final e in events) e.toJson()],
    'persons': [for (final p in persons) p.toJson()],
    'substances': [for (final s in substances) s.toJson()],
    'settings': settings,
  };
}

/// Result of merging a backup into the database.
final class ImportReport {
  const ImportReport({
    this.inserted = const {},
    this.updated = const {},
    this.skipped = const {},
  });

  /// Table keys used in the maps below.
  static const tables = [
    'sets',
    'tracks',
    'sessions',
    'events',
    'persons',
    'substances',
    'settings',
  ];

  /// Rows that did not exist and were added, per table.
  final Map<String, int> inserted;

  /// Existing rows replaced by a newer version from the backup, per table.
  final Map<String, int> updated;

  /// Existing rows kept because they are the same or newer, per table.
  final Map<String, int> skipped;

  int get insertedTotal => inserted.values.fold(0, (a, b) => a + b);
  int get updatedTotal => updated.values.fold(0, (a, b) => a + b);
  int get skippedTotal => skipped.values.fold(0, (a, b) => a + b);
}
