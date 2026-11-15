import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../adaptive/adaptive.dart';
import '../../../core/domain/domain.dart';
import '../../../core/engine/engine.dart';
import '../../../core/repo/repo.dart';
import '../../../core/services/haptics.dart';
import '../../../l10n/formatters.dart';
import '../../../l10n/strings.dart';
import '../../../theme/theme.dart';
import '../../protocol/entry_edit_sheet.dart';
import '../../protocol/protocol_widgets.dart';
import '../now_selector.dart';
import '../tracks_strings.dart';
import 'evening/evening_view.dart';
import 'person_cards.dart';
import 'strip/strip_view.dart';
import 'timeline_event_sheet.dart';
import 'timeline_logic.dart';
import 'timeline_mode.dart';

/// Keys of the timeline view (for tests).
abstract final class TimelineKeys {
  static const view = ValueKey('timeline-view');
  static const list = ValueKey('timeline-list');
  static const order = ValueKey('timeline-order');
  static const lifecycle = ValueKey('timeline-lifecycle');
  static const level = ValueKey('timeline-level');
  static const previous = ValueKey('timeline-previous');
  static const next = ValueKey('timeline-next');
  static const day = ValueKey('timeline-day');
  static const compact = ValueKey('timeline-compact');
  static Key trackChip(String trackId) => ValueKey('timeline-track-$trackId');
  static Key row(String eventId) => ValueKey('timeline-row-$eventId');
}

/// What the timeline of a set reads: the open sessions (`from` `null`),
/// or the sessions of a range.
typedef TimelineRange = ({String setId, int? from, int? to});

/// The sessions behind the timeline of one set: a stream scoped to the
/// range in the database (`HistoryRepository.watchSetActivity`) that only
/// lives while the timeline is shown.
final timelineActivityProvider = StreamProvider.autoDispose
    .family<List<HistorySession>, TimelineRange>((ref, key) {
      final from = key.from;
      return ref
          .watch(historyRepositoryProvider)
          .watchSetActivity(
            key.setId,
            sinceMs: from == null ? null : () => from,
            untilMs: key.to,
          );
    });

/// "Zeitleiste": everything that happened in a set, across its tracks.
/// The level is remembered per set ([timelineChoiceProvider]):
///
/// * "Jetzt": the strip of the open sessions ([StripView]) with a card
///   per person above it ([PersonCards]).
/// * "Abend": one logical day (it starts at the time set in the
///   preferences, 06:00 by default), the time running downwards
///   ([EveningView]); "Kompakt" shows the same day as a list - newest (or
///   oldest) first, a marker where more than [timelineGapThresholdMs]
///   passed, a tap opens the event editor.
/// * Start and stop are hidden unless asked for; tracks can be hidden.
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
  /// The evening shown; `null` = the one going on now.
  LocalDay? _day;
  bool _newestFirst = true;
  bool _showLifecycle = false;
  final Set<String> _hiddenTracks = {};

  void _set(VoidCallback change) {
    ref.read(hapticsProvider).selection();
    setState(change);
  }

  @override
  void didUpdateWidget(TimelineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.setId != widget.setId) _day = null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final tracks = widget.tracks;
    final choice = ref.watch(timelineChoiceProvider(widget.setId));
    final dayStart = t.prefs.dayStartMinutes;
    // The evening going on changes with the time: listen to the day.
    return NowSelector<LocalDay>(
      selector: (now) => logicalDayOf(now, dayStart),
      builder: (context, today) => _build(context, t, tracks, choice, today),
    );
  }

  Widget _build(
    BuildContext context,
    TikkyTokens t,
    List<Track> tracks,
    TimelineChoice choice,
    LocalDay today,
  ) {
    final dayStart = t.prefs.dayStartMinutes;
    final choices = ref.read(timelineChoicesProvider.notifier);
    final day = _day ?? today;
    final evening = choice.level == TimelineLevel.evening;
    final compact = evening && choice.compact;

    // "Jetzt" / "Abend" ("Woche" and "Monat" follow).
    final levelRow = Padding(
      padding: EdgeInsets.symmetric(horizontal: t.space.page),
      child: Semantics(
        container: true,
        label: TracksStrings.levelSwitch,
        child: KeyedSubtree(
          key: TimelineKeys.level,
          child: AdaptiveSegmented<TimelineLevel>(
            segments: const {
              TimelineLevel.now: TracksStrings.levelNow,
              TimelineLevel.evening: TracksStrings.levelEvening,
            },
            selected: choice.level,
            onChanged: (next) {
              ref.read(hapticsProvider).selection();
              choices.show(widget.setId, next);
            },
          ),
        ),
      ),
    );

    final filterRow = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: t.space.page),
      child: Row(
        children: [
          FilterChip(
            key: TimelineKeys.lifecycle,
            label: const Text(TracksStrings.timelineShowLifecycle),
            selected: _showLifecycle,
            onSelected: (on) => _set(() => _showLifecycle = on),
          ),
          if (tracks.length > 1)
            for (final track in tracks) ...[
              SizedBox(width: t.space.sm),
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
        ],
      ),
    );

    final from = evening ? logicalDayStartMs(day, dayStart) : null;
    final to = evening ? logicalDayEndMs(day, dayStart) : null;

    return Column(
      key: TimelineKeys.view,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        levelRow,
        SizedBox(height: t.space.xs),
        if (evening)
          _DayRow(
            setId: widget.setId,
            day: day,
            fromMs: from!,
            toMs: to!,
            isToday: day == today,
            compact: compact,
            newestFirst: _newestFirst,
            onDay: (next) => _set(() => _day = next == today ? null : next),
            onCompact: () {
              ref.read(hapticsProvider).selection();
              choices.setCompact(widget.setId, compact: !compact);
            },
            onOrder: () => _set(() => _newestFirst = !_newestFirst),
          ),
        filterRow,
        Divider(height: t.space.sm, color: t.colors.border),
        Expanded(
          child: TickerMode(
            // Offstage (another destination is shown): pause the stream.
            enabled: Visibility.of(context),
            child: _TimelineBody(
              setId: widget.setId,
              tracks: tracks,
              level: choice.level,
              compact: compact,
              fromMs: from,
              toMs: to,
              newestFirst: _newestFirst,
              showLifecycle: _showLifecycle,
              hiddenTracks: _hiddenTracks,
            ),
          ),
        ),
      ],
    );
  }
}

/// The evening shown: back, the day with since when, forward,
/// "Kompakt" (and in it the order of the list).
class _DayRow extends ConsumerWidget {
  const _DayRow({
    required this.setId,
    required this.day,
    required this.fromMs,
    required this.toMs,
    required this.isToday,
    required this.compact,
    required this.newestFirst,
    required this.onDay,
    required this.onCompact,
    required this.onOrder,
  });

  final String setId;
  final LocalDay day;
  final int fromMs;
  final int toMs;
  final bool isToday;
  final bool compact;
  final bool newestFirst;
  final ValueChanged<LocalDay> onDay;
  final VoidCallback onCompact;
  final VoidCallback onOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tikky;
    final sessions = ref
        .watch(timelineActivityProvider((setId: setId, from: fromMs, to: toMs)))
        .value;
    int? first;
    for (final item in sessions ?? const <HistorySession>[]) {
      final track = item.track;
      if (track == null) continue;
      for (final e in item.events) {
        if (e.at < fromMs || e.at >= toMs) continue;
        if (track.mode == TrackMode.protocol && e.type != EventType.entry) {
          continue;
        }
        if (first == null || e.at < first) first = e.at;
      }
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.space.pageLanes,
        0,
        t.space.pageLanes,
        t.space.xs,
      ),
      child: Row(
        children: [
          HeaderRoundButton(
            key: TimelineKeys.previous,
            icon: AdaptiveIcons.chevronLeft(context),
            label: TracksStrings.eveningPrevious,
            onPressed: () => onDay(logicalDayShift(day, -1)),
          ),
          Expanded(
            child: Semantics(
              container: true,
              liveRegion: true,
              child: Column(
                key: TimelineKeys.day,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    Fmt.dayShort(fromMs),
                    style: t.text.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    first == null
                        ? TracksStrings.eveningPlain
                        : TracksStrings.eveningSince(
                            Fmt.time(first, use24h: t.prefs.use24h),
                          ),
                    style: t.text.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          HeaderRoundButton(
            key: TimelineKeys.next,
            icon: AdaptiveIcons.chevronRight(context),
            label: TracksStrings.eveningNext,
            onPressed: isToday ? null : () => onDay(logicalDayShift(day, 1)),
          ),
          SizedBox(width: t.space.sm),
          SheetChip(
            key: TimelineKeys.compact,
            label: TracksStrings.eveningCompact,
            semanticLabel: TracksStrings.eveningCompactSemantics,
            selected: compact,
            onTap: onCompact,
          ),
          if (compact)
            AdaptiveIconButton(
              key: TimelineKeys.order,
              icon: newestFirst
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              semanticLabel: newestFirst
                  ? TracksStrings.timelineNewestFirst
                  : TracksStrings.timelineOldestFirst,
              onPressed: onOrder,
            ),
        ],
      ),
    );
  }
}

class _TimelineBody extends ConsumerWidget {
  const _TimelineBody({
    required this.setId,
    required this.tracks,
    required this.level,
    required this.compact,
    required this.fromMs,
    required this.toMs,
    required this.newestFirst,
    required this.showLifecycle,
    required this.hiddenTracks,
  });

  final String setId;
  final List<Track> tracks;
  final TimelineLevel level;
  final bool compact;
  final int? fromMs;
  final int? toMs;
  final bool newestFirst;
  final bool showLifecycle;
  final Set<String> hiddenTracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tikky;
    final async = ref.watch(
      timelineActivityProvider((setId: setId, from: fromMs, to: toMs)),
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

    if (level == TimelineLevel.now) {
      final strip = StripView(
        setId: setId,
        tracks: tracks,
        sessions: sessions,
        sinceMs: null,
        showLifecycle: showLifecycle,
        hiddenTracks: hiddenTracks,
        emptyMessage: TracksStrings.timelineEmptyOpen,
      );
      // Low (a phone held sideways): the strip keeps all the room.
      return LayoutBuilder(
        builder: (context, constraints) =>
            constraints.maxHeight < t.strip.cardsMinHeight
            ? strip
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PersonCards(setId: setId, sessions: sessions),
                  Expanded(child: strip),
                ],
              ),
      );
    }

    if (!compact) {
      return EveningView(
        sessions: sessions,
        fromMs: fromMs!,
        toMs: toMs!,
        hiddenTracks: hiddenTracks,
      );
    }

    Widget empty(String message) => AdaptiveEmptyState(
      icon: AdaptiveIcons.history(context),
      title: TracksStrings.timelineEmptyTitle,
      message: message,
    );
    final rows = buildTimelineRows(
      sessions: sessions,
      sinceMs: fromMs,
      untilMs: toMs,
      personNames: {
        for (final p in ref.watch(personsByIdProvider).values) p.id: p.name,
      },
      substanceNames: {
        for (final s in ref.watch(substancesByIdProvider).values) s.id: s.name,
      },
      newestFirst: newestFirst,
    );
    if (rows.isEmpty) return empty(TracksStrings.eveningEmpty);
    final items = withGapMarkers(
      filterTimelineRows(
        rows,
        showLifecycle: showLifecycle,
        hiddenTrackIds: hiddenTracks,
      ),
    );
    if (items.isEmpty) return empty(TracksStrings.timelineAllHidden);
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
