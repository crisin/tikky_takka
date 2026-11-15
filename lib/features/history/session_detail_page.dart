import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../core/core.dart';
import '../../l10n/formatters.dart';
import '../../l10n/strings.dart';
import '../../theme/theme.dart';
import '../protocol/protocol_entry_sheet.dart';
import 'history_actions.dart';
import 'history_strings.dart';
import 'history_widgets.dart';

/// What the detail page asks its opener to do when it closes.
enum SessionDetailResult {
  /// Delete the session (the opener stays visible and shows the undo
  /// snackbar).
  delete,
}

/// One session: figures, note and the list of its events (laps, ticks with
/// labels, protocol entries, acknowledgements with their delay). Events
/// can be annotated and deleted, the session note edited, the session
/// deleted.
class SessionDetailPage extends ConsumerWidget {
  const SessionDetailPage({required this.sessionId, super.key});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sessionDetailProvider(sessionId));
    final item = async.value;
    return AdaptivePageScaffold(
      title: Text(
        item == null
            ? Strings.sessionDetail
            : item.track?.name ?? Strings.deletedTrack,
      ),
      actions: [
        if (item != null) ...[
          AdaptiveIconButton(
            icon: AdaptiveIcons.note(context),
            semanticLabel: Strings.editNote,
            onPressed: () =>
                HistoryActions.editSessionNote(context, ref, item.session),
          ),
          AdaptiveIconButton(
            icon: AdaptiveIcons.delete(context),
            semanticLabel: Strings.deleteSession,
            onPressed: () =>
                Navigator.of(context).pop(SessionDetailResult.delete),
          ),
        ],
      ],
      body: async.when(
        loading: () => const AdaptiveProgress(),
        error: (error, _) => AdaptiveEmptyState(
          icon: AdaptiveIcons.close(context),
          title: Strings.errorGeneric,
          message: '$error',
        ),
        data: (item) => item == null
            ? AdaptiveEmptyState(
                icon: AdaptiveIcons.history(context),
                title: HistoryStrings.sessionGone,
              )
            : HistoryContentWidth(child: _SessionDetailBody(item: item)),
      ),
    );
  }
}

class _SessionDetailBody extends ConsumerWidget {
  const _SessionDetailBody({required this.item});

  final HistorySession item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tikky;
    final use24h = ref.watch(uiPrefsProvider.select((p) => p.use24h));
    final persons = ref.watch(personsByIdProvider);
    final substances = ref.watch(substancesByIdProvider);
    final session = item.session;
    final summary = item.summary;
    final track = item.track;
    final start = summary.startAt ?? session.startedAt;
    final end = session.endedAt ?? summary.endAt;
    final note = session.note;

    // Mode specific figures come from the same pure engine the lanes use.
    final snapshot = deriveSnapshot(
      config: session.config,
      events: item.events,
      nowMs: end ?? ref.watch(clockProvider).nowMs(),
    );
    final acks = {
      if (snapshot is ReminderSnapshot)
        for (final ack in snapshot.acks) ack.eventId: ack,
    };
    // Labels that were never tapped in this session are left out.
    final labelCounts = {
      if (snapshot is CounterSnapshot)
        for (final e in snapshot.labelCounts.entries)
          if (e.value > 0) e.key: e.value,
    };
    final annotations = annotateEvents(item.events);
    final personNames = {for (final p in persons.values) p.id: p.name};
    final substanceNames = {for (final s in substances.values) s.id: s.name};

    return ListView(
      padding: EdgeInsets.only(bottom: t.space.xl),
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            t.space.page,
            t.space.lg,
            t.space.page,
            t.space.xs,
          ),
          child: HistoryColorBarRow(
            color: track == null ? t.colors.border : t.trackColor(track),
            child: Padding(
              padding: EdgeInsetsDirectional.only(start: t.space.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    HistoryStrings.joined([
                      Strings.modeName(session.mode),
                      item.set?.name ?? '',
                    ]),
                    style: t.text.laneTitle,
                  ),
                  SizedBox(height: t.space.xs),
                  Text(
                    Fmt.clock(summary.netMs),
                    style: t.text.digitsLarge,
                    semanticsLabel: Fmt.compact(summary.netMs),
                  ),
                  SizedBox(height: t.space.xs),
                  Text(
                    Fmt.dayLong(LocalDay.fromMs(start)),
                    style: t.text.subLine,
                  ),
                ],
              ),
            ),
          ),
        ),
        AdaptiveSection(
          header: HistoryStrings.sessionSummary,
          children: [
            AdaptiveTile(
              title: Strings.started,
              value: Fmt.dateTime(start, use24h: use24h),
            ),
            AdaptiveTile(
              title: Strings.ended,
              value: end == null
                  ? HistoryStrings.sessionRunning
                  : Fmt.dateTime(end, use24h: use24h),
            ),
            AdaptiveTile(
              title: Strings.netDuration,
              value: Fmt.hms(summary.netMs),
            ),
            if (summary.pausedMs > 0)
              AdaptiveTile(
                title: Strings.pausedDuration,
                value: Fmt.hms(summary.pausedMs),
              ),
            if (summary.count > 0)
              AdaptiveTile(
                title: session.mode == TrackMode.stopwatch
                    ? Strings.laps
                    : Strings.count,
                subtitle: labelCounts.isEmpty
                    ? null
                    : HistoryStrings.joined([
                        for (final e in labelCounts.entries)
                          '${e.key} ${e.value}',
                      ]),
                value: Strings.countValue(summary.count),
              ),
          ],
        ),
        AdaptiveSection(
          header: Strings.note,
          children: [
            AdaptiveTile(
              leading: Icon(AdaptiveIcons.note(context)),
              title: note ?? HistoryStrings.addNote,
              onTap: () =>
                  HistoryActions.editSessionNote(context, ref, session),
            ),
          ],
        ),
        AdaptiveSection(
          header: Strings.events,
          children: [
            for (final annotation in annotations)
              _EventTile(
                key: ValueKey(annotation.event.id),
                line: describeEvent(
                  annotation,
                  personNames: personNames,
                  substanceNames: substanceNames,
                  ack: acks[annotation.event.id],
                ),
                time: Fmt.time(
                  annotation.event.at,
                  use24h: use24h,
                  seconds: true,
                ),
                onActions: HistoryActions.isEditable(annotation.event)
                    ? () => _showEventActions(context, ref, annotation.event)
                    : null,
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _showEventActions(
    BuildContext context,
    WidgetRef ref,
    TrackEvent event,
  ) async {
    final track = item.track;
    unawaited(ref.read(hapticsProvider).selection());
    final action = await showAdaptiveActionSheet<_EventAction>(
      context,
      title: Strings.eventTypeName(event.type),
      actions: [
        // Entries are edited in the protocol sheet (who, what, amount,
        // note and time); it needs the track.
        if (event.type == EventType.entry && track != null)
          AdaptiveSheetAction(
            value: _EventAction.editEntry,
            label: HistoryStrings.editEntry,
            icon: AdaptiveIcons.edit(context),
          )
        else
          AdaptiveSheetAction(
            value: _EventAction.editNote,
            label: event.note == null
                ? HistoryStrings.addNote
                : Strings.editNote,
            icon: AdaptiveIcons.note(context),
          ),
        AdaptiveSheetAction(
          value: _EventAction.delete,
          label: Strings.deleteEvent,
          icon: AdaptiveIcons.delete(context),
          destructive: true,
        ),
      ],
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _EventAction.editEntry:
        await showProtocolEntrySheet(context, track: track!, existing: event);
      case _EventAction.editNote:
        await HistoryActions.editEventNote(context, ref, event);
      case _EventAction.delete:
        await HistoryActions.deleteEvent(context, ref, event);
    }
  }
}

enum _EventAction { editEntry, editNote, delete }

/// The texts of one event row.
final class EventLine {
  const EventLine({required this.title, this.detail, this.note, this.figure});

  /// "Runde 3", "Tipp 2 · Reiher", "Alex · Wasser", "Bestätigt", ...
  final String title;

  /// Amount of an entry, delay of an acknowledgement.
  final String? detail;
  final String? note;

  /// Lap duration or time since the previous tick.
  final String? figure;
}

/// Describes an event for the detail list. Pure.
///
/// [ack] carries the delay of a reminder acknowledgement; unknown person /
/// substance ids show as "Unbekannt", missing ones as "Ohne ...".
EventLine describeEvent(
  EventAnnotation annotation, {
  Map<String, String> personNames = const {},
  Map<String, String> substanceNames = const {},
  AckInfo? ack,
}) {
  final event = annotation.event;
  final n = annotation.runningCount;
  final lapMs = annotation.lapMs;
  final label = event.label ?? '';
  final figure = lapMs == null ? null : Fmt.clock(lapMs, tenths: true);
  switch (event.type) {
    case EventType.lap:
      return EventLine(
        title: HistoryStrings.joined([
          if (n == null)
            Strings.eventTypeName(event.type)
          else
            Strings.lapNumber(n),
          label,
        ]),
        note: event.note,
        figure: figure,
      );
    case EventType.tick:
      return EventLine(
        title: HistoryStrings.joined([
          if (n == null)
            Strings.eventTypeName(event.type)
          else
            HistoryStrings.tickNumber(n),
          label,
        ]),
        note: event.note,
        figure: figure,
      );
    case EventType.entry:
      final personId = event.personId;
      final substanceId = event.substanceId;
      return EventLine(
        title: HistoryStrings.joined([
          personId == null
              ? Strings.protocolNoPerson
              : personNames[personId] ?? Strings.unknown,
          substanceId == null
              ? Strings.protocolNoSubstance
              : substanceNames[substanceId] ?? Strings.unknown,
        ]),
        detail: event.amount,
        note: event.note,
      );
    case EventType.ack:
      return EventLine(
        title: Strings.eventTypeName(event.type),
        detail: ack == null
            ? null
            : ack.delayMs < 1000
            ? HistoryStrings.ackOnTime
            : HistoryStrings.ackDelayed(Fmt.compact(ack.delayMs)),
        note: event.note,
      );
    case EventType.extend:
      return EventLine(
        title: Strings.eventTypeName(event.type),
        detail: HistoryStrings.extendedBy(Fmt.compact(event.extendMs)),
        note: event.note,
      );
    case EventType.start ||
        EventType.pause ||
        EventType.resume ||
        EventType.stop ||
        EventType.skip:
      return EventLine(
        title: Strings.eventTypeName(event.type),
        note: event.note,
      );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.line,
    required this.time,
    required this.onActions,
    super.key,
  });

  final EventLine line;
  final String time;

  /// `null` for events that cannot be changed (start, stop).
  final VoidCallback? onActions;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final detail = line.detail;
    final note = line.note;
    final figure = line.figure;
    return InkWell(
      onTap: onActions,
      onLongPress: onActions,
      onSecondaryTap: onActions,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: t.sizes.minTapTarget),
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: t.space.page,
            end: onActions == null ? t.space.page : t.space.xs,
            top: t.space.xs,
            bottom: t.space.xs,
          ),
          child: Row(
            children: [
              Text(time, style: t.text.digitsSmall),
              SizedBox(width: t.space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(line.title, style: t.text.label),
                    if (detail != null && detail.isNotEmpty)
                      Text(detail, style: t.text.subLine),
                    if (note != null && note.isNotEmpty)
                      Text(note, style: t.text.caption),
                  ],
                ),
              ),
              if (figure != null) ...[
                SizedBox(width: t.space.sm),
                Text(figure, style: t.text.digitsSmall),
              ],
              if (onActions != null)
                AdaptiveIconButton(
                  icon: AdaptiveIcons.more(context),
                  semanticLabel: HistoryStrings.eventActions,
                  size: t.sizes.iconSm,
                  onPressed: onActions,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
