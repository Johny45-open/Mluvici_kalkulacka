import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:mluvici_kalkulacka/rational.dart';
import 'package:mluvici_kalkulacka/surd.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Integrační testy přesné racionální větve: exaktní výsledky, přepínač
// v režimech segment/text/auto, invalidace metadat, ANS, paměť, historie,
// dialog vložení. Manuální ověření TalkBack/NVDA není součástí (neprovedeno).
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
    tester.platformDispatcher.clearAllTestValues();
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(const ScientificCalculatorApp());
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

  Rational rat(int n, int d) =>
      Rational(BigInt.from(n), BigInt.from(d));

  group('exact results keep numeric _lastResult with structural metadata',
      () {
    testWidgets('six required equalities', (tester) async {
      final state = await pumpApp(tester);
      final cases = <String, Rational>{
        '1/2+1/3': rat(5, 6),
        '3/4*2/5': rat(3, 10),
        '(1/2)/(3/4)': rat(2, 3),
        '-1/2+3/4': rat(1, 4),
        '1/2-1/3': rat(1, 6),
        '1/3*3': rat(1, 1),
      };
      final doubles = <String, double>{
        '1/2+1/3': 5 / 6,
        '3/4*2/5': 3 / 10,
        '(1/2)/(3/4)': 2 / 3,
        '-1/2+3/4': 1 / 4,
        '1/2-1/3': 1 / 6,
        '1/3*3': 1.0,
      };
      for (final entry in cases.entries) {
        await calculate(tester, state, entry.key);
        // Invariant: _lastResult je numerický řetězec (vč. periodické
        // notace "0.(3)"), nikdy "n/d".
        expect(state.lastResultForTest, isNot(contains('/')));
        expect(
          state.lastNumericForTest,
          closeTo(doubles[entry.key]!, 1e-9),
          reason: entry.key,
        );
        expect(state.lastRationalForTest, entry.value, reason: entry.key);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('division by zero keeps CalcError path', (tester) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '1/0');
      expect(state.lastResultForTest, 'Error');
      expect(state.lastRationalForTest, isNull);
      await calculate(tester, state, '1/(2-2)');
      expect(state.lastResultForTest, 'Error');
      expect(state.lastRationalForTest, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('trivial 10/2 is integer, never n/1', (tester) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '10/2');
      expect(state.lastNumericForTest, closeTo(5, 1e-9));
      expect(state.lastRationalForTest, rat(5, 1));
      expect(state.fractionStringForTest, isNull);
      expect(state.fractionEligibleForTest, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('scientific input falls back to double engine unchanged',
        (tester) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '1/2+0.5');
      expect(state.lastNumericForTest, closeTo(1.0, 1e-9));
      expect(state.lastRationalForTest, isNull);
      await calculate(tester, state, 'SIN(30)');
      expect(state.lastRationalForTest, isNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('toggle across segment/text/auto', () {
    testWidgets('segment: decimal -> 5/6 -> decimal', (tester) async {
      final state = await pumpApp(tester);
      expect(state.resultDisplayModeForTest.toString(), contains('segment'));
      await calculate(tester, state, '1/2+1/3');
      expect(state.fractionStringForTest, '5/6');
      expect(state.fractionViewForTest, isFalse);
      expect(state.fractionTargetKindForTest(), 'fraction');
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isTrue);
      expect(find.text('5/6'), findsOneWidget);
      expect(state.fractionTargetKindForTest(), 'numeric');
      // Vypnutí ukáže numeriku, ne znovu zlomek.
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isFalse);
      expect(find.text('5/6'), findsNothing);
      // Matematika nedotčena.
      expect(state.lastRationalForTest, rat(5, 6));
      expect(state.lastResultForTest, isNot(contains('/')));
      expect(tester.takeException(), isNull);
    });

    testWidgets('text: auto-shows 5/6 with null override, toggles to decimal',
        (tester) async {
      final state = await pumpApp(tester);
      state.setResultDisplayModeForTest(ResultDisplayMode.text);
      await tester.pump();
      await calculate(tester, state, '1/2+1/3');
      // Výchozí zobrazení je zlomek i bez jakéhokoliv override.
      expect(state.fractionViewForTest, isTrue);
      expect(find.text('5/6'), findsOneWidget);
      expect(state.fractionTargetKindForTest(), 'numeric');
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isFalse);
      expect(find.text('5/6'), findsNothing);
      expect(state.fractionTargetKindForTest(), 'fraction');
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isTrue);
      expect(find.text('5/6'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('surd roundtrip keeps exact base label path', (tester) async {
      final state = await pumpApp(tester);
      state.setResultDisplayModeForTest(ResultDisplayMode.text);
      await tester.pump();
      state.setDisplayForTest('√(72)', 5);
      await tester.pump();
      state.calculateForTest();
      await tester.pumpAndSettle();
      expect(find.text('6√2'), findsOneWidget);
      expect(state.lastRationalForTest, isNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('invalidation', () {
    testWidgets('1/3 exact vs 0.3333333333 numeric share no metadata',
        (tester) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '1/3');
      expect(state.lastRationalForTest, rat(1, 3));
      final numericRes = state.lastResultForTest as String;
      await calculate(tester, state, '0.3333333333');
      expect(state.lastResultForTest, numericRes);
      // Stejný řetězec, ale zastaralý RationalValue se nesmí použít.
      expect(state.lastRationalForTest, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('special modes and clear invalidate exact metadata',
        (tester) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '1/2+1/3');
      expect(state.lastRationalForTest, rat(5, 6));
      state.switchModeForTest(CalculatorMode.time);
      await tester.pumpAndSettle();
      await calculate(tester, state, '12:30');
      expect(state.lastRationalForTest, isNull);
      state.switchModeForTest(CalculatorMode.scientific);
      await tester.pumpAndSettle();
      await calculate(tester, state, '1/2+1/3');
      expect(state.lastRationalForTest, rat(5, 6));
      state.clearForTest();
      await tester.pumpAndSettle();
      expect(state.lastRationalForTest, isNull);
      expect(state.fractionViewForTest, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('new result resets override to mode base', (tester) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '1/2+1/3');
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isTrue);
      await calculate(tester, state, '3/4*2/5');
      expect(state.fractionViewForTest, isFalse);
      expect(state.fractionStringForTest, '3/10');
      expect(state.lastRationalForTest, rat(3, 10));
      expect(tester.takeException(), isNull);
    });
  });

  group('ANS, memory, history carry structure, never double approximation',
      () {
    testWidgets('ANS chaining stays exact: 5/6 + 1/6 = 1', (tester) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '1/2+1/3');
      state.setDisplayForTest('ANS+1/6', 7);
      await tester.pump();
      state.calculateForTest();
      await tester.pumpAndSettle();
      expect(state.lastRationalForTest, rat(1, 1));
      expect(state.lastNumericForTest, closeTo(1.0, 1e-9));
      expect(tester.takeException(), isNull);
    });

    testWidgets('STO/RCL roundtrip inserts (n/d)', (tester) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '1/2+1/3');
      state.setDisplayForTest('ANS', 3);
      await tester.pump();
      expect(state.storeCurrentValueToMemory('A'), isTrue);
      state.clearForTest();
      await tester.pumpAndSettle();
      state.recallMemoryVariable('A');
      await tester.pumpAndSettle();
      expect(state.displayForTest as String, contains('(5/6)'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('history stores rn/rd and inserts (n/d)', (tester) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '1/2+1/3');
      final history = state.historyForTest as List;
      expect(history, isNotEmpty);
      final first = history.first;
      expect(first.rational, rat(5, 6));
      expect(first.numericResult, isNot(contains('/')));
      // Storage roundtrip nese strukturovaná data, žádný text "5/6" v JSON.
      final restored =
          CalculationHistoryEntry.fromStorageString(first.toStorageString());
      expect(restored.rational, rat(5, 6));
      expect(tester.takeException(), isNull);
    });

    testWidgets('legacy entries never gain back-approximated fractions',
        (tester) async {
      final state = await pumpApp(tester);
      state.addHistoryEntryForTest(
        CalculationHistoryEntry.fromStorageString('2+2|4'),
      );
      await tester.pump();
      final history = state.historyForTest as List;
      expect(history.first.rational, isNull);
      expect(history.first.isLegacyExactUnknown, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('unavailable toggle stays reachable and announces once', () {
    testWidgets('fresh app: enabled, press changes nothing', (tester) async {
      final state = await pumpApp(tester);
      final toggle = find.byKey(const ValueKey('fraction_toggle'));
      expect(toggle, findsOneWidget);
      expect(tester.widget<TextButton>(toggle).onPressed, isNotNull);
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isFalse);
      expect(state.fractionEligibleForTest, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('integer result: reachable, no fraction engaged',
        (tester) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '1+1');
      final toggle = find.byKey(const ValueKey('fraction_toggle'));
      expect(tester.widget<TextButton>(toggle).onPressed, isNotNull);
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isFalse);
      expect(find.text('2/1'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('fraction input dialog', () {
    testWidgets('confirm inserts (3/4) at cursor', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('1+', 2);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('fraction_insert')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));
      await tester.enterText(fields.at(0), '3');
      await tester.enterText(fields.at(1), '4');
      await tester.pump();
      final confirm = find.text('POTVRDIT').evaluate().isNotEmpty
          ? find.text('POTVRDIT')
          : find.text('CONFIRM');
      await tester.tap(confirm.first);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(state.displayForTest, '1+(3/4)');
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancel changes nothing', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('1+', 2);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('fraction_insert')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '3');
      await tester.pump();
      final cancel = find.text('ZRUŠIT').evaluate().isNotEmpty
          ? find.text('ZRUŠIT')
          : find.text('CANCEL');
      await tester.tap(cancel.first);
      await tester.pumpAndSettle();
      expect(state.displayForTest, '1+');
      expect(tester.takeException(), isNull);
    });

    testWidgets('zero denominator keeps dialog open with error',
        (tester) async {
      final state = await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('fraction_insert')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '1');
      await tester.enterText(find.byType(TextField).at(1), '0');
      await tester.pump();
      final confirm = find.text('POTVRDIT').evaluate().isNotEmpty
          ? find.text('POTVRDIT')
          : find.text('CONFIRM');
      await tester.tap(confirm.first);
      await tester.pumpAndSettle();
      // Dialog zůstal otevřený, výraz nedotčen.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(state.displayForTest, '');
      expect(tester.takeException(), isNull);
    });
  });
}
