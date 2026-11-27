import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Úprava počtu výskytů v dialogu statistické paměti (tlačítko MR):
// pole "Počet výskytů" sníží nebo zvýší počet jen u upravované hodnoty,
// ostatní záznamy zůstávají nedotčené (uživatel nemusí mazat celou paměť).
// Neplatný počet nic neuloží a dialog zůstává otevřený pro opravu.
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

  Future<dynamic> pumpApp(
    WidgetTester tester, {
    Locale locale = const Locale('cs'),
  }) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.localeTestValue = locale;
    tester.platformDispatcher.textScaleFactorTestValue = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(ScientificCalculatorApp(locale: locale));
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

  List<StatisticsRecord> recordsOf(List<double> values) {
    return values.map((v) => StatisticsRecord(values: [v])).toList();
  }

  // Otevře sadu s danými hodnotami a přes MR dialog statistické paměti.
  Future<dynamic> openMemoryDialog(
    WidgetTester tester, {
    required List<double> values,
  }) async {
    final state = await pumpApp(tester);
    await switchToStatistics(tester);
    state.addStatsSetForTest(
      StatisticsSet(
        name: 'Test',
        fieldNames: const ['Hodnota'],
        records: recordsOf(values),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('MR'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    return state;
  }

  Finder editIcons() {
    return find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byIcon(Icons.edit),
    );
  }

  Finder countField() {
    final byLabel = find.widgetWithText(TextField, 'Počet výskytů');
    if (byLabel.evaluate().isNotEmpty) return byLabel;
    return find.widgetWithText(TextField, 'Occurrences');
  }

  Finder findConfirmButton() {
    var f = find.widgetWithText(TextButton, 'Potvrdit');
    if (f.evaluate().isEmpty) f = find.widgetWithText(TextButton, 'Confirm');
    return f;
  }

  List<double> storedValues(dynamic state) {
    final values = state.statsMemoryForTest
        .map<double>((r) => r.values.first as double)
        .toList();
    return values;
  }

  group('úprava počtu výskytů v statistické paměti', () {
    testWidgets('snížení počtu 142 z 5 na 3, 141 zůstává 3×', (tester) async {
      final state = await openMemoryDialog(
        tester,
        values: [141, 141, 141, 142, 142, 142, 142, 142],
      );
      expect(state.statsMemoryForTest.length, 8);
      expect(editIcons(), findsNWidgets(2));

      // Druhá skupina (142) je podle vzestupného řazení druhá.
      await tester.tap(editIcons().at(1), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(2));

      await tester.enterText(countField(), '3');
      await tester.pump();
      await tester.tap(findConfirmButton());
      await tester.pumpAndSettle();

      expect(state.statsMemoryForTest.length, 6);
      expect(storedValues(state), [141, 141, 141, 142, 142, 142]);
      // Dialog paměti zůstává otevřený a obě skupiny teď mají 3 výskyty.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('3×'), findsNWidgets(2));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('zvýšení počtu 141 z 3 na 5, 142 zůstává 5×', (tester) async {
      final state = await openMemoryDialog(
        tester,
        values: [141, 141, 141, 142, 142, 142, 142, 142],
      );

      await tester.tap(editIcons().at(0), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.enterText(countField(), '5');
      await tester.pump();
      await tester.tap(findConfirmButton());
      await tester.pumpAndSettle();

      expect(state.statsMemoryForTest.length, 10);
      expect(storedValues(state)..sort(), [
        141,
        141,
        141,
        141,
        141,
        142,
        142,
        142,
        142,
        142,
      ]);
      expect(find.text('5×'), findsNWidgets(2));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('změna hodnoty i počtu naráz: 142 (5×) na 143 (2×)', (
      tester,
    ) async {
      final state = await openMemoryDialog(
        tester,
        values: [141, 141, 141, 142, 142, 142, 142, 142],
      );

      await tester.tap(editIcons().at(1), warnIfMissed: false);
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '143');
      await tester.pump();
      await tester.enterText(countField(), '2');
      await tester.pump();
      await tester.tap(findConfirmButton());
      await tester.pumpAndSettle();

      expect(state.statsMemoryForTest.length, 5);
      expect(storedValues(state)..sort(), [141, 141, 141, 143, 143]);
      await tester.pump(const Duration(seconds: 1));
    });

    for (final bad in <String>['', '0', '-2', 'abc', '3.5', '1001']) {
      testWidgets('neplatný počet "$bad": nic se neuloží, dialog zůstává', (
        tester,
      ) async {
        final state = await openMemoryDialog(
          tester,
          values: [141, 141, 141, 142, 142, 142, 142, 142],
        );
        await tester.tap(editIcons().at(1), warnIfMissed: false);
        await tester.pumpAndSettle();
        ttsLog.clear();

        await tester.enterText(countField(), bad);
        await tester.pump();
        await tester.tap(findConfirmButton());
        await tester.pumpAndSettle();

        // paměť beze změny
        expect(state.statsMemoryForTest.length, 8);
        expect(storedValues(state), [141, 141, 141, 142, 142, 142, 142, 142]);
        // dialog úpravy zůstává otevřený pro opravu
        expect(find.byType(TextField), findsNWidgets(2));
        // viditelná chyba v poli + ohlášení rozsahu
        expect(find.textContaining('od 1 do 1000'), findsOneWidget);
        expect(
          ttsLog.any((t) => t.contains('od 1 do 1000')),
          isTrue,
          reason: 'TTS log: $ttsLog',
        );
        await tester.pump(const Duration(seconds: 1));
      });
    }

    testWidgets('po chybě lze počet opravit a uložit', (tester) async {
      final state = await openMemoryDialog(
        tester,
        values: [141, 141, 141, 142, 142, 142, 142, 142],
      );
      await tester.tap(editIcons().at(1), warnIfMissed: false);
      await tester.pumpAndSettle();

      await tester.enterText(countField(), '0');
      await tester.pump();
      await tester.tap(findConfirmButton());
      await tester.pumpAndSettle();
      expect(state.statsMemoryForTest.length, 8);

      await tester.enterText(countField(), '2');
      await tester.pump();
      await tester.tap(findConfirmButton());
      await tester.pumpAndSettle();

      expect(state.statsMemoryForTest.length, 5);
      expect(storedValues(state), [141, 141, 141, 142, 142]);
      // dialog úpravy se zavřel, paměť zůstává
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
