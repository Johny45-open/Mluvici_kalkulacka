import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:mluvici_kalkulacka/surd.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Regrese: dve cesty ke stejnemu globalnimu ResultDisplayMode.
// A) Pokrocile funkce -> Vzhled vysledkoveho displeje (stavajici).
// B) Nastaveni pristupnosti -> Vzhled vysledkoveho displeje (nova).
// Obe sdileji _ResultDisplayModePicker, stejny source of truth, profily beze zmeny.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void mockChannels() {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (c) async => null,
    );
    m.setMockMethodCallHandler(
      const MethodChannel('com.example.mluvici_kalkulacka/accessibility'),
      (c) async => false,
    );
    m.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (c) async => <String, Object>{
        'appName': 'mluvici_kalkulacka',
        'packageName': 'com.example.mluvici_kalkulacka',
        'version': '6.2.0',
        'buildNumber': '1',
      },
    );
  }

  Future<dynamic> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'modeQuestionAsked': true,
    });
    mockChannels();
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ScientificCalculatorApp(locale: Locale('cs')),
    );
    await tester.pumpAndSettle();
    return tester.state(find.byType(CalculatorScreen)) as dynamic;
  }

  // _s() se ridi host locale pres platformDispatcher (v testech typicky
  // en-US), zatimco _l10n aplikacnim locale. Sekce i volby pickeru pouzivaji
  // _s, proto se jazyk detekuje z platformDispatcher, ne z UI.
  bool isHostCs(WidgetTester tester) =>
      tester.platformDispatcher.locale.languageCode == 'cs';

  String tr(WidgetTester tester, String cs, String en) =>
      isHostCs(tester) ? cs : en;

  Finder dialogScrollable() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(Scrollable),
  );

  Future<void> scrollToText(WidgetTester tester, String text) async {
    final target = find.text(text);
    expect(target, findsWidgets, reason: 'ocekavan text "$text"');
    await tester.scrollUntilVisible(
      target.first,
      300,
      scrollable: dialogScrollable(),
    );
    await tester.pumpAndSettle();
  }

  Future<void> expandResultSection(WidgetTester tester) async {
    final title = tr(tester, 'Vzhled výsledkového displeje', 'Result display');
    await scrollToText(tester, title);
    await tester.tap(find.text(title).first);
    await tester.pumpAndSettle();
  }

  Future<void> tapOption(WidgetTester tester, String cs, String en) async {
    final label = tr(tester, cs, en);
    await scrollToText(tester, label);
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();
  }

  // Zaviraci tlacitka: Pokrocile pouzivaji _s (host locale),
  // Pristupnost _l10n.done (aplikacni locale cs v testu) – proto explicitne.
  Future<void> closeDialogByLabel(WidgetTester tester, String label) async {
    final btn = find.text(label);
    expect(btn, findsWidgets, reason: 'ocekavano tlacitko "$label"');
    await tester.tap(btn.first);
    await tester.pumpAndSettle();
  }

  group('dve cesty – stejny global', () {
    testWidgets('A -> B: zmena z Pokrocilych je videt v Pristupnosti', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      expect(state.resultDisplayModeForTest, ResultDisplayMode.segment);

      // Cesta A: Pokrocile funkce.
      state.showAdvancedDialogForTest();
      await tester.pumpAndSettle();
      await expandResultSection(tester);
      await tapOption(tester, 'Matematický text', 'Math text');
      expect(state.resultDisplayModeForTest, ResultDisplayMode.text);
      await closeDialogByLabel(tester, tr(tester, 'ZAVŘÍT', 'CLOSE'));

      // Cesta B: Nastaveni pristupnosti ukazuje stejnou hodnotu.
      state.showAccessibilityDialogForTest();
      await tester.pumpAndSettle();
      await expandResultSection(tester);
      final radios = tester.widgetList<RadioListTile<ResultDisplayMode>>(
        find.byType(RadioListTile<ResultDisplayMode>),
      );
      expect(radios, isNotEmpty);
      // Produkcni kod pouziva stejne RadioListTile API jako zbytek
      // projektu, test ho jen cte.
      // ignore: deprecated_member_use
      final selected = radios.where((r) => r.value == r.groupValue);
      expect(selected.length, 1);
      expect(selected.first.value, ResultDisplayMode.text);
      await closeDialogByLabel(tester, 'HOTOVO');
      expect(tester.takeException(), isNull);
    });

    testWidgets('B -> A: zmena z Pristupnosti je videt v Pokrocilych', (
      tester,
    ) async {
      final state = await pumpApp(tester);

      // Cesta B: Nastaveni pristupnosti.
      state.showAccessibilityDialogForTest();
      await tester.pumpAndSettle();
      await expandResultSection(tester);
      await tapOption(tester, 'Automatický', 'Automatic');
      expect(state.resultDisplayModeForTest, ResultDisplayMode.auto);
      await closeDialogByLabel(tester, 'HOTOVO');

      // Cesta A: Pokrocile funkce ukazuji stejnou hodnotu.
      state.showAdvancedDialogForTest();
      await tester.pumpAndSettle();
      await expandResultSection(tester);
      final radios = tester.widgetList<RadioListTile<ResultDisplayMode>>(
        find.byType(RadioListTile<ResultDisplayMode>),
      );
      // Produkcni kod pouziva stejne RadioListTile API (viz komentar vyse).
      // ignore: deprecated_member_use
      final selected = radios.where((r) => r.value == r.groupValue);
      expect(selected.length, 1);
      expect(selected.first.value, ResultDisplayMode.auto);
      await closeDialogByLabel(tester, tr(tester, 'ZAVŘÍT', 'CLOSE'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('zmena profilu ani ulozeni profilu RDM nezmeni', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      state.setResultDisplayModeForTest(ResultDisplayMode.text);
      await tester.pump();
      final before = state.activeProfileIdForTest as String;
      state.switchProfileForTest('blind');
      await tester.pump();
      expect(state.resultDisplayModeForTest, ResultDisplayMode.text);
      expect(state.activeProfileIdForTest, isNot(before));
      // Ulozeni profilu (bez RDM pole) hodnotu neovlivni.
      expect(state.startEditingForTest('standard'), isTrue);
      state.updateEditingForTest(
        (AccessibilitySettings s) => s.copyWith(speechRate: 0.9),
      );
      await tester.pump();
      expect(await state.saveEditingForTest(), isTrue);
      expect(state.resultDisplayModeForTest, ResultDisplayMode.text);
      final prefs = await SharedPreferences.getInstance();
      final v2 = prefs.getString('accessibility_profiles_v2') ?? '';
      expect(v2, isNot(contains('resultDisplayMode')));
      expect(tester.takeException(), isNull);
    });
  });
}
