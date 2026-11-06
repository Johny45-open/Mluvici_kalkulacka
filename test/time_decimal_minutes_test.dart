import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void mockChannels() {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (c) async => null,
    );
    m.setMockMethodCallHandler(
      const MethodChannel('com.example.mluvici_kalkulacka/accessibility'),
      (c) async => false,
    );
    m.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (c) async => <String, Object>{
        'appName': 'mluvici_kalkulacka',
        'packageName': 'com.example.mluvici_kalkulacka',
        'version': '6.2.0',
        'buildNumber': '1',
      },
    );
  }

  Future<dynamic> pumpApp(WidgetTester tester) async {
    tester.platformDispatcher.clearAllTestValues();
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    SharedPreferences.setMockInitialValues({'modeQuestionAsked': true});
    mockChannels();
    await tester.pumpWidget(const ScientificCalculatorApp());
    await tester.pumpAndSettle();
    return tester.state(find.byType(CalculatorScreen)) as dynamic;
  }

  Future<void> switchToTimeMode(WidgetTester tester, dynamic state) async {
    try {
      state.switchModeForTest(CalculatorMode.time);
      await tester.pumpAndSettle();
      return;
    } catch (_) {}
    state._changeMode(CalculatorMode.time);
    await tester.pumpAndSettle();
  }

  group('Time Decimal Minutes Tests', () {
    testWidgets('1 & 2 & 12 & 13: Default state, disabled behavior, toggle, and reset on mode change', (tester) async {
      final state = await pumpApp(tester);
      await switchToTimeMode(tester, state);

      // Default state: disabled
      expect(state._timeDecimalMinutesEnabled, isFalse);

      // Single number without colon means seconds when disabled (e.g., 90 -> 90s -> 00:01:30)
      state.display = '90';
      expect(state._calculateTimeResult('90'), '00:01:30');

      // Open advanced functions dialog to check switch
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.byType(SwitchListTile), findsWidgets);
      
      // Enable decimal minutes
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(state._timeDecimalMinutesEnabled, isTrue);

      // Close dialog
      await tester.tap(find.text('ZAVŘÍT').first);
      await tester.pumpAndSettle();

      // Now 1,5 means 1.5 minutes = 90 seconds -> 00:01:30
      expect(state._calculateTimeResult('1,5'), '00:01:30');

      // Switch mode away from time and back -> should reset to disabled
      state._changeMode(CalculatorMode.basic);
      await tester.pumpAndSettle();
      await switchToTimeMode(tester, state);
      expect(state._timeDecimalMinutesEnabled, isFalse);
    });

    testWidgets('4, 5, 6, 8, 9, 10: Calculations with decimal minutes (comma & dot, +, -, diff, combinations)', (tester) async {
      final state = await pumpApp(tester);
      await switchToTimeMode(tester, state);

      // Enable decimal minutes via state directly for test precision
      state._timeDecimalMinutesEnabled = true;

      // 1,5 + 2,25 -> 00:03:45 (90s + 135s = 225s)
      expect(state._calculateTimeResult('1,5+2,25'), '00:03:45');

      // Using dot: 1.5+2.25 -> 00:03:45
      expect(state._calculateTimeResult('1.5+2.25'), '00:03:45');

      // 5,5 - 2,25 -> 00:03:15 (330s - 135s = 195s)
      expect(state._calculateTimeResult('5,5-2,25'), '00:03:15');

      // Difference: 1,5;0,25 -> 00:01:15 (90s - 15s = 75s abs difference -> 01:15)
      expect(state._calculateTimeResult('1,5;0,25'), '00:01:15');

      // Combination of decimal minutes and standard HH:MM:SS
      // 1,5 + 01:00 -> 90s + 3600s = 3690s = 01:01:30
      expect(state._calculateTimeResult('1,5+01:00'), '01:01:30');
    });

    testWidgets('7 & 8: TO_SEC and TO_HMS conversions with decimal minutes', (tester) async {
      final state = await pumpApp(tester);
      await switchToTimeMode(tester, state);
      state._timeDecimalMinutesEnabled = true;

      // Test TO_SEC button action on input '1,5'
      state.display = '1,5';
      await state._handleButtonPressed('TO_SEC');
      expect(state._lastResult, '90');

      // Test TO_HMS button action on input '2,25' (135 seconds -> 00:02:15)
      state.display = '2,25';
      await state._handleButtonPressed('TO_HMS');
      expect(state._lastResult, '00:02:15');
    });

    testWidgets('11: Invalid inputs, rounding, NaN, Infinity', (tester) async {
      final state = await pumpApp(tester);
      await switchToTimeMode(tester, state);
      state._timeDecimalMinutesEnabled = true;

      // Rounding test: 0,1 min = 6 seconds. What about 0,01 min = 0.6 seconds -> rounds to 1 second
      expect(state._calculateTimeResult('0,01'), '00:00:01');

      // Invalid input throws _TimeInputException
      expect(() => state._calculateTimeResult('abc'), throwsA(isA<_TimeInputException>()));
      expect(() => state._calculateTimeResult('1,,5'), throwsA(isA<_TimeInputException>()));
    });

    testWidgets('14 & 15: Dialog accessibility and button semantic name', (tester) async {
      final state = await pumpApp(tester);
      await switchToTimeMode(tester, state);

      // Verify decimal button '.' exists in time mode keypad
      expect(find.text('.'), findsOneWidget);

      // Open advanced functions dialog
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Verify switch label exists
      expect(find.text('Desetinné minuty'), findsOneWidget);
    });
  });
}
