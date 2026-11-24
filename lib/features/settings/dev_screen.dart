import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../core/repo/providers.dart';
import '../../core/repo/settings_store.dart';
import '../../core/services/dev/app_reset.dart';
import '../../core/services/dev/dev_tools.dart';
import '../../core/services/dev/frame_stats.dart';
import '../../core/services/settings_refresh.dart';
import '../../l10n/strings.dart';
import 'settings_strings.dart';
import 'widgets/setting_rows.dart';
import 'widgets/settings_icons.dart';

/// Keys for tests.
abstract final class DevKeys {
  static const checkUpdate = ValueKey('dev.checkUpdate');
  static const clearCache = ValueKey('dev.clearCache');
  static const perfReset = ValueKey('dev.perfReset');
  static const frames = ValueKey('dev.frames');
  static const events = ValueKey('dev.events');
  static const reset = ValueKey('dev.reset');
  static ValueKey<String> cache(String name) => ValueKey('dev.cache.$name');
}

/// "Entwickler" in the settings: for debugging and testing, above all the
/// installed web app. What the offline cache holds, how much data there
/// is, how fast the app draws, and a full reset (with a warning).
class DevScreen extends ConsumerStatefulWidget {
  const DevScreen({super.key});

  @override
  ConsumerState<DevScreen> createState() => _DevScreenState();
}

class _DevScreenState extends ConsumerState<DevScreen> {
  PwaStatus? _pwa;
  TableCounts? _counts;
  int? _dbBytes;
  bool _busy = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _refresh();
    // The frame figures move while the page is open.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final tools = ref.read(devToolsProvider);
    final reset = ref.read(appResetProvider);
    final counts = await reset.counts();
    final dbBytes = await tools.databaseBytes();
    if (!mounted) return;
    setState(() {
      _counts = counts;
      _dbBytes = dbBytes;
    });
    // Reading the caches takes a moment; the rest is already on screen.
    final pwa = await tools.pwaStatus();
    if (!mounted) return;
    setState(() => _pwa = pwa);
  }

  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkUpdate() => _guard(() async {
    final tools = ref.read(devToolsProvider);
    String message;
    try {
      message = await tools.checkForUpdate()
          ? SettingsStrings.devUpdateFound
          : SettingsStrings.devUpdateNone;
    } catch (_) {
      message = SettingsStrings.devUpdateFailed;
    }
    if (!mounted) return;
    showInfoSnackBar(context, message);
    await _refresh();
  });

  Future<void> _clearCache() => _guard(() async {
    final tools = ref.read(devToolsProvider);
    if (!tools.online) {
      showInfoSnackBar(context, SettingsStrings.devNeedsNetwork);
      return;
    }
    await tools.clearOfflineCache();
    tools.reload();
  });

  Future<void> _reset() => _guard(() async {
    final confirmed = await showAdaptiveConfirm(
      context,
      title: SettingsStrings.devResetTitle,
      message: SettingsStrings.devResetMessage,
      confirmLabel: SettingsStrings.devResetConfirm,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final tools = ref.read(devToolsProvider);
    try {
      await ref.read(appResetProvider).wipe(offlineCache: tools.online);
      if (tools.isWeb) {
        // A fresh page start writes the first-launch data again.
        tools.reload();
        return;
      }
      ref.invalidate(appBootstrapProvider);
      await ref.read(appBootstrapProvider.future);
      // The seed writes its flag straight to the database.
      await ref.read(settingsStoreProvider).reload();
      if (!mounted) return;
      refreshSettingsAfterImport(ref);
      showInfoSnackBar(context, SettingsStrings.devResetDone);
      await _refresh();
    } catch (_) {
      if (mounted) showInfoSnackBar(context, SettingsStrings.devResetFailed);
    }
  });

  static String _yesNo(bool? value) => switch (value) {
    null => SettingsStrings.devUnknown,
    true => SettingsStrings.diagYes,
    false => SettingsStrings.diagNo,
  };

  static String _count(int? value) =>
      value == null ? SettingsStrings.devUnknown : '$value';

  static String _workerState(PwaStatus pwa) => !pwa.workerSupported
      ? SettingsStrings.devWorkerUnsupported
      : switch (pwa.workerState) {
          null => SettingsStrings.devWorkerNone,
          'activated' => SettingsStrings.devWorkerActive,
          final state => state,
        };

  List<Widget> _pwaSections(BuildContext context, PwaStatus pwa) {
    final usage = pwa.usageBytes;
    final quota = pwa.quotaBytes;
    return [
      AdaptiveSection(
        header: SettingsStrings.devPwa,
        footer: SettingsStrings.devPwaFooter,
        children: [
          AdaptiveTile(
            title: SettingsStrings.devWorker,
            value: _workerState(pwa),
          ),
          AdaptiveTile(
            title: SettingsStrings.devControlled,
            value: _yesNo(pwa.controlled),
          ),
          AdaptiveTile(
            title: SettingsStrings.devCachedVersion,
            value: pwa.cachedVersion ?? SettingsStrings.devUnknown,
          ),
          AdaptiveTile(
            title: SettingsStrings.devInstalled,
            value: _yesNo(pwa.installed),
          ),
          AdaptiveTile(
            title: SettingsStrings.devOnline,
            value: _yesNo(pwa.online),
          ),
          AdaptiveTile(
            title: SettingsStrings.devPersisted,
            value: _yesNo(pwa.persisted),
          ),
          AdaptiveTile(
            title: SettingsStrings.devUsage,
            value: usage == null || quota == null
                ? SettingsStrings.devUnknown
                : SettingsStrings.devUsageOf(usage, quota),
          ),
          AdaptiveTile(
            key: DevKeys.checkUpdate,
            leading: Icon(SettingsIcons.refresh(context)),
            title: SettingsStrings.devCheckUpdate,
            onTap: pwa.workerState == null ? null : _checkUpdate,
          ),
          AdaptiveTile(
            key: DevKeys.clearCache,
            leading: Icon(AdaptiveIcons.delete(context)),
            title: SettingsStrings.devClearCache,
            subtitle: SettingsStrings.devClearCacheHint,
            onTap: pwa.caches.isEmpty ? null : _clearCache,
          ),
        ],
      ),
      AdaptiveSection(
        header: SettingsStrings.devCaches,
        children: [
          if (pwa.caches.isEmpty)
            const AdaptiveTile(title: SettingsStrings.devNoCaches),
          for (final cache in pwa.caches)
            AdaptiveTile(
              key: DevKeys.cache(cache.name),
              title: cache.name,
              subtitle: SettingsStrings.devCacheSummary(
                cache.entries.length,
                cache.bytes,
              ),
              onTap: () => pushAdaptivePage<void>(
                context,
                builder: (_) => _CacheFilesScreen(cache: cache),
              ),
            ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tools = ref.watch(devToolsProvider);
    final stats = ref.watch(frameStatsProvider);
    final pwa = _pwa;
    final counts = _counts;
    final dbBytes = _dbBytes;
    final memory = tools.memoryBytes();
    final startup = stats.startupMs;

    final refreshRate = View.of(context).display.refreshRate;
    final budgetMs = 1000 / (refreshRate > 0 ? refreshRate : 60);
    final frames = stats.summary(budgetMs: budgetMs);
    String frameMs(double value) =>
        frames.frames == 0 ? SettingsStrings.devUnknown : DevFormat.ms(value);

    return AdaptivePageScaffold(
      title: const Text(SettingsStrings.dev),
      body: SettingsBody(
        children: [
          if (pwa != null) ..._pwaSections(context, pwa),
          AdaptiveSection(
            header: SettingsStrings.devData,
            children: [
              if (dbBytes != null)
                AdaptiveTile(
                  title: SettingsStrings.devDbSize,
                  value: DevFormat.bytes(dbBytes),
                ),
              AdaptiveTile(
                title: SettingsStrings.sectionSets,
                value: _count(counts?.sets),
              ),
              AdaptiveTile(
                title: SettingsStrings.devTracks,
                value: _count(counts?.tracks),
              ),
              AdaptiveTile(
                title: SettingsStrings.devSessions,
                value: _count(counts?.sessions),
              ),
              AdaptiveTile(
                key: DevKeys.events,
                title: SettingsStrings.devEvents,
                value: _count(counts?.events),
              ),
              AdaptiveTile(
                title: SettingsStrings.devEntries,
                value: _count(counts?.entries),
              ),
              AdaptiveTile(
                title: Strings.persons,
                value: _count(counts?.persons),
              ),
              AdaptiveTile(
                title: Strings.substances,
                value: _count(counts?.substances),
              ),
              AdaptiveTile(
                title: SettingsStrings.devSettingsRows,
                value: _count(counts?.settings),
              ),
            ],
          ),
          AdaptiveSection(
            header: SettingsStrings.devPerf,
            footer: SettingsStrings.devPerfFooter(stats.capacity, budgetMs),
            children: [
              AdaptiveTile(
                title: SettingsStrings.devStartup,
                value: startup == null
                    ? SettingsStrings.devUnknown
                    : DevFormat.ms(startup.toDouble()),
              ),
              AdaptiveTile(
                key: DevKeys.frames,
                title: SettingsStrings.devFrames,
                value: '${frames.frames}',
              ),
              AdaptiveTile(
                title: SettingsStrings.devBuild,
                value: frameMs(frames.avgBuildMs),
              ),
              AdaptiveTile(
                title: SettingsStrings.devRaster,
                value: frameMs(frames.avgRasterMs),
              ),
              AdaptiveTile(
                title: SettingsStrings.devWorst,
                value: frameMs(frames.worstMs),
              ),
              AdaptiveTile(
                title: SettingsStrings.devSlow,
                value: SettingsStrings.devCountOf(frames.slow, frames.frames),
              ),
              if (memory != null)
                AdaptiveTile(
                  title: SettingsStrings.devMemory,
                  value: DevFormat.bytes(memory),
                ),
              AdaptiveTile(
                key: DevKeys.perfReset,
                leading: Icon(SettingsIcons.refresh(context)),
                title: SettingsStrings.devPerfReset,
                onTap: () => setState(stats.clear),
              ),
            ],
          ),
          AdaptiveSection(
            header: SettingsStrings.devReset,
            children: [
              AdaptiveTile(
                key: DevKeys.reset,
                leading: Icon(SettingsIcons.warning(context)),
                title: SettingsStrings.devResetApp,
                subtitle: SettingsStrings.devResetHint,
                destructive: true,
                onTap: _reset,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The files of one cache, largest first.
class _CacheFilesScreen extends StatelessWidget {
  const _CacheFilesScreen({required this.cache});

  final CacheInfo cache;

  @override
  Widget build(BuildContext context) {
    return AdaptivePageScaffold(
      title: Text(cache.name),
      body: SettingsBody(
        children: [
          AdaptiveSection(
            header: SettingsStrings.devCacheSummary(
              cache.entries.length,
              cache.bytes,
            ),
            children: [
              for (final entry in cache.entries)
                AdaptiveTile(
                  title: entry.path,
                  value: DevFormat.bytes(entry.bytes),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
