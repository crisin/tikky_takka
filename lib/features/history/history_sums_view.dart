import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../core/core.dart';
import '../../l10n/formatters.dart';
import '../../l10n/strings.dart';
import '../../theme/theme.dart';
import 'history_filter_logic.dart';
import 'history_session_list.dart';
import 'history_strings.dart';
import 'history_widgets.dart';

/// Net time per track, summed per day or per week (Monday based), for the
/// sessions matching the active filter. The work-time view.
class HistorySumsView extends ConsumerWidget {
  const HistorySumsView({required this.weekly, super.key});

  /// `true`: one block per week, `false`: one block per day.
  final bool weekly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tikky;
    final async = ref.watch(
      weekly ? historyWeeklySumsProvider : historyDailySumsProvider,
    );
    final filter = ref.watch(historyFilterProvider);
    final nowMs = ref.watch(clockProvider).nowMs();

    return async.when(
      loading: () => const AdaptiveProgress(),
      error: (error, _) => AdaptiveEmptyState(
        icon: AdaptiveIcons.close(context),
        title: Strings.errorGeneric,
        message: '$error',
      ),
      data: (sums) {
        if (sums.isEmpty) return HistoryEmptyState(filter: filter);
        final periods = groupSumsByPeriod(sums);
        return ListView.builder(
          padding: EdgeInsets.only(bottom: t.space.xl),
          itemCount: periods.length,
          itemBuilder: (context, index) {
            final period = periods[index];
            final sessions = period.sums.fold(
              0,
              (count, s) => count + s.sessionCount,
            );
            return HistoryGroup(
              key: ValueKey(period.period),
              title: weekly
                  ? _weekTitle(period.period)
                  : Fmt.dayHeader(period.period, todayMs: nowMs),
              caption: Strings.sessionCount(sessions),
              trailing: HistoryStrings.total(
                weekly ? Strings.weekTotal : Strings.dayTotal,
                Fmt.compact(period.totalNetMs),
              ),
              children: [for (final sum in period.sums) _SumRow(sum: sum)],
            );
          },
        );
      },
    );
  }

  static String _weekTitle(LocalDay monday) => HistoryStrings.week(
    HistoryFilterLogic.isoWeekNumber(monday),
    Fmt.date(monday.startMs),
    Fmt.date(HistoryFilterLogic.weekEnd(monday).startMs),
  );
}

/// The sums of one period (a day, or a week identified by its Monday).
final class PeriodSums {
  const PeriodSums({
    required this.period,
    required this.sums,
    required this.totalNetMs,
  });

  final LocalDay period;
  final List<TrackPeriodSum> sums;
  final int totalNetMs;
}

/// Groups sums (already ordered newest period first) by their period.
List<PeriodSums> groupSumsByPeriod(Iterable<TrackPeriodSum> sums) {
  final byPeriod = <LocalDay, List<TrackPeriodSum>>{};
  for (final sum in sums) {
    byPeriod.putIfAbsent(sum.period, () => []).add(sum);
  }
  final periods = byPeriod.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final period in periods)
      PeriodSums(
        period: period,
        sums: byPeriod[period]!,
        totalNetMs: byPeriod[period]!.fold(0, (total, s) => total + s.netMs),
      ),
  ];
}

class _SumRow extends StatelessWidget {
  const _SumRow({required this.sum});

  final TrackPeriodSum sum;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final track = sum.track;
    return MergeSemantics(
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
                      Text(
                        HistoryStrings.joined([
                          if (track != null) Strings.modeName(track.mode),
                          Strings.sessionCount(sum.sessionCount),
                        ]),
                        style: t.text.subLine,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: t.space.md),
                Text(
                  Fmt.clock(sum.netMs, alwaysHours: true),
                  style: t.text.digitsMedium,
                  semanticsLabel: Fmt.compact(sum.netMs),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
