package com.example.mluvici_kalkulacka

import android.content.Context
import android.content.Intent
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.mluvici_kalkulacka/accessibility"
    private val TTS_SETTINGS_CHANNEL = "com.example.mluvici_kalkulacka/tts_settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "isTalkBackEnabled") {
                val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
                result.success(am.isTouchExplorationEnabled)
            } else {
                result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TTS_SETTINGS_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openTtsSettings") {
                val intent = Intent("android.settings.TEXT_TO_SPEECH_SETTINGS")
                startActivity(intent)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }
}
