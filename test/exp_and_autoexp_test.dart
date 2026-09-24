import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void mockChannels() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (c) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.example.mluvici_kalkulacka/accessibility'),
      (c) async => false,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (c) async => <String, Object>{
        'appName': 'mluvici_kalkulacka',
        'packageName': 'com.example.mluvici_kalkulacka',
        'version': '6.2.0',
        'buildNumber': '1',
      },
    );
  }

  Future<dynamic> pumpApp(
    WidgetTester tester, {
    Locale locale = const Locale('cs'),
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'modeQuestionAsked': true,
    });
    mockChannels();
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ScientificCalculatorApp(locale: locale));
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(CalculatorScreen)) as dynamic;
    return state;
  }

  group('EXP placeholder ochrana', () {
    testWidgets('10E5, 10E+5, 10E-5, 2.5E3, 2.5E-3, (10)E5, (2.5)E3', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      state.setMemoryForTest('E', 5.0);
      state.setMemoryForTest('A', 2.0);
      await tester.pump();
      expect(state.evaluateExpressionForTest('10E5'), closeTo(1000000, 0.001));
      expect(state.evaluateExpressionForTest('10E+5'), closeTo(1000000, 0.001));
      expect(state.evaluateExpressionForTest('10E-5'), closeTo(0.0001, 1e-9));
      expect(state.evaluateExpressionForTest('2.5E3'), closeTo(2500, 0.001));
      expect(state.evaluateExpressionForTest('2.5E-3'), closeTo(0.0025, 1e-9));
      expect(
        state.evaluateExpressionForTest('(10)E5'),
        closeTo(1000000, 0.001),
      );
      expect(state.evaluateExpressionForTest('(2.5)E3'), closeTo(2500, 0.001));
    });

    testWidgets('promenna E zustava funkcni', (tester) async {
      final state = await pumpApp(tester);
      state.setMemoryForTest('E', 7.0);
      state.setMemoryForTest('A', 3.0);
      await tester.pump();
      expect(state.evaluateExpressionForTest('E'), closeTo(7, 0.001));
      expect(state.evaluateExpressionForTest('E+2'), closeTo(9, 0.001));
      expect(state.evaluateExpressionForTest('2*E'), closeTo(14, 0.001));
      expect(state.evaluateExpressionForTest('A+E'), closeTo(10, 0.001));
      expect(state.evaluateExpressionForTest('E*2'), closeTo(14, 0.001));
    });

    testWidgets('validni tvary dokumentace', (tester) async {
      final state = await pumpApp(tester);
      state.setMemoryForTest('E', 99.0);
      await tester.pump();
      expect(state.evaluateExpressionForTest('10E5'), closeTo(1e6, 1));
      expect(state.evaluateExpressionForTest('E+5'), closeTo(104, 1));
    });
  });

  group('Auto exponencialni zapis', () {
    testWidgets('hranicni hodnoty', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayFormatForTest(DisplayFormat.standard);
      await tester.pump();

      expect(state.tryAutoExponentialForTest(999999999.0), isNull);
      expect(state.tryAutoExponentialForTest(1000000000.0), equals('1E+09'));
      expect(state.tryAutoExponentialForTest(9999999999.0), isNull);
      expect(state.tryAutoExponentialForTest(10000000000.0), equals('1E+10'));
      expect(state.tryAutoExponentialForTest(100000000000.0), equals('1E+11'));
      expect(state.tryAutoExponentialForTest(-1000000000.0), equals('-1E+09'));
      expect(state.tryAutoExponentialForTest(-999999999.0), isNull);

      expect(state.formatNumberForTest(1000000000.0), equals('1E+09'));
      expect(state.formatNumberForTest(10000000000.0), equals('1E+10'));
      expect(state.formatNumberForTest(1230000000.0), equals('1230000000'));
      expect(state.formatNumberForTest(1000000001.0), equals('1000000001'));
      expect(state.formatNumberForTest(1234567890.0), equals('1234567890'));
      expect(state.formatNumberForTest(999999999.0), equals('999999999'));
    });

    testWidgets('pouze standard, fix/sci/eng nemeni', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayFormatForTest(DisplayFormat.fix);
      state.setPrecisionForTest(2);
      await tester.pump();
      expect(state.formatNumberForTest(1000000000.0), equals('1000000000.00'));
      state.setDisplayFormatForTest(DisplayFormat.sci);
      await tester.pump();
      expect(state.formatNumberForTest(1000000000.0), contains('E+'));
      state.setDisplayFormatForTest(DisplayFormat.eng);
      await tester.pump();
      expect(state.formatNumberForTest(1000000000.0), contains('E+'));
      state.setDisplayFormatForTest(DisplayFormat.standard);
      await tester.pump();
      expect(state.formatNumberForTest(1000000000.0), equals('1E+09'));
    });

    testWidgets('double presnost guard', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayFormatForTest(DisplayFormat.standard);
      await tester.pump();
      expect(state.tryAutoExponentialForTest(1000000000.5), isNull);
      expect(state.tryAutoExponentialForTest(1000000000.0), isNotNull);
    });
  });

  group('Hlas exponenciala', () {
    testWidgets('ceska ordinalni podoba', (tester) async {
      final state = await pumpApp(tester);
      expect(state.formatForSpeechForTest('1E+09'), contains('devátou'));
      expect(state.formatForSpeechForTest('1E+10'), contains('desátou'));
      expect(state.formatForSpeechForTest('1E+11'), contains('jedenáctou'));
      expect(state.formatForSpeechForTest('1E-09'), contains('mínus'));
      expect(state.formatForSpeechForTest('1E-09'), contains('devátou'));
      expect(state.spokenForDisplayForTest('1E+09'), contains('devátou'));
    });

    testWidgets('formatSpokenNumber pro auto-exp', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayFormatForTest(DisplayFormat.standard);
      await tester.pump();
      expect(
        state.formatSpokenNumberForTest(1000000000.0),
        contains('devátou'),
      );
      expect(
        state.formatSpokenNumberForTest(10000000000.0),
        contains('desátou'),
      );
      expect(state.formatSpokenNumberForTest(999999999.0), equals('999999999'));
    });
  });

  group('Klavesnice focus order', () {
    testWidgets(
      'Wrap poradi zleva doprava shora dolu s ReadingOrderTraversalPolicy',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'modeQuestionAsked': true,
        });
        mockChannels();
        tester.view.physicalSize = const Size(412, 860);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(const ScientificCalculatorApp());
        await tester.pumpAndSettle();
        final wrapGroups = tester
            .widgetList<FocusTraversalGroup>(find.byType(FocusTraversalGroup))
            .toList();
        expect(wrapGroups, isNotEmpty);
        final hasReadingOrder = wrapGroups.any(
          (g) => g.policy is ReadingOrderTraversalPolicy,
        );
        expect(
          hasReadingOrder,
          isTrue,
          reason: 'klavesnice musi mit ReadingOrderTraversalPolicy pro Wrap',
        );
        final sizedBoxes = tester
            .widgetList<SizedBox>(find.byType(SizedBox))
            .where((s) => s.width != null && s.height != null && s.width! > 50)
            .toList();
        final btnBoxes = sizedBoxes
            .where((s) => s.width! > 80 && s.width! < 150)
            .toList();
        if (btnBoxes.length >= 8) {
          final h0 = btnBoxes.first.height!;
          for (final b in btnBoxes) {
            expect(
              b.height,
              closeTo(h0, 0.5),
              reason: 'vsechna tlacitka musi mit stejnou vysku',
            );
          }
        }
      },
    );
  });
}
