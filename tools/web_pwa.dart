// Fills in the offline service worker of a web build (web/sw.js).
//
//   flutter build web --release --no-web-resources-cdn
//   dart run tools/web_pwa.dart            # default: build/web
//
// Writes into build/web/sw.js: a version (hash over the app files, so every
// change yields a new worker and cache), the engine revision (CanvasKit
// cache) and the list of files to precache. CanvasKit is left out of the
// list; the page reports the variant it loaded (see web/index.html).
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final root = Directory(args.isEmpty ? 'build/web' : args.first);
  final worker = File('${root.path}/sw.js');
  final bootstrap = File('${root.path}/flutter_bootstrap.js');
  if (!worker.existsSync() || !bootstrap.existsSync()) {
    stderr.writeln('No web build in ${root.path} (flutter build web first).');
    exit(1);
  }

  final engine = RegExp(
    r'"engineRevision":"([0-9a-f]+)"',
  ).firstMatch(bootstrap.readAsStringSync())?.group(1);
  if (engine == null) {
    stderr.writeln('Engine revision not found in flutter_bootstrap.js.');
    exit(1);
  }

  final files = <String>[];
  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File) continue;
    final path = entity.path
        .substring(root.path.length + 1)
        .replaceAll(r'\', '/');
    if (_skip(path)) continue;
    files.add(path);
  }
  files.sort();

  var hash = _fnvOffset;
  for (final path in files) {
    hash = _fnv(hash, utf8.encode(path));
    hash = _fnv(hash, File('${root.path}/$path').readAsBytesSync());
  }
  // Two halves: a 64-bit int with the top bit set would print with a minus
  // sign (toUnsigned(64) changes nothing on the VM).
  String half(int value) => value.toRadixString(16).padLeft(8, '0');
  final version = half(hash >>> 32) + half(hash & 0xffffffff);

  // The app shell is cached under the scope URL ('./'), not 'index.html'.
  final core = ['./', ...files.where((p) => p != 'index.html')];
  final source = worker
      .readAsStringSync()
      .replaceFirst('__TIKKY_VERSION__', version)
      .replaceFirst('__TIKKY_ENGINE__', engine)
      .replaceFirst(
        '/* __TIKKY_CORE__ */',
        '${core.map((p) => "\n  '$p',").join()}\n',
      );
  if (source.contains('__TIKKY_')) {
    stderr.writeln('sw.js: placeholder not replaced.');
    exit(1);
  }
  worker.writeAsStringSync(source);
  stdout.writeln(
    'sw.js: version $version, ${core.length} files, engine '
    '${engine.substring(0, 10)}.',
  );
}

bool _skip(String path) =>
    path == 'sw.js' ||
    path == 'flutter_service_worker.js' ||
    path == '.last_build_id' ||
    path == '.nojekyll' ||
    path.startsWith('canvaskit/') ||
    path.endsWith('.map') ||
    path.endsWith('.symbols');

const _fnvOffset = 0xcbf29ce484222325;
const _fnvPrime = 0x100000001b3;

/// FNV-1a, 64 bit (wraps on the Dart VM's 64-bit ints).
int _fnv(int hash, List<int> bytes) {
  var h = hash;
  for (final b in bytes) {
    h ^= b;
    h *= _fnvPrime;
  }
  return h;
}
