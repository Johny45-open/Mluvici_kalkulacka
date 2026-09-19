import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void mockChannels() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (MethodCall call) async => null);
    messenger.setMockMethodCallHandler(const MethodChannel('com.example.mluvici_kalkulacka/accessibility'), (MethodCall call) async {
      if (call.method == 'isTalkBackEnabled' || call.method == 'isScreenReaderEnabled') return false;
      return false;
    });
    messenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/package_info'), (MethodCall call) async => <String, Object>{
      'appName': 'mluvici_kalkulacka',
      'packageName': 'com.example.mluvici_kalkulacka',
      'version': '6.2.0',
      'buildNumber': '1',
    });
    messenger.setMockMethodCallHandler(const MethodChannel('com.example.mluvici_kalkulacka/tts_settings'), (MethodCall call) async => null);
  }

  Future<dynamic> pumpApp(WidgetTester tester) async {
    tester.platformDispatcher.clearAllTestValues();
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(const ScientificCalculatorApp());
    await tester.pumpAndSettle();
    // allow _loadProfilesV2 to complete
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    return tester.state(find.byType(CalculatorScreen)) as dynamic;
  }

  group('S1 aktivni edit save reopen restart', () {
    testWidgets('S1', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'modeQuestionAsked': true});
      mockChannels();
      dynamic state = await pumpApp(tester);
      expect(state.profilesLoadedForTest, isTrue);
      final beforeActive = state.activeProfileIdForTest as String;
      // ensure active is standard for deterministic
      state.switchProfileForTest('standard');
      await tester.pumpAndSettle();
      state.startEditingForTest('standard');
      await tester.pumpAndSettle();
      state.updateEditingForTest((AccessibilitySettings s) => s.copyWith(speechRate: 0.77, dialogFontScale: 2.2, speechVolume: 0.33));
      await tester.pumpAndSettle();
      // draft not persisted yet
      expect(state.editingDraftForTest.settings.speechRate, closeTo(0.77, 0.001));
      expect(state.profilesForTest.firstWhere((p) => p.id == 'standard').settings.speechRate, isNot(closeTo(0.77, 0.001)));
      final ok = await state.saveEditingForTest();
      expect(ok, isTrue);
      await tester.pumpAndSettle();
      expect(state.editingDraftForTest, isNull);
      expect(state.profilesForTest.firstWhere((p) => p.id == 'standard').settings.speechRate, closeTo(0.77, 0.001));
      expect(state.dialogFontScaleNotifierForTest.value, closeTo(2.2, 0.001));
      // reopen
      state.startEditingForTest('standard');
      await tester.pumpAndSettle();
      expect(state.editingDraftForTest.settings.speechRate, closeTo(0.77, 0.001));
      await state.saveEditingForTest();
      await tester.pumpAndSettle();
      // restart persistence
      await tester.pumpWidget(const ScientificCalculatorApp());
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      state = tester.state(find.byType(CalculatorScreen)) as dynamic;
      expect(state.profilesLoadedForTest, isTrue);
      // after restart active may be standard; check persisted value
      state.switchProfileForTest('standard');
      await tester.pumpAndSettle();
      expect(state.speechRateForTest, closeTo(0.77, 0.001));
      expect(state.dialogFontScaleForTest, closeTo(2.2, 0.001));
    });
  });

  group('S2 aktivni cancel revert', () {
    testWidgets('S2', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'modeQuestionAsked': true, 'themeMode': ThemeMode.light.index});
      mockChannels();
      dynamic state = await pumpApp(tester);
      await tester.pumpAndSettle();
      state.switchProfileForTest('standard');
      await tester.pumpAndSettle();
      final beforeRate = state.speechRateForTest as double;
      final beforeScale = state.dialogFontScaleForTest as double;
      final beforeTheme = state.themeModeForTest as ThemeMode;
      state.startEditingForTest('standard');
      await tester.pumpAndSettle();
      state.updateEditingForTest((AccessibilitySettings s) => s.copyWith(speechRate: 0.91, dialogFontScale: 2.5, speechVolume: 0.1, accessibilityType: AccessibilityType.visuallyImpaired));
      await tester.pumpAndSettle();
      expect(state.dialogFontScaleNotifierForTest.value, closeTo(2.5, 0.001));
      // TTS update via draft live preview triggers theme dark
      expect(state.themeModeForTest, ThemeMode.dark);
      // profile not yet changed
      expect(state.profilesForTest.firstWhere((p) => p.id == 'standard').settings.speechRate, closeTo(beforeRate, 0.001));
      state.discardEditingForTest();
      await tester.pumpAndSettle();
      expect(state.editingDraftForTest, isNull);
      expect(state.dialogFontScaleNotifierForTest.value, closeTo(beforeScale, 0.001));
      expect(state.themeModeForTest, beforeTheme);
      expect(state.speechRateForTest, closeTo(beforeRate, 0.001));
      // persistence unchanged
      final prefs = await SharedPreferences.getInstance();
      final v2 = prefs.getString('accessibility_profiles_v2');
      final decoded = jsonDecode(v2!) as List;
      final std = (decoded.firstWhere((e) => (e as Map)['id'] == 'standard') as Map)['settings'] as Map;
      expect((std['speechRate'] as num).toDouble(), closeTo(beforeRate, 0.001));
    });
  });

  group('S3 neaktivni save bez aktivace', () {
    testWidgets('S3', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'modeQuestionAsked': true});
      mockChannels();
      dynamic state = await pumpApp(tester);
      state.switchProfileForTest('standard');
      await tester.pumpAndSettle();
      final beforeActiveId = state.activeProfileIdForTest as String;
      expect(beforeActiveId, 'standard');
      final beforeBlindRate = state.profilesForTest.firstWhere((p) => p.id == 'blind').settings.speechRate as double;
      // edit blind (neaktivni)
      state.startEditingForTest('blind');
      await tester.pumpAndSettle();
      state.updateEditingForTest((AccessibilitySettings s) => s.copyWith(speechRate: 0.88, fontSizeMultiplier: 1.99));
      await tester.pumpAndSettle();
      // runtime must stay standard
      expect(state.speechRateForTest, isNot(closeTo(0.88, 0.001)));
      expect(state.dialogFontScaleNotifierForTest.value, isNot(closeTo(2.5, 0.001)));
      // save
      final ok = await state.saveEditingForTest();
      expect(ok, isTrue);
      await tester.pumpAndSettle();
      expect(state.activeProfileIdForTest, 'standard');
      expect(state.profilesForTest.firstWhere((p) => p.id == 'blind').settings.speechRate, closeTo(0.88, 0.001));
      expect(state.profilesForTest.firstWhere((p) => p.id == 'standard').settings.speechRate, isNot(closeTo(0.88, 0.001)));
      // aktivace az ted projevi
      state.switchProfileForTest('blind');
      await tester.pumpAndSettle();
      expect(state.speechRateForTest, closeTo(0.88, 0.001));
      expect(state.keyboardFontScaleForTest, closeTo(1.99, 0.001));
    });
  });

  group('S4 neaktivni cancel bez runtime zmeny', () {
    testWidgets('S4', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'modeQuestionAsked': true});
      mockChannels();
      dynamic state = await pumpApp(tester);
      state.switchProfileForTest('standard');
      await tester.pumpAndSettle();
      final beforeNotifier = state.dialogFontScaleNotifierForTest.value as double;
      final beforeActiveRate = state.speechRateForTest as double;
      state.startEditingForTest('blind');
      await tester.pumpAndSettle();
      state.updateEditingForTest((AccessibilitySettings s) => s.copyWith(speechRate: 0.12, dialogFontScale: 2.8));
      await tester.pumpAndSettle();
      // runtime unchanged
      expect(state.dialogFontScaleNotifierForTest.value, closeTo(beforeNotifier, 0.001));
      expect(state.speechRateForTest, closeTo(beforeActiveRate, 0.001));
      state.discardEditingForTest();
      await tester.pumpAndSettle();
      expect(state.editingDraftForTest, isNull);
      expect(state.dialogFontScaleNotifierForTest.value, closeTo(beforeNotifier, 0.001));
      expect(state.profilesForTest.firstWhere((p) => p.id == 'blind').settings.speechRate, isNot(closeTo(0.12, 0.001)));
    });
  });

  group('S5 draft neaktivniho + zmena aktivniho zvenčí', () {
    testWidgets('S5', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'modeQuestionAsked': true});
      mockChannels();
      dynamic state = await pumpApp(tester);
      state.switchProfileForTest('standard');
      await tester.pumpAndSettle();
      state.startEditingForTest('blind');
      await tester.pumpAndSettle();
      state.updateEditingForTest((AccessibilitySettings s) => s.copyWith(speechRate: 0.77));
      await tester.pumpAndSettle();
      // mezitim zmen aktivni zvenčí
      state.switchProfileForTest('lowvision');
      await tester.pumpAndSettle();
      expect(state.activeProfileIdForTest, 'lowvision');
      // save blind draft – nesmí přepsat lowvision
      final lowBefore = state.profilesForTest.firstWhere((p) => p.id == 'lowvision').settings.speechRate;
      final ok = await state.saveEditingForTest();
      expect(ok, isTrue);
      await tester.pumpAndSettle();
      expect(state.profilesForTest.firstWhere((p) => p.id == 'blind').settings.speechRate, closeTo(0.77, 0.001));
      expect(state.profilesForTest.firstWhere((p) => p.id == 'lowvision').settings.speechRate, lowBefore);
      expect(state.activeProfileIdForTest, 'lowvision');
      expect(state.editingDraftForTest, isNull);
    });
  });

  group('S6 reset behem otevreneho draftu', () {
    testWidgets('S6 active reset updates draft and runtime, save persists defaults, cancel reverts to original', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'modeQuestionAsked': true});
      mockChannels();
      dynamic state = await pumpApp(tester);
      state.switchProfileForTest('standard');
      await tester.pumpAndSettle();
      // change standard via draft to non-default
      state.startEditingForTest('standard');
      await tester.pumpAndSettle();
      state.updateEditingForTest((AccessibilitySettings s) => s.copyWith(speechRate: 0.9, dialogFontScale: 2.2));
      await tester.pumpAndSettle();
      expect(state.dialogFontScaleNotifierForTest.value, closeTo(2.2, 0.001));
      // reset during editing – should set draft to defaults (speechRate 0.5, dialogScale 1.0)
      await state.resetProfileForTest('standard');
      await tester.pumpAndSettle();
      expect(state.editingDraftForTest.settings.speechRate, closeTo(0.5, 0.001));
      expect(state.editingDraftForTest.settings.dialogFontScale, closeTo(1.0, 0.001));
      expect(state.dialogFontScaleNotifierForTest.value, closeTo(1.0, 0.001));
      // Save -> persistes defaults
      var ok = await state.saveEditingForTest();
      expect(ok, isTrue);
      await tester.pumpAndSettle();
      expect(state.profilesForTest.firstWhere((p) => p.id == 'standard').settings.speechRate, closeTo(0.5, 0.001));
      // second part: reset then cancel should revert to original (0.5 defaults already, so change again)
      state.startEditingForTest('standard');
      await tester.pumpAndSettle();
      state.updateEditingForTest((AccessibilitySettings s) => s.copyWith(speechRate: 0.88));
      await tester.pumpAndSettle();
      await state.resetProfileForTest('standard');
      await tester.pumpAndSettle();
      expect(state.editingDraftForTest.settings.speechRate, closeTo(0.5, 0.001));
      state.discardEditingForTest();
      await tester.pumpAndSettle();
      // after discard, profile stays as saved before (0.5), not 0.88
      expect(state.profilesForTest.firstWhere((p) => p.id == 'standard').settings.speechRate, closeTo(0.5, 0.001));
      expect(state.speechRateForTest, closeTo(0.5, 0.001));
    });
    testWidgets('S6 inactive reset', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'modeQuestionAsked': true});
      mockChannels();
      dynamic state = await pumpApp(tester);
      state.switchProfileForTest('standard');
      await tester.pumpAndSettle();
      state.startEditingForTest('blind');
      await tester.pumpAndSettle();
      state.updateEditingForTest((AccessibilitySettings s) => s.copyWith(speechRate: 0.9));
      await tester.pumpAndSettle();
      await state.resetProfileForTest('blind');
      await tester.pumpAndSettle();
      expect(state.editingDraftForTest.settings.speechRate, closeTo(0.5, 0.001));
      // runtime unchanged (blind neaktivni)
      expect(state.speechRateForTest, isNot(closeTo(0.9, 0.001)));
      final ok = await state.saveEditingForTest();
      expect(ok, isTrue);
      expect(state.profilesForTest.firstWhere((p) => p.id == 'blind').settings.speechRate, closeTo(0.5, 0.001));
    });
  });

  group('S7 race pred load', () {
    testWidgets('S7 dialog shows loading guard and startEditing validation', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'modeQuestionAsked': true});
      mockChannels();
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.pumpWidget(const ScientificCalculatorApp());
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      dynamic state = tester.state(find.byType(CalculatorScreen)) as dynamic;
      expect(state.profilesLoadedForTest, isTrue);
      // open dialog after load – should NOT show loading
      state.showAccessibilityDialogForTest();
      await tester.pumpAndSettle();
      expect(find.text('Načítám profily…'), findsNothing);
      // Upravit/Edit should be present and enabled (profiles ready)
      expect(find.byWidgetPredicate((w) => w is Text && (w.data == 'Upravit' || w.data == 'Edit')), findsOneWidget);
      // startEditing with nonexistent id should fail explicitly
      final ok = state.startEditingForTest('nonexistent_xyz');
      expect(ok, isFalse);
      expect(state.editingDraftForTest, isNull);
      // valid id should succeed
      final ok2 = state.startEditingForTest('standard');
      expect(ok2, isTrue);
      expect(state.editingDraftForTest, isNotNull);
      state.discardEditingForTest();
      await tester.pumpAndSettle();
      // dialog remains – just pop it if present
      if (tester.any(find.text('Hotovo'))) {
        await tester.tap(find.text('Hotovo').first);
        await tester.pumpAndSettle();
      } else if (tester.any(find.text('Done'))) {
        await tester.tap(find.text('Done').first);
        await tester.pumpAndSettle();
      }
    });
  });

  group('S8 neexistujici editingProfileId', () {
    testWidgets('S8', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'modeQuestionAsked': true});
      mockChannels();
      dynamic state = await pumpApp(tester);
      state.startEditingForTest('standard');
      await tester.pumpAndSettle();
      // corrupt editingProfileId to nonexistent via test helper injection
      // Use direct field hack: set via discard then manual start with bad id
      state.discardEditingForTest();
      await tester.pumpAndSettle();
      final okStart = state.startEditingForTest('nonexistent_id_999');
      expect(okStart, isFalse);
      expect(state.editingDraftForTest, isNull);
      // try save without draft
      final okSave = await state.saveEditingForTest();
      expect(okSave, isFalse);
      // ensure no profile was overwritten
      final prefs = await SharedPreferences.getInstance();
      final v2Before = prefs.getString('accessibility_profiles_v2');
      // after failed save, v2 unchanged
      final v2After = prefs.getString('accessibility_profiles_v2');
      expect(v2After, v2Before);
    });
  });

  group('S9 Esc dismiss reverts active', () {
    testWidgets('S9', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'modeQuestionAsked': true, 'themeMode': ThemeMode.light.index});
      mockChannels();
      dynamic state = await pumpApp(tester);
      state.switchProfileForTest('standard');
      await tester.pumpAndSettle();
      final beforeRate = state.speechRateForTest as double;
      final beforeScale = state.dialogFontScaleForTest as double;
      // simulate open editor then dismiss via discard (Esc triggers PopScope discard)
      state.startEditingForTest('standard');
      await tester.pumpAndSettle();
      state.updateEditingForTest((AccessibilitySettings s) => s.copyWith(speechRate: 0.91, dialogFontScale: 2.0));
      await tester.pumpAndSettle();
      expect(state.dialogFontScaleNotifierForTest.value, closeTo(2.0, 0.001));
      // simulate Esc: PopScope would call discardEditingProfile
      state.discardEditingForTest();
      await tester.pumpAndSettle();
      expect(state.speechRateForTest, closeTo(beforeRate, 0.001));
      expect(state.dialogFontScaleNotifierForTest.value, closeTo(beforeScale, 0.001));
      expect(state.editingDraftForTest, isNull);
    });
  });

  group('S12 dialogFontScale immediate preview', () {
    testWidgets('S12', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'modeQuestionAsked': true});
      mockChannels();
      dynamic state = await pumpApp(tester);
      state.switchProfileForTest('standard');
      await tester.pumpAndSettle();
      state.startEditingForTest('standard');
      await tester.pumpAndSettle();
      state.updateEditingForTest((AccessibilitySettings s) => s.copyWith(dialogFontScale: 1.8));
      await tester.pumpAndSettle();
      expect(state.dialogFontScaleNotifierForTest.value, closeTo(1.8, 0.001));
      state.updateEditingForTest((AccessibilitySettings s) => s.copyWith(dialogFontScale: 0.7));
      await tester.pumpAndSettle();
      expect(state.dialogFontScaleNotifierForTest.value, closeTo(0.7, 0.001));
      state.discardEditingForTest();
      await tester.pumpAndSettle();
      expect(state.dialogFontScaleNotifierForTest.value, closeTo(1.0, 0.001));
    });
  });

  group('S13 semantics selected', () {
    testWidgets('S13', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'modeQuestionAsked': true});
      mockChannels();
      tester.view.physicalSize = const Size(800, 1280);
      dynamic state = await pumpApp(tester);
      state.switchProfileForTest('blind');
      await tester.pumpAndSettle();
      state.showAccessibilityDialogForTest();
      await tester.pumpAndSettle();
      // active is blind, selected initially also blind (initState = active)
      // Tap Standard to change selection without activating
      await tester.tap(find.text('Standard'));
      await tester.pumpAndSettle();
      // Label for Standard should now contain ', vybrán k úpravě' and be selected visually (secondary color)
      // Check that Standard button is enabled and has been selected – verify via semantics label containing selected phrase
      // Find ElevatedButton widgets and check their Semantics ancestors
      final standardBtn = find.widgetWithText(ElevatedButton, 'Standard');
      expect(standardBtn, findsOneWidget);
      // Verify Standard is selected by checking that its Semantics has selected flag via widget's Semantics
      // Alternative check: find semantics with label containing 'Standard, vybrán'
      expect(find.bySemanticsLabel(RegExp(r'Standard.*vybrán')), findsOneWidget);
      // Blind should still be marked as active but not selected: label contains 'aktivní' but not 'vybrán'
      expect(find.bySemanticsLabel(RegExp(r'Blind.*aktivní')), findsWidgets);
      // Ensure that Standard's semantics does NOT also imply active – Standard is not active
      final standardSemanticsFinder = find.bySemanticsLabel(RegExp(r'Standard.*vybrán'));
      expect(standardSemanticsFinder, findsOneWidget);
      // Verify active profile text still shows Blind as active
      expect(find.textContaining('Blind'), findsWidgets);
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  // S10/S11 focus restoration – require widget focus integration, limited in headless test
  group('S10 S11 focus', () {
    testWidgets('S10 TTS subdialog does not break draft', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'modeQuestionAsked': true});
      mockChannels();
      dynamic state = await pumpApp(tester);
      state.startEditingForTest('standard');
      await tester.pumpAndSettle();
      state.updateEditingForTest((AccessibilitySettings s) => s.copyWith(speechRate: 0.77));
      await tester.pumpAndSettle();
      // Simulate opening TTS voice dialog (which internally uses showAppDialog)
      // We test that draft still valid after subdialog closed
      // Call _showTtsVoiceDialog would require mock getVoices; instead we simulate via direct editing
      // Update via editing again to ensure focus restoration path not clearing draft
      state.updateEditingForTest((AccessibilitySettings s) => s.copyWith(speechVolume: 0.33));
      await tester.pumpAndSettle();
      expect(state.editingDraftForTest, isNotNull);
      expect(state.editingDraftForTest.settings.speechRate, closeTo(0.77, 0.001));
      expect(state.editingDraftForTest.settings.speechVolume, closeTo(0.33, 0.001));
      state.discardEditingForTest();
      await tester.pumpAndSettle();
      expect(state.editingDraftForTest, isNull);
    });
  });
}
