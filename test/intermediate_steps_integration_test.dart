import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/intermediate_evaluation.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'accessibilityType': 0,
      'modeQuestionAsked': true,
    });

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final docsDir = Directory.systemTemp.createTempSync('intermediate_steps');
    addTearDown(() {
      try {
        docsDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => call.method == 'getApplicationDocumentsDirectory'
          ? docsDir.path
          : null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.example.mluvici_kalkulacka/accessibility'),
      (call) async => false,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (call) async => <String, Object>{
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
    // Inicializace TTS plánuje uvítací timer; necháme jej doběhnout, aby po
    // testu nezůstal v fake async smyčce.
    await tester.pump(const Duration(seconds: 3));
    return tester.state(find.byType(CalculatorScreen)) as dynamic;
  }

  Future<void> openIntermediateSteps(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.account_tree_outlined));
    await tester.pumpAndSettle();
  }

  Finder noStepsMessage() => find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        (widget.data == 'Výraz neobsahuje mezivýpočty.' ||
            widget.data == 'The expression has no intermediate steps.'),
  );

  const expression = '(-2)^2+4*(-2)-6';
  const expectedSteps = <String>[
    '(-2)^2 = 4',
    '4*(-2) = -8',
    '4+-8 = -4',
    '-4-6 = -10',
  ];

  testWidgets('skutečný evaluator vrací všechny kroky záporného výrazu', (
    tester,
  ) async {
    final state = await pumpApp(tester);
    final result = IntermediateEvaluator.computeIntermediateSteps(
      expression: expression,
      evaluator: state.evaluateExpressionForTest,
      formatter: (value) => value == value.truncateToDouble()
          ? value.toInt().toString()
          : value.toString(),
      spokenFormatter: (value) => value.toString(),
    );

    expect(result.hasError, isFalse);
    expect(result.steps.map((step) => step.stepDescription), expectedSteps);
    expect(result.finalValue, -10.0);
  });

  testWidgets('po výpočtu se mezikroky opírají o původní výraz', (
    tester,
  ) async {
    final state = await pumpApp(tester);
    state.setDisplayForTest(expression, expression.length);
    state.calculateForTest();
    await tester.pump();

    expect(state.lastResultForTest, '-10');
    expect(state.displayForTest, isEmpty);

    // Simuluje cestu, kdy displej obsahuje pouze výsledek, ale výpočetní stav
    // stále označuje poslední výsledek jako platný.
    state.setDisplayForTest('-10', 3);
    await openIntermediateSteps(tester);

    for (final step in expectedSteps) {
      expect(find.text(step), findsOneWidget);
    }
    expect(find.text('Výraz neobsahuje mezivýpočty.'), findsNothing);
  });

  testWidgets('před výpočtem se použije aktuální výraz na displeji', (
    tester,
  ) async {
    final state = await pumpApp(tester);
    state.setDisplayForTest(expression, expression.length);
    await openIntermediateSteps(tester);

    for (final step in expectedSteps) {
      expect(find.text(step), findsOneWidget);
    }
  });

  testWidgets('jednoduchý výraz bez skutečných mezikroků zůstane prázdný', (
    tester,
  ) async {
    final state = await pumpApp(tester);
    state.setDisplayForTest('123+456', 7);
    await openIntermediateSteps(tester);

    expect(noStepsMessage(), findsOneWidget);
  });

  testWidgets('clear zabrání použití výrazu z předchozího výpočtu', (
    tester,
  ) async {
    final state = await pumpApp(tester);
    state.setDisplayForTest(expression, expression.length);
    state.calculateForTest();
    await tester.pump();
    state.clearForTest();
    state.setDisplayForTest('123+456', 7);
    await openIntermediateSteps(tester);

    expect(noStepsMessage(), findsOneWidget);
    for (final step in expectedSteps) {
      expect(find.text(step), findsNothing);
    }
  });
}
