import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Automatické hlasové oznámení dostupnosti zlomku ve výsledkové speech.
// Jedna výsledková hláška: věta je součástí existujícího
// speak(spoken, force: true) v calculateResult(), žádné druhé speak()/say().
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

  Future<void> calculate(
    WidgetTester tester,
    dynamic state,
    String expr,
  ) async {
    state.setDisplayForTest(expr, expr.length);
    await tester.pump();
    ttsLog.clear();
    state.calculateForTest();
    await tester.pumpAndSettle();
  }

  Future<void> setScreenReader(WidgetTester tester, dynamic state, bool on) async {
    state.updateActiveSettingsForTest(
      (s) => s.copyWith(
        screenReaderMode: on ? ScreenReaderMode.on : ScreenReaderMode.off,
      ),
    );
    await tester.pumpAndSettle();
  }

  List<String> resultSpeeches(String csMarker, String enMarker) => ttsLog
      .where((t) => t.contains(csMarker) || t.contains(enMarker))
      .toList();

  group('Fraction announcement – automatická věta ve výsledkové speech', () {
    testWidgets('A. SR OFF + 0,75 -> jedna speech s 3 lomeno 4 (cs)', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      expect(state.ttsEnabled, isTrue);
      await setScreenReader(tester, state, false);
      await calculate(tester, state, '0.75');
      expect(state.fractionStringForTest, '3/4');
      final speeches = resultSpeeches('Výsledek je', 'The result is');
      expect(speeches, hasLength(1), reason: 'TTS log: $ttsLog');
      expect(speeches.single, contains('Výsledek je'));
      expect(speeches.single, contains('3 lomeno 4'));
      expect(
        speeches.single,
        contains('Pro tento výsledek je dostupný zlomek'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('A2. SR OFF + 0.75 -> 3 over 4 (en)', (tester) async {
      final state = await pumpApp(tester, locale: const Locale('en'));
      await setScreenReader(tester, state, false);
      await calculate(tester, state, '0.75');
      expect(state.fractionStringForTest, '3/4');
      final speeches = resultSpeeches('Výsledek je', 'The result is');
      expect(speeches, hasLength(1), reason: 'TTS log: $ttsLog');
      expect(speeches.single, contains('3 over 4'));
      expect(speeches.single, contains('is available for this result'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('B. chybový výsledek -> žádná nová věta o zlomku', (
      tester,
    ) async {
      // Null-safe větev helperu (_fractionString == null ->
      // fractionUnavailable) je ponechána v kódu; decimalToFraction() pro
      // konečné relevantní výsledky prakticky vždy vrací Fraction, takže se
      // zde ověřuje, že nerelevantní (chybový) kontext žádnou novou větu
      // nepřidá. Chybová větev calculateResult() je nedotčena.
      final state = await pumpApp(tester);
      await setScreenReader(tester, state, false);
      await calculate(tester, state, '5+');
      // Neplatný výraz -> chybová větev calculateResult() ('Error'),
      // nerelevantní kontext, helper nic nepřidá. Chybová větev je nedotčena
      // a neukládá historii.
      expect(state.lastResultForTest, 'Error');
      final added = ttsLog.where(
        (t) =>
            t.contains('lomeno') ||
            t.contains(' over ') ||
            t.contains('dostupný') ||
            t.contains('dostupné') ||
            t.contains('is available'),
      );
      expect(added, isEmpty, reason: 'TTS log: $ttsLog');
      expect(tester.takeException(), isNull);
    });

    testWidgets('C. SR ON + 3/4 -> nová věta se nepřidá', (tester) async {
      final state = await pumpApp(tester);
      await setScreenReader(tester, state, true);
      await calculate(tester, state, '3/4');
      expect(state.fractionStringForTest, '3/4');
      final speeches = resultSpeeches('Výsledek je', 'The result is');
      expect(speeches, hasLength(1), reason: 'TTS log: $ttsLog');
      expect(speeches.single.contains('lomeno'), isFalse);
      expect(speeches.single.contains('dostupný'), isFalse);
      expect(speeches.single.contains('is available'), isFalse);
      // Toggle Semantics dál obsahuje konkrétní zlomek.
      final toggle = find.byKey(const ValueKey('fraction_toggle'));
      expect(toggle, findsOneWidget);
      final semFinder = find.ancestor(
        of: toggle,
        matching: find.byWidgetPredicate((w) {
          if (w is! Semantics) return false;
          return (w.properties.label ?? '').contains('3/4');
        }),
      );
      expect(semFinder, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('D. psaní 7 . 5 nevyvolá větu o zlomku', (tester) async {
      final state = await pumpApp(tester);
      await setScreenReader(tester, state, false);
      ttsLog.clear();
      await state.handleButtonPressedForTest('7');
      await state.handleButtonPressedForTest('.');
      await state.handleButtonPressedForTest('5');
      await tester.pumpAndSettle();
      final added = ttsLog.where(
        (t) =>
            t.contains('lomeno') ||
            t.contains(' over ') ||
            t.contains('dostupný') ||
            t.contains('dostupné') ||
            t.contains('is available'),
      );
      expect(added, isEmpty, reason: 'TTS log: $ttsLog');
      expect(tester.takeException(), isNull);
    });

    testWidgets('E. toggle ON/OFF bez nové automatické věty', (tester) async {
      final state = await pumpApp(tester);
      await setScreenReader(tester, state, false);
      await calculate(tester, state, '1/2');
      // Manuální toggle: stávající oznámení zůstává, nová automatická věta
      // (fractionAvailableAnnouncement) se nepřidá a nic se nezdvojí.
      ttsLog.clear();
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isTrue);
      expect(
        ttsLog.where((t) => t.contains('dostupný') || t.contains('is available')),
        isEmpty,
        reason: 'TTS log: $ttsLog',
      );
      expect(ttsLog.where((t) => t.contains('lomeno')).length, 1);
      ttsLog.clear();
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isFalse);
      expect(
        ttsLog.where((t) => t.contains('dostupný') || t.contains('is available')),
        isEmpty,
        reason: 'TTS log: $ttsLog',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('F. nový výsledek 3/4 -> 1/2 mluví nový zlomek', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await setScreenReader(tester, state, false);
      await calculate(tester, state, '3/4');
      expect(ttsLog.last, contains('3 lomeno 4'));
      await calculate(tester, state, '1/2');
      expect(state.fractionStringForTest, '1/2');
      final speeches = resultSpeeches('Výsledek je', 'The result is');
      expect(speeches, hasLength(1), reason: 'TTS log: $ttsLog');
      expect(speeches.single, contains('1 lomeno 2'));
      expect(speeches.single.contains('3 lomeno 4'), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('G1. basic + SR OFF + TTS ON -> věta MUSÍ být ve speech', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      expect(state.ttsEnabled, isTrue);
      state.switchModeForTest(CalculatorMode.basic);
      await tester.pumpAndSettle();
      await setScreenReader(tester, state, false);
      await calculate(tester, state, '0.75');
      final speeches = resultSpeeches('Výsledek je', 'The result is');
      expect(speeches, hasLength(1), reason: 'TTS log: $ttsLog');
      expect(speeches.single, contains('3 lomeno 4'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('G2. scientific + SR OFF + TTS ON -> věta MUSÍ být ve speech',
        (tester) async {
      final state = await pumpApp(tester);
      expect(state.ttsEnabled, isTrue);
      state.switchModeForTest(CalculatorMode.scientific);
      await tester.pumpAndSettle();
      await setScreenReader(tester, state, false);
      await calculate(tester, state, '0.75');
      final speeches = resultSpeeches('Výsledek je', 'The result is');
      expect(speeches, hasLength(1), reason: 'TTS log: $ttsLog');
      expect(speeches.single, contains('3 lomeno 4'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('G3. time/statistics/electrician/currency/unit -> bez věty',
        (tester) async {
      final state = await pumpApp(tester);
      await setScreenReader(tester, state, false);

      state.switchModeForTest(CalculatorMode.time);
      await tester.pumpAndSettle();
      await calculate(tester, state, '12:30');
      expect(
        ttsLog
            .where(
              (t) =>
                  t.contains('lomeno') ||
                  t.contains('dostupný') ||
                  t.contains('is available'),
            )
            .isEmpty,
        isTrue,
        reason: 'time TTS log: $ttsLog',
      );

      state.switchModeForTest(CalculatorMode.statistics);
      await tester.pumpAndSettle();
      await calculate(tester, state, '1+1');
      expect(
        ttsLog
            .where(
              (t) =>
                  t.contains('lomeno') ||
                  t.contains('dostupný') ||
                  t.contains('is available'),
            )
            .isEmpty,
        isTrue,
        reason: 'statistics TTS log: $ttsLog',
      );

      state.switchModeForTest(CalculatorMode.electrician);
      await tester.pumpAndSettle();
      await calculate(tester, state, '12;4');
      expect(
        ttsLog
            .where(
              (t) =>
                  t.contains('lomeno') ||
                  t.contains('dostupný') ||
                  t.contains('is available'),
            )
            .isEmpty,
        isTrue,
        reason: 'electrician TTS log: $ttsLog',
      );

      state.switchModeForTest(CalculatorMode.currency);
      await tester.pumpAndSettle();
      await calculate(tester, state, '10');
      expect(
        ttsLog
            .where(
              (t) =>
                  t.contains('lomeno') ||
                  t.contains('dostupný') ||
                  t.contains('is available'),
            )
            .isEmpty,
        isTrue,
        reason: 'currency TTS log: $ttsLog',
      );

      state.switchModeForTest(CalculatorMode.unitConversion);
      await tester.pumpAndSettle();
      await calculate(tester, state, '1+1');
      expect(
        ttsLog
            .where(
              (t) =>
                  t.contains('lomeno') ||
                  t.contains('dostupný') ||
                  t.contains('is available'),
            )
            .isEmpty,
        isTrue,
        reason: 'unitConversion TTS log: $ttsLog',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('G4. DMS výsledek -> bez nové věty', (tester) async {
      final state = await pumpApp(tester);
      await setScreenReader(tester, state, false);
      state.switchModeForTest(CalculatorMode.scientific);
      await tester.pumpAndSettle();
      state.setDisplayForTest('30', 2);
      await tester.pump();
      ttsLog.clear();
      await state.handleButtonPressedForTest("°→'");
      await tester.pumpAndSettle();
      expect(ttsLog, isNotEmpty, reason: 'DMS musí něco říct');
      expect(
        ttsLog
            .where(
              (t) =>
                  t.contains('lomeno') ||
                  t.contains('dostupný') ||
                  t.contains('is available'),
            )
            .isEmpty,
        isTrue,
        reason: 'DMS TTS log: $ttsLog',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('H1. SR OFF + cele cislo 2 -> bez vety o zlomku', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await setScreenReader(tester, state, false);
      await calculate(tester, state, '1+1');
      expect(state.fractionStringForTest, isNull);
      expect(state.fractionEligibleForTest, isFalse);
      final speeches = resultSpeeches('Výsledek je', 'The result is');
      expect(speeches, hasLength(1), reason: 'TTS log: $ttsLog');
      expect(speeches.single.contains('2/1'), isFalse);
      expect(speeches.single.contains('lomeno 1'), isFalse);
      expect(speeches.single.contains('over 1'), isFalse);
      expect(speeches.single.contains('dostupný zlomek'), isFalse);
      expect(speeches.single.contains('is available'), isFalse);
      expect(speeches.single.contains('není dostupný'), isFalse);
      expect(speeches.single.contains('not available'), isFalse);
      // Toggle ve stavu nedostupnosti nic nezapne.
      ttsLog.clear();
      state.toggleFractionForTest();
      await tester.pumpAndSettle();
      expect(state.fractionViewForTest, isFalse);
      expect(state.currentResultSpeechForTest().contains('lomeno 1'), isFalse);
      expect(state.currentResultSpeechForTest().contains('over 1'), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('H2. SR ON + cele cislo 2 -> bez vety o zlomku', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await setScreenReader(tester, state, true);
      await calculate(tester, state, '1+1');
      expect(state.fractionStringForTest, isNull);
      expect(state.fractionEligibleForTest, isFalse);
      final speeches = resultSpeeches('Výsledek je', 'The result is');
      expect(speeches, hasLength(1), reason: 'TTS log: $ttsLog');
      expect(speeches.single.contains('2/1'), isFalse);
      expect(speeches.single.contains('lomeno'), isFalse);
      expect(speeches.single.contains('dostupný'), isFalse);
      expect(speeches.single.contains('is available'), isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}
