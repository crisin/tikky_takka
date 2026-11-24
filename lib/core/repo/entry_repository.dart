import 'package:drift/drift.dart';

import '../clock.dart';
import '../db/app_database.dart';
import '../domain/domain.dart';
import '../engine/derive.dart';
import 'mappers.dart';
import 'models.dart';
import 'watch.dart';

/// The protocol entries ("who had what, when").
///
/// Nothing here asks for confirmation; [delete] returns what [restore]
/// needs for "Rückgängig".
class EntryRepository {
  EntryRepository(this._db, this._clock, this._newId);

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _newId;

  /// Writes an entry at [at] (default: now).
  Future<Entry> add({
    required String personId,
    required String substanceId,
    int? at,
    String? amount,
    String? note,
  }) async {
    final now = _clock.nowMs();
    final entry = Entry(
      id: _newId(),
      at: at ?? now,
      personId: personId,
      substanceId: substanceId,
      amount: _clean(amount),
      note: _clean(note),
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.entries).insert(entry.toRow());
    return entry;
  }

  /// Stores [entry] as it is (apart from `updatedAt`). False when it no
  /// longer exists.
  Future<bool> update(Entry entry) async {
    final next = entry.copyWith(
      amount: () => _clean(entry.amount),
      note: () => _clean(entry.note),
      updatedAt: _clock.nowMs(),
    );
    return _db.update(_db.entries).replace(next.toRow());
  }

  /// Removes the entry and returns it, or `null` when it did not exist.
  Future<Entry?> delete(String id) async {
    final entry = await get(id);
    if (entry == null) return null;
    await (_db.delete(_db.entries)..where((e) => e.id.equals(id))).go();
    return entry;
  }

  /// Puts back an entry exactly as it was (undo of [delete] or of an edit).
  Future<void> restore(Entry entry) async {
    await _db.into(_db.entries).insertOnConflictUpdate(entry.toRow());
  }

  Future<Entry?> get(String id) async {
    final row = await (_db.select(
      _db.entries,
    )..where((e) => e.id.equals(id))).getSingleOrNull();
    return row?.toDomain();
  }

  Stream<Entry?> watch(String id) =>
      watchTables(_db, [_db.entries], () => get(id));

  /// The entries with `fromMs <= at < toMs`, oldest first.
  Future<List<Entry>> getRange(int fromMs, int toMs) async {
    final query = _db.select(_db.entries)
      ..where(
        (e) =>
            e.at.isBiggerOrEqualValue(fromMs) & e.at.isSmallerThanValue(toMs),
      )
      ..orderBy([
        (e) => OrderingTerm.asc(e.at),
        (e) => OrderingTerm.asc(e.createdAt),
      ]);
    return [for (final r in await query.get()) r.toDomain()];
  }

  Stream<List<Entry>> watchRange(int fromMs, int toMs) =>
      watchTables(_db, [_db.entries], () => getRange(fromMs, toMs));

  /// Every entry, oldest first (export, backup).
  Future<List<Entry>> getAll() => getRange(-(1 << 62), 1 << 62);

  /// When each person last had each thing.
  Future<List<LastEntryFact>> getLastEntries() async {
    final entries = _db.entries;
    final lastAt = entries.at.max();
    final query = _db.selectOnly(entries)
      ..addColumns([entries.personId, entries.substanceId, lastAt])
      ..groupBy([entries.personId, entries.substanceId]);
    return [
      for (final row in await query.get())
        if (row.read(lastAt) case final at?)
          LastEntryFact(
            personId: row.read(entries.personId),
            substanceId: row.read(entries.substanceId),
            at: at,
          ),
    ];
  }

  Stream<List<LastEntryFact>> watchLastEntries() =>
      watchTables(_db, [_db.entries], getLastEntries);

  /// How often each person had each thing, and when last.
  Future<List<SubstanceUse>> getUse() async {
    final entries = _db.entries;
    final lastAt = entries.at.max();
    final count = entries.id.count();
    final query = _db.selectOnly(entries)
      ..addColumns([entries.personId, entries.substanceId, lastAt, count])
      ..groupBy([entries.personId, entries.substanceId]);
    return [
      for (final row in await query.get())
        if (row.read(lastAt) case final at?)
          SubstanceUse(
            personId: row.read(entries.personId),
            substanceId: row.read(entries.substanceId),
            count: row.read(count) ?? 0,
            lastAt: at,
          ),
    ];
  }

  Stream<List<SubstanceUse>> watchUse() =>
      watchTables(_db, [_db.entries], getUse);

  /// The most recent entry of [personId], or `null`.
  Future<Entry?> lastOfPerson(String personId) async {
    final query = _db.select(_db.entries)
      ..where((e) => e.personId.equals(personId))
      ..orderBy([
        (e) => OrderingTerm.desc(e.at),
        (e) => OrderingTerm.desc(e.createdAt),
      ])
      ..limit(1);
    return (await query.getSingleOrNull())?.toDomain();
  }

  /// The entry of [personId] and [substanceId] right before [beforeMs].
  Future<Entry?> previousOf(
    String personId,
    String substanceId,
    int beforeMs,
  ) async {
    final query = _db.select(_db.entries)
      ..where(
        (e) =>
            e.personId.equals(personId) &
            e.substanceId.equals(substanceId) &
            e.at.isSmallerThanValue(beforeMs),
      )
      ..orderBy([(e) => OrderingTerm.desc(e.at)])
      ..limit(1);
    return (await query.getSingleOrNull())?.toDomain();
  }

  /// Distinct amounts the user typed for [substanceId] before, newest
  /// first. Always the user's own inputs, never values from the app.
  ///
  /// [exceptId]: the entry that is being edited never suggests its own
  /// amount.
  Future<List<String>> getAmounts(
    String substanceId, {
    String? exceptId,
    int limit = 6,
  }) async {
    final query = _db.select(_db.entries)
      ..where(
        (e) =>
            e.substanceId.equals(substanceId) &
            e.amount.isNotNull() &
            (exceptId == null
                ? const Constant(true)
                : e.id.equals(exceptId).not()),
      )
      ..orderBy([(e) => OrderingTerm.desc(e.at)])
      ..limit(200);
    final seen = <String>{};
    final result = <String>[];
    for (final row in await query.get()) {
      final amount = row.amount?.trim() ?? '';
      if (amount.isEmpty || !seen.add(amount.toLowerCase())) continue;
      result.add(amount);
      if (result.length >= limit) break;
    }
    return result;
  }

  static String? _clean(String? text) {
    final trimmed = text?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
