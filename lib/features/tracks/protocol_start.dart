import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repo/providers.dart';
import '../protocol/protocol_scene_sheet.dart';
import 'tracks_view.dart';

/// Sets up the protocol of a set: "Wer ist dabei?" and "Was ist dran?" in
/// the scene editor. With somebody in the scene afterwards the tap pad is
/// shown: that is where the board is.
///
/// The protocol is not a track; this is its way in from the places where
/// a track would be added.
Future<void> startProtocol(
  BuildContext context, {
  required String setId,
}) async {
  // Fetched up front: the sheet may outlive the widget that opened it.
  final container = ProviderScope.containerOf(context, listen: false);
  await showSceneEditor(context, setId: setId);
  final set = await container.read(setRepositoryProvider).getSet(setId);
  if (set == null || set.scenePersonIds.isEmpty) return;
  await container
      .read(tracksViewsProvider.notifier)
      .show(setId, TracksView.pad);
}
