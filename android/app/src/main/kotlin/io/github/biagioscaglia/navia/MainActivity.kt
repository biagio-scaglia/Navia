package io.github.biagioscaglia.navia

import android.content.Intent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.github.biagioscaglia.navia.guidance.GuidanceChannel

class MainActivity : FlutterActivity() {
    private var guidance: GuidanceChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Turn-by-turn guidance in the background: foreground service,
        // ongoing notification and audio ducking.
        guidance = GuidanceChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        // Opens the system share sheet: the user picks the receiving app.
        // No third-party sharing SDK is needed for plain text.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "navia/share")
            .setMethodCallHandler { call, result ->
                if (call.method != "shareText") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val text = call.argument<String>("text")
                if (text.isNullOrBlank()) {
                    result.error("INVALID_TEXT", "Nothing to share", null)
                    return@setMethodCallHandler
                }
                val send = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, text)
                    call.argument<String>("subject")?.let {
                        putExtra(Intent.EXTRA_SUBJECT, it)
                    }
                }
                startActivity(Intent.createChooser(send, null))
                result.success(true)
            }
        // Keeps the screen on during turn-by-turn guidance only.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "navia/screen")
            .setMethodCallHandler { call, result ->
                if (call.method != "keepOn") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (call.argument<Boolean>("enabled") == true) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
                result.success(null)
            }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        guidance?.dispose()
        guidance = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (guidance?.onRequestPermissionsResult(requestCode, grantResults) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}
