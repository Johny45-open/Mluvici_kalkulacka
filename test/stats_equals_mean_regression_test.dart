import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Regresní test: '=' ve Statistickém režimu počítá průměr z paměti.
// Dříve calculateResult() dělal List<double> data = List.from(_statsMemory),
// kde _statsMemory je List<StatisticsRecord> -> TypeError
// "type 'StatisticsRecord' is not a subtype of type 'double'"
// a displej zobrazil Error místo průměru.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'modeQuestionAsked': true,
    });
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
      MethodCall call,
    ) async {
      return 1;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.example.mluvici_kalkulacka/accessibility'), (
        MethodCall call,
      ) async {
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
  });

  Future<dynamic> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.localeTestValue = const Locale('cs');
    tester.platformDispatcher.textScaleFactorTestValue = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(const ScientificCalculatorApp(locale: Locale('cs')));
    await tester.pumpAndSettle();
    return tester.state(find.byType(CalculatorScreen)) as dynamic;
  }

  Future<void> switchToStatistics(WidgetTester tester) async {
    var chip = find.widgetWithText(ChoiceChip, 'Statistika');
    if (chip.evaluate().isEmpty) {
      chip = find.widgetWithText(ChoiceChip, 'Statistics');
    }
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  testWidgets("('=' ve statistickém režimu vypočte průměr, ne Error)", (
    tester,
  ) async {
    final state = await pumpApp(tester);
    await switchToStatistics(tester);
    // Sada se třemi hodnotami: průměr = 2, směrodatná odchylka = sqrt(2/3).
    state.addStatsSetForTest(
      StatisticsSet(
        name: 'Test',
        fieldNames: const ['Value'],
        records: [
          StatisticsRecord(values: [1]),
          StatisticsRecord(values: [2]),
          StatisticsRecord(values: [3]),
        ],
      ),
    );
    await tester.pumpAndSettle();
    // Displej nesmí být prázdný, jinak se calculateResult vrátí dřív.
    state.setDisplayForTest('1', 1);
    await tester.pump();
    state.calculateForTest();
    await tester.pump();
    // Před opravou skončil výpočet na TypeError a _lastResult byl 'Error'.
    expect(state.lastResultForTest, isNot('Error'));
    expect(
      double.parse(state.lastResultForTest),
      closeTo(2.0, 1e-9),
      reason:
          'Průměr z [1, 2, 3] má být 2, skutečný výsledek: '
          '${state.lastResultForTest}',
    );
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets("('=' s vícepole sadou počítá s vybraným polem, ne Error)", (
    tester,
  ) async {
    final state = await pumpApp(tester);
    await switchToStatistics(tester);
    // Vícepole sada: pole 0 = [10, 20, 30] (průměr 20), pole 1 = [1, 2, 3].
    state.addStatsSetForTest(
      StatisticsSet(
        name: 'VicePoli',
        fieldNames: const ['Value', 'Weight'],
        records: [
          StatisticsRecord(values: [10, 1]),
          StatisticsRecord(values: [20, 2]),
          StatisticsRecord(values: [30, 3]),
        ],
      ),
    );
    await tester.pumpAndSettle();
    state.setDisplayForTest('1', 1);
    await tester.pump();
    state.calculateForTest();
    await tester.pump();
    expect(state.lastResultForTest, isNot('Error'));
    expect(
      double.parse(state.lastResultForTest),
      closeTo(20.0, 1e-9),
      reason:
          'Průměr prvního pole [10, 20, 30] má být 20, skutečný výsledek: '
          '${state.lastResultForTest}',
    );
    await tester.pump(const Duration(seconds: 1));
  });

  // Cesta dialogu Paměť → "Uložit do proměnné": dialog volá přímo
  // storeCurrentValueToMemory (dialogs.dart), tedy tutéž business logiku
  // jako STO na klávesnici. Ukládání nesmí spadnout na statistické větvi
  // calculateResult a hodnota se musí dostat do _memory.
  testWidgets("('Uložit do proměnné' přes store funguje i ve statistickém režimu)", (
    tester,
  ) async {
    final state = await pumpApp(tester);
    await switchToStatistics(tester);
    state.addStatsSetForTest(
      StatisticsSet(
        name: 'Test',
        fieldNames: const ['Value'],
        records: [StatisticsRecord(values: [1])],
      ),
    );
    await tester.pumpAndSettle();
    state.setDisplayForTest('0.5', 3);
    await tester.pump();
    final ok = state.storeCurrentValueToMemory('A');
    await tester.pumpAndSettle();
    expect(ok, isTrue, reason: 'Ukládání do proměnné A se nesmí selhat');
    expect(
      state.memoryValueForTest('A'),
      isNotNull,
      reason: 'Proměnná A musí být po uložení v _memory',
    );
    expect(
      state.memoryValueForTest('A'),
      closeTo(0.5, 1e-9),
      reason: 'Proměnná A musí mít hodnotu 0.5',
    );
    await tester.pump(const Duration(seconds: 1));
  });
}
