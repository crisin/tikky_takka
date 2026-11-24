import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'dev_tools.dart';

DevTools createDevTools() => const WebDevTools();

/// The browser side: service worker, Cache Storage, storage estimate.
///
/// `navigator.serviceWorker` and `caches` do not exist in an insecure
/// context (plain http on a host other than localhost), so every access is
/// guarded.
class WebDevTools implements DevTools {
  const WebDevTools();

  @override
  bool get isWeb => true;

  bool get _hasWorkers => web.window.navigator.has('serviceWorker');
  bool get _hasCaches => web.window.has('caches');

  Future<web.ServiceWorkerRegistration?> _registration() async {
    if (!_hasWorkers) return null;
    try {
      return await web.window.navigator.serviceWorker.getRegistration().toDart;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PwaStatus?> pwaStatus() async {
    final nav = web.window.navigator;
    final registration = await _registration();
    final worker =
        registration?.active ??
        registration?.waiting ??
        registration?.installing;

    bool? persisted;
    int? usage;
    int? quota;
    if (nav.has('storage')) {
      try {
        persisted = (await nav.storage.persisted().toDart).toDart;
        final estimate = await nav.storage.estimate().toDart;
        usage = estimate.usage;
        quota = estimate.quota;
      } catch (_) {
        // Not available (private mode, old browser).
      }
    }

    return PwaStatus(
      workerSupported: _hasWorkers,
      workerState: worker?.state,
      controlled: _hasWorkers && nav.serviceWorker.controller != null,
      installed: web.window.matchMedia('(display-mode: standalone)').matches,
      online: nav.onLine,
      persisted: persisted,
      usageBytes: usage,
      quotaBytes: quota,
      caches: await _caches(),
    );
  }

  Future<List<CacheInfo>> _caches() async {
    if (!_hasCaches) return const [];
    final base = Uri.base.resolve('./').toString();
    final result = <CacheInfo>[];
    try {
      final names = (await web.window.caches.keys().toDart).toDart;
      for (final jsName in names) {
        final name = jsName.toDart;
        final cache = await web.window.caches.open(name).toDart;
        final entries = <CacheEntryInfo>[];
        for (final request in (await cache.keys().toDart).toDart) {
          final response = await cache.match(request).toDart;
          // The stored body, not Content-Length: that is the transfer size
          // and smaller when the server compresses.
          final bytes = response == null
              ? 0
              : (await response.blob().toDart).size;
          final url = request.url;
          final path = url.startsWith(base) ? url.substring(base.length) : url;
          entries.add(
            CacheEntryInfo(path: path.isEmpty ? './' : path, bytes: bytes),
          );
        }
        entries.sort((a, b) => b.bytes.compareTo(a.bytes));
        result.add(CacheInfo(name: name, entries: entries));
      }
    } catch (_) {
      // Cache Storage blocked: show what was read so far.
    }
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  @override
  Future<bool> checkForUpdate() async {
    final registration = await _registration();
    if (registration == null) return false;
    final before = registration.active;
    await registration.update().toDart;
    // sw.js skips waiting, so a new worker may already be the active one.
    return registration.installing != null ||
        registration.waiting != null ||
        registration.active != before;
  }

  @override
  Future<void> clearOfflineCache() async {
    if (_hasCaches) {
      final names = (await web.window.caches.keys().toDart).toDart;
      for (final name in names) {
        if (name.toDart.startsWith(PwaStatus.appCachePrefix)) {
          await web.window.caches.delete(name.toDart).toDart;
        }
      }
    }
    if (_hasWorkers) {
      final registrations =
          (await web.window.navigator.serviceWorker.getRegistrations().toDart)
              .toDart;
      for (final registration in registrations) {
        await registration.unregister().toDart;
      }
    }
  }

  @override
  Future<void> clearPageStorage() async {
    try {
      web.window.localStorage.clear();
      web.window.sessionStorage.clear();
    } catch (_) {
      // Storage blocked: nothing to clear.
    }
  }

  @override
  bool get online => web.window.navigator.onLine;

  @override
  void reload() => web.window.location.reload();

  @override
  int? memoryBytes() {
    // Non-standard, Chromium only.
    final memory = web.window.performance.getProperty<JSObject?>('memory'.toJS);
    final used = memory?.getProperty<JSNumber?>('usedJSHeapSize'.toJS);
    return used?.toDartDouble.round();
  }

  @override
  Future<int?> databaseBytes() async => null;

  @override
  double? pageClockMs() => web.window.performance.now();
}
