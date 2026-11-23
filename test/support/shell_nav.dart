import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/features/tracks/tracks_screen.dart';
import 'package:tikky_takka/l10n/strings.dart';

/// Opens [label] ("Einstellungen", "Verlauf") through "···" in the head of
/// the tracks screen. Leaves the page opening; settle afterwards.
Future<void> openFromMore(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(TracksScreenKeys.more));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.tap(find.text(label).last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Opens the settings page.
Future<void> openSettingsPage(WidgetTester tester) =>
    openFromMore(tester, Strings.navSettings);

/// Opens the history page.
Future<void> openHistoryPage(WidgetTester tester) =>
    openFromMore(tester, Strings.navHistory);

/// Closes the page on top (back to the tracks screen).
Future<void> closePage(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}
