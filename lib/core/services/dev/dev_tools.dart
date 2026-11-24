import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dev_tools_native.dart'
    if (dart.library.js_interop) 'dev_tools_web.dart'
    as platform;

/// One file in an offline cache.
@immutable
final class CacheEntryInfo {
  const CacheEntryInfo({required this.path, required this.bytes});

  /// Path relative to the app's base URL (`./` is the app shell).
  final String path;
  final int bytes;
}

/// One cache of the browser's Cache Storage.
@immutable
final class CacheInfo {
  const CacheInfo({required this.name, required this.entries});

  final String name;
  final List<CacheEntryInfo> entries;

  int get bytes => entries.fold(0, (sum, e) => sum + e.bytes);
}

/// What the browser knows about the installed web app.
@immutable
final class PwaStatus {
  const PwaStatus({
    required this.workerSupported,
    required this.workerState,
    required this.controlled,
    required this.installed,
    required this.online,
    required this.persisted,
    required this.usageBytes,
    required this.quotaBytes,
    required this.caches,
  });

  /// False in an insecure context (plain http on another host) or in a
  /// browser without service workers.
  final bool workerSupported;

  /// State of the registered worker (`activated`, `installing`, …), or
  /// `null` without a registration (as in `flutter run -d chrome`).
  final String? workerState;

  /// Whether this page is served through the worker.
  final bool controlled;

  /// Runs as an installed app (home screen), not in a browser tab.
  final bool installed;
  final bool online;

  /// Whether the browser promised to keep the data (`null`: unknown).
  final bool? persisted;
  final int? usageBytes;
  final int? quotaBytes;
  final List<CacheInfo> caches;

  /// The build version of the app cache (`tikky-<version>`), if any.
  String? get cachedVersion {
    for (final c in caches) {
      if (c.name.startsWith(appCachePrefix) &&
          !c.name.startsWith(rendererCachePrefix)) {
        return c.name.substring(appCachePrefix.length);
      }
    }
    return null;
  }

  /// Cache names written by `web/sw.js`.
  static const appCachePrefix = 'tikky-';
  static const rendererCachePrefix = 'tikky-canvaskit-';
}

/// Platform access for the developer page in the settings: the browser's
/// service worker and caches on the web, process figures elsewhere.
abstract class DevTools {
  /// Whether this is the web build (PWA section, reset by reloading).
  bool get isWeb;

  /// `null` outside the browser.
  Future<PwaStatus?> pwaStatus();

  /// Asks the browser to fetch `sw.js` again. True if a new worker was
  /// found; it serves the new build from the next start on.
  Future<bool> checkForUpdate();

  /// Deletes the offline caches and unregisters the worker. The app's data
  /// (database) stays. Call [reload] afterwards to fetch everything anew.
  Future<void> clearOfflineCache();

  /// Clears the page's local and session storage (web). The database is
  /// emptied separately (see `AppReset`).
  Future<void> clearPageStorage();

  /// Whether the device has a network connection (always true off the web).
  /// Without one the offline cache must stay: it could not be refilled.
  bool get online;

  /// Reloads the page (web only; a no-op elsewhere).
  void reload();

  /// Memory in use: the JS heap in Chromium browsers, the resident set
  /// size of the process elsewhere. `null` where it cannot be read.
  int? memoryBytes();

  /// Size of the database file; `null` on the web.
  Future<int?> databaseBytes();

  /// Milliseconds since the page started loading (web); `null` elsewhere.
  double? pageClockMs();
}

/// The [DevTools] of the running platform.
DevTools platformDevTools() => platform.createDevTools();

/// The app's [DevTools]; tests override it.
final devToolsProvider = Provider<DevTools>((ref) => platformDevTools());
