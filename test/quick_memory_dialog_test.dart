import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Testy rychlé paměti: AppBar akce „Paměť" (Icons.memory),
/// dialog Paměť → A, reuse business logiky STO/RCL,
/// persistence `memoryVariables`, přehled a legacy Advanced cesta.
Finder memoryAppBarButton() =>
    find.widgetWithIcon(IconButton, Icons.memory);

/// Najde [Text] s libovolným z daných řetězců (cs/en varianta).
Finder textAny(List<String> options) => find.byWidgetPredicate(
  (w) => w is Text && w.data != null && options.contains(w.data),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const memoryVars = ['A', 'B', 'C', 'D', 'E', 'F', 'X', 'Y', 'M'];

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'accessibilityType': 0,
      'modeQuestionAsked': true,
    });

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    // path_provider nemá ve widget testech handler a jeho Future by visel:
    // _saveStatsData() (StatsStorage.save → getApplicationDocumentsDirectory)
    // by se nikdy nedokončil a memoryVariables by se nezapsalo.
    // Vracíme izolovaný temp adresář pro každý test.
    final docsDir = Directory.systemTemp.createTempSync('quickmem_docs');
    addTearDown(() {
      try {
        docsDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return docsDir.path;
        }
        return null;
      },
    );

    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (MethodCall call) async => null,
    );

    messenger.setMockMethodCallHandler(
      const MethodChannel('com.example.mluvici_kalkulacka/accessibility'),
      (MethodCall call) async {
        if (call.method == 'isTalkBackEnabled' ||
            call.method == 'isScreenReaderEnabled') {
          return false;
        }
        return false;
      },
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
    tester.platformDispatcher.clearAllTestValues();
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(const ScientificCalculatorApp());
    await tester.pumpAndSettle();

    return tester.state(find.byType(CalculatorScreen)) as dynamic;
  }

  Future<void> openQuickMemory(WidgetTester tester) async {
    expect(memoryAppBarButton(), findsOneWidget);
    await tester.tap(memoryAppBarButton());
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  }

  Finder dialogText(String value) => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.text(value),
  );

  group('Quick memory AppBar entry point', () {
    testWidgets('1. AppBar akce Pamet existuje', (tester) async {
      await pumpApp(tester);
      expect(memoryAppBarButton(), findsOneWidget);
    });

    testWidgets('2. AppBar akce ma spravnou accessibility label', (
      tester,
    ) async {
      await pumpApp(tester);
      final btn = tester.widget<IconButton>(memoryAppBarButton());
      // Tooltip je zdroj accessibility labelu pro IconButton (TalkBack/NVDA).
      expect(btn.tooltip, anyOf(['Paměť', 'Memory']));
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is IconButton &&
              (w.tooltip == 'Paměť' || w.tooltip == 'Memory') &&
              w.icon is Icon &&
              (w.icon as Icon).icon == Icons.memory,
        ),
        findsOneWidget,
      );
    });

    testWidgets('3. Dialog lze otevrit', (tester) async {
      await pumpApp(tester);
      await openQuickMemory(tester);
      // Nadpis dialogu + heading pro uložení.
      expect(textAny(['Paměť', 'Memory']), findsWidgets);
      expect(
        textAny(['Uložit aktuální hodnotu do:', 'Save current value to:']),
        findsOneWidget,
      );
    });

    testWidgets('4. Dialog obsahuje A, B, C, D, E, F, X, Y, M', (tester) async {
      await pumpApp(tester);
      await openQuickMemory(tester);
      for (final v in memoryVars) {
        expect(
          dialogText(v),
          findsOneWidget,
          reason: 'proměnná $v chybí v rychlém dialogu',
        );
      }
    });

    testWidgets('13. Novy dialog nerusi focus order hlavni klavesnice', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      expect(find.byKey(const ValueKey('keypad_grid')), findsOneWidget);
      await openQuickMemory(tester);
      await tester.tap(textAny(['ZAVŘÍT', 'CLOSE']));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(const ValueKey('keypad_grid')), findsOneWidget);
      expect(state.displayForTest, isNotNull);
    });
  });

  group('Quick memory store (reuse STO logiky)', () {
    testWidgets('5. Ulozeni cisla do A', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('42', 2);
      await tester.pump();
      final ok = state.storeCurrentValueToMemory('A') as bool;
      expect(ok, isTrue);
      expect(state.memoryForTest['A'], 42.0);
    });

    testWidgets('Pamet → B ulozi vyhodnoceny vyraz, ne text', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12*20+5', 7);
      await tester.pump();
      // Cesta rychlého dialogu: Paměť → B.
      await tester.tap(memoryAppBarButton());
      await tester.pumpAndSettle();
      await tester.tap(dialogText('B'));
      await tester.pumpAndSettle();
      expect(state.memoryForTest['B'], 245.0);
    });

    testWidgets('6. Ulozeni vyrazu do B', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12*20+5', 7);
      await tester.pump();
      final ok = state.storeCurrentValueToMemory('B') as bool;
      expect(ok, isTrue);
      expect(state.memoryForTest['B'], 245.0);
    });

    testWidgets('7. Prazdny displej pouzije _lastResult', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('7*6', 3);
      await tester.pump();
      state.calculateForTest();
      await tester.pumpAndSettle();
      expect(state.lastResultForTest, isNotEmpty);
      state.setDisplayForTest('', 0);
      await tester.pump();
      final ok = state.storeCurrentValueToMemory('C') as bool;
      expect(ok, isTrue);
      expect(state.memoryForTest['C'], 42.0);
    });

    testWidgets('8. Chyba u neplatneho vyrazu', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('5/0', 3);
      await tester.pump();
      final ok = state.storeCurrentValueToMemory('D') as bool;
      expect(ok, isFalse);
      expect(state.memoryForTest['D'], 0.0);
    });

    testWidgets('Ulozeni do kazde promenne A-F/X/Y/M', (tester) async {
      final state = await pumpApp(tester);
      for (final v in memoryVars) {
        state.setDisplayForTest('5', 1);
        await tester.pump();
        final ok = state.storeCurrentValueToMemory(v) as bool;
        expect(ok, isTrue, reason: 'uložení do $v selhalo');
      }
      for (final v in memoryVars) {
        expect(state.memoryForTest[v], 5.0, reason: 'proměnná $v');
      }
    });

    testWidgets('9. Persistence po ulozeni (memoryVariables)', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('42', 2);
      await tester.pump();
      state.storeCurrentValueToMemory('A');
      // _saveStatsData() je fire-and-forget: opakovaný pump propláchne
      // microtask frontu mock kanálů (SharedPreferences + path_provider).
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('memoryVariables');
      expect(raw, isNotNull);
      expect(raw, contains('"A"'));
      expect(raw, contains('42'));
    });
  });

  group('Quick memory recall + overview', () {
    testWidgets('10. Vyvolani promenne vlozi hodnotu do vyrazu', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      state.setMemoryForTest('D', 99.0);
      state.setDisplayForTest('', 0);
      await tester.pump();
      state.recallMemoryVariable('D');
      await tester.pump();
      expect(state.displayForTest, contains('99'));
    });

    testWidgets('Vyvolat pres dialog: Pamet → Vyvolat → A', (tester) async {
      final state = await pumpApp(tester);
      state.setMemoryForTest('A', 230.0);
      state.setDisplayForTest('', 0);
      await tester.pump();
      await openQuickMemory(tester);
      await tester.tap(textAny(['Vyvolat proměnnou', 'Recall variable']));
      await tester.pumpAndSettle();
      expect(
        textAny(['Vyvolat proměnnou:', 'Recall variable:']),
        findsOneWidget,
      );
      await tester.tap(dialogText('A'));
      await tester.pumpAndSettle();
      expect(state.displayForTest, contains('230'));
    });

    testWidgets('11. Prehled zobrazuje aktualni hodnoty', (tester) async {
      final state = await pumpApp(tester);
      state.setMemoryForTest('A', 230.0);
      state.setMemoryForTest('B', 245.0);
      await tester.pump();
      await openQuickMemory(tester);
      await tester.tap(textAny(['Přehled proměnných', 'Show variables']));
      await tester.pumpAndSettle();
      expect(
        textAny(['Přehled proměnných', 'Variables overview']),
        findsWidgets,
      );
      final semanticsA = find.bySemanticsLabel(
        RegExp('Proměnná A.*230|Variable A.*230'),
      );
      expect(semanticsA, findsOneWidget);
    });
  });

  group('Rychla pamet ve vsech rezimech', () {
    testWidgets('8. Dialog lze otevrit ze vsech hlavnich rezimu', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      for (final mode in CalculatorMode.values) {
        state.switchModeForTest(mode);
        await tester.pumpAndSettle();
        expect(
          memoryAppBarButton(),
          findsOneWidget,
          reason: 'Paměť chybí v AppBaru režimu $mode',
        );
        await tester.tap(memoryAppBarButton());
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(dialogText('A'), findsOneWidget);
        await tester.tap(textAny(['ZAVŘÍT', 'CLOSE']));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      }
    });
  });

  group('Legacy cesta zustava funkcni', () {    testWidgets('12. Advanced Functions → STO → A stale funguje', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('10', 2);
      await tester.pump();
      final advancedBtn = find.widgetWithIcon(IconButton, Icons.list);
      expect(advancedBtn, findsOneWidget);
      await tester.tap(advancedBtn);
      await tester.pumpAndSettle();
      // Memory sekce je defaultně sbalená (_CollapsibleSection) – rozbalit.
      await tester.tap(textAny(['Paměť', 'Memory']));
      await tester.pumpAndSettle();
      expect(find.text('STO'), findsOneWidget);
      await tester.tap(find.text('STO'));
      await tester.pumpAndSettle();
      // Cílová proměnná v Memory sekci dialogu.
      expect(dialogText('A'), findsOneWidget);
      await tester.tap(dialogText('A'));
      await tester.pumpAndSettle();
      expect(state.memoryForTest['A'], 10.0);
    });
  });
}
