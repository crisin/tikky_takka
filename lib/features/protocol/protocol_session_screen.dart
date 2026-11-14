import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../core/domain/domain.dart';
import '../../core/engine/engine.dart';
import '../../core/now_ticker.dart';
import '../../core/repo/repo.dart';
import '../../l10n/strings.dart';
import '../../theme/theme.dart';
import 'protocol_entry_sheet.dart';
import 'protocol_logic.dart';
import 'protocol_people_screen.dart';
import 'protocol_strings.dart';
import 'protocol_widgets.dart';

/// Opens the entry list of the open session of a protocol track.
Future<void> openProtocolSession(BuildContext context, {required Track track}) =>
    pushAdaptivePage<void>(
      context,
      builder: (_) => ProtocolSessionScreen(track: track),
    );

/// The entries of the open session of a protocol track, newest first.
///
/// Tap an entry to edit it (person, substance, amount, note, time), use the
/// bin to delete it. Nothing asks for confirmation; every change offers
/// "Rückgängig". "Sitzung beenden" closes the session, which then shows up
/// in the history; the next entry starts a new one.
class ProtocolSessionScreen extends ConsumerWidget {
  const ProtocolSessionScreen({required this.track, super.key});

  final Track track;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    TrackEvent entry,
  ) async {
    final actions = ref.read(protocolActionsProvider);
    final deleted = await actions.deleteEntry(entry.id);
    await actions.haptics.heavy();
    if (deleted == null || !context.mounted) return;
    showUndoSnackBar(
      context,
      message: Strings.protocolDeleted,
      onUndo: () => actions.restoreEntry(deleted),
    );
  }

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    final actions = ref.read(protocolActionsProvider);
    final sessionId = await actions.finishSession(track.id);
    await actions.haptics.heavy();
    if (sessionId == null || !context.mounted) return;
    // Shown before leaving: the snackbar moves on to the screen below.
    showUndoSnackBar(
      context,
      message: ProtocolStrings.sessionFinished,
      onUndo: () => actions.reopenSession(sessionId),
    );
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The track may be renamed or recoloured while this screen is open.
    final track = ref.watch(trackProvider(this.track.id)) ?? this.track;
    final open = ref.watch(openSessionProvider(track.id));
    final persons = ref.watch(personsByIdProvider);
    final substances = ref.watch(substancesByIdProvider);
    final entries = [
      for (final e in sortEvents(open?.events ?? const <TrackEvent>[]))
        if (e.type == EventType.entry) e,
    ].reversed.toList();

    // A pushed page is outside the tracks screen, so the theme and UI
    // preferences of the track's set are applied again here.
    return SetThemeScope(
      setId: track.setId,
      child: Builder(
        builder: (context) {
          final t = context.tikky;
          final nowMs = ref.watch(nowTickerProvider).value;

          final Widget body;
          if (open == null) {
            body = AdaptiveEmptyState(
              icon: ProtocolIcons.entries(context),
              title: ProtocolStrings.noOpenSessionTitle,
              message: ProtocolStrings.noOpenSessionBody,
            );
          } else {
            body = ListView(
              padding: EdgeInsets.symmetric(vertical: t.space.sm),
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: t.space.page,
                    vertical: t.space.sm,
                  ),
                  child: Text(
                    [
                      ProtocolStrings.sessionSince(
                        entryTimeLabel(
                          open.session.startedAt,
                          nowMs: nowMs,
                          use24h: t.prefs.use24h,
                        ),
                      ),
                      ProtocolStrings.entryCount(entries.length),
                    ].join(' · '),
                    style: t.text.laneTitle,
                  ),
                ),
                if (entries.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(t.space.page),
                    child: Text(
                      ProtocolStrings.sessionEmptyBody,
                      style: t.text.bodyMuted,
                    ),
                  ),
                for (final entry in entries)
                  _EntryRow(
                    key: ValueKey('entry-${entry.id}'),
                    entry: entry,
                    nowMs: nowMs,
                    persons: persons,
                    substances: substances,
                    onEdit: () => showProtocolEntrySheet(
                      context,
                      track: track,
                      existing: entry,
                    ),
                    onDelete: () => _delete(context, ref, entry),
                  ),
                const ProtocolNeutralNote(),
              ],
            );
          }

          return AdaptivePageScaffold(
            title: Text(track.name),
            actions: [
              AdaptiveIconButton(
                icon: AdaptiveIcons.person(context),
                semanticLabel: ProtocolStrings.peopleTitle,
                onPressed: () => openProtocolPeople(context),
              ),
            ],
            body: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: t.sizes.maxContentWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: body),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(top: t.hairline),
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          t.space.page,
                          t.space.sm,
                          t.space.page,
                          t.space.sm,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: t.sizes.bigTapTarget,
                              ),
                              child: AdaptiveFilledButton(
                                key: const ValueKey('session-add'),
                                label: Strings.actionAddEntry,
                                icon: AdaptiveIcons.add(context),
                                onPressed: () => showProtocolEntrySheet(
                                  context,
                                  track: track,
                                ),
                              ),
                            ),
                            if (open != null)
                              AdaptiveTextButton(
                                key: const ValueKey('session-finish'),
                                label: ProtocolStrings.finishSession,
                                onPressed: () => _finish(context, ref),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.nowMs,
    required this.persons,
    required this.substances,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final TrackEvent entry;
  final int nowMs;
  final Map<String, Person> persons;
  final Map<String, Substance> substances;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final person = entry.personId == null ? null : persons[entry.personId];
    final note = entry.note?.trim() ?? '';
    final name = personLabel(entry.personId, persons);
    final summary = entrySummary(entry, substances);
    final time = entryTimeLabel(
      entry.at,
      nowMs: nowMs,
      use24h: t.prefs.use24h,
    );
    final headline = t.text.headline;
    final lineHeight = (headline.fontSize ?? 0) * (headline.height ?? 1);
    final dotInset = lineHeight > t.sizes.dot
        ? (lineHeight - t.sizes.dot) / 2
        : 0.0;

    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        button: true,
        hint: ProtocolStrings.editEntry,
        child: InkWell(
          onTap: onEdit,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: t.sizes.bigTapTarget),
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                t.space.page,
                t.space.sm,
                t.space.xs,
                t.space.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: dotInset),
                          child: ColorDot(
                            color: person == null
                                ? t.colors.textMuted
                                : Color(person.color),
                          ),
                        ),
                        SizedBox(width: t.space.sm),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$name · $summary', style: headline),
                              Text(time, style: t.text.digitsSmall),
                              if (note.isNotEmpty)
                                Text(note, style: t.text.subLine),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  AdaptiveIconButton(
                    icon: AdaptiveIcons.delete(context),
                    semanticLabel: ProtocolStrings.deleteEntry,
                    size: t.sizes.iconLg,
                    color: t.colors.textMuted,
                    onPressed: onDelete,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
