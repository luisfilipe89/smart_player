package com.example.sportappdenbosch

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "app.sportappdenbosch/intent"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "launchUrl") {
                val url = call.argument<String>("url")
                if (url != null) {
                    try {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("LAUNCH_ERROR", "Failed to launch URL: ${e.message}", null)
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "URL is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
