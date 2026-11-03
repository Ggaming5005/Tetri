package dev.tetri.tetri

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.tetri/platform")
            .setMethodCallHandler { call, result ->
                if (call.method == "openRepository") {
                    try {
                        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://github.com/Ggaming5005/Tetri")))
                        result.success(null)
                    } catch (error: android.content.ActivityNotFoundException) {
                        result.error("browser_unavailable", "No browser is available.", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
