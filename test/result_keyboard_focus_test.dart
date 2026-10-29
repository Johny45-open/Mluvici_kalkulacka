import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Z5: displej výsledku je dosažitelný klávesou Tab (NVDA/klávesnice),
/// aniž by vznikla druhá sémantická zastávka nebo se rozbilo Z1–Z4.
///
/// Pořadí sémantických uzlů samo o sobě NENÍ důkazem Tab-chování —
/// testy níže proto posílají skutečné klávesové události (Tab/Shift+Tab,
/// Enter, mezerník, šipky) a ověřují stav fokusového stromu
/// (`FocusManager.instance.primaryFocus`, `hasPrimaryFocus`).
/// Skutečné čtení NVDA/TalkBacku musí ověřit manuální protokol.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<String> ttsLog = [];

  setUp(() {
    ttsLog.clear();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'modeQuestionAsked': true,
    });
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
      (MethodCall call) async => false,
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
  });

  Future<dynamic> pumpApp(
    WidgetTester tester, {
    Locale locale = const Locale('cs'),
  }) async {
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.localeTestValue = locale;
    tester.platformDispatcher.textScaleFactorTestValue = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(ScientificCalculatorApp(locale: locale));
    await tester.pumpAndSettle();
    return tester.state(find.byType(CalculatorScreen)) as dynamic;
  }

  /// Všechny uzly stromu v DFS pořadí (pořadí lineární navigace).
  List<SemanticsNode> allNodes(WidgetTester tester) {
    final owner = tester.binding.pipelineOwner.semanticsOwner;
    expect(owner, isNotNull, reason: 'Vyžaduje ensureSemantics()');
    final out = <SemanticsNode>[];
    void visit(SemanticsNode node) {
      out.add(node);
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(owner!.rootSemanticsNode!);
    return out;
  }

  List<SemanticsNode> resultNodes(WidgetTester tester) =>
      allNodes(tester).where((n) {
        final lbl = n.getSemanticsData().label;
        return lbl == 'Výsledek' || lbl == 'Result';
      }).toList();

  Future<dynamic> calculate(
    WidgetTester tester,
    dynamic state,
    String expr,
  ) async {
    state.setDisplayForTest(expr, expr.length);
    await tester.pump();
    state.calculateForTest();
    await tester.pumpAndSettle();
  }

  /// Skutečný Tab, dokud není fokus na výsledku (max [maxTabs] kroků).
  /// Vrací počet odeslaných Tabů; při nedosažení selže.
  Future<int> tabToResult(
    WidgetTester tester,
    dynamic state, {
    int maxTabs = 60,
  }) async {
    for (var i = 1; i <= maxTabs; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      if ((state.resultFocusNodeForTest as FocusNode).hasPrimaryFocus) {
        return i;
      }
    }
    fail('Tab během $maxTabs kroků nedosáhl na displej výsledku');
  }

  Future<void> shiftTab(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
  }

  group('Z5 výsledek dosažitelný přes Tab', () {
    testWidgets(
      '1. Tab dosáhne na výsledek, Shift+Tab se předvídatelně vrátí',
      (tester) async {
        final state = await pumpApp(tester);
        final FocusNode resultNode = state.resultFocusNodeForTest as FocusNode;
        final FocusNode mainNode = state.mainFocusNodeForTest as FocusNode;

        // Výchozí stav: primární fokus na kořeni klávesnice.
        (state.mainFocusNodeForTest as FocusNode).requestFocus();
        await tester.pump();
        expect(FocusManager.instance.primaryFocus, mainNode);
        expect(resultNode.hasPrimaryFocus, isFalse);

        // Skutečný Tab-cyklus (klávesové události, ne sémantické pořadí).
        await tabToResult(tester, state);
        expect(state.resultHasFocusForTest as bool, isTrue);

        // Shift+Tab: výsledek opustí na předchozí prvek v pořadí.
        await shiftTab(tester);
        expect(resultNode.hasPrimaryFocus, isFalse);
        expect(state.resultHasFocusForTest as bool, isFalse);

        // Tab se vrátí zpět na výsledek (symetrická cesta).
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(resultNode.hasPrimaryFocus, isTrue);
      },
    );

    testWidgets('2. jeden uzel výsledku s plnou hodnotou po více výpočtech', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        final state = await pumpApp(tester);
        final FocusNode nodeBefore = state.resultFocusNodeForTest as FocusNode;

        await calculate(tester, state, '3/4');
        var results = resultNodes(tester);
        expect(results, hasLength(1));
        expect(results.single.getSemanticsData().value, contains('0,75'));

        await calculate(tester, state, '2+2');
        results = resultNodes(tester);
        expect(results, hasLength(1));
        expect(results.single.getSemanticsData().value, contains('4'));

        // Stejný dlouhodobý FocusNode, žádná výměna při setState.
        expect(
          identical(state.resultFocusNodeForTest as FocusNode, nodeBefore),
          isTrue,
        );
        // Konfigurace nodu dle zadání.
        expect(nodeBefore.debugLabel, 'resultDisplay');
        expect(nodeBefore.skipTraversal, isFalse);
        expect(nodeBefore.canRequestFocus, isTrue);
      } finally {
        handle.dispose();
      }
    });

    testWidgets(
      '3a. aktivace čtečkou při fokusu jinde vrací řízení klávesnici',
      (tester) async {
        final handle = tester.ensureSemantics();
        try {
          final state = await pumpApp(tester);
          final FocusNode mainNode = state.mainFocusNodeForTest as FocusNode;
          await calculate(tester, state, '3/4');

          // Fokus prokazatelně jinde (mimo primární fokus kořenového uzlu).
          // Přímé vyvolání onTap uzlu = cesta NVDA (Invoke) / TalkBacku
          // (double-tap). Fyzický dotyk se ve widgetovém testu na displeji
          // nedá věrně simulovat (proxy je hit-test transparentní, plochu
          // výsledku obsluhuje horizontální scroller); dotyková cesta
          // (GestureDetector) je kódem Z5 nedotčena.
          (state.a11yProxyFocusNodeForTest as FocusNode).requestFocus();
          await tester.pumpAndSettle();
          expect(mainNode.hasPrimaryFocus, isFalse);

          final Finder resultSemantics = find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                (w.properties.label == 'Výsledek' ||
                    w.properties.label == 'Result'),
          );
          expect(resultSemantics, findsOneWidget);
          ttsLog.clear();
          (tester.widget(resultSemantics) as Semantics).properties.onTap!();
          await tester.pumpAndSettle();

          // Řízení se vrátilo klávesnici a hodnota se promluvila.
          expect(FocusManager.instance.primaryFocus, mainNode);
          expect(ttsLog, isNotEmpty);
        } finally {
          handle.dispose();
        }
      },
    );

    testWidgets(
      '3b. aktivace čtečkou při klávesnicovém fokusu fokus neukradne',
      (tester) async {
        final handle = tester.ensureSemantics();
        try {
          final state = await pumpApp(tester);
          final FocusNode resultNode =
              state.resultFocusNodeForTest as FocusNode;
          await calculate(tester, state, '3/4');

          (resultNode).requestFocus();
          await tester.pump();
          expect(FocusManager.instance.primaryFocus, resultNode);

          // Přímé vyvolání onTap uzlu = to, co pošle NVDA (Invoke) či TalkBack
          // (double-tap): žádné pointerové události, žádný GestureDetector.
          final Finder resultSemantics = find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                (w.properties.label == 'Výsledek' ||
                    w.properties.label == 'Result'),
          );
          expect(resultSemantics, findsOneWidget);
          ttsLog.clear();
          (tester.widget(resultSemantics) as Semantics).properties.onTap!();
          await tester.pump();

          // Fokus zůstal na výsledku, hodnota se promluvila.
          expect(FocusManager.instance.primaryFocus, resultNode);
          expect(ttsLog, isNotEmpty);
        } finally {
          handle.dispose();
        }
      },
    );

    testWidgets('4. Enter/mezerník/šipky nemění výraz ani kurzor', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      final FocusNode resultNode = state.resultFocusNodeForTest as FocusNode;
      state.setDisplayForTest('2+2', 3);
      await tester.pump();
      state.calculateForTest();
      await tester.pump();

      resultNode.requestFocus();
      await tester.pumpAndSettle();
      // Režim ovládání výrazu je při fokusu mimo kořen vypnutý (Z1).
      expect(state.expressionControlActiveForTest as bool, isFalse);

      final String beforeDisplay = state.displayForTest as String;
      final int beforeCursor = state.cursorForTest as int;

      // Enter a mezerník: žádná změna výrazu/kurzoru, fokus drží.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(state.displayForTest as String, beforeDisplay);
      expect(state.cursorForTest as int, beforeCursor);
      expect(resultNode.hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(state.displayForTest as String, beforeDisplay);
      expect(state.cursorForTest as int, beforeCursor);
      expect(resultNode.hasPrimaryFocus, isTrue);

      // Home/End nejsou traversálové klávesy: kurzor stojí, fokus drží.
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(state.displayForTest as String, beforeDisplay);
      expect(state.cursorForTest as int, beforeCursor);
      expect(resultNode.hasPrimaryFocus, isTrue);

      // Šipky při fokusu mimo kořen patří směrovému traversálu frameworku
      // (stejně jako při fokusu kteréhokoli tlačítka): kurzorem výrazu
      // nehýbou. Samotný traversál fokus přesunout smí — proto zde bez
      // aserce na setrvání fokusu.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(state.displayForTest as String, beforeDisplay);
      expect(state.cursorForTest as int, beforeCursor);
    });

    testWidgets('4b. číslice dál píší do vstupu i při fokusu výsledku', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      final FocusNode resultNode = state.resultFocusNodeForTest as FocusNode;
      state.setDisplayForTest('', 0);
      await tester.pump();

      resultNode.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.pump();

      // Kořenový handler (předek) číslici zpracoval, nový node nic nespolkl.
      expect((state.displayForTest as String).contains('1'), isTrue);
      expect(state.cursorForTest as int, 1);
    });

    testWidgets('5. dlouhý výsledek: scroll + plná hodnota i při fokusu', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      final FocusNode resultNode = state.resultFocusNodeForTest as FocusNode;
      await calculate(tester, state, '123456789*987654321');

      resultNode.requestFocus();
      await tester.pumpAndSettle();

      final scroller = find.ancestor(
        of: find.byType(CustomSegmentDisplay).first,
        matching: find.byWidgetPredicate(
          (w) =>
              w is SingleChildScrollView &&
              w.scrollDirection == Axis.horizontal,
        ),
      );
      expect(scroller, findsOneWidget);
      final scrollable = find.descendant(
        of: scroller,
        matching: find.byType(Scrollable),
      );
      expect(scrollable, findsOneWidget);
      await tester.drag(scroller, const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        greaterThan(0.0),
      );

      final handle = tester.ensureSemantics();
      try {
        final results = resultNodes(tester);
        expect(results, hasLength(1));
        expect(
          results.single.getSemanticsData().value,
          contains('121932631112635264'),
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('6. při novém fokusu nevznikne druhá sémantická zastávka', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        final state = await pumpApp(tester);
        final FocusNode resultNode = state.resultFocusNodeForTest as FocusNode;
        await calculate(tester, state, '3/4');

        // Bez fokusu: jeden neoznačený uzel.
        var results = resultNodes(tester);
        expect(results, hasLength(1));
        expect(
          results.single.getSemanticsData().flagsCollection.isFocused,
          isNot(true),
        );

        // S klávesnicovým fokusem: stále jeden uzel, nově s příznakem focused.
        // (Focus má includeSemantics:false — vlastní uzel nepřidává.)
        // Fokusová notifikace + sémantický update doběhnou až se settlem.
        resultNode.requestFocus();
        await tester.pumpAndSettle();
        results = resultNodes(tester);
        expect(results, hasLength(1));
        final data = results.single.getSemanticsData();
        expect(data.label, 'Výsledek');
        expect(data.value, contains('0,75'));
        expect(data.flagsCollection.isFocused, Tristate.isTrue);
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        // Žádná falešná role tlačítka.
        expect(data.flagsCollection.isButton, isFalse);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('7. Z1: kurzorový režim po Tab-návratu stále funguje', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      final FocusNode resultNode = state.resultFocusNodeForTest as FocusNode;
      final FocusNode mainNode = state.mainFocusNodeForTest as FocusNode;
      state.setDisplayForTest('12+34', 5);
      await tester.pump();

      // Odchod fokusu režim vypne (traversal), návrat ho sám nezapne.
      resultNode.requestFocus();
      await tester.pumpAndSettle();
      expect(state.expressionControlActiveForTest as bool, isFalse);
      mainNode.requestFocus();
      await tester.pumpAndSettle();
      expect(state.expressionControlActiveForTest as bool, isFalse);

      // První šipka reaktivuje bez pohybu, druhá už hýbe kurzorem.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(state.expressionControlActiveForTest as bool, isTrue);
      expect(state.cursorForTest as int, 5);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(state.cursorForTest as int, 4);
    });

    testWidgets('viditelná indikace fokusu (ne pouze barvou)', (tester) async {
      final state = await pumpApp(tester);
      final FocusNode resultNode = state.resultFocusNodeForTest as FocusNode;
      await calculate(tester, state, '3/4');

      Finder frame() => find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            ((w.decoration as BoxDecoration).border is Border),
      );

      // Bez fokusu: průhledný rámeček (layout stabilní, nic viditelného).
      await tester.pump();
      var decorations = tester
          .widgetList<Container>(frame())
          .map((c) => (c.decoration as BoxDecoration).border as Border)
          .toList();
      expect(decorations, isNotEmpty);
      final unfocused = decorations.firstWhere(
        (b) => b.top.color == const Color(0x00000000),
        orElse: () => throw StateError('chybí neviditelný rámeček výsledku'),
      );
      expect(unfocused.top.width, greaterThan(0));

      // S fokusem: rámeček se objeví (tvarová změna, ne jen barva plochy).
      resultNode.requestFocus();
      await tester.pumpAndSettle();
      decorations = tester
          .widgetList<Container>(frame())
          .map((c) => (c.decoration as BoxDecoration).border as Border)
          .toList();
      expect(
        decorations.any((b) => b.top.color == Colors.white && b.top.width >= 2),
        isTrue,
      );
    });
  });
}
