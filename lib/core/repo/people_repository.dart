import 'package:drift/drift.dart';

import '../clock.dart';
import '../db/app_database.dart';
import '../domain/domain.dart';
import 'mappers.dart';
import 'models.dart';
import 'watch.dart';

/// User-managed persons and substances for protocol tracks.
///
/// The app never creates, ships or suggests any of these: both lists start
/// empty and only contain what the user typed in.
class PeopleRepository {
  PeopleRepository(this._db, this._clock, this._newId);

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _newId;

  /// Where a deleted person / substance stood in which scene (set id ->
  /// position), so "Rückgängig" can put it back. Only kept in memory.
  final Map<String, Map<String, int>> _removedFromScenes = {};

  /// Takes [id] out of the scene of every set and remembers its places.
  Future<void> _removeFromScenes(String id, {required bool person}) async {
    final places = <String, int>{};
    final now = _clock.nowMs();
    for (final row in await _db.select(_db.trackSets).get()) {
      final set = row.toDomain();
      final ids = person ? set.scenePersonIds : set.sceneSubstanceIds;
      final index = ids.indexOf(id);
      if (index < 0) continue;
      places[set.id] = index;
      final rest = [...ids]..removeAt(index);
      await _writeScene(set, rest, person: person, now: now);
    }
    if (places.isEmpty) {
      _removedFromScenes.remove(id);
    } else {
      _removedFromScenes[id] = places;
    }
  }

  /// Puts [id] back where [_removeFromScenes] took it from.
  Future<void> _restoreToScenes(String id, {required bool person}) async {
    final places = _removedFromScenes.remove(id);
    if (places == null) return;
    final now = _clock.nowMs();
    for (final row in await _db.select(_db.trackSets).get()) {
      final index = places[row.id];
      if (index == null) continue;
      final set = row.toDomain();
      final ids = [...person ? set.scenePersonIds : set.sceneSubstanceIds];
      if (ids.contains(id)) continue;
      ids.insert(index > ids.length ? ids.length : index, id);
      await _writeScene(set, ids, person: person, now: now);
    }
  }

  Future<void> _writeScene(
    TrackSet set,
    List<String> ids, {
    required bool person,
    required int now,
  }) async {
    final next = person
        ? set.copyWith(scenePersonIds: ids)
        : set.copyWith(sceneSubstanceIds: ids);
    await (_db.update(_db.trackSets)..where((s) => s.id.equals(set.id))).write(
      TrackSetsCompanion(
        extraJson: Value(encodeSetExtra(next)),
        updatedAt: Value(now),
      ),
    );
  }

  // -------------------------------------------------------------- persons

  Future<List<Person>> getPersons({bool includeArchived = false}) async {
    final query = _db.select(_db.persons)
      ..orderBy([
        (p) => OrderingTerm.asc(p.sortIndex),
        (p) => OrderingTerm.asc(p.createdAt),
      ]);
    if (!includeArchived) query.where((p) => p.archived.equals(false));
    return [for (final r in await query.get()) r.toDomain()];
  }

  Stream<List<Person>> watchPersons({bool includeArchived = false}) =>
      watchTables(
        _db,
        [_db.persons],
        () => getPersons(includeArchived: includeArchived),
      );

  Future<Person> createPerson({
    required String name,
    int color = 0xFF888888,
    String? note,
  }) async {
    final now = _clock.nowMs();
    final count = await _db.persons.count().getSingle();
    final person = Person(
      id: _newId(),
      name: name.trim(),
      color: color,
      sortIndex: count,
      note: note,
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.persons).insert(person.toRow());
    return person;
  }

  /// Saves all fields of [person] (matched by id) and bumps `updatedAt`.
  Future<void> updatePerson(Person person) async {
    await _db
        .update(_db.persons)
        .replace(person.copyWith(updatedAt: _clock.nowMs()).toRow());
  }

  /// Hides (or restores) a person. Existing entries keep referring to it.
  Future<void> setPersonArchived(String id, {required bool archived}) async {
    await (_db.update(_db.persons)..where((p) => p.id.equals(id))).write(
      PersonsCompanion(
        archived: Value(archived),
        updatedAt: Value(_clock.nowMs()),
      ),
    );
  }

  /// Permanently deletes a person and returns it (for undo through
  /// [restorePerson]). Entries that refer to it keep the id and should be
  /// shown as "unbekannt"; prefer [setPersonArchived].
  ///
  /// The person also leaves the scene of every set; [restorePerson] puts
  /// it back there.
  Future<Person?> deletePerson(String id) {
    return _db.transaction(() async {
      final row = await (_db.select(
        _db.persons,
      )..where((p) => p.id.equals(id))).getSingleOrNull();
      if (row == null) return null;
      await (_db.delete(_db.persons)..where((p) => p.id.equals(id))).go();
      await _removeFromScenes(id, person: true);
      return row.toDomain();
    });
  }

  Future<void> restorePerson(Person person) async {
    await _db.transaction(() async {
      await _db.into(_db.persons).insertOnConflictUpdate(person.toRow());
      await _restoreToScenes(person.id, person: true);
    });
  }

  Future<void> reorderPersons(List<String> orderedIds) async {
    await _db.transaction(() async {
      final now = _clock.nowMs();
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(
          _db.persons,
        )..where((p) => p.id.equals(orderedIds[i]))).write(
          PersonsCompanion(sortIndex: Value(i), updatedAt: Value(now)),
        );
      }
    });
  }

  // ----------------------------------------------------------- substances

  Future<List<Substance>> getSubstances({bool includeArchived = false}) async {
    final query = _db.select(_db.substances)
      ..orderBy([
        (s) => OrderingTerm.asc(s.sortIndex),
        (s) => OrderingTerm.asc(s.createdAt),
      ]);
    if (!includeArchived) query.where((s) => s.archived.equals(false));
    return [for (final r in await query.get()) r.toDomain()];
  }

  Stream<List<Substance>> watchSubstances({bool includeArchived = false}) =>
      watchTables(
        _db,
        [_db.substances],
        () => getSubstances(includeArchived: includeArchived),
      );

  /// [lockoutMs] is only ever a value the user entered; `null` = none.
  Future<Substance> createSubstance({
    required String name,
    int color = 0xFF888888,
    int? lockoutMs,
    String? note,
  }) async {
    final now = _clock.nowMs();
    final count = await _db.substances.count().getSingle();
    final substance = Substance(
      id: _newId(),
      name: name.trim(),
      color: color,
      lockoutMs: lockoutMs,
      sortIndex: count,
      note: note,
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.substances).insert(substance.toRow());
    return substance;
  }

  /// Saves all fields of [substance] (matched by id) and bumps `updatedAt`.
  Future<void> updateSubstance(Substance substance) async {
    await _db
        .update(_db.substances)
        .replace(substance.copyWith(updatedAt: _clock.nowMs()).toRow());
  }

  Future<void> setSubstanceArchived(String id, {required bool archived}) async {
    await (_db.update(_db.substances)..where((s) => s.id.equals(id))).write(
      SubstancesCompanion(
        archived: Value(archived),
        updatedAt: Value(_clock.nowMs()),
      ),
    );
  }

  /// Permanently deletes a substance and returns it (for undo through
  /// [restoreSubstance]). Prefer [setSubstanceArchived].
  ///
  /// The substance also leaves the scene of every set; [restoreSubstance]
  /// puts it back there.
  Future<Substance?> deleteSubstance(String id) {
    return _db.transaction(() async {
      final row = await (_db.select(
        _db.substances,
      )..where((s) => s.id.equals(id))).getSingleOrNull();
      if (row == null) return null;
      await (_db.delete(_db.substances)..where((s) => s.id.equals(id))).go();
      await _removeFromScenes(id, person: false);
      return row.toDomain();
    });
  }

  Future<void> restoreSubstance(Substance substance) async {
    await _db.transaction(() async {
      await _db
          .into(_db.substances)
          .insertOnConflictUpdate(substance.toRow());
      await _restoreToScenes(substance.id, person: false);
    });
  }

  Future<void> reorderSubstances(List<String> orderedIds) async {
    await _db.transaction(() async {
      final now = _clock.nowMs();
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(
          _db.substances,
        )..where((s) => s.id.equals(orderedIds[i]))).write(
          SubstancesCompanion(sortIndex: Value(i), updatedAt: Value(now)),
        );
      }
    });
  }
}
