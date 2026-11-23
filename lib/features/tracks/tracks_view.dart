import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repo/settings_store.dart';
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

/// The word of a view in the navigation.
String tracksViewLabel(TracksView view) => switch (view) {
  TracksView.lanes => TracksStrings.viewLanes,
  TracksView.pad => TracksStrings.viewPad,
  TracksView.timeline => TracksStrings.viewTimeline,
};

/// A page of the tap pad that was asked for elsewhere: a person tile of a
/// protocol lane opens "Was?" for that person.
final class PadPageRequest {
  const PadPageRequest({required this.trackId, required this.personId});

  final String trackId;
  final String personId;
}

/// Holds a [PadPageRequest] until the tap pad has taken it.
class PadPageRequests extends Notifier<PadPageRequest?> {
  @override
  PadPageRequest? build() => null;

  /// Shows the tap pad of [setId] on the page "Was?" of [personId].
  void open(String setId, {required String trackId, required String personId}) {
    state = PadPageRequest(trackId: trackId, personId: personId);
    ref.read(tracksViewsProvider.notifier).show(setId, TracksView.pad);
  }

  /// The tap pad has taken the request.
  void clear() => state = null;
}

final padPageRequestProvider =
    NotifierProvider<PadPageRequests, PadPageRequest?>(PadPageRequests.new);
