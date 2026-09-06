import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Testy trvale uložených profilů přístupnosti:
/// A) nové spuštění → dialog nabízí Nevidomý / Slabozraký (en: Blind / Low vision),
/// B) výběr Blind → hodnoty + uložení + oznámení,
/// C) restart → uložený profil drží, podmínka prvního spuštění je splněna,
/// D) změna na Low vision v Nastavení → aktualizace + uložení + oznámení,
/// E) restart → Low vision drží,
/// F) existující uživatel s historickým none(0) → migrace bez resetu.
///
/// Poznámka: časovačem řízené automatické zobrazení úvodního dialogu
/// (_initTts, ~2200 ms) nelze ve widget testech věrně spustit – _loadStatsData
/// visí na reálném file I/O ve fake-async zóně (pre-existující limit testovacího
/// prostředí, na zařízení se netýká). Proto se dialog prvního spuštění otevírá
/// přes showInitialAccessibilityDialogForTest (stejný vzor, jaký projekt používá
/// pro STATS dialogy) a podmínka „neptat se znovu" se ověřuje přímo přes
/// strážce `containsKey('accessibilityType')` z _initTts.
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

  group('Accessibility profiles', () {
    testWidgets('A) fresh start offers Blind / Low vision choice',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
      });
      mockChannels();
      final state = await pumpApp(tester);

      // Podmínka prvního spuštění: klíč ještě neexistuje → dialog se zobrazí.
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('accessibilityType'), isFalse);

      state.showInitialAccessibilityDialogForTest();
      await tester.pumpAndSettle();

      expect(find.text('BLIND'), findsOneWidget);
      expect(find.text('LOW VISION'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('B) choosing Blind sets values, saves profile, announces',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
      });
      mockChannels();
      final state = await pumpApp(tester);
      state.showInitialAccessibilityDialogForTest();
      await tester.pumpAndSettle();

      await tester.tap(find.text('BLIND'));
      await tester.pump(const Duration(milliseconds: 500));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('accessibilityType'), 1);
      expect(state.ttsEnabled, isTrue);
      
      // Debug:
      final allTexts = find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data ?? '')
          .toList();
      print('ALL TEXTS B: $allTexts');

      // Po výběru se dialog v testu nezavře hned, ale snackbar už existuje.
      // Najdeme ho v textu snackbaru.
      expect(
        find.byWidgetPredicate((widget) =>
            widget is Text &&
            (widget.data ?? '').contains('Accessibility mode Blind has been set')),
        findsWidgets,
      );

      // Necháme SnackBar doznít a dialog zavřeme
      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets(
        'C) restart keeps Blind and first-run guard is satisfied; '
        'D) change to Low vision updates, saves and announces; '
        'E) restart keeps Low vision', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
      });
      mockChannels();
      dynamic state = await pumpApp(tester);
      state.showInitialAccessibilityDialogForTest();
      await tester.pumpAndSettle();

      // B: výběr Blind.
      await tester.tap(find.text('BLIND'));
      await tester.pumpAndSettle();

      // C: restart – profil drží a strážce prvního spuštění už dialog
      // znovu nevyvolá (klíč existuje).
      await tester.pumpWidget(const ScientificCalculatorApp());
      await tester.pumpAndSettle();
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('accessibilityType'), isTrue);
      expect(prefs.getInt('accessibilityType'), 1);
      state = tester.state(find.byType(CalculatorScreen)) as dynamic;
      expect(
        state.displayAccessibilityTypeForTest,
        AccessibilityType.blind,
      );

      // D: změna profilu v Nastavení.
      tester.view.physicalSize = const Size(800, 1280);
      await tester.pumpAndSettle();
      state.showAccessibilityDialogForTest();
      await tester.pumpAndSettle();
      expect(find.text('Accessibility mode'), findsOneWidget);
      await tester.tap(find.text('Low vision'));
      // NEPOUŽIJEME PUMPANDSETTLE IHNED, jinak SnackBar zmizí.
      await tester.pump(const Duration(milliseconds: 500));

      prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('accessibilityType'), 2);
      expect(prefs.getDouble('keyboardFontScale'), 1.4);
      
      // Hledání v SnackBaru
      expect(
        find.byType(SnackBar),
        findsOneWidget,
      );

      // Necháme SnackBar doznít a dialog zavřeme
      await tester.pumpAndSettle();

      // E: restart – Low vision drží.
      await tester.pumpWidget(const ScientificCalculatorApp());
      await tester.pumpAndSettle();
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('accessibilityType'), 2);
      expect(prefs.getDouble('keyboardFontScale'), 1.4);
      state = tester.state(find.byType(CalculatorScreen)) as dynamic;
      expect(
        state.displayAccessibilityTypeForTest,
        AccessibilityType.visuallyImpaired,
      );

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets(
        'F) existing user with legacy STANDARDNÍ (0) migrates '
        'to Low vision without resetting custom values', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
        'accessibilityType': 0,
        'keyboardFontScale': 1.1,
        'dialogFontScale': 1.2,
      });
      mockChannels();
      final state = await pumpApp(tester);
      await tester.pumpAndSettle();

      // Migrace: historické none se zobrazí jako Slabozraký…
      expect(
        state.displayAccessibilityTypeForTest,
        AccessibilityType.visuallyImpaired,
      );
      // …ale ruční hodnoty uživatele zůstanou nedotčené.
      expect(state.keyboardFontScaleForTest, 1.1);
      expect(state.dialogFontScaleForTest, 1.2);
      // Strážce prvního spuštění: klíč existuje → žádná nová volba.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('accessibilityType'), isTrue);

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('Blind profile keeps font/zoom, Low vision sets them',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
        'accessibilityType': 1,
      });
      mockChannels();
      dynamic state = await pumpApp(tester);
      await tester.pumpAndSettle();

      state.applyAccessibilityProfile(
        AccessibilityType.blind,
        announcement: 'done-blind',
      );
      await tester.pumpAndSettle();
      expect(state.keyboardFontScaleForTest, 1.0);
      expect(state.dialogFontScaleForTest, 1.0);

      state.applyAccessibilityProfile(
        AccessibilityType.visuallyImpaired,
        announcement: 'done-lowvision',
      );
      await tester.pumpAndSettle();
      expect(state.keyboardFontScaleForTest, 1.4);
      expect(state.dialogFontScaleForTest, 1.4);
      expect(state.dotMatrixZoomForTest, 1.5);
      expect(state.resultZoomForTest, 1.5);

      // Ruční změna po profilu má přednost – restart ji nepřepíše.
      state.setKeyboardFontScaleForTest(2.0);
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('keyboardFontScale'), 2.0);

      await tester.pumpWidget(const ScientificCalculatorApp());
      await tester.pumpAndSettle();
      state = tester.state(find.byType(CalculatorScreen)) as dynamic;
      expect(state.keyboardFontScaleForTest, 2.0);

      await tester.pump(const Duration(seconds: 3));
    });
  });
}
