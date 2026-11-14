import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/domain.dart';
import '../../core/repo/repo.dart';

/// "Rückgängig" for deleting tracks and sets.
///
/// `TrackRepository.deleteTrack` and `SetRepository.deleteSet` are final by
/// themselves. To keep the app's "do it, then offer undo" rule, the rows
/// about to be deleted are captured first and put back through the backup
/// merge (insert by id, nothing else is touched).
class TrackUndo {
  TrackUndo(this._ref);

  final Ref _ref;

  Future<BackupData> _capture({
    TrackSet? set,
    required List<Track> tracks,
  }) async {
    var sessions = const <Session>[];
    var events = const <TrackEvent>[];
    if (tracks.isNotEmpty) {
      // An empty id filter would mean "all tracks".
      final history = await _ref
          .read(historyRepositoryProvider)
          .getSessions(
            HistoryFilter(
              trackIds: {for (final t in tracks) t.id},
              includeOpen: true,
            ),
          );
      sessions = [for (final h in history) h.session];
      events = [for (final h in history) ...h.events];
    }
    return BackupData(
      sets: [?set],
      tracks: tracks,
      sessions: sessions,
      events: events,
    );
  }

  Future<void> _restore(BackupData data) async {
    await _ref
        .read(backupRepositoryProvider)
        .merge(data, importSettings: false);
  }

  /// Deletes [track] with its history. The returned callback restores
  /// everything.
  Future<Future<void> Function()> deleteTrack(Track track) async {
    final data = await _capture(tracks: [track]);
    await _ref.read(trackRepositoryProvider).deleteTrack(track.id);
    return () => _restore(data);
  }

  /// Deletes [set] with all its tracks and their history. The returned
  /// callback restores everything.
  Future<Future<void> Function()> deleteSet(TrackSet set) async {
    final tracks = await _ref
        .read(trackRepositoryProvider)
        .getTracks(set.id, includeArchived: true);
    final data = await _capture(set: set, tracks: tracks);
    await _ref.read(setRepositoryProvider).deleteSet(set.id);
    return () => _restore(data);
  }
}

final trackUndoProvider = Provider<TrackUndo>(TrackUndo.new);
