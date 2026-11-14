import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'adaptive/adaptive.dart';
import 'core/clock.dart';
import 'core/now_ticker.dart';
import 'core/repo/providers.dart';
import 'core/services/alarms/alarm_service.dart';
import 'core/services/keep_awake.dart';
import 'features/history/history_screen.dart';
import 'features/settings/lock_gate.dart';
import 'features/settings/settings_screen.dart';
import 'features/tracks/tracks_screen.dart';
import 'l10n/strings.dart';
import 'theme/theme.dart';

/// The three top-level destinations, in navigation order.
enum ShellDestination { tracks, history, settings }

/// The selected top-level destination. Any feature may switch it, e.g.
/// `ref.read(shellDestinationProvider.notifier).go(ShellDestination.tracks)`.
class ShellDestinationController extends Notifier<ShellDestination> {
  @override
  ShellDestination build() => ShellDestination.tracks;

  void go(ShellDestination destination) => state = destination;
}

final shellDestinationProvider =
    NotifierProvider<ShellDestinationController, ShellDestination>(
      ShellDestinationController.new,
    );

/// Routes notification taps and action buttons from the [AlarmService] to
/// the track commands. Kept alive by the app shell.
final alarmActionRouterProvider = Provider<void>((ref) {
  final alarms = ref.watch(alarmServiceProvider);
  final subscription = alarms.actions.listen((action) async {
    final commands = ref.read(trackCommandsProvider);
    switch (action.type) {
      case AlarmActionType.dismiss:
        await commands.stopTrack(action.trackId);
      case AlarmActionType.acknowledge:
        await commands.ack(action.trackId);
      case AlarmActionType.open:
        // Bring the track into view: its set and the tracks destination.
        final track = await ref
            .read(trackRepositoryProvider)
            .getTrack(action.trackId);
        if (track != null) {
          await ref.read(activeSetIdProvider.notifier).select(track.setId);
        }
        ref
            .read(shellDestinationProvider.notifier)
            .go(ShellDestination.tracks);
    }
  });
  ref.onDispose(subscription.cancel);
});

/// Root widget: theme wiring, system light / dark tracking, lifecycle
/// handling for the shared ticker, lock gate and the app shell.
class TikkyApp extends ConsumerStatefulWidget {
  const TikkyApp({super.key});

  @override
  ConsumerState<TikkyApp> createState() => _TikkyAppState();
}

class _TikkyAppState extends ConsumerState<TikkyApp>
    with WidgetsBindingObserver {
  /// The alarm plans were rebuilt for the current trip to the background.
  bool _plannedForBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    ref
        .read(platformBrightnessProvider.notifier)
        .set(
          WidgetsBinding.instance.platformDispatcher.platformBrightness,
        );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Nothing counts in the background: time is derived from the log, so
    // the ticker can simply stop and catch up on resume.
    final ticker = ref.read(nowTickerProvider);
    switch (state) {
      case AppLifecycleState.resumed:
        _plannedForBackground = false;
        ticker.suspended = false;
        // Alarms may have fired (or been cleared by the OS) meanwhile.
        unawaited(ref.read(trackCommandsProvider).rescheduleAllAlarms());
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        ticker.suspended = true;
        // Every track only has a limited number of OS notification slots.
        // Rebuild the plans now, so the slots cover the time from the
        // moment the app leaves the screen (once per trip: Android reports
        // hidden and then paused).
        if (!_plannedForBackground) {
          _plannedForBackground = true;
          unawaited(ref.read(trackCommandsProvider).rescheduleAllAlarms());
        }
      case AppLifecycleState.detached:
        ticker.suspended = true;
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeData = ref.watch(appThemeDataProvider);
    final tokens = themeData.extension<TikkyTokens>()!;
    return MaterialApp(
      title: Strings.appName,
      debugShowCheckedModeBanner: false,
      // German UI: the built-in pickers, dialogs and tooltips follow.
      locale: const Locale('de'),
      supportedLocales: const [Locale('de')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: themeData,
      themeAnimationDuration: tokens.motion.normal,
      scrollBehavior: const AdaptiveScrollBehavior(),
      builder: (context, child) {
        final isDark = tokens.isDark;
        // Edge-to-edge: transparent system bars with matching icon colours,
        // also on pages without a Material app bar.
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            statusBarBrightness: tokens.theme.brightness,
            statusBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            systemNavigationBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
          ),
          child: LockGate(child: child ?? const SizedBox.shrink()),
        );
      },
      home: const AppShell(),
    );
  }
}

/// The app shell: waits for the bootstrap, then shows the three
/// destinations with adaptive navigation (bottom bar on phones, rail on
/// wide layouts). Destinations are built lazily and kept alive.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final Set<ShellDestination> _visited = {ShellDestination.tracks};

  /// At most one "system time changed" notice per this many milliseconds
  /// (setting the clock by hand produces several jumps in a row).
  static const int _clockNoticeEveryMs = 30000;

  StreamSubscription<int>? _clockJumps;
  int? _lastClockNoticeAt;

  /// The system time jumped while the app was open. Nothing in the log is
  /// rewritten; the OS alarms are rebuilt for the new time and the user is
  /// told once that running timers may be off.
  void _onClockJump(int jumpMs) {
    if (!mounted) return;
    unawaited(ref.read(trackCommandsProvider).rescheduleAllAlarms());
    final monotonicMs = ref.read(clockProvider).monotonicMs();
    final last = _lastClockNoticeAt;
    if (last != null && monotonicMs - last < _clockNoticeEveryMs) return;
    _lastClockNoticeAt = monotonicMs;
    showInfoSnackBar(context, Strings.clockChanged);
  }

  @override
  void dispose() {
    unawaited(_clockJumps?.cancel());
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual<NowTicker>(nowTickerProvider, (previous, ticker) {
      unawaited(_clockJumps?.cancel());
      _clockJumps = ticker.clockJumps.listen(_onClockJump);
    }, fireImmediately: true);
    // "Bildschirm anlassen" follows the preference in effect for the active
    // set. The service is only touched when the wake lock is (or was) on.
    ref.listenManual<bool>(
      activeUiPrefsProvider.select((prefs) => prefs.keepScreenOn),
      (previous, next) {
        if (next || previous == true) {
          unawaited(ref.read(keepAwakeServiceProvider).setEnabled(next));
        }
      },
      fireImmediately: true,
    );
  }

  /// A visited destination stays mounted (scroll position, filter, open
  /// pickers survive a tab change).
  ///
  /// The history is additionally switched to `TickerMode` off while it is
  /// not shown: that pauses its provider subscriptions and with them the
  /// session stream, which would otherwise re-read the whole history on
  /// every event written on the tracks screen (see `watchTables`). It
  /// catches up with one reload when it is shown again. Always the same
  /// widget at the same place, so no state is lost.
  Widget _keptAlive(ShellDestination destination, {required bool visible}) {
    final page = _page(destination);
    if (destination != ShellDestination.history) return page;
    return TickerMode(enabled: visible, child: page);
  }

  Widget _page(ShellDestination destination) => switch (destination) {
    ShellDestination.tracks => const TracksScreen(),
    ShellDestination.history => const HistoryScreen(),
    ShellDestination.settings => const SettingsScreen(),
  };

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(appBootstrapProvider);
    ref.watch(alarmActionRouterProvider);

    if (bootstrap.isLoading && !bootstrap.hasValue) {
      return const Scaffold(body: AdaptiveProgress());
    }
    if (bootstrap.hasError && !bootstrap.hasValue) {
      return Scaffold(
        body: AdaptiveEmptyState(
          icon: AdaptiveIcons.close(context),
          title: Strings.errorGeneric,
          message: '${bootstrap.error}',
        ),
      );
    }

    final selected = ref.watch(shellDestinationProvider);
    _visited.add(selected);
    return AdaptiveNavScaffold(
      selectedIndex: selected.index,
      onDestinationSelected: (index) => ref
          .read(shellDestinationProvider.notifier)
          .go(ShellDestination.values[index]),
      destinations: [
        AdaptiveDestination(
          label: Strings.navTracks,
          icon: AdaptiveIcons.tracks(context),
          selectedIcon: AdaptiveIcons.tracksSelected(context),
        ),
        AdaptiveDestination(
          label: Strings.navHistory,
          icon: AdaptiveIcons.history(context),
          selectedIcon: AdaptiveIcons.historySelected(context),
        ),
        AdaptiveDestination(
          label: Strings.navSettings,
          icon: AdaptiveIcons.settings(context),
          selectedIcon: AdaptiveIcons.settingsSelected(context),
        ),
      ],
      body: IndexedStack(
        index: selected.index,
        children: [
          for (final destination in ShellDestination.values)
            _visited.contains(destination)
                ? _keptAlive(destination, visible: destination == selected)
                : const SizedBox.shrink(),
        ],
      ),
    );
  }
}
