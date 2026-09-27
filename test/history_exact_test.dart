import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:mluvici_kalkulacka/surd.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void mockChannels() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (c) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.example.mluvici_kalkulacka/accessibility'),
      (c) async => false,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (c) async => <String, Object>{
        'appName': 'mluvici_kalkulacka',
        'packageName': 'com.example.mluvici_kalkulacka',
        'version': '6.2.0',
        'buildNumber': '1',
      },
    );
  }

  Future<dynamic> pumpApp(
    WidgetTester tester, {
    Locale locale = const Locale('cs'),
    Map<String, Object> initialPrefs = const {'modeQuestionAsked': true},
  }) async {
    SharedPreferences.setMockInitialValues(initialPrefs);
    mockChannels();
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ScientificCalculatorApp(locale: locale));
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(CalculatorScreen)) as dynamic;
    return state;
  }

  group('A) částečné odmocňování end-to-end', () {
    testWidgets('√72 → historie nese 6√2 metadata, numerika zdrojem pravdy', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('√(72)', 5);
      await tester.pump();
      state.calculateForTest();
      await tester.pumpAndSettle();
      expect(
        state.lastExactForTest,
        const SurdValue(coefficient: 6, radicand: 2, index: 2),
      );
      expect(
        double.parse(state.lastResultForTest.replaceAll(',', '.')),
        closeTo(8.4852813742, 1e-6),
      );
      final history = state.historyForTest as List;
      expect(history, isNotEmpty);
      final first = history.first;
      expect(first.expression, '√(72)');
      expect(first.exact, const SurdValue(coefficient: 6, radicand: 2, index: 2));
      expect(
        double.parse(first.numericResult.replaceAll(',', '.')),
        closeTo(8.4852813742, 1e-6),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('∛54 → 3∛2', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('∛(54)', 5);
      await tester.pump();
      state.calculateForTest();
      await tester.pumpAndSettle();
      expect(
        state.lastExactForTest,
        const SurdValue(coefficient: 3, radicand: 2, index: 3),
      );
      final history = state.historyForTest as List;
      expect(history.first.exact, const SurdValue(coefficient: 3, radicand: 2, index: 3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('4ⁿ√48 → 2⁴√3', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('4ⁿ√(48)', 6);
      await tester.pump();
      state.calculateForTest();
      await tester.pumpAndSettle();
      expect(
        state.lastExactForTest,
        const SurdValue(coefficient: 2, radicand: 3, index: 4),
      );
      final history = state.historyForTest as List;
      expect(history.first.exact, const SurdValue(coefficient: 2, radicand: 3, index: 4));
      expect(formatSurd(history.first.exact), '2⁴√3');
      expect(tester.takeException(), isNull);
    });
  });

  group('B) historie – exact vs numeric, legacy kompatibilita', () {
    testWidgets('exact režim zobrazí 6√2, numeric režim číselně', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('√(72)', 5);
      await tester.pump();
      state.calculateForTest();
      await tester.pumpAndSettle();

      state.setHistoryExactFormatForTest(HistoryExactFormat.exact);
      await tester.pump();
      state.showHistoryDialogForTest();
      await tester.pumpAndSettle();
      expect(find.text('6√2'), findsOneWidget);
      final closeFinder = find.text('ZAVŘÍT').evaluate().isNotEmpty
          ? find.text('ZAVŘÍT')
          : find.text('CLOSE');
      await tester.tap(closeFinder.first);
      await tester.pumpAndSettle();

      state.setHistoryExactFormatForTest(HistoryExactFormat.numeric);
      await tester.pump();
      state.showHistoryDialogForTest();
      await tester.pumpAndSettle();
      expect(find.text('6√2'), findsNothing);
      // Numerická hodnota je stále v historii.
      expect(
        find.textContaining(RegExp(r'8[,.]485')),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });

    // Widget-testy seedují historii přes API: startup _loadHistory
    // v testovacím prostředí neběží (visící StatsStorage.load je
    // pre-existující chování), parsování kryje parseHistoryStrings test.
    void seedLegacyHistory(dynamic state) {
      state.addHistoryEntryForTest(
        CalculationHistoryEntry.fromStorageString('2+2|4'),
      );
      state.addHistoryEntryForTest(
        CalculationHistoryEntry.fromStorageString('√72|8,485281'),
      );
    }

    testWidgets('starý formát exp|res se načte, fallback dá 6√2', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      seedLegacyHistory(state);
      await tester.pump();
      final history = state.historyForTest as List;
      expect(history.length, 2);
      expect(history[0].expression, '√72');
      expect(history[0].numericResult, '8,485281');
      expect(history[0].exact, isNull);

      state.setHistoryExactFormatForTest(HistoryExactFormat.exact);
      await tester.pump();
      state.showHistoryDialogForTest();
      await tester.pumpAndSettle();
      // Legacy fallback přes trySurdFromExpression.
      expect(find.text('6√2'), findsOneWidget);
      // Ne-surd záznam beze změny.
      expect(find.text('4'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('poklepání vloží NUMERICKOU hodnotu, ne 6√2', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      seedLegacyHistory(state);
      await tester.pump();
      state.setHistoryExactFormatForTest(HistoryExactFormat.exact);
      await tester.pump();
      state.showHistoryDialogForTest();
      await tester.pumpAndSettle();
      expect(find.text('6√2'), findsOneWidget);
      await tester.tap(find.text('6√2'));
      await tester.pumpAndSettle();
      // Vložená je numerika (s tečkou pro výpočet), dialog zavřen.
      expect(state.displayForTest as String, contains('8.485281'));
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('historie má přístupný slovní popis, ne jen 6√2', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      seedLegacyHistory(state);
      await tester.pump();
      state.setHistoryExactFormatForTest(HistoryExactFormat.exact);
      await tester.pump();
      state.showHistoryDialogForTest();
      await tester.pumpAndSettle();
      final semantics = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.label?.contains('odmocnina') == true ||
                w.properties.label?.contains('root') == true),
      );
      expect(semantics, findsWidgets);
      expect(tester.takeException(), isNull);
    });

    test('parseHistoryStrings: JSON, exp|res, exp=res, garbage', () {
      const surdEntry = CalculationHistoryEntry(
        expression: '√(72)',
        numericResult: '8,485281',
        resultDouble: 8.4852813742,
        exactCoef: 6,
        exactRadicand: 2,
        exactIndex: 2,
      );
      final parsed = parseHistoryStrings([
        surdEntry.toStorageString(),
        '√72|8,485281',
        '2+2 = 4',
        'nesmysl bez oddělovače',
      ]);
      expect(parsed.length, 4);
      expect(
        parsed[0].exact,
        const SurdValue(coefficient: 6, radicand: 2, index: 2),
      );
      expect(parsed[1].expression, '√72');
      expect(parsed[1].numericResult, '8,485281');
      expect(parsed[1].exact, isNull);
      expect(parsed[1].isLegacyExactUnknown, isTrue);
      expect(parsed[2].expression, '2+2');
      expect(parsed[2].numericResult, '4');
      expect(parsed[3].expression, 'nesmysl bez oddělovače');
    });

    test('CalculationHistoryEntry JSON roundtrip nese strukturovaná data', () {
      const e = CalculationHistoryEntry(
        expression: '√(72)',
        numericResult: '8,485281',
        resultDouble: 8.4852813742,
        exactCoef: 6,
        exactRadicand: 2,
        exactIndex: 2,
      );
      final restored = CalculationHistoryEntry.fromJson(e.toJson());
      expect(restored.expression, '√(72)');
      expect(restored.numericResult, '8,485281');
      expect(restored.exact, const SurdValue(coefficient: 6, radicand: 2, index: 2));
      // Žádný předformátovaný text v JSON.
      final raw = jsonEncode(e.toJson());
      expect(raw, isNot(contains('6√2')));
      // Storage roundtrip.
      final fromStorage =
          CalculationHistoryEntry.fromStorageString(e.toStorageString());
      expect(fromStorage.exact, const SurdValue(coefficient: 6, radicand: 2, index: 2));
    });
  });

  group('C) migrace starého profilu → globál', () {
    Map<String, Object> prefsWithLegacyProfile() {
      final settings =
          AccessibilitySettings.defaultsStandard().toJson();
      settings['resultDisplayMode'] = 1; // text ve starém profilu
      final v2 = jsonEncode([
        {
          'id': 'standard',
          'name': 'Standardní',
          'isBuiltIn': true,
          'settings': settings,
        },
      ]);
      return {'modeQuestionAsked': true, 'accessibility_profiles_v2': v2};
    }

    testWidgets('globál převezme hodnotu aktivního profilu', (tester) async {
      final state = await pumpApp(
        tester,
        initialPrefs: prefsWithLegacyProfile(),
      );
      expect(state.resultDisplayModeForTest, ResultDisplayMode.text);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('resultDisplayMode'), 'text');
      expect(tester.takeException(), isNull);
    });

    testWidgets('existující globál staré hodnoty v profilech nepřepíší', (
      tester,
    ) async {
      final initial = prefsWithLegacyProfile();
      final withGlobal = Map<String, Object>.from(initial);
      withGlobal['resultDisplayMode'] = 'auto';
      final state = await pumpApp(tester, initialPrefs: withGlobal);
      expect(state.resultDisplayModeForTest, ResultDisplayMode.auto);
      expect(tester.takeException(), isNull);
    });
  });

  group('D) save flow profilu', () {
    testWidgets('změna → save → draft null → discard no-op', (tester) async {
      final state = await pumpApp(tester);
      expect(state.startEditingForTest('standard'), isTrue);
      state.updateEditingForTest(
        (AccessibilitySettings s) => s.copyWith(speechRate: 0.9),
      );
      await tester.pump();
      expect(state.editingDraftForTest, isNotNull);
      expect(await state.saveEditingForTest(), isTrue);
      await tester.pump();
      expect(state.editingDraftForTest, isNull);
      expect(state.editingProfileIdForTest, isNull);
      // Discard po save nic nevrací, nepadá.
      state.discardEditingForTest();
      await tester.pump();
      expect(state.editingDraftForTest, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('potvrzovací dialog: jeden titul, žádný liveRegion se souhrnem', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      expect(state.startEditingForTest('standard'), isTrue);
      state.updateEditingForTest(
        (AccessibilitySettings s) => s.copyWith(speechRate: 0.9),
      );
      await tester.pump();
      final dialogFuture = state.openEditorDialogForTest();
      await tester.pumpAndSettle();
      // _s() v editoru může vrátit cs i en variantu podle testovacího
      // locale — akceptuj obě stejně jako stávající testy.
      Finder saveFinder() => find
          .text('Uložit')
          .evaluate()
          .isNotEmpty
          ? find.text('Uložit')
          : find.text('Save');
      await tester.tap(saveFinder().first);
      await tester.pumpAndSettle();
      // Potvrzovací dialog má správný název.
      final confirmTitle = find.text('Potvrdit uložení').evaluate().isNotEmpty
          ? find.text('Potvrdit uložení')
          : find.text('Confirm save');
      expect(confirmTitle, findsOneWidget);
      // Žádný liveRegion s celým summary textem (duplicita pro TalkBack).
      final liveSummary = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.liveRegion == true) &&
            ((w.properties.label?.contains('Potvrdit uložení profilu') ==
                    true) ||
                (w.properties.label?.contains('Confirm saving profile') ==
                    true)),
      );
      expect(liveSummary, findsNothing);
      // Save tlačítko confirmu má správný label.
      expect(saveFinder(), findsWidgets);
      await tester.tap(saveFinder().last);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      await dialogFuture;
      // Po save je editor zavřený a draft vyčištěn, summary není
      // znovu vystaven jako živá oblast.
      expect(find.byType(AlertDialog), findsNothing);
      expect(state.editingDraftForTest, isNull);
      expect(liveSummary, findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
