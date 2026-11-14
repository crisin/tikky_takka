import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../core/core.dart';
import '../../l10n/strings.dart';
import '../../theme/theme.dart';
import 'history_filter_logic.dart';
import 'history_strings.dart';

/// The filter bar of the history screen: one chip each for the date range,
/// the set and the tracks, plus a reset button while a filter is active.
/// Writes to `historyFilterProvider`, which export reads as well.
class HistoryFilterBar extends ConsumerWidget {
  const HistoryFilterBar({super.key});

  /// Earliest day the date pickers offer.
  static final DateTime _firstDay = DateTime(2000);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tikky;
    final filter = ref.watch(historyFilterProvider);
    final sets = ref.watch(allSetsProvider).value ?? const <TrackSet>[];
    final tracks = ref.watch(allTracksProvider).value ?? const <Track>[];
    final nowMs = ref.watch(clockProvider).nowMs();

    final hasDates = filter.fromMs != null || filter.toMs != null;
    // The chips scroll if they do not fit; the reset button stays put.
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: t.space.page,
        end: filter.isUnrestricted ? t.space.page : t.space.xs,
        top: t.space.xs,
        bottom: t.space.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    name: Strings.filterDateRange,
                    value: HistoryFilterLogic.describeDates(filter, nowMs),
                    active: hasDates,
                    onPressed: () => _pickDates(context, ref),
                  ),
                  SizedBox(width: t.space.sm),
                  _FilterChip(
                    name: Strings.filterSet,
                    value: HistoryFilterLogic.describeSet(filter, sets),
                    active: filter.setId != null,
                    onPressed: () => _pickSet(context, ref, sets, tracks),
                  ),
                  SizedBox(width: t.space.sm),
                  _FilterChip(
                    name: Strings.filterTracks,
                    value: HistoryFilterLogic.describeTracks(filter, tracks),
                    active: filter.trackIds.isNotEmpty,
                    onPressed: () => _pickTracks(context, ref, sets, tracks),
                  ),
                ],
              ),
            ),
          ),
          if (!filter.isUnrestricted)
            AdaptiveIconButton(
              icon: AdaptiveIcons.close(context),
              semanticLabel: Strings.filterReset,
              size: t.sizes.iconSm,
              onPressed: () => ref.read(historyFilterProvider.notifier).reset(),
            ),
        ],
      ),
    );
  }

  Future<void> _pickDates(BuildContext context, WidgetRef ref) async {
    final clock = ref.read(clockProvider);
    final nowMs = clock.nowMs();
    final current = ref.read(historyFilterProvider);
    final active = HistoryFilterLogic.presetOf(current, nowMs);
    final preset = await showAdaptiveActionSheet<DatePreset>(
      context,
      title: Strings.filterDateRange,
      actions: [
        for (final p in DatePreset.choices)
          AdaptiveSheetAction(value: p, label: p.label, selected: p == active),
      ],
    );
    if (preset == null) return;

    var span = HistoryFilterLogic.spanOf(preset, nowMs);
    if (preset == DatePreset.custom) {
      if (!context.mounted) return;
      final today = LocalDay.fromMs(nowMs).start;
      final from = current.fromMs;
      final to = current.toMs;
      final picked = await showAdaptiveDateRangePicker(
        context,
        first: _firstDay,
        last: today,
        initial: from == null || to == null
            ? null
            : _clampRange(
                DateTime.fromMillisecondsSinceEpoch(from),
                HistoryFilterLogic.lastDayOf(to),
                today,
              ),
      );
      if (picked == null) return;
      span = HistoryFilterLogic.spanOfDays(picked.start, picked.end);
    }
    // Read again: the filter may have changed while the pickers were open.
    final latest = ref.read(historyFilterProvider);
    ref
        .read(historyFilterProvider.notifier)
        .set(latest.copyWith(fromMs: () => span.fromMs, toMs: () => span.toMs));
  }

  /// The pickers reject initial ranges outside their bounds.
  static DateTimeRange? _clampRange(
    DateTime start,
    DateTime end,
    DateTime last,
  ) {
    final startDay = DateTime(start.year, start.month, start.day);
    if (startDay.isBefore(_firstDay) || startDay.isAfter(last)) return null;
    final endDay = end.isAfter(last) ? last : end;
    if (endDay.isBefore(startDay)) return null;
    return DateTimeRange(start: startDay, end: endDay);
  }

  Future<void> _pickSet(
    BuildContext context,
    WidgetRef ref,
    List<TrackSet> sets,
    List<Track> tracks,
  ) async {
    final current = ref.read(historyFilterProvider).setId;
    final choice = await showAdaptiveActionSheet<_SetChoice>(
      context,
      title: HistoryStrings.filterSetTitle,
      actions: [
        AdaptiveSheetAction(
          value: const _SetChoice(null),
          label: Strings.allSets,
          selected: current == null,
        ),
        for (final set in sets)
          AdaptiveSheetAction(
            value: _SetChoice(set.id),
            label: set.archived
                ? HistoryStrings.joined([
                    set.name,
                    HistoryStrings.archivedSuffix,
                  ])
                : set.name,
            selected: set.id == current,
          ),
      ],
    );
    if (choice == null) return;
    final latest = ref.read(historyFilterProvider);
    ref
        .read(historyFilterProvider.notifier)
        .set(HistoryFilterLogic.withSet(latest, choice.setId, tracks));
  }

  Future<void> _pickTracks(
    BuildContext context,
    WidgetRef ref,
    List<TrackSet> sets,
    List<Track> tracks,
  ) async {
    final filter = ref.read(historyFilterProvider);
    final setNames = {for (final set in sets) set.id: set.name};
    final setOrder = {for (final (i, set) in sets.indexed) set.id: i};
    final candidates =
        [
          for (final track in tracks)
            if (filter.setId == null || track.setId == filter.setId) track,
        ]..sort((a, b) {
          final bySet = (setOrder[a.setId] ?? sets.length).compareTo(
            setOrder[b.setId] ?? sets.length,
          );
          return bySet != 0 ? bySet : a.sortIndex.compareTo(b.sortIndex);
        });
    final picked = await showAdaptiveSheet<Set<String>>(
      context,
      builder: (context) => _TrackPickerSheet(
        tracks: candidates,
        // Set names tell equally named tracks apart, unless one set is
        // already selected.
        setNames: filter.setId == null ? setNames : const {},
        initial: filter.trackIds,
      ),
    );
    if (picked == null) return;
    final latest = ref.read(historyFilterProvider);
    ref
        .read(historyFilterProvider.notifier)
        .set(latest.copyWith(trackIds: picked));
  }
}

/// `null` is a valid choice ("Alle Sets"), so it needs a wrapper to tell
/// it apart from a dismissed sheet.
@immutable
class _SetChoice {
  const _SetChoice(this.setId);

  final String? setId;
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.name,
    required this.value,
    required this.active,
    required this.onPressed,
  });

  /// What is filtered ("Zeitraum"): the label of an idle chip and the
  /// tooltip.
  final String name;

  /// The current choice ("Heute"): the label while [active].
  final String value;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final color = active ? t.colors.text : t.colors.textMuted;
    return ActionChip(
      onPressed: onPressed,
      tooltip: name,
      backgroundColor: active ? t.colors.surfaceAlt : t.colors.surface,
      side: active
          ? BorderSide(color: t.colors.primary, width: t.sizes.hairline)
          : t.hairline,
      padding: EdgeInsets.symmetric(horizontal: t.space.xs),
      labelPadding: EdgeInsetsDirectional.only(start: t.space.xs),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Idle chips only name what they filter, so all three fit on a
          // phone; an active chip shows its choice.
          Text(
            active ? value : name,
            style: t.text.label.copyWith(color: color),
          ),
          Icon(
            AdaptiveIcons.chevronDown(context),
            size: t.sizes.iconSm,
            color: color,
          ),
        ],
      ),
    );
  }
}

/// Multi-selection of tracks. Pops with the selected ids; an empty set
/// means "all tracks".
class _TrackPickerSheet extends StatefulWidget {
  const _TrackPickerSheet({
    required this.tracks,
    required this.setNames,
    required this.initial,
  });

  final List<Track> tracks;
  final Map<String, String> setNames;
  final Set<String> initial;

  @override
  State<_TrackPickerSheet> createState() => _TrackPickerSheetState();
}

class _TrackPickerSheetState extends State<_TrackPickerSheet> {
  late final Set<String> _selected = {
    // Ids of tracks that are not offered (other set, deleted) are dropped.
    for (final track in widget.tracks)
      if (widget.initial.contains(track.id)) track.id,
  };

  void _toggle(String id, bool selected) => setState(() {
    if (selected) {
      _selected.add(id);
    } else {
      _selected.remove(id);
    }
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    // The sheet itself is limited to the screen; the list takes what the
    // header leaves and scrolls.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(t.space.page, 0, t.space.sm, t.space.xs),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    HistoryStrings.filterTracksTitle,
                    style: t.text.title,
                  ),
                ),
              ),
              AdaptiveTextButton(
                label: Strings.done,
                onPressed: () => Navigator.of(context).pop(_selected),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              CheckboxListTile.adaptive(
                value: _selected.isEmpty,
                title: const Text(Strings.allTracks),
                // "All" cannot be switched off, only replaced by a choice.
                onChanged: _selected.isEmpty
                    ? null
                    : (_) => setState(_selected.clear),
              ),
              for (final track in widget.tracks)
                CheckboxListTile.adaptive(
                  value: _selected.contains(track.id),
                  secondary: _ColorDot(color: t.trackColor(track)),
                  title: Text(track.name),
                  subtitle: Text(
                    HistoryStrings.joined([
                      Strings.modeName(track.mode),
                      widget.setNames[track.setId] ?? '',
                      if (track.archived) HistoryStrings.archivedSuffix,
                    ]),
                  ),
                  onChanged: (value) => _toggle(track.id, value ?? false),
                ),
            ],
          ),
        ),
        SizedBox(height: t.space.sm),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Container(
      width: t.sizes.dot,
      height: t.sizes.dot,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
