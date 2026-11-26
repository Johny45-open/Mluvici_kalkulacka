import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test přístupnosti přepínače režimů: čtečka obrazovky musí projít
/// po všech chipech bez uvíznutí a každý chip musí být čitelné
/// tlačítko s akcí onTap (i ten vybraný).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Názvy režimů podle cs lokalizace (l10n modeBasic … modeCurrency).
  const modeLabels = <String>{
    'Základní',
    'Vědecká',
    'Statistika',
    'Elektro',
    'Převody jednotek',
    'Čas',
    'Měna',
  };

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'modeQuestionAsked': true,
    });
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
      MethodCall call,
    ) async {
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

  /// Najde sémantické uzly chipů přepínače režimů.
  List<SemanticsNode> findModeChipNodes(WidgetTester tester) {
    final owner = tester.binding.pipelineOwner.semanticsOwner;
    if (owner == null) return [];

    final chipNodes = <SemanticsNode>[];
    void visit(SemanticsNode node) {
      final d = node.getSemanticsData();
      if (d.hasFlag(SemanticsFlag.isButton) && modeLabels.contains(d.label)) {
        chipNodes.add(node);
      }
      node.visitChildren((c) {
        visit(c);
        return true;
      });
    }

    visit(owner.rootSemanticsNode!);
    return chipNodes;
  }

  /// Chipy leží v vodorovném scrollu – mimo obrazovku 412 px by na ně
  /// `tap()` nedosáhl. Nejdřív ho zviditelníme.
  Future<void> tapChip(WidgetTester tester, Finder chip) async {
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  testWidgets('všechny chipy přepínače režimů mají onTap a focusable', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester);

    final chipNodes = findModeChipNodes(tester);
    // Musíme najít všech 7 režimů.
    expect(chipNodes.length, equals(7),
        reason: 'Přepínač režimů musí mít 7 chipů');

    for (final node in chipNodes) {
      final d = node.getSemanticsData();
      // Každý chip musí mít onTap akci (i vybraný).
      expect(d.hasAction(SemanticsAction.tap), isTrue,
          reason: 'Chip "${d.label}" musí mít onTap akci');
      // Každý chip musí být button.
      expect(d.hasFlag(SemanticsFlag.isButton), isTrue,
          reason: 'Chip "${d.label}" musí být button');
      // Každý chip musí být focusable.
      expect(d.hasFlag(SemanticsFlag.isFocusable), isTrue,
          reason: 'Chip "${d.label}" musí být focusable');
    }

    // Právě jeden chip musí být vybraný.
    final selectedChips = chipNodes.where((n) {
      return n.getSemanticsData().hasFlag(SemanticsFlag.isSelected);
    }).toList();
    expect(selectedChips.length, equals(1),
        reason: 'Právě jeden chip musí být vybraný');

    handle.dispose();
  });

  testWidgets('aktivace nevybraného chipu přepne režim', (tester) async {
    final handle = tester.ensureSemantics();
    final state = await pumpApp(tester);

    // Výchozí režim je scientific.
    expect((state as dynamic).currentModeForTest,
        equals(CalculatorMode.scientific));

    // Tapneme na chip „Základní" (nevybraný).
    final basicChip = find.widgetWithText(ChoiceChip, 'Základní');
    expect(basicChip, findsOneWidget);
    await tapChip(tester, basicChip);

    // Režim se musí přepnout.
    expect((state as dynamic).currentModeForTest,
        equals(CalculatorMode.basic));

    handle.dispose();
  });

  testWidgets('aktivace vybraného chipu nepřepne režim', (tester) async {
    final handle = tester.ensureSemantics();
    final state = await pumpApp(tester);

    // Výchozí režim je scientific.
    expect((state as dynamic).currentModeForTest,
        equals(CalculatorMode.scientific));

    // Tapneme na chip „Vědecká" (vybraný) – leží za hranou 412 px.
    final sciChip = find.widgetWithText(ChoiceChip, 'Vědecká');
    expect(sciChip, findsOneWidget);
    await tapChip(tester, sciChip);

    // Režim se nesmí změnit.
    expect((state as dynamic).currentModeForTest,
        equals(CalculatorMode.scientific));

    handle.dispose();
  });

  testWidgets('po přepnutí režimu nový vybraný chip má stále onTap', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester);

    // Přepneme na Základní.
    final basicChip = find.widgetWithText(ChoiceChip, 'Základní');
    await tapChip(tester, basicChip);

    // Všechny chipy musí mít onTap i po přepnutí.
    final chipNodes = findModeChipNodes(tester);
    expect(chipNodes.length, equals(7));
    for (final node in chipNodes) {
      final d = node.getSemanticsData();
      expect(d.hasAction(SemanticsAction.tap), isTrue,
          reason: 'Chip "${d.label}" musí mít onTap i po přepnutí režimu');
    }

    // Nový vybraný chip musí být „Základní".
    final selectedChips = chipNodes.where((n) {
      return n.getSemanticsData().hasFlag(SemanticsFlag.isSelected);
    }).toList();
    expect(selectedChips.length, equals(1));
    expect(selectedChips.first.getSemanticsData().label, equals('Základní'));

    handle.dispose();
  });

  testWidgets('Tab traversal projde přes přepínač bez uvíznutí', (
    tester,
  ) async {
    await pumpApp(tester);

    // Projdeme 20 Tabů a sledujeme, že fokus nenulový a neuvízneme.
    final visited = <String>{};
    for (var i = 0; i < 20; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final pf = FocusManager.instance.primaryFocus;
      expect(pf, isNotNull, reason: 'Tab $i: fokus nesmí být null');
      visited.add(pf!.debugLabel ?? 'unlabeled-${pf.hashCode}');
    }
    // Měli jsme navštívit více než 2 různé uzly (ne uvíznutí v cyklu 1-2).
    expect(visited.length, greaterThan(2),
        reason: 'Tab traversal musí projít více uzlů');
    expect(tester.takeException(), isNull);
  });
}
