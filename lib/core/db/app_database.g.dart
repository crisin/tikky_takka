// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TrackSetsTable extends TrackSets
    with TableInfo<$TrackSetsTable, SetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackSetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _themeIdMeta = const VerificationMeta(
    'themeId',
  );
  @override
  late final GeneratedColumn<String> themeId = GeneratedColumn<String>(
    'theme_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _uiPrefsOverrideJsonMeta =
      const VerificationMeta('uiPrefsOverrideJson');
  @override
  late final GeneratedColumn<String> uiPrefsOverrideJson =
      GeneratedColumn<String>(
        'ui_prefs_override_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _extraJsonMeta = const VerificationMeta(
    'extraJson',
  );
  @override
  late final GeneratedColumn<String> extraJson = GeneratedColumn<String>(
    'extra_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    sortIndex,
    themeId,
    uiPrefsOverrideJson,
    archived,
    createdAt,
    updatedAt,
    extraJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'track_sets';
  @override
  VerificationContext validateIntegrity(
    Insertable<SetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    }
    if (data.containsKey('theme_id')) {
      context.handle(
        _themeIdMeta,
        themeId.isAcceptableOrUnknown(data['theme_id']!, _themeIdMeta),
      );
    }
    if (data.containsKey('ui_prefs_override_json')) {
      context.handle(
        _uiPrefsOverrideJsonMeta,
        uiPrefsOverrideJson.isAcceptableOrUnknown(
          data['ui_prefs_override_json']!,
          _uiPrefsOverrideJsonMeta,
        ),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('extra_json')) {
      context.handle(
        _extraJsonMeta,
        extraJson.isAcceptableOrUnknown(data['extra_json']!, _extraJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SetRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      )!,
      themeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme_id'],
      ),
      uiPrefsOverrideJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ui_prefs_override_json'],
      ),
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      extraJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extra_json'],
      ),
    );
  }

  @override
  $TrackSetsTable createAlias(String alias) {
    return $TrackSetsTable(attachedDatabase, alias);
  }
}

class SetRow extends DataClass implements Insertable<SetRow> {
  final String id;
  final String name;
  final int sortIndex;

  /// Optional theme override (id of a preset or custom theme).
  final String? themeId;

  /// Optional partial UiPrefs override as a JSON object.
  final String? uiPrefsOverrideJson;
  final bool archived;
  final int createdAt;
  final int updatedAt;
  final String? extraJson;
  const SetRow({
    required this.id,
    required this.name,
    required this.sortIndex,
    this.themeId,
    this.uiPrefsOverrideJson,
    required this.archived,
    required this.createdAt,
    required this.updatedAt,
    this.extraJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['sort_index'] = Variable<int>(sortIndex);
    if (!nullToAbsent || themeId != null) {
      map['theme_id'] = Variable<String>(themeId);
    }
    if (!nullToAbsent || uiPrefsOverrideJson != null) {
      map['ui_prefs_override_json'] = Variable<String>(uiPrefsOverrideJson);
    }
    map['archived'] = Variable<bool>(archived);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || extraJson != null) {
      map['extra_json'] = Variable<String>(extraJson);
    }
    return map;
  }

  TrackSetsCompanion toCompanion(bool nullToAbsent) {
    return TrackSetsCompanion(
      id: Value(id),
      name: Value(name),
      sortIndex: Value(sortIndex),
      themeId: themeId == null && nullToAbsent
          ? const Value.absent()
          : Value(themeId),
      uiPrefsOverrideJson: uiPrefsOverrideJson == null && nullToAbsent
          ? const Value.absent()
          : Value(uiPrefsOverrideJson),
      archived: Value(archived),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      extraJson: extraJson == null && nullToAbsent
          ? const Value.absent()
          : Value(extraJson),
    );
  }

  factory SetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SetRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
      themeId: serializer.fromJson<String?>(json['themeId']),
      uiPrefsOverrideJson: serializer.fromJson<String?>(
        json['uiPrefsOverrideJson'],
      ),
      archived: serializer.fromJson<bool>(json['archived']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      extraJson: serializer.fromJson<String?>(json['extraJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'sortIndex': serializer.toJson<int>(sortIndex),
      'themeId': serializer.toJson<String?>(themeId),
      'uiPrefsOverrideJson': serializer.toJson<String?>(uiPrefsOverrideJson),
      'archived': serializer.toJson<bool>(archived),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'extraJson': serializer.toJson<String?>(extraJson),
    };
  }

  SetRow copyWith({
    String? id,
    String? name,
    int? sortIndex,
    Value<String?> themeId = const Value.absent(),
    Value<String?> uiPrefsOverrideJson = const Value.absent(),
    bool? archived,
    int? createdAt,
    int? updatedAt,
    Value<String?> extraJson = const Value.absent(),
  }) => SetRow(
    id: id ?? this.id,
    name: name ?? this.name,
    sortIndex: sortIndex ?? this.sortIndex,
    themeId: themeId.present ? themeId.value : this.themeId,
    uiPrefsOverrideJson: uiPrefsOverrideJson.present
        ? uiPrefsOverrideJson.value
        : this.uiPrefsOverrideJson,
    archived: archived ?? this.archived,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    extraJson: extraJson.present ? extraJson.value : this.extraJson,
  );
  SetRow copyWithCompanion(TrackSetsCompanion data) {
    return SetRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
      themeId: data.themeId.present ? data.themeId.value : this.themeId,
      uiPrefsOverrideJson: data.uiPrefsOverrideJson.present
          ? data.uiPrefsOverrideJson.value
          : this.uiPrefsOverrideJson,
      archived: data.archived.present ? data.archived.value : this.archived,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      extraJson: data.extraJson.present ? data.extraJson.value : this.extraJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SetRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('themeId: $themeId, ')
          ..write('uiPrefsOverrideJson: $uiPrefsOverrideJson, ')
          ..write('archived: $archived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('extraJson: $extraJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    sortIndex,
    themeId,
    uiPrefsOverrideJson,
    archived,
    createdAt,
    updatedAt,
    extraJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SetRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.sortIndex == this.sortIndex &&
          other.themeId == this.themeId &&
          other.uiPrefsOverrideJson == this.uiPrefsOverrideJson &&
          other.archived == this.archived &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.extraJson == this.extraJson);
}

class TrackSetsCompanion extends UpdateCompanion<SetRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> sortIndex;
  final Value<String?> themeId;
  final Value<String?> uiPrefsOverrideJson;
  final Value<bool> archived;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String?> extraJson;
  final Value<int> rowid;
  const TrackSetsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.themeId = const Value.absent(),
    this.uiPrefsOverrideJson = const Value.absent(),
    this.archived = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.extraJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrackSetsCompanion.insert({
    required String id,
    required String name,
    this.sortIndex = const Value.absent(),
    this.themeId = const Value.absent(),
    this.uiPrefsOverrideJson = const Value.absent(),
    this.archived = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.extraJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<SetRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? sortIndex,
    Expression<String>? themeId,
    Expression<String>? uiPrefsOverrideJson,
    Expression<bool>? archived,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? extraJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sortIndex != null) 'sort_index': sortIndex,
      if (themeId != null) 'theme_id': themeId,
      if (uiPrefsOverrideJson != null)
        'ui_prefs_override_json': uiPrefsOverrideJson,
      if (archived != null) 'archived': archived,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (extraJson != null) 'extra_json': extraJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrackSetsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? sortIndex,
    Value<String?>? themeId,
    Value<String?>? uiPrefsOverrideJson,
    Value<bool>? archived,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String?>? extraJson,
    Value<int>? rowid,
  }) {
    return TrackSetsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sortIndex: sortIndex ?? this.sortIndex,
      themeId: themeId ?? this.themeId,
      uiPrefsOverrideJson: uiPrefsOverrideJson ?? this.uiPrefsOverrideJson,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      extraJson: extraJson ?? this.extraJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    if (themeId.present) {
      map['theme_id'] = Variable<String>(themeId.value);
    }
    if (uiPrefsOverrideJson.present) {
      map['ui_prefs_override_json'] = Variable<String>(
        uiPrefsOverrideJson.value,
      );
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (extraJson.present) {
      map['extra_json'] = Variable<String>(extraJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackSetsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('themeId: $themeId, ')
          ..write('uiPrefsOverrideJson: $uiPrefsOverrideJson, ')
          ..write('archived: $archived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('extraJson: $extraJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TracksTable extends Tracks with TableInfo<$TracksTable, TrackRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _setIdMeta = const VerificationMeta('setId');
  @override
  late final GeneratedColumn<String> setId = GeneratedColumn<String>(
    'set_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorIndexMeta = const VerificationMeta(
    'colorIndex',
  );
  @override
  late final GeneratedColumn<int> colorIndex = GeneratedColumn<int>(
    'color_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _customColorMeta = const VerificationMeta(
    'customColor',
  );
  @override
  late final GeneratedColumn<int> customColor = GeneratedColumn<int>(
    'custom_color',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _configJsonMeta = const VerificationMeta(
    'configJson',
  );
  @override
  late final GeneratedColumn<String> configJson = GeneratedColumn<String>(
    'config_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _alarmSoundMeta = const VerificationMeta(
    'alarmSound',
  );
  @override
  late final GeneratedColumn<bool> alarmSound = GeneratedColumn<bool>(
    'alarm_sound',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("alarm_sound" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _vibrationMeta = const VerificationMeta(
    'vibration',
  );
  @override
  late final GeneratedColumn<bool> vibration = GeneratedColumn<bool>(
    'vibration',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("vibration" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _logEnabledMeta = const VerificationMeta(
    'logEnabled',
  );
  @override
  late final GeneratedColumn<bool> logEnabled = GeneratedColumn<bool>(
    'log_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("log_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _extraJsonMeta = const VerificationMeta(
    'extraJson',
  );
  @override
  late final GeneratedColumn<String> extraJson = GeneratedColumn<String>(
    'extra_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    setId,
    name,
    colorIndex,
    customColor,
    mode,
    configJson,
    alarmSound,
    vibration,
    sortIndex,
    logEnabled,
    archived,
    createdAt,
    updatedAt,
    extraJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrackRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('set_id')) {
      context.handle(
        _setIdMeta,
        setId.isAcceptableOrUnknown(data['set_id']!, _setIdMeta),
      );
    } else if (isInserting) {
      context.missing(_setIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_index')) {
      context.handle(
        _colorIndexMeta,
        colorIndex.isAcceptableOrUnknown(data['color_index']!, _colorIndexMeta),
      );
    }
    if (data.containsKey('custom_color')) {
      context.handle(
        _customColorMeta,
        customColor.isAcceptableOrUnknown(
          data['custom_color']!,
          _customColorMeta,
        ),
      );
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('config_json')) {
      context.handle(
        _configJsonMeta,
        configJson.isAcceptableOrUnknown(data['config_json']!, _configJsonMeta),
      );
    }
    if (data.containsKey('alarm_sound')) {
      context.handle(
        _alarmSoundMeta,
        alarmSound.isAcceptableOrUnknown(data['alarm_sound']!, _alarmSoundMeta),
      );
    }
    if (data.containsKey('vibration')) {
      context.handle(
        _vibrationMeta,
        vibration.isAcceptableOrUnknown(data['vibration']!, _vibrationMeta),
      );
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    }
    if (data.containsKey('log_enabled')) {
      context.handle(
        _logEnabledMeta,
        logEnabled.isAcceptableOrUnknown(data['log_enabled']!, _logEnabledMeta),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('extra_json')) {
      context.handle(
        _extraJsonMeta,
        extraJson.isAcceptableOrUnknown(data['extra_json']!, _extraJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TrackRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      setId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}set_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_index'],
      )!,
      customColor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}custom_color'],
      ),
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      configJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config_json'],
      )!,
      alarmSound: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}alarm_sound'],
      )!,
      vibration: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}vibration'],
      )!,
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      )!,
      logEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}log_enabled'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      extraJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extra_json'],
      ),
    );
  }

  @override
  $TracksTable createAlias(String alias) {
    return $TracksTable(attachedDatabase, alias);
  }
}

class TrackRow extends DataClass implements Insertable<TrackRow> {
  final String id;
  final String setId;
  final String name;

  /// Index into the theme's track palette.
  final int colorIndex;

  /// Custom ARGB colour; wins over [colorIndex] when set.
  final int? customColor;

  /// `TrackMode.name`.
  final String mode;

  /// Mode-specific configuration as a JSON object.
  final String configJson;
  final bool alarmSound;
  final bool vibration;
  final int sortIndex;
  final bool logEnabled;
  final bool archived;
  final int createdAt;
  final int updatedAt;
  final String? extraJson;
  const TrackRow({
    required this.id,
    required this.setId,
    required this.name,
    required this.colorIndex,
    this.customColor,
    required this.mode,
    required this.configJson,
    required this.alarmSound,
    required this.vibration,
    required this.sortIndex,
    required this.logEnabled,
    required this.archived,
    required this.createdAt,
    required this.updatedAt,
    this.extraJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['set_id'] = Variable<String>(setId);
    map['name'] = Variable<String>(name);
    map['color_index'] = Variable<int>(colorIndex);
    if (!nullToAbsent || customColor != null) {
      map['custom_color'] = Variable<int>(customColor);
    }
    map['mode'] = Variable<String>(mode);
    map['config_json'] = Variable<String>(configJson);
    map['alarm_sound'] = Variable<bool>(alarmSound);
    map['vibration'] = Variable<bool>(vibration);
    map['sort_index'] = Variable<int>(sortIndex);
    map['log_enabled'] = Variable<bool>(logEnabled);
    map['archived'] = Variable<bool>(archived);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || extraJson != null) {
      map['extra_json'] = Variable<String>(extraJson);
    }
    return map;
  }

  TracksCompanion toCompanion(bool nullToAbsent) {
    return TracksCompanion(
      id: Value(id),
      setId: Value(setId),
      name: Value(name),
      colorIndex: Value(colorIndex),
      customColor: customColor == null && nullToAbsent
          ? const Value.absent()
          : Value(customColor),
      mode: Value(mode),
      configJson: Value(configJson),
      alarmSound: Value(alarmSound),
      vibration: Value(vibration),
      sortIndex: Value(sortIndex),
      logEnabled: Value(logEnabled),
      archived: Value(archived),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      extraJson: extraJson == null && nullToAbsent
          ? const Value.absent()
          : Value(extraJson),
    );
  }

  factory TrackRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackRow(
      id: serializer.fromJson<String>(json['id']),
      setId: serializer.fromJson<String>(json['setId']),
      name: serializer.fromJson<String>(json['name']),
      colorIndex: serializer.fromJson<int>(json['colorIndex']),
      customColor: serializer.fromJson<int?>(json['customColor']),
      mode: serializer.fromJson<String>(json['mode']),
      configJson: serializer.fromJson<String>(json['configJson']),
      alarmSound: serializer.fromJson<bool>(json['alarmSound']),
      vibration: serializer.fromJson<bool>(json['vibration']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
      logEnabled: serializer.fromJson<bool>(json['logEnabled']),
      archived: serializer.fromJson<bool>(json['archived']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      extraJson: serializer.fromJson<String?>(json['extraJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'setId': serializer.toJson<String>(setId),
      'name': serializer.toJson<String>(name),
      'colorIndex': serializer.toJson<int>(colorIndex),
      'customColor': serializer.toJson<int?>(customColor),
      'mode': serializer.toJson<String>(mode),
      'configJson': serializer.toJson<String>(configJson),
      'alarmSound': serializer.toJson<bool>(alarmSound),
      'vibration': serializer.toJson<bool>(vibration),
      'sortIndex': serializer.toJson<int>(sortIndex),
      'logEnabled': serializer.toJson<bool>(logEnabled),
      'archived': serializer.toJson<bool>(archived),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'extraJson': serializer.toJson<String?>(extraJson),
    };
  }

  TrackRow copyWith({
    String? id,
    String? setId,
    String? name,
    int? colorIndex,
    Value<int?> customColor = const Value.absent(),
    String? mode,
    String? configJson,
    bool? alarmSound,
    bool? vibration,
    int? sortIndex,
    bool? logEnabled,
    bool? archived,
    int? createdAt,
    int? updatedAt,
    Value<String?> extraJson = const Value.absent(),
  }) => TrackRow(
    id: id ?? this.id,
    setId: setId ?? this.setId,
    name: name ?? this.name,
    colorIndex: colorIndex ?? this.colorIndex,
    customColor: customColor.present ? customColor.value : this.customColor,
    mode: mode ?? this.mode,
    configJson: configJson ?? this.configJson,
    alarmSound: alarmSound ?? this.alarmSound,
    vibration: vibration ?? this.vibration,
    sortIndex: sortIndex ?? this.sortIndex,
    logEnabled: logEnabled ?? this.logEnabled,
    archived: archived ?? this.archived,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    extraJson: extraJson.present ? extraJson.value : this.extraJson,
  );
  TrackRow copyWithCompanion(TracksCompanion data) {
    return TrackRow(
      id: data.id.present ? data.id.value : this.id,
      setId: data.setId.present ? data.setId.value : this.setId,
      name: data.name.present ? data.name.value : this.name,
      colorIndex: data.colorIndex.present
          ? data.colorIndex.value
          : this.colorIndex,
      customColor: data.customColor.present
          ? data.customColor.value
          : this.customColor,
      mode: data.mode.present ? data.mode.value : this.mode,
      configJson: data.configJson.present
          ? data.configJson.value
          : this.configJson,
      alarmSound: data.alarmSound.present
          ? data.alarmSound.value
          : this.alarmSound,
      vibration: data.vibration.present ? data.vibration.value : this.vibration,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
      logEnabled: data.logEnabled.present
          ? data.logEnabled.value
          : this.logEnabled,
      archived: data.archived.present ? data.archived.value : this.archived,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      extraJson: data.extraJson.present ? data.extraJson.value : this.extraJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackRow(')
          ..write('id: $id, ')
          ..write('setId: $setId, ')
          ..write('name: $name, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('customColor: $customColor, ')
          ..write('mode: $mode, ')
          ..write('configJson: $configJson, ')
          ..write('alarmSound: $alarmSound, ')
          ..write('vibration: $vibration, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('logEnabled: $logEnabled, ')
          ..write('archived: $archived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('extraJson: $extraJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    setId,
    name,
    colorIndex,
    customColor,
    mode,
    configJson,
    alarmSound,
    vibration,
    sortIndex,
    logEnabled,
    archived,
    createdAt,
    updatedAt,
    extraJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackRow &&
          other.id == this.id &&
          other.setId == this.setId &&
          other.name == this.name &&
          other.colorIndex == this.colorIndex &&
          other.customColor == this.customColor &&
          other.mode == this.mode &&
          other.configJson == this.configJson &&
          other.alarmSound == this.alarmSound &&
          other.vibration == this.vibration &&
          other.sortIndex == this.sortIndex &&
          other.logEnabled == this.logEnabled &&
          other.archived == this.archived &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.extraJson == this.extraJson);
}

class TracksCompanion extends UpdateCompanion<TrackRow> {
  final Value<String> id;
  final Value<String> setId;
  final Value<String> name;
  final Value<int> colorIndex;
  final Value<int?> customColor;
  final Value<String> mode;
  final Value<String> configJson;
  final Value<bool> alarmSound;
  final Value<bool> vibration;
  final Value<int> sortIndex;
  final Value<bool> logEnabled;
  final Value<bool> archived;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String?> extraJson;
  final Value<int> rowid;
  const TracksCompanion({
    this.id = const Value.absent(),
    this.setId = const Value.absent(),
    this.name = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.customColor = const Value.absent(),
    this.mode = const Value.absent(),
    this.configJson = const Value.absent(),
    this.alarmSound = const Value.absent(),
    this.vibration = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.logEnabled = const Value.absent(),
    this.archived = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.extraJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TracksCompanion.insert({
    required String id,
    required String setId,
    required String name,
    this.colorIndex = const Value.absent(),
    this.customColor = const Value.absent(),
    required String mode,
    this.configJson = const Value.absent(),
    this.alarmSound = const Value.absent(),
    this.vibration = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.logEnabled = const Value.absent(),
    this.archived = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.extraJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       setId = Value(setId),
       name = Value(name),
       mode = Value(mode);
  static Insertable<TrackRow> custom({
    Expression<String>? id,
    Expression<String>? setId,
    Expression<String>? name,
    Expression<int>? colorIndex,
    Expression<int>? customColor,
    Expression<String>? mode,
    Expression<String>? configJson,
    Expression<bool>? alarmSound,
    Expression<bool>? vibration,
    Expression<int>? sortIndex,
    Expression<bool>? logEnabled,
    Expression<bool>? archived,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? extraJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (setId != null) 'set_id': setId,
      if (name != null) 'name': name,
      if (colorIndex != null) 'color_index': colorIndex,
      if (customColor != null) 'custom_color': customColor,
      if (mode != null) 'mode': mode,
      if (configJson != null) 'config_json': configJson,
      if (alarmSound != null) 'alarm_sound': alarmSound,
      if (vibration != null) 'vibration': vibration,
      if (sortIndex != null) 'sort_index': sortIndex,
      if (logEnabled != null) 'log_enabled': logEnabled,
      if (archived != null) 'archived': archived,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (extraJson != null) 'extra_json': extraJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TracksCompanion copyWith({
    Value<String>? id,
    Value<String>? setId,
    Value<String>? name,
    Value<int>? colorIndex,
    Value<int?>? customColor,
    Value<String>? mode,
    Value<String>? configJson,
    Value<bool>? alarmSound,
    Value<bool>? vibration,
    Value<int>? sortIndex,
    Value<bool>? logEnabled,
    Value<bool>? archived,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String?>? extraJson,
    Value<int>? rowid,
  }) {
    return TracksCompanion(
      id: id ?? this.id,
      setId: setId ?? this.setId,
      name: name ?? this.name,
      colorIndex: colorIndex ?? this.colorIndex,
      customColor: customColor ?? this.customColor,
      mode: mode ?? this.mode,
      configJson: configJson ?? this.configJson,
      alarmSound: alarmSound ?? this.alarmSound,
      vibration: vibration ?? this.vibration,
      sortIndex: sortIndex ?? this.sortIndex,
      logEnabled: logEnabled ?? this.logEnabled,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      extraJson: extraJson ?? this.extraJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (setId.present) {
      map['set_id'] = Variable<String>(setId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorIndex.present) {
      map['color_index'] = Variable<int>(colorIndex.value);
    }
    if (customColor.present) {
      map['custom_color'] = Variable<int>(customColor.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (configJson.present) {
      map['config_json'] = Variable<String>(configJson.value);
    }
    if (alarmSound.present) {
      map['alarm_sound'] = Variable<bool>(alarmSound.value);
    }
    if (vibration.present) {
      map['vibration'] = Variable<bool>(vibration.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    if (logEnabled.present) {
      map['log_enabled'] = Variable<bool>(logEnabled.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (extraJson.present) {
      map['extra_json'] = Variable<String>(extraJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TracksCompanion(')
          ..write('id: $id, ')
          ..write('setId: $setId, ')
          ..write('name: $name, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('customColor: $customColor, ')
          ..write('mode: $mode, ')
          ..write('configJson: $configJson, ')
          ..write('alarmSound: $alarmSound, ')
          ..write('vibration: $vibration, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('logEnabled: $logEnabled, ')
          ..write('archived: $archived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('extraJson: $extraJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionsTable extends Sessions
    with TableInfo<$SessionsTable, SessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _configJsonMeta = const VerificationMeta(
    'configJson',
  );
  @override
  late final GeneratedColumn<String> configJson = GeneratedColumn<String>(
    'config_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<int> endedAt = GeneratedColumn<int>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _extraJsonMeta = const VerificationMeta(
    'extraJson',
  );
  @override
  late final GeneratedColumn<String> extraJson = GeneratedColumn<String>(
    'extra_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    trackId,
    mode,
    configJson,
    startedAt,
    endedAt,
    note,
    createdAt,
    updatedAt,
    extraJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('config_json')) {
      context.handle(
        _configJsonMeta,
        configJson.isAcceptableOrUnknown(data['config_json']!, _configJsonMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('extra_json')) {
      context.handle(
        _extraJsonMeta,
        extraJson.isAcceptableOrUnknown(data['extra_json']!, _extraJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_id'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      configJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config_json'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ended_at'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      extraJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extra_json'],
      ),
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class SessionRow extends DataClass implements Insertable<SessionRow> {
  final String id;
  final String trackId;

  /// `TrackMode.name` at the time of the session.
  final String mode;

  /// Snapshot of the track configuration used by this session.
  final String configJson;
  final int startedAt;

  /// NULL while the session is open.
  final int? endedAt;
  final String? note;
  final int createdAt;
  final int updatedAt;
  final String? extraJson;
  const SessionRow({
    required this.id,
    required this.trackId,
    required this.mode,
    required this.configJson,
    required this.startedAt,
    this.endedAt,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.extraJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['track_id'] = Variable<String>(trackId);
    map['mode'] = Variable<String>(mode);
    map['config_json'] = Variable<String>(configJson);
    map['started_at'] = Variable<int>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<int>(endedAt);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || extraJson != null) {
      map['extra_json'] = Variable<String>(extraJson);
    }
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      trackId: Value(trackId),
      mode: Value(mode),
      configJson: Value(configJson),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      extraJson: extraJson == null && nullToAbsent
          ? const Value.absent()
          : Value(extraJson),
    );
  }

  factory SessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionRow(
      id: serializer.fromJson<String>(json['id']),
      trackId: serializer.fromJson<String>(json['trackId']),
      mode: serializer.fromJson<String>(json['mode']),
      configJson: serializer.fromJson<String>(json['configJson']),
      startedAt: serializer.fromJson<int>(json['startedAt']),
      endedAt: serializer.fromJson<int?>(json['endedAt']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      extraJson: serializer.fromJson<String?>(json['extraJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'trackId': serializer.toJson<String>(trackId),
      'mode': serializer.toJson<String>(mode),
      'configJson': serializer.toJson<String>(configJson),
      'startedAt': serializer.toJson<int>(startedAt),
      'endedAt': serializer.toJson<int?>(endedAt),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'extraJson': serializer.toJson<String?>(extraJson),
    };
  }

  SessionRow copyWith({
    String? id,
    String? trackId,
    String? mode,
    String? configJson,
    int? startedAt,
    Value<int?> endedAt = const Value.absent(),
    Value<String?> note = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<String?> extraJson = const Value.absent(),
  }) => SessionRow(
    id: id ?? this.id,
    trackId: trackId ?? this.trackId,
    mode: mode ?? this.mode,
    configJson: configJson ?? this.configJson,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    extraJson: extraJson.present ? extraJson.value : this.extraJson,
  );
  SessionRow copyWithCompanion(SessionsCompanion data) {
    return SessionRow(
      id: data.id.present ? data.id.value : this.id,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      mode: data.mode.present ? data.mode.value : this.mode,
      configJson: data.configJson.present
          ? data.configJson.value
          : this.configJson,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      extraJson: data.extraJson.present ? data.extraJson.value : this.extraJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionRow(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('mode: $mode, ')
          ..write('configJson: $configJson, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('extraJson: $extraJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    trackId,
    mode,
    configJson,
    startedAt,
    endedAt,
    note,
    createdAt,
    updatedAt,
    extraJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionRow &&
          other.id == this.id &&
          other.trackId == this.trackId &&
          other.mode == this.mode &&
          other.configJson == this.configJson &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.extraJson == this.extraJson);
}

class SessionsCompanion extends UpdateCompanion<SessionRow> {
  final Value<String> id;
  final Value<String> trackId;
  final Value<String> mode;
  final Value<String> configJson;
  final Value<int> startedAt;
  final Value<int?> endedAt;
  final Value<String?> note;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String?> extraJson;
  final Value<int> rowid;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.trackId = const Value.absent(),
    this.mode = const Value.absent(),
    this.configJson = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.extraJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    required String id,
    required String trackId,
    required String mode,
    this.configJson = const Value.absent(),
    required int startedAt,
    this.endedAt = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.extraJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       trackId = Value(trackId),
       mode = Value(mode),
       startedAt = Value(startedAt);
  static Insertable<SessionRow> custom({
    Expression<String>? id,
    Expression<String>? trackId,
    Expression<String>? mode,
    Expression<String>? configJson,
    Expression<int>? startedAt,
    Expression<int>? endedAt,
    Expression<String>? note,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? extraJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackId != null) 'track_id': trackId,
      if (mode != null) 'mode': mode,
      if (configJson != null) 'config_json': configJson,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (extraJson != null) 'extra_json': extraJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? trackId,
    Value<String>? mode,
    Value<String>? configJson,
    Value<int>? startedAt,
    Value<int?>? endedAt,
    Value<String?>? note,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String?>? extraJson,
    Value<int>? rowid,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      mode: mode ?? this.mode,
      configJson: configJson ?? this.configJson,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      extraJson: extraJson ?? this.extraJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (configJson.present) {
      map['config_json'] = Variable<String>(configJson.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<int>(endedAt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (extraJson.present) {
      map['extra_json'] = Variable<String>(extraJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('mode: $mode, ')
          ..write('configJson: $configJson, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('extraJson: $extraJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EventsTable extends Events with TableInfo<$EventsTable, EventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<String> trackId = GeneratedColumn<String>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<int> at = GeneratedColumn<int>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _personIdMeta = const VerificationMeta(
    'personId',
  );
  @override
  late final GeneratedColumn<String> personId = GeneratedColumn<String>(
    'person_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _substanceIdMeta = const VerificationMeta(
    'substanceId',
  );
  @override
  late final GeneratedColumn<String> substanceId = GeneratedColumn<String>(
    'substance_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<String> amount = GeneratedColumn<String>(
    'amount',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _extraJsonMeta = const VerificationMeta(
    'extraJson',
  );
  @override
  late final GeneratedColumn<String> extraJson = GeneratedColumn<String>(
    'extra_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
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
    extraJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'events';
  @override
  VerificationContext validateIntegrity(
    Insertable<EventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('person_id')) {
      context.handle(
        _personIdMeta,
        personId.isAcceptableOrUnknown(data['person_id']!, _personIdMeta),
      );
    }
    if (data.containsKey('substance_id')) {
      context.handle(
        _substanceIdMeta,
        substanceId.isAcceptableOrUnknown(
          data['substance_id']!,
          _substanceIdMeta,
        ),
      );
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('extra_json')) {
      context.handle(
        _extraJsonMeta,
        extraJson.isAcceptableOrUnknown(data['extra_json']!, _extraJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      personId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}person_id'],
      ),
      substanceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}substance_id'],
      ),
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}amount'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      extraJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extra_json'],
      ),
    );
  }

  @override
  $EventsTable createAlias(String alias) {
    return $EventsTable(attachedDatabase, alias);
  }
}

class EventRow extends DataClass implements Insertable<EventRow> {
  final String id;
  final String sessionId;
  final String trackId;

  /// `EventType.name`.
  final String type;

  /// UTC milliseconds.
  final int at;

  /// Insertion order inside the session (tie-breaker for equal `at`).
  final int seq;
  final String? label;
  final String? personId;
  final String? substanceId;

  /// Free text.
  final String? amount;
  final String? note;
  final int createdAt;
  final int updatedAt;
  final String? extraJson;
  const EventRow({
    required this.id,
    required this.sessionId,
    required this.trackId,
    required this.type,
    required this.at,
    required this.seq,
    this.label,
    this.personId,
    this.substanceId,
    this.amount,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.extraJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['track_id'] = Variable<String>(trackId);
    map['type'] = Variable<String>(type);
    map['at'] = Variable<int>(at);
    map['seq'] = Variable<int>(seq);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    if (!nullToAbsent || personId != null) {
      map['person_id'] = Variable<String>(personId);
    }
    if (!nullToAbsent || substanceId != null) {
      map['substance_id'] = Variable<String>(substanceId);
    }
    if (!nullToAbsent || amount != null) {
      map['amount'] = Variable<String>(amount);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || extraJson != null) {
      map['extra_json'] = Variable<String>(extraJson);
    }
    return map;
  }

  EventsCompanion toCompanion(bool nullToAbsent) {
    return EventsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      trackId: Value(trackId),
      type: Value(type),
      at: Value(at),
      seq: Value(seq),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      personId: personId == null && nullToAbsent
          ? const Value.absent()
          : Value(personId),
      substanceId: substanceId == null && nullToAbsent
          ? const Value.absent()
          : Value(substanceId),
      amount: amount == null && nullToAbsent
          ? const Value.absent()
          : Value(amount),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      extraJson: extraJson == null && nullToAbsent
          ? const Value.absent()
          : Value(extraJson),
    );
  }

  factory EventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      trackId: serializer.fromJson<String>(json['trackId']),
      type: serializer.fromJson<String>(json['type']),
      at: serializer.fromJson<int>(json['at']),
      seq: serializer.fromJson<int>(json['seq']),
      label: serializer.fromJson<String?>(json['label']),
      personId: serializer.fromJson<String?>(json['personId']),
      substanceId: serializer.fromJson<String?>(json['substanceId']),
      amount: serializer.fromJson<String?>(json['amount']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      extraJson: serializer.fromJson<String?>(json['extraJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'trackId': serializer.toJson<String>(trackId),
      'type': serializer.toJson<String>(type),
      'at': serializer.toJson<int>(at),
      'seq': serializer.toJson<int>(seq),
      'label': serializer.toJson<String?>(label),
      'personId': serializer.toJson<String?>(personId),
      'substanceId': serializer.toJson<String?>(substanceId),
      'amount': serializer.toJson<String?>(amount),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'extraJson': serializer.toJson<String?>(extraJson),
    };
  }

  EventRow copyWith({
    String? id,
    String? sessionId,
    String? trackId,
    String? type,
    int? at,
    int? seq,
    Value<String?> label = const Value.absent(),
    Value<String?> personId = const Value.absent(),
    Value<String?> substanceId = const Value.absent(),
    Value<String?> amount = const Value.absent(),
    Value<String?> note = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<String?> extraJson = const Value.absent(),
  }) => EventRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    trackId: trackId ?? this.trackId,
    type: type ?? this.type,
    at: at ?? this.at,
    seq: seq ?? this.seq,
    label: label.present ? label.value : this.label,
    personId: personId.present ? personId.value : this.personId,
    substanceId: substanceId.present ? substanceId.value : this.substanceId,
    amount: amount.present ? amount.value : this.amount,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    extraJson: extraJson.present ? extraJson.value : this.extraJson,
  );
  EventRow copyWithCompanion(EventsCompanion data) {
    return EventRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      type: data.type.present ? data.type.value : this.type,
      at: data.at.present ? data.at.value : this.at,
      seq: data.seq.present ? data.seq.value : this.seq,
      label: data.label.present ? data.label.value : this.label,
      personId: data.personId.present ? data.personId.value : this.personId,
      substanceId: data.substanceId.present
          ? data.substanceId.value
          : this.substanceId,
      amount: data.amount.present ? data.amount.value : this.amount,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      extraJson: data.extraJson.present ? data.extraJson.value : this.extraJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('trackId: $trackId, ')
          ..write('type: $type, ')
          ..write('at: $at, ')
          ..write('seq: $seq, ')
          ..write('label: $label, ')
          ..write('personId: $personId, ')
          ..write('substanceId: $substanceId, ')
          ..write('amount: $amount, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('extraJson: $extraJson')
          ..write(')'))
        .toString();
  }

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
    extraJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.trackId == this.trackId &&
          other.type == this.type &&
          other.at == this.at &&
          other.seq == this.seq &&
          other.label == this.label &&
          other.personId == this.personId &&
          other.substanceId == this.substanceId &&
          other.amount == this.amount &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.extraJson == this.extraJson);
}

class EventsCompanion extends UpdateCompanion<EventRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> trackId;
  final Value<String> type;
  final Value<int> at;
  final Value<int> seq;
  final Value<String?> label;
  final Value<String?> personId;
  final Value<String?> substanceId;
  final Value<String?> amount;
  final Value<String?> note;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String?> extraJson;
  final Value<int> rowid;
  const EventsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.trackId = const Value.absent(),
    this.type = const Value.absent(),
    this.at = const Value.absent(),
    this.seq = const Value.absent(),
    this.label = const Value.absent(),
    this.personId = const Value.absent(),
    this.substanceId = const Value.absent(),
    this.amount = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.extraJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EventsCompanion.insert({
    required String id,
    required String sessionId,
    required String trackId,
    required String type,
    required int at,
    this.seq = const Value.absent(),
    this.label = const Value.absent(),
    this.personId = const Value.absent(),
    this.substanceId = const Value.absent(),
    this.amount = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.extraJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       trackId = Value(trackId),
       type = Value(type),
       at = Value(at);
  static Insertable<EventRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? trackId,
    Expression<String>? type,
    Expression<int>? at,
    Expression<int>? seq,
    Expression<String>? label,
    Expression<String>? personId,
    Expression<String>? substanceId,
    Expression<String>? amount,
    Expression<String>? note,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? extraJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (trackId != null) 'track_id': trackId,
      if (type != null) 'type': type,
      if (at != null) 'at': at,
      if (seq != null) 'seq': seq,
      if (label != null) 'label': label,
      if (personId != null) 'person_id': personId,
      if (substanceId != null) 'substance_id': substanceId,
      if (amount != null) 'amount': amount,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (extraJson != null) 'extra_json': extraJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EventsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? trackId,
    Value<String>? type,
    Value<int>? at,
    Value<int>? seq,
    Value<String?>? label,
    Value<String?>? personId,
    Value<String?>? substanceId,
    Value<String?>? amount,
    Value<String?>? note,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String?>? extraJson,
    Value<int>? rowid,
  }) {
    return EventsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      trackId: trackId ?? this.trackId,
      type: type ?? this.type,
      at: at ?? this.at,
      seq: seq ?? this.seq,
      label: label ?? this.label,
      personId: personId ?? this.personId,
      substanceId: substanceId ?? this.substanceId,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      extraJson: extraJson ?? this.extraJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<String>(trackId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (at.present) {
      map['at'] = Variable<int>(at.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (personId.present) {
      map['person_id'] = Variable<String>(personId.value);
    }
    if (substanceId.present) {
      map['substance_id'] = Variable<String>(substanceId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<String>(amount.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (extraJson.present) {
      map['extra_json'] = Variable<String>(extraJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('trackId: $trackId, ')
          ..write('type: $type, ')
          ..write('at: $at, ')
          ..write('seq: $seq, ')
          ..write('label: $label, ')
          ..write('personId: $personId, ')
          ..write('substanceId: $substanceId, ')
          ..write('amount: $amount, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('extraJson: $extraJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PersonsTable extends Persons with TableInfo<$PersonsTable, PersonRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PersonsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xFF888888),
  );
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _extraJsonMeta = const VerificationMeta(
    'extraJson',
  );
  @override
  late final GeneratedColumn<String> extraJson = GeneratedColumn<String>(
    'extra_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    color,
    sortIndex,
    archived,
    note,
    createdAt,
    updatedAt,
    extraJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'persons';
  @override
  VerificationContext validateIntegrity(
    Insertable<PersonRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('extra_json')) {
      context.handle(
        _extraJsonMeta,
        extraJson.isAcceptableOrUnknown(data['extra_json']!, _extraJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PersonRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PersonRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      extraJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extra_json'],
      ),
    );
  }

  @override
  $PersonsTable createAlias(String alias) {
    return $PersonsTable(attachedDatabase, alias);
  }
}

class PersonRow extends DataClass implements Insertable<PersonRow> {
  final String id;
  final String name;

  /// ARGB.
  final int color;
  final int sortIndex;
  final bool archived;
  final String? note;
  final int createdAt;
  final int updatedAt;
  final String? extraJson;
  const PersonRow({
    required this.id,
    required this.name,
    required this.color,
    required this.sortIndex,
    required this.archived,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.extraJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['color'] = Variable<int>(color);
    map['sort_index'] = Variable<int>(sortIndex);
    map['archived'] = Variable<bool>(archived);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || extraJson != null) {
      map['extra_json'] = Variable<String>(extraJson);
    }
    return map;
  }

  PersonsCompanion toCompanion(bool nullToAbsent) {
    return PersonsCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
      sortIndex: Value(sortIndex),
      archived: Value(archived),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      extraJson: extraJson == null && nullToAbsent
          ? const Value.absent()
          : Value(extraJson),
    );
  }

  factory PersonRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PersonRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<int>(json['color']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
      archived: serializer.fromJson<bool>(json['archived']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      extraJson: serializer.fromJson<String?>(json['extraJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<int>(color),
      'sortIndex': serializer.toJson<int>(sortIndex),
      'archived': serializer.toJson<bool>(archived),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'extraJson': serializer.toJson<String?>(extraJson),
    };
  }

  PersonRow copyWith({
    String? id,
    String? name,
    int? color,
    int? sortIndex,
    bool? archived,
    Value<String?> note = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<String?> extraJson = const Value.absent(),
  }) => PersonRow(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color ?? this.color,
    sortIndex: sortIndex ?? this.sortIndex,
    archived: archived ?? this.archived,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    extraJson: extraJson.present ? extraJson.value : this.extraJson,
  );
  PersonRow copyWithCompanion(PersonsCompanion data) {
    return PersonRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
      archived: data.archived.present ? data.archived.value : this.archived,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      extraJson: data.extraJson.present ? data.extraJson.value : this.extraJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PersonRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('archived: $archived, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('extraJson: $extraJson')
          ..write(')'))
        .toString();
  }

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
    extraJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PersonRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.sortIndex == this.sortIndex &&
          other.archived == this.archived &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.extraJson == this.extraJson);
}

class PersonsCompanion extends UpdateCompanion<PersonRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> color;
  final Value<int> sortIndex;
  final Value<bool> archived;
  final Value<String?> note;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String?> extraJson;
  final Value<int> rowid;
  const PersonsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.archived = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.extraJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PersonsCompanion.insert({
    required String id,
    required String name,
    this.color = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.archived = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.extraJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<PersonRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? color,
    Expression<int>? sortIndex,
    Expression<bool>? archived,
    Expression<String>? note,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? extraJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (sortIndex != null) 'sort_index': sortIndex,
      if (archived != null) 'archived': archived,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (extraJson != null) 'extra_json': extraJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PersonsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? color,
    Value<int>? sortIndex,
    Value<bool>? archived,
    Value<String?>? note,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String?>? extraJson,
    Value<int>? rowid,
  }) {
    return PersonsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      sortIndex: sortIndex ?? this.sortIndex,
      archived: archived ?? this.archived,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      extraJson: extraJson ?? this.extraJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (extraJson.present) {
      map['extra_json'] = Variable<String>(extraJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PersonsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('archived: $archived, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('extraJson: $extraJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SubstancesTable extends Substances
    with TableInfo<$SubstancesTable, SubstanceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubstancesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xFF888888),
  );
  static const VerificationMeta _lockoutMsMeta = const VerificationMeta(
    'lockoutMs',
  );
  @override
  late final GeneratedColumn<int> lockoutMs = GeneratedColumn<int>(
    'lockout_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortIndexMeta = const VerificationMeta(
    'sortIndex',
  );
  @override
  late final GeneratedColumn<int> sortIndex = GeneratedColumn<int>(
    'sort_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _extraJsonMeta = const VerificationMeta(
    'extraJson',
  );
  @override
  late final GeneratedColumn<String> extraJson = GeneratedColumn<String>(
    'extra_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    color,
    lockoutMs,
    sortIndex,
    archived,
    note,
    createdAt,
    updatedAt,
    extraJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'substances';
  @override
  VerificationContext validateIntegrity(
    Insertable<SubstanceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('lockout_ms')) {
      context.handle(
        _lockoutMsMeta,
        lockoutMs.isAcceptableOrUnknown(data['lockout_ms']!, _lockoutMsMeta),
      );
    }
    if (data.containsKey('sort_index')) {
      context.handle(
        _sortIndexMeta,
        sortIndex.isAcceptableOrUnknown(data['sort_index']!, _sortIndexMeta),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('extra_json')) {
      context.handle(
        _extraJsonMeta,
        extraJson.isAcceptableOrUnknown(data['extra_json']!, _extraJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SubstanceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SubstanceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
      lockoutMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lockout_ms'],
      ),
      sortIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_index'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      extraJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extra_json'],
      ),
    );
  }

  @override
  $SubstancesTable createAlias(String alias) {
    return $SubstancesTable(attachedDatabase, alias);
  }
}

class SubstanceRow extends DataClass implements Insertable<SubstanceRow> {
  final String id;
  final String name;

  /// ARGB.
  final int color;

  /// User-set lockout in milliseconds; NULL = none.
  final int? lockoutMs;
  final int sortIndex;
  final bool archived;
  final String? note;
  final int createdAt;
  final int updatedAt;
  final String? extraJson;
  const SubstanceRow({
    required this.id,
    required this.name,
    required this.color,
    this.lockoutMs,
    required this.sortIndex,
    required this.archived,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.extraJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['color'] = Variable<int>(color);
    if (!nullToAbsent || lockoutMs != null) {
      map['lockout_ms'] = Variable<int>(lockoutMs);
    }
    map['sort_index'] = Variable<int>(sortIndex);
    map['archived'] = Variable<bool>(archived);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || extraJson != null) {
      map['extra_json'] = Variable<String>(extraJson);
    }
    return map;
  }

  SubstancesCompanion toCompanion(bool nullToAbsent) {
    return SubstancesCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
      lockoutMs: lockoutMs == null && nullToAbsent
          ? const Value.absent()
          : Value(lockoutMs),
      sortIndex: Value(sortIndex),
      archived: Value(archived),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      extraJson: extraJson == null && nullToAbsent
          ? const Value.absent()
          : Value(extraJson),
    );
  }

  factory SubstanceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SubstanceRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<int>(json['color']),
      lockoutMs: serializer.fromJson<int?>(json['lockoutMs']),
      sortIndex: serializer.fromJson<int>(json['sortIndex']),
      archived: serializer.fromJson<bool>(json['archived']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      extraJson: serializer.fromJson<String?>(json['extraJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<int>(color),
      'lockoutMs': serializer.toJson<int?>(lockoutMs),
      'sortIndex': serializer.toJson<int>(sortIndex),
      'archived': serializer.toJson<bool>(archived),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'extraJson': serializer.toJson<String?>(extraJson),
    };
  }

  SubstanceRow copyWith({
    String? id,
    String? name,
    int? color,
    Value<int?> lockoutMs = const Value.absent(),
    int? sortIndex,
    bool? archived,
    Value<String?> note = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<String?> extraJson = const Value.absent(),
  }) => SubstanceRow(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color ?? this.color,
    lockoutMs: lockoutMs.present ? lockoutMs.value : this.lockoutMs,
    sortIndex: sortIndex ?? this.sortIndex,
    archived: archived ?? this.archived,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    extraJson: extraJson.present ? extraJson.value : this.extraJson,
  );
  SubstanceRow copyWithCompanion(SubstancesCompanion data) {
    return SubstanceRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      lockoutMs: data.lockoutMs.present ? data.lockoutMs.value : this.lockoutMs,
      sortIndex: data.sortIndex.present ? data.sortIndex.value : this.sortIndex,
      archived: data.archived.present ? data.archived.value : this.archived,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      extraJson: data.extraJson.present ? data.extraJson.value : this.extraJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SubstanceRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('lockoutMs: $lockoutMs, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('archived: $archived, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('extraJson: $extraJson')
          ..write(')'))
        .toString();
  }

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
    extraJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubstanceRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.lockoutMs == this.lockoutMs &&
          other.sortIndex == this.sortIndex &&
          other.archived == this.archived &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.extraJson == this.extraJson);
}

class SubstancesCompanion extends UpdateCompanion<SubstanceRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> color;
  final Value<int?> lockoutMs;
  final Value<int> sortIndex;
  final Value<bool> archived;
  final Value<String?> note;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String?> extraJson;
  final Value<int> rowid;
  const SubstancesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.lockoutMs = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.archived = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.extraJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SubstancesCompanion.insert({
    required String id,
    required String name,
    this.color = const Value.absent(),
    this.lockoutMs = const Value.absent(),
    this.sortIndex = const Value.absent(),
    this.archived = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.extraJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<SubstanceRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? color,
    Expression<int>? lockoutMs,
    Expression<int>? sortIndex,
    Expression<bool>? archived,
    Expression<String>? note,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? extraJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (lockoutMs != null) 'lockout_ms': lockoutMs,
      if (sortIndex != null) 'sort_index': sortIndex,
      if (archived != null) 'archived': archived,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (extraJson != null) 'extra_json': extraJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SubstancesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? color,
    Value<int?>? lockoutMs,
    Value<int>? sortIndex,
    Value<bool>? archived,
    Value<String?>? note,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String?>? extraJson,
    Value<int>? rowid,
  }) {
    return SubstancesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      lockoutMs: lockoutMs ?? this.lockoutMs,
      sortIndex: sortIndex ?? this.sortIndex,
      archived: archived ?? this.archived,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      extraJson: extraJson ?? this.extraJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (lockoutMs.present) {
      map['lockout_ms'] = Variable<int>(lockoutMs.value);
    }
    if (sortIndex.present) {
      map['sort_index'] = Variable<int>(sortIndex.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (extraJson.present) {
      map['extra_json'] = Variable<String>(extraJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubstancesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('lockoutMs: $lockoutMs, ')
          ..write('sortIndex: $sortIndex, ')
          ..write('archived: $archived, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('extraJson: $extraJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  final int updatedAt;
  const SettingRow({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  SettingRow copyWith({String? key, String? value, int? updatedAt}) =>
      SettingRow(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TrackSetsTable trackSets = $TrackSetsTable(this);
  late final $TracksTable tracks = $TracksTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $EventsTable events = $EventsTable(this);
  late final $PersonsTable persons = $PersonsTable(this);
  late final $SubstancesTable substances = $SubstancesTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final Index idxSetsSort = Index(
    'idx_sets_sort',
    'CREATE INDEX idx_sets_sort ON track_sets (sort_index)',
  );
  late final Index idxTracksSet = Index(
    'idx_tracks_set',
    'CREATE INDEX idx_tracks_set ON tracks (set_id, sort_index)',
  );
  late final Index idxSessionsTrack = Index(
    'idx_sessions_track',
    'CREATE INDEX idx_sessions_track ON sessions (track_id, started_at)',
  );
  late final Index idxSessionsStarted = Index(
    'idx_sessions_started',
    'CREATE INDEX idx_sessions_started ON sessions (started_at)',
  );
  late final Index idxSessionsEnded = Index(
    'idx_sessions_ended',
    'CREATE INDEX idx_sessions_ended ON sessions (ended_at)',
  );
  late final Index idxEventsSession = Index(
    'idx_events_session',
    'CREATE INDEX idx_events_session ON events (session_id, at, seq)',
  );
  late final Index idxEventsTrack = Index(
    'idx_events_track',
    'CREATE INDEX idx_events_track ON events (track_id, at)',
  );
  late final Index idxEventsAt = Index(
    'idx_events_at',
    'CREATE INDEX idx_events_at ON events (at)',
  );
  late final Index idxEventsPerson = Index(
    'idx_events_person',
    'CREATE INDEX idx_events_person ON events (person_id)',
  );
  late final Index idxEventsSubstance = Index(
    'idx_events_substance',
    'CREATE INDEX idx_events_substance ON events (substance_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    trackSets,
    tracks,
    sessions,
    events,
    persons,
    substances,
    settings,
    idxSetsSort,
    idxTracksSet,
    idxSessionsTrack,
    idxSessionsStarted,
    idxSessionsEnded,
    idxEventsSession,
    idxEventsTrack,
    idxEventsAt,
    idxEventsPerson,
    idxEventsSubstance,
  ];
}

typedef $$TrackSetsTableCreateCompanionBuilder = TrackSetsCompanion Function({
  required String id,
  required String name,
  Value<int> sortIndex,
  Value<String?> themeId,
  Value<String?> uiPrefsOverrideJson,
  Value<bool> archived,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<String?> extraJson,
  Value<int> rowid,
});
typedef $$TrackSetsTableUpdateCompanionBuilder = TrackSetsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<int> sortIndex,
  Value<String?> themeId,
  Value<String?> uiPrefsOverrideJson,
  Value<bool> archived,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<String?> extraJson,
  Value<int> rowid,
});

class $$TrackSetsTableFilterComposer
    extends Composer<_$AppDatabase, $TrackSetsTable> {
  $$TrackSetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themeId => $composableBuilder(
    column: $table.themeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uiPrefsOverrideJson => $composableBuilder(
    column: $table.uiPrefsOverrideJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extraJson => $composableBuilder(
    column: $table.extraJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TrackSetsTableOrderingComposer
    extends Composer<_$AppDatabase, $TrackSetsTable> {
  $$TrackSetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themeId => $composableBuilder(
    column: $table.themeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uiPrefsOverrideJson => $composableBuilder(
    column: $table.uiPrefsOverrideJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extraJson => $composableBuilder(
    column: $table.extraJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TrackSetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrackSetsTable> {
  $$TrackSetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  GeneratedColumn<String> get themeId =>
      $composableBuilder(column: $table.themeId, builder: (column) => column);

  GeneratedColumn<String> get uiPrefsOverrideJson => $composableBuilder(
    column: $table.uiPrefsOverrideJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get extraJson =>
      $composableBuilder(column: $table.extraJson, builder: (column) => column);
}

class $$TrackSetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TrackSetsTable,
          SetRow,
          $$TrackSetsTableFilterComposer,
          $$TrackSetsTableOrderingComposer,
          $$TrackSetsTableAnnotationComposer,
          $$TrackSetsTableCreateCompanionBuilder,
          $$TrackSetsTableUpdateCompanionBuilder,
          (SetRow, BaseReferences<_$AppDatabase, $TrackSetsTable, SetRow>),
          SetRow,
          PrefetchHooks Function()
        > {
  $$TrackSetsTableTableManager(_$AppDatabase db, $TrackSetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackSetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackSetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackSetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<String?> themeId = const Value.absent(),
                Value<String?> uiPrefsOverrideJson = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String?> extraJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrackSetsCompanion(
                id: id,
                name: name,
                sortIndex: sortIndex,
                themeId: themeId,
                uiPrefsOverrideJson: uiPrefsOverrideJson,
                archived: archived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                extraJson: extraJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int> sortIndex = const Value.absent(),
                Value<String?> themeId = const Value.absent(),
                Value<String?> uiPrefsOverrideJson = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String?> extraJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrackSetsCompanion.insert(
                id: id,
                name: name,
                sortIndex: sortIndex,
                themeId: themeId,
                uiPrefsOverrideJson: uiPrefsOverrideJson,
                archived: archived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                extraJson: extraJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TrackSetsTable, SetRow>(table),
                  BaseReferences<_$AppDatabase, $TrackSetsTable, SetRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TrackSetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TrackSetsTable,
      SetRow,
      $$TrackSetsTableFilterComposer,
      $$TrackSetsTableOrderingComposer,
      $$TrackSetsTableAnnotationComposer,
      $$TrackSetsTableCreateCompanionBuilder,
      $$TrackSetsTableUpdateCompanionBuilder,
      (SetRow, BaseReferences<_$AppDatabase, $TrackSetsTable, SetRow>),
      SetRow,
      PrefetchHooks Function()
    >;
typedef $$TracksTableCreateCompanionBuilder = TracksCompanion Function({
  required String id,
  required String setId,
  required String name,
  Value<int> colorIndex,
  Value<int?> customColor,
  required String mode,
  Value<String> configJson,
  Value<bool> alarmSound,
  Value<bool> vibration,
  Value<int> sortIndex,
  Value<bool> logEnabled,
  Value<bool> archived,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<String?> extraJson,
  Value<int> rowid,
});
typedef $$TracksTableUpdateCompanionBuilder = TracksCompanion Function({
  Value<String> id,
  Value<String> setId,
  Value<String> name,
  Value<int> colorIndex,
  Value<int?> customColor,
  Value<String> mode,
  Value<String> configJson,
  Value<bool> alarmSound,
  Value<bool> vibration,
  Value<int> sortIndex,
  Value<bool> logEnabled,
  Value<bool> archived,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<String?> extraJson,
  Value<int> rowid,
});

class $$TracksTableFilterComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get setId => $composableBuilder(
    column: $table.setId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get customColor => $composableBuilder(
    column: $table.customColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get alarmSound => $composableBuilder(
    column: $table.alarmSound,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get vibration => $composableBuilder(
    column: $table.vibration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get logEnabled => $composableBuilder(
    column: $table.logEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extraJson => $composableBuilder(
    column: $table.extraJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TracksTableOrderingComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get setId => $composableBuilder(
    column: $table.setId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get customColor => $composableBuilder(
    column: $table.customColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get alarmSound => $composableBuilder(
    column: $table.alarmSound,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get vibration => $composableBuilder(
    column: $table.vibration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get logEnabled => $composableBuilder(
    column: $table.logEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extraJson => $composableBuilder(
    column: $table.extraJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get setId =>
      $composableBuilder(column: $table.setId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get customColor => $composableBuilder(
    column: $table.customColor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get alarmSound => $composableBuilder(
    column: $table.alarmSound,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get vibration =>
      $composableBuilder(column: $table.vibration, builder: (column) => column);

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  GeneratedColumn<bool> get logEnabled => $composableBuilder(
    column: $table.logEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get extraJson =>
      $composableBuilder(column: $table.extraJson, builder: (column) => column);
}

class $$TracksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TracksTable,
          TrackRow,
          $$TracksTableFilterComposer,
          $$TracksTableOrderingComposer,
          $$TracksTableAnnotationComposer,
          $$TracksTableCreateCompanionBuilder,
          $$TracksTableUpdateCompanionBuilder,
          (TrackRow, BaseReferences<_$AppDatabase, $TracksTable, TrackRow>),
          TrackRow,
          PrefetchHooks Function()
        > {
  $$TracksTableTableManager(_$AppDatabase db, $TracksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> setId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> colorIndex = const Value.absent(),
                Value<int?> customColor = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<String> configJson = const Value.absent(),
                Value<bool> alarmSound = const Value.absent(),
                Value<bool> vibration = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<bool> logEnabled = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String?> extraJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TracksCompanion(
                id: id,
                setId: setId,
                name: name,
                colorIndex: colorIndex,
                customColor: customColor,
                mode: mode,
                configJson: configJson,
                alarmSound: alarmSound,
                vibration: vibration,
                sortIndex: sortIndex,
                logEnabled: logEnabled,
                archived: archived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                extraJson: extraJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String setId,
                required String name,
                Value<int> colorIndex = const Value.absent(),
                Value<int?> customColor = const Value.absent(),
                required String mode,
                Value<String> configJson = const Value.absent(),
                Value<bool> alarmSound = const Value.absent(),
                Value<bool> vibration = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<bool> logEnabled = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String?> extraJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TracksCompanion.insert(
                id: id,
                setId: setId,
                name: name,
                colorIndex: colorIndex,
                customColor: customColor,
                mode: mode,
                configJson: configJson,
                alarmSound: alarmSound,
                vibration: vibration,
                sortIndex: sortIndex,
                logEnabled: logEnabled,
                archived: archived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                extraJson: extraJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TracksTable, TrackRow>(table),
                  BaseReferences<_$AppDatabase, $TracksTable, TrackRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TracksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TracksTable,
      TrackRow,
      $$TracksTableFilterComposer,
      $$TracksTableOrderingComposer,
      $$TracksTableAnnotationComposer,
      $$TracksTableCreateCompanionBuilder,
      $$TracksTableUpdateCompanionBuilder,
      (TrackRow, BaseReferences<_$AppDatabase, $TracksTable, TrackRow>),
      TrackRow,
      PrefetchHooks Function()
    >;
typedef $$SessionsTableCreateCompanionBuilder = SessionsCompanion Function({
  required String id,
  required String trackId,
  required String mode,
  Value<String> configJson,
  required int startedAt,
  Value<int?> endedAt,
  Value<String?> note,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<String?> extraJson,
  Value<int> rowid,
});
typedef $$SessionsTableUpdateCompanionBuilder = SessionsCompanion Function({
  Value<String> id,
  Value<String> trackId,
  Value<String> mode,
  Value<String> configJson,
  Value<int> startedAt,
  Value<int?> endedAt,
  Value<String?> note,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<String?> extraJson,
  Value<int> rowid,
});

class $$SessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extraJson => $composableBuilder(
    column: $table.extraJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extraJson => $composableBuilder(
    column: $table.extraJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get trackId =>
      $composableBuilder(column: $table.trackId, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get extraJson =>
      $composableBuilder(column: $table.extraJson, builder: (column) => column);
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionsTable,
          SessionRow,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (
            SessionRow,
            BaseReferences<_$AppDatabase, $SessionsTable, SessionRow>,
          ),
          SessionRow,
          PrefetchHooks Function()
        > {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> trackId = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<String> configJson = const Value.absent(),
                Value<int> startedAt = const Value.absent(),
                Value<int?> endedAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String?> extraJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                trackId: trackId,
                mode: mode,
                configJson: configJson,
                startedAt: startedAt,
                endedAt: endedAt,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                extraJson: extraJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String trackId,
                required String mode,
                Value<String> configJson = const Value.absent(),
                required int startedAt,
                Value<int?> endedAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String?> extraJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion.insert(
                id: id,
                trackId: trackId,
                mode: mode,
                configJson: configJson,
                startedAt: startedAt,
                endedAt: endedAt,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                extraJson: extraJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SessionsTable, SessionRow>(table),
                  BaseReferences<_$AppDatabase, $SessionsTable, SessionRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionsTable,
      SessionRow,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (SessionRow, BaseReferences<_$AppDatabase, $SessionsTable, SessionRow>),
      SessionRow,
      PrefetchHooks Function()
    >;
typedef $$EventsTableCreateCompanionBuilder = EventsCompanion Function({
  required String id,
  required String sessionId,
  required String trackId,
  required String type,
  required int at,
  Value<int> seq,
  Value<String?> label,
  Value<String?> personId,
  Value<String?> substanceId,
  Value<String?> amount,
  Value<String?> note,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<String?> extraJson,
  Value<int> rowid,
});
typedef $$EventsTableUpdateCompanionBuilder = EventsCompanion Function({
  Value<String> id,
  Value<String> sessionId,
  Value<String> trackId,
  Value<String> type,
  Value<int> at,
  Value<int> seq,
  Value<String?> label,
  Value<String?> personId,
  Value<String?> substanceId,
  Value<String?> amount,
  Value<String?> note,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<String?> extraJson,
  Value<int> rowid,
});

class $$EventsTableFilterComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get personId => $composableBuilder(
    column: $table.personId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get substanceId => $composableBuilder(
    column: $table.substanceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extraJson => $composableBuilder(
    column: $table.extraJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EventsTableOrderingComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackId => $composableBuilder(
    column: $table.trackId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get personId => $composableBuilder(
    column: $table.personId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get substanceId => $composableBuilder(
    column: $table.substanceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extraJson => $composableBuilder(
    column: $table.extraJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get trackId =>
      $composableBuilder(column: $table.trackId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get personId =>
      $composableBuilder(column: $table.personId, builder: (column) => column);

  GeneratedColumn<String> get substanceId => $composableBuilder(
    column: $table.substanceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get extraJson =>
      $composableBuilder(column: $table.extraJson, builder: (column) => column);
}

class $$EventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventsTable,
          EventRow,
          $$EventsTableFilterComposer,
          $$EventsTableOrderingComposer,
          $$EventsTableAnnotationComposer,
          $$EventsTableCreateCompanionBuilder,
          $$EventsTableUpdateCompanionBuilder,
          (EventRow, BaseReferences<_$AppDatabase, $EventsTable, EventRow>),
          EventRow,
          PrefetchHooks Function()
        > {
  $$EventsTableTableManager(_$AppDatabase db, $EventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> trackId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> at = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<String?> personId = const Value.absent(),
                Value<String?> substanceId = const Value.absent(),
                Value<String?> amount = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String?> extraJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventsCompanion(
                id: id,
                sessionId: sessionId,
                trackId: trackId,
                type: type,
                at: at,
                seq: seq,
                label: label,
                personId: personId,
                substanceId: substanceId,
                amount: amount,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                extraJson: extraJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String trackId,
                required String type,
                required int at,
                Value<int> seq = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<String?> personId = const Value.absent(),
                Value<String?> substanceId = const Value.absent(),
                Value<String?> amount = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String?> extraJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventsCompanion.insert(
                id: id,
                sessionId: sessionId,
                trackId: trackId,
                type: type,
                at: at,
                seq: seq,
                label: label,
                personId: personId,
                substanceId: substanceId,
                amount: amount,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                extraJson: extraJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EventsTable, EventRow>(table),
                  BaseReferences<_$AppDatabase, $EventsTable, EventRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventsTable,
      EventRow,
      $$EventsTableFilterComposer,
      $$EventsTableOrderingComposer,
      $$EventsTableAnnotationComposer,
      $$EventsTableCreateCompanionBuilder,
      $$EventsTableUpdateCompanionBuilder,
      (EventRow, BaseReferences<_$AppDatabase, $EventsTable, EventRow>),
      EventRow,
      PrefetchHooks Function()
    >;
typedef $$PersonsTableCreateCompanionBuilder = PersonsCompanion Function({
  required String id,
  required String name,
  Value<int> color,
  Value<int> sortIndex,
  Value<bool> archived,
  Value<String?> note,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<String?> extraJson,
  Value<int> rowid,
});
typedef $$PersonsTableUpdateCompanionBuilder = PersonsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<int> color,
  Value<int> sortIndex,
  Value<bool> archived,
  Value<String?> note,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<String?> extraJson,
  Value<int> rowid,
});

class $$PersonsTableFilterComposer
    extends Composer<_$AppDatabase, $PersonsTable> {
  $$PersonsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extraJson => $composableBuilder(
    column: $table.extraJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PersonsTableOrderingComposer
    extends Composer<_$AppDatabase, $PersonsTable> {
  $$PersonsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extraJson => $composableBuilder(
    column: $table.extraJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PersonsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PersonsTable> {
  $$PersonsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get extraJson =>
      $composableBuilder(column: $table.extraJson, builder: (column) => column);
}

class $$PersonsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PersonsTable,
          PersonRow,
          $$PersonsTableFilterComposer,
          $$PersonsTableOrderingComposer,
          $$PersonsTableAnnotationComposer,
          $$PersonsTableCreateCompanionBuilder,
          $$PersonsTableUpdateCompanionBuilder,
          (PersonRow, BaseReferences<_$AppDatabase, $PersonsTable, PersonRow>),
          PersonRow,
          PrefetchHooks Function()
        > {
  $$PersonsTableTableManager(_$AppDatabase db, $PersonsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PersonsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PersonsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PersonsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String?> extraJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PersonsCompanion(
                id: id,
                name: name,
                color: color,
                sortIndex: sortIndex,
                archived: archived,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                extraJson: extraJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int> color = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String?> extraJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PersonsCompanion.insert(
                id: id,
                name: name,
                color: color,
                sortIndex: sortIndex,
                archived: archived,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                extraJson: extraJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PersonsTable, PersonRow>(table),
                  BaseReferences<_$AppDatabase, $PersonsTable, PersonRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PersonsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PersonsTable,
      PersonRow,
      $$PersonsTableFilterComposer,
      $$PersonsTableOrderingComposer,
      $$PersonsTableAnnotationComposer,
      $$PersonsTableCreateCompanionBuilder,
      $$PersonsTableUpdateCompanionBuilder,
      (PersonRow, BaseReferences<_$AppDatabase, $PersonsTable, PersonRow>),
      PersonRow,
      PrefetchHooks Function()
    >;
typedef $$SubstancesTableCreateCompanionBuilder = SubstancesCompanion Function({
  required String id,
  required String name,
  Value<int> color,
  Value<int?> lockoutMs,
  Value<int> sortIndex,
  Value<bool> archived,
  Value<String?> note,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<String?> extraJson,
  Value<int> rowid,
});
typedef $$SubstancesTableUpdateCompanionBuilder = SubstancesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<int> color,
  Value<int?> lockoutMs,
  Value<int> sortIndex,
  Value<bool> archived,
  Value<String?> note,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<String?> extraJson,
  Value<int> rowid,
});

class $$SubstancesTableFilterComposer
    extends Composer<_$AppDatabase, $SubstancesTable> {
  $$SubstancesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lockoutMs => $composableBuilder(
    column: $table.lockoutMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extraJson => $composableBuilder(
    column: $table.extraJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SubstancesTableOrderingComposer
    extends Composer<_$AppDatabase, $SubstancesTable> {
  $$SubstancesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lockoutMs => $composableBuilder(
    column: $table.lockoutMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortIndex => $composableBuilder(
    column: $table.sortIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extraJson => $composableBuilder(
    column: $table.extraJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SubstancesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubstancesTable> {
  $$SubstancesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get lockoutMs =>
      $composableBuilder(column: $table.lockoutMs, builder: (column) => column);

  GeneratedColumn<int> get sortIndex =>
      $composableBuilder(column: $table.sortIndex, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get extraJson =>
      $composableBuilder(column: $table.extraJson, builder: (column) => column);
}

class $$SubstancesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SubstancesTable,
          SubstanceRow,
          $$SubstancesTableFilterComposer,
          $$SubstancesTableOrderingComposer,
          $$SubstancesTableAnnotationComposer,
          $$SubstancesTableCreateCompanionBuilder,
          $$SubstancesTableUpdateCompanionBuilder,
          (
            SubstanceRow,
            BaseReferences<_$AppDatabase, $SubstancesTable, SubstanceRow>,
          ),
          SubstanceRow,
          PrefetchHooks Function()
        > {
  $$SubstancesTableTableManager(_$AppDatabase db, $SubstancesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubstancesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubstancesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubstancesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<int?> lockoutMs = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String?> extraJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubstancesCompanion(
                id: id,
                name: name,
                color: color,
                lockoutMs: lockoutMs,
                sortIndex: sortIndex,
                archived: archived,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                extraJson: extraJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int> color = const Value.absent(),
                Value<int?> lockoutMs = const Value.absent(),
                Value<int> sortIndex = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String?> extraJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubstancesCompanion.insert(
                id: id,
                name: name,
                color: color,
                lockoutMs: lockoutMs,
                sortIndex: sortIndex,
                archived: archived,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                extraJson: extraJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SubstancesTable, SubstanceRow>(table),
                  BaseReferences<_$AppDatabase, $SubstancesTable, SubstanceRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SubstancesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SubstancesTable,
      SubstanceRow,
      $$SubstancesTableFilterComposer,
      $$SubstancesTableOrderingComposer,
      $$SubstancesTableAnnotationComposer,
      $$SubstancesTableCreateCompanionBuilder,
      $$SubstancesTableUpdateCompanionBuilder,
      (
        SubstanceRow,
        BaseReferences<_$AppDatabase, $SubstancesTable, SubstanceRow>,
      ),
      SubstanceRow,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> updatedAt,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingRow>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TrackSetsTableTableManager get trackSets =>
      $$TrackSetsTableTableManager(_db, _db.trackSets);
  $$TracksTableTableManager get tracks =>
      $$TracksTableTableManager(_db, _db.tracks);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db, _db.events);
  $$PersonsTableTableManager get persons =>
      $$PersonsTableTableManager(_db, _db.persons);
  $$SubstancesTableTableManager get substances =>
      $$SubstancesTableTableManager(_db, _db.substances);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
