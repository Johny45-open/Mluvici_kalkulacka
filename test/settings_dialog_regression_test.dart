import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regresní testy pro pád Nastavení při prázdném `_profiles`:
/// 1) otevření Nastavení velmi brzy (závod s async `_loadProfiles`),
/// 2) uložené `accessibility_profiles = []` -> fallback na výchozí profily.
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

  Future<dynamic> pumpAppEarly(WidgetTester tester) async {
    tester.platformDispatcher.clearAllTestValues();
    // Široký viewport jako v accessibility_profile_test (krok D):
    // řádek Záloha/Obnova v dialogu by se na úzké ploše přetékal
    // (pre-existující layout, netýká se této regrese).
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(const ScientificCalculatorApp());
    return tester.state(find.byType(CalculatorScreen)) as dynamic;
  }

  Finder profileSectionHeader() {
    return find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          ((widget.data ?? '') == 'Accessibility profile' ||
              (widget.data ?? '') == 'Profil přístupnosti'),
    );
  }

  group('Settings dialog regression', () {
    testWidgets(
        'Settings opens while profiles are unavailable (load failed/pending)',
        (tester) async {
      // Poškozený JSON deterministicky simuluje stav závodu: na neopraveném
      // kódu `_loadProfiles` vyhodí výjimku a `_profiles` zůstane prázdné
      // (stejný pozorovatelný stav jako otevření Nastavení před dokončením
      // preloadu). Dialog se otevírá okamžitě, jediným `pump`, bez čekání.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
        'accessibility_profiles': 'corrupted-json{',
      });
      mockChannels();
      final state = await pumpAppEarly(tester);

      // Otevřít Nastavení velmi brzy, bez čekání na dokončení preloadu.
      state.showAccessibilityDialogForTest();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsWidgets);
      expect(profileSectionHeader(), findsOneWidget);
      // Fallback vykreslí výchozí profily, dialog je plně použitelný.
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('Blind'), findsOneWidget);
      expect(find.text('Low vision'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('Empty stored profiles fall back to defaults', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
        'accessibility_profiles': '[]',
      });
      mockChannels();
      final state = await pumpAppEarly(tester);
      await tester.pumpAndSettle();

      state.showAccessibilityDialogForTest();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsWidgets);
      expect(profileSectionHeader(), findsOneWidget);

      final ids = (state.profilesForTest as List)
          .map((p) => (p as dynamic).id as String)
          .toSet();
      expect(ids, containsAll(<String>{'standard', 'blind', 'lowvision'}));

      await tester.pump(const Duration(seconds: 3));
    });
  });
}
