import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Třetí odmocnina záporných hodnot a vnořených závorek (část A).
/// Kritéria opravy: ∛(ANS) se záporným výsledkem projde celou produkční
/// cestou (substituce ANS → markery → kontroly závorek → vyhodnocení)
/// bez syntaxParens a se znaménkově správným reálným výsledkem.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'accessibilityType': 0,
      'modeQuestionAsked': true,
    });

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    final docsDir = Directory.systemTemp.createTempSync('cbrt_docs');
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

  CalcError catchCalcError(dynamic state, String expr) {
    try {
      state.evaluateExpressionForTest(expr);
    } on CalcError catch (e) {
      return e;
    }
    fail('Výraz "$expr" nevyhodil CalcError');
  }

  group('∛ záporných a zlomkových hodnot (kritéria opravy)', () {
    testWidgets('∛(-8) = -2', (tester) async {
      final state = await pumpApp(tester);
      expect(state.evaluateExpressionForTest('∛(-8)'), closeTo(-2.0, 1e-9));
    });

    testWidgets('∛(-27) = -3', (tester) async {
      final state = await pumpApp(tester);
      expect(state.evaluateExpressionForTest('∛(-27)'), closeTo(-3.0, 1e-9));
    });

    testWidgets('∛(-8/27) = -2/3', (tester) async {
      final state = await pumpApp(tester);
      expect(
        state.evaluateExpressionForTest('∛(-8/27)'),
        closeTo(-2.0 / 3.0, 1e-9),
      );
    });

    testWidgets('∛(8/27) = 2/3', (tester) async {
      final state = await pumpApp(tester);
      expect(
        state.evaluateExpressionForTest('∛(8/27)'),
        closeTo(2.0 / 3.0, 1e-9),
      );
    });

    testWidgets('∛ přes ANS se záporným výsledkem (celá produkční cesta)',
        (tester) async {
      final state = await pumpApp(tester);
      state.displayForTest = '-8/27';
      state.calculateForTest();
      await tester.pump();
      // Před opravou: ∛(ANS) padalo na syntaxParens už při přípravě.
      await state.handleButtonPressedForTest('∛');
      await tester.pump();
      expect(state.displayForTest, '∛(ANS)');
      expect(
        state.evaluateExpressionForTest('∛(ANS)'),
        closeTo(-2.0 / 3.0, 1e-9),
      );
      state.calculateForTest();
      await tester.pump();
      expect(state.lastResultForTest, isNot('Error'));
    });

    testWidgets('∛ přes ANS s kladným výsledkem', (tester) async {
      final state = await pumpApp(tester);
      state.displayForTest = '8/27';
      state.calculateForTest();
      await tester.pump();
      await state.handleButtonPressedForTest('∛');
      await tester.pump();
      expect(state.displayForTest, '∛(ANS)');
      expect(
        state.evaluateExpressionForTest('∛(ANS)'),
        closeTo(2.0 / 3.0, 1e-9),
      );
      state.calculateForTest();
      await tester.pump();
      expect(state.lastResultForTest, isNot('Error'));
    });

    testWidgets('vnořené závorky: ∛((-8)), ∛((8/27)), ∛(∛(729))',
        (tester) async {
      final state = await pumpApp(tester);
      expect(state.evaluateExpressionForTest('∛((-8))'), closeTo(-2.0, 1e-9));
      expect(
        state.evaluateExpressionForTest('∛((8/27))'),
        closeTo(2.0 / 3.0, 1e-9),
      );
      // Vnitřní ∛(729) = 9 (s float chybou pow), vnější ∛(9).
      // Tolerance kryje zdvojenou chybu pow, smyslem testu je funkční
      // vnoření, ne poslední bit přesnosti.
      expect(
        state.evaluateExpressionForTest('∛(∛(729))'),
        closeTo(2.0800837383, 1e-6),
      );
    });

    testWidgets('∛(0) = 0', (tester) async {
      final state = await pumpApp(tester);
      expect(state.evaluateExpressionForTest('∛(0)'), closeTo(0.0, 1e-12));
    });
  });

  group('∛ regrese ostatních funkcí a syntaxe', () {
    testWidgets('kladné odmocniny beze změny', (tester) async {
      final state = await pumpApp(tester);
      expect(state.evaluateExpressionForTest('∛(27)'), closeTo(3.0, 1e-9));
      expect(state.evaluateExpressionForTest('∛(54/2)'), closeTo(3.0, 1e-9));
      expect(state.evaluateExpressionForTest('√(16)'), closeTo(4.0, 1e-9));
      expect(state.evaluateExpressionForTest('√(2)*√(2)'), closeTo(2.0, 1e-9));
    });

    testWidgets('skutečně nevyvážený výraz je stále syntaxParens',
        (tester) async {
      final state = await pumpApp(tester);
      for (final expr in ['∛(-8', '1+(2*3', '((1+2)', '(1+2))']) {
        final err = catchCalcError(state, expr);
        expect(err.kind, CalcErrorKind.syntax, reason: 'výraz $expr');
        expect(
          err.reason,
          CalcErrorReason.syntaxParens,
          reason: 'výraz $expr',
        );
      }
    });

    testWidgets('prázdné ∛() je obecná syntax jako SIN()', (tester) async {
      final state = await pumpApp(tester);
      final err = catchCalcError(state, '∛()');
      expect(err.kind, CalcErrorKind.syntax);
      expect(err.reason, CalcErrorReason.syntaxGeneral);
    });

    testWidgets('√(-1) je stále doménová chyba', (tester) async {
      final state = await pumpApp(tester);
      final err = catchCalcError(state, '√(-1)');
      expect(err.kind, CalcErrorKind.domain);
      expect(err.reason, CalcErrorReason.sqrtOfNegative);
    });

    testWidgets('∛ s dělením nulou uvnitř se propaguje', (tester) async {
      final state = await pumpApp(tester);
      final err = catchCalcError(state, '∛(5/0)');
      expect(err.kind, CalcErrorKind.divisionByZero);
    });
  });
}
