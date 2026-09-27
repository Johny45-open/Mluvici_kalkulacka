import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<dynamic> pumpApp(
    WidgetTester tester, {
    Size size = const Size(412, 860),
    double textScale = 1.0,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'modeQuestionAsked': true,
    });
    mockChannels();
    tester.platformDispatcher.clearAllTestValues();
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    tester.view.physicalSize = size;
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

  Semantics outerDisplaySemantics(WidgetTester tester) {
    final finder = find.descendant(
      of: find.byType(CalculatorScreen),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.label == 'Displej' ||
                w.properties.label == 'Display'),
      ),
    );
    expect(finder, findsOneWidget);
    return tester.widget<Semantics>(finder.first);
  }

  Finder keypadGrid() => find.byKey(const ValueKey('keypad_grid'));
  Finder keypadRow(int r) => find.byKey(ValueKey('keypad_row_$r'));

  group('Fraction toggle – stavovy model (pouze prezentacni vrstva)', () {
    testWidgets('1. novy vysledek: fraction view = false', (tester) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '3/4');
      expect(state.lastNumericForTest, closeTo(0.75, 1e-9));
      expect(state.fractionViewForTest, isFalse);
      expect(state.fractionEligibleForTest, isTrue);
      expect(state.fractionStringForTest, '3/4');
      expect(tester.takeException(), isNull);
    });

    testWidgets('2./3. stisk zapne, druhy stisk vrati', (tester) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '3/4');
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isTrue);
      expect(find.text('3/4'), findsOneWidget);
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isFalse);
      expect(find.text('3/4'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('4. prepnuti nemeni _lastResult/ANS/historii', (tester) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '3/4');
      final beforeResult = state.lastResultForTest as String;
      final beforeNumeric = state.lastNumericForTest as double;
      final beforeHistory = (state.historyForTest as List).first;
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.lastResultForTest, beforeResult);
      expect(state.lastNumericForTest, beforeNumeric);
      expect((state.historyForTest as List).length, 1);
      final afterHistory = (state.historyForTest as List).first;
      expect(afterHistory.numericResult, beforeHistory.numericResult);
      expect(afterHistory.resultDouble, beforeHistory.resultDouble);
      // Historie uklada numericky vysledek, ne zlomek.
      expect(afterHistory.numericResult, isNot(contains('/')));
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.lastResultForTest, beforeResult);
      expect(state.lastNumericForTest, beforeNumeric);
      expect(tester.takeException(), isNull);
    });

    testWidgets('5. + po zlomku pouzije numericke ANS', (tester) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '3/4');
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isTrue);
      await state.handleButtonPressedForTest('+');
      await tester.pumpAndSettle();
      // Pokracovani s ANS vypne pohled a pripravi display ANS+.
      expect(state.fractionViewForTest, isFalse);
      expect(state.displayForTest, 'ANS+');
      state.setDisplayForTest('ANS+1', 5);
      await tester.pump();
      state.calculateForTest();
      await tester.pumpAndSettle();
      expect(state.lastNumericForTest, closeTo(1.75, 1e-9));
      expect(tester.takeException(), isNull);
    });

    testWidgets('6. novy vypocet resetuje do vychoziho stavu', (tester) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '3/4');
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isTrue);
      await calculate(tester, state, '1/2');
      expect(state.fractionViewForTest, isFalse);
      expect(state.fractionStringForTest, '1/2');
      expect(tester.takeException(), isNull);
    });

    testWidgets('C resetuje pohled', (tester) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '3/4');
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isTrue);
      state.clearForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isFalse);
      expect(state.fractionEligibleForTest, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cela cisla: 5 -> 5/1, 0 -> 0/1', (tester) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '10/2');
      expect(state.fractionStringForTest, '5/1');
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(find.text('5/1'), findsOneWidget);
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      await calculate(tester, state, '5-5');
      expect(state.fractionStringForTest, '0/1');
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(find.text('0/1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('casovy vysledek neni zpusobily, toggle je disabled', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      state.switchModeForTest(CalculatorMode.time);
      await tester.pumpAndSettle();
      await calculate(tester, state, '12:30');
      expect(state.fractionEligibleForTest, isFalse);
      expect(state.fractionViewForTest, isFalse);
      // Tlacitko zustava na miste jako disabled.
      final toggle = find.byKey(const ValueKey('fraction_toggle'));
      expect(toggle, findsOneWidget);
      final btn = tester.widget<TextButton>(toggle);
      expect(btn.onPressed, isNull);
      // Aktivace bez zpusobilosti nic nezapne.
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('Fraction toggle – displej a TalkBack', () {
    testWidgets('7. Semantics.value odpovida prave zobrazene variante', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '3/4');
      final before = outerDisplaySemantics(tester).properties.value ?? '';
      expect(before.contains('lomeno') || before.contains('over'), isFalse);
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      final during = outerDisplaySemantics(tester).properties.value ?? '';
      expect(during.contains('lomeno') || during.contains('over'), isTrue);
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      final after = outerDisplaySemantics(tester).properties.value ?? '';
      expect(after.contains('lomeno') || after.contains('over'), isFalse);
      expect(after, before);
      expect(tester.takeException(), isNull);
    });

    testWidgets('segment + fraction -> matematicky text, global zustava', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      expect(state.resultDisplayModeForTest.toString(), contains('segment'));
      await calculate(tester, state, '3/4');
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      final text = tester.widget<Text>(find.text('3/4'));
      expect(text.style?.fontFamily, 'MathText');
      expect(
        find.ancestor(
          of: find.text('3/4'),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      // Globalni rezim se nezmenil.
      expect(state.resultDisplayModeForTest.toString(), contains('segment'));
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(find.byType(CustomSegmentDisplay), findsWidgets);
      expect(find.text('3/4'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('prepinac ma pristupny label a je v panelu, ne v rastru', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '1/2');
      final toggle = find.byKey(const ValueKey('fraction_toggle'));
      expect(toggle, findsOneWidget);
      // Neni soucasti 7x4 rastru.
      expect(find.descendant(of: keypadGrid(), matching: toggle), findsNothing);
      // Label odpovida stavu (cs "zlomek" / en "fraction").
      final semFinder = find.ancestor(
        of: toggle,
        matching: find.byWidgetPredicate((w) {
          if (w is! Semantics) return false;
          final label = w.properties.label ?? '';
          final l = label.toLowerCase();
          return l.contains('zlomek') || l.contains('fraction');
        }),
      );
      expect(semFinder, findsOneWidget);
      expect(state.fractionViewForTest, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('Kladenice bez scrollu – 7 radku, stejne vysky', () {
    testWidgets('8. zadny vertikalni ScrollView v hlavni klavesnici', (
      tester,
    ) async {
      final state = await pumpApp(tester, size: const Size(412, 860));
      expect(
        find.ancestor(
          of: keypadGrid(),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      // I pri mensi vysce zadny vertikalni scroll.
      tester.view.physicalSize = const Size(412, 560);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: keypadGrid(),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: keypadGrid(),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      for (var r = 0; r < 7; r++) {
        expect(keypadRow(r), findsOneWidget);
      }
      expect(state, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('9. vsechny rezimy stejnou vysku radku', (tester) async {
      final state = await pumpApp(tester, size: const Size(412, 860));
      final Map<CalculatorMode, double> heights = {};
      for (final mode in CalculatorMode.values) {
        state.switchModeForTest(mode);
        await tester.pumpAndSettle();
        heights[mode] = tester.getSize(keypadRow(0)).height;
      }
      final ref = heights[CalculatorMode.basic]!;
      for (final e in heights.entries) {
        expect(e.value, closeTo(ref, 0.5), reason: '${e.key}');
      }
      // Pri mensi vysce zustava konzistentni pro rezimy se stejnym
      // okolnim chrome. Scientific ma navic prepinac CISLA/FUNKCE, takze
      // klavesnice dostane mene vysky a radky jsou mensi – to je spravne:
      // pri stejnych constraints (stejne dostupne vysce) jsou stejne.
      tester.view.physicalSize = const Size(412, 560);
      await tester.pumpAndSettle();
      final plainModes = CalculatorMode.values
          .where((m) => m != CalculatorMode.scientific)
          .toList();
      final Map<CalculatorMode, double> small = {};
      for (final mode in plainModes) {
        state.switchModeForTest(mode);
        await tester.pumpAndSettle();
        small[mode] = tester.getSize(keypadRow(0)).height;
      }
      final refSmall = small[CalculatorMode.basic]!;
      for (final e in small.entries) {
        expect(e.value, closeTo(refSmall, 0.5), reason: 'small ${e.key}');
      }
      // Scientific se vejde bez scrollu, radky ma mensi/stejne (uzsi prostor).
      state.switchModeForTest(CalculatorMode.scientific);
      await tester.pumpAndSettle();
      final sciH = tester.getSize(keypadRow(0)).height;
      expect(sciH, lessThanOrEqualTo(refSmall + 0.5));
      expect(sciH, greaterThan(refSmall * 0.3));
      expect(
        find.ancestor(
          of: keypadGrid(),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('7 referencnich radku ve vsech rezimech', (tester) async {
      final state = await pumpApp(tester);
      for (final mode in CalculatorMode.values) {
        state.switchModeForTest(mode);
        await tester.pumpAndSettle();
        expect(keypadGrid(), findsOneWidget, reason: '$mode');
        for (var r = 0; r < 7; r++) {
          expect(keypadRow(r), findsOneWidget, reason: '$mode row $r');
        }
      }
      expect(tester.takeException(), isNull);
    });
  });
}
