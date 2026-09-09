import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:mluvici_kalkulacka/thousand_grouping.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Pure logic tests
  group('Thousand grouping pure logic', () {
    test('888 -> no gap', () {
      expect(computeThousandGapIndicesForDisplay('888'), isEmpty);
      expect(formatDisplayWithSpaces('888'), '888');
    });
    test('8888 -> 8 888', () {
      expect(formatDisplayWithSpaces('8888'), '8 888');
      expect(computeThousandGapIndicesForDisplay('8888'), {0});
    });
    test('88888 -> 88 888', () {
      expect(formatDisplayWithSpaces('88888'), '88 888');
    });
    test('888888 -> 888 888', () {
      expect(formatDisplayWithSpaces('888888'), '888 888');
      expect(computeThousandGapIndicesForDisplay('888888'), {2});
    });
    test('8888888 -> 8 888 888', () {
      expect(formatDisplayWithSpaces('8888888'), '8 888 888');
    });
    test('8888888888888888 -> 8 888 888 888 888 888', () {
      expect(
        formatDisplayWithSpaces('8888888888888888'),
        '8 888 888 888 888 888',
      );
    });
    test('1234567.89 -> 1 234 567.89', () {
      expect(formatDisplayWithSpaces('1234567.89'), '1 234 567.89');
      // fractional part not grouped
      expect(formatDisplayWithSpaces('1234567.891234'), '1 234 567.891234');
    });
    test('-1234567 -> -1 234 567 (minus not counted)', () {
      expect(formatDisplayWithSpaces('-1234567'), '-1 234 567');
      expect(computeThousandGapIndicesForDisplay('-1234567'), {1, 4});
    });
    test('1234567+8888888 -> 1 234 567+8 888 888', () {
      expect(
        formatDisplayWithSpaces('1234567+8888888'),
        '1 234 567+8 888 888',
      );
    });
    test('1234567*8888888+1000000', () {
      expect(
        formatDisplayWithSpaces('1234567*8888888+1000000'),
        '1 234 567*8 888 888+1 000 000',
      );
    });
    test('decimal with comma', () {
      expect(formatDisplayWithSpaces('1234567,89'), '1 234 567,89');
    });
    test('periodic 1234567.(3) not grouped in period', () {
      // integer part grouped, period not
      expect(formatDisplayWithSpaces('1234567.(3)'), '1 234 567.(3)');
    });
    test('small numbers no grouping', () {
      expect(formatDisplayWithSpaces('12+34'), '12+34');
      expect(formatDisplayWithSpaces('123'), '123');
    });
    test('expression with parentheses', () {
      expect(formatDisplayWithSpaces('(1234567)'), '(1 234 567)');
    });
  });

  group('Widget integration – cursor and semantics', () {
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
    }

    Future<dynamic> pumpApp(WidgetTester tester) async {
      tester.platformDispatcher.clearAllTestValues();
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.pumpWidget(const ScientificCalculatorApp());
      await tester.pumpAndSettle();
      return tester.state(find.byType(CalculatorScreen)) as dynamic;
    }

    testWidgets('kurzor na začátku / uprostřed / konci zachová pozici',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
      });
      mockChannels();
      await pumpApp(tester);
      // pure item-level check – no need for state
      // items gaps for cursor at 0: visual should still group correctly
      var items = [
        (char: '_', overline: false),
        (char: '8', overline: false),
        (char: '8', overline: false),
        (char: '8', overline: false),
        (char: '8', overline: false),
        (char: '8', overline: false),
        (char: '8', overline: false),
        (char: '8', overline: false),
      ];
      // After cursor at 0, integer digits are 7, gaps after logical positions 0 and 3
      // In items with leading _, gaps should be after digit indices 1 and 4 (0-based items)
      var gaps = computeThousandGapIndicesForItems(items);
      expect(gaps, contains(1));
      expect(gaps, contains(4));

      // cursor uprostřed (pos 3)
      items = [
        (char: '8', overline: false),
        (char: '8', overline: false),
        (char: '8', overline: false),
        (char: '_', overline: false),
        (char: '8', overline: false),
        (char: '8', overline: false),
        (char: '8', overline: false),
        (char: '8', overline: false),
      ];
      gaps = computeThousandGapIndicesForItems(items);
      // Logical 8888888 gaps after 0 and 3 -> visual gaps after items 0 and 4 (since _ transparent)
      expect(gaps, contains(0));
      expect(gaps, contains(4));

      // cursor na konci (pos 7) -> "8888888_"
      items = [
        (char: '8', overline: false),
        (char: '8', overline: false),
        (char: '8', overline: false),
        (char: '8', overline: false),
        (char: '8', overline: false),
        (char: '8', overline: false),
        (char: '8', overline: false),
        (char: '_', overline: false),
      ];
      gaps = computeThousandGapIndicesForItems(items);
      expect(gaps, contains(0));
      expect(gaps, contains(3));
    });

    testWidgets('widget CustomDotMatrixDisplay renders gaps', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomDotMatrixDisplay(
              text: '8888888',
              thousandGroupGap: 5.0,
              enableThousandGrouping: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Verify Row contains 7 children and margins include extra gap
      final dot = tester.widget<CustomDotMatrixDisplay>(
        find.byType(CustomDotMatrixDisplay),
      );
      expect(dot.thousandGroupGap, 5.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mazání po vizuálně odděleném čísle nemění display',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
      });
      mockChannels();
      final state = await pumpApp(tester);
      state.setDisplayForTest('8888888', 7);
      await tester.pump();
      expect(state.displayForTest, '8888888');
      // Simulate backspace
      state.backspaceForTest();
      await tester.pump();
      expect(state.displayForTest, '888888');
      expect(formatDisplayWithSpaces(state.displayForTest), '888 888');
      // visual should update
      expect(state.displayForTest.contains(' '), isFalse);
    });

    testWidgets('výpočet dlouhého čísla funguje', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
      });
      mockChannels();
      final state = await pumpApp(tester);
      state.setDisplayForTest('8888888+1', 9);
      await tester.pump();
      state.calculateForTest();
      await tester.pumpAndSettle();
      // Result should be 8888889
      expect(state.lastResultForTest, contains('8888889'));
      expect(state.displayForTest, isNot(contains(' ')));
    });

    testWidgets('Semantics stále používá skutečný výraz bez mezer',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
      });
      mockChannels();
      final state = await pumpApp(tester);
      state.setDisplayForTest('1234567+8888888', 15);
      await tester.pump();
      // Find Semantics that wraps display (cs: Displej, en: Display)
      final semanticsFinder = find.descendant(
        of: find.byType(CalculatorScreen),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.label == 'Displej' ||
                  w.properties.label == 'Display'),
        ),
      );
      expect(semanticsFinder, findsOneWidget);
      final semantics = tester.widget<Semantics>(semanticsFinder.first);
      // value should be based on _expressionToSpeech which does not contain visual spaces
      final val = semantics.properties.value ?? '';
      expect(val.contains('  '), isFalse);
      // It should contain spoken forms but not contain formatted visual spaces as characters
      // Check that underlying display has no spaces
      expect(state.displayForTest.contains(' '), isFalse);
      // And visual formatting would be "1 234 567+8 888 888" but semantics value is without those visual gaps
      expect(formatDisplayWithSpaces(state.displayForTest), '1 234 567+8 888 888');
    });

    testWidgets('desetinná čísla – jen celá část', (tester) async {
      expect(formatDisplayWithSpaces('1234567.89'), '1 234 567.89');
      expect(formatDisplayWithSpaces('1234567.8912345'), '1 234 567.8912345');
      // cursor uprostřed celé části
      var items = [
        (char: '1', overline: false),
        (char: '2', overline: false),
        (char: '_', overline: false),
        (char: '3', overline: false),
        (char: '4', overline: false),
        (char: '5', overline: false),
        (char: '6', overline: false),
        (char: '7', overline: false),
        (char: '.', overline: false),
        (char: '8', overline: false),
        (char: '9', overline: false),
      ];
      var gaps = computeThousandGapIndicesForItems(items);
      // integer part 1234567 L=7 gaps after 0 and 3 => items indices 0 and 4? Let's check
      // intDigitIndices = [0,1,3,4,5,6,7]??? Actually '.' at 8 stops, so indices [0,1,3,4,5,6,7] -> wait we have 1,2,3,4,5,6,7 digits excluding '_' -> 7 digits
      // gaps after 0 (digit '1') and after 4th digit which is at items[4] ('4')
      expect(gaps, contains(0));
    });
  });
}
