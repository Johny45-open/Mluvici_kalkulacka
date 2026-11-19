import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regresní testy goniometrických funkcí – oprava greedy RegExp (bug: více
/// funkcí stejného typu v jednom výrazu vedlo k syntaktické chybě).
///
/// Všechny testy procházejí produkční cestou [_evaluateExpression] přes
/// [evaluateExpressionForTest]. Mód stupňů je výchozí po spuštění.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'accessibilityType': 0,
      'modeQuestionAsked': true,
    });

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    final docsDir = Directory.systemTemp.createTempSync('trig_docs');
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

  /// Spustí aplikaci v RAD módu (isDegreeMode = false přes SharedPreferences).
  Future<dynamic> pumpAppRad(WidgetTester tester) async {
    tester.platformDispatcher.clearAllTestValues();
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    // Přepíšeme mock prefs pro tento test – RAD mód od startu
    SharedPreferences.setMockInitialValues(<String, Object>{
      'accessibilityType': 0,
      'modeQuestionAsked': true,
      'isDegreeMode': false,
    });
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

  // ---------------------------------------------------------------------------
  // Povinné testy z požadavku (DEG mód)
  // ---------------------------------------------------------------------------
  group('Povinné testy – původní bug výrazy (DEG)', () {
    testWidgets('(8*SIN(65))/SIN(40) ≈ 11.2797169501', (tester) async {
      final state = await pumpApp(tester);
      expect(
        state.evaluateExpressionForTest('(8*SIN(65))/SIN(40)'),
        closeTo(11.2797169501, 1e-6),
      );
    });

    testWidgets('SIN(30)+SIN(60) ≈ 1.3660254038', (tester) async {
      final state = await pumpApp(tester);
      expect(
        state.evaluateExpressionForTest('SIN(30)+SIN(60)'),
        closeTo(1.3660254038, 1e-9),
      );
    });

    testWidgets('SIN(30)+COS(60) = 1.0', (tester) async {
      final state = await pumpApp(tester);
      expect(
        state.evaluateExpressionForTest('SIN(30)+COS(60)'),
        closeTo(1.0, 1e-12),
      );
    });

    testWidgets('TAN(45)+SIN(30) = 1.5', (tester) async {
      final state = await pumpApp(tester);
      expect(
        state.evaluateExpressionForTest('TAN(45)+SIN(30)'),
        closeTo(1.5, 1e-9),
      );
    });

    testWidgets('SIN(5*(2+3)) ≈ 0.4226 (vnořené závorky v argumentu)', (tester) async {
      final state = await pumpApp(tester);
      // SIN(5*(2+3)°) = SIN(25°) ≈ 0.42261826174069944
      expect(
        state.evaluateExpressionForTest('SIN(5*(2+3))'),
        closeTo(0.42261826174, 1e-9),
      );
    });

    testWidgets('SIN(COS(60)) ≈ 0.0087265355 (vnořené různé)', (tester) async {
      final state = await pumpApp(tester);
      // COS(60°) = 0.5; SIN(0.5°) ≈ 0.0087265355
      expect(
        state.evaluateExpressionForTest('SIN(COS(60))'),
        closeTo(0.0087265355, 1e-9),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Více stejných funkcí v jednom výrazu (DEG)
  // ---------------------------------------------------------------------------
  group('Více stejných funkcí v jednom výrazu (DEG)', () {
    testWidgets('COS(0)+COS(60) = 1.5', (tester) async {
      final state = await pumpApp(tester);
      expect(
        state.evaluateExpressionForTest('COS(0)+COS(60)'),
        closeTo(1.5, 1e-12),
      );
    });

    testWidgets('TAN(30)+TAN(45) ≈ 1.5773502692', (tester) async {
      final state = await pumpApp(tester);
      // tan(30°) = 1/√3 ≈ 0.5773502692; tan(45°) = 1
      expect(
        state.evaluateExpressionForTest('TAN(30)+TAN(45)'),
        closeTo(1.5773502692, 1e-9),
      );
    });

    testWidgets('SIN(10)+SIN(20)+SIN(30) – tři stejné funkce', (tester) async {
      final state = await pumpApp(tester);
      // sin(10°)+sin(20°)+sin(30°)
      const expected = 0.17364817766 + 0.34202014332 + 0.5;
      expect(
        state.evaluateExpressionForTest('SIN(10)+SIN(20)+SIN(30)'),
        closeTo(expected, 1e-8),
      );
    });

    testWidgets('ASIN(0.5)+ASIN(1) = 90+30 = ... (DEG)', (tester) async {
      final state = await pumpApp(tester);
      // arcsin(0.5)=30°, arcsin(1)=90° → součet = 120°
      expect(
        state.evaluateExpressionForTest('ASIN(0.5)+ASIN(1)'),
        closeTo(120.0, 1e-9),
      );
    });

    testWidgets('ACOS(0)+ACOS(1) = 90+0 = 90 (DEG)', (tester) async {
      final state = await pumpApp(tester);
      expect(
        state.evaluateExpressionForTest('ACOS(0)+ACOS(1)'),
        closeTo(90.0, 1e-9),
      );
    });

    testWidgets('ATAN(1)+ATAN(0) = 45+0 = 45 (DEG)', (tester) async {
      final state = await pumpApp(tester);
      expect(
        state.evaluateExpressionForTest('ATAN(1)+ATAN(0)'),
        closeTo(45.0, 1e-9),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Vnořené závorky v argumentu (DEG)
  // ---------------------------------------------------------------------------
  group('Vnořené závorky v argumentu (DEG)', () {
    testWidgets('SIN(2*(10+5)) = SIN(30) = 0.5', (tester) async {
      final state = await pumpApp(tester);
      expect(
        state.evaluateExpressionForTest('SIN(2*(10+5))'),
        closeTo(0.5, 1e-12),
      );
    });

    testWidgets('COS((90-30)) = COS(60) = 0.5', (tester) async {
      final state = await pumpApp(tester);
      expect(
        state.evaluateExpressionForTest('COS((90-30))'),
        closeTo(0.5, 1e-12),
      );
    });

    testWidgets('SIN(5*(2+3)) = SIN(25) ≈ 0.4226', (tester) async {
      final state = await pumpApp(tester);
      expect(
        state.evaluateExpressionForTest('SIN(5*(2+3))'),
        closeTo(0.42261826174, 1e-9),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Vnořené různé funkce (DEG)
  // ---------------------------------------------------------------------------
  group('Vnořené různé funkce (DEG)', () {
    testWidgets('COS(SIN(30)*60) = COS(30) = √3/2', (tester) async {
      final state = await pumpApp(tester);
      // SIN(30°)=0.5; 0.5*60=30; COS(30°)=√3/2≈0.8660254038
      expect(
        state.evaluateExpressionForTest('COS(SIN(30)*60)'),
        closeTo(0.8660254038, 1e-9),
      );
    });

    testWidgets('ASIN(SIN(30)) = 30 (round-trip DEG)', (tester) async {
      final state = await pumpApp(tester);
      expect(
        state.evaluateExpressionForTest('ASIN(SIN(30))'),
        closeTo(30.0, 1e-9),
      );
    });

    testWidgets('ACOS(COS(45)) = 45 (round-trip DEG)', (tester) async {
      final state = await pumpApp(tester);
      expect(
        state.evaluateExpressionForTest('ACOS(COS(45))'),
        closeTo(45.0, 1e-9),
      );
    });

    testWidgets('ATAN(TAN(30)) = 30 (round-trip DEG)', (tester) async {
      final state = await pumpApp(tester);
      expect(
        state.evaluateExpressionForTest('ATAN(TAN(30))'),
        closeTo(30.0, 1e-9),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Kombinace s násobením a dělením (DEG)
  // ---------------------------------------------------------------------------
  group('Kombinace s násobením a dělením (DEG)', () {
    testWidgets('SIN(30)*COS(60) = 0.5*0.5 = 0.25', (tester) async {
      final state = await pumpApp(tester);
      expect(
        state.evaluateExpressionForTest('SIN(30)*COS(60)'),
        closeTo(0.25, 1e-12),
      );
    });

    testWidgets('2*SIN(30)+3*COS(60) = 1+1.5 = 2.5', (tester) async {
      final state = await pumpApp(tester);
      expect(
        state.evaluateExpressionForTest('2*SIN(30)+3*COS(60)'),
        closeTo(2.5, 1e-12),
      );
    });

    testWidgets('SIN(45)/COS(45) = TAN(45) = 1', (tester) async {
      final state = await pumpApp(tester);
      expect(
        state.evaluateExpressionForTest('SIN(45)/COS(45)'),
        closeTo(1.0, 1e-12),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Více inverzních funkcí v jednom výrazu (DEG)
  // ---------------------------------------------------------------------------
  group('Více inverzních funkcí v jednom výrazu (DEG)', () {
    testWidgets('ASIN(0.5)+ACOS(0.5) = 30+60 = 90', (tester) async {
      final state = await pumpApp(tester);
      expect(
        state.evaluateExpressionForTest('ASIN(0.5)+ACOS(0.5)'),
        closeTo(90.0, 1e-9),
      );
    });

    testWidgets('ATAN(1)+ATAN(1) = 45+45 = 90', (tester) async {
      final state = await pumpApp(tester);
      expect(
        state.evaluateExpressionForTest('ATAN(1)+ATAN(1)'),
        closeTo(90.0, 1e-9),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Chybové stavy – musí zůstat zachovány (DEG)
  // ---------------------------------------------------------------------------
  group('Chybové stavy – zachování (DEG)', () {
    testWidgets('TAN(90) je nedefinovaný – _MathDomainException', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      // _MathDomainException není CalcError, zachycuje se zvlášť
      bool threw = false;
      try {
        state.evaluateExpressionForTest('TAN(90)');
      } catch (_) {
        threw = true;
      }
      expect(threw, isTrue, reason: 'TAN(90) musí vyhodit výjimku');
    });

    testWidgets('TAN(270) je nedefinovaný', (tester) async {
      final state = await pumpApp(tester);
      bool threw = false;
      try {
        state.evaluateExpressionForTest('TAN(270)');
      } catch (_) {
        threw = true;
      }
      expect(threw, isTrue, reason: 'TAN(270) musí vyhodit výjimku');
    });

    testWidgets('ASIN(2) je mimo definiční obor', (tester) async {
      final state = await pumpApp(tester);
      final err = catchCalcError(state, 'ASIN(2)');
      expect(err.kind, CalcErrorKind.domain);
    });

    testWidgets('ACOS(-2) je mimo definiční obor', (tester) async {
      final state = await pumpApp(tester);
      final err = catchCalcError(state, 'ACOS(-2)');
      expect(err.kind, CalcErrorKind.domain);
    });

    testWidgets('SIN() – prázdný argument → syntaxGeneral', (tester) async {
      final state = await pumpApp(tester);
      final err = catchCalcError(state, 'SIN()');
      expect(err.kind, CalcErrorKind.syntax);
      expect(err.reason, CalcErrorReason.syntaxGeneral);
    });

    testWidgets('COS() – prázdný argument → syntaxGeneral', (tester) async {
      final state = await pumpApp(tester);
      final err = catchCalcError(state, 'COS()');
      expect(err.kind, CalcErrorKind.syntax);
      expect(err.reason, CalcErrorReason.syntaxGeneral);
    });

    testWidgets('SIN(1+2 – neuzavřená závorka → syntaxParens', (tester) async {
      final state = await pumpApp(tester);
      final err = catchCalcError(state, 'SIN(1+2');
      expect(err.kind, CalcErrorKind.syntax);
      expect(err.reason, CalcErrorReason.syntaxParens);
    });

    testWidgets('COS( – holý marker bez závorky → syntaxParens', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      final err = catchCalcError(state, 'COS(');
      expect(err.kind, CalcErrorKind.syntax);
    });
  });

  // ---------------------------------------------------------------------------
  // RAD mód – prosté přejmenování markerů, více funkcí stejného typu
  // ---------------------------------------------------------------------------
  group('RAD mód – více funkcí stejného typu', () {
    testWidgets('SIN(1)+SIN(2) v RAD ≈ 1.75077', (tester) async {
      final state = await pumpAppRad(tester);
      // sin(1 rad)+sin(2 rad) ≈ 0.84147+0.90930 = 1.75077
      expect(
        state.evaluateExpressionForTest('SIN(1)+SIN(2)'),
        closeTo(1.75077, 1e-4),
      );
    });

    testWidgets('COS(0)+COS(1) v RAD ≈ 1.5403', (tester) async {
      final state = await pumpAppRad(tester);
      // cos(0)+cos(1 rad) = 1 + 0.54030 = 1.54030
      expect(
        state.evaluateExpressionForTest('COS(0)+COS(1)'),
        closeTo(1.5403023059, 1e-9),
      );
    });

    testWidgets('SIN(0)+SIN(0)+SIN(0) = 0 (tři funkce, RAD)', (tester) async {
      final state = await pumpAppRad(tester);
      expect(
        state.evaluateExpressionForTest('SIN(0)+SIN(0)+SIN(0)'),
        closeTo(0.0, 1e-12),
      );
    });
  });
}
