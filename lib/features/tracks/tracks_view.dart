import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../core/repo/settings_store.dart';
import '../../core/services/haptics.dart';
import 'tracks_strings.dart';

/// What the tracks screen shows for a set.
///
/// The [name] of each value is the persisted identifier - never rename.
enum TracksView {
  /// The lanes (the default).
  lanes,

  /// "Tippfeld": a grid of large buttons for the fastest possible capture.
  pad,

  /// "Zeitleiste": everything that happened, across all tracks.
  timeline;

  static TracksView fromName(String? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return TracksView.lanes;
  }
}

/// The view chosen per set (set id -> view), remembered in the settings
/// store under `ui.tracksView.<setId>`. Sets without an entry show the
/// lanes.
class TracksViewController extends Notifier<Map<String, TracksView>> {
  @override
  Map<String, TracksView> build() {
    const prefix = SettingsKeys.tracksViewPrefix;
    final stored = ref.watch(settingsStoreProvider).withPrefix(prefix);
    return {
      for (final e in stored.entries)
        e.key.substring(prefix.length): TracksView.fromName(e.value),
    };
  }

  /// Shows [view] for [setId] and remembers it.
  Future<void> show(String setId, TracksView view) async {
    if (state[setId] == view) return;
    state = {...state, setId: view};
    await ref
        .read(settingsStoreProvider)
        .setString('${SettingsKeys.tracksViewPrefix}$setId', view.name);
  }
}

final tracksViewsProvider =
    NotifierProvider<TracksViewController, Map<String, TracksView>>(
      TracksViewController.new,
    );

/// The view of one set.
final tracksViewProvider = Provider.family<TracksView, String>(
  (ref, setId) => ref.watch(
    tracksViewsProvider.select((views) => views[setId] ?? TracksView.lanes),
  ),
);

/// The segmented control in the tracks app bar: "Spuren", "Tippfeld",
/// "Zeitleiste". Icons with labels on wide layouts, icons with tooltips
/// and semantics labels on phones.
class TracksViewSwitch extends ConsumerWidget {
  const TracksViewSwitch({required this.setId, super.key});

  final String setId;

  static IconData _icon(BuildContext c, TracksView view) => switch (view) {
    TracksView.lanes =>
      isCupertino(c) ? CupertinoIcons.list_bullet : Icons.view_agenda_outlined,
    TracksView.pad =>
      isCupertino(c) ? CupertinoIcons.square_grid_2x2 : Icons.grid_view_rounded,
    TracksView.timeline =>
      isCupertino(c) ? CupertinoIcons.time : Icons.timeline_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(tracksViewProvider(setId));
    return Semantics(
      container: true,
      label: TracksStrings.viewSwitch,
      child: AdaptiveSegmented<TracksView>(
        segments: const {
          TracksView.lanes: TracksStrings.viewLanes,
          TracksView.pad: TracksStrings.viewPad,
          TracksView.timeline: TracksStrings.viewTimeline,
        },
        icons: {for (final v in TracksView.values) v: _icon(context, v)},
        showLabels: isWide(context),
        selected: view,
        onChanged: (next) {
          ref.read(hapticsProvider).selection();
          ref.read(tracksViewsProvider.notifier).show(setId, next);
        },
      ),
    );
  }
}
