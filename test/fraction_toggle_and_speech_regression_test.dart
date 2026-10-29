import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:mluvici_kalkulacka/rational.dart';
import 'package:mluvici_kalkulacka/surd.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<String> ttsLog = [];

  void mockChannels() {
    ttsLog.clear();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
      MethodCall call,
    ) async {
      if (call.method == 'speak') {
        ttsLog.add(call.arguments as String? ?? '');
      }
      return 1;
    });
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
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'modeQuestionAsked': true,
    });
    mockChannels();
    tester.platformDispatcher.clearAllTestValues();
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.localeTestValue = locale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(ScientificCalculatorApp(locale: locale));
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
    ttsLog.clear();
    state.calculateForTest();
    await tester.pumpAndSettle();
  }

  Rational rat(int n, int d) => Rational(BigInt.from(n), BigInt.from(d));

  group('Regresní testy přepínání zlomků a hlasu (body 1 - 9)', () {
    // 1. Přesný výsledek 1/2 + 1/3 lze přepnout mezi 5/6 a desetinnou reprezentací.
    testWidgets(
      '1. Přesný výsledek 1/2 + 1/3 lze přepnout mezi 5/6 a desetinnou reprezentací',
      (tester) async {
        final state = await pumpApp(tester);
        await calculate(tester, state, '1/2+1/3');
        expect(state.fractionStringForTest, '5/6');
        expect(state.fractionViewForTest, isFalse);

        // Přepnutí na zlomek
        state.toggleFractionForTest();
        await tester.pumpAndSettle();
        expect(state.fractionViewForTest, isTrue);
        expect(find.text('5/6'), findsOneWidget);

        // Přepnutí zpět na desetinné číslo
        state.toggleFractionForTest();
        await tester.pumpAndSettle();
        expect(state.fractionViewForTest, isFalse);
        expect(find.text('5/6'), findsNothing);
        expect(state.lastResultForTest, isNot(contains('/')));
        expect(tester.takeException(), isNull);
      },
    );

    // 2. Přepnutí reprezentace nezmění interní číselnou hodnotu, historii, ANS ani paměť.
    testWidgets(
      '2. Přepnutí reprezentace nezmění interní hodnotu, historii, ANS ani paměť',
      (tester) async {
        final state = await pumpApp(tester);
        await calculate(tester, state, '1/2+1/3');
        final double numericBefore = state.lastNumericForTest as double;
        final historyBefore = (state.historyForTest as List).length;

        // Uložení do paměti A
        state.setDisplayForTest('ANS', 3);
        await tester.pump();
        expect(state.storeCurrentValueToMemory('A'), isTrue);

        // Přepnutí zlomku na zapnuto a zpět
        state.toggleFractionForTest();
        await tester.pumpAndSettle();
        expect(state.lastNumericForTest, closeTo(numericBefore, 1e-12));
        expect(state.lastRationalForTest, rat(5, 6));

        state.toggleFractionForTest();
        await tester.pumpAndSettle();
        expect(state.lastNumericForTest, closeTo(numericBefore, 1e-12));
        expect(state.lastRationalForTest, rat(5, 6));
        expect((state.historyForTest as List).length, historyBefore);

        // Test přesného ANS po přepínání: ANS*6 = 5
        state.setDisplayForTest('ANS*6', 5);
        await tester.pump();
        state.calculateForTest();
        await tester.pumpAndSettle();
        expect(state.lastNumericForTest, closeTo(5.0, 1e-12));
        expect(state.lastRationalForTest, rat(5, 1));

        // Test paměti: hodnota v A zůstala 5/6
        state.clearForTest();
        await tester.pumpAndSettle();
        state.recallMemoryVariable('A');
        await tester.pumpAndSettle();
        expect(state.displayForTest, contains('(5/6)'));
        expect(tester.takeException(), isNull);
      },
    );

    // 3. Po výpočtu aritmetického průměru (3/2) lze přepínat mezi 3/2 a 1,5.
    testWidgets(
      '3. Aritmetický průměr 3/2 lze přepínat mezi 3/2 a 1,5 (MEAN i =)',
      (tester) async {
        final state = await pumpApp(tester);
        state.switchModeForTest(CalculatorMode.statistics);
        await tester.pumpAndSettle();

        // Sada s hodnotami [1, 2] -> průměr je 3/2 = 1.5
        state.addStatsSetForTest(
          StatisticsSet(
            name: 'PrumerTest',
            fieldNames: const ['Val'],
            records: [
              StatisticsRecord(values: [1]),
              StatisticsRecord(values: [2]),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // A) Výpočet přes tlačítko MEAN
        await state.handleButtonPressedForTest('MEAN');
        await tester.pumpAndSettle();
        expect(state.lastNumericForTest, closeTo(1.5, 1e-12));
        expect(state.lastRationalForTest, rat(3, 2));
        expect(state.fractionStringForTest, '3/2');
        expect(state.fractionEligibleForTest, isTrue);

        // Přepnutí na zlomek
        state.toggleFractionForTest();
        await tester.pumpAndSettle();
        expect(state.fractionViewForTest, isTrue);
        expect(find.text('3/2'), findsOneWidget);

        // Přepnutí zpět na desetinné
        state.toggleFractionForTest();
        await tester.pumpAndSettle();
        expect(state.fractionViewForTest, isFalse);
        expect(find.text('3/2'), findsNothing);

        // B) Výpočet přes '=' ve statistickém režimu
        state.setDisplayForTest('1', 1);
        await tester.pump();
        state.calculateForTest();
        await tester.pumpAndSettle();
        expect(state.lastNumericForTest, closeTo(1.5, 1e-12));
        expect(state.lastRationalForTest, rat(3, 2));
        expect(state.fractionStringForTest, '3/2');
        expect(state.fractionEligibleForTest, isTrue);

        // Přepnutí na zlomek po '='
        state.toggleFractionForTest();
        await tester.pumpAndSettle();
        expect(state.fractionViewForTest, isTrue);
        expect(find.text('3/2'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    // 4. Hlas po výpočtu a po každém přepnutí odpovídá skutečně aktivní reprezentaci.
    testWidgets(
      '4. Hlas po výpočtu i po přepnutí odpovídá zobrazené reprezentaci',
      (tester) async {
        final state = await pumpApp(tester);

        // A) Režim segment: výchozí výsledek 1/2+1/3 je zobrazen desetinně, hlas ohlásí desetinné číslo a dostupnost zlomku
        await calculate(tester, state, '1/2+1/3');
        expect(state.fractionViewForTest, isFalse);
        expect(ttsLog, isNotEmpty);
        expect(ttsLog.last, contains('Výsledek je'));
        expect(
          ttsLog.last,
          contains('Pro tento výsledek je dostupný zlomek 5 lomeno 6'),
        );

        // Přepnutí na zlomek: hlas ohlásí Zlomek 5 lomeno 6
        ttsLog.clear();
        state.toggleFractionForTest();
        await tester.pumpAndSettle();
        expect(state.fractionViewForTest, isTrue);
        expect(ttsLog, hasLength(1));
        expect(ttsLog.single, contains('Zlomek 5 lomeno 6'));

        // Přepnutí zpět: hlas ohlásí desetinnou hodnotu
        ttsLog.clear();
        state.toggleFractionForTest();
        await tester.pumpAndSettle();
        expect(state.fractionViewForTest, isFalse);
        expect(ttsLog, hasLength(1));
        expect(ttsLog.single, contains('Výsledek je'));
        expect(ttsLog.single, isNot(contains('lomeno')));

        // B) Režim text: přesný zlomek se zobrazí přímo a hlas ohlásí přímo zlomek
        state.setResultDisplayModeForTest(ResultDisplayMode.text);
        state.setResultNotationPreferenceForTest(ResultNotationPreference.fraction);
        await tester.pump();
        await calculate(tester, state, '1/2+1/3');
        expect(state.fractionViewForTest, isTrue);
        expect(ttsLog, hasLength(1));
        expect(ttsLog.single, contains('Výsledek je 5 lomeno 6'));

        // Přepnutí na desetinné číslo
        ttsLog.clear();
        state.toggleFractionForTest();
        await tester.pumpAndSettle();
        expect(state.fractionViewForTest, isFalse);
        expect(ttsLog, hasLength(1));
        expect(ttsLog.single, contains('Výsledek je'));
        expect(ttsLog.single, isNot(contains('lomeno')));
        expect(tester.takeException(), isNull);
      },
    );

    // 5. Přibližný zlomek je oznámen jako přibližný a není zaměněn za přesný racionální výsledek.
    testWidgets('5. Přibližný zlomek je oznámen jako přibližný (≈)', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      state.switchModeForTest(CalculatorMode.statistics);
      await tester.pumpAndSettle();

      // Sada s neceločíselnými hodnotami: [1.2, 2.4] -> průměr = 1.8
      state.addStatsSetForTest(
        StatisticsSet(
          name: 'ApproxStats',
          fieldNames: const ['Val'],
          records: [
            StatisticsRecord(values: [1.2]),
            StatisticsRecord(values: [2.4]),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await state.handleButtonPressedForTest('MEAN');
      await tester.pumpAndSettle();
      expect(state.lastNumericForTest, closeTo(1.8, 1e-12));
      // Není přesný racionální výsledek!
      expect(state.lastRationalForTest, isNull);
      // Má přibližný zlomek s ≈
      expect(state.fractionStringForTest, '≈ 9/5');
      expect(state.fractionEligibleForTest, isTrue);

      // Přepnutí na zlomek ohlásí přibližný zlomek
      ttsLog.clear();
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(ttsLog, hasLength(1));
      expect(ttsLog.single, contains('Přibližný zlomek 9 lomeno 5'));
      expect(
        state.currentResultSpeechForTest(),
        contains('přibližně 9 lomeno 5'),
      );
      expect(find.text('≈ 9/5'), findsOneWidget);

      // Přepnutí zpět na desetinné
      ttsLog.clear();
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.currentResultSpeechForTest(), isNot(contains('lomeno')));
      expect(tester.takeException(), isNull);
    });

    // 6. Celočíselný průměr, například 2, nenabízí 2/1.
    testWidgets('6. Celočíselný průměr nenabízí 2/1', (tester) async {
      final state = await pumpApp(tester);
      state.switchModeForTest(CalculatorMode.statistics);
      await tester.pumpAndSettle();

      // Hodnoty [1, 2, 3] -> průměr = 2.0
      state.addStatsSetForTest(
        StatisticsSet(
          name: 'IntegerMean',
          fieldNames: const ['Val'],
          records: [
            StatisticsRecord(values: [1]),
            StatisticsRecord(values: [2]),
            StatisticsRecord(values: [3]),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await state.handleButtonPressedForTest('MEAN');
      await tester.pumpAndSettle();
      expect(state.lastNumericForTest, closeTo(2.0, 1e-12));
      expect(state.fractionStringForTest, isNull);
      expect(state.fractionEligibleForTest, isFalse);
      expect(find.text('2/1'), findsNothing);

      // Pokus o stisk přepínače
      ttsLog.clear();
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(ttsLog, hasLength(1));
      expect(
        ttsLog.single,
        contains('Zlomek není pro tento výsledek dostupný'),
      );
      expect(state.fractionViewForTest, isFalse);

      // Ověření i přes '='
      state.setDisplayForTest('1', 1);
      await tester.pump();
      state.calculateForTest();
      await tester.pumpAndSettle();
      expect(state.lastNumericForTest, closeTo(2.0, 1e-12));
      expect(state.fractionStringForTest, isNull);
      expect(state.fractionEligibleForTest, isFalse);
      expect(tester.takeException(), isNull);
    });

    // 7. Zlomkový pohled se nestane dostupným pro chybový, neplatný nebo nepodporovaný výsledek.
    testWidgets(
      '7. Zlomkový pohled není dostupný pro Error / nepodporovaný výsledek',
      (tester) async {
        final state = await pumpApp(tester);

        // Dělení nulou
        await calculate(tester, state, '1/0');
        expect(state.lastResultForTest, 'Error');
        expect(state.fractionStringForTest, isNull);
        expect(state.fractionEligibleForTest, isFalse);

        // Časový režim
        state.switchModeForTest(CalculatorMode.time);
        await tester.pumpAndSettle();
        await calculate(tester, state, '12:30');
        expect(state.fractionStringForTest, isNull);
        expect(state.fractionEligibleForTest, isFalse);

        // DMS
        state.switchModeForTest(CalculatorMode.scientific);
        await tester.pumpAndSettle();
        state.setDisplayForTest('30', 2);
        await tester.pump();
        await state.handleButtonPressedForTest("°→'");
        await tester.pumpAndSettle();
        expect(state.fractionStringForTest, isNull);
        expect(state.fractionEligibleForTest, isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    // 8. Přepínání nadále správně funguje ve stávajících režimech zobrazení.
    testWidgets('8. Přepínání funguje v režimech segment, text a auto', (
      tester,
    ) async {
      final state = await pumpApp(tester);

      for (final mode in [
        ResultDisplayMode.segment,
        ResultDisplayMode.text,
        ResultDisplayMode.auto,
      ]) {
        state.setResultDisplayModeForTest(mode);
        await tester.pump();
        await calculate(tester, state, '3/4*2/5'); // 3/10
        expect(state.fractionStringForTest, '3/10');

        final initialFractionView = state.fractionViewForTest as bool;
        // Přepnutí
        state.toggleFractionForTest();
        await tester.pumpAndSettle();
        expect(state.fractionViewForTest, !initialFractionView);

        // Návrat zpět
        state.toggleFractionForTest();
        await tester.pumpAndSettle();
        expect(state.fractionViewForTest, initialFractionView);
      }
      expect(tester.takeException(), isNull);
    });

    // 9. Nedochází k regresím v TalkBack/NVDA a fokusování.
    testWidgets(
      '9. Sémantika pro TalkBack/NVDA a fokus zůstávají konzistentní',
      (tester) async {
        final state = await pumpApp(tester);
        await calculate(tester, state, '1/2+1/3');

        // V segment módu je speech na výsledku číselný
        expect(state.currentResultSpeechForTest(), isNot(contains('lomeno')));

        // Po přepnutí na zlomek má sémantika zlomek
        state.toggleFractionForTest();
        await tester.pumpAndSettle();
        expect(state.currentResultSpeechForTest(), contains('5 lomeno 6'));

        // Semantics widget na displeji výsledku má hodnotu 5 lomeno 6
        final semFinder = find.byWidgetPredicate((w) {
          if (w is! Semantics) return false;
          return (w.properties.value ?? '').contains('5 lomeno 6');
        });
        expect(semFinder, findsWidgets);

        // Tlačítko přepínače má sémantický label obsahující stav a zlomek
        final toggleFinder = find.descendant(
          of: find.byKey(const ValueKey('fraction_toggle')),
          matching: find.byWidgetPredicate((w) {
            if (w is! Semantics) return false;
            return (w.properties.label ?? '').contains('5/6');
          }),
        );
        expect(toggleFinder, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
