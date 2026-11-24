import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/domain.dart';
import '../../core/engine/engine.dart';
import '../../core/repo/repo.dart';
import '../../l10n/formatters.dart';
import '../../l10n/strings.dart';

// ------------------------------------------------------------ pure helpers

/// How many things the page "Was?" shows before "Anderes".
const int captureSubstanceLimit = 5;

/// Rounds a remaining time UP for display (to the minute from ten minutes
/// on, to the second below), so a lockout never reads shorter than it is.
int roundUpRemaining(int ms) {
  if (ms <= 0) return 0;
  final unit = ms >= 10 * 60 * 1000 ? 60 * 1000 : 1000;
  return (ms + unit - 1) ~/ unit * unit;
}

/// "noch ..." duration text for [remainingMs].
String formatRemaining(int remainingMs) =>
    Fmt.compact(roundUpRemaining(remainingMs));

/// Display name of a person id; "Unbekannt" for a person that no longer
/// exists.
String personLabel(String? personId, Map<String, Person> persons) {
  if (personId == null) return Strings.protocolNoPerson;
  return persons[personId]?.name ?? Strings.unknown;
}

/// Display name of a thing id, `null` without one.
String? substanceLabel(String? substanceId, Map<String, Substance> substances) {
  if (substanceId == null) return null;
  return substances[substanceId]?.name ?? Strings.unknown;
}

/// The remaining lockout (ms) of [substanceId] for [personId] at [nowMs],
/// or `null` when none is running.
int? lockoutRemainingFor(
  Iterable<LastEntryFact> lastEntries, {
  required String? personId,
  required String substanceId,
  required int nowMs,
  required Map<String, int> lockouts,
}) {
  final running = deriveLockouts(
    lastEntries,
    nowMs,
    lockoutMsBySubstance: lockouts,
  )[personId];
  for (final lockout in running ?? const <LockoutStatus>[]) {
    if (lockout.substanceId == substanceId) return lockout.remainingMs;
  }
  return null;
}

// ------------------------------------------------------- persons and things

/// Finds or creates the persons and things the user names inline (the
/// scene, "Anderes"). Widgets fetch it BEFORE an async gap, so it never
/// touches a disposed `ref`.
class ProtocolActions {
  const ProtocolActions({required this.people});

  final PeopleRepository people;

  /// The person called [name]: an existing one (brought back to the list
  /// when it was removed) or a new one with [color]. `null` for a blank
  /// name.
  Future<Person?> ensurePerson(String name, {required int color}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    Person? match;
    for (final p in await people.getPersons(includeArchived: true)) {
      if (p.name.toLowerCase() == trimmed.toLowerCase()) match = p;
    }
    if (match == null) return people.createPerson(name: trimmed, color: color);
    if (match.archived) {
      await people.setPersonArchived(match.id, archived: false);
    }
    return match;
  }

  /// Like [ensurePerson], for things. A new thing never gets a lockout
  /// here; that is set by the user in its editor.
  Future<Substance?> ensureSubstance(String name, {required int color}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    Substance? match;
    for (final s in await people.getSubstances(includeArchived: true)) {
      if (s.name.toLowerCase() == trimmed.toLowerCase()) match = s;
    }
    if (match == null) {
      return people.createSubstance(name: trimmed, color: color);
    }
    if (match.archived) {
      await people.setSubstanceArchived(match.id, archived: false);
    }
    return match;
  }
}

final protocolActionsProvider = Provider<ProtocolActions>(
  (ref) => ProtocolActions(people: ref.watch(peopleRepositoryProvider)),
);
