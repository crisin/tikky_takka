import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/features/protocol/entry_edit_sheet.dart';
import 'package:tikky_takka/features/protocol/protocol_scene_sheet.dart';
import 'package:tikky_takka/theme/theme.dart';

import '../../support/test_app.dart';

const int minuteMs = 60 * 1000;
const int hourMs = 60 * minuteMs;

/// Lets database work, streams, sheets and snackbars settle.
Future<void> settleUi(WidgetTester tester, TestApp app) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 5)),
  );
  for (var i = 0; i < 4; i++) {
    await app.settle(tester);
    await tester.pump(const Duration(milliseconds: 350));
  }
  await app.settle(tester);
}

/// An empty page: the sheets of the protocol open above it.
class ProtocolHost extends StatelessWidget {
  const ProtocolHost({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.expand());
}

/// A set with persons, things and entries, and a page to open the
/// protocol's sheets on.
class ProtocolFixture {
  ProtocolFixture(this.tester, this.app, this.container, this.setId);

  final WidgetTester tester;
  final TestApp app;
  final ProviderContainer container;
  final String setId;

  static Future<ProtocolFixture> pump(
    WidgetTester tester, {
    Size surfaceSize = TestApp.phoneSize,
    TargetPlatform? platform,
    UiPrefs prefs = UiPrefs.defaults,
  }) async {
    final app = await TestApp.create(tester);
    await app.pumpWidget(
      tester,
      const ProtocolHost(),
      surfaceSize: surfaceSize,
      platform: platform,
      prefs: prefs,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ProtocolHost)),
    );
    final set = (await tester.runAsync(
      () => container.read(setRepositoryProvider).createSet(name: 'Festival'),
    ))!;
    final fixture = ProtocolFixture(tester, app, container, set.id);
    await fixture.settle();
    return fixture;
  }

  BuildContext get _context => tester.element(find.byType(ProtocolHost));

  Future<T> run<T>(Future<T> Function() body) async {
    final result = (await tester.runAsync(body)) as T;
    await tester.pump();
    return result;
  }

  Future<void> settle() => settleUi(tester, app);

  Future<void> tap(Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await settle();
  }

  PeopleRepository get people => container.read(peopleRepositoryProvider);
  EntryRepository get entryRepo => container.read(entryRepositoryProvider);

  Future<Person> person(String name) =>
      run(() => people.createPerson(name: name));

  Future<Substance> substance(String name, {int? lockoutMs}) =>
      run(() => people.createSubstance(name: name, lockoutMs: lockoutMs));

  Future<void> scene({
    List<Person> persons = const [],
    List<Substance> substances = const [],
  }) async {
    await run(
      () => container
          .read(setRepositoryProvider)
          .updateScene(
            setId,
            personIds: [for (final p in persons) p.id],
            substanceIds: [for (final s in substances) s.id],
          ),
    );
    await settle();
  }

  Future<TrackSet> storedSet() async {
    final set = await run<TrackSet?>(
      () => container.read(setRepositoryProvider).getSet(setId),
    );
    return set!;
  }

  /// Writes an entry straight into the database, at the time of the clock.
  Future<Entry> entry({
    required Person person,
    required Substance substance,
    String? amount,
    String? note,
  }) => run(
    () => entryRepo.add(
      personId: person.id,
      substanceId: substance.id,
      amount: amount,
      note: note,
    ),
  );

  /// All entries, oldest first.
  Future<List<Entry>> entries() => run(entryRepo.getAll);

  /// Opens the sheet "Ändern" of [entry] above the page.
  Future<void> openEdit(Entry entry, {bool fresh = false}) async {
    unawaited(showEntryEditSheet(_context, entry: entry, fresh: fresh));
    await settle();
  }

  /// Opens the scene editor of the set.
  Future<void> openScene() async {
    unawaited(showSceneEditor(_context, setId: setId));
    await settle();
  }

  /// Moves the fake clock and lets "now"-driven widgets follow.
  Future<void> advance(Duration duration) async {
    app.clock.advance(duration);
    await tester.pump(const Duration(milliseconds: 300));
  }
}
