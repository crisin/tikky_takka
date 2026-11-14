import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One entry of the [DiagnosticsLog].
@immutable
final class DiagnosticsEntry {
  const DiagnosticsEntry({
    required this.at,
    required this.source,
    required this.message,
    this.stack,
  });

  /// Wall time (UTC milliseconds).
  final int at;

  /// Where it came from, e.g. "Flutter", "Alarme".
  final String source;
  final String message;
  final String? stack;
}

/// The last errors of this app run, in memory only (nothing is written to
/// disk, nothing leaves the device unless the user copies it).
///
/// On a phone there is no debug console, so the diagnostics page in the
/// settings shows this list. Fed by the global error handlers in
/// `main.dart` and by services that swallow platform errors.
class DiagnosticsLog extends ChangeNotifier {
  DiagnosticsLog({this.capacity = 200, int Function()? nowMs})
    : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// The log of the running app.
  static final instance = DiagnosticsLog();

  final int capacity;
  final int Function() _nowMs;
  final ListQueue<DiagnosticsEntry> _entries = ListQueue();

  /// Oldest first.
  List<DiagnosticsEntry> get entries => List.unmodifiable(_entries);

  void record(String source, Object error, [StackTrace? stack]) {
    _entries.addLast(
      DiagnosticsEntry(
        at: _nowMs(),
        source: source,
        message: '$error',
        stack: stack?.toString(),
      ),
    );
    while (_entries.length > capacity) {
      _entries.removeFirst();
    }
    notifyListeners();
  }

  /// A handler for `onError` callbacks of services.
  void Function(Object error, StackTrace stack) handlerFor(String source) =>
      (error, stack) => record(source, error, stack);

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}

/// The app's [DiagnosticsLog]; tests can override it with a fresh one.
final diagnosticsLogProvider = Provider<DiagnosticsLog>(
  (ref) => DiagnosticsLog.instance,
);
