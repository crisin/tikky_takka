import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/domain.dart';
import '../../core/engine/engine.dart';
import '../../core/repo/repo.dart';
import '../../core/services/haptics.dart';
import '../../l10n/formatters.dart';
import '../../l10n/strings.dart';

// ------------------------------------------------------------ pure helpers

/// The protocol state of an open session at [nowMs], or `null` when the
/// track has no open session.
ProtocolSnapshot? protocolSnapshotOf(
  OpenSession? open, {
  required int nowMs,
  Map<String, int> lockouts = const {},
}) {
  if (open == null) return null;
  final snapshot = deriveSnapshot(
    config: open.session.config,
    events: open.events,
    nowMs: nowMs,
    lockoutMsBySubstance: lockouts,
  );
  return snapshot is ProtocolSnapshot ? snapshot : null;
}

/// All entries of [sessions], newest first.
List<TrackEvent> newestEntries(
  Iterable<HistorySession> sessions, {
  int limit = 300,
}) {
  final entries = <TrackEvent>[
    for (final s in sessions)
      for (final e in s.events)
        if (e.type == EventType.entry) e,
  ]..sort((a, b) => compareEvents(b, a));
  return entries.length > limit ? entries.sublist(0, limit) : entries;
}

/// Distinct amounts the user typed before, newest first.
///
/// With a [substanceId] only amounts logged for that substance are offered:
/// an amount typed for something else is never carried over. These are
/// always the user's own earlier inputs, never values from the app.
List<String> recentAmounts(
  Iterable<TrackEvent> newestFirst, {
  String? substanceId,
  int limit = 6,
}) {
  final seen = <String>{};
  final result = <String>[];
  for (final e in newestFirst) {
    if (e.type != EventType.entry) continue;
    if (substanceId != null && e.substanceId != substanceId) continue;
    final amount = e.amount?.trim();
    if (amount == null || amount.isEmpty) continue;
    if (!seen.add(amount.toLowerCase())) continue;
    result.add(amount);
    if (result.length >= limit) break;
  }
  return result;
}

/// The most recent entry of a person (`null` = entries without a person).
TrackEvent? lastEntryOfPerson(Iterable<TrackEvent> events, String? personId) {
  TrackEvent? last;
  for (final e in events) {
    if (e.type != EventType.entry || e.personId != personId) continue;
    if (last == null || compareEvents(e, last) > 0) last = e;
  }
  return last;
}

/// How many one-tap substance buttons a person gets.
const int captureSubstanceLimit = 5;

/// The substances offered as one-tap buttons to [personId] (`null` =
/// entries without a person), at most [limit]:
///
/// 1. the scene's substances, in the order of the scene;
/// 2. then the substances this person logged most often on the track
///    ([use], over all sessions), the most recently logged one first when
///    the counts are equal.
///
/// Only ids in [available] (the user's current substance list) are
/// returned. This orders the user's own list by the user's own entries;
/// nothing is suggested by the app.
List<String> topSubstanceIds({
  required List<String> sceneSubstanceIds,
  required Iterable<SubstanceUse> use,
  required String? personId,
  required Set<String> available,
  int limit = captureSubstanceLimit,
}) {
  final result = <String>[];
  for (final id in sceneSubstanceIds) {
    if (result.length >= limit) return result;
    if (available.contains(id) && !result.contains(id)) result.add(id);
  }
  final own = <String, SubstanceUse>{};
  for (final u in use) {
    final id = u.substanceId;
    if (id == null || u.personId != personId) continue;
    if (!available.contains(id) || result.contains(id)) continue;
    final known = own[id];
    own[id] = known == null
        ? u
        : SubstanceUse(
            personId: personId,
            substanceId: id,
            count: known.count + u.count,
            lastAt: u.lastAt > known.lastAt ? u.lastAt : known.lastAt,
          );
  }
  final ranked = own.values.toList()
    ..sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      final byRecency = b.lastAt.compareTo(a.lastAt);
      if (byRecency != 0) return byRecency;
      return a.substanceId!.compareTo(b.substanceId!);
    });
  for (final u in ranked) {
    if (result.length >= limit) break;
    result.add(u.substanceId!);
  }
  return result;
}

/// Keeps buttons where they are while the lane is in use: the ids of
/// [shown] that are still in [available] stay at their place, then [fresh]
/// fills the free places up to [limit]. A button never moves under a
/// finger because another one became more used a moment ago.
List<String> keepButtonOrder(
  List<String> shown,
  List<String> fresh, {
  required Set<String> available,
  int limit = captureSubstanceLimit,
}) {
  final result = [
    for (final id in shown)
      if (available.contains(id)) id,
  ];
  for (final id in fresh) {
    if (result.length >= limit) break;
    if (!result.contains(id)) result.add(id);
  }
  return result.length > limit ? result.sublist(0, limit) : result;
}

/// How often [personId] logged each substance in the open session.
Map<String, int> sessionCounts(OpenSession? open, String? personId) {
  final counts = <String, int>{};
  for (final e in open?.events ?? const <TrackEvent>[]) {
    final id = e.substanceId;
    if (e.type != EventType.entry || e.personId != personId || id == null) {
      continue;
    }
    counts[id] = (counts[id] ?? 0) + 1;
  }
  return counts;
}

/// Rounds a remaining time UP for display (to the minute from ten minutes
/// on, to the second below), so a lockout never reads shorter than it is.
int roundUpRemaining(int ms) {
  if (ms <= 0) return 0;
  final unit = ms >= 10 * 60 * 1000 ? 60 * 1000 : 1000;
  return (ms + unit - 1) ~/ unit * unit;
}

/// "frühestens wieder in ..." duration text for [remainingMs].
String formatRemaining(int remainingMs) =>
    Fmt.compact(roundUpRemaining(remainingMs));

/// Display name of a person id: "Ohne Person" for none, "Unbekannt" for a
/// person that no longer exists.
String personLabel(String? personId, Map<String, Person> persons) {
  if (personId == null) return Strings.protocolNoPerson;
  return persons[personId]?.name ?? Strings.unknown;
}

/// Display name of a substance id, `null` when the entry has none.
String? substanceLabel(String? substanceId, Map<String, Substance> substances) {
  if (substanceId == null) return null;
  return substances[substanceId]?.name ?? Strings.unknown;
}

/// "Substanz · Menge" of an entry; "Ohne Angabe" when it has neither.
String entrySummary(TrackEvent entry, Map<String, Substance> substances) {
  final parts = [
    ?substanceLabel(entry.substanceId, substances),
    if (entry.amount case final amount? when amount.trim().isNotEmpty)
      amount.trim(),
  ];
  return parts.isEmpty ? Strings.protocolNoSubstance : parts.join(' · ');
}

/// Whether two instants fall on the same local calendar day.
bool sameLocalDay(int aMs, int bMs) =>
    LocalDay.fromMs(aMs) == LocalDay.fromMs(bMs);

/// Time of an entry: only the time today, date and time otherwise.
String entryTimeLabel(int atMs, {required int nowMs, bool use24h = true}) =>
    sameLocalDay(atMs, nowMs)
    ? Fmt.time(atMs, use24h: use24h)
    : Fmt.dateTime(atMs, use24h: use24h);

// ----------------------------------------------------------------- actions

/// A freshly logged entry, with what is needed to take it back.
final class AddedEntry {
  const AddedEntry(this.event, {required this.createdSession});

  final TrackEvent event;

  /// The entry opened a new session (the track was idle before).
  final bool createdSession;
}

/// The write side of the protocol feature. Widgets fetch it BEFORE an async
/// gap or a snackbar, so undo callbacks never touch a disposed `ref`.
///
/// Nothing here asks for confirmation; every destructive step returns what
/// is needed for "Rückgängig".
class ProtocolActions {
  const ProtocolActions({
    required this.commands,
    required this.history,
    required this.people,
    required this.haptics,
  });

  final TrackCommands commands;
  final HistoryRepository history;
  final PeopleRepository people;
  final Haptics haptics;

  /// Logs an entry ([at] `null` = now). Opens a session when needed.
  Future<AddedEntry?> addEntry(
    String trackId, {
    String? personId,
    String? substanceId,
    String? amount,
    String? note,
    int? at,
  }) async {
    final hadSession = await commands.getOpenSession(trackId) != null;
    final event = await commands.addEntry(
      trackId,
      personId: personId,
      substanceId: substanceId,
      amount: amount,
      note: note,
      at: at,
    );
    if (event == null) return null;
    return AddedEntry(event, createdSession: !hadSession);
  }

  /// Takes [added] back. A session that only existed because of this entry
  /// and is empty again disappears with it.
  Future<void> undoAdd(AddedEntry added) async {
    await history.deleteEvent(added.event.id);
    if (!added.createdSession) return;
    final open = await commands.getOpenSession(added.event.trackId);
    if (open == null || open.session.id != added.event.sessionId) return;
    if (open.events.any((e) => e.type == EventType.entry)) return;
    await commands.resetTrack(added.event.trackId, discard: true);
  }

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

  /// Like [ensurePerson], for substances. A new substance never gets a
  /// lockout here; that is set by the user in the substance list.
  Future<Substance?> ensureSubstance(
    String name, {
    required int color,
  }) async {
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

  /// Saves an edited entry. Returns `false` when it no longer exists.
  Future<bool> updateEntry(TrackEvent entry) => history.updateEvent(entry);

  /// Deletes an entry and returns it for [restoreEntry].
  Future<TrackEvent?> deleteEntry(String eventId) =>
      history.deleteEvent(eventId);

  Future<void> restoreEntry(TrackEvent entry) => history.restoreEvent(entry);

  /// Ends the open session; returns its id for [reopenSession].
  Future<String?> finishSession(String trackId) => commands.stopTrack(trackId);

  Future<bool> reopenSession(String sessionId) =>
      commands.reopenSession(sessionId);
}

final protocolActionsProvider = Provider<ProtocolActions>(
  (ref) => ProtocolActions(
    commands: ref.watch(trackCommandsProvider),
    history: ref.watch(historyRepositoryProvider),
    people: ref.watch(peopleRepositoryProvider),
    haptics: ref.watch(hapticsProvider),
  ),
);

/// When each person last logged each substance on a track, over all its
/// sessions. The lane and the entry sheet derive the running lockouts from
/// it (`deriveLockouts`), so "frühestens wieder in ..." survives "Sitzung
/// beenden" and the start of a new session.
final protocolLastEntriesProvider = StreamProvider.autoDispose
    .family<List<LastEntryFact>, String>(
      (ref, trackId) =>
          ref.watch(historyRepositoryProvider).watchLastEntries(trackId),
    );

/// How often each person logged each substance on a track, over all its
/// sessions. Orders the one-tap substance buttons ([topSubstanceIds]).
final protocolSubstanceUseProvider = StreamProvider.autoDispose
    .family<List<SubstanceUse>, String>(
      (ref, trackId) =>
          ref.watch(historyRepositoryProvider).watchSubstanceUse(trackId),
    );

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

/// The facts of one open session, in the shape of
/// [protocolLastEntriesProvider] (used until that has loaded).
List<LastEntryFact> lastEntriesOfSession(OpenSession? open) => [
  for (final e in open?.events ?? const <TrackEvent>[])
    if (e.type == EventType.entry)
      LastEntryFact(personId: e.personId, substanceId: e.substanceId, at: e.at),
];

/// Every entry ever logged on a track (open and closed sessions), newest
/// first. Source of the "Zuletzt eingetragen" amount suggestions.
final protocolEntryHistoryProvider = StreamProvider.autoDispose
    .family<List<TrackEvent>, String>(
      (ref, trackId) => ref
          .watch(historyRepositoryProvider)
          .watchSessions(HistoryFilter(trackIds: {trackId}, includeOpen: true))
          .map(newestEntries),
    );
