/// Opens the app database on the current platform: a SQLite file on
/// Android / iOS / macOS / Windows, SQLite-WASM (OPFS / IndexedDB) on the web.
library;

export 'connection_native.dart'
    if (dart.library.js_interop) 'connection_web.dart';
