import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/domain.dart';
import '../../../core/engine/engine.dart';
import '../../../core/repo/repo.dart';
import '../../../core/services/haptics.dart';
import '../../../l10n/formatters.dart';
import '../../../l10n/strings.dart';
import '../../../theme/theme.dart';
import '../../protocol/protocol_widgets.dart';
import '../now_selector.dart';
import '../tracks_strings.dart';
import '../tracks_view.dart';

/// Keys of the person cards (for tests).
abstract final class PersonCardKeys {
  static const row = ValueKey('person-cards');
  static Key card(String trackId, String personId) =>
      ValueKey('person-card-$trackId/$personId');
}

/// What the card of a person above the strip shows (Pult 3.1).
@immutable
final class PersonCardData {
  const PersonCardData({
    required this.trackId,
    required this.personId,
    required this.name,
    required this.colorArgb,
    required this.since,
    required this.thing,
    this.lockoutUntil,
    this.otherThing,
    this.otherAt,
  });

  final String trackId;
  final String personId;
  final String name;

  /// `null` for a person that is not known (any more).
  final int? colorArgb;

  /// The entry the big time counts from, and what it was.
  final int since;
  final String thing;

  /// End of the lockout the user set on [thing], while it still runs.
  final int? lockoutUntil;

  /// The latest entry of something else.
  final String? otherThing;
  final int? otherAt;
}

/// One card per person with an entry in an open session of a protocol
/// track (in the order of their first entry).
///
/// The big time counts from the entry whose lockout (set by the user)
/// still runs - the one that ends last - else from the latest entry. The
/// line below says how long the lockout still runs, else what came last
/// of something else. Nothing is judged; a lockout exists only where the
/// user set one.
List<PersonCardData> buildPersonCards({
  required Iterable<HistorySession> sessions,
  required Map<String, Person> persons,
  required Map<String, Substance> substances,
  required int nowMs,
}) {
  // (track, person) -> entries, oldest first.
  final byPerson = <(String, String), List<TrackEvent>>{};
  for (final item in sessions) {
    if (item.session.endedAt != null) continue;
    if (item.track?.mode != TrackMode.protocol) continue;
    final entries = [
      for (final e in item.events)
        if (e.type == EventType.entry && e.personId != null && e.at <= nowMs) e,
    ]..sort((a, b) => a.at.compareTo(b.at));
    for (final e in entries) {
      byPerson
          .putIfAbsent((item.session.trackId, e.personId!), () => [])
          .add(e);
    }
  }
  final order = byPerson.keys.toList()
    ..sort((a, b) => byPerson[a]!.first.at.compareTo(byPerson[b]!.first.at));

  String thingOf(TrackEvent e) {
    final id = e.substanceId;
    if (id != null) return substances[id]?.name ?? Strings.unknown;
    final amount = (e.amount ?? '').trim();
    return amount.isEmpty ? Strings.protocolNoSubstance : amount;
  }

  return [
    for (final key in order)
      () {
        final entries = byPerson[key]!;
        // The latest entry per substance and the lockout it started.
        TrackEvent? locked;
        int? until;
        final latest = <String?, TrackEvent>{};
        for (final e in entries) {
          latest[e.substanceId] = e;
        }
        for (final e in latest.values) {
          final lockout = e.substanceId == null
              ? null
              : substances[e.substanceId]?.lockoutMs;
          if (lockout == null || lockout <= 0) continue;
          final end = e.at + lockout;
          if (end <= nowMs) continue;
          if (until == null || end > until) {
            until = end;
            locked = e;
          }
        }
        final main = locked ?? entries.last;
        TrackEvent? other;
        for (final e in entries.reversed) {
          if (e.substanceId != main.substanceId ||
              (e.substanceId == null && thingOf(e) != thingOf(main))) {
            other = e;
            break;
          }
        }
        final person = persons[key.$2];
        return PersonCardData(
          trackId: key.$1,
          personId: key.$2,
          name: person?.name ?? Strings.unknown,
          colorArgb: person?.color,
          since: main.at,
          thing: thingOf(main),
          lockoutUntil: until,
          otherThing: other == null ? null : thingOf(other),
          otherAt: other?.at,
        );
      }(),
  ];
}

/// The cards of the persons above the strip: two side by side, more
/// scroll sideways. A tap opens "Was?" of that person in the tap pad.
class PersonCards extends ConsumerWidget {
  const PersonCards({required this.setId, required this.sessions, super.key});

  final String setId;
  final List<HistorySession> sessions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tikky;
    final persons = ref.watch(personsByIdProvider);
    final substances = ref.watch(substancesByIdProvider);
    final hasCards = sessions.any(
      (s) =>
          s.session.endedAt == null &&
          s.track?.mode == TrackMode.protocol &&
          s.events.any((e) => e.type == EventType.entry && e.personId != null),
    );
    if (!hasCards) return const SizedBox.shrink();
    return NowSelector<int>(
      // Every second: the times count, a lockout may end.
      selector: (now) => now ~/ Duration.millisecondsPerSecond,
      builder: (context, second) {
        final now = second * Duration.millisecondsPerSecond;
        final cards = buildPersonCards(
          sessions: sessions,
          persons: persons,
          substances: substances,
          nowMs: now,
        );
        if (cards.isEmpty) return const SizedBox.shrink();
        return LayoutBuilder(
          builder: (context, constraints) {
            final gap = t.space.sm;
            final inset = t.space.pageLanes;
            final width = (constraints.maxWidth - 2 * inset - gap) / 2;
            return SingleChildScrollView(
              key: PersonCardKeys.row,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.fromLTRB(inset, 0, inset, t.space.sm),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) SizedBox(width: gap),
                      SizedBox(
                        width: width,
                        child: _PersonCard(
                          setId: setId,
                          card: cards[i],
                          nowMs: now,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PersonCard extends ConsumerWidget {
  const _PersonCard({
    required this.setId,
    required this.card,
    required this.nowMs,
  });

  final String setId;
  final PersonCardData card;
  final int nowMs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tikky;
    final since = Fmt.clock(nowMs - card.since);
    final sinceText = TracksStrings.cardSince(card.thing);
    final until = card.lockoutUntil;
    final otherAt = card.otherAt;
    final String? note;
    TextStyle noteStyle = t.text.cardNote;
    if (until != null) {
      note = TracksStrings.cardLockout(Fmt.compact(until - nowMs));
      noteStyle = noteStyle.copyWith(
        color: t.colors.warningText,
        fontWeight: FontWeight.w600,
      );
    } else if (card.otherThing != null && otherAt != null) {
      note = TracksStrings.cardOther(
        card.otherThing!,
        Fmt.compact(nowMs - otherAt),
      );
    } else {
      note = null;
    }
    void open() {
      ref.read(hapticsProvider).selection();
      ref
          .read(padPageRequestProvider.notifier)
          .open(setId, trackId: card.trackId, personId: card.personId);
    }

    return Semantics(
      button: true,
      label: TracksStrings.cardSemantics(card.name, '$since $sinceText', note),
      excludeSemantics: true,
      onTap: open,
      child: Material(
        key: PersonCardKeys.card(card.trackId, card.personId),
        color: t.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radii.small),
          side: t.hairline,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: open,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: t.space.md,
              vertical: t.space.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PersonInitial(
                      name: card.name,
                      color: card.colorArgb == null
                          ? null
                          : Color(card.colorArgb!),
                      size: t.strip.cardAvatar,
                      style: t.text.stripName,
                    ),
                    SizedBox(width: t.space.sm),
                    Expanded(
                      child: Text(
                        card.name,
                        style: t.text.laneName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: t.space.xs),
                // "seit Bier" moves below the time when both do not fit.
                Wrap(
                  spacing: t.space.xs,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    Text(since, style: t.text.cardDigits, maxLines: 1),
                    Text(
                      sinceText,
                      style: t.text.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                if (note != null) ...[
                  SizedBox(height: t.space.xs),
                  Text(
                    note,
                    style: noteStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
