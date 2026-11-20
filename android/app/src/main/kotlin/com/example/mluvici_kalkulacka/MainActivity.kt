package com.example.mluvici_kalkulacka

import android.content.Context
import android.content.Intent
import android.content.UriPermission
import android.net.Uri
import android.provider.DocumentsContract
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.mluvici_kalkulacka/accessibility"
    private val ACCESSIBILITY_EVENTS_CHANNEL =
        "com.example.mluvici_kalkulacka/accessibility_events"
    private val TTS_SETTINGS_CHANNEL = "com.example.mluvici_kalkulacka/tts_settings"
    private val AUTO_IMPORT_CHANNEL = "com.example.mluvici_kalkulacka/auto_import"
    private val mainHandler = Handler(Looper.getMainLooper())

    private var accessibilityManager: AccessibilityManager? = null
    private var touchExplorationListener:
        AccessibilityManager.TouchExplorationStateChangeListener? = null
    private var accessibilityEventSink: EventChannel.EventSink? = null
    private var accessibilityListenerGeneration = 0

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
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ACCESSIBILITY_EVENTS_CHANNEL,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                stopAccessibilityUpdates()

                val manager =
                    getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
                val generation = accessibilityListenerGeneration
                accessibilityManager = manager
                accessibilityEventSink = events

                val listener =
                    AccessibilityManager.TouchExplorationStateChangeListener { enabled ->
                        mainHandler.post {
                            if (generation == accessibilityListenerGeneration &&
                                accessibilityEventSink === events
                            ) {
                                events.success(enabled)
                            }
                        }
                    }
                touchExplorationListener = listener
                manager.addTouchExplorationStateChangeListener(listener)
                events.success(manager.isTouchExplorationEnabled)
            }

            override fun onCancel(arguments: Any?) {
                stopAccessibilityUpdates()
            }
        })
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TTS_SETTINGS_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openTtsSettings") {
                val intent = Intent("android.settings.TEXT_TO_SPEECH_SETTINGS")
                startActivity(intent)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUTO_IMPORT_CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "takePersistablePermission" -> {
                        val uri = Uri.parse(call.argument<String>("treeUri"))
                        contentResolver.takePersistableUriPermission(
                            uri,
                            Intent.FLAG_GRANT_READ_URI_PERMISSION,
                        )
                        result.success(true)
                    }
                    "readTreeFile" -> {
                        val treeUri = Uri.parse(call.argument<String>("treeUri"))
                        val fileName = call.argument<String>("fileName")
                            ?: throw IllegalArgumentException("Missing fileName")
                        val treeId = DocumentsContract.getTreeDocumentId(treeUri)
                        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, treeId)
                        var fileUri: Uri? = null
                        contentResolver.query(
                            childrenUri,
                            arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME),
                            null,
                            null,
                            null,
                        )?.use { cursor ->
                            val idIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
                            val nameIndex = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                            while (cursor.moveToNext()) {
                                if (nameIndex >= 0 && cursor.getString(nameIndex) == fileName) {
                                    fileUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, cursor.getString(idIndex))
                                    break
                                }
                            }
                        }
                        if (fileUri == null) throw IllegalStateException("File not found")
                        val bytes = contentResolver.openInputStream(fileUri!!)?.use { it.readBytes() }
                            ?: throw IllegalStateException("Cannot read file")
                        result.success(bytes.toList())
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("AUTO_IMPORT_ERROR", error.message, null)
            }
        }
    }

    override fun onDestroy() {
        stopAccessibilityUpdates()
        super.onDestroy()
    }

    private fun stopAccessibilityUpdates() {
        accessibilityListenerGeneration++
        accessibilityEventSink = null

        val manager = accessibilityManager
        val listener = touchExplorationListener
        if (manager != null && listener != null) {
            manager.removeTouchExplorationStateChangeListener(listener)
        }
        touchExplorationListener = null
        accessibilityManager = null
    }
}
