import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Klasifikace chyb výpočtu (R1): divisionByZero / domain / syntax / overflow.
/// Ověřuje strukturální klasifikaci přes existující test-hook
/// `evaluateExpressionForTest` (vyhazuje typovaný [CalcError]),
/// read-only helper Info o čísle a zákaz tichého ukládání 0.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'accessibilityType': 0,
      'modeQuestionAsked': true,
    });

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    final docsDir = Directory.systemTemp.createTempSync('calcerr_docs');
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

  group('divisionByZero', () {
    testWidgets('5/0, 0/0, 0^(-1)', (tester) async {
      final state = await pumpApp(tester);
      for (final expr in ['5/0', '0/0', '0^(-1)']) {
        final err = catchCalcError(state, expr);
        expect(
          err.kind,
          CalcErrorKind.divisionByZero,
          reason: 'výraz $expr',
        );
      }
    });

    testWidgets('5/(3-3), 5/(2-1-1)', (tester) async {
      final state = await pumpApp(tester);
      for (final expr in ['5/(3-3)', '5/(2-1-1)']) {
        final err = catchCalcError(state, expr);
        expect(
          err.kind,
          CalcErrorKind.divisionByZero,
          reason: 'výraz $expr',
        );
        expect(err.reason, CalcErrorReason.zeroDenominator);
      }
    });

    testWidgets('pametove varianty 5/(A-5), 5/A, 5/(A+0)', (tester) async {
      final state = await pumpApp(tester);
      state.setMemoryForTest('A', 5.0);
      var err = catchCalcError(state, '5/(A-5)');
      expect(err.kind, CalcErrorKind.divisionByZero);

      state.setMemoryForTest('A', 0.0);
      err = catchCalcError(state, '5/A');
      expect(err.kind, CalcErrorKind.divisionByZero);
      err = catchCalcError(state, '5/(A+0)');
      expect(err.kind, CalcErrorKind.divisionByZero);
    });
  });

  group('domain (nikdy divisionByZero)', () {
    testWidgets('sqrt(-1), ln(0), log(0)', (tester) async {
      final state = await pumpApp(tester);
      var err = catchCalcError(state, '√(-1)');
      expect(err.kind, CalcErrorKind.domain);
      expect(err.reason, CalcErrorReason.sqrtOfNegative);

      err = catchCalcError(state, 'LN(0)');
      expect(err.kind, CalcErrorKind.domain);
      expect(err.reason, CalcErrorReason.logNonPositiveArg);

      err = catchCalcError(state, 'LOG(0)');
      expect(err.kind, CalcErrorKind.domain);
      expect(err.reason, CalcErrorReason.logNonPositiveArg);
    });

    testWidgets('asin(2), acos(2)', (tester) async {
      final state = await pumpApp(tester);
      var err = catchCalcError(state, 'ASIN(2)');
      expect(err.kind, CalcErrorKind.domain);
      expect(err.reason, CalcErrorReason.asinOutOfRange);

      err = catchCalcError(state, 'ACOS(2)');
      expect(err.kind, CalcErrorKind.domain);
      expect(err.reason, CalcErrorReason.acosOutOfRange);
    });
  });

  group('syntax', () {
    testWidgets('nevyvazene zavorky', (tester) async {
      final state = await pumpApp(tester);
      for (final expr in ['1+2)', '1+(2*3', '((1+2)', '(1+2))']) {
        final err = catchCalcError(state, expr);
        expect(err.kind, CalcErrorKind.syntax, reason: 'výraz $expr');
        expect(
          err.reason,
          CalcErrorReason.syntaxParens,
          reason: 'výraz $expr',
        );
      }
    });

    testWidgets('5+*3, SIN()', (tester) async {
      final state = await pumpApp(tester);
      for (final expr in ['5+*3', 'SIN()']) {
        final err = catchCalcError(state, expr);
        expect(err.kind, CalcErrorKind.syntax, reason: 'výraz $expr');
      }
    });
  });

  group('overflow (nikdy divisionByZero)', () {
    testWidgets('10^308*10, 21!', (tester) async {
      final state = await pumpApp(tester);
      // 10^308*10 pretece az vysledkem: engine vrati Infinity bez
      // strukturalniho dukazu deleni nulou -> zbytkova klasifikace.
      final big = state.evaluateExpressionForTest('10^308*10') as double;
      expect(big.isInfinite, isTrue);
      final residual = state.classifyResidualForTest(big) as CalcError;
      expect(residual.kind, CalcErrorKind.overflow);
      expect(residual.kind, isNot(CalcErrorKind.divisionByZero));

      // Faktorial mimo double rozsah je prokazany overflow.
      final factErr = catchCalcError(state, '21!');
      expect(factErr.kind, CalcErrorKind.overflow);
    });
  });

  group('validni vysledky', () {
    testWidgets('5/(A-5) pri A=6 je 5; A*5 pri A=10 je 50', (tester) async {
      final state = await pumpApp(tester);
      state.setMemoryForTest('A', 6.0);
      expect(state.evaluateExpressionForTest('5/(A-5)'), 5.0);

      state.setMemoryForTest('A', 10.0);
      expect(state.evaluateExpressionForTest('A*5'), 50.0);
    });

    testWidgets('0^0 je 1 (runtime sonda math.pow)', (tester) async {
      final state = await pumpApp(tester);
      expect(state.evaluateExpressionForTest('0^0'), 1.0);
    });
  });

  group('Info o cisle z horniho displeje', () {
    testWidgets('0,5 / 1/2 / 2+3 bez =', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('0,5', 3);
      expect(state.resolveNumberInfoForTest(), 0.5);

      state.setDisplayForTest('1/2', 3);
      expect(state.resolveNumberInfoForTest(), 0.5);

      state.setDisplayForTest('2+3', 3);
      expect(state.resolveNumberInfoForTest(), 5.0);
    });

    testWidgets('A+0,5 s pameti', (tester) async {
      final state = await pumpApp(tester);
      state.setMemoryForTest('A', 10.0);
      state.setDisplayForTest('A+0,5', 5);
      expect(state.resolveNumberInfoForTest(), 10.5);
    });

    testWidgets('stale-data: 5+5= pak 0,5 musi byt 0,5', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('5+5', 3);
      await tester.pump();
      state.calculateForTest();
      await tester.pumpAndSettle();
      expect(state.lastNumericForTest, 10.0);

      state.setDisplayForTest('0,5', 3);
      await tester.pump();
      expect(state.resolveNumberInfoForTest(), 0.5);
      // Read-only: stav se helperem nezmenil.
      expect(state.displayForTest, '0,5');
      expect(state.lastNumericForTest, 10.0);
    });
  });

  group('Ulozeni do pameti bez tiche nuly', () {
    testWidgets('5/0 se neulozi', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('5/0', 3);
      await tester.pump();
      final ok = state.storeCurrentValueToMemory('D') as bool;
      expect(ok, isFalse);
      expect(state.memoryForTest['D'], 0.0);
    });

    testWidgets('prazdny display + Error nic neulozi', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('7*6', 3);
      await tester.pump();
      state.calculateForTest();
      await tester.pumpAndSettle();
      expect(state.lastResultForTest, isNotEmpty);

      // Chyba: _lastResult = Error, display rucne prazdny.
      state.setDisplayForTest('5/0', 3);
      await tester.pump();
      state.calculateForTest();
      await tester.pumpAndSettle();
      expect(state.lastResultForTest, 'Error');
      state.setDisplayForTest('', 0);
      await tester.pump();

      state.setMemoryForTest('X', 7.0);
      final ok = state.storeCurrentValueToMemory('X') as bool;
      expect(ok, isFalse);
      // Zadna ticha nula: puvodni hodnota zustala.
      expect(state.memoryForTest['X'], 7.0);
    });
  });
}
