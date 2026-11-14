import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../l10n/strings.dart';
import '../../theme/theme.dart';
import 'export_sheet.dart';
import 'history_actions.dart';
import 'history_filter_bar.dart';
import 'history_session_list.dart';
import 'history_strings.dart';
import 'history_sums_view.dart';
import 'history_widgets.dart';

/// The "Verlauf" destination: a filter bar (date range, set, tracks), a
/// switch between the sessions grouped by day and the sums per track per
/// day / week, and the export sheet in the app bar.
///
/// Parts, all in this folder:
/// * [HistoryFilterBar] - writes `historyFilterProvider`;
/// * [HistorySessionList] - days with totals, opens `SessionDetailPage`;
/// * [HistorySumsView] - daily / weekly sums per track;
/// * [showExportSheet] - CSV / JSON export and JSON import.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tikky;
    final view = ref.watch(historyViewProvider);
    return AdaptivePageScaffold(
      title: const Text(Strings.historyTitle),
      largeTitle: true,
      actions: [
        AdaptiveIconButton(
          icon: AdaptiveIcons.export(context),
          semanticLabel: Strings.export,
          onPressed: () => showExportSheet(context),
        ),
      ],
      belowTitle: HistoryContentWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const HistoryFilterBar(),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: t.space.page,
                vertical: t.space.xs,
              ),
              child: Semantics(
                label: HistoryStrings.view,
                container: true,
                child: AdaptiveSegmented<HistoryView>(
                  segments: const {
                    HistoryView.sessions: Strings.sessions,
                    HistoryView.daily: Strings.sumsDaily,
                    HistoryView.weekly: Strings.sumsWeekly,
                  },
                  selected: view,
                  onChanged: ref.read(historyViewProvider.notifier).show,
                ),
              ),
            ),
          ],
        ),
      ),
      body: HistoryContentWidth(
        child: switch (view) {
          HistoryView.sessions => const HistorySessionList(),
          HistoryView.daily => const HistorySumsView(weekly: false),
          HistoryView.weekly => const HistorySumsView(weekly: true),
        },
      ),
    );
  }
}
