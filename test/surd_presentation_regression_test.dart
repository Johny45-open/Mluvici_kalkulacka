import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:mluvici_kalkulacka/surd.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Regresní testy: SurdValue prezentační vrstva.
// - Historie se řídí výhradně ResultDisplayMode (BUG 1).
// - DEC <-> a/b návrat oznamuje skutečně aktivní reprezentaci (BUG 2).
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

  Future<void> calculate(
    WidgetTester tester,
    dynamic state,
    String expr,
  ) async {
    state.setDisplayForTest(expr, expr.length);
    await tester.pump();
    state.calculateForTest();
    await tester.pumpAndSettle();
  }

  Finder closeButton() {
    final cs = find.text('ZAVŘÍT').evaluate().isNotEmpty
        ? find.text('ZAVŘÍT')
        : find.text('CLOSE');
    return cs.first;
  }

  group('Historie – autorita ResultDisplayMode', () {
    testWidgets('√72 vytvoří SurdValue(6,2,2)', (tester) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '√(72)');
      expect(
        state.lastExactForTest,
        const SurdValue(coefficient: 6, radicand: 2, index: 2),
      );
      final history = state.historyForTest as List;
      expect(history.first.exact, const SurdValue(coefficient: 6, radicand: 2, index: 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('text režim: historie ukazuje 6√2', (tester) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '√(72)');
      state.setResultDisplayModeForTest(ResultDisplayMode.text);
      await tester.pump();
      state.showHistoryDialogForTest();
      await tester.pumpAndSettle();
      // Hlavní displej i historie ukazují 6√2 (2 výskyty).
      expect(find.text('6√2'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('auto režim: historie ukazuje 6√2', (tester) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '√(72)');
      state.setResultDisplayModeForTest(ResultDisplayMode.auto);
      await tester.pump();
      state.showHistoryDialogForTest();
      await tester.pumpAndSettle();
      expect(find.text('6√2'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('segment režim: historie zůstává numerická', (tester) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '√(72)');
      state.setResultDisplayModeForTest(ResultDisplayMode.segment);
      await tester.pump();
      state.showHistoryDialogForTest();
      await tester.pumpAndSettle();
      expect(find.text('6√2'), findsNothing);
      expect(find.textContaining(RegExp(r'8[,.]485')), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('HistoryExactFormat už není override (text přes numeric)', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '√(72)');
      // Legacy přepínač ponechán na numeric, ale nesmí přebít text režim.
      state.setHistoryExactFormatForTest(HistoryExactFormat.numeric);
      state.setResultDisplayModeForTest(ResultDisplayMode.text);
      await tester.pump();
      state.showHistoryDialogForTest();
      await tester.pumpAndSettle();
      expect(find.text('6√2'), findsWidgets);
      await tester.tap(closeButton());
      await tester.pumpAndSettle();
      // A naopak: segment zůstane numerický i při legacy exact.
      state.setHistoryExactFormatForTest(HistoryExactFormat.exact);
      state.setResultDisplayModeForTest(ResultDisplayMode.segment);
      await tester.pump();
      state.showHistoryDialogForTest();
      await tester.pumpAndSettle();
      expect(find.text('6√2'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('běžný výsledek 2+2 je numerický ve všech režimech', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '2+2');
      for (final mode in ResultDisplayMode.values) {
        state.setResultDisplayModeForTest(mode);
        await tester.pump();
        state.showHistoryDialogForTest();
        await tester.pumpAndSettle();
        expect(find.text('4'), findsWidgets);
        expect(find.text('6√2'), findsNothing);
        await tester.tap(closeButton());
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('legacy bez metadat: text/auto fallback 6√2, segment numerika', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      state.addHistoryEntryForTest(
        CalculationHistoryEntry.fromStorageString('√72|8,485281'),
      );
      await tester.pump();
      final history = state.historyForTest as List;
      expect(history.first.exact, isNull);
      expect(history.first.isLegacyExactUnknown, isTrue);

      state.setResultDisplayModeForTest(ResultDisplayMode.text);
      await tester.pump();
      state.showHistoryDialogForTest();
      await tester.pumpAndSettle();
      expect(find.text('6√2'), findsOneWidget);
      await tester.tap(closeButton());
      await tester.pumpAndSettle();

      state.setResultDisplayModeForTest(ResultDisplayMode.auto);
      await tester.pump();
      state.showHistoryDialogForTest();
      await tester.pumpAndSettle();
      expect(find.text('6√2'), findsOneWidget);
      await tester.tap(closeButton());
      await tester.pumpAndSettle();

      state.setResultDisplayModeForTest(ResultDisplayMode.segment);
      await tester.pump();
      state.showHistoryDialogForTest();
      await tester.pumpAndSettle();
      expect(find.text('6√2'), findsNothing);
      expect(find.textContaining(RegExp(r'8[,.]485')), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tap na historii vkládá numeriku, ne 6√2', (tester) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '√(72)');
      state.setResultDisplayModeForTest(ResultDisplayMode.text);
      await tester.pump();
      state.showHistoryDialogForTest();
      await tester.pumpAndSettle();
      expect(find.text('6√2'), findsWidgets);
      // Dialog je nad hlavním displejem: tap na záznam historie (poslední).
      await tester.tap(find.text('6√2').last);
      await tester.pumpAndSettle();
      expect(state.displayForTest as String, contains('8.485281'));
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    test('JSON roundtrip nese exact metadata, raw neobsahuje 6√2', () {
      const e = CalculationHistoryEntry(
        expression: '√(72)',
        numericResult: '8,485281',
        resultDouble: 8.4852813742,
        exactCoef: 6,
        exactRadicand: 2,
        exactIndex: 2,
      );
      final restored =
          CalculationHistoryEntry.fromStorageString(e.toStorageString());
      expect(
        restored.exact,
        const SurdValue(coefficient: 6, radicand: 2, index: 2),
      );
      expect(e.toStorageString(), isNot(contains('6√2')));
    });
  });

  group('DEC <-> a/b – návrat drží aktivní reprezentaci', () {
    testWidgets('text: √72 -> zlomek -> zpět 6√2 (displej i speech)', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      state.setResultDisplayModeForTest(ResultDisplayMode.text);
      await tester.pump();
      await calculate(tester, state, '√(72)');
      expect(
        state.lastExactForTest,
        const SurdValue(coefficient: 6, radicand: 2, index: 2),
      );
      expect(state.fractionEligibleForTest, isTrue);
      expect(find.text('6√2'), findsOneWidget);

      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isTrue);

      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isFalse);
      // Metadata nezmizela.
      expect(
        state.lastExactForTest,
        const SurdValue(coefficient: 6, radicand: 2, index: 2),
      );
      // Displej drží 6√2.
      expect(find.text('6√2'), findsOneWidget);
      expect(state.activeResultForTest() as String, '6√2');
      // Hlas odpovídá aktivní reprezentaci, ne natvrdo numerice.
      final speech = state.currentResultSpeechForTest() as String;
      final expected =
          state.spokenForDisplayForTest('6√2') as String;
      expect(speech, expected);
      expect(speech.contains('odmocnina') || speech.contains('root'), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('auto: √72 -> zlomek -> zpět 6√2', (tester) async {
      final state = await pumpApp(tester);
      state.setResultDisplayModeForTest(ResultDisplayMode.auto);
      await tester.pump();
      await calculate(tester, state, '√(72)');
      expect(find.text('6√2'), findsOneWidget);
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isTrue);
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isFalse);
      expect(find.text('6√2'), findsOneWidget);
      expect(state.activeResultForTest() as String, '6√2');
      expect(
        state.currentResultSpeechForTest() as String,
        state.spokenForDisplayForTest('6√2') as String,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('segment: √72 -> zlomek -> zpět numerika (displej i speech)', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      state.setResultDisplayModeForTest(ResultDisplayMode.segment);
      await tester.pump();
      await calculate(tester, state, '√(72)');
      expect(find.text('6√2'), findsNothing);
      final numeric = state.lastResultForTest as String;
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isTrue);
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isFalse);
      // Displej numerický, hlas numerický (žádný surd).
      expect(find.text('6√2'), findsNothing);
      expect(state.activeResultForTest() as String, numeric);
      final speech = state.currentResultSpeechForTest() as String;
      expect(
        speech.contains('odmocnina') || speech.contains('root'),
        isFalse,
      );
      expect(
        speech,
        state.spokenForDisplayForTest(numeric) as String,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('běžný decimal 1/2 se chová jako před opravou', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '1/2');
      final before = state.lastResultForTest as String;
      final beforeNumeric = state.lastNumericForTest as double;
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isTrue);
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isFalse);
      expect(state.lastResultForTest, before);
      expect(state.lastNumericForTest, beforeNumeric);
      expect(state.lastExactForTest, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('vyšší odmocniny: ∛54 a 4ⁿ√48 přes toggle', (tester) async {
      final state = await pumpApp(tester);
      state.setResultDisplayModeForTest(ResultDisplayMode.text);
      await tester.pump();

      await calculate(tester, state, '∛(54)');
      expect(
        state.lastExactForTest,
        const SurdValue(coefficient: 3, radicand: 2, index: 3),
      );
      expect(find.text('3∛2'), findsOneWidget);
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isTrue);
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(find.text('3∛2'), findsOneWidget);
      expect(state.activeResultForTest() as String, '3∛2');
      expect(
        state.currentResultSpeechForTest() as String,
        state.spokenForDisplayForTest('3∛2') as String,
      );

      await calculate(tester, state, '4ⁿ√(48)');
      expect(
        state.lastExactForTest,
        const SurdValue(coefficient: 2, radicand: 3, index: 4),
      );
      expect(find.text('2⁴√3'), findsOneWidget);
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isTrue);
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(find.text('2⁴√3'), findsOneWidget);
      expect(state.activeResultForTest() as String, '2⁴√3');
      expect(
        state.currentResultSpeechForTest() as String,
        state.spokenForDisplayForTest('2⁴√3') as String,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
