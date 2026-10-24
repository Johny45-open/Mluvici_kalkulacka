import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regrese dosazování paměťových proměnných v `_evaluateExpression`.
///
/// Oprava: implicitní násobení (krok 4) musí proběhnout PO expanzi
/// placeholderů E-notace (krok 3) a PŘED dosazením proměnných (krok 5),
/// jinak se sousedící proměnné (4AC, 2A, AC) nedosadí — `\b` hranice
/// mezi slepenými písmeny neexistuje.
///
/// Ověřuje skutečné dosazení hodnot a číselné výsledky (ne jen absenci
/// výjimky), a to včetně odlišení E-notace od paměťové proměnné E
/// a ochrany názvů funkcí.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'accessibilityType': 0,
      'modeQuestionAsked': true,
    });

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    final docsDir = Directory.systemTemp.createTempSync('memsubst_docs');
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
    tester.platformDispatcher.clearAllTestValues();
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(const ScientificCalculatorApp());
    await tester.pumpAndSettle();

    return tester.state(find.byType(CalculatorScreen)) as dynamic;
  }

  group('sousedící paměťové proměnné (A=2, B=-3, C=1)', () {
    testWidgets('Bx²-4AC = B²-4AC = 1, 4AC = 8, AC = 2, 2A = 4', (tester) async {
      final state = await pumpApp(tester);
      state.setMemoryForTest('A', 2.0);
      state.setMemoryForTest('B', -3.0);
      state.setMemoryForTest('C', 1.0);

      // x² je dvouznakový glyf tlačítka (normalizace na ^2).
      expect(
        state.evaluateExpressionForTest('Bx²-4AC'),
        closeTo(1.0, 1e-9),
        reason: 'B²-4AC = 9-8',
      );
      expect(state.evaluateExpressionForTest('4AC'), closeTo(8.0, 1e-9));
      expect(state.evaluateExpressionForTest('AC'), closeTo(2.0, 1e-9));
      expect(state.evaluateExpressionForTest('2A'), closeTo(4.0, 1e-9));
    });

    testWidgets('A+B+C = 0, (A+B)x² = 1, A^(B+3) = 1', (tester) async {
      final state = await pumpApp(tester);
      state.setMemoryForTest('A', 2.0);
      state.setMemoryForTest('B', -3.0);
      state.setMemoryForTest('C', 1.0);

      expect(
        state.evaluateExpressionForTest('A+B+C'),
        closeTo(0.0, 1e-9),
        reason: '2 + (-3) + 1',
      );
      expect(
        state.evaluateExpressionForTest('(A+B)x²'),
        closeTo(1.0, 1e-9),
        reason: '(2 + (-3))² = (-1)²',
      );
      expect(
        state.evaluateExpressionForTest('A^(B+3)'),
        closeTo(1.0, 1e-9),
        reason: '2^(-3+3) = 2^0',
      );
    });
  });

  group('explicitní násobení, záporné a nulové hodnoty', () {
    testWidgets('A*C: 2*3 = 6 a (-2)*3 = -6', (tester) async {
      final state = await pumpApp(tester);
      state.setMemoryForTest('A', 2.0);
      state.setMemoryForTest('C', 3.0);
      expect(state.evaluateExpressionForTest('A*C'), closeTo(6.0, 1e-9));

      state.setMemoryForTest('A', -2.0);
      expect(state.evaluateExpressionForTest('A*C'), closeTo(-6.0, 1e-9));
    });

    testWidgets('Bx² = B² = 9 při B = -3', (tester) async {
      final state = await pumpApp(tester);
      state.setMemoryForTest('B', -3.0);
      expect(state.evaluateExpressionForTest('Bx²'), closeTo(9.0, 1e-9));
    });

    testWidgets('4AC = 0 při A = 0 (uložená nula, ne chybějící proměnná)',
        (tester) async {
      final state = await pumpApp(tester);
      state.setMemoryForTest('A', 0.0);
      state.setMemoryForTest('C', 1.0);
      expect(state.evaluateExpressionForTest('4AC'), closeTo(0.0, 1e-9));
    });
  });

  group('E-notace má přednost před uloženou proměnnou E = 99', () {
    testWidgets('2(10E5) = 2000000, A(10E5) = 2000000, 10E5+A = 1000002',
        (tester) async {
      final state = await pumpApp(tester);
      state.setMemoryForTest('E', 99.0);
      state.setMemoryForTest('A', 2.0);

      expect(
        state.evaluateExpressionForTest('2(10E5)'),
        closeTo(2000000.0, 1.0),
        reason: '2 × (10 × 10^5)',
      );
      expect(
        state.evaluateExpressionForTest('A(10E5)'),
        closeTo(2000000.0, 1.0),
        reason: '2 × (10 × 10^5)',
      );
      expect(
        state.evaluateExpressionForTest('10E5+A'),
        closeTo(1000002.0, 1.0),
        reason: '(10 × 10^5) + 2',
      );
    });

    testWidgets('10E5, 20E-6, (10)E5 — standardní E-notace beze změny',
        (tester) async {
      final state = await pumpApp(tester);
      state.setMemoryForTest('E', 99.0);

      expect(
        state.evaluateExpressionForTest('10E5'),
        closeTo(1000000.0, 1.0),
      );
      expect(
        state.evaluateExpressionForTest('20E-6'),
        closeTo(0.00002, 1e-9),
      );
      expect(
        state.evaluateExpressionForTest('(10)E5'),
        closeTo(1000000.0, 1.0),
      );
    });
  });

  group('proměnná E, funkce a sousedící proměnné', () {
    testWidgets('E = 7: E+2 = 9, 2*E = 14, 2E = 14, AE = 14 (A = 2)',
        (tester) async {
      final state = await pumpApp(tester);
      state.setMemoryForTest('E', 7.0);
      state.setMemoryForTest('A', 2.0);

      expect(state.evaluateExpressionForTest('E+2'), closeTo(9.0, 1e-9));
      expect(state.evaluateExpressionForTest('2*E'), closeTo(14.0, 1e-9));
      // 2E bez exponentu = 2 × proměnná E (ne E-notace).
      expect(state.evaluateExpressionForTest('2E'), closeTo(14.0, 1e-9));
      // Sousedící proměnné A a E.
      expect(state.evaluateExpressionForTest('AE'), closeTo(14.0, 1e-9));
    });

    testWidgets('ABS(A) = 5 při A = -5 (marker funkce + dosazení)',
        (tester) async {
      final state = await pumpApp(tester);
      state.setMemoryForTest('A', -5.0);
      expect(state.evaluateExpressionForTest('ABS(A)'), closeTo(5.0, 1e-9));
    });

    testWidgets('LN(EX) = 1 při E = e a X = 1 (funkce + sousedící proměnné)',
        (tester) async {
      final state = await pumpApp(tester);
      state.setMemoryForTest('E', math.e);
      state.setMemoryForTest('X', 1.0);
      expect(
        state.evaluateExpressionForTest('LN(EX)'),
        closeTo(1.0, 1e-9),
        reason: 'ln(e × 1) = 1',
      );
    });
  });
}
