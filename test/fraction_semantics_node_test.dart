import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Regresní test pro NVDA/odečítače: čte se SEMANTICKÝ STROM, ne widgety.
// TextButton je vlastní sémantická hranice (button_style_button.dart), takže
// přístupný název musí ležet na Text.semanticsLabel UVNITŘ TextButtonu –
// jinak vzniká druhý parazitní „button" uzel bez akce tap, kam se název a
// stav přesunou nahoru (doloženo auditní sondou před opravou: parazitní
// uzel s bohatým názvem BEZ tap + reálný TextButton jen s vizuálním
// textem = dvojí položka v objektové navigaci, stav mimo aktivovatelný
// uzel). Test je jazykově neutrální – popisky bere z widgetu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void mockChannels() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (MethodCall call) async => null,
    );
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
  }

  Future<dynamic> pumpApp(
    WidgetTester tester, {
    Size size = const Size(412, 860),
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'modeQuestionAsked': true,
    });
    mockChannels();
    tester.platformDispatcher.clearAllTestValues();
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

  /// Všechny uzly stromu (to, co NVDA skutečně vidí).
  List<SemanticsNode> allSemanticsNodes(WidgetTester tester) {
    final root =
        tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!;
    final nodes = <SemanticsNode>[];
    void walk(SemanticsNode node) {
      nodes.add(node);
      node.visitChildren((SemanticsNode child) {
        walk(child);
        return true;
      });
    }

    walk(root);
    return nodes;
  }

  /// Plný přístupný název tak, jak ho dodává implementace (Text.semanticsLabel).
  String fullSemanticsLabel(WidgetTester tester, ValueKey<String> key) {
    final text = tester.widget<Text>(
      find.descendant(of: find.byKey(key), matching: find.byType(Text)).first,
    );
    expect(text.semanticsLabel, isNotNull);
    return text.semanticsLabel!;
  }

  String describe(SemanticsNode n) =>
      '[${n.label}] flags=${n.getSemanticsData().flagsCollection}';

  group('Sémantický strom zlomkových tlačítek (uzly, ne widgety)', () {
    testWidgets(
        '1. Vložit zlomek: právě jeden uzel, button + focusable + tap', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpApp(tester);
        const key = ValueKey<String>('fraction_insert');
        final label = fullSemanticsLabel(tester, key);
        final nodes = allSemanticsNodes(tester);

        final matching = nodes.where((n) => n.label == label).toList();
        expect(
          matching,
          hasLength(1),
          reason:
              'Přístupný název smí nést právě jeden uzel (jinak NVDA hlásí '
              'dvě tlačítkové položky). Nalezeno: '
              '${matching.map(describe).join(' | ')}',
        );
        final node = matching.single;
        expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
        expect(node.hasFlag(SemanticsFlag.isFocusable), isTrue);
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        // Parazitní uzel: tlačítko bez akce tap s týmž názvem.
        final parasitic = nodes
            .where(
              (n) =>
                  n != node &&
                  n.hasFlag(SemanticsFlag.isButton) &&
                  !n.getSemanticsData().hasAction(SemanticsAction.tap) &&
                  n.label.contains(label),
            )
            .toList();
        expect(
          parasitic,
          isEmpty,
          reason:
              'Žádný druhý „button" uzel bez tap s týmž názvem. '
              'Nalezeno: ${parasitic.map(describe).join(' | ')}',
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets(
        '2. Přepínač: právě jeden uzel nese plný název se stavem '
        '(button, focusable, tap)', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final state = await pumpApp(tester);
        await calculate(tester, state, '1/3');

        const key = ValueKey<String>('fraction_toggle');
        final richLabel = fullSemanticsLabel(tester, key);
        // Bohatý název = vizuální text + tečkované doplnění stavu
        // (viz _buildFractionToggle: semanticLabel = '$visualText. $base. $back').
        expect(richLabel, contains('. '), reason: 'label má být bohatý');

        final nodes = allSemanticsNodes(tester);
        final sameLabel = nodes.where((n) => n.label == richLabel).toList();
        expect(
          sameLabel,
          hasLength(1),
          reason:
              'Plný název přepínače musí být právě na jednom uzlu. '
              'Nalezeno: ${sameLabel.map(describe).join(' | ')}',
        );
        final node = sameLabel.single;
        expect(
          node.hasFlag(SemanticsFlag.isButton),
          isTrue,
          reason: 'Uzel s plným názvem musí být aktivovatelné tlačítko',
        );
        expect(node.hasFlag(SemanticsFlag.isFocusable), isTrue);
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        // Vizuální text nesmí být na samostatném druhém uzlu (dvojí čtení).
        final visual = nodes
            .where(
              (n) =>
                  n.label == richLabel.split('. ').first && n.label != richLabel,
            )
            .toList();
        expect(
          visual,
          isEmpty,
          reason:
              'Vizuální text nesmí nést jiný uzel než tlačítko. '
              'Nalezeno: ${visual.map(describe).join(' | ')}',
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('3. Po zapnutí zlomku: přepínací stav je na uzlu tlačítka', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        final state = await pumpApp(tester);
        await calculate(tester, state, '1/3');
        state.toggleFractionForTest();
        await tester.pumpAndSettle();

        const key = ValueKey<String>('fraction_toggle');
        final richLabel = fullSemanticsLabel(tester, key);
        final nodes = allSemanticsNodes(tester);
        final sameLabel = nodes.where((n) => n.label == richLabel).toList();
        expect(sameLabel, hasLength(1));
        final node = sameLabel.single;
        expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
        expect(node.hasFlag(SemanticsFlag.isToggled), isTrue);
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('4. Oba prvky = právě dva tlačítkové uzly, žádný parazit', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        final state = await pumpApp(tester);
        await calculate(tester, state, '1/3');
        final insertLabel = fullSemanticsLabel(
          tester,
          const ValueKey<String>('fraction_insert'),
        );
        final richLabel = fullSemanticsLabel(
          tester,
          const ValueKey<String>('fraction_toggle'),
        );
        final nodes = allSemanticsNodes(tester);
        final fragmentButtons = nodes
            .where(
              (n) =>
                  n.hasFlag(SemanticsFlag.isButton) &&
                  (n.label == insertLabel || n.label == richLabel),
            )
            .toList();
        expect(
          fragmentButtons,
          hasLength(2),
          reason:
              'Očekávány právě dva tlačítkové uzly (přepínač + vložit). '
              'Nalezeno: ${fragmentButtons.map(describe).join(' | ')}',
        );
        // Ani jeden z nich nesmí být „button" bez tap.
        final disabledLike = fragmentButtons
            .where((n) => !n.getSemanticsData().hasAction(SemanticsAction.tap))
            .toList();
        expect(
          disabledLike,
          isEmpty,
          reason:
              'Uzly bez akce tap nejsou aktivovatelné. '
              'Nalezeno: ${disabledLike.map(describe).join(' | ')}',
        );
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    });
  });
}