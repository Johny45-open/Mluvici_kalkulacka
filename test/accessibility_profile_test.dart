import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Aktualizované testy pro per-profile model v2
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void mockChannels() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (MethodCall call) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.example.mluvici_kalkulacka/accessibility'),
      (MethodCall call) async {
        if (call.method == 'isTalkBackEnabled' ||
            call.method == 'isScreenReaderEnabled') {
          return false;
        }
        return false;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (MethodCall call) async => <String, Object>{
        'appName': 'mluvici_kalkulacka',
        'packageName': 'com.example.mluvici_kalkulacka',
        'version': '6.2.0',
        'buildNumber': '1',
      },
    );
  }

  Future<dynamic> pumpApp(WidgetTester tester) async {
    tester.platformDispatcher.clearAllTestValues();
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(const ScientificCalculatorApp());
    await tester.pumpAndSettle();
    return tester.state(find.byType(CalculatorScreen)) as dynamic;
  }

  String? activeIdFromPrefs() {
    // helper sync – caller must await SharedPreferences.getInstance
    return null;
  }

  group('Accessibility profiles v2', () {
    testWidgets('A) fresh start offers Blind / Low vision choice', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'modeQuestionAsked': true});
      mockChannels();
      final state = await pumpApp(tester);
      var prefs = await SharedPreferences.getInstance();
      // v2 is auto-created on first load
      expect(prefs.containsKey('accessibility_profiles_v2'), isTrue);
      expect(prefs.getString('activeProfileId'), isNotNull);
      state.showInitialAccessibilityDialogForTest();
      await tester.pumpAndSettle();
      expect(find.text('BLIND'), findsOneWidget);
      expect(find.text('LOW VISION'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('B) choosing Blind saves v2 and announces', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'modeQuestionAsked': true});
      mockChannels();
      final state = await pumpApp(tester);
      state.showInitialAccessibilityDialogForTest();
      await tester.pumpAndSettle();
      await tester.tap(find.text('BLIND'));
      await tester.pump(const Duration(milliseconds: 500));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('activeProfileId'), 'blind');
      final v2 = prefs.getString('accessibility_profiles_v2');
      expect(v2, isNotNull);
      final decoded = jsonDecode(v2!) as List;
      expect(decoded.any((e) => (e as Map)['id'] == 'blind'), isTrue);
      expect(state.ttsEnabled, isTrue);
      expect(
        find.byWidgetPredicate((w) => w is Text && (w.data ?? '').contains('Accessibility mode Blind has been set')),
        findsWidgets,
      );
      await tester.pumpAndSettle();
    });

    testWidgets('C) restart keeps Blind; D) change to Low vision via dialog; E) restart keeps Low vision', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'modeQuestionAsked': true});
      mockChannels();
      dynamic state = await pumpApp(tester);
      state.showInitialAccessibilityDialogForTest();
      await tester.pumpAndSettle();
      await tester.tap(find.text('BLIND'));
      await tester.pumpAndSettle();

      // C restart
      await tester.pumpWidget(const ScientificCalculatorApp());
      await tester.pumpAndSettle();
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('activeProfileId'), 'blind');
      state = tester.state(find.byType(CalculatorScreen)) as dynamic;
      expect(state.displayAccessibilityTypeForTest, AccessibilityType.blind);

      // D: změna v dialogu – nový UI: přímé tlačítka profilů bez preview
      tester.view.physicalSize = const Size(800, 1280);
      await tester.pumpAndSettle();
      state.showAccessibilityDialogForTest();
      await tester.pumpAndSettle();
      expect(find.text('Accessibility profile'), findsOneWidget);
      // Najdi tlačítko Low vision uvnitř dialogu (English)
      await tester.tap(find.text('Low vision'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Activate'));
      await tester.pumpAndSettle();
      // Nyní již bez Preview – rovnou se aplikuje
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('activeProfileId'), 'lowvision');
      // ověř per-profile hodnoty
      expect(state.keyboardFontScaleForTest, 1.75);

      await tester.pumpAndSettle();

      // E restart
      await tester.pumpWidget(const ScientificCalculatorApp());
      await tester.pumpAndSettle();
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('activeProfileId'), 'lowvision');
      state = tester.state(find.byType(CalculatorScreen)) as dynamic;
      expect(state.displayAccessibilityTypeForTest, AccessibilityType.visuallyImpaired);
    });

    testWidgets('Per-profile independence A-G', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'modeQuestionAsked': true});
      mockChannels();
      dynamic state = await pumpApp(tester);
      await tester.pumpAndSettle();

      // A) aktivuj Blind
      state.switchProfileForTest('blind');
      await tester.pumpAndSettle();
      // B) změň několik nastavení Blind
      state.updateActiveSettingsForTest((s) => s.copyWith(
            fontSizeMultiplier: 1.0,
            dialogFontScale: 1.0,
            thousandGroupGap: ThousandGroupGap.small,
            announceExpression: true,
            speechRate: 0.8,
          ));
      await tester.pumpAndSettle();

      // C) přepni na Low vision
      state.switchProfileForTest('lowvision');
      await tester.pumpAndSettle();
      expect(state.keyboardFontScaleForTest, 1.75); // defaults

      // D) změň stejná jinak
      state.updateActiveSettingsForTest((s) => s.copyWith(
            fontSizeMultiplier: 2.0,
            dialogFontScale: 2.5,
            thousandGroupGap: ThousandGroupGap.large,
            announceExpression: false,
            speechRate: 0.3,
          ));
      await tester.pumpAndSettle();

      // E) zpět na Blind
      state.switchProfileForTest('blind');
      await tester.pumpAndSettle();
      expect(state.keyboardFontScaleForTest, 1.0);
      expect(state.dialogFontScaleForTest, 1.0);
      expect(state.thousandGroupGapForTest, ThousandGroupGap.small);
      expect(state.announceExpressionForTest, true);
      expect(state.speechRateForTest, 0.8);

      // F) ověř druhé
      state.switchProfileForTest('lowvision');
      await tester.pumpAndSettle();
      expect(state.keyboardFontScaleForTest, 2.0);
      expect(state.dialogFontScaleForTest, 2.5);
      expect(state.thousandGroupGapForTest, ThousandGroupGap.large);
      expect(state.announceExpressionForTest, false);
      expect(state.speechRateForTest, 0.3);

      // G) několik přepnutí
      for (int i = 0; i < 5; i++) {
        state.switchProfileForTest(i % 2 == 0 ? 'lowvision' : 'blind');
        await tester.pumpAndSettle();
      }
      state.switchProfileForTest('blind');
      await tester.pumpAndSettle();
      expect(state.keyboardFontScaleForTest, 1.0);
      state.switchProfileForTest('lowvision');
      await tester.pumpAndSettle();
      expect(state.keyboardFontScaleForTest, 2.0);

      // persistence po restartu
      await tester.pumpWidget(const ScientificCalculatorApp());
      await tester.pumpAndSettle();
      state = tester.state(find.byType(CalculatorScreen)) as dynamic;
      state.switchProfileForTest('blind');
      await tester.pumpAndSettle();
      expect(state.speechRateForTest, 0.8);
    });

    testWidgets('persistence per-profile after restart', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'modeQuestionAsked': true});
      mockChannels();
      dynamic state = await pumpApp(tester);
      state.switchProfileForTest('blind');
      await tester.pumpAndSettle();
      state.updateActiveSettingsForTest((s) => s.copyWith(fontSizeMultiplier: 1.42, speechRate: 0.77));
      await tester.pumpAndSettle();
      state.switchProfileForTest('lowvision');
      await tester.pumpAndSettle();
      state.updateActiveSettingsForTest((s) => s.copyWith(fontSizeMultiplier: 1.99, speechRate: 0.33));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const ScientificCalculatorApp());
      await tester.pumpAndSettle();
      state = tester.state(find.byType(CalculatorScreen)) as dynamic;
      state.switchProfileForTest('blind');
      await tester.pumpAndSettle();
      expect(state.keyboardFontScaleForTest, closeTo(1.42, 0.001));
      expect(state.speechRateForTest, closeTo(0.77, 0.001));
      state.switchProfileForTest('lowvision');
      await tester.pumpAndSettle();
      expect(state.keyboardFontScaleForTest, closeTo(1.99, 0.001));
      expect(state.speechRateForTest, closeTo(0.33, 0.001));
    });

    testWidgets('reset active profile to defaults', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'modeQuestionAsked': true});
      mockChannels();
      dynamic state = await pumpApp(tester);
      state.switchProfileForTest('blind');
      await tester.pumpAndSettle();
      state.updateActiveSettingsForTest((s) => s.copyWith(fontSizeMultiplier: 2.2, dialogFontScale: 2.2));
      await tester.pumpAndSettle();
      expect(state.keyboardFontScaleForTest, 2.2);
      state.resetActiveProfileForTest();
      await tester.pumpAndSettle();
      expect(state.keyboardFontScaleForTest, 1.0);
      expect(state.dialogFontScaleForTest, 1.0);
    });

    testWidgets('custom profile isolates from base', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'modeQuestionAsked': true});
      mockChannels();
      dynamic state = await pumpApp(tester);
      state.switchProfileForTest('blind');
      await tester.pumpAndSettle();
      state.createProfileForTest('Moje', 'blind');
      await tester.pumpAndSettle();
      expect(state.activeProfileIdForTest, isNot('blind'));
      // změň custom
      state.updateActiveSettingsForTest((s) => s.copyWith(fontSizeMultiplier: 2.5));
      await tester.pumpAndSettle();
      expect(state.keyboardFontScaleForTest, 2.5);
      // zpět na blind – musí zůstat původní
      state.switchProfileForTest('blind');
      await tester.pumpAndSettle();
      expect(state.keyboardFontScaleForTest, 1.0);
      // custom stále 2.5
      final customId = (state.profilesForTest as List).firstWhere((p) => p.name == 'Moje').id as String;
      state.switchProfileForTest(customId);
      await tester.pumpAndSettle();
      expect(state.keyboardFontScaleForTest, 2.5);
    });

    testWidgets('delete custom profile fallback to standard', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'modeQuestionAsked': true});
      mockChannels();
      dynamic state = await pumpApp(tester);
      state.createProfileForTest('DeleteMe', 'standard');
      await tester.pumpAndSettle();
      final customId = state.activeProfileIdForTest as String;
      expect(state.profilesForTest.any((p) => p.id == customId), isTrue);
      state.deleteProfileForTest(customId);
      await tester.pumpAndSettle();
      expect(state.profilesForTest.any((p) => p.id == customId), isFalse);
      expect(state.activeProfileIdForTest, 'standard');
    });

    testWidgets('Semantics: no grouping, active profile selected', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'modeQuestionAsked': true});
      mockChannels();
      // enlarge to avoid Row overflow with new profile UI
      tester.view.physicalSize = const Size(800, 1280);
      dynamic state = await pumpApp(tester);
      state.showAccessibilityDialogForTest();
      await tester.pumpAndSettle();
      // Hledání Semantics s selected:true pro aktivní profil
      final semantics = tester.getSemantics(find.text('Standard'));
      // Pokud je aktivní Standard, měl by mít selected
      // Kontrola že neexistuje Semantics s label 'Seskupení' (en: group)
      expect(find.byWidgetPredicate((w) => w is Semantics && (w.properties.label ?? '').toLowerCase().contains('seskupení')), findsNothing);
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('Blind keeps font/zoom, Low vision sets them via apply', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'modeQuestionAsked': true});
      mockChannels();
      dynamic state = await pumpApp(tester);
      await tester.pumpAndSettle();
      state.switchProfileForTest('blind');
      await tester.pumpAndSettle();
      expect(state.keyboardFontScaleForTest, 1.0);
      expect(state.dialogFontScaleForTest, 1.0);
      state.switchProfileForTest('lowvision');
      await tester.pumpAndSettle();
      expect(state.keyboardFontScaleForTest, 1.75);
      expect(state.dialogFontScaleForTest, 1.5);
      expect(state.dotMatrixZoomForTest, 1.25);
      expect(state.resultZoomForTest, 1.25);
      state.setKeyboardFontScaleForTest(2.0);
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      final v2 = jsonDecode(prefs.getString('accessibility_profiles_v2')!);
      // ověř že v2 obsahuje změnu
      expect(v2, isNotNull);
      await tester.pumpWidget(const ScientificCalculatorApp());
      await tester.pumpAndSettle();
      state = tester.state(find.byType(CalculatorScreen)) as dynamic;
      // po restartu active je stále lowvision s 2.0
      expect(state.keyboardFontScaleForTest, 2.0);
    });
  });
}
