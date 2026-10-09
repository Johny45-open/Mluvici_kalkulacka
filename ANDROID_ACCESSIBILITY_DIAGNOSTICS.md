# Android AccessibilityNodeInfo diagnostics (DEBUG/TEMPORARY)

This diagnostic service is included only in the debug APK. It does not change
the Flutter semantics bridge, calculator UI, cursor state, focus nodes, or TTS.

## Build and install

From the repository root:

```powershell
flutter build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

## Enable the service

1. Open Android Settings.
2. Open Accessibility.
3. Open the installed-services list.
4. Enable **Accessibility diagnostics (DEBUG/TEMPORARY)**.
5. Confirm the Android warning dialog.

The exact settings labels vary by Android version and manufacturer.

## Capture the expression node

1. Start `Mluvici_kalkulacka`.
2. Put `12+3` in the expression display.
3. Move accessibility focus to the display.
4. Inspect Logcat with:

```powershell
adb logcat -s MluviciA11yDiag:I
```

The service identifies the expression node by the three advertised actions:
`ACTION_NEXT_AT_MOVEMENT_GRANULARITY`,
`ACTION_PREVIOUS_AT_MOVEMENT_GRANULARITY`, and `ACTION_SET_SELECTION`.

The first accessibility-focus event triggers one diagnostic probe for:

- next character,
- previous character,
- selection `0..0`.

Each probe logs arguments, `performAction()` result, selection before/after,
and subsequent node dumps. Selection-change events are logged separately.

## Fields to record

Record at least `className`, `text`, `isEditable`, `isFocusable`, `isFocused`,
`isAccessibilityFocused`, `isTextSelectable` on API 33+, selection bounds,
movement granularities, and the complete action list.

The service intentionally does not infer whether TalkBack will expose cursor
navigation. Use the direct action results first, then repeat with TalkBack.
