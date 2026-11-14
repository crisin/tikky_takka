package dev.tikkytakka.tikky_takka

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// local_auth (app lock) shows its prompt through a fragment and therefore
// needs a FragmentActivity.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // App lock: FLAG_SECURE keeps the app out of screenshots and shows a
        // blank card in the recent-apps overview. Driven from Dart
        // (lib/core/services/screen_security.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tikky_takka/window")
            .setMethodCallHandler { call, result ->
                if (call.method == "setSecure") {
                    if (call.arguments == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
