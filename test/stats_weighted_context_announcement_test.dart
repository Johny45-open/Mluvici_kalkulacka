import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Regresní test: kontext vah ("pole X váženo polem Y") se v mluveném
// souhrnu statistik naráže jen jednou – u první vážené statistiky
// v pořadí čtení, ne u každé z WMEAN/WVAR/WSD/WCV.
// Dříve se hláška opakovala za váženým průměrem, rozptylem, směrodatnou
// odchylkou i variačním koeficientem.
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
  });

  Future<dynamic> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.localeTestValue = const Locale('cs');
    tester.platformDispatcher.textScaleFactorTestValue = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(
      const ScientificCalculatorApp(locale: Locale('cs')),
    );
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

  testWidgets(
    'Kontext vah se naráže jen jednou (u první vážené statistiky)',
    (tester) async {
      final state = await pumpApp(tester);
      await switchToStatistics(tester);
      // Dvěpole sada: pole 0 = hodnoty, pole 1 = váhy.
      state.addStatsSetForTest(
        StatisticsSet(
          name: 'Vážená sada',
          fieldNames: const ['Hodnoty', 'Váhy'],
          records: [
            StatisticsRecord(values: [10, 1]),
            StatisticsRecord(values: [20, 2]),
            StatisticsRecord(values: [30, 3]),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final summary = state.orderedSpokenSummaryForTest(0) as String;

      // Všechny čtyři vážené charakteristiky musí být v souhrnu přítomny.
      expect(summary.contains('Vážený průměr'), isTrue,
          reason: 'Vážený průměr chybí v: $summary');
      expect(summary.contains('Vážený rozptyl'), isTrue,
          reason: 'Vážený rozptyl chybí v: $summary');
      expect(summary.contains('Vážená směrodatná odchylka'), isTrue,
          reason: 'Vážená směrodatná odchylka chybí v: $summary');
      expect(summary.contains('Vážený variační koeficient'), isTrue,
          reason: 'Vážený variační koeficient chybí v: $summary');

      // Kontext vah se vyskytne přesně jednou, ne u každé vážené statistiky.
      final contextCount = 'pole Hodnoty váženo polem Váhy'
          .allMatches(summary)
          .length;
      expect(
        contextCount,
        1,
        reason: 'Kontext vah se opakuje $contextCount× v: $summary',
      );

      await tester.pump(const Duration(seconds: 1));
    },
  );
}
