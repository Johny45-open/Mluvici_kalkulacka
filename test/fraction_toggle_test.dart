import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:mluvici_kalkulacka/surd.dart';
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

    testWidgets('cela cisla: 5 -> nedostupne, 0 -> nedostupne', (tester) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '10/2');
      expect(state.lastNumericForTest, closeTo(5, 1e-9));
      expect(state.fractionStringForTest, isNull);
      expect(state.fractionEligibleForTest, isFalse);
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isFalse);
      expect(find.text('5/1'), findsNothing);
      expect(state.currentResultSpeechForTest().contains('lomeno 1'), isFalse);
      expect(state.currentResultSpeechForTest().contains('over 1'), isFalse);
      await calculate(tester, state, '5-5');
      expect(state.lastNumericForTest, closeTo(0, 1e-9));
      expect(state.fractionStringForTest, isNull);
      expect(state.fractionEligibleForTest, isFalse);
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isFalse);
      expect(find.text('0/1'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cela cisla: -3 a 2 -> nedostupne, 1/2 zustava dostupna', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '0-3');
      expect(state.fractionStringForTest, isNull);
      expect(state.fractionEligibleForTest, isFalse);
      expect(state.currentResultSpeechForTest().contains('lomeno 1'), isFalse);
      expect(state.currentResultSpeechForTest().contains('over 1'), isFalse);
      await calculate(tester, state, '1+1');
      expect(state.fractionStringForTest, isNull);
      expect(state.fractionEligibleForTest, isFalse);
      await calculate(tester, state, '1/2');
      expect(state.fractionStringForTest, '1/2');
      expect(state.fractionEligibleForTest, isTrue);
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

  group('Fraction toggle – samostatny row mimo displej', () {
    Semantics toggleSemantics(WidgetTester tester) {
      final toggle = find.byKey(const ValueKey('fraction_toggle'));
      final semFinder = find.ancestor(
        of: toggle,
        matching: find.byWidgetPredicate((w) {
          if (w is! Semantics) return false;
          final label = w.properties.label ?? '';
          return label.isNotEmpty;
        }),
      );
      expect(semFinder, findsOneWidget);
      return tester.widget<Semantics>(semFinder.first);
    }

    Finder displayFinder() {
      return find.descendant(
        of: find.byType(CalculatorScreen),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.label == 'Displej' ||
                  w.properties.label == 'Display'),
        ),
      );
    }

    testWidgets('A. 0,5 (1/2) -> 1/2 a zapnuti zobrazi zlomek', (tester) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '1/2');
      expect(state.fractionStringForTest, '1/2');
      expect(state.fractionViewForTest, isFalse);
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isTrue);
      expect(find.text('1/2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('B. OFF->ON nemeni vysledek/ANS/historii', (tester) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '1/2');
      final beforeResult = state.lastResultForTest as String;
      final beforeNumeric = state.lastNumericForTest as double;
      final beforeHistoryLen = (state.historyForTest as List).length;
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isTrue);
      expect(state.lastResultForTest, beforeResult);
      expect(state.lastNumericForTest, beforeNumeric);
      expect((state.historyForTest as List).length, beforeHistoryLen);
      expect(tester.takeException(), isNull);
    });

    testWidgets('C. ON->OFF vrati desetinne zobrazeni', (tester) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '1/2');
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isTrue);
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isFalse);
      expect(find.text('1/2'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('D. novy vysledek invaliduje stary pohled (klic)', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '3/4');
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isTrue);
      expect(
        state.fractionViewKeyForTest as String,
        state.lastResultForTest as String,
      );
      await calculate(tester, state, '1/2');
      expect(state.fractionViewForTest, isFalse);
      expect(state.fractionStringForTest, '1/2');
      // Stary klic zustal u predchoziho vysledku -> pohled zneplatnen.
      expect(
        state.fractionViewKeyForTest as String,
        isNot(state.lastResultForTest as String),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('E. casovy vysledek neni zpusobily + duvod v Semantics', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      state.switchModeForTest(CalculatorMode.time);
      await tester.pumpAndSettle();
      await calculate(tester, state, '12:30');
      expect(state.fractionEligibleForTest, isFalse);
      expect(state.fractionViewForTest, isFalse);
      final toggle = find.byKey(const ValueKey('fraction_toggle'));
      expect(toggle, findsOneWidget);
      expect(tester.widget<TextButton>(toggle).onPressed, isNull);
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isFalse);
      final label = (toggleSemantics(tester).properties.label ?? '')
          .toLowerCase();
      expect(
        label.contains('dostupn') || label.contains('not available'),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('F. Semantics ma explicitni stav + toggled, nejen akci', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '1/2');
      final off = toggleSemantics(tester);
      final offLabel = (off.properties.label ?? '').toLowerCase();
      // Segment + 1/2: zaklad je ciselny, nikdy „desetinne/decimal".
      expect(
        offLabel.contains('číselně') || offLabel.contains('numerically'),
        isTrue,
      );
      expect(
        offLabel.contains('desetinn') || offLabel.contains('decimal'),
        isFalse,
      );
      expect(offLabel.contains('vypnuto') || offLabel.contains('off'), isTrue);
      expect(off.properties.toggled, isFalse);
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      final on = toggleSemantics(tester);
      final onLabel = (on.properties.label ?? '').toLowerCase();
      expect(
        onLabel.contains('zlomek') || onLabel.contains('fraction'),
        isTrue,
      );
      expect(onLabel.contains('zapnuto') || onLabel.contains(' on'), isTrue);
      // Zapnuty pohled rika, kam se vratime (ciselne), ne „desetinne".
      expect(
        onLabel.contains('číselně') || onLabel.contains('numerically'),
        isTrue,
      );
      expect(
        onLabel.contains('desetinn') || onLabel.contains('decimal'),
        isFalse,
      );
      expect(on.properties.toggled, isTrue);
      // Neni to pouze akcni label bez stavu.
      expect(
        onLabel == 'přepnout na zlomek' ||
            onLabel == 'přepnout na desetinný výsledek' ||
            onLabel == 'switch to fraction' ||
            onLabel == 'switch to decimal result',
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('G. vizualni stav je textovy, ne pouze barva', (tester) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '1/2');
      final toggle = find.byKey(const ValueKey('fraction_toggle'));
      String visual() {
        return tester
            .widget<Text>(
              find.descendant(of: toggle, matching: find.byType(Text)).first,
            )
            .data!;
      }

      final offText = visual();
      expect(offText.contains('vypnuto') || offText.contains('off'), isTrue);
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      final onText = visual();
      expect(onText.contains('zapnuto') || onText.contains(' on'), isTrue);
      expect(onText, isNot(offText));
      expect(onText, isNot(anyOf(['a/b', 'DEC'])));
      expect(offText, isNot(anyOf(['a/b', 'DEC'])));
      expect(tester.takeException(), isNull);
    });

    testWidgets('H. toggle neni v keypad_grid, 7x4 zustava', (tester) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '1/2');
      final toggle = find.byKey(const ValueKey('fraction_toggle'));
      expect(toggle, findsOneWidget);
      expect(find.descendant(of: keypadGrid(), matching: toggle), findsNothing);
      for (var r = 0; r < 7; r++) {
        expect(keypadRow(r), findsOneWidget);
        final row = tester.widget<Row>(keypadRow(r));
        expect(row.children.whereType<Expanded>().length, 4);
      }
      expect(state, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('I. toggle neni potomek displeje ani Stack/Positioned', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '1/2');
      final toggle = find.byKey(const ValueKey('fraction_toggle'));
      expect(toggle, findsOneWidget);
      expect(displayFinder(), findsOneWidget);
      expect(
        find.descendant(of: displayFinder(), matching: toggle),
        findsNothing,
      );
      // Retez predku az po CalculatorScreen nesmi obsahovat Stack/Positioned.
      final chain = <String>[];
      tester.element(toggle).visitAncestorElements((e) {
        chain.add(e.widget.runtimeType.toString());
        return e.widget is! CalculatorScreen;
      });
      expect(chain.any((t) => t == 'Stack' || t == 'Positioned'), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('J. poradi display < toggle < mode selector < keypad', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '1/2');
      final toggle = find.byKey(const ValueKey('fraction_toggle'));
      expect(toggle, findsOneWidget);
      final displayBottom = tester.getBottomLeft(displayFinder()).dy;
      final toggleTop = tester.getTopLeft(toggle).dy;
      final toggleBottom = tester.getBottomLeft(toggle).dy;
      expect(toggleTop, greaterThanOrEqualTo(displayBottom - 1.0));
      final modeSel = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.label == 'Přepínač režimů' ||
                w.properties.label == 'Mode selector'),
      );
      expect(modeSel, findsOneWidget);
      expect(
        tester.getTopLeft(modeSel).dy,
        greaterThanOrEqualTo(toggleBottom - 1.0),
      );
      expect(
        tester.getTopLeft(keypadGrid()).dy,
        greaterThanOrEqualTo(toggleBottom - 1.0),
      );
      expect(state, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('K. toggle je focusovatelny a jde aktivovat klavesnici', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '1/2');
      final toggle = find.byKey(const ValueKey('fraction_toggle'));
      expect(toggle, findsOneWidget);
      // Nejblizsi Focus vnitrniho Textu je interni fokus samotneho tlacitka.
      final inner = find
          .descendant(of: toggle, matching: find.byType(Text))
          .first;
      final FocusNode node = Focus.of(tester.element(inner));
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isTrue);
      // Fokus po aktivaci zustal na toggle, neutekl do displeje.
      expect(node.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group(
    'Fraction toggle – tri vizualni stavy + mode-aware Semantics (A-J)',
    () {
      Semantics toggleSemantics(WidgetTester tester) {
        final toggle = find.byKey(const ValueKey('fraction_toggle'));
        final semFinder = find.ancestor(
          of: toggle,
          matching: find.byWidgetPredicate((w) {
            if (w is! Semantics) return false;
            final label = w.properties.label ?? '';
            return label.isNotEmpty;
          }),
        );
        expect(semFinder, findsOneWidget);
        return tester.widget<Semantics>(semFinder.first);
      }

      String visualText(WidgetTester tester) {
        final toggle = find.byKey(const ValueKey('fraction_toggle'));
        return tester
            .widget<Text>(
              find.descendant(of: toggle, matching: find.byType(Text)).first,
            )
            .data!;
      }

      String toggleLabel(WidgetTester tester) =>
          (toggleSemantics(tester).properties.label ?? '').toLowerCase();

      testWidgets('A. bez vysledku: nedostupne + disabled', (tester) async {
        final state = await pumpApp(tester);
        expect(state.fractionEligibleForTest, isFalse);
        expect(state.fractionViewForTest, isFalse);
        final toggle = find.byKey(const ValueKey('fraction_toggle'));
        expect(toggle, findsOneWidget);
        expect(tester.widget<TextButton>(toggle).onPressed, isNull);
        final text = visualText(tester).toLowerCase();
        expect(
          text.contains('nedostupné') || text.contains('unavailable'),
          isTrue,
        );
        // Nedostupny stav nesmi ukazovat zadny konkretni zlomek.
        expect(text.contains('/'), isFalse);
        final sem = toggleSemantics(tester);
        expect(sem.properties.enabled, isFalse);
        expect(sem.properties.toggled, isFalse);
        expect(tester.takeException(), isNull);
      });

      testWidgets('B. po 3/4: eligible + vypnuto + enabled', (tester) async {
        final state = await pumpApp(tester);
        await calculate(tester, state, '3/4');
        expect(state.fractionEligibleForTest, isTrue);
        expect(state.fractionViewForTest, isFalse);
        expect(state.fractionStringForTest, '3/4');
        final toggle = find.byKey(const ValueKey('fraction_toggle'));
        expect(toggle, findsOneWidget);
        expect(tester.widget<TextButton>(toggle).onPressed, isNotNull);
        expect(toggleSemantics(tester).properties.enabled, isTrue);
        expect(toggleSemantics(tester).properties.toggled, isFalse);
        final text = visualText(tester).toLowerCase();
        expect(text.contains('vypnuto') || text.contains('off'), isTrue);
        expect(
          text.contains('nedostupné') || text.contains('unavailable'),
          isFalse,
        );
        // Vizual i Semantics musi ukazat konkretni zlomek.
        expect(visualText(tester), contains('3/4'));
        expect(toggleLabel(tester), contains('3/4'));
        expect(tester.takeException(), isNull);
      });

      testWidgets('C. po aktivaci: zapnuto + stale enabled', (tester) async {
        final state = await pumpApp(tester);
        await calculate(tester, state, '3/4');
        state.toggleFractionForTest();
        await tester.pumpAndSettle();
        expect(state.fractionEligibleForTest, isTrue);
        expect(state.fractionViewForTest, isTrue);
        expect(state.fractionStringForTest, '3/4');
        final toggle = find.byKey(const ValueKey('fraction_toggle'));
        expect(tester.widget<TextButton>(toggle).onPressed, isNotNull);
        expect(toggleSemantics(tester).properties.enabled, isTrue);
        expect(toggleSemantics(tester).properties.toggled, isTrue);
        final text = visualText(tester).toLowerCase();
        expect(text.contains('zapnuto') || text.contains(' on'), isTrue);
        // Vizual i Semantics musi ukazat konkretni zlomek.
        expect(visualText(tester), contains('3/4'));
        expect(toggleLabel(tester), contains('3/4'));
        expect(tester.takeException(), isNull);
      });

      testWidgets('D. novy vypocet pohled vypne', (tester) async {
        final state = await pumpApp(tester);
        await calculate(tester, state, '3/4');
        state.toggleFractionForTest();
        await tester.pumpAndSettle();
        expect(state.fractionViewForTest, isTrue);
        await calculate(tester, state, '1/2');
        expect(state.fractionViewForTest, isFalse);
        expect(state.fractionStringForTest, '1/2');
        expect(state.fractionEligibleForTest, isTrue);
        final text = visualText(tester).toLowerCase();
        expect(text.contains('vypnuto') || text.contains('off'), isTrue);
        // Novy vysledek musi byt videt v UI, stary nesmi zustat.
        expect(visualText(tester), contains('1/2'));
        expect(toggleLabel(tester), contains('1/2'));
        expect(visualText(tester), isNot(contains('3/4')));
        expect(toggleLabel(tester), isNot(contains('3/4')));
        expect(tester.takeException(), isNull);
      });

      testWidgets('E. segment + 1/2: ciselne, nikdy decimal', (tester) async {
        final state = await pumpApp(tester);
        state.setResultDisplayModeForTest(ResultDisplayMode.segment);
        await tester.pump();
        await calculate(tester, state, '1/2');
        expect(state.fractionViewForTest, isFalse);
        final label = toggleLabel(tester);
        expect(
          label.contains('číselně') || label.contains('numerically'),
          isTrue,
        );
        expect(
          label.contains('desetinn') || label.contains('decimal'),
          isFalse,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('F. text + √72: 6√2 + exaktne', (tester) async {
        final state = await pumpApp(tester);
        state.setResultDisplayModeForTest(ResultDisplayMode.text);
        await tester.pump();
        state.setDisplayForTest('√(72)', 5);
        await tester.pump();
        state.calculateForTest();
        await tester.pumpAndSettle();
        expect(find.text('6√2'), findsOneWidget);
        expect(state.fractionViewForTest, isFalse);
        final label = toggleLabel(tester);
        expect(label.contains('exaktně') || label.contains('exactly'), isTrue);
        expect(
          label.contains('desetinn') || label.contains('decimal'),
          isFalse,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('G. text + 0,75: ciselne, ne exaktne', (tester) async {
        final state = await pumpApp(tester);
        state.setResultDisplayModeForTest(ResultDisplayMode.text);
        await tester.pump();
        state.setDisplayForTest('0.75', 4);
        await tester.pump();
        state.calculateForTest();
        await tester.pumpAndSettle();
        final label = toggleLabel(tester);
        expect(
          label.contains('číselně') || label.contains('numerically'),
          isTrue,
        );
        expect(label.contains('exaktně') || label.contains('exactly'), isFalse);
        expect(
          label.contains('desetinn') || label.contains('decimal'),
          isFalse,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('H. auto + √72: exaktne', (tester) async {
        final state = await pumpApp(tester);
        state.setResultDisplayModeForTest(ResultDisplayMode.auto);
        await tester.pump();
        state.setDisplayForTest('√(72)', 5);
        await tester.pump();
        state.calculateForTest();
        await tester.pumpAndSettle();
        expect(find.text('6√2'), findsOneWidget);
        final label = toggleLabel(tester);
        expect(label.contains('exaktně') || label.contains('exactly'), isTrue);
        expect(
          label.contains('desetinn') || label.contains('decimal'),
          isFalse,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('I. auto + 0,75: ciselne', (tester) async {
        final state = await pumpApp(tester);
        state.setResultDisplayModeForTest(ResultDisplayMode.auto);
        await tester.pump();
        state.setDisplayForTest('0.75', 4);
        await tester.pump();
        state.calculateForTest();
        await tester.pumpAndSettle();
        final label = toggleLabel(tester);
        expect(
          label.contains('číselně') || label.contains('numerically'),
          isTrue,
        );
        expect(label.contains('exaktně') || label.contains('exactly'), isFalse);
        expect(tester.takeException(), isNull);
      });

      testWidgets('J. focus/layout zustava: mimo grid, bez presunu focusu', (
        tester,
      ) async {
        final state = await pumpApp(tester);
        await calculate(tester, state, '1/2');
        final toggle = find.byKey(const ValueKey('fraction_toggle'));
        expect(toggle, findsOneWidget);
        expect(
          find.descendant(of: keypadGrid(), matching: toggle),
          findsNothing,
        );
        final inner = find
            .descendant(of: toggle, matching: find.byType(Text))
            .first;
        final FocusNode node = Focus.of(tester.element(inner));
        node.requestFocus();
        await tester.pumpAndSettle();
        expect(node.hasFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(state.fractionViewForTest, isTrue);
        expect(node.hasFocus, isTrue);
        expect(tester.takeException(), isNull);
      });

      testWidgets('K. hodnoty 0,75 -> 3/4, 10/2 -> nedostupne, -0,75 -> -3/4', (
        tester,
      ) async {
        final state = await pumpApp(tester);
        await calculate(tester, state, '0.75');
        expect(state.fractionStringForTest, '3/4');
        expect(visualText(tester), contains('3/4'));
        expect(toggleLabel(tester), contains('3/4'));
        await calculate(tester, state, '10/2');
        expect(state.fractionStringForTest, isNull);
        expect(state.fractionEligibleForTest, isFalse);
        final unavailableText = visualText(tester).toLowerCase();
        expect(
          unavailableText.contains('nedostupné') ||
              unavailableText.contains('unavailable'),
          isTrue,
        );
        await calculate(tester, state, '0-3/4');
        expect(state.fractionStringForTest, '-3/4');
        expect(visualText(tester), contains('-3/4'));
        expect(toggleLabel(tester), contains('-3/4'));
        expect(tester.takeException(), isNull);
      });

      testWidgets('L. maly viewport + textScale 2.0: 3/4 stale cele', (
        tester,
      ) async {
        final state = await pumpApp(
          tester,
          size: const Size(320, 560),
          textScale: 2.0,
        );
        await calculate(tester, state, '3/4');
        expect(state.fractionEligibleForTest, isTrue);
        // Plna hodnota musi zustat v datech widgetu, ne jen bez vyjimky.
        expect(visualText(tester), contains('3/4'));
        expect(toggleLabel(tester), contains('3/4'));
        expect(tester.takeException(), isNull);
      });
    },
  );
}
