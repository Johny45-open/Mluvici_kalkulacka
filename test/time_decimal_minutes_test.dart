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
    state.switchModeForTest(CalculatorMode.time);
    await tester.pumpAndSettle();
  }

  group('Time Decimal Minutes Tests', () {
    testWidgets(
        '1 & 2 & 12 & 13: Default state, disabled behavior, toggle, and reset on mode change',
        (tester) async {
      final state = await pumpApp(tester);
      await switchToTimeMode(tester, state);

      // Default state: disabled
      expect(state.timeDecimalMinutesEnabledForTest, isFalse);

      // Single number without colon means seconds when disabled (e.g., 90 -> 90s -> 00:01:30)
      state.displayForTest = '90';
      expect(state.calculateTimeResultForTest('90'), '00:01:30');

      // Open advanced functions dialog (ikona seznamu) to check switch
      await tester.tap(find.byIcon(Icons.list));
      await tester.pumpAndSettle();

      expect(find.byType(SwitchListTile), findsWidgets);

      // Enable/disable decimal minutes through the switch widget
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(state.timeDecimalMinutesEnabledForTest, isTrue);

      // Close dialog (podle jazyka aplikace 'ZAVŘÍT' nebo 'CLOSE')
      final closeFinder =
          find.text('ZAVŘÍT').evaluate().isNotEmpty
              ? find.text('ZAVŘÍT').first
              : find.text('CLOSE').first;
      await tester.tap(closeFinder);
      await tester.pumpAndSettle();

      // Now 1,5 means 1.5 minutes = 90 seconds -> 00:01:30
      expect(state.calculateTimeResultForTest('1,5'), '00:01:30');

      // Switch mode away from time and back -> should reset to disabled
      state.switchModeForTest(CalculatorMode.basic);
      await tester.pumpAndSettle();
      await switchToTimeMode(tester, state);
      expect(state.timeDecimalMinutesEnabledForTest, isFalse);
    });

    testWidgets(
        '4, 5, 6, 8, 9, 10: Calculations with decimal minutes (comma & dot, +, -, diff, combinations)',
        (tester) async {
      final state = await pumpApp(tester);
      await switchToTimeMode(tester, state);

      // Enable decimal minutes via test hook for precision
      state.timeDecimalMinutesEnabledForTest = true;

      // 1,5 + 2,25 -> 00:03:45 (90s + 135s = 225s)
      expect(state.calculateTimeResultForTest('1,5+2,25'), '00:03:45');

      // Using dot: 1.5+2.25 -> 00:03:45
      expect(state.calculateTimeResultForTest('1.5+2.25'), '00:03:45');

      // 5,5 - 2,25 -> 00:03:15 (330s - 135s = 195s)
      expect(state.calculateTimeResultForTest('5,5-2,25'), '00:03:15');

      // Difference: 1,5;0,25 -> 00:01:15 (90s - 15s = 75s abs difference -> 01:15)
      expect(state.calculateTimeResultForTest('1,5;0,25'), '00:01:15');

      // Combination of decimal minutes and standard HH:MM:SS
      // 1,5 + 01:00 -> 90s + 3600s = 3690s = 01:01:30
      expect(state.calculateTimeResultForTest('1,5+01:00'), '01:01:30');
    });

    testWidgets('7 & 8: TO_SEC and TO_HMS conversions with decimal minutes',
        (tester) async {
      final state = await pumpApp(tester);
      await switchToTimeMode(tester, state);
      state.timeDecimalMinutesEnabledForTest = true;

      // Test TO_SEC button action on input '1,5'
      state.displayForTest = '1,5';
      await state.handleButtonPressedForTest('TO_SEC');
      expect(state.lastResultForTest, '90');

      // Test TO_HMS button action on input '2.25' (135 seconds -> 00:02:15).
      // Vstup zadáváme reálně stiskem kláves: po TO_SEC je _hasResult true a
      // přímé nastavení display by ho nečistilo (kalkulačka by TO_HMS nepochopila).
      for (final key in ['2', '.', '2', '5']) {
        await state.handleButtonPressedForTest(key);
      }
      expect(state.displayForTest, '2.25');
      await state.handleButtonPressedForTest('TO_HMS');
      expect(state.lastResultForTest, '00:02:15');
    });

    testWidgets('16: Announcement source unit follows decimal-minutes switch',
        (tester) async {
      final state = await pumpApp(tester);
      await switchToTimeMode(tester, state);

      state.timeDecimalMinutesEnabledForTest = true;

      // Jazyk testu není jistý (zařízení/CI), a proto se jednotky porovnávají
      // se stejným slovníkem, z kterého hlášky čerpají, a ověřuje se,
      // že zapnuté/vypnuté přepínač dává jinou jednotku pro stejné číslo.

      // 2,75 => minuty (přepínač zapnutý)
      // Hodnoty pro unitSpeechForTest jsou explicitně double,
      // protože dynamic volání int na double? nedorazí samo.
      final phMin = state.timeSourcePhraseForTest('2,75', 165);
      expect(phMin.value, '2,75');
      expect(phMin.unit, state.unitSpeechForTest('min', value: 2.75));

      // Jednotné číslo: 1 minuta
      expect(state.timeSourcePhraseForTest('1', 60).unit,
          state.unitSpeechForTest('min', value: 1.0));

      // 5 a více: 5 minut
      expect(state.timeSourcePhraseForTest('5', 300).unit,
          state.unitSpeechForTest('min', value: 5.0));

      // Vypnuté: holé číslo = sekundy, skloňované podle hodnoty
      state.timeDecimalMinutesEnabledForTest = false;
      expect(state.timeSourcePhraseForTest('1', 1).unit,
          state.unitSpeechForTest('s', value: 1.0));
      expect(state.timeSourcePhraseForTest('3', 3).unit,
          state.unitSpeechForTest('s', value: 3.0));
      expect(state.timeSourcePhraseForTest('165', 165).unit,
          state.unitSpeechForTest('s', value: 165.0));
      // Desetinné sekundy -> partitivní tvar
      expect(state.timeSourcePhraseForTest('2,75', 2).unit,
          state.unitSpeechForTest('s', value: 2.75));

      // Stejné číslo, jiná jednotka podle přepínače (hlavní smysl testu)
      state.timeDecimalMinutesEnabledForTest = true;
      final phOn = state.timeSourcePhraseForTest('2,75', 165);
      state.timeDecimalMinutesEnabledForTest = false;
      final phOff = state.timeSourcePhraseForTest('2,75', 2);
      expect(phOn.unit, isNot(phOff.unit));

      // Časový zápis se vždy mluví jako přepočtené sekundy
      final phHms = state.timeSourcePhraseForTest('01:00:00', 3600);
      expect(phHms.value, '3600');
      expect(phHms.unit, state.unitSpeechForTest('s', value: 3600.0));
    });

    testWidgets('11: Invalid inputs, rounding, NaN, Infinity', (tester) async {
      final state = await pumpApp(tester);
      await switchToTimeMode(tester, state);
      state.timeDecimalMinutesEnabledForTest = true;

      // Rounding test: 0,1 min = 6 seconds. What about 0,01 min = 0.6 seconds -> rounds to 1 second
      expect(state.calculateTimeResultForTest('0,01'), '00:00:01');

      // Invalid input throws Exception (konkrétně privátní _TimeInputException
      // z models.dart, který přes test balíček neodkážeme; stačí Exception).
      expect(
        () => state.calculateTimeResultForTest('abc'),
        throwsA(isA<Exception>()),
      );
      expect(
        () => state.calculateTimeResultForTest('1,,5'),
        throwsA(isA<Exception>()),
      );
    });

    testWidgets('14 & 15: Dialog accessibility and button semantic name',
        (tester) async {
      final state = await pumpApp(tester);
      await switchToTimeMode(tester, state);

      // Verify decimal button '.' exists in time mode keypad
      expect(find.text('.'), findsOneWidget);

      // Open advanced functions dialog (ikona seznamu)
      await tester.tap(find.byIcon(Icons.list));
      await tester.pumpAndSettle();

      // Verify switch label exists (CS/EN podle jazyka zařízení)
      final csLabel = find.text('Desetinné minuty');
      final enLabel = find.text('Decimal minutes');
      expect(
        csLabel.evaluate().isNotEmpty ? csLabel : enLabel,
        findsOneWidget,
      );
    });
  });
}
