import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gated BUILD spike: jediný přístupný prvek kurzorového displeje.
///
/// Požadavky (widget testy — TalkBack na zařízení musí potvrdit zvlášť):
/// 1. Právě jeden uzel představující editační displej.
/// 2. Má správný label, hodnotu, textSelection a pohybové akce.
/// 3. Žádný další samostatný uzel „Displej" před ním.
/// 4. Žádné druhé textové pole se stejným výrazem.
/// 5. Zoom instrukce není čtena jako nápověda před kurzorovým polem.
/// + hlasový kontrakt: SR on → liveRegion, žádné TTS; SR off/auto-bez-SR
///   → TTS kalkulačky, žádná změna liveRegionu. `_announceCursorPosition`
///   se NERUŠÍ — testy jen zaznamenávají, kudy hlas jde (rozhodnutí
///   o potlačení patří ověření na zařízení).
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
    final state = tester.state(find.byType(CalculatorScreen)) as dynamic;
    final keys = tester.widget<KeyboardListener>(
      find.byType(KeyboardListener).first,
    );
    keys.focusNode.requestFocus();
    await tester.pumpAndSettle();
    return state;
  }

  Future<dynamic> pumpAppSrOn(WidgetTester tester) async {
    final state = await pumpApp(tester);
    state.updateActiveSettingsForTest(
      (s) => s.copyWith(screenReaderMode: ScreenReaderMode.on),
    );
    await tester.pumpAndSettle();
    expect(state.isScreenReaderActiveForTest, isTrue);
    return state;
  }

  Future<dynamic> pumpAppSrOff(WidgetTester tester) async {
    final state = await pumpApp(tester);
    state.updateActiveSettingsForTest(
      (s) => s.copyWith(screenReaderMode: ScreenReaderMode.off),
    );
    await tester.pumpAndSettle();
    expect(state.isScreenReaderActiveForTest, isFalse);
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

  int countTextFields(WidgetTester tester) => allNodes(
    tester,
  ).where((n) => n.getSemanticsData().flagsCollection.isTextField).length;

  group('Jediný přístupný prvek displeje', () {
    testWidgets('1.+2. neprázdný: jeden uzel Displej = textové pole se vším',
        (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final state = await pumpApp(tester);
        state.setDisplayForTest('12+3', 2);
        await tester.pumpAndSettle();

        final nodes = displejNodes(tester);
        expect(nodes, hasLength(1), reason: 'Právě jeden uzel Displej');
        final data = nodes.single.getSemanticsData();
        expect(data.flagsCollection.isTextField, isTrue);
        expect(data.flagsCollection.isReadOnly, isTrue);
        expect(data.value, '12+3');
        expect(
          data.textSelection,
          const TextSelection(baseOffset: 2, extentOffset: 2),
        );
        expect(
          data.hasAction(SemanticsAction.moveCursorForwardByCharacter),
          isTrue,
        );
        expect(
          data.hasAction(SemanticsAction.moveCursorBackwardByCharacter),
          isTrue,
        );
        // Aktivační tap zůstal na tomto uzlu (parita s původní obálkou).
        expect(data.hasAction(SemanticsAction.tap), isTrue);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('3. žádný další samostatný uzel Displej před polem',
        (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final state = await pumpApp(tester);
        state.setDisplayForTest('12+3', 0);
        await tester.pumpAndSettle();

        final nodes = allNodes(tester);
        final idx = <int>[];
        for (var i = 0; i < nodes.length; i++) {
          if (nodes[i].getSemanticsData().label == 'Displej') idx.add(i);
        }
        expect(idx, hasLength(1));
        // Ten jediný je textové pole, ne prázdná obálka před ním.
        expect(
          nodes[idx.single].getSemanticsData().flagsCollection.isTextField,
          isTrue,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('4. žádné druhé textové pole se stejným výrazem',
        (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final state = await pumpApp(tester);
        state.setDisplayForTest('12+3', 4);
        await tester.pumpAndSettle();
        expect(countTextFields(tester), 1);
        expect(find.byType(EditableText), findsOneWidget);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('5. zoom instrukce není hintem před kurzorovým polem',
        (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final state = await pumpApp(tester);
        state.setDisplayForTest('12+3', 1);
        await tester.pumpAndSettle();

        final zoomHints = allNodes(tester).where((n) {
          final hint = n.getSemanticsData().hint;
          return hint.contains('Zoomujte') || hint.contains('Pinch');
        }).toList();
        expect(
          zoomHints,
          isEmpty,
          reason: 'Žádný uzel nesmí číst zoom instrukci jako hint',
        );
        // Ani samotný displejový uzel nemá hint.
        expect(
          displejNodes(tester).single.getSemanticsData().hint,
          isEmpty,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('prázdný stav: jediný uzel Displej = pole s Prázdnem',
        (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final state = await pumpApp(tester);
        state.setDisplayForTest('', 0);
        await tester.pumpAndSettle();

        // Stabilní proxy: i prázdný displej je jedno textové pole.
        expect(find.byType(EditableText), findsOneWidget);
        expect(countTextFields(tester), 1);
        final nodes = displejNodes(tester);
        expect(nodes, hasLength(1));
        final data = nodes.single.getSemanticsData();
        expect(data.flagsCollection.isTextField, isTrue);
        expect(data.flagsCollection.isReadOnly, isTrue);
        expect(data.value, 'Prázdno');
        expect(
          data.textSelection,
          const TextSelection(baseOffset: 0, extentOffset: 0),
        );
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        expect(data.hint, isEmpty);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('pořadí: displej před zlomkem a klávesnicí', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final state = await pumpApp(tester);
        state.setDisplayForTest('12+3', 2);
        await tester.pumpAndSettle();

        final nodes = allNodes(tester);
        int displejIdx = -1;
        int fractionIdx = -1;
        for (var i = 0; i < nodes.length; i++) {
          final d = nodes[i].getSemanticsData();
          if (d.label == 'Displej' && displejIdx < 0) displejIdx = i;
          if ((d.label.contains('Zlomek') || d.label.contains('Fraction')) &&
              fractionIdx < 0) {
            fractionIdx = i;
          }
        }
        expect(displejIdx, greaterThanOrEqualTo(0));
        expect(fractionIdx, greaterThanOrEqualTo(0));
        expect(
          displejIdx,
          lessThan(fractionIdx),
          reason: 'Displej před přepínačem zlomku',
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('přechody prázdný→znak→smazat drží jeden uzel', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final state = await pumpApp(tester);
        state.setDisplayForTest('', 0);
        await tester.pumpAndSettle();
        expect(displejNodes(tester), hasLength(1));
        expect(countTextFields(tester), 1);

        // První znak: stejný jediný uzel Displej, nyní s výrazem.
        await state.handleButtonPressedForTest('7');
        await tester.pumpAndSettle();
        expect(displejNodes(tester), hasLength(1));
        expect(countTextFields(tester), 1);
        expect(
          displejNodes(tester).single.getSemanticsData().value,
          '7',
        );

        // Smazat vše: návrat na jediný uzel s Prázdnem (pole zůstává).
        state.backspaceForTest();
        await tester.pumpAndSettle();
        expect(displejNodes(tester), hasLength(1));
        expect(countTextFields(tester), 1);
        expect(
          displejNodes(tester).single.getSemanticsData().value,
          'Prázdno',
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('výsledek výpočtu: proxy nese řeč prázdna a výsledek je samostatný uzel', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final state = await pumpApp(tester);
        state.setDisplayForTest('3/4', 3);
        await tester.pump();
        state.calculateForTest();
        await tester.pumpAndSettle();

        // Po výpočtu je výraz prázdný → stabilní proxy je jediným uzlem
        // Displej s hodnotou "Prázdno" (stále textové pole, collapsed 0).
        expect(find.byType(EditableText), findsOneWidget);
        expect(countTextFields(tester), 1);
        expect(displejNodes(tester), hasLength(1));
        final data = displejNodes(tester).single.getSemanticsData();
        expect(data.flagsCollection.isTextField, isTrue);
        expect(data.value, 'Prázdno');
        expect(
          data.textSelection,
          const TextSelection(baseOffset: 0, extentOffset: 0),
        );

        // Dolní uzel Výsledek je samostatným uzlem s řečí výsledku.
        final results = allNodes(tester).where((n) {
          final lbl = n.getSemanticsData().label;
          return lbl == 'Výsledek' || lbl == 'Result';
        }).toList();
        expect(results, hasLength(1));
        final resData = results.single.getSemanticsData();
        expect(resData.value.isNotEmpty, isTrue);
        expect(resData.value, contains('0,75'));
      } finally {
        handle.dispose();
      }
    });
  });

  group('Hlasový kontrakt kurzoru (diagnostika, ne odstranění)', () {
    testWidgets('SR on: pohyb → liveRegion, žádné vlastní TTS', (tester) async {
      final state = await pumpAppSrOn(tester);
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();
      ttsLog.clear();
      final before = state.lastAnnouncementForTest as String;

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(state.cursorForTest, 3);
      expect(state.a11yProxyValueForTest.selection,
          const TextSelection.collapsed(offset: 3));
      // Aplikační hláška (fallback) stále odchází liveRegionem…
      expect(state.lastAnnouncementForTest as String, isNot(before));
      expect(
        state.lastAnnouncementForTest as String,
        'Před číslem 3, pozice 4 z 5',
      );
      // …a nikdy vlastním TTS souběžně s odečítačem.
      expect(ttsLog, isEmpty);
      expect(state.isScreenReaderActiveForTest, isTrue);
    });

    testWidgets('SR off: pohyb → vlastní TTS, liveRegion se nemění',
        (tester) async {
      final state = await pumpAppSrOff(tester);
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();
      ttsLog.clear();
      final before = state.lastAnnouncementForTest as String;

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(state.cursorForTest, 3);
      expect(ttsLog, isNotEmpty);
      expect(ttsLog.single, contains('3'));
      expect(state.lastAnnouncementForTest as String, before);
      expect(state.isScreenReaderActiveForTest, isFalse);
    });

    testWidgets('auto + detekce bez SR: pohyb → vlastní TTS', (tester) async {
      final state = await pumpApp(tester);
      // Výchozí profil je auto; mock kanál hlásí false → po settle false.
      await tester.pumpAndSettle();
      expect(state.isScreenReaderActiveForTest, isFalse);
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();
      ttsLog.clear();
      final before = state.lastAnnouncementForTest as String;

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      expect(state.cursorForTest, 1);
      expect(ttsLog, isNotEmpty);
      expect(state.lastAnnouncementForTest as String, before);
    });
  });

  group('Aktivace displeje a focus', () {
    testWidgets('tap na displej vrátí focus klávesnici', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();

      final FocusNode proxyFocus = state.a11yProxyFocusNodeForTest as FocusNode;
      expect(proxyFocus.skipTraversal, isTrue);
      expect(proxyFocus.hasFocus, isFalse);

      await tester.tap(find.byType(EditableText));
      await tester.pumpAndSettle();

      final keys = tester.widget<KeyboardListener>(
        find.byType(KeyboardListener).first,
      );
      expect(keys.focusNode.hasFocus, isTrue);
      // Výraz zůstal nedotčen, kurzor také.
      expect(state.displayForTest, '12+3');
      expect(state.cursorForTest, 2);
    });
  });
}
