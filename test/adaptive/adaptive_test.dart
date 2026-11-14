import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/adaptive/adaptive.dart';
import 'package:tikky_takka/l10n/strings.dart';
import 'package:tikky_takka/theme/theme.dart';

/// Pumps [child] in a themed app for [platform] at a phone-sized (or given)
/// window.
Future<void> pumpOn(
  WidgetTester tester,
  TargetPlatform platform,
  Widget child, {
  Size size = const Size(400, 800),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildMaterialTheme(
        ThemePresets.light,
        UiPrefs.defaults,
        platform: platform,
      ),
      // Theme changes animate; tests that switch platform want it at once.
      themeAnimationDuration: Duration.zero,
      home: child,
    ),
  );
}

const _destinations = [
  AdaptiveDestination(
    label: 'Eins',
    icon: Icons.looks_one_outlined,
    selectedIcon: Icons.looks_one,
  ),
  AdaptiveDestination(
    label: 'Zwei',
    icon: Icons.looks_two_outlined,
    selectedIcon: Icons.looks_two,
  ),
];

void main() {
  group('AdaptiveNavScaffold', () {
    Widget scaffold(ValueChanged<int> onSelected) => AdaptiveNavScaffold(
      destinations: _destinations,
      selectedIndex: 0,
      onDestinationSelected: onSelected,
      body: const AdaptivePageScaffold(
        title: Text('Titel'),
        body: Text('Inhalt'),
      ),
    );

    testWidgets('Material phone: NavigationBar + AppBar', (tester) async {
      int? tapped;
      await pumpOn(tester, TargetPlatform.android, scaffold((i) => tapped = i));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(CupertinoTabBar), findsNothing);
      await tester.tap(find.text('Zwei'));
      expect(tapped, 1);
    });

    testWidgets('Cupertino phone: CupertinoTabBar + CupertinoNavigationBar', (
      tester,
    ) async {
      int? tapped;
      await pumpOn(tester, TargetPlatform.iOS, scaffold((i) => tapped = i));
      expect(find.byType(CupertinoTabBar), findsOneWidget);
      expect(find.byType(CupertinoNavigationBar), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Titel'), findsOneWidget);
      expect(find.text('Inhalt'), findsOneWidget);
      await tester.tap(find.text('Zwei'));
      expect(tapped, 1);
    });

    testWidgets('wide: NavigationRail on every platform', (tester) async {
      for (final platform in [
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.android,
      ]) {
        int? tapped;
        await pumpOn(
          tester,
          platform,
          scaffold((i) => tapped = i),
          size: const Size(1000, 700),
        );
        expect(find.byType(NavigationRail), findsOneWidget, reason: '$platform');
        expect(find.byType(NavigationBar), findsNothing);
        expect(find.byType(CupertinoTabBar), findsNothing);
        await tester.tap(find.text('Zwei'));
        expect(tapped, 1);
      }
    });

    testWidgets('the breakpoint is 720 logical pixels', (tester) async {
      await pumpOn(
        tester,
        TargetPlatform.android,
        scaffold((_) {}),
        size: const Size(719, 700),
      );
      expect(find.byType(NavigationRail), findsNothing);
      await pumpOn(
        tester,
        TargetPlatform.android,
        scaffold((_) {}),
        size: const Size(720, 700),
      );
      expect(find.byType(NavigationRail), findsOneWidget);
    });
  });

  group('platform helpers', () {
    testWidgets('isCupertino / isDesktop / icons follow the theme platform', (
      tester,
    ) async {
      final results = <TargetPlatform, (bool, bool, IconData)>{};
      for (final platform in TargetPlatform.values) {
        await pumpOn(
          tester,
          platform,
          Builder(
            builder: (context) {
              results[platform] = (
                isCupertino(context),
                isDesktop(context),
                AdaptiveIcons.add(context),
              );
              return const SizedBox();
            },
          ),
        );
      }
      expect(results[TargetPlatform.android], (false, false, Icons.add_rounded));
      expect(results[TargetPlatform.iOS], (true, false, CupertinoIcons.add));
      expect(results[TargetPlatform.macOS], (true, true, CupertinoIcons.add));
      expect(results[TargetPlatform.windows], (false, true, Icons.add_rounded));
    });
  });

  group('dialogs', () {
    Future<Future<T?>> open<T>(
      WidgetTester tester,
      TargetPlatform platform,
      Future<T?> Function(BuildContext context) show,
    ) async {
      late Future<T?> result;
      await pumpOn(
        tester,
        platform,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => result = show(context),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('confirm: Material', (tester) async {
      final result = await open<bool>(
        tester,
        TargetPlatform.android,
        (c) => showAdaptiveConfirm(
          c,
          title: 'Löschen?',
          message: 'Wirklich?',
          confirmLabel: Strings.delete,
          destructive: true,
        ),
      );
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.text('Wirklich?'), findsOneWidget);
      await tester.tap(find.text(Strings.delete));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    });

    testWidgets('confirm: Cupertino, cancel returns false', (tester) async {
      final result = await open<bool>(
        tester,
        TargetPlatform.iOS,
        (c) => showAdaptiveConfirm(c, title: 'Sicher?'),
      );
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.byType(CupertinoDialogAction), findsNWidgets(2));
      await tester.tap(find.text(Strings.cancel));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets('action sheet: Material bottom sheet', (tester) async {
      final result = await open<String>(
        tester,
        TargetPlatform.android,
        (c) => showAdaptiveActionSheet<String>(
          c,
          title: 'Aktion',
          actions: const [
            AdaptiveSheetAction(value: 'a', label: 'Alpha', selected: true),
            AdaptiveSheetAction(value: 'b', label: 'Beta', destructive: true),
          ],
        ),
      );
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(CupertinoActionSheet), findsNothing);
      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();
      expect(await result, 'b');
    });

    testWidgets('action sheet: CupertinoActionSheet', (tester) async {
      final result = await open<String>(
        tester,
        TargetPlatform.iOS,
        (c) => showAdaptiveActionSheet<String>(
          c,
          actions: const [AdaptiveSheetAction(value: 'a', label: 'Alpha')],
        ),
      );
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      expect(find.text(Strings.cancel), findsOneWidget);
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      expect(await result, 'a');
    });

    testWidgets('text prompt trims and refuses empty input', (tester) async {
      final result = await open<String>(
        tester,
        TargetPlatform.android,
        (c) => showAdaptiveTextPrompt(c, title: 'Name', initialValue: 'Alt'),
      );
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text(Strings.save));
      await tester.pumpAndSettle();
      // Still open.
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), '  Neu  ');
      await tester.tap(find.text(Strings.save));
      await tester.pumpAndSettle();
      expect(await result, 'Neu');
    });

    testWidgets('text prompt on Cupertino uses a CupertinoTextField', (
      tester,
    ) async {
      final result = await open<String>(
        tester,
        TargetPlatform.iOS,
        (c) => showAdaptiveTextPrompt(c, title: 'Name'),
      );
      expect(find.byType(CupertinoTextField), findsOneWidget);
      await tester.tap(find.text(Strings.cancel));
      await tester.pumpAndSettle();
      expect(await result, isNull);
    });

    testWidgets('sheet returns the popped value', (tester) async {
      final result = await open<int>(
        tester,
        TargetPlatform.android,
        (c) => showAdaptiveSheet<int>(
          c,
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).pop(7),
            child: const Text('sieben'),
          ),
        ),
      );
      await tester.tap(find.text('sieben'));
      await tester.pumpAndSettle();
      expect(await result, 7);
    });

    testWidgets('undo snackbar calls back', (tester) async {
      var undone = false;
      await pumpOn(
        tester,
        TargetPlatform.android,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showUndoSnackBar(
                context,
                message: 'Gelöscht',
                onUndo: () => undone = true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Gelöscht'), findsOneWidget);
      await tester.tap(find.text(Strings.undo));
      await tester.pumpAndSettle();
      expect(undone, isTrue);
    });
  });

  group('pickers', () {
    Future<Future<T?>> open<T>(
      WidgetTester tester,
      TargetPlatform platform,
      Future<T?> Function(BuildContext context) show,
    ) async {
      late Future<T?> result;
      await pumpOn(
        tester,
        platform,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => result = show(context),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('duration: Material wheels', (tester) async {
      final result = await open<Duration>(
        tester,
        TargetPlatform.android,
        (c) => showAdaptiveDurationPicker(
          c,
          initial: const Duration(hours: 1, minutes: 30, seconds: 15),
        ),
      );
      expect(find.byType(ListWheelScrollView), findsNWidgets(3));
      expect(find.byType(CupertinoTimerPicker), findsNothing);
      // Scroll the minutes wheel one step further.
      await tester.drag(
        find.byType(ListWheelScrollView).at(1),
        const Offset(0, -48),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.ok));
      await tester.pumpAndSettle();
      expect(await result, const Duration(hours: 1, minutes: 31, seconds: 15));
    });

    testWidgets('duration: without seconds', (tester) async {
      final result = await open<Duration>(
        tester,
        TargetPlatform.windows,
        (c) => showAdaptiveDurationPicker(
          c,
          initial: const Duration(minutes: 10, seconds: 59),
          showSeconds: false,
        ),
      );
      expect(find.byType(ListWheelScrollView), findsNWidgets(2));
      await tester.tap(find.text(Strings.ok));
      await tester.pumpAndSettle();
      expect(await result, const Duration(minutes: 10));
    });

    testWidgets('duration: CupertinoTimerPicker on Apple', (tester) async {
      final result = await open<Duration>(
        tester,
        TargetPlatform.iOS,
        (c) => showAdaptiveDurationPicker(
          c,
          initial: const Duration(minutes: 10),
        ),
      );
      expect(find.byType(CupertinoTimerPicker), findsOneWidget);
      await tester.tap(find.text(Strings.done));
      await tester.pumpAndSettle();
      expect(await result, const Duration(minutes: 10));
    });

    testWidgets('duration: cancel returns null', (tester) async {
      final result = await open<Duration>(
        tester,
        TargetPlatform.android,
        (c) => showAdaptiveDurationPicker(c, initial: Duration.zero),
      );
      await tester.tap(find.text(Strings.cancel));
      await tester.pumpAndSettle();
      expect(await result, isNull);
    });

    testWidgets('date: Cupertino picker returns local midnight', (tester) async {
      final result = await open<DateTime>(
        tester,
        TargetPlatform.iOS,
        (c) => showAdaptiveDatePicker(
          c,
          initial: DateTime(2026, 11, 11, 15, 30),
          first: DateTime(2020),
          last: DateTime(2030),
        ),
      );
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      await tester.tap(find.text(Strings.done));
      await tester.pumpAndSettle();
      expect(await result, DateTime(2026, 11, 11));
    });

    testWidgets('date: Material picker with German buttons', (tester) async {
      final result = await open<DateTime>(
        tester,
        TargetPlatform.android,
        (c) => showAdaptiveDatePicker(
          c,
          initial: DateTime(2026, 11, 11),
          first: DateTime(2020),
          last: DateTime(2030),
        ),
      );
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(find.text(Strings.cancel), findsOneWidget);
      await tester.tap(find.text(Strings.ok));
      await tester.pumpAndSettle();
      expect(await result, DateTime(2026, 11, 11));
    });

    testWidgets('date range: Cupertino shows two pickers', (tester) async {
      final result = await open<DateTimeRange>(
        tester,
        TargetPlatform.iOS,
        (c) => showAdaptiveDateRangePicker(
          c,
          first: DateTime(2020),
          last: DateTime(2030),
          initial: DateTimeRange(
            start: DateTime(2026, 11, 9, 8),
            end: DateTime(2026, 11, 11, 20),
          ),
        ),
      );
      expect(find.byType(CupertinoDatePicker), findsNWidgets(2));
      await tester.tap(find.text(Strings.done));
      await tester.pumpAndSettle();
      expect(
        await result,
        DateTimeRange(start: DateTime(2026, 11, 9), end: DateTime(2026, 11, 11)),
      );
    });
  });

  group('controls', () {
    testWidgets('switch, slider and segmented adapt to the platform', (
      tester,
    ) async {
      Widget controls(void Function(Object) onChange) => Scaffold(
        body: Column(
          children: [
            AdaptiveSwitch(
              value: false,
              onChanged: onChange,
              semanticLabel: 'Schalter',
            ),
            AdaptiveSlider(value: 0.5, onChanged: onChange),
            AdaptiveSegmented<String>(
              segments: const {'a': 'Alpha', 'b': 'Beta'},
              selected: 'a',
              onChanged: onChange,
            ),
            const AdaptiveProgress(),
          ],
        ),
      );

      final changes = <Object>[];
      await pumpOn(tester, TargetPlatform.android, controls(changes.add));
      expect(find.byType(SegmentedButton<String>), findsOneWidget);
      expect(find.byType(CupertinoSlider), findsNothing);
      await tester.tap(find.text('Beta'));
      await tester.tap(find.byType(Switch));
      expect(changes, ['b', true]);

      changes.clear();
      await pumpOn(tester, TargetPlatform.iOS, controls(changes.add));
      // Switch.adaptive paints the iOS toggle itself (no CupertinoSwitch
      // widget in the tree).
      expect(find.byType(Switch), findsOneWidget);
      expect(find.byType(CupertinoSlider), findsOneWidget);
      expect(
        find.byType(CupertinoSlidingSegmentedControl<String>),
        findsOneWidget,
      );
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      await tester.tap(find.text('Beta'));
      // No pumpAndSettle: the activity indicator animates forever.
      await tester.pump(const Duration(milliseconds: 500));
      expect(changes, ['b']);
    });

    testWidgets('icon buttons always expose a semantics label', (tester) async {
      final handle = tester.ensureSemantics();
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        var taps = 0;
        await pumpOn(
          tester,
          platform,
          Scaffold(
            body: Builder(
              builder: (context) => AdaptiveIconButton(
                icon: AdaptiveIcons.add(context),
                semanticLabel: Strings.addTrack,
                onPressed: () => taps++,
              ),
            ),
          ),
        );
        expect(find.bySemanticsLabel(Strings.addTrack), findsOneWidget);
        await tester.tap(find.byType(AdaptiveIconButton));
        expect(taps, 1, reason: '$platform');
        final size = tester.getSize(find.byType(AdaptiveIconButton));
        expect(size.width, greaterThanOrEqualTo(40));
        expect(size.height, greaterThanOrEqualTo(40));
      }
      handle.dispose();
    });

    testWidgets('sections, tiles, buttons and empty state render', (
      tester,
    ) async {
      for (final platform in [TargetPlatform.android, TargetPlatform.macOS]) {
        var tapped = 0;
        await pumpOn(
          tester,
          platform,
          Scaffold(
            body: ListView(
              children: [
                AdaptiveSection(
                  header: 'Darstellung',
                  footer: 'Hinweis',
                  children: [
                    AdaptiveTile(
                      title: 'Design',
                      value: 'Dunkel',
                      onTap: () => tapped++,
                    ),
                    AdaptiveSwitchTile(
                      title: 'Haptik',
                      subtitle: 'Vibration beim Tippen',
                      value: true,
                      onChanged: (_) => tapped++,
                    ),
                    AdaptiveTile(
                      title: 'Löschen',
                      destructive: true,
                      onTap: () {},
                    ),
                  ],
                ),
                AdaptiveFilledButton(
                  label: 'Los',
                  icon: Icons.check,
                  onPressed: () => tapped++,
                ),
                AdaptiveFilledButton(
                  label: 'Weg',
                  destructive: true,
                  onPressed: () {},
                ),
                AdaptiveTextButton(label: 'Später', onPressed: () => tapped++),
                const SizedBox(
                  height: 300,
                  child: AdaptiveEmptyState(
                    icon: Icons.inbox,
                    title: 'Leer',
                    message: 'Nichts da',
                  ),
                ),
              ],
            ),
          ),
        );
        expect(find.text('Darstellung'), findsOneWidget);
        expect(find.text('Dunkel'), findsOneWidget);
        expect(find.text('Leer'), findsOneWidget);
        await tester.tap(find.text('Design'));
        await tester.tap(find.text('Los'));
        await tester.tap(find.text('Später'));
        expect(tapped, 3, reason: '$platform');
        expect(tester.takeException(), isNull);
      }
    });
  });

  test('scroll behaviour allows mouse dragging', () {
    const behavior = AdaptiveScrollBehavior();
    expect(behavior.dragDevices, contains(PointerDeviceKind.mouse));
    expect(behavior.dragDevices, contains(PointerDeviceKind.touch));
    expect(behavior.dragDevices, contains(PointerDeviceKind.trackpad));
  });
}
