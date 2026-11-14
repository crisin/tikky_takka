import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../core/core.dart';
import '../../l10n/formatters.dart';
import '../../l10n/strings.dart';
import '../../theme/theme.dart';
import 'history_actions.dart';
import 'history_strings.dart';
import 'history_widgets.dart';
import 'session_detail_page.dart';

/// The sessions matching the active filter, grouped by day with a day
/// total. Tap opens the session, long-press (or secondary click) offers
/// note and delete, swiping a row away deletes it - always with undo.
class HistorySessionList extends ConsumerStatefulWidget {
  const HistorySessionList({super.key});

  @override
  ConsumerState<HistorySessionList> createState() => _HistorySessionListState();
}

enum _SessionAction { editNote, delete }

class _HistorySessionListState extends ConsumerState<HistorySessionList> {
  /// Sessions swiped away whose deletion has not come back from the
  /// database stream yet. A dismissed row must leave the tree at once.
  final Set<String> _hidden = {};

  Future<void> _delete(String sessionId, {bool hide = false}) async {
    if (hide) setState(() => _hidden.add(sessionId));
    final repo = ref.read(historyRepositoryProvider);
    unawaited(ref.read(hapticsProvider).heavy());
    final deleted = await repo.deleteSession(sessionId);
    if (!mounted) return;
    if (deleted == null) {
      setState(() => _hidden.remove(sessionId));
      return;
    }
    showUndoSnackBar(
      context,
      message: Strings.sessionDeleted,
      onUndo: () {
        if (mounted) setState(() => _hidden.remove(sessionId));
        unawaited(repo.restoreSession(deleted));
      },
    );
  }

  Future<void> _open(HistorySession item) async {
    final result = await pushAdaptivePage<SessionDetailResult>(
      context,
      builder: (context) => SessionDetailPage(sessionId: item.session.id),
    );
    if (result == SessionDetailResult.delete && mounted) {
      await _delete(item.session.id);
    }
  }

  Future<void> _showActions(HistorySession item) async {
    unawaited(ref.read(hapticsProvider).selection());
    final action = await showAdaptiveActionSheet<_SessionAction>(
      context,
      title: item.track?.name ?? Strings.deletedTrack,
      actions: [
        AdaptiveSheetAction(
          value: _SessionAction.editNote,
          label: item.session.note == null
              ? HistoryStrings.addNote
              : Strings.editNote,
          icon: AdaptiveIcons.note(context),
        ),
        AdaptiveSheetAction(
          value: _SessionAction.delete,
          label: Strings.deleteSession,
          icon: AdaptiveIcons.delete(context),
          destructive: true,
        ),
      ],
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _SessionAction.editNote:
        await HistoryActions.editSessionNote(context, ref, item.session);
      case _SessionAction.delete:
        await _delete(item.session.id);
    }
  }

  /// [days] without the rows that were just swiped away.
  List<HistoryDay> _visible(List<HistoryDay> days) {
    if (_hidden.isEmpty) return days;
    // Once the deletion has arrived there is nothing left to hide; keeping
    // the id would hide the session again should it ever come back (undo,
    // backup import).
    final present = {
      for (final day in days)
        for (final s in day.sessions) s.session.id,
    };
    _hidden.removeWhere((id) => !present.contains(id));
    if (_hidden.isEmpty) return days;
    return [
      for (final day in days)
        if (day.sessions.any((s) => !_hidden.contains(s.session.id)))
          () {
            final sessions = [
              for (final s in day.sessions)
                if (!_hidden.contains(s.session.id)) s,
            ];
            return HistoryDay(
              day: day.day,
              sessions: sessions,
              totalNetMs: sessions.fold(0, (sum, s) => sum + s.summary.netMs),
            );
          }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final async = ref.watch(historyDaysProvider);
    final filter = ref.watch(historyFilterProvider);
    final use24h = ref.watch(uiPrefsProvider.select((p) => p.use24h));
    final nowMs = ref.watch(clockProvider).nowMs();

    return async.when(
      loading: () => const AdaptiveProgress(),
      error: (error, _) => AdaptiveEmptyState(
        icon: AdaptiveIcons.close(context),
        title: Strings.errorGeneric,
        message: '$error',
      ),
      data: (allDays) {
        final days = _visible(allDays);
        if (days.isEmpty) return HistoryEmptyState(filter: filter);
        return ListView.builder(
          padding: EdgeInsets.only(bottom: t.space.xl),
          itemCount: days.length,
          itemBuilder: (context, index) {
            final day = days[index];
            return HistoryGroup(
              key: ValueKey(day.day),
              title: Fmt.dayHeader(day.day, todayMs: nowMs),
              caption: Strings.sessionCount(day.sessions.length),
              trailing: HistoryStrings.total(
                Strings.dayTotal,
                Fmt.compact(day.totalNetMs),
              ),
              children: [
                for (final item in day.sessions)
                  Dismissible(
                    key: ValueKey(item.session.id),
                    direction: DismissDirection.endToStart,
                    background: const SwipeDeleteBackground(
                      semanticLabel: Strings.deleteSession,
                    ),
                    onDismissed: (_) =>
                        unawaited(_delete(item.session.id, hide: true)),
                    child: SessionTile(
                      item: item,
                      use24h: use24h,
                      onTap: () => _open(item),
                      onActions: () => _showActions(item),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Friendly empty state: nothing recorded yet, or nothing matches the
/// filter (then with a button to reset it).
class HistoryEmptyState extends ConsumerWidget {
  const HistoryEmptyState({required this.filter, super.key});

  final HistoryFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (filter.isUnrestricted) {
      return AdaptiveEmptyState(
        icon: AdaptiveIcons.history(context),
        title: Strings.historyEmptyTitle,
        message: Strings.historyEmptyBody,
      );
    }
    return AdaptiveEmptyState(
      icon: AdaptiveIcons.filter(context),
      title: Strings.historyNoMatchTitle,
      message: Strings.historyNoMatchBody,
      action: AdaptiveFilledButton(
        label: Strings.filterReset,
        onPressed: () => ref.read(historyFilterProvider.notifier).reset(),
      ),
    );
  }
}

/// One session in the list: colour bar, track name, a muted line with time
/// range, mode and count, an optional note, and the net duration.
class SessionTile extends StatelessWidget {
  const SessionTile({
    required this.item,
    required this.use24h,
    required this.onTap,
    required this.onActions,
    super.key,
  });

  final HistorySession item;
  final bool use24h;
  final VoidCallback onTap;

  /// Long-press / secondary click.
  final VoidCallback onActions;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final track = item.track;
    final summary = item.summary;
    final start = summary.startAt ?? item.session.startedAt;
    final end = item.session.endedAt ?? summary.endAt;
    final note = item.session.note;
    final subLine = HistoryStrings.joined([
      end == null
          ? Fmt.time(start, use24h: use24h)
          : HistoryStrings.timeRange(
              Fmt.time(start, use24h: use24h),
              Fmt.time(end, use24h: use24h),
            ),
      Strings.modeName(item.session.mode),
      if (summary.count > 0)
        HistoryStrings.countLabel(item.session.mode, summary.count),
    ]);

    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        onLongPress: onActions,
        onSecondaryTap: onActions,
        child: HistoryColorBarRow(
          color: track == null ? t.colors.border : t.trackColor(track),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: t.sizes.minTapTarget),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: t.space.md,
                vertical: t.space.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          track?.name ?? Strings.deletedTrack,
                          style: t.text.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: t.space.xxs),
                        Text(subLine, style: t.text.subLine),
                        if (note != null) ...[
                          SizedBox(height: t.space.xxs),
                          Text(
                            note,
                            style: t.text.caption,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: t.space.md),
                  Text(
                    Fmt.clock(summary.netMs),
                    style: t.text.digitsMedium,
                    semanticsLabel: Fmt.compact(summary.netMs),
                  ),
                  SizedBox(width: t.space.xs),
                  Icon(
                    AdaptiveIcons.chevronRight(context),
                    size: t.sizes.iconSm,
                    color: t.colors.textMuted,
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
