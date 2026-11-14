import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../adaptive/adaptive.dart';
import '../../../core/clock.dart';
import '../../../core/domain/domain.dart';
import '../../../core/engine/engine.dart';
import '../../../core/repo/repo.dart';
import '../../../core/services/haptics.dart';
import '../../../l10n/formatters.dart';
import '../../../l10n/strings.dart';
import '../../../theme/theme.dart';
import '../../protocol/protocol_logic.dart';
import '../../protocol/protocol_widgets.dart';
import '../lane_view.dart';
import '../now_selector.dart';
import '../tracks_strings.dart';
import 'strip/strip_view.dart';
import 'timeline_event_sheet.dart';
import 'timeline_logic.dart';
import 'timeline_mode.dart';
import 'timeline_summary.dart';

/// Keys of the timeline view (for tests).
abstract final class TimelineKeys {
  static const view = ValueKey('timeline-view');
  static const strip = ValueKey('timeline-strip');
  static const list = ValueKey('timeline-list');
  static const summary = ValueKey('timeline-summary');
  static const order = ValueKey('timeline-order');
  static const lifecycle = ValueKey('timeline-lifecycle');
  static const mode = ValueKey('timeline-mode');
  static const scope = ValueKey('timeline-scope');
  static const sort = ValueKey('timeline-sort');
  static Key trackChip(String trackId) => ValueKey('timeline-track-$trackId');
  static Key row(String eventId) => ValueKey('timeline-row-$eventId');
  static Key stripChip(String trackId) => ValueKey('timeline-strip-$trackId');
  static Key group(String title) => ValueKey('timeline-group-$title');
}

/// The sessions behind the timeline of one set for one scope: a stream
/// that is scoped to the range in the database
/// (`HistoryRepository.watchSetActivity`) and only lives while the
/// timeline is shown. A moving range is re-evaluated on every reload.
final timelineActivityProvider = StreamProvider.autoDispose
    .family<List<HistorySession>, ({String setId, TimelineScope scope})>((
      ref,
      key,
    ) {
      final clock = ref.watch(clockProvider);
      return ref
          .watch(historyRepositoryProvider)
          .watchSetActivity(
            key.setId,
            sinceMs: key.scope == TimelineScope.open
                ? null
                : () => timelineSince(key.scope, clock.nowMs()),
          );
    });

/// "Zeitleiste": everything that happened in a set, across all its
/// tracks - as a strip with the time from left to right ("Streifen", the
/// default), as a list to walk through ("Liste") or, switched to
/// "Zusammenfassung", what came together overall. The mode is remembered
/// per set ([timelineModeProvider]).
///
/// * Pinned at the top: the running timers of the set ([RunningStrip]),
///   so they stay in view while reading.
/// * Scope (a chip that opens the choices): the open sessions (default),
///   today, or the last 24 hours.
/// * Strip: see [StripView]. The scope and the filters apply to it too.
/// * List: newest first (or oldest first), lifecycle events hidden
///   unless asked for, tracks can be filtered, a marker where more than
///   [timelineGapThresholdMs] passed. A tap opens the event editor.
/// * Summary: grouped totals, see [buildSummary].
///
/// While the tracks destination is not the visible one, the data stream
/// is paused (`TickerMode` off, see `watchTables`) and catches up with a
/// single reload afterwards.
class TimelineView extends ConsumerStatefulWidget {
  const TimelineView({required this.setId, required this.tracks, super.key});

  final String setId;

  /// Ordered, non-archived tracks of the set.
  final List<Track> tracks;

  @override
  ConsumerState<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends ConsumerState<TimelineView> {
  TimelineScope _scope = TimelineScope.open;
  bool _newestFirst = true;
  bool _showLifecycle = false;
  SummarySort _sort = SummarySort.count;
  final Set<String> _hiddenTracks = {};

  void _set(VoidCallback change) {
    ref.read(hapticsProvider).selection();
    setState(change);
  }

  static String _scopeLabel(TimelineScope scope) => switch (scope) {
    TimelineScope.open => TracksStrings.scopeOpen,
    TimelineScope.today => TracksStrings.scopeToday,
    TimelineScope.last24h => TracksStrings.scopeLast24h,
  };

  Future<void> _pickScope() async {
    final picked = await showAdaptiveActionSheet<TimelineScope>(
      context,
      title: TracksStrings.scopeLabel,
      actions: [
        for (final scope in TimelineScope.values)
          AdaptiveSheetAction(
            value: scope,
            label: _scopeLabel(scope),
            selected: scope == _scope,
          ),
      ],
    );
    if (picked == null || !mounted) return;
    _set(() => _scope = picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final tracks = widget.tracks;
    final mode = ref.watch(timelineModeProvider(widget.setId));
    final chipRowPadding = EdgeInsets.symmetric(horizontal: t.space.page);

    Widget chipRow(List<Widget> chips) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: chipRowPadding,
      child: Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) SizedBox(width: t.space.sm),
            chips[i],
          ],
        ],
      ),
    );

    // Row 1: strip, list or summary, and the order of the list.
    final modeRow = Padding(
      padding: EdgeInsets.symmetric(horizontal: t.space.page),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              container: true,
              label: TracksStrings.modeSwitch,
              child: KeyedSubtree(
                key: TimelineKeys.mode,
                child: AdaptiveSegmented<TimelineMode>(
                  segments: const {
                    TimelineMode.strip: TracksStrings.modeStrip,
                    TimelineMode.list: TracksStrings.modeTimeline,
                    TimelineMode.summary: TracksStrings.modeSummary,
                  },
                  // Three words have to share the width of a phone.
                  fitLabels: true,
                  selected: mode,
                  onChanged: (next) {
                    ref.read(hapticsProvider).selection();
                    ref
                        .read(timelineModesProvider.notifier)
                        .show(widget.setId, next);
                  },
                ),
              ),
            ),
          ),
          if (mode == TimelineMode.list)
            AdaptiveIconButton(
              key: TimelineKeys.order,
              icon: _newestFirst
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              semanticLabel: _newestFirst
                  ? TracksStrings.timelineNewestFirst
                  : TracksStrings.timelineOldestFirst,
              onPressed: () => _set(() => _newestFirst = !_newestFirst),
            ),
        ],
      ),
    );

    // Row 2: the range, then the filters (timeline) or the sorting
    // (summary). The range and the lifecycle filter come first, so they
    // are in view on a phone; the track chips scroll.
    final filterRow = chipRow([
      Semantics(
        container: true,
        label: TracksStrings.scopeLabel,
        child: ActionChip(
          key: TimelineKeys.scope,
          avatar: Icon(AdaptiveIcons.calendar(context), size: t.sizes.iconSm),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_scopeLabel(_scope)),
              Icon(AdaptiveIcons.chevronDown(context), size: t.sizes.iconSm),
            ],
          ),
          onPressed: _pickScope,
        ),
      ),
      if (mode == TimelineMode.summary)
        Semantics(
          container: true,
          label: TracksStrings.sortLabel,
          child: ActionChip(
            key: TimelineKeys.sort,
            avatar: Icon(Icons.sort_rounded, size: t.sizes.iconSm),
            label: Text(
              _sort == SummarySort.count
                  ? TracksStrings.sortByCount
                  : TracksStrings.sortByLast,
            ),
            onPressed: () => _set(
              () => _sort = _sort == SummarySort.count
                  ? SummarySort.last
                  : SummarySort.count,
            ),
          ),
        )
      else ...[
        FilterChip(
          key: TimelineKeys.lifecycle,
          label: const Text(TracksStrings.timelineShowLifecycle),
          selected: _showLifecycle,
          onSelected: (on) => _set(() => _showLifecycle = on),
        ),
        if (tracks.length > 1)
          for (final track in tracks)
            FilterChip(
              key: TimelineKeys.trackChip(track.id),
              avatar: ColorDot(color: t.trackColor(track)),
              label: Text(track.name),
              selected: !_hiddenTracks.contains(track.id),
              onSelected: (on) => _set(() {
                if (on) {
                  _hiddenTracks.remove(track.id);
                } else {
                  _hiddenTracks.add(track.id);
                }
              }),
            ),
      ],
    ]);

    return Column(
      key: TimelineKeys.view,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RunningStrip(tracks: tracks),
        modeRow,
        SizedBox(height: t.space.xs),
        filterRow,
        Divider(height: t.space.sm, color: t.colors.border),
        Expanded(
          child: TickerMode(
            // Offstage (another destination is shown): pause the stream.
            enabled: Visibility.of(context),
            child: _TimelineBody(
              setId: widget.setId,
              scope: _scope,
              tracks: tracks,
              mode: mode,
              newestFirst: _newestFirst,
              showLifecycle: _showLifecycle,
              hiddenTracks: _hiddenTracks,
              sort: _sort,
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineBody extends ConsumerWidget {
  const _TimelineBody({
    required this.setId,
    required this.scope,
    required this.tracks,
    required this.mode,
    required this.newestFirst,
    required this.showLifecycle,
    required this.hiddenTracks,
    required this.sort,
  });

  final String setId;
  final TimelineScope scope;
  final List<Track> tracks;
  final TimelineMode mode;
  final bool newestFirst;
  final bool showLifecycle;
  final Set<String> hiddenTracks;
  final SummarySort sort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tikky;
    final async = ref.watch(
      timelineActivityProvider((setId: setId, scope: scope)),
    );
    final sessions = async.value;
    if (sessions == null) {
      return async.hasError
          ? AdaptiveEmptyState(
              icon: AdaptiveIcons.close(context),
              title: Strings.errorGeneric,
              message: '${async.error}',
            )
          : const AdaptiveProgress();
    }
    final now = ref.watch(clockProvider).nowMs();
    final since = timelineSince(scope, now);
    final personNames = {
      for (final p in ref.watch(personsByIdProvider).values) p.id: p.name,
    };
    final substanceNames = {
      for (final s in ref.watch(substancesByIdProvider).values) s.id: s.name,
    };

    Widget empty(String title, [String? message]) => AdaptiveEmptyState(
      icon: AdaptiveIcons.history(context),
      title: title,
      message: message,
    );
    final emptyMessage = scope == TimelineScope.open
        ? TracksStrings.timelineEmptyOpen
        : TracksStrings.timelineEmptyRange;

    if (mode == TimelineMode.strip) {
      return StripView(
        setId: setId,
        scope: scope,
        tracks: tracks,
        sessions: sessions,
        sinceMs: since,
        showLifecycle: showLifecycle,
        hiddenTracks: hiddenTracks,
        emptyMessage: emptyMessage,
      );
    }

    if (mode == TimelineMode.summary) {
      final groups = buildSummary(
        sessions: sessions,
        sinceMs: since,
        sort: sort,
        personNames: personNames,
        substanceNames: substanceNames,
      );
      if (groups.isEmpty) {
        return empty(TracksStrings.summaryEmptyTitle, emptyMessage);
      }
      return ListView.separated(
        key: TimelineKeys.summary,
        padding: EdgeInsets.all(t.space.page),
        itemCount: groups.length,
        separatorBuilder: (_, _) => SizedBox(height: t.space.sm),
        itemBuilder: (context, index) => Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: t.sizes.maxContentWidth),
            child: _SummaryCard(group: groups[index], nowMs: now),
          ),
        ),
      );
    }

    final rows = buildTimelineRows(
      sessions: sessions,
      sinceMs: since,
      personNames: personNames,
      substanceNames: substanceNames,
      newestFirst: newestFirst,
    );
    if (rows.isEmpty) {
      return empty(TracksStrings.timelineEmptyTitle, emptyMessage);
    }
    final items = withGapMarkers(
      filterTimelineRows(
        rows,
        showLifecycle: showLifecycle,
        hiddenTrackIds: hiddenTracks,
      ),
    );
    if (items.isEmpty) {
      return empty(
        TracksStrings.timelineEmptyTitle,
        TracksStrings.timelineAllHidden,
      );
    }
    return ListView.builder(
      key: TimelineKeys.list,
      padding: EdgeInsets.symmetric(vertical: t.space.sm),
      itemCount: items.length,
      itemBuilder: (context, index) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: t.sizes.maxContentWidth),
          child: switch (items[index]) {
            TimelineGapItem(:final ms) => _GapMarker(
              ms: ms,
              newestFirst: newestFirst,
            ),
            TimelineEventItem(:final row) => _RowTile(
              key: TimelineKeys.row(row.event.id),
              row: row,
              onTap: () => openTimelineEvent(context, ref, row),
            ),
          },
        ),
      ),
    );
  }
}

/// One event: time, the track's colour dot and name, what happened.
class _RowTile extends StatelessWidget {
  const _RowTile({required this.row, required this.onTap, super.key});

  final TimelineRow row;
  final VoidCallback onTap;

  /// From this width on a row is a single line.
  static const double _oneLineMinWidth = 520;

  /// The track name's share of a single-line row.
  static const double _nameMaxWidth = 160;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final muted = row.isLifecycle;
    final time = Fmt.time(row.at, use24h: t.prefs.use24h, seconds: true);
    final note = row.note;
    return Semantics(
      button: true,
      label: TracksStrings.timelineRowSemantics(
        time,
        row.track.name,
        note == null ? row.text : '${row.text}, $note',
      ),
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: muted ? t.sizes.iconLg : t.sizes.minTapTarget,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: t.space.page,
              vertical: muted ? t.space.xxs : t.space.xs,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final timeText = Text(
                  time,
                  style: muted
                      ? t.text.caption
                      : t.text.digitsSmall.copyWith(color: t.colors.text),
                );
                final name = Text(
                  row.track.name,
                  style: muted ? t.text.caption : t.text.laneTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
                final what = Text(
                  row.text,
                  style: muted ? t.text.caption : t.text.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                );
                final noteText = note == null || note.isEmpty
                    ? null
                    : Text(
                        note,
                        style: t.text.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      );
                final lead = [
                  timeText,
                  SizedBox(width: t.space.md),
                  ColorDot(color: t.trackColor(row.track)),
                  SizedBox(width: t.space.sm),
                ];
                // Room for everything in one line; lifecycle rows are
                // short enough for one line everywhere.
                if (muted || constraints.maxWidth >= _oneLineMinWidth) {
                  return Row(
                    children: [
                      ...lead,
                      Flexible(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: muted ? double.infinity : _nameMaxWidth,
                          ),
                          child: name,
                        ),
                      ),
                      SizedBox(width: t.space.md),
                      if (muted)
                        Flexible(child: what)
                      else
                        Expanded(
                          flex: 3,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [what, ?noteText],
                          ),
                        ),
                    ],
                  );
                }
                // A phone: time and the track's name above what happened
                // (the name moves below the time when both do not fit).
                return Row(
                  children: [
                    ColorDot(color: t.trackColor(row.track)),
                    SizedBox(width: t.space.sm),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: t.space.sm,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [timeText, name],
                          ),
                          what,
                          ?noteText,
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// "12 min später": the subtle marker between two rows.
class _GapMarker extends StatelessWidget {
  const _GapMarker({required this.ms, required this.newestFirst});

  final int ms;
  final bool newestFirst;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final duration = Fmt.compact(ms);
    final line = Expanded(
      child: Divider(height: t.sizes.hairline, color: t.colors.border),
    );
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: t.space.page,
        vertical: t.space.xs,
      ),
      child: Row(
        children: [
          line,
          Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space.md),
            child: Text(
              // Reading downwards: later with the oldest on top, earlier
              // with the newest on top.
              newestFirst
                  ? TracksStrings.gapEarlier(duration)
                  : TracksStrings.gapLater(duration),
              style: t.text.caption,
            ),
          ),
          line,
        ],
      ),
    );
  }
}

/// The totals of one group of the summary.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.group, required this.nowMs});

  final SummaryGroup group;
  final int nowMs;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final use24h = t.prefs.use24h;
    String time(int at) => entryTimeLabel(at, nowMs: nowMs, use24h: use24h);

    final header = Row(
      children: [
        ColorDot(color: t.trackColor(group.track)),
        SizedBox(width: t.space.sm),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              group.title,
              style: t.text.headline,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (group.lines.length > 1)
          Text(TracksStrings.summaryTotal(group.total), style: t.text.caption),
      ],
    );

    final List<Widget> body;
    if (group.kind == SummaryGroupKind.stopwatch) {
      body = [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                [
                  TracksStrings.summaryNetTime,
                  if (group.lapCount > 0)
                    TracksStrings.summaryLaps(group.lapCount),
                ].join(TracksStrings.separator),
                style: t.text.body,
              ),
            ),
            Text(
              Fmt.clock(group.netMs),
              style: t.text.digitsMedium,
              semanticsLabel: Fmt.compact(group.netMs),
            ),
          ],
        ),
      ];
    } else {
      body = [
        for (final line in group.lines)
          Padding(
            padding: EdgeInsets.only(top: t.space.xs),
            child: MergeSemantics(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(line.label, style: t.text.body),
                        Text(
                          [
                            TracksStrings.summaryFirstLast(
                              time(line.firstAt),
                              time(line.lastAt),
                            ),
                            // Only counters: how regularly it was counted.
                            if (group.kind == SummaryGroupKind.counter)
                              if (line.averageGapMs case final gap?)
                                TracksStrings.summaryAvgGap(Fmt.compact(gap)),
                          ].join(TracksStrings.separator),
                          style: t.text.caption,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: t.space.md),
                  Text(
                    TracksStrings.summaryCount(line.count),
                    style: t.text.digitsMedium,
                  ),
                ],
              ),
            ),
          ),
      ];
    }

    return DecoratedBox(
      key: TimelineKeys.group(group.title),
      decoration: t.surfaceDecoration(),
      child: Padding(
        padding: EdgeInsets.all(t.space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            SizedBox(height: t.space.xs),
            ...body,
          ],
        ),
      ),
    );
  }
}

/// The running timers of a set in one compact line: name, colour, live
/// time. Stopwatches, countdowns, intervals and reminders that are
/// running or ringing; paused ones are not listed.
class RunningStrip extends ConsumerWidget {
  const RunningStrip({required this.tracks, super.key});

  final List<Track> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tikky;
    final sessions =
        ref.watch(openSessionsProvider).value ?? const <String, OpenSession>{};
    final candidates = [
      for (final track in tracks)
        if (track.mode.supportsStartPause &&
            laneSession(track, sessions[track.id]) != null)
          track,
    ];
    return Semantics(
      container: true,
      label: TracksStrings.stripLabel,
      child: SizedBox(
        key: TimelineKeys.strip,
        height: t.sizes.minTapTarget,
        // Which timers run can change by itself (a countdown ends), so
        // the list follows the ticker - but only rebuilds when it changes.
        child: NowSelector<String>(
          enabled: candidates.isNotEmpty,
          selector: (now) => [
            for (final track in candidates)
              if (laneSnapshot(track, sessions[track.id], now).isTicking)
                track.id,
          ].join('\n'),
          builder: (context, ids) {
            final running = ids.isEmpty
                ? const <String>{}
                : ids.split('\n').toSet();
            final shown = [
              for (final track in candidates)
                if (running.contains(track.id)) track,
            ];
            if (shown.isEmpty) {
              return Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: t.space.page),
                  child: Text(
                    TracksStrings.stripNothingRunning,
                    style: t.text.caption,
                  ),
                ),
              );
            }
            return ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(
                horizontal: t.space.page,
                vertical: t.space.xs,
              ),
              itemCount: shown.length,
              separatorBuilder: (_, _) => SizedBox(width: t.space.sm),
              itemBuilder: (context, index) => _StripChip(
                key: TimelineKeys.stripChip(shown[index].id),
                track: shown[index],
                open: sessions[shown[index].id],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StripChip extends StatelessWidget {
  const _StripChip({required this.track, required this.open, super.key});

  final Track track;
  final OpenSession? open;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final prefs = t.prefs;
    return DecoratedBox(
      decoration: t.surfaceDecoration(color: t.colors.surfaceAlt),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: t.space.md),
        child: MergeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ColorDot(color: t.trackColor(track)),
              SizedBox(width: t.space.sm),
              Text(track.name, style: t.text.label),
              SizedBox(width: t.space.sm),
              NowSelector<String>(
                selector: (now) => buildLaneView(
                  track: track,
                  open: open,
                  nowMs: now,
                  prefs: prefs,
                ).time.digits,
                builder: (context, digits) => Text(
                  digits,
                  style: t.text.digitsSmall.copyWith(color: t.colors.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
