import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/services/diagnostics_log.dart';
import 'package:tikky_takka/features/settings/diagnostics_screen.dart';
import 'package:tikky_takka/features/settings/settings_strings.dart';

import 'settings_harness.dart';

void main() {
  group('DiagnosticsLog', () {
    test('keeps the newest entries up to its capacity', () {
      var now = 0;
      final log = DiagnosticsLog(capacity: 2, nowMs: () => now++);
      log
        ..record('A', 'one')
        ..record('B', 'two')
        ..record('C', 'three');
      expect(log.entries.map((e) => e.message), ['two', 'three']);
      log.clear();
      expect(log.entries, isEmpty);
    });
  });

  group('diagnostics screen', () {
    Future<(SettingsHarness, DiagnosticsLog)> open(WidgetTester tester) async {
      final log = DiagnosticsLog(nowMs: () => 1700000000000);
      final h = await SettingsHarness.create(
        tester,
        extraOverrides: [diagnosticsLogProvider.overrideWithValue(log)],
      );
      await h.pump(tester, const DiagnosticsScreen(version: '1.0.0'));
      return (h, log);
    }

    testWidgets('shows permissions, schedules the test alarm', (tester) async {
      final (h, _) = await open(tester);
      expect(find.text(SettingsStrings.diagSupported), findsOneWidget);
      expect(find.text(SettingsStrings.diagYes), findsWidgets);

      await tester.tap(find.byKey(DiagnosticsKeys.testAlarm));
      await h.settle(tester);
      expect(h.alarms.log, contains('test:10'));
      expect(find.text(SettingsStrings.diagTestAlarmSet), findsOneWidget);
    });

    testWidgets('lists errors, copies a report and clears', (tester) async {
      final (h, log) = await open(tester);
      await h.reveal(tester, find.byKey(DiagnosticsKeys.noErrors));
      expect(find.byKey(DiagnosticsKeys.noErrors), findsOneWidget);

      log.record('Alarme', StateError('kaputt'));
      await h.settle(tester);
      expect(find.byKey(DiagnosticsKeys.noErrors), findsNothing);

      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await h.reveal(tester, find.byKey(DiagnosticsKeys.copy), up: true);
      await tester.tap(find.byKey(DiagnosticsKeys.copy));
      await h.settle(tester);
      expect(copied, contains('Tikky Takka 1.0.0'));
      expect(copied, contains('Alarme: Bad state: kaputt'));

      await h.reveal(tester, find.byKey(DiagnosticsKeys.clear));
      await tester.tap(find.byKey(DiagnosticsKeys.clear));
      await h.settle(tester);
      expect(log.entries, isEmpty);
    });
  });
}
