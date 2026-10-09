package com.example.mluvici_kalkulacka

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * DEBUG/TEMPORARY only. Dumps the expression semantics node and probes the
 * Android accessibility actions that TalkBack would use for cursor movement.
 *
 * This service is declared only by the debug manifest. It does not modify the
 * Flutter semantics tree or add any application UI.
 */
class AccessibilityDiagnosticsService : AccessibilityService() {
    private val handler = Handler(Looper.getMainLooper())
    private var probeIssued = false

    override fun onServiceConnected() {
        super.onServiceConnected()
        serviceInfo = serviceInfo.apply {
            eventTypes = AccessibilityEvent.TYPE_VIEW_ACCESSIBILITY_FOCUSED or
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                AccessibilityEvent.TYPE_VIEW_TEXT_SELECTION_CHANGED or
                AccessibilityEvent.TYPE_VIEW_FOCUSED or
                AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = flags or AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            notificationTimeout = 100
        }
        log("service connected; probeIssued=$probeIssued")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.packageName?.toString() != TARGET_PACKAGE) return

        val node = findExpressionNode(rootInActiveWindow) ?: return
        log("event=${eventTypeName(event.eventType)} source=${event.source != null}")
        dumpNode("event", node)

        if (event.eventType == AccessibilityEvent.TYPE_VIEW_ACCESSIBILITY_FOCUSED && !probeIssued) {
            probeIssued = true
            scheduleProbe()
        }
    }

    override fun onInterrupt() {
        log("service interrupted")
    }

    private fun scheduleProbe() {
        val steps = listOf(
            ProbeStep(
                "ACTION_NEXT_AT_MOVEMENT_GRANULARITY",
                AccessibilityNodeInfo.ACTION_NEXT_AT_MOVEMENT_GRANULARITY,
                Bundle().apply {
                    putInt(
                        AccessibilityNodeInfo.ACTION_ARGUMENT_MOVEMENT_GRANULARITY_INT,
                        AccessibilityNodeInfo.MOVEMENT_GRANULARITY_CHARACTER,
                    )
                    putBoolean(
                        AccessibilityNodeInfo.ACTION_ARGUMENT_EXTEND_SELECTION_BOOLEAN,
                        false,
                    )
                },
            ),
            ProbeStep(
                "ACTION_PREVIOUS_AT_MOVEMENT_GRANULARITY",
                AccessibilityNodeInfo.ACTION_PREVIOUS_AT_MOVEMENT_GRANULARITY,
                Bundle().apply {
                    putInt(
                        AccessibilityNodeInfo.ACTION_ARGUMENT_MOVEMENT_GRANULARITY_INT,
                        AccessibilityNodeInfo.MOVEMENT_GRANULARITY_CHARACTER,
                    )
                    putBoolean(
                        AccessibilityNodeInfo.ACTION_ARGUMENT_EXTEND_SELECTION_BOOLEAN,
                        false,
                    )
                },
            ),
            ProbeStep(
                "ACTION_SET_SELECTION",
                AccessibilityNodeInfo.ACTION_SET_SELECTION,
                Bundle().apply {
                    putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT, 0)
                    putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT, 0)
                },
            ),
        )

        steps.forEachIndexed { index, step ->
            handler.postDelayed({ runProbeStep(step) }, index * PROBE_DELAY_MS)
        }
    }

    private fun runProbeStep(step: ProbeStep) {
        val beforeNode = findExpressionNode(rootInActiveWindow)
        if (beforeNode == null) {
            log("probe action=${step.name} node unavailable")
            return
        }

        val before = selectionOf(beforeNode)
        log("probe action=${step.name} args=${bundleToString(step.arguments)} before=$before")
        val result = beforeNode.performAction(step.action, step.arguments)
        log("probe action=${step.name} performAction=$result")

        handler.postDelayed({
            val afterNode = findExpressionNode(rootInActiveWindow)
            if (afterNode == null) {
                log("probe action=${step.name} after node unavailable")
            } else {
                log("probe action=${step.name} after=${selectionOf(afterNode)}")
                dumpNode("probe-after-${step.name}", afterNode)
            }
        }, RESULT_DELAY_MS)
    }

    private fun findExpressionNode(node: AccessibilityNodeInfo?): AccessibilityNodeInfo? {
        if (node == null) return null
        if (node.packageName?.toString() == TARGET_PACKAGE && isExpressionNode(node)) {
            return node
        }
        for (index in 0 until node.childCount) {
            val found = findExpressionNode(node.getChild(index))
            if (found != null) return found
        }
        return null
    }

    private fun isExpressionNode(node: AccessibilityNodeInfo): Boolean {
        val actionIds = node.actionList.map { it.id }.toSet()
        return AccessibilityNodeInfo.ACTION_NEXT_AT_MOVEMENT_GRANULARITY in actionIds &&
            AccessibilityNodeInfo.ACTION_PREVIOUS_AT_MOVEMENT_GRANULARITY in actionIds &&
            AccessibilityNodeInfo.ACTION_SET_SELECTION in actionIds
    }

    private fun dumpNode(label: String, node: AccessibilityNodeInfo) {
        val actions = node.actionList.joinToString(",") { actionName(it.id) }
        val textSelectable = if (Build.VERSION.SDK_INT >= 33) {
            "${node.isTextSelectable}"
        } else {
            "unavailable(api<33)"
        }
        log(
            "dump=$label " +
                "package=${node.packageName} " +
                "class=${node.className} " +
                "text=${node.text} " +
                "contentDescription=${node.contentDescription} " +
                "editable=${node.isEditable} " +
                "focusable=${node.isFocusable} " +
                "focused=${node.isFocused} " +
                "accessibilityFocused=${node.isAccessibilityFocused} " +
                "textSelectable=$textSelectable " +
                "selection=${selectionOf(node)} " +
                "movementGranularities=${granularitiesName(node.movementGranularities)} " +
                "actions=[$actions]",
        )
    }

    private fun selectionOf(node: AccessibilityNodeInfo): String =
        "${node.textSelectionStart}..${node.textSelectionEnd}"

    private fun bundleToString(bundle: Bundle): String =
        bundle.keySet().joinToString(",", prefix = "{", postfix = "}") { key ->
            "$key=${bundle.get(key)}"
        }

    private fun actionName(id: Int): String = when (id) {
        AccessibilityNodeInfo.ACTION_NEXT_AT_MOVEMENT_GRANULARITY -> "ACTION_NEXT_AT_MOVEMENT_GRANULARITY"
        AccessibilityNodeInfo.ACTION_PREVIOUS_AT_MOVEMENT_GRANULARITY -> "ACTION_PREVIOUS_AT_MOVEMENT_GRANULARITY"
        AccessibilityNodeInfo.ACTION_SET_SELECTION -> "ACTION_SET_SELECTION"
        AccessibilityNodeInfo.ACTION_FOCUS -> "ACTION_FOCUS"
        AccessibilityNodeInfo.ACTION_ACCESSIBILITY_FOCUS -> "ACTION_ACCESSIBILITY_FOCUS"
        AccessibilityNodeInfo.ACTION_CLEAR_ACCESSIBILITY_FOCUS -> "ACTION_CLEAR_ACCESSIBILITY_FOCUS"
        AccessibilityNodeInfo.ACTION_SET_TEXT -> "ACTION_SET_TEXT"
        AccessibilityNodeInfo.ACTION_CLICK -> "ACTION_CLICK"
        AccessibilityNodeInfo.ACTION_LONG_CLICK -> "ACTION_LONG_CLICK"
        AccessibilityNodeInfo.ACTION_SCROLL_FORWARD -> "ACTION_SCROLL_FORWARD"
        AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD -> "ACTION_SCROLL_BACKWARD"
        AccessibilityNodeInfo.ACTION_COPY -> "ACTION_COPY"
        AccessibilityNodeInfo.ACTION_CUT -> "ACTION_CUT"
        AccessibilityNodeInfo.ACTION_PASTE -> "ACTION_PASTE"
        else -> "ACTION_$id"
    }

    private fun granularitiesName(value: Int): String {
        val names = mutableListOf<String>()
        if (value and AccessibilityNodeInfo.MOVEMENT_GRANULARITY_CHARACTER != 0) names += "CHARACTER"
        if (value and AccessibilityNodeInfo.MOVEMENT_GRANULARITY_WORD != 0) names += "WORD"
        if (value and AccessibilityNodeInfo.MOVEMENT_GRANULARITY_LINE != 0) names += "LINE"
        if (value and AccessibilityNodeInfo.MOVEMENT_GRANULARITY_PARAGRAPH != 0) names += "PARAGRAPH"
        if (value and AccessibilityNodeInfo.MOVEMENT_GRANULARITY_PAGE != 0) names += "PAGE"
        return "$value(${names.joinToString("|")})"
    }

    private fun eventTypeName(type: Int): String = when (type) {
        AccessibilityEvent.TYPE_VIEW_ACCESSIBILITY_FOCUSED -> "TYPE_VIEW_ACCESSIBILITY_FOCUSED"
        AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> "TYPE_WINDOW_CONTENT_CHANGED"
        AccessibilityEvent.TYPE_VIEW_TEXT_SELECTION_CHANGED -> "TYPE_VIEW_TEXT_SELECTION_CHANGED"
        AccessibilityEvent.TYPE_VIEW_FOCUSED -> "TYPE_VIEW_FOCUSED"
        AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> "TYPE_WINDOW_STATE_CHANGED"
        else -> "TYPE_$type"
    }

    private fun log(message: String) {
        Log.i(TAG, message)
    }

    private data class ProbeStep(
        val name: String,
        val action: Int,
        val arguments: Bundle,
    )

    companion object {
        private const val TAG = "MluviciA11yDiag"
        private const val TARGET_PACKAGE = "com.example.mluvici_kalkulacka"
        private const val PROBE_DELAY_MS = 700L
        private const val RESULT_DELAY_MS = 250L
    }
}
