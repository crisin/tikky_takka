import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/repo/repo.dart';

import '../../support/test_env.dart';

void main() {
  final env = useTestEnv();

  group('TrackSet scene (domain)', () {
    test('JSON round trip keeps both lists and their order', () {
      const set = TrackSet(
        id: 's1',
        name: 'Festival',
        scenePersonIds: ['p2', 'p1'],
        sceneSubstanceIds: ['x3', 'x1', 'x2'],
        extra: {'keep': 1},
      );
      expect(set.hasScene, isTrue);
      final json = jsonMap(jsonDecode(jsonEncode(set.toJson())));
      expect(json['scenePersonIds'], ['p2', 'p1']);
      expect(json['sceneSubstanceIds'], ['x3', 'x1', 'x2']);
      final back = TrackSet.fromJson(json);
      expect(back, set);
      expect(back.scenePersonIds, ['p2', 'p1']);
      expect(back.sceneSubstanceIds, ['x3', 'x1', 'x2']);
      expect(back.extra, {'keep': 1});
    });

    test('older JSON without the fields has no scene', () {
      final set = TrackSet.fromJson({'id': 's1', 'name': 'Alt'});
      expect(set.hasScene, isFalse);
      expect(set.scenePersonIds, isEmpty);
      expect(set.sceneSubstanceIds, isEmpty);
    });

    test('malformed lists are read leniently, without duplicates', () {
      final set = TrackSet.fromJson({
        'id': 's1',
        'name': 'X',
        'scenePersonIds': ['a', 7, 'a', '', 'b'],
        'sceneSubstanceIds': 'nope',
      });
      expect(set.scenePersonIds, ['a', 'b']);
      expect(set.sceneSubstanceIds, isEmpty);
    });

    test('equality and copyWith cover the scene', () {
      const a = TrackSet(id: 's', name: 'n', scenePersonIds: ['p']);
      expect(a, isNot(const TrackSet(id: 's', name: 'n')));
      expect(a.copyWith(scenePersonIds: const []).hasScene, isFalse);
      expect(a.copyWith(name: 'm').scenePersonIds, ['p']);
    });
  });

  group('scene storage', () {
    test('updateScene stores the lists in extra_json, next to extra', () async {
      final e = env();
      final set = await e.sets.createSet(name: 'Festival');
      await e.sets.updateSet(set.copyWith(extra: {'keep': true}));
      e.clock.advanceMs(5);
      await e.sets.updateScene(
        set.id,
        personIds: ['p1', 'p2'],
        substanceIds: ['x2', 'x1'],
      );

      final stored = (await e.sets.getSet(set.id))!;
      expect(stored.scenePersonIds, ['p1', 'p2']);
      expect(stored.sceneSubstanceIds, ['x2', 'x1']);
      // The scene is not part of the free-form extra data.
      expect(stored.extra, {'keep': true});
      expect(stored.updatedAt, e.clock.nowMs());

      // No own column: it rides in extra_json.
      final row = await (e.db.select(e.db.trackSets)).getSingle();
      final raw = jsonMap(jsonDecode(row.extraJson!));
      expect(raw['keep'], true);
      expect(raw['scene'], {
        'personIds': ['p1', 'p2'],
        'substanceIds': ['x2', 'x1'],
      });
    });

    test('other set edits keep the scene; clearing removes it', () async {
      final e = env();
      final set = await e.sets.createSet(name: 'Festival');
      await e.sets.updateScene(set.id, personIds: ['p1'], substanceIds: []);
      await e.sets.renameSet(set.id, 'Club');
      final renamed = (await e.sets.getSet(set.id))!;
      await e.sets.updateSet(renamed.copyWith(themeId: () => 'preset.dark'));
      await e.sets.reorderSets([set.id]);
      await e.sets.setArchived(set.id, archived: true);

      final stored = (await e.sets.getSet(set.id))!;
      expect(stored.name, 'Club');
      expect(stored.themeId, 'preset.dark');
      expect(stored.scenePersonIds, ['p1']);

      await e.sets.updateScene(set.id, personIds: [], substanceIds: []);
      expect((await e.sets.getSet(set.id))!.hasScene, isFalse);
      final row = await (e.db.select(e.db.trackSets)).getSingle();
      expect(row.extraJson, isNull);

      // Unknown set: nothing happens.
      await e.sets.updateScene('missing', personIds: ['p'], substanceIds: []);
    });
  });

  group('deleting removes from every scene', () {
    test('a deleted person leaves all scenes; undo puts it back', () async {
      final e = env();
      final a = await e.sets.createSet(name: 'A');
      final b = await e.sets.createSet(name: 'B');
      final c = await e.sets.createSet(name: 'C');
      final alex = await e.people.createPerson(name: 'Alex');
      final kim = await e.people.createPerson(name: 'Kim');
      final water = await e.people.createSubstance(name: 'Wasser');
      await e.sets.updateScene(
        a.id,
        personIds: [alex.id, kim.id],
        substanceIds: [water.id],
      );
      await e.sets.updateScene(
        b.id,
        personIds: [kim.id, alex.id],
        substanceIds: [],
      );
      await e.sets.updateScene(c.id, personIds: [kim.id], substanceIds: []);

      final deleted = await e.people.deletePerson(alex.id);
      expect((await e.sets.getSet(a.id))!.scenePersonIds, [kim.id]);
      expect((await e.sets.getSet(a.id))!.sceneSubstanceIds, [water.id]);
      expect((await e.sets.getSet(b.id))!.scenePersonIds, [kim.id]);
      expect((await e.sets.getSet(c.id))!.scenePersonIds, [kim.id]);

      await e.people.restorePerson(deleted!);
      expect((await e.sets.getSet(a.id))!.scenePersonIds, [alex.id, kim.id]);
      expect((await e.sets.getSet(b.id))!.scenePersonIds, [kim.id, alex.id]);
      expect((await e.sets.getSet(c.id))!.scenePersonIds, [kim.id]);
    });

    test('a deleted substance leaves all scenes; undo puts it back', () async {
      final e = env();
      final a = await e.sets.createSet(name: 'A');
      final alex = await e.people.createPerson(name: 'Alex');
      final water = await e.people.createSubstance(name: 'Wasser');
      final tea = await e.people.createSubstance(name: 'Tee');
      await e.sets.updateScene(
        a.id,
        personIds: [alex.id],
        substanceIds: [tea.id, water.id],
      );

      final deleted = await e.people.deleteSubstance(tea.id);
      var stored = (await e.sets.getSet(a.id))!;
      expect(stored.sceneSubstanceIds, [water.id]);
      expect(stored.scenePersonIds, [alex.id]);

      await e.people.restoreSubstance(deleted!);
      stored = (await e.sets.getSet(a.id))!;
      expect(stored.sceneSubstanceIds, [tea.id, water.id]);
    });

    test('removing from the list (archive) keeps the scene entry', () async {
      final e = env();
      final a = await e.sets.createSet(name: 'A');
      final alex = await e.people.createPerson(name: 'Alex');
      await e.sets.updateScene(a.id, personIds: [alex.id], substanceIds: []);
      await e.people.setPersonArchived(alex.id, archived: true);
      expect((await e.sets.getSet(a.id))!.scenePersonIds, [alex.id]);
    });
  });

  group('backup', () {
    Future<(TrackSet, Person, Substance)> populate(TestEnv e) async {
      final set = await e.sets.createSet(name: 'Festival');
      final protocol = await e.makeTrack(set, const ProtocolConfig());
      await e.makeTrack(set, const StopwatchConfig());
      final alex = await e.people.createPerson(name: 'Alex');
      final water = await e.people.createSubstance(name: 'Wasser');
      await e.commands.addEntry(
        protocol.id,
        personId: alex.id,
        substanceId: water.id,
      );
      await e.sets.updateScene(
        set.id,
        personIds: [alex.id],
        substanceIds: [water.id],
      );
      return ((await e.sets.getSet(set.id))!, alex, water);
    }

    test('the scene survives a JSON round trip with protocol data', () async {
      final e = env();
      final (set, alex, water) = await populate(e);
      final data = await e.backup.readAll(includeProtocol: true);
      expect(data.sets.single, set);
      final json = jsonEncode(data.toJson());

      final target = TestEnv();
      addTearDown(target.dispose);
      await target.backup.merge(BackupData.fromJson(jsonMap(jsonDecode(json))));
      final restored = (await target.sets.getSet(set.id))!;
      expect(restored, set);
      expect(restored.scenePersonIds, [alex.id]);
      expect(restored.sceneSubstanceIds, [water.id]);
      expect((await target.people.getPersons()).single.id, alex.id);
    });

    test('without protocol data the scene is not exported', () async {
      final e = env();
      final (set, alex, water) = await populate(e);
      final data = await e.backup.readAll();
      expect(data.persons, isEmpty);
      expect(data.substances, isEmpty);
      expect(data.sets.single.id, set.id);
      expect(data.sets.single.hasScene, isFalse);
      // Not a trace of the excluded person / substance in the file.
      final json = jsonEncode(data.toJson());
      expect(json.contains(alex.id), isFalse);
      expect(json.contains(water.id), isFalse);
      expect(json.contains('Alex'), isFalse);
      // The stored set is untouched by exporting.
      expect((await e.sets.getSet(set.id))!.scenePersonIds, [alex.id]);

      // Into an empty database: the set arrives without a scene.
      final target = TestEnv();
      addTearDown(target.dispose);
      await target.backup.merge(BackupData.fromJson(jsonMap(jsonDecode(json))));
      expect((await target.sets.getSet(set.id))!.hasScene, isFalse);
    });

    test(
      'importing a backup without protocol data keeps the local scene',
      () async {
        final e = env();
        final (set, alex, water) = await populate(e);
        final plain = await e.backup.readAll();
        // The backup's set is newer than the local row, so it replaces it.
        final newer = BackupData(
          sets: [
            plain.sets.single.copyWith(
              name: 'Umbenannt',
              updatedAt: set.updatedAt + 1000,
            ),
          ],
        );
        final report = await e.backup.merge(newer);
        expect(report.updated['sets'], 1);
        final stored = (await e.sets.getSet(set.id))!;
        expect(stored.name, 'Umbenannt');
        expect(stored.scenePersonIds, [alex.id]);
        expect(stored.sceneSubstanceIds, [water.id]);
      },
    );
  });

  group('substance use', () {
    test('counts per person and substance over all sessions', () async {
      final e = env();
      final set = await e.sets.createSet(name: 'Festival');
      final track = await e.makeTrack(set, const ProtocolConfig());
      final other = await e.makeTrack(set, const ProtocolConfig(), name: 'B');
      await e.commands.addEntry(track.id, personId: 'p1', substanceId: 'x1');
      e.clock.advanceMs(1000);
      await e.commands.addEntry(track.id, personId: 'p1', substanceId: 'x1');
      await e.commands.stopTrack(track.id);
      e.clock.advanceMs(1000);
      await e.commands.addEntry(track.id, personId: 'p1', substanceId: 'x1');
      await e.commands.addEntry(track.id, personId: 'p2', substanceId: 'x1');
      await e.commands.addEntry(track.id, personId: 'p1');
      await e.commands.addEntry(other.id, personId: 'p1', substanceId: 'x9');

      final use = await e.history.getSubstanceUse(track.id);
      final now = e.clock.nowMs();
      expect(use.toSet(), {
        SubstanceUse(personId: 'p1', substanceId: 'x1', count: 3, lastAt: now),
        SubstanceUse(personId: 'p2', substanceId: 'x1', count: 1, lastAt: now),
        SubstanceUse(personId: 'p1', substanceId: null, count: 1, lastAt: now),
      });
      expect(await e.history.getSubstanceUse('missing'), isEmpty);
    });
  });
}
