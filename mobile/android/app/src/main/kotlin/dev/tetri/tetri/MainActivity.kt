package dev.tetri.tetri

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.Semaphore
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec

class MainActivity : FlutterFragmentActivity() {
    private val pinExecutor = Executors.newSingleThreadExecutor()
    private val pinPermit = Semaphore(1)
    private val mainHandler = Handler(Looper.getMainLooper())

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.tetri/pin")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "defaultAlgorithm" -> result.success(
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            "pbkdf2-sha256"
                        } else {
                            "pbkdf2-sha1"
                        }
                    )
                    "derive" -> derivePin(call.arguments, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun derivePin(arguments: Any?, result: MethodChannel.Result) {
        val values = arguments as? Map<*, *>
        val pin = values?.get("pin") as? String
        val suppliedSalt = values?.get("salt") as? ByteArray
        val algorithm = values?.get("algorithm") as? String
        if (values?.size != 3 || pin == null || pin.length != 4 ||
            !pin.all { it in '0'..'9' } || suppliedSalt == null || suppliedSalt.size != 16 ||
            (algorithm != "pbkdf2-sha256" && algorithm != "pbkdf2-sha1")
        ) {
            result.error("pin_invalid_input", "PIN verification is unavailable.", null)
            return
        }
        if (algorithm == "pbkdf2-sha256" && Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.error("pin_unavailable", "PIN verification is unavailable.", null)
            return
        }
        // Fixed work factors and one active request bound native work and memory.
        if (!pinPermit.tryAcquire()) {
            result.error("pin_busy", "PIN verification is already running.", null)
            return
        }
        val password = pin.toCharArray()
        val salt = suppliedSalt.copyOf()
        val factoryName = if (algorithm == "pbkdf2-sha256") {
            "PBKDF2WithHmacSHA256"
        } else {
            "PBKDF2WithHmacSHA1"
        }
        val iterations = if (algorithm == "pbkdf2-sha256") 600_000 else 1_400_000
        try {
            pinExecutor.execute {
                val spec = PBEKeySpec(password, salt, iterations, 256)
                try {
                    val derived = SecretKeyFactory.getInstance(factoryName).generateSecret(spec).encoded
                    if (derived.size != 32) throw IllegalStateException()
                    mainHandler.post { result.success(derived) }
                } catch (_: Exception) {
                    mainHandler.post {
                        result.error("pin_unavailable", "PIN verification is unavailable.", null)
                    }
                } finally {
                    spec.clearPassword()
                    password.fill('\u0000')
                    salt.fill(0)
                    pinPermit.release()
                }
            }
        } catch (_: RejectedExecutionException) {
            password.fill('\u0000')
            salt.fill(0)
            pinPermit.release()
            result.error("pin_unavailable", "PIN verification is unavailable.", null)
        }
    }

    override fun onDestroy() {
        pinExecutor.shutdown()
        super.onDestroy()
    }
}
