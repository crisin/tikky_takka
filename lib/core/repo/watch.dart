import 'dart:async';

import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// Re-runs [load] whenever one of [tables] changes and emits the results.
///
/// Emits the first result right after subscription. Reloads are coalesced:
/// while a load is running, further table updates only trigger one more
/// load. Every listener gets its own subscription; cancelling it stops
/// everything. This is used instead of drift's cached `watch()` streams so
/// that no timers outlive a subscription (friendly to widget tests).
///
/// A PAUSED subscription loads nothing: table updates are only remembered
/// and answered with a single reload on resume. Riverpod pauses a
/// `StreamProvider` whose listeners are all paused (a widget subtree with
/// `TickerMode` off), which is how the history stops re-reading every
/// session on each event write while its destination is not shown.
Stream<T> watchTables<T>(
  AppDatabase db,
  Iterable<TableInfo<Table, Object?>> tables,
  Future<T> Function() load,
) {
  return Stream<T>.multi((controller) {
    var loading = false;
    var dirty = false;
    var closed = false;
    var paused = false;

    Future<void> run() async {
      if (loading || paused) {
        dirty = true;
        return;
      }
      loading = true;
      try {
        do {
          dirty = false;
          final value = await load();
          if (closed) return;
          controller.add(value);
        } while (dirty && !closed && !paused);
      } catch (error, stack) {
        if (!closed) controller.addError(error, stack);
      } finally {
        loading = false;
      }
    }

    final sub = db
        .tableUpdates(TableUpdateQuery.onAllTables(tables))
        .listen((_) => run());
    controller.onPause = () => paused = true;
    controller.onResume = () {
      paused = false;
      if (dirty && !closed) run();
    };
    controller.onCancel = () {
      closed = true;
      return sub.cancel();
    };
    run();
  });
}
