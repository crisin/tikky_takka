import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';

import '../../support/test_env.dart';

void main() {
  final env = useTestEnv();

  test('protocol tracks of an earlier version are removed, with their '
      'sessions and events; everything else stays', () async {
    final e = env();
    final set = await e.makeSet('Festival');
    final old = await e.makeTrack(set, const ProtocolConfig(), name: 'Zelt');
    final watch = await e.makeTrack(set, const StopwatchConfig());
    await e.commands.startTrack(old.id);
    await e.commands.startTrack(watch.id);
    await e.entries.add(personId: 'p', substanceId: 's');

    expect(await e.tracks.purgeProtocolTracks(), 1);
    expect(
      [for (final t in await e.tracks.getTracks(set.id)) t.id],
      [watch.id],
    );
    expect(await e.commands.getOpenSession(old.id), isNull);
    expect(await e.commands.getOpenSession(watch.id), isNotNull);
    // The entries of the new protocol are not touched.
    expect(await e.entries.getAll(), hasLength(1));
    // Nothing left to remove.
    expect(await e.tracks.purgeProtocolTracks(), 0);
  });
}
