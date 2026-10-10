import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Testy rychlého přístupu k paměti: velké textové tlačítko „Paměť"
/// v hlavní pracovní ploše (nikoli AppBar), dialog Paměť → A,
/// reuse business logiky STO/RCL, persistence `memoryVariables`,
/// přehled, mazání s výčtem proměnných a legacy Advanced cesta.
Finder memoryEntryButton() =>
    find.byKey(const ValueKey('memory_entry_button'));

/// Najde [Text] s libovolným z daných řetězců (cs/en varianta).
Finder textAny(List<String> options) => find.byWidgetPredicate(
  (w) => w is Text && w.data != null && options.contains(w.data),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const memoryVars = ['A', 'B', 'C', 'D', 'E', 'F', 'X', 'Y', 'M'];

  /// Zachycené vlastní TTS promluvy (Z2-10).
  final List<String> ttsLog = [];

  setUp(() {
    ttsLog.clear();
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
      (MethodCall call) async {
        if (call.method == 'speak') {
          ttsLog.add(call.arguments as String? ?? '');
        }
        return null;
      },
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
    expect(memoryEntryButton(), findsOneWidget);
    await tester.tap(memoryEntryButton());
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  }

  Finder dialogText(String value) => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.text(value),
  );

  group('Quick memory body entry point (not AppBar)', () {
    testWidgets('1. Velke textove tlacitko Pamet existuje v body', (tester) async {
      await pumpApp(tester);
      expect(memoryEntryButton(), findsOneWidget);
      expect(textAny(['Paměť', 'Memory']), findsWidgets);
    });

    testWidgets('1b. Pamet NENI v AppBaru', (tester) async {
      await pumpApp(tester);
      expect(
        find.widgetWithIcon(IconButton, Icons.memory),
        findsNothing,
      );
    });

    testWidgets('2. Tlacitko ma spravny accessibility label', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(memoryEntryButton(), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          RegExp('Paměť, otevře paměťové proměnné|Memory, opens memory variables'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('3. Dialog se otevre ve vychozim rezimu Vlozit', (tester) async {
      await pumpApp(tester);
      await openQuickMemory(tester);
      // Nadpis dialogu + heading pro vložení (default, ne ukládání).
      expect(textAny(['Paměť', 'Memory']), findsWidgets);
      expect(
        textAny([
          'Vložit proměnnou do výrazu:',
          'Insert variable into expression:',
        ]),
        findsOneWidget,
      );
    });

    testWidgets('3b. Zalozka Ulozit zobrazi ukladaci nadpis', (tester) async {
      await pumpApp(tester);
      await openQuickMemory(tester);
      await tester.tap(textAny(['Uložit hodnotu', 'Store value']));
      await tester.pumpAndSettle();
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

    testWidgets('4b. Hlavni klavesnice zustava 4x7 rastr', (tester) async {
      await pumpApp(tester);
      // Tlačítko Paměť je mimo keypad_grid, rastr má 7 řádků.
      expect(find.byKey(const ValueKey('keypad_grid')), findsOneWidget);
      for (var r = 0; r < 7; r++) {
        expect(
          find.byKey(ValueKey('keypad_row_$r')),
          findsOneWidget,
          reason: 'řádek klávesnice $r chybí',
        );
      }
      expect(memoryEntryButton(), findsOneWidget);
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

    testWidgets('Pamet → zalozka Ulozit → B ulozi vyhodnoceny vyraz', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12*20+5', 7);
      await tester.pump();
      // Cesta rychlého dialogu: Paměť → Uložit hodnotu → B.
      await tester.tap(memoryEntryButton());
      await tester.pumpAndSettle();
      await tester.tap(textAny(['Uložit hodnotu', 'Store value']));
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

  group('Mazani s vypisem konkretnich promennych', () {
    testWidgets('Smazani A, C, M oznami ktere promenne byly smazany', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      state.setMemoryForTest('A', 10.0);
      state.setMemoryForTest('C', 30.0);
      state.setMemoryForTest('M', 50.0);
      await tester.pump();
      await openQuickMemory(tester);
      await tester.tap(textAny(['Vymazat paměť', 'Clear memory']));
      await tester.pumpAndSettle();
      // Potvrzovací dialog existujícího flow.
      expect(find.byType(AlertDialog), findsWidgets);
      await tester.tap(textAny(['ANO, SMAZAT', 'YES, CLEAR']));
      await tester.pumpAndSettle();
      expect(state.memoryForTest['A'], 0.0);
      expect(state.memoryForTest['C'], 0.0);
      expect(state.memoryForTest['M'], 0.0);
      // SnackBar s výčtem smazaných proměnných.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.data != null &&
              w.data!.contains('A') &&
              w.data!.contains('C') &&
              w.data!.contains('M'),
        ),
        findsWidgets,
      );
    });

    testWidgets('Prazdna pamet zachova stavajici chovani', (tester) async {
      final state = await pumpApp(tester);
      for (final v in memoryVars) {
        state.setMemoryForTest(v, 0.0);
      }
      await tester.pump();
      await openQuickMemory(tester);
      await tester.tap(textAny(['Vymazat paměť', 'Clear memory']));
      await tester.pumpAndSettle();
      // Žádný potvrzovací dialog, jen hláška o prázdné paměti.
      expect(
        textAny(['Paměť je již prázdná.', 'Memory is already empty.']),
        findsOneWidget,
      );
    });
  });

  group('Rychla pamet ve vsech rezimech', () {
    testWidgets('Dialog lze otevrit ze vsech hlavnich rezimu', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      for (final mode in CalculatorMode.values) {
        state.switchModeForTest(mode);
        await tester.pumpAndSettle();
        expect(
          memoryEntryButton(),
          findsOneWidget,
          reason: 'Paměť chybí v body režimu $mode',
        );
        await tester.tap(memoryEntryButton());
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(dialogText('A'), findsOneWidget);
        await tester.tap(textAny(['ZAVŘÍT', 'CLOSE']));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      }
    });

    testWidgets('Zmena rezimu zrusi rozpracovane STO', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('42', 2);
      await tester.pump();
      await state.handleButtonPressedForTest('STO');
      expect(state.isStoreModeForTest, isTrue);
      state.switchModeForTest(CalculatorMode.basic);
      await tester.pump();
      expect(state.isStoreModeForTest, isFalse);
      expect(state.isRecallModeForTest, isFalse);
      // Tap proměnné nyní vloží písmeno do výrazu, nic neuloží.
      await state.handleButtonPressedForTest('A');
      await tester.pump();
      expect(state.memoryForTest['A'], 0.0);
      expect(state.displayForTest, contains('A'));
    });

    testWidgets('Zmena rezimu zrusi rozpracovane RCL', (tester) async {
      final state = await pumpApp(tester);
      await state.handleButtonPressedForTest('RCL');
      expect(state.isRecallModeForTest, isTrue);
      state.switchModeForTest(CalculatorMode.statistics);
      await tester.pump();
      expect(state.isStoreModeForTest, isFalse);
      expect(state.isRecallModeForTest, isFalse);
    });
  });

  group('Legacy cesta zustava funkcni', () {
    testWidgets('12. Advanced Functions → STO → A stale funguje', (
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
      // Scope na dialog: body tlačítko „Paměť" je stále ve stromu za dialogem.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: textAny(['Paměť', 'Memory']),
        ),
      );
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

  group('Vlozit promennou (vychozi rezim)', () {
    testWidgets('Vlozeni A vlozi symbol, ne hodnotu', (tester) async {
      final state = await pumpApp(tester);
      state.setMemoryForTest('A', 10.0);
      state.setDisplayForTest('', 0);
      await tester.pump();
      await tester.tap(memoryEntryButton());
      await tester.pumpAndSettle();
      // Výchozí režim: vložení (otevření dialogu neukládá).
      expect(
        textAny([
          'Vložit proměnnou do výrazu:',
          'Insert variable into expression:',
        ]),
        findsOneWidget,
      );
      await tester.tap(dialogText('A'));
      await tester.pumpAndSettle();
      expect(state.displayForTest, contains('A'));
      expect(state.memoryForTest['A'], 10.0);
    });

    testWidgets('A*5 zustane symbolicky a spocita 50', (tester) async {
      final state = await pumpApp(tester);
      state.setMemoryForTest('A', 10.0);
      state.setDisplayForTest('A*5', 3);
      await tester.pump();
      state.calculateForTest();
      await tester.pumpAndSettle();
      expect(state.lastNumericForTest, 50.0);
    });
  });

  group('Z2 dialog Pamet: rezim, kontext a fokus', () {
    /// Všechny uzly Semantics stromu v DFS pořadí.
    List<SemanticsNode> allSemanticsNodes(WidgetTester tester) {
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

    /// Segmentové popisky přepínače režimů (cs/en podle locale testu).
    const insertLabels = {'Vložit proměnnou', 'Insert variable'};
    const storeLabels = {'Uložit hodnotu', 'Store value'};
    const recallLabels = {'Vyvolat proměnnou', 'Recall variable'};

    /// Primární fokus leží uvnitř otevřeného dialogu.
    bool primaryFocusInsideDialog() {
      final primary = FocusManager.instance.primaryFocus;
      if (primary == null || primary.context == null) return false;
      try {
        return primary.context!.findAncestorWidgetOfExactType<AlertDialog>() !=
            null;
      } catch (_) {
        return false;
      }
    }

    bool memoryIsEmpty(dynamic state) =>
        memoryVars.every((v) => (state.memoryForTest[v] as double) == 0.0);

    testWidgets('Z2-1. vychozi rezim insert, otevreni nic nemeni',
        (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('', 0);
      await tester.pump();
      await openQuickMemory(tester);
      // Nadpis + heading vložení, instrukce o neškodném otevření.
      expect(textAny(['Paměť', 'Memory']), findsWidgets);
      expect(
        textAny([
          'Vložit proměnnou do výrazu:',
          'Insert variable into expression:',
        ]),
        findsOneWidget,
      );
      expect(
        textAny([
          'Vyberte operaci s pamětí. Samotné otevření dialogu nic nemění.',
          'Choose a memory operation. Opening the dialog changes nothing.',
        ]),
        findsOneWidget,
      );
      expect(memoryIsEmpty(state), isTrue);
      expect(state.displayForTest, '');
      // SegmentedButton nese vybraný insert (typový parametr je privátní,
      // proto raw predicate + toString enum hodnoty).
      final segFinder = find.byWidgetPredicate((w) => w is SegmentedButton);
      expect(segFinder, findsOneWidget);
      final seg = tester.widget<SegmentedButton<dynamic>>(segFinder);
      expect(seg.selected, hasLength(1));
      expect(seg.selected.single.toString(), contains('insert'));
    });

    testWidgets('Z2-2. vybrany rezim je selected, ne disabled', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpApp(tester);
        await openQuickMemory(tester);
        // Skupinové uzly (mutex): label + selected + enabled na jednom uzlu.
        // Pozn.: isSelected/isEnabled jsou Tristate (dart:ui).
        final mutexNodes = allSemanticsNodes(tester).where((n) {
          final d = n.getSemanticsData();
          return d.flagsCollection.isInMutuallyExclusiveGroup &&
              (insertLabels.contains(d.label) ||
                  storeLabels.contains(d.label) ||
                  recallLabels.contains(d.label));
        }).toList();
        expect(mutexNodes, hasLength(3), reason: 'Tři režimy ve skupině');
        bool isSel(SemanticsNode n) =>
            n.getSemanticsData().flagsCollection.isSelected ==
            Tristate.isTrue;
        for (final s in mutexNodes) {
          // Žádný režim nesmí být prezentován jako zakázaný.
          expect(
            s.getSemanticsData().flagsCollection.isEnabled == Tristate.isTrue,
            isTrue,
          );
        }
        bool isInsert(SemanticsNode n) =>
            insertLabels.contains(n.getSemanticsData().label);
        expect(mutexNodes.where(isSel), hasLength(1));
        expect(isInsert(mutexNodes.singleWhere(isSel)), isTrue);
        // Tlačítkové uzly režimů existují s přesnými popisky, všechny enabled.
        final buttonLabels = allSemanticsNodes(tester)
            .where(
              (n) =>
                  n.getSemanticsData().flagsCollection.isButton == true &&
                  (insertLabels.contains(n.getSemanticsData().label) ||
                      storeLabels.contains(n.getSemanticsData().label) ||
                      recallLabels.contains(n.getSemanticsData().label)),
            )
            .map((n) => n.getSemanticsData().label)
            .toSet();
        expect(buttonLabels.length, 3);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('Z2-3. prepnuti rezimu meni obsah, neprovadi operaci',
        (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('', 0);
      await tester.pump();
      await openQuickMemory(tester);

      await tester.tap(textAny(['Uložit hodnotu', 'Store value']));
      await tester.pumpAndSettle();
      expect(
        textAny(['Uložit aktuální hodnotu do:', 'Save current value to:']),
        findsOneWidget,
      );
      expect(memoryIsEmpty(state), isTrue);
      expect(state.displayForTest, '');

      await tester.tap(textAny(['Vyvolat proměnnou', 'Recall variable']));
      await tester.pumpAndSettle();
      expect(
        textAny(['Vyvolat proměnnou:', 'Recall variable:']),
        findsOneWidget,
      );
      expect(memoryIsEmpty(state), isTrue);
      expect(state.displayForTest, '');

      await tester.tap(textAny(['Vložit proměnnou', 'Insert variable']));
      await tester.pumpAndSettle();
      expect(
        textAny([
          'Vložit proměnnou do výrazu:',
          'Insert variable into expression:',
        ]),
        findsOneWidget,
      );
      expect(memoryIsEmpty(state), isTrue);
      // Dialog je stále otevřený — přepnutí nic nezavřelo ani neuložilo.
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('Z2-4. titulek a instrukce v semantickem stromu',
        (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpApp(tester);
        await openQuickMemory(tester);
        final nodes = allSemanticsNodes(tester);
        final titles = nodes.where(
          (n) =>
              n.getSemanticsData().label == 'Paměť' ||
              n.getSemanticsData().label == 'Memory',
        );
        expect(titles, hasLength(1));
        expect(
          titles.single.getSemanticsData().flagsCollection.isHeader,
          isTrue,
        );
        final instructions = nodes.where(
          (n) =>
              n.getSemanticsData().label.contains('Samotné otevření') ||
              n.getSemanticsData().label.contains('changes nothing'),
        );
        expect(instructions, hasLength(1));
      } finally {
        handle.dispose();
      }
    });

    testWidgets('Z2-5. prvni fokus je deterministicky, nic se nespusti',
        (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('', 0);
      await tester.pump();
      await openQuickMemory(tester);
      // Standardní cesta AlertDialogu: primární fokus drží scope dialogu
      // (nikoli hlavní klávesnice), první Tab vede dovnitř obsahu.
      final primary = FocusManager.instance.primaryFocus;
      expect(primary, isNotNull);
      expect(
        primary,
        isNot(state.mainFocusNodeForTest as FocusNode),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(primaryFocusInsideDialog(), isTrue);
      // Žádná operace se automaticky nespustila.
      expect(
        memoryVars.every((v) => (state.memoryForTest[v] as double) == 0.0),
        isTrue,
      );
      expect(state.displayForTest, '');
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('Z2-7. zavreni vrati fokus dle mechanismu', (tester) async {
      final state = await pumpApp(tester);
      await openQuickMemory(tester);
      await tester.tap(textAny(['ZAVŘÍT', 'CLOSE']));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      // Obnova fokusu (observer 150 ms + _returnFocusToKeyboard).
      await tester.pump(const Duration(milliseconds: 300));
      final FocusNode main = state.mainFocusNodeForTest as FocusNode;
      expect(
        FocusManager.instance.primaryFocus,
        main,
        reason: 'Fokus se vrátil na hlavní uzel klávesnice',
      );
    });

    testWidgets('Z2-8. vnorene dialogy a _dialogDepth ze Z1', (tester) async {
      final state = await pumpApp(tester);
      state.setMemoryForTest('A', 10.0);
      await tester.pump();
      await openQuickMemory(tester);
      expect(state.dialogDepthForTest, 1);
      // Vnořený potvrzovací dialog vymazání.
      await tester.tap(textAny(['Vymazat paměť', 'Clear memory']));
      await tester.pumpAndSettle();
      expect(state.dialogDepthForTest, 2);
      expect(find.byType(AlertDialog), findsWidgets);
      // Zavřít jen vnořený…
      Navigator.of(state.contextForTest as BuildContext).pop();
      await tester.pumpAndSettle();
      expect(state.dialogDepthForTest, 1);
      // …pak i vnější, fokus se obnoví.
      Navigator.of(state.contextForTest as BuildContext).pop();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.dialogDepthForTest, 0);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('Z2-9. otevreni negeneruje duplicitni oznameni', (tester) async {
      final state = await pumpApp(tester);
      state.updateActiveSettingsForTest(
        (s) => s.copyWith(screenReaderMode: ScreenReaderMode.on),
      );
      await tester.pumpAndSettle();
      expect(state.isScreenReaderActiveForTest, isTrue);
      final before = state.lastAnnouncementForTest as String;
      await openQuickMemory(tester);
      // Aplikační kanál při otevření nic nepublikuje (žádný speak/announce).
      expect(state.lastAnnouncementForTest as String, before);
      // Přepnutí režimu je při aktivní čtečce rovněž tiché (segment oznámí
      // sama čtečka skrze selected sémantiku).
      await tester.tap(textAny(['Uložit hodnotu', 'Store value']));
      await tester.pumpAndSettle();
      expect(state.lastAnnouncementForTest as String, before);
      expect(ttsLog, isEmpty);
      // Opakovaný tap aktivního segmentu: ticho.
      await tester.tap(textAny(['Uložit hodnotu', 'Store value']));
      await tester.pumpAndSettle();
      expect(state.lastAnnouncementForTest as String, before);
      expect(ttsLog, isEmpty);
    });

    testWidgets('Z2-10. zmena rezimu bez ctecky oznami prave jednou',
        (tester) async {
      final state = await pumpApp(tester);
      state.updateActiveSettingsForTest(
        (s) => s.copyWith(screenReaderMode: ScreenReaderMode.off),
      );
      await tester.pumpAndSettle();
      expect(state.isScreenReaderActiveForTest, isFalse);
      await openQuickMemory(tester);
      // Otevření s neaktivní čtečkou oznámí hlas kalkulačky právě jednou
      // (titul + instrukce + výchozí režim).
      expect(ttsLog, hasLength(1));
      expect(
        ttsLog.single.contains('Paměť') || ttsLog.single.contains('Memory'),
        isTrue,
      );

      // Přepnutí insert → store: právě jedna další TTS promluva s nadpisem.
      await tester.tap(textAny(['Uložit hodnotu', 'Store value']));
      await tester.pumpAndSettle();
      expect(ttsLog, hasLength(2));
      expect(
        ttsLog.last.contains('Uložit') || ttsLog.last.contains('Save'),
        isTrue,
      );
      // Semantics kanál mlčí (žádná čtečka).
      final announced = state.lastAnnouncementForTest as String;
      // Opakovaný tap aktivního segmentu: ticho, žádná operace.
      await tester.tap(textAny(['Uložit hodnotu', 'Store value']));
      await tester.pumpAndSettle();
      expect(ttsLog, hasLength(2));
      expect(state.lastAnnouncementForTest as String, announced);
      // Přepnutí na recall: opět právě jedna nová promluva.
      await tester.tap(textAny(['Vyvolat proměnnou', 'Recall variable']));
      await tester.pumpAndSettle();
      expect(ttsLog, hasLength(3));
      expect(
        ttsLog.last.contains('Vyvolat') || ttsLog.last.contains('Recall'),
        isTrue,
      );
    });
  });
}
