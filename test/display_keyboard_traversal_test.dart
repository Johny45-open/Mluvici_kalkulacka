import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Z6: horní vstupní řádek displeje je zastávkou klávesnicového traversálu
/// (Tab/Shift+Tab) PŘED dolním výsledkem a při skutečném fokusu se zobrazí
/// jeho bílý obrys.
///
/// Oprava NVDA: dříve měla vstupní proxy `skipTraversal: true`, takže
/// Flutterův traversál vstupní řádek přeskakoval a NVDA (sledující UIA
/// stav `focused`) při Tab-navigaci dosáhl pouze na výsledek. Při fokusu
/// proxy navíc `RenderEditable` sám publikuje skutečné `isFocused` i
/// `onSetSelection` (SDK) — fokus se nepředstírá.
///
/// Pořadí uzlů samo o sobě NENÍ důkazem chování NVDA — testy posílají
/// skutečné klávesové události a kontrolují stav fokusového stromu.
/// Skutečné čtení NVDA/TalkBacku musí potvrdit ruční protokol.
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

  Future<dynamic> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.localeTestValue = const Locale('cs');
    tester.platformDispatcher.textScaleFactorTestValue = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(
      const ScientificCalculatorApp(locale: Locale('cs')),
    );
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(CalculatorScreen)) as dynamic;
    (state.mainFocusNodeForTest as FocusNode).requestFocus();
    await tester.pumpAndSettle();
    return state;
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

  List<SemanticsNode> displejNodes(WidgetTester tester) => allNodes(
    tester,
  ).where((n) => n.getSemanticsData().label == 'Displej').toList();

  List<SemanticsNode> resultNodes(WidgetTester tester) => allNodes(
    tester,
  ).where((n) => n.getSemanticsData().label == 'Výsledek').toList();

  /// Skutečný Tab, dokud není primární fokus na [target] (max [maxTabs]).
  /// Vrací počet odeslaných Tabů; při nedosažení selže.
  Future<int> tabUntil(
    WidgetTester tester,
    FocusNode target, {
    int maxTabs = 60,
  }) async {
    for (var i = 1; i <= maxTabs; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      if (target.hasPrimaryFocus) return i;
    }
    fail('Tab během $maxTabs kroků nedosáhl uzlu ${target.debugLabel}');
  }

  Future<void> shiftTab(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
  }

  group('Z6 klávesnicový traversál vstupní řádek přeskakuje NE', () {
    testWidgets('1. Tab dosáhne vstup PŘED výsledkem, Shift+Tab se vrátí', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      final FocusNode proxyNode = state.a11yProxyFocusNodeForTest as FocusNode;
      final FocusNode resultNode = state.resultFocusNodeForTest as FocusNode;
      final FocusNode mainNode = state.mainFocusNodeForTest as FocusNode;

      // Výchozí stav: primární fokus na kořeni klávesnice.
      expect(FocusManager.instance.primaryFocus, mainNode);
      expect(proxyNode.hasPrimaryFocus, isFalse);

      // Tab-cyklus: vstupní řádek je zastávkou a je BEFORE výsledkem.
      await tabUntil(tester, proxyNode);
      expect(resultNode.hasPrimaryFocus, isFalse);

      // Další Tab vede na výsledek (sousední zastávka).
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(resultNode.hasPrimaryFocus, isTrue);
      expect(proxyNode.hasPrimaryFocus, isFalse);

      // Reverzní navigace: Shift+Tab z výsledku se vrací na vstup.
      await shiftTab(tester);
      expect(proxyNode.hasPrimaryFocus, isTrue);
      expect(state.resultHasFocusForTest as bool, isFalse);

      // Symetrická cesta zpět.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(resultNode.hasPrimaryFocus, isTrue);
    });
  });

  group('Z6 sémantika: dva samostatné přístupné prvky', () {
    testWidgets('2. vstup a výsledek jsou dva uzly; hodnota = aktuální výraz', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        final state = await pumpApp(tester);
        state.setDisplayForTest('12+3', 3);
        await tester.pumpAndSettle();

        var display = displejNodes(tester);
        expect(display, hasLength(1));
        final data = display.single.getSemanticsData();
        expect(data.flagsCollection.isTextField, isTrue);
        expect(data.value, contains('12+3'));
        expect(data.textSelection, const TextSelection.collapsed(offset: 3));

        // Výsledek zůstává samostatný uzel mimo vstup.
        expect(resultNodes(tester), hasLength(1));

        // Po výpočtu vstup i výsledek nesou správné, oddělené hodnoty.
        state.calculateForTest();
        await tester.pumpAndSettle();
        display = displejNodes(tester);
        expect(display, hasLength(1));
        expect(resultNodes(tester), hasLength(1));
        expect(
          resultNodes(tester).single.getSemanticsData().value,
          contains('15'),
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets(
      '3. s fokusem proxy uzel publikuje isFocused i onSetSelection',
      (tester) async {
        final handle = tester.ensureSemantics();
        try {
          final state = await pumpApp(tester);
          final FocusNode proxyNode =
              state.a11yProxyFocusNodeForTest as FocusNode;
          state.setDisplayForTest('12+3', 3);
          await tester.pumpAndSettle();

          // Bez klávesnicového fokusu proxy: žádný focused, žádné
          // onSetSelection (kontrakt SDK: publikují se POUZE při fokusu).
          var data = displejNodes(tester).single.getSemanticsData();
          expect(data.flagsCollection.isFocused, isNot(Tristate.isTrue));
          expect(data.hasAction(SemanticsAction.setSelection), isFalse);

          // S klávesnicovým fokusem (cílená Tab zastávka): skutečný
          // focused stav a akce pro změnu výběru — nic není předstíráno.
          await tabUntil(tester, proxyNode);
          await tester.pumpAndSettle();
          data = displejNodes(tester).single.getSemanticsData();
          expect(data.flagsCollection.isFocused, Tristate.isTrue);
          expect(data.hasAction(SemanticsAction.setSelection), isTrue);
          expect(data.value, contains('12+3'));
        } finally {
          handle.dispose();
        }
      },
    );
  });

  group('Z6 ovládání kalkulačky při fokusu vstupní proxy', () {
    testWidgets('4. číslice dál píší výraz a proxy se synchronizuje', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      final FocusNode proxyNode = state.a11yProxyFocusNodeForTest as FocusNode;
      state.setDisplayForTest('', 0);
      await tester.pumpAndSettle();

      await tabUntil(tester, proxyNode);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
      await tester.pump();

      expect((state.displayForTest as String).contains('5'), isTrue);
      final int len = (state.displayForTest as String).length;
      expect(state.a11yProxyValueForTest.text, state.displayForTest);
      expect(
        state.a11yProxyValueForTest.selection,
        TextSelection.collapsed(offset: len),
      );
      expect(state.cursorForTest as int, len);
    });

    testWidgets('5. šipky/Home/End synchronizují kurzor s proxy jednou', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      final FocusNode proxyNode = state.a11yProxyFocusNodeForTest as FocusNode;
      state.setDisplayForTest('12+3', 4);
      await tester.pumpAndSettle();

      await tabUntil(tester, proxyNode);

      // Šipka doleva: přesně jeden krok (žádné dvojité zpracování
      // EditableText + kořenový handler), proxy i interní stav souhlasí.
      ttsLog.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(state.cursorForTest as int, 3);
      expect(
        state.a11yProxyValueForTest.selection,
        const TextSelection.collapsed(offset: 3),
      );
      expect(ttsLog, hasLength(1));

      // Home: kurzor na začátek, opět právě jedno oznámení.
      ttsLog.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(state.cursorForTest as int, 0);
      expect(
        state.a11yProxyValueForTest.selection,
        const TextSelection.collapsed(offset: 0),
      );
      expect(ttsLog, hasLength(1));

      // End: kurzor na konec výrazu.
      ttsLog.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(state.cursorForTest as int, 4);
      expect(
        state.a11yProxyValueForTest.selection,
        const TextSelection.collapsed(offset: 4),
      );
      expect(ttsLog, hasLength(1));
    });

    testWidgets('6. Backspace při fokusu proxy maže znak před kurzorem', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      final FocusNode proxyNode = state.a11yProxyFocusNodeForTest as FocusNode;
      state.setDisplayForTest('12+3', 4);
      await tester.pumpAndSettle();

      await tabUntil(tester, proxyNode);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(state.displayForTest as String, '12+');
      expect(state.cursorForTest as int, 3);
      expect(state.a11yProxyValueForTest.text, '12+');
      expect(
        state.a11yProxyValueForTest.selection,
        const TextSelection.collapsed(offset: 3),
      );
    });

    testWidgets('7. Enter při fokusu proxy počítá a klávesnice zůstane živá', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        final state = await pumpApp(tester);
        final FocusNode proxyNode =
            state.a11yProxyFocusNodeForTest as FocusNode;
        state.setDisplayForTest('2+2', 3);
        await tester.pumpAndSettle();

        await tabUntil(tester, proxyNode);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        // Výpočet proběhl (výsledek 4).
        final results = resultNodes(tester);
        expect(results, hasLength(1));
        expect(results.single.getSemanticsData().value, contains('4'));

        // Fokus se nezasekl: další číslice musí dál projít do výrazu
        // (chování, ne interní stav — pokud by Enter uvolnil fokus někam,
        // kde klávesy nedosáhnou na kořenový handler, test selže).
        expect(FocusManager.instance.primaryFocus, isNotNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.digit7);
        await tester.pumpAndSettle();
        expect((state.displayForTest as String).contains('7'), isTrue);
      } finally {
        handle.dispose();
      }
    });
  });

  group('Z6 bílý obrys vstupního i výsledkového řádku', () {
    /// Obrysový překryv (Container s rámečkem) uvnitř sémantického uzlu
    /// se zadaným labellem. Rámeček je ve stromu trvale (průhledný/viditelný).
    Border borderInLabel(WidgetTester tester, String label) {
      final finder = find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == label,
        ),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).border is Border,
        ),
      );
      expect(
        finder,
        findsOneWidget,
        reason: 'očekáván právě jeden obrysový překryv v uzlu $label',
      );
      final container = tester.widget(finder) as Container;
      return (container.decoration as BoxDecoration).border as Border;
    }

    bool isWhite(Border b) => b.top.color == Colors.white;

    testWidgets('8. obrysy sledují přechody klávesnicového fokusu', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      final FocusNode proxyNode = state.a11yProxyFocusNodeForTest as FocusNode;
      final FocusNode resultNode = state.resultFocusNodeForTest as FocusNode;

      // Výchozí stav (fokus na kořeni): oba obrysy průhledné.
      expect(isWhite(borderInLabel(tester, 'Displej')), isFalse);
      expect(isWhite(borderInLabel(tester, 'Výsledek')), isFalse);

      // Tab na vstup: bílý obrys vstupu, výsledek beze změny.
      await tabUntil(tester, proxyNode);
      await tester.pumpAndSettle();
      expect(proxyNode.hasPrimaryFocus, isTrue);
      expect(isWhite(borderInLabel(tester, 'Displej')), isTrue);
      expect(isWhite(borderInLabel(tester, 'Výsledek')), isFalse);

      // Tab na výsledek: obrys přejde na výsledek.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(resultNode.hasPrimaryFocus, isTrue);
      expect(state.resultHasFocusForTest as bool, isTrue);
      expect(isWhite(borderInLabel(tester, 'Displej')), isFalse);
      expect(isWhite(borderInLabel(tester, 'Výsledek')), isTrue);

      // Shift+Tab zpět na vstup: obrys se vrátí na vstup.
      await shiftTab(tester);
      await tester.pumpAndSettle();
      expect(proxyNode.hasPrimaryFocus, isTrue);
      expect(isWhite(borderInLabel(tester, 'Displej')), isTrue);
      expect(isWhite(borderInLabel(tester, 'Výsledek')), isFalse);

      // Návrat na kořen (tap/aktivace vstupu žádá fokus kořenový):
      // obrys vstupu zmizí.
      final Finder displejSemantics = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Displej',
      );
      (tester.widget(displejSemantics) as Semantics).properties.onTap!();
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus,
        state.mainFocusNodeForTest as FocusNode,
      );
      expect(isWhite(borderInLabel(tester, 'Displej')), isFalse);
      expect(isWhite(borderInLabel(tester, 'Výsledek')), isFalse);
    });

    testWidgets(
      '9. aktivace čtečkou nezapne obrys; virtuální kurzor nezaměřuje',
      (tester) async {
        final handle = tester.ensureSemantics();
        try {
          final state = await pumpApp(tester);
          final FocusNode mainNode = state.mainFocusNodeForTest as FocusNode;
          state.setDisplayForTest('12+3', 2);
          await tester.pumpAndSettle();

          // Přímé vyvolání onTap uzlu Displej = cesta NVDA (Invoke) /
          // TalkBacku (double-tap), kterou virtuální kurzor prochází.
          // Vrací řízení klávesnici (kořenový uzel) — NENÍ to klávesnicový
          // fokus proxy, takže se obrys vstupu nesmí zobrazit.
          final Finder displejSemantics = find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == 'Displej',
          );
          expect(displejSemantics, findsOneWidget);
          (tester.widget(displejSemantics) as Semantics).properties.onTap!();
          await tester.pumpAndSettle();

          expect(FocusManager.instance.primaryFocus, mainNode);
          expect(isWhite(borderInLabel(tester, 'Displej')), isFalse);
          expect(isWhite(borderInLabel(tester, 'Výsledek')), isFalse);
        } finally {
          handle.dispose();
        }
      },
    );
  });
}
