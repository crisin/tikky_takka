import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/core/services/export_service.dart';
import 'package:tikky_takka/features/history/export_sheet.dart';
import 'package:tikky_takka/features/history/history_screen.dart';
import 'package:tikky_takka/features/history/history_strings.dart';
import 'package:tikky_takka/l10n/strings.dart';
import 'package:tikky_takka/theme/theme.dart';

import '../../support/test_app.dart';
import 'history_fixture.dart';

void main() {
  late TestApp app;
  late HistoryFixture fx;
  late FakeExportService export;

  Future<void> pumpHistory(WidgetTester tester) async {
    export = FakeExportService();
    app = await TestApp.create(
      tester,
      startMs: wednesdayMorning,
      extraOverrides: [exportServiceProvider.overrideWithValue(export)],
    );
    fx = HistoryFixture(app);
    await fx.run(tester, fx.seedTwoDays);
    await app.pumpWidget(tester, const HistoryScreen());
    await settleUi(tester, app);
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(HistoryScreen)));

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byTooltip(Strings.export));
    await settleUi(tester, app);
    expect(find.text(Strings.exportTitle), findsOneWidget);
  }

  bool protocolSwitch(WidgetTester tester) => tester
      .widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, Strings.exportIncludeProtocol),
      )
      .value;

  testWidgets('offers the three exports and the import; protocol is off', (
    tester,
  ) async {
    await pumpHistory(tester);
    await openSheet(tester);

    expect(find.text(Strings.exportSessionsCsv), findsOneWidget);
    expect(find.text(Strings.exportEventsCsv), findsOneWidget);
    expect(find.text(Strings.exportBackupJson), findsOneWidget);
    expect(find.text(Strings.importBackupJson), findsOneWidget);
    expect(find.text(Strings.exportIncludeProtocolHint), findsOneWidget);
    expect(protocolSwitch(tester), isFalse);
    expect(find.text(HistoryStrings.exportAllSessions), findsOneWidget);
    expect(
      find.text(HistoryStrings.separatorInfo(Strings.csvSemicolon)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('sessions CSV: default options, delivered, sheet closes', (
    tester,
  ) async {
    await pumpHistory(tester);
    await openSheet(tester);

    await tester.tap(find.text(Strings.exportSessionsCsv));
    await settleUi(tester, app);

    final (kind, options) = export.built.single;
    expect(kind, ExportKind.sessionsCsv);
    expect(options.includeProtocol, isFalse);
    expect(options.separator, CsvSeparator.semicolon);
    expect(options.filter, HistoryFilter.all);
    expect(export.delivered, hasLength(1));
    // The share popover is anchored at the tapped row.
    expect(export.lastOrigin, isNotNull);
    expect(export.lastOrigin!.width, greaterThan(0));

    expect(find.text(Strings.exportTitle), findsNothing);
    expect(find.text(Strings.exportDone), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('honours the active filter, the separator preference and the '
      'protocol opt-in', (tester) async {
    await pumpHistory(tester);
    final filter = HistoryFilter(
      setId: 'some-set',
      fromMs: DateTime(2026, 11, 11).millisecondsSinceEpoch,
      toMs: DateTime(2026, 11, 12).millisecondsSinceEpoch,
    );
    container(tester).read(historyFilterProvider.notifier).set(filter);
    await tester.runAsync(
      () => container(tester)
          .read(uiPrefsProvider.notifier)
          .change((p) => p.copyWith(csvSeparator: CsvSeparator.comma)),
    );
    await settleUi(tester, app);
    await openSheet(tester);

    expect(
      find.text(HistoryStrings.separatorInfo(Strings.csvComma)),
      findsOneWidget,
    );
    expect(
      find.textContaining('Der Export berücksichtigt den Filter: Heute'),
      findsOneWidget,
    );

    await tester.tap(
      find.widgetWithText(SwitchListTile, Strings.exportIncludeProtocol),
    );
    await settleUi(tester, app);
    expect(protocolSwitch(tester), isTrue);

    await tester.tap(find.text(Strings.exportEventsCsv));
    await settleUi(tester, app);

    final (kind, options) = export.built.single;
    expect(kind, ExportKind.eventsCsv);
    expect(options.includeProtocol, isTrue);
    expect(options.separator, CsvSeparator.comma);
    expect(options.filter, filter);

    // The opt-in is not remembered.
    await openSheet(tester);
    expect(protocolSwitch(tester), isFalse);
    await tester.tap(find.text(Strings.exportBackupJson));
    await settleUi(tester, app);
    expect(export.built.last.$1, ExportKind.backupJson);
    expect(export.built.last.$2.includeProtocol, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a cancelled share / save keeps the sheet open', (tester) async {
    await pumpHistory(tester);
    export.deliverResult = false;
    await openSheet(tester);

    await tester.tap(find.text(Strings.exportSessionsCsv));
    await settleUi(tester, app);

    expect(export.delivered, hasLength(1));
    expect(find.text(Strings.exportTitle), findsOneWidget);
    expect(find.text(Strings.exportDone), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failing export is reported', (tester) async {
    await pumpHistory(tester);
    export.buildError = StateError('boom');
    await openSheet(tester);

    await tester.tap(find.text(Strings.exportSessionsCsv));
    await settleUi(tester, app);

    expect(find.text(Strings.exportFailed), findsOneWidget);
    await tester.tap(find.text(Strings.ok));
    await settleUi(tester, app);
    expect(find.text(Strings.exportTitle), findsOneWidget);
    expect(export.delivered, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('import shows the merge summary', (tester) async {
    await pumpHistory(tester);
    export
      ..pickedFile = '{"app":"tikky_takka"}'
      ..importReport = const ImportReport(
        inserted: {'sets': 1, 'tracks': 3, 'sessions': 12, 'events': 40},
        updated: {'tracks': 1},
        skipped: {'sets': 2, 'settings': 5},
      );
    await openSheet(tester);

    await tester.tap(find.text(Strings.importBackupJson));
    await settleUi(tester, app);

    expect(export.imported, ['{"app":"tikky_takka"}']);
    expect(find.text(Strings.importDone), findsOneWidget);
    final summary = describeImport(export.importReport);
    expect(find.text(summary), findsOneWidget);
    expect(summary, contains('56 neu, 1 aktualisiert, 7 unverändert'));
    expect(summary, contains('Spuren: 3 neu, 1 aktualisiert, 0 unverändert'));
    expect(summary, contains('Einstellungen: 0 neu, 0 aktualisiert, 5'));
    expect(summary, isNot(contains('Personen')));

    await tester.tap(find.text(Strings.ok));
    await settleUi(tester, app);
    expect(find.text(Strings.exportTitle), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('import: cancelled picker does nothing', (tester) async {
    await pumpHistory(tester);
    await openSheet(tester);

    await tester.tap(find.text(Strings.importBackupJson));
    await settleUi(tester, app);

    expect(export.imported, isEmpty);
    expect(find.text(Strings.importDone), findsNothing);
    expect(find.text(Strings.exportTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('import: a file that is no backup is rejected', (tester) async {
    await pumpHistory(tester);
    export
      ..pickedFile = 'Set;Spur'
      ..importError = const FormatException('nope');
    await openSheet(tester);

    await tester.tap(find.text(Strings.importBackupJson));
    await settleUi(tester, app);

    expect(find.text(Strings.importFailed), findsOneWidget);
    expect(find.text(Strings.importInvalidFile), findsOneWidget);
    await tester.tap(find.text(Strings.ok));
    await settleUi(tester, app);
    expect(find.text(Strings.exportTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('describeImport: nothing new', () {
    expect(
      describeImport(
        const ImportReport(skipped: {'sets': 2, 'tracks': 4}),
      ),
      HistoryStrings.importNothingNew,
    );
  });

  testWidgets('without a registered service the export fails politely', (
    tester,
  ) async {
    app = await TestApp.create(tester, startMs: wednesdayMorning);
    await app.pumpWidget(tester, const HistoryScreen());
    await settleUi(tester, app);
    await tester.tap(find.byTooltip(Strings.export));
    await settleUi(tester, app);

    await tester.tap(find.text(Strings.exportSessionsCsv));
    await settleUi(tester, app);
    expect(find.text(Strings.exportFailed), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
