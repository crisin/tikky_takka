import '../domain/domain.dart';
import 'derive.dart';
import 'logical_day.dart';
import 'snapshots.dart';

/// Where a person stands at one moment: what the board shows on a tile.
final class PersonStand {
  const PersonStand({
    required this.personId,
    this.substanceId,
    this.lastAt,
    this.sinceMs,
    this.lockout,
  });

  final String personId;

  /// The thing the time refers to; `null` without any entry.
  final String? substanceId;

  /// When that thing was last had.
  final int? lastAt;

  /// Time since [lastAt], never negative.
  final int? sinceMs;

  /// The user's own lockout that is still running on [substanceId].
  final LockoutStatus? lockout;

  bool get hasEntry => lastAt != null;
}

/// The stand of [personId] at [nowMs] from the last entries per person and
/// thing ([facts]).
///
/// Decisive is the thing with a running lockout of the user's own (the one
/// that runs longest), otherwise the most recent entry. With [onlySubstanceId]
/// only that thing counts. Nothing is invented: a thing without a positive
/// value in [lockoutMsBySubstance] never locks.
PersonStand personStand(
  String personId,
  Iterable<LastEntryFact> facts,
  int nowMs, {
  Map<String, int> lockoutMsBySubstance = const {},
  String? onlySubstanceId,
}) {
  final own = [
    for (final f in facts)
      if (f.personId == personId &&
          f.substanceId != null &&
          (onlySubstanceId == null || f.substanceId == onlySubstanceId))
        f,
  ];
  if (own.isEmpty) return PersonStand(personId: personId);

  final lockouts = deriveLockouts(
    own,
    nowMs,
    lockoutMsBySubstance: lockoutMsBySubstance,
  )[personId];
  if (lockouts != null && lockouts.isNotEmpty) {
    final running = lockouts.first;
    return PersonStand(
      personId: personId,
      substanceId: running.substanceId,
      lastAt: running.lastEntryAt,
      sinceMs: _since(nowMs, running.lastEntryAt),
      lockout: running,
    );
  }
  final latest = own.reduce((a, b) => b.at > a.at ? b : a);
  return PersonStand(
    personId: personId,
    substanceId: latest.substanceId,
    lastAt: latest.at,
    sinceMs: _since(nowMs, latest.at),
  );
}

int _since(int nowMs, int at) => nowMs > at ? nowMs - at : 0;

/// The running lockout of [substanceId] for [personId], or `null`.
LockoutStatus? lockoutOf(
  String personId,
  String substanceId,
  Iterable<LastEntryFact> facts,
  int nowMs, {
  Map<String, int> lockoutMsBySubstance = const {},
}) => personStand(
  personId,
  facts,
  nowMs,
  lockoutMsBySubstance: lockoutMsBySubstance,
  onlySubstanceId: substanceId,
).lockout;

/// How often each person had each thing on the logical day of [nowMs]
/// (see [logicalDayOf]): person id -> thing id -> count.
Map<String, Map<String, int>> entryCountsOfDay(
  Iterable<Entry> entries,
  int nowMs,
  int dayStartMinutes,
) {
  final today = logicalDayOf(nowMs, dayStartMinutes);
  final result = <String, Map<String, int>>{};
  for (final e in entries) {
    if (logicalDayOf(e.at, dayStartMinutes) != today) continue;
    final byThing = result.putIfAbsent(e.personId, () => {});
    byThing[e.substanceId] = (byThing[e.substanceId] ?? 0) + 1;
  }
  return result;
}
