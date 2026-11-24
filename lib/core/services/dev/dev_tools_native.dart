import 'dart:io';

import '../../db/app_database.dart';
import '../../db/database_location.dart';
import 'dev_tools.dart';

DevTools createDevTools() => const NativeDevTools();

/// Android, iOS, macOS, Windows: no service worker, no caches.
class NativeDevTools implements DevTools {
  const NativeDevTools();

  @override
  bool get isWeb => false;

  @override
  Future<PwaStatus?> pwaStatus() async => null;

  @override
  Future<bool> checkForUpdate() async => false;

  @override
  Future<void> clearOfflineCache() async {}

  @override
  Future<void> clearPageStorage() async {}

  @override
  bool get online => true;

  @override
  void reload() {}

  @override
  int? memoryBytes() {
    try {
      return ProcessInfo.currentRss;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int?> databaseBytes() async {
    try {
      final path = await DatabaseLocation.resolveDatabasePath(
        AppDatabase.fileBaseName,
      );
      var bytes = 0;
      for (final suffix in ['', ...DatabaseLocation.sideFileSuffixes]) {
        final file = File('$path$suffix');
        if (file.existsSync()) bytes += file.lengthSync();
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  double? pageClockMs() => null;
}
