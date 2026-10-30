package io.github.biagioscaglia.navia

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
    }
}
