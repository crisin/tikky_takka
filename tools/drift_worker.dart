// Source of web/drift_worker.js (the drift database worker for the web).
// Rebuild after a drift update:
//   dart compile js -O4 -o web/drift_worker.js tools/drift_worker.dart
import 'package:drift/wasm.dart';

void main() => WasmDatabase.workerMainForOpen();
