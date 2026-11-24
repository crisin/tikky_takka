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
import '../../protocol/entry_edit_sheet.dart';
import '../../protocol/protocol_widgets.dart';
import '../now_selector.dart';
import '../tracks_strings.dart';
import 'evening/evening_view.dart';
import 'period/month_view.dart';
import 'period/period_things.dart';
import 'period/week_view.dart';
import 'protocol_bridge.dart';
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

/// The sessions of the tracks of one set: a stream scoped to the range in
/// the database (`HistoryRepository.watchSetActivity`) that only lives
/// while the timeline is shown.
final _trackActivityProvider = StreamProvider.autoDispose
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

/// What the timeline of one set draws: the sessions of its tracks, and
/// the entries of the protocol as one more lane ([entriesAsSession]).
///
/// Entries belong to persons, not to a set: every set shows all of them.
/// Without a range ("Jetzt") the entries of the logical day are taken.
final timelineActivityProvider = Provider.autoDispose
    .family<AsyncValue<List<HistorySession>>, TimelineRange>((ref, key) {
      final tracks = ref.watch(_trackActivityProvider(key));
      final dayStart = ref.watch(
        uiPrefsProvider.select((p) => p.dayStartMinutes),
      );
      final now = ref.read(clockProvider).nowMs();
      final from =
          key.from ?? logicalDayStartMs(logicalDayOf(now, dayStart), dayStart);
      final entries = ref.watch(
        entriesInRangeProvider((from: from, to: key.to ?? _endOfTime)),
      );
      if (!entries.hasValue) return const AsyncLoading();
      return tracks.whenData((sessions) {
        final protocol = entriesAsSession(
          key.setId,
          entries.value ?? const <Entry>[],
          now,
          set: ref.read(setProvider(key.setId)),
        );
        return [
          // A protocol track of an earlier version is not shown any more.
          for (final s in sessions)
            if (s.track?.mode != TrackMode.protocol) s,
          ?protocol,
        ];
      });
    });

const int _endOfTime = 1 << 62;

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
  /// The day the levels are around (the evening, its week, its month);
  /// `null` = the one going on now.
  LocalDay? _day;

  /// What the month counts; `null` = everything.
  String? _monthThing;
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
    // The protocol is one more lane, as soon as there is something to it.
    final hasProtocol =
        (ref.watch(setProvider(widget.setId))?.scenePersonIds.isNotEmpty ??
            false) ||
        (ref.watch(entryFactsProvider).value?.isNotEmpty ?? false);
    final tracks = [
      if (hasProtocol) protocolLane(widget.setId),
      ...widget.tracks,
    ];
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
    final level = choice.level;
    final evening = level == TimelineLevel.evening;
    final compact = evening && choice.compact;

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
              TimelineLevel.week: TracksStrings.levelWeek,
              TimelineLevel.month: TracksStrings.levelMonth,
            },
            fitLabels: true,
            selected: level,
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
          // Start and stop are only drawn in "Jetzt" and in the list.
          if (level == TimelineLevel.now || compact)
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

    // The range of the level around the chosen day.
    final monday = day.weekStart;
    final month = LocalDay(day.year, day.month, 1);
    final nextMonth = DateTime(day.year, day.month + 1);
    final lastOfMonth = logicalDayShift(
      LocalDay(nextMonth.year, nextMonth.month, 1),
      -1,
    );
    final (LocalDay first, LocalDay last) = switch (level) {
      TimelineLevel.now || TimelineLevel.evening => (day, day),
      TimelineLevel.week => (monday, logicalDayShift(monday, 6)),
      TimelineLevel.month => (month, lastOfMonth),
    };
    final from = level == TimelineLevel.now
        ? null
        : logicalDayStartMs(first, dayStart);
    final to = level == TimelineLevel.now
        ? null
        : logicalDayEndMs(last, dayStart);
    final hasToday = first.compareTo(today) <= 0 && last.compareTo(today) >= 0;

    void go(LocalDay next) => _set(() => _day = next == today ? null : next);
    void openEvening(LocalDay next) {
      go(next);
      choices.show(widget.setId, TimelineLevel.evening);
    }

    Widget? head;
    switch (level) {
      case TimelineLevel.now:
        head = null;
      case TimelineLevel.evening:
        head = _PeriodRow(
          title: Fmt.dayShort(from!),
          caption: _EveningCaption(
            setId: widget.setId,
            fromMs: from,
            toMs: to!,
          ),
          previousLabel: TracksStrings.eveningPrevious,
          nextLabel: TracksStrings.eveningNext,
          onPrevious: () => go(logicalDayShift(day, -1)),
          onNext: hasToday ? null : () => go(logicalDayShift(day, 1)),
          trailing: [
            SizedBox(width: t.space.sm),
            SheetChip(
              key: TimelineKeys.compact,
              label: TracksStrings.eveningCompact,
              semanticLabel: TracksStrings.eveningCompactSemantics,
              selected: compact,
              onTap: () {
                ref.read(hapticsProvider).selection();
                choices.setCompact(widget.setId, compact: !compact);
              },
            ),
            if (compact)
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
        );
      case TimelineLevel.week:
        head = _PeriodRow(
          title: Fmt.weekRange(monday),
          caption: Text(
            TracksStrings.weekNumber(isoWeekNumber(monday)),
            style: t.text.caption,
          ),
          previousLabel: TracksStrings.weekPrevious,
          nextLabel: TracksStrings.weekNext,
          onPrevious: () => go(logicalDayShift(day, -7)),
          onNext: hasToday ? null : () => go(logicalDayShift(day, 7)),
        );
      case TimelineLevel.month:
        final substances = ref.watch(substancesByIdProvider);
        final thing = _monthThing;
        head = _PeriodRow(
          title: Fmt.monthYear(month),
          caption: Text(
            TracksStrings.monthCaption(
              thing == null
                  ? TracksStrings.monthAll
                  : thingLabel(thing, substances),
              current: hasToday,
            ),
            style: t.text.caption,
          ),
          previousLabel: TracksStrings.monthPrevious,
          nextLabel: TracksStrings.monthNext,
          onPrevious: () {
            final d = DateTime(day.year, day.month - 1);
            go(LocalDay(d.year, d.month, 1));
          },
          onNext: hasToday
              ? null
              : () {
                  final d = DateTime(day.year, day.month + 1);
                  go(LocalDay(d.year, d.month, 1));
                },
        );
    }

    return Column(
      key: TimelineKeys.view,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        levelRow,
        SizedBox(height: t.space.xs),
        ?head,
        filterRow,
        Divider(height: t.space.sm, color: t.colors.border),
        Expanded(
          child: TickerMode(
            // Offstage (another destination is shown): pause the stream.
            enabled: Visibility.of(context),
            child: _TimelineBody(
              setId: widget.setId,
              tracks: tracks,
              level: level,
              compact: compact,
              fromMs: from,
              toMs: to,
              monday: monday,
              month: month,
              monthThing: _monthThing,
              onMonthThing: (thing) => setState(() => _monthThing = thing),
              onDay: openEvening,
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

/// The period shown: back, its name with a line below, forward, and what
/// belongs to it ("Kompakt").
class _PeriodRow extends StatelessWidget {
  const _PeriodRow({
    required this.title,
    required this.caption,
    required this.previousLabel,
    required this.nextLabel,
    required this.onPrevious,
    required this.onNext,
    this.trailing = const [],
  });

  final String title;
  final Widget caption;
  final String previousLabel;
  final String nextLabel;
  final VoidCallback onPrevious;

  /// `null` while the period going on is shown.
  final VoidCallback? onNext;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
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
            label: previousLabel,
            onPressed: onPrevious,
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
                    title,
                    style: t.text.headline,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  DefaultTextStyle.merge(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: caption,
                  ),
                ],
              ),
            ),
          ),
          HeaderRoundButton(
            key: TimelineKeys.next,
            icon: AdaptiveIcons.chevronRight(context),
            label: nextLabel,
            onPressed: onNext,
          ),
          ...trailing,
        ],
      ),
    );
  }
}

/// "Abend · seit 20:50": since the first entry (or start) of the evening.
class _EveningCaption extends ConsumerWidget {
  const _EveningCaption({
    required this.setId,
    required this.fromMs,
    required this.toMs,
  });

  final String setId;
  final int fromMs;
  final int toMs;

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
    return Text(
      first == null
          ? TracksStrings.eveningPlain
          : TracksStrings.eveningSince(Fmt.time(first, use24h: t.prefs.use24h)),
      style: t.text.caption,
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
    required this.monday,
    required this.month,
    required this.monthThing,
    required this.onMonthThing,
    required this.onDay,
    required this.newestFirst,
    required this.showLifecycle,
    required this.hiddenTracks,
  });

  final LocalDay monday;
  final LocalDay month;
  final String? monthThing;
  final ValueChanged<String?> onMonthThing;
  final ValueChanged<LocalDay> onDay;
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
      // The cards per person are the board of the tap pad now.
      return strip;
    }

    if (level == TimelineLevel.week || level == TimelineLevel.month) {
      final shown = [
        for (final s in sessions)
          if (!hiddenTracks.contains(s.track?.id)) s,
      ];
      return level == TimelineLevel.week
          ? WeekView(sessions: shown, monday: monday, onDay: onDay)
          : MonthView(
              sessions: shown,
              month: month,
              thing: monthThing,
              onThing: onMonthThing,
              onDay: onDay,
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
