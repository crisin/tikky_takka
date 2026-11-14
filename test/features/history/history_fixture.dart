import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/core/repo/session_store.dart';
import 'package:tikky_takka/core/services/export_service.dart';

import '../../support/test_app.dart';

/// 11.11.2026 09:00:00 local time, a Wednesday (ISO week 46).
final int wednesdayMorning = DateTime(2026, 11, 11, 9).millisecondsSinceEpoch;

/// 10.11.2026 09:00:00 local time.
final int tuesdayMorning = DateTime(2026, 11, 10, 9).millisecondsSinceEpoch;

/// Repositories on the database and clock of a [TestApp], to prepare
/// history data for widget tests. Database work must run on the real event
/// loop: wrap calls in [run].
class HistoryFixture {
  HistoryFixture(this.app) {
    final alarmSync = AlarmSync(SessionStore(app.db), app.clock, app.alarms);
    sets = SetRepository(app.db, app.clock, _newId, alarmSync);
    tracks = TrackRepository(app.db, app.clock, _newId, alarmSync);
    commands = TrackCommands(app.db, app.clock, _newId, alarmSync);
    history = HistoryRepository(app.db, app.clock, alarmSync);
    people = PeopleRepository(app.db, app.clock, _newId);
  }

  final TestApp app;
  late final SetRepository sets;
  late final TrackRepository tracks;
  late final TrackCommands commands;
  late final HistoryRepository history;
  late final PeopleRepository people;

  int _id = 0;

  String _newId() => 'fx-${(++_id).toString().padLeft(4, '0')}';

  /// Runs database work outside the fake-async zone of the widget test.
  Future<T> run<T>(WidgetTester tester, Future<T> Function() body) async =>
      (await tester.runAsync(body)) as T;

  /// Starts [track], lets [duration] pass and stops it. Returns the
  /// session id.
  Future<String> record(Track track, Duration duration) async {
    await commands.startTrack(track.id);
    app.clock.advance(duration);
    return (await commands.stopTrack(track.id))!;
  }

  /// Two sets with one track each and three sessions:
  ///
  /// * Tuesday 09:00: "Arbeit" (Büro), 1 h
  /// * Wednesday 09:00: "Arbeit" (Büro), 30 min
  /// * Wednesday 09:30: "Tee" (Küche), 5 min
  ///
  /// Afterwards the clock stands at Wednesday 09:35.
  Future<TwoDays> seedTwoDays() async {
    final office = await sets.createSet(name: 'Büro');
    final kitchen = await sets.createSet(name: 'Küche');
    final work = await tracks.createTrack(
      setId: office.id,
      name: 'Arbeit',
      config: const StopwatchConfig(),
    );
    final tea = await tracks.createTrack(
      setId: kitchen.id,
      name: 'Tee',
      config: const CountdownConfig(durationMs: 10 * 60 * 1000),
      colorIndex: 1,
    );
    app.clock.setMs(tuesdayMorning);
    final first = await record(work, const Duration(hours: 1));
    app.clock.setMs(wednesdayMorning);
    final second = await record(work, const Duration(minutes: 30));
    final third = await record(tea, const Duration(minutes: 5));
    return TwoDays(
      office: office,
      kitchen: kitchen,
      work: work,
      tea: tea,
      sessionIds: [first, second, third],
    );
  }
}

class TwoDays {
  const TwoDays({
    required this.office,
    required this.kitchen,
    required this.work,
    required this.tea,
    required this.sessionIds,
  });

  final TrackSet office;
  final TrackSet kitchen;
  final Track work;
  final Track tea;
  final List<String> sessionIds;
}

/// Lets database streams, sheets, dialogs and page transitions finish.
/// (`pumpAndSettle` is not usable: the database answers on the real event
/// loop and progress indicators animate forever.)
Future<void> settleUi(WidgetTester tester, TestApp app) async {
  // Database answers and animations take turns (a swipe animates, then
  // deletes, then the snackbar animates in), so alternate a few times.
  for (var i = 0; i < 4; i++) {
    await app.settle(tester, rounds: 3);
    await tester.pump(const Duration(milliseconds: 350));
  }
}

/// Records every call instead of touching the database or plugins.
class FakeExportService implements ExportService {
  final List<(ExportKind, ExportOptions)> built = [];
  final List<ExportFile> delivered = [];
  final List<String> imported = [];
  Rect? lastOrigin;

  /// What [deliver] answers (`false` = the user cancelled).
  bool deliverResult = true;

  /// Content of the picked file; `null` = cancelled.
  String? pickedFile;

  /// Thrown by [importJsonBackup] when set.
  Object? importError;

  /// Thrown by the `build*` methods when set.
  Object? buildError;
  ImportReport importReport = const ImportReport();

  Future<ExportFile> _build(ExportKind kind, ExportOptions options) async {
    final error = buildError;
    if (error != null) throw error;
    built.add((kind, options));
    return ExportFile(
      fileName: 'test.${kind.extension}',
      mimeType: kind.mimeType,
      bytes: Uint8List(0),
    );
  }

  @override
  Future<ExportFile> buildSessionsCsv(ExportOptions options) =>
      _build(ExportKind.sessionsCsv, options);

  @override
  Future<ExportFile> buildEventsCsv(ExportOptions options) =>
      _build(ExportKind.eventsCsv, options);

  @override
  Future<ExportFile> buildJsonBackup(ExportOptions options) =>
      _build(ExportKind.backupJson, options);

  @override
  Future<bool> deliver(ExportFile file, {Rect? sharePositionOrigin}) async {
    delivered.add(file);
    lastOrigin = sharePositionOrigin;
    return deliverResult;
  }

  @override
  Future<String?> pickJsonFile() async => pickedFile;

  @override
  Future<ImportReport> importJsonBackup(String json) async {
    final error = importError;
    if (error != null) throw error;
    imported.add(json);
    return importReport;
  }
}

/// Finds the widget of type [T] that contains [text].
Finder withText<T extends Widget>(String text) => find.widgetWithText(T, text);
