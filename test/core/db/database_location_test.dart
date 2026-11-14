import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tikky_takka/core/db/database_location.dart';

/// The one-time move of the database out of the (OS-synchronised)
/// documents directory into the private application-support directory.
void main() {
  late Directory root;
  late Directory documents;
  late Directory support;
  const name = 'tikky_takka.sqlite';

  setUp(() {
    root = Directory.systemTemp.createTempSync('tikky_db_location_');
    documents = Directory(p.join(root.path, 'Documents'))..createSync();
    // Deliberately missing: created on demand.
    support = Directory(p.join(root.path, 'AppData', 'tikky'));
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  File oldFile([String suffix = '']) =>
      File(p.join(documents.path, '$name$suffix'));
  File newFile([String suffix = '']) =>
      File(p.join(support.path, '$name$suffix'));

  Future<String> migrate() => DatabaseLocation.migrate(
    fileName: name,
    newDirectory: support,
    oldDirectory: documents,
  );

  test('the file name follows drift_flutter', () {
    expect(DatabaseLocation.fileName('tikky_takka'), name);
  });

  test('a fresh install opens the database in application support', () async {
    expect(await migrate(), newFile().path);
    expect(oldFile().existsSync(), isFalse);
    expect(newFile().existsSync(), isFalse, reason: 'drift creates it');
  });

  test('an existing database moves with its -wal and -shm files, content '
      'intact', () async {
    oldFile().writeAsStringSync('main');
    oldFile('-wal').writeAsStringSync('wal');
    oldFile('-shm').writeAsStringSync('shm');
    // Unrelated files of the user stay where they are.
    final other = File(p.join(documents.path, 'brief.txt'))
      ..writeAsStringSync('x');

    expect(await migrate(), newFile().path);

    expect(newFile().readAsStringSync(), 'main');
    expect(newFile('-wal').readAsStringSync(), 'wal');
    expect(newFile('-shm').readAsStringSync(), 'shm');
    expect(oldFile().existsSync(), isFalse);
    expect(oldFile('-wal').existsSync(), isFalse);
    expect(oldFile('-shm').existsSync(), isFalse);
    expect(other.existsSync(), isTrue);
    expect(newFile('.migrating').existsSync(), isFalse);
  });

  test('a rollback journal moves too; missing side files are no problem', () async {
    oldFile().writeAsStringSync('main');
    oldFile('-journal').writeAsStringSync('journal');
    expect(await migrate(), newFile().path);
    expect(newFile('-journal').readAsStringSync(), 'journal');
    expect(newFile('-wal').existsSync(), isFalse);
  });

  test('runs once: afterwards the new place is simply used', () async {
    oldFile().writeAsStringSync('main');
    await migrate();
    newFile().writeAsStringSync('changed by the app');
    expect(await migrate(), newFile().path);
    expect(newFile().readAsStringSync(), 'changed by the app');
  });

  test('a database at the new place is never overwritten by an old file', () async {
    support.createSync(recursive: true);
    newFile().writeAsStringSync('current');
    oldFile().writeAsStringSync('stale');
    oldFile('-wal').writeAsStringSync('stale wal');

    expect(await migrate(), newFile().path);

    expect(newFile().readAsStringSync(), 'current');
    expect(newFile('-wal').existsSync(), isFalse);
    // Left alone, not deleted.
    expect(oldFile().readAsStringSync(), 'stale');
  });

  test('an interrupted move (side files already over, main file not) is '
      'continued', () async {
    support.createSync(recursive: true);
    newFile('-wal').writeAsStringSync('wal');
    oldFile().writeAsStringSync('main');

    expect(await migrate(), newFile().path);

    expect(newFile().readAsStringSync(), 'main');
    expect(newFile('-wal').readAsStringSync(), 'wal');
    expect(oldFile().existsSync(), isFalse);
  });

  test('when the move is impossible the old database keeps being used', () async {
    oldFile().writeAsStringSync('main');
    oldFile('-wal').writeAsStringSync('wal');
    // A FILE where the new directory would have to be created.
    Directory(p.dirname(support.path)).createSync(recursive: true);
    File(support.path).writeAsStringSync('in the way');

    expect(await migrate(), oldFile().path);

    expect(oldFile().readAsStringSync(), 'main');
    expect(oldFile('-wal').readAsStringSync(), 'wal');
  });

  test('same directory or no documents directory: nothing to do', () async {
    oldFile().writeAsStringSync('main');
    expect(
      await DatabaseLocation.migrate(
        fileName: name,
        newDirectory: documents,
        oldDirectory: documents,
      ),
      oldFile().path,
    );
    expect(
      await DatabaseLocation.migrate(
        fileName: name,
        newDirectory: support,
        oldDirectory: null,
      ),
      newFile().path,
    );
    expect(oldFile().readAsStringSync(), 'main');
  });
}
