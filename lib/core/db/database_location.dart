import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where the database file lives, and the one-time move out of the
/// documents directory.
///
/// The documents directory is the wrong place for a private database: on
/// Windows it is usually synchronised by OneDrive, on iOS / macOS it is the
/// user-visible, iCloud-synchronised "Documents" folder. The database
/// therefore lives in the application-support directory, which is private
/// to the app on every platform.
///
/// Earlier versions created the file in the documents directory;
/// [resolveDatabasePath] moves it (with its `-wal` / `-shm` / `-journal`
/// side files) on the first start after the update, so nothing is lost.
abstract final class DatabaseLocation {
  /// File name of the database inside its directory.
  static String fileName(String name) => '$name.sqlite';

  /// Side files SQLite keeps next to the database. `-wal` holds committed
  /// data that is not yet in the main file and MUST travel with it.
  static const List<String> sideFileSuffixes = ['-wal', '-shm', '-journal'];

  /// The path to open: the file in the application-support directory,
  /// after moving a database of an older version there.
  ///
  /// Never throws for a failed move: when the old file cannot be moved it
  /// keeps being used where it is (no data loss beats the better place),
  /// and the move is tried again on the next start.
  static Future<String> resolveDatabasePath(String name) async {
    final support = await getApplicationSupportDirectory();
    Directory? documents;
    try {
      documents = await getApplicationDocumentsDirectory();
    } catch (_) {
      // No documents directory on this platform: nothing to migrate.
    }
    return migrate(
      fileName: fileName(name),
      newDirectory: support,
      oldDirectory: documents,
    );
  }

  /// Moves `fileName` (and its side files) from [oldDirectory] to
  /// [newDirectory] when the new location has no database yet, and returns
  /// the path to open.
  ///
  /// * A database that already exists at the new location is never
  ///   overwritten; an old file is then left alone.
  /// * The side files move first and the main file last, so an interrupted
  ///   move is simply continued on the next start.
  /// * Works across volumes (copy to a temporary name, rename, delete).
  static Future<String> migrate({
    required String fileName,
    required Directory newDirectory,
    required Directory? oldDirectory,
  }) async {
    final newPath = p.join(newDirectory.path, fileName);
    if (oldDirectory == null ||
        p.equals(oldDirectory.path, newDirectory.path)) {
      return newPath;
    }
    final oldPath = p.join(oldDirectory.path, fileName);
    final oldFile = File(oldPath);
    try {
      if (File(newPath).existsSync() || !oldFile.existsSync()) return newPath;
      await newDirectory.create(recursive: true);
      for (final suffix in sideFileSuffixes) {
        final side = File('$oldPath$suffix');
        if (side.existsSync()) await _move(side, '$newPath$suffix');
      }
      await _move(oldFile, newPath);
      return newPath;
    } catch (_) {
      // Keep working with whatever is complete. The main file moves last:
      // while it is still at the old place, bring the side files back to it.
      if (File(newPath).existsSync()) return newPath;
      if (!oldFile.existsSync()) return newPath;
      for (final suffix in sideFileSuffixes) {
        final moved = File('$newPath$suffix');
        try {
          if (moved.existsSync()) await _move(moved, '$oldPath$suffix');
        } catch (_) {
          // Best effort.
        }
      }
      return oldPath;
    }
  }

  static Future<void> _move(File source, String targetPath) async {
    final target = File(targetPath);
    if (target.existsSync()) await target.delete();
    try {
      await source.rename(targetPath);
      return;
    } on FileSystemException {
      // Different volume (e.g. documents on D:, app data on C:).
    }
    final temporary = File('$targetPath.migrating');
    if (temporary.existsSync()) await temporary.delete();
    await source.copy(temporary.path);
    await temporary.rename(targetPath);
    await source.delete();
  }
}
