import 'dart:ui' show Brightness, Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/clock.dart';
import 'package:tikky_takka/core/db/app_database.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/core/services/alarms/alarm_service.dart';
import 'package:tikky_takka/core/services/haptics.dart';
import 'package:tikky_takka/core/services/lock_service.dart';
import 'package:tikky_takka/theme/theme.dart';

/// A provider container on an in-memory database, plus a way to "restart
/// the app" on the same database.
class _Harness {
  _Harness._(this.db, this.container);

  final AppDatabase db;
  ProviderContainer container;

  static Future<ProviderContainer> _open(AppDatabase db) async {
    final clock = FakeClock(1000);
    final store = await SettingsStore.load(db, clock: clock);
    var id = 0;
    return ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        settingsStoreProvider.overrideWithValue(store),
        clockProvider.overrideWithValue(clock),
        idGeneratorProvider.overrideWithValue(() => 'gen-${++id}'),
        alarmServiceProvider.overrideWithValue(const NoopAlarmService()),
        dynamicPaletteProvider.overrideWith((ref) async => null),
      ],
    );
  }

  static Future<_Harness> create() async {
    final db = AppDatabase.inMemory();
    final harness = _Harness._(db, await _open(db));
    addTearDown(() async {
      harness.container.dispose();
      await db.close();
    });
    return harness;
  }

  /// Drops all in-memory state and reloads from the database.
  Future<void> restart() async {
    container.dispose();
    container = await _open(db);
  }

  T read<T>(ProviderListenable<T> provider) => container.read(provider);
}

void main() {
  test('theme settings persist across restarts', () async {
    final h = await _Harness.create();
    expect(h.read(themeSettingsProvider), ThemeSettings.defaults);
    expect(h.read(appThemeProvider).id, ThemePresets.lightId);

    await h
        .read(themeSettingsProvider.notifier)
        .selectTheme(ThemePresets.blackId);
    expect(h.read(appThemeProvider), ThemePresets.black);
    await h
        .read(themeSettingsProvider.notifier)
        .setDarkTheme(ThemePresets.blackId);
    await h.read(themeSettingsProvider.notifier).setUseDynamicColor(true);

    await h.restart();
    final settings = h.read(themeSettingsProvider);
    expect(settings.followSystem, isFalse);
    expect(settings.themeId, ThemePresets.blackId);
    expect(settings.darkThemeId, ThemePresets.blackId);
    expect(settings.useDynamicColor, isTrue);
    expect(h.read(appThemeProvider), ThemePresets.black);

    await h.read(themeSettingsProvider.notifier).setFollowSystem(true);
    h.read(platformBrightnessProvider.notifier).set(Brightness.dark);
    expect(h.read(appThemeProvider), ThemePresets.black);
    h.read(platformBrightnessProvider.notifier).set(Brightness.light);
    expect(h.read(appThemeProvider), ThemePresets.light);
    expect(h.read(appThemeDataProvider).brightness, Brightness.light);
  });

  test('custom themes: duplicate, edit, rename, delete, persist', () async {
    final h = await _Harness.create();
    final themes = h.read(customThemesProvider.notifier);
    expect(h.read(customThemesProvider), isEmpty);
    expect(h.read(allThemesProvider).length, 3);

    final copy = await themes.duplicate(ThemePresets.dark);
    expect(copy.id, 'gen-1');
    expect(copy.name, 'Dunkel (Kopie)');
    expect(copy.colors, ThemePresets.dark.colors);

    // Presets are read-only.
    expect(await themes.save(ThemePresets.dark.copyWith(name: 'x')), isFalse);

    final edited = copy.copyWith(
      colors: copy.colors.copyWith(primary: const Color(0xFF00FF00)),
      cornerRadius: 4,
    );
    expect(await themes.save(edited), isTrue);
    expect(await themes.rename(copy.id, 'Grün'), isTrue);
    expect(await themes.rename('missing', 'x'), isFalse);
    expect(h.read(customThemesProvider).single.name, 'Grün');
    expect(h.read(allThemesProvider).length, 4);

    await h.read(themeSettingsProvider.notifier).selectTheme(copy.id);
    expect(h.read(appThemeProvider).colors.primary, const Color(0xFF00FF00));

    await h.restart();
    final restored = h.read(customThemesProvider).single;
    expect(restored, edited.copyWith(name: 'Grün'));
    expect(h.read(appThemeProvider).id, copy.id);

    final deleted = await h.read(customThemesProvider.notifier).delete(copy.id);
    expect(deleted, restored);
    expect(h.read(customThemesProvider), isEmpty);
    // The selection now points nowhere: fall back to a preset.
    expect(h.read(appThemeProvider), ThemePresets.light);
    expect(
      await h.read(customThemesProvider.notifier).delete('missing'),
      isNull,
    );
  });

  test('theme file export / import always creates a new theme', () async {
    final h = await _Harness.create();
    final themes = h.read(customThemesProvider.notifier);
    final file = themes.exportFile(ThemePresets.blackId)!;
    expect(themes.exportFile('missing'), isNull);

    final imported = await themes.importFile(file);
    expect(imported, isNotNull);
    expect(imported!.id, isNot(ThemePresets.blackId));
    expect(ThemePresets.isPresetId(imported.id), isFalse);
    expect(imported.copyWith(id: ThemePresets.blackId), ThemePresets.black);

    final again = await themes.importFile(themes.exportFile(imported.id)!);
    expect(again!.id, isNot(imported.id));
    expect(h.read(customThemesProvider).length, 2);

    expect(await themes.importFile('{"hello":"world"}'), isNull);
    expect(await themes.importFile('garbage'), isNull);
    expect(h.read(customThemesProvider).length, 2);
  });

  test('UI prefs persist', () async {
    final h = await _Harness.create();
    expect(h.read(uiPrefsProvider), UiPrefs.defaults);
    await h
        .read(uiPrefsProvider.notifier)
        .change((p) => p.copyWith(leftHanded: true, digitScale: 1.4));
    await h.restart();
    expect(h.read(uiPrefsProvider).leftHanded, isTrue);
    expect(h.read(uiPrefsProvider).digitScale, 1.4);
    expect(h.read(hapticsProvider).enabled, isTrue);
  });

  test('active set, per-set theme and prefs overrides', () async {
    final h = await _Harness.create();
    await h.read(setRepositoryProvider).ensureSeedData();
    final festival = await h
        .read(setRepositoryProvider)
        .createSet(
          name: 'Festival',
          themeId: ThemePresets.blackId,
          uiPrefsOverride: {UiPrefsKeys.layout: 'tiles'},
        );
    // Keep the stream providers alive and wait for their first values.
    final sub = h.container.listen(setsProvider, (_, _) {});
    final subAll = h.container.listen(allSetsProvider, (_, _) {});
    final sets = await h.container.read(setsProvider.future);
    await h.container.read(allSetsProvider.future);
    expect(sets.map((s) => s.name), ['Allgemein', 'Festival']);

    // Nothing stored yet: the first set is active.
    expect(h.read(activeSetProvider)!.name, 'Allgemein');
    expect(h.read(activeThemeProvider).id, ThemePresets.lightId);
    expect(h.read(activeUiPrefsProvider).layout, LaneLayout.rows);

    await h.read(activeSetIdProvider.notifier).select(festival.id);
    expect(h.read(activeSetProvider)!.id, festival.id);
    expect(h.read(activeThemeProvider), ThemePresets.black);
    expect(h.read(activeUiPrefsProvider).layout, LaneLayout.tiles);
    expect(
      h.read(themeDataForSetProvider(festival.id)).scaffoldBackgroundColor,
      ThemePresets.black.colors.background,
    );
    // The app-wide theme is untouched by a set override.
    expect(h.read(appThemeProvider).id, ThemePresets.lightId);
    expect(h.read(themeForSetProvider(null)).id, ThemePresets.lightId);

    sub.close();
    subAll.close();
    await h.restart();
    final sub2 = h.container.listen(setsProvider, (_, _) {});
    await h.container.read(setsProvider.future);
    expect(h.read(activeSetProvider)!.id, festival.id);

    // A stale id (set deleted) falls back to the first set.
    await h.read(setRepositoryProvider).deleteSet(festival.id);
    await pumpEventQueue();
    expect(h.read(activeSetProvider)!.name, 'Allgemein');
    sub2.close();
  });

  test(
    'tracks, open sessions and lockouts flow through the providers',
    () async {
      final h = await _Harness.create();
      await h.read(setRepositoryProvider).ensureSeedData();
      final subs = [
        h.container.listen(setsProvider, (_, _) {}),
        h.container.listen(openSessionsProvider, (_, _) {}),
        h.container.listen(allTracksProvider, (_, _) {}),
        h.container.listen(allSubstancesProvider, (_, _) {}),
      ];
      final sets = await h.container.read(setsProvider.future);
      final setId = sets.single.id;
      final subTracks = h.container.listen(
        tracksInSetProvider(setId),
        (_, _) {},
      );
      await h.container.read(tracksInSetProvider(setId).future);
      await h.container.read(allTracksProvider.future);
      await h.container.read(openSessionsProvider.future);

      final tracks = h.read(activeTracksProvider);
      expect(tracks.map((t) => t.mode), [
        TrackMode.stopwatch,
        TrackMode.countdown,
        TrackMode.counter,
      ]);
      final watch = tracks.first;
      expect(h.read(trackProvider(watch.id)), watch);
      expect(h.read(trackProvider('missing')), isNull);
      expect(h.read(openSessionProvider(watch.id)), isNull);

      await h.read(trackCommandsProvider).startTrack(watch.id);
      await pumpEventQueue();
      final open = h.read(openSessionProvider(watch.id));
      expect(open!.events.single.type, EventType.start);
      expect(h.read(openSessionProvider(tracks[1].id)), isNull);

      final people = h.read(peopleRepositoryProvider);
      final locked = await people.createSubstance(name: 'A', lockoutMs: 5000);
      await people.createSubstance(name: 'B');
      await pumpEventQueue();
      expect(h.read(lockoutsProvider), {locked.id: 5000});
      expect(h.read(substancesByIdProvider).length, 2);

      await h.container.read(appBootstrapProvider.future);
      for (final s in subs) {
        s.close();
      }
      subTracks.close();
    },
  );

  test(
    'app lock switch persists; noop lock service is a pass-through',
    () async {
      final h = await _Harness.create();
      expect(h.read(appLockEnabledProvider), isFalse);
      expect(await h.container.read(lockSupportedProvider.future), isFalse);
      expect(
        await h.read(lockServiceProvider).authenticate(reason: 'x'),
        isTrue,
      );
      await h.read(appLockEnabledProvider.notifier).set(true);
      await h.restart();
      expect(h.read(appLockEnabledProvider), isTrue);
    },
  );
}
