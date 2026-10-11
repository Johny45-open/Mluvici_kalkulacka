import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Z4: výsledkový displej je jedna sémantická položka; jedno gesto doprava
/// z něj vede na další prvek (kurzorový řádek), ne na vnitřní scroll-uzel.
///
/// Pořadí uzlů ve widgetovém testu NENÍ důkazem chování NVDA/TalkBacku —
/// finální verdikt patří ručnímu testu na zařízení. Testy zde ověřují
/// strukturální předpoklad: žádný bezlabelový scroll-uzel s akcemi
/// mezi výsledkem a následujícím prvkem.
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

  List<SemanticsNode> resultNodes(WidgetTester tester) => allNodes(
    tester,
  ).where((n) {
    final lbl = n.getSemanticsData().label;
    return lbl == 'Výsledek' || lbl == 'Result';
  }).toList();

  int indexOfLabel(List<SemanticsNode> nodes, bool Function(String) match) {
    for (var i = 0; i < nodes.length; i++) {
      if (match(nodes[i].getSemanticsData().label)) return i;
    }
    return -1;
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

  group('Z4 výsledek = jedna položka', () {
    testWidgets('1.+2. krátký výsledek: jeden uzel s plnou hodnotou',
        (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final state = await pumpApp(tester);
        await calculate(tester, state, '3/4');

        final results = resultNodes(tester);
        expect(results, hasLength(1));
        final data = results.single.getSemanticsData();
        expect(data.value.isNotEmpty, isTrue);
        expect(data.value, contains('0,75'));
        // Aktivační tap zůstal na uzlu výsledku.
        expect(data.hasAction(SemanticsAction.tap), isTrue);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('1.+2. dlouhý výsledek: jeden uzel s plnou hodnotou',
        (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final state = await pumpApp(tester);
        await calculate(tester, state, '123456789*987654321');

        final results = resultNodes(tester);
        expect(results, hasLength(1));
        final data = results.single.getSemanticsData();
        expect(data.value, contains('121932631112635264'));
        expect(data.hasAction(SemanticsAction.tap), isTrue);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('3. výsledková větev bez scrollLeft/scrollRight',
        (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final state = await pumpApp(tester);
        await calculate(tester, state, '123456789*987654321');

        final nodes = allNodes(tester);
        final resIdx = indexOfLabel(
          nodes,
          (l) => l == 'Výsledek' || l == 'Result',
        );
        expect(resIdx, greaterThanOrEqualTo(0));
        // Uzel výsledku ani jeho potomci (do dalšího labelovaného uzlu)
        // nesmí nést scroll-akce: jinak by čtečka zastavila na němém uzlu.
        var i = resIdx;
        expect(
          nodes[i].getSemanticsData().hasAction(SemanticsAction.scrollLeft),
          isFalse,
        );
        expect(
          nodes[i].getSemanticsData().hasAction(SemanticsAction.scrollRight),
          isFalse,
        );
        i++;
        while (i < nodes.length &&
            nodes[i].getSemanticsData().label.isEmpty) {
          expect(
            nodes[i].getSemanticsData().hasAction(SemanticsAction.scrollLeft),
            isFalse,
            reason: 'Bezlabelový potomek výsledku nesmí mít scrollLeft',
          );
          expect(
            nodes[i].getSemanticsData().hasAction(SemanticsAction.scrollRight),
            isFalse,
            reason: 'Bezlabelový potomek výsledku nesmí mít scrollRight',
          );
          i++;
        }
        // A hned za výsledkovou větví je kurzorový řádek, ne scroll-uzel.
        expect(nodes[i].getSemanticsData().label, 'Na začátek');
      } finally {
        handle.dispose();
      }
    });

    testWidgets('4. pořadí: Výsledek → Na začátek → zlomek → Paměť → klávesnice',
        (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final state = await pumpApp(tester);
        await calculate(tester, state, '3/4');

        final nodes = allNodes(tester);
        final resIdx = indexOfLabel(
          nodes,
          (l) => l == 'Výsledek' || l == 'Result',
        );
        final cursorIdx = indexOfLabel(
          nodes,
          (l) => l == 'Na začátek' || l == 'To start',
        );
        final fractionIdx = indexOfLabel(
          nodes,
          (l) => l.contains('Zlomek') || l.contains('Fraction'),
        );
        final memoryIdx = indexOfLabel(
          nodes,
          (l) => l.contains('Paměť') || l.contains('Memory'),
        );
        final equalsIdx = indexOfLabel(
          nodes,
          (l) => l == 'Rovná se' || l == 'Equals',
        );
        for (final e in {
          'Výsledek': resIdx,
          'Na začátek': cursorIdx,
          'Zlomek': fractionIdx,
          'Paměť': memoryIdx,
          'Rovná se': equalsIdx,
        }.entries) {
          expect(e.value, greaterThanOrEqualTo(0), reason: 'Chybí ${e.key}');
        }
        expect(resIdx, lessThan(cursorIdx));
        expect(cursorIdx, lessThan(fractionIdx));
        expect(fractionIdx, lessThan(memoryIdx));
        expect(memoryIdx, lessThan(equalsIdx));
      } finally {
        handle.dispose();
      }
    });

    testWidgets('6. dlouhý výsledek lze vizuálně horizontálně posouvat',
        (tester) async {
      final state = await pumpApp(tester);
      await calculate(tester, state, '123456789*987654321');

      // Scrollable výsledkového řádku: horizontální, se stejným controllerem.
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
      final before =
          tester.state<ScrollableState>(scrollable).position.pixels;
      expect(before, 0.0);

      // Tažení prstem po výsledku: offset se pohne, struktura drží.
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
  });
}
