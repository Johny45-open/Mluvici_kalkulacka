import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Captured TTS texts via flutter_tts channel
  final List<String> ttsLog = [];
  final List<String> announceLog = [];

  setUp(() {
    ttsLog.clear();
    announceLog.clear();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'modeQuestionAsked': true,
    });
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
      MethodCall call,
    ) async {
      if (call.method == 'speak') {
        final text = call.arguments as String? ?? '';
        ttsLog.add(text);
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
        if (call.method == 'announce' ||
            call.method == 'announceForAccessibility') {
          // not used directly – SemanticsService.announce uses different channel
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

  bool hasRepeatDialog() {
    return find.text('Počet opakování').evaluate().isNotEmpty ||
        find.text('Repeat count').evaluate().isNotEmpty;
  }

  bool hasReviewDialog() {
    return find.text('Kontrola dat před uložením').evaluate().isNotEmpty ||
        find.text('Review data before saving').evaluate().isNotEmpty;
  }

  Finder findSaveButton() {
    var f = find.widgetWithText(TextButton, 'Uložit');
    if (f.evaluate().isEmpty) f = find.widgetWithText(TextButton, 'Save');
    return f;
  }

  Finder findConfirmButton() {
    var f = find.widgetWithText(TextButton, 'Potvrdit');
    if (f.evaluate().isEmpty) f = find.widgetWithText(TextButton, 'Confirm');
    return f;
  }

  Finder findCancelButton() {
    var f = find.widgetWithText(TextButton, 'Zrušit');
    if (f.evaluate().isEmpty) f = find.widgetWithText(TextButton, 'Cancel');
    return f;
  }

  group('M+ kratky stisk ve Statistickem rezimu', () {
    testWidgets('M+ s jednou hodnotou otevre kontrolni dialog bez pole poctu', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await switchToStatistics(tester);
      state.addStatsSetForTest(
        StatisticsSet(name: 'Test', fieldNames: const ['Value'], records: []),
      );
      await tester.pumpAndSettle();
      ttsLog.clear();
      state.setDisplayForTest('5', 1);
      await tester.pump();
      await state.addSingleValueToStatsForTest();
      await tester.pumpAndSettle();
      // kontrolni dialog je zobrazen, repeat dialog nikoli
      expect(hasReviewDialog(), isTrue);
      expect(hasRepeatDialog(), isFalse);
      // zadne pole pro pocet opakovani
      expect(find.byType(TextField), findsNothing);
      // souhrn se jednou ohlasi
      expect(
        ttsLog.any((t) => t.contains('Připraveno 1 záznam')),
        isTrue,
        reason: 'TTS log: $ttsLog',
      );
      // nesmi spustit nesouvisejici obecnou hlasku jako samostatny speak
      expect(
        ttsLog.any((t) => t == 'Přidat do statistické paměti'),
        isFalse,
        reason: 'Nesmi se spustit obecna hlaska tlacitka: $ttsLog',
      );
      // hodnota se opravdu dostane do sady az po Ulozit – zatim prazdne
      expect(state.statsMemoryForTest.length, 0);
      // ulozit prave jednou
      await tester.tap(findSaveButton());
      await tester.pumpAndSettle();
      expect(state.statsMemoryForTest.length, 1);
      expect(state.displayForTest, '');
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('M+ se dvema hodnotami zobrazi obe a Zrusit nic neulozi', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await switchToStatistics(tester);
      state.addStatsSetForTest(
        StatisticsSet(name: 'Test', fieldNames: const ['Value'], records: []),
      );
      await tester.pumpAndSettle();
      ttsLog.clear();
      state.setDisplayForTest('5;10', 4);
      await tester.pump();
      await state.addSingleValueToStatsForTest();
      await tester.pumpAndSettle();
      expect(hasReviewDialog(), isTrue);
      expect(hasRepeatDialog(), isFalse);
      expect(find.byType(TextField), findsNothing);
      expect(state.statsMemoryForTest.length, 0);
      // zrusit
      await tester.tap(findCancelButton());
      await tester.pumpAndSettle();
      expect(state.statsMemoryForTest.length, 0);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('M+ s peti hodnotami ulozi kazdou prave jednou', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await switchToStatistics(tester);
      state.addStatsSetForTest(
        StatisticsSet(name: 'Test', fieldNames: const ['Value'], records: []),
      );
      await tester.pumpAndSettle();
      ttsLog.clear();
      state.setDisplayForTest('5;10;15;20;25', 14);
      await tester.pump();
      await state.addSingleValueToStatsForTest();
      await tester.pumpAndSettle();
      expect(hasReviewDialog(), isTrue);
      await tester.tap(findSaveButton());
      await tester.pumpAndSettle();
      expect(state.statsMemoryForTest.length, 5);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('prazdny displej zachova hlasku', (tester) async {
      final state = await pumpApp(tester);
      await switchToStatistics(tester);
      state.addStatsSetForTest(
        StatisticsSet(name: 'Test', fieldNames: const ['Value'], records: []),
      );
      await tester.pumpAndSettle();
      ttsLog.clear();
      state.setDisplayForTest('', 0);
      await tester.pump();
      await state.addSingleValueToStatsForTest();
      await tester.pumpAndSettle();
      expect(
        ttsLog.any((t) => t.contains('Displej je prázdný')),
        isTrue,
        reason: 'TTS log: $ttsLog',
      );
      expect(hasRepeatDialog(), isFalse);
      expect(hasReviewDialog(), isFalse);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('neexistujici sada zachova logiku vytvoreni', (tester) async {
      final state = await pumpApp(tester);
      await switchToStatistics(tester);
      // zadna sada
      expect(state.statsSetsCountForTest, 0);
      ttsLog.clear();
      state.setDisplayForTest('5', 1);
      await tester.pump();
      await state.addSingleValueToStatsForTest();
      await tester.pumpAndSettle();
      expect(
        ttsLog.any((t) => t.contains('Není vytvořena žádná statistická sada')),
        isTrue,
        reason: 'TTS log: $ttsLog',
      );
      expect(
        find.text('Vytvořit novou sadu').evaluate().isNotEmpty ||
            find.text('Create new set').evaluate().isNotEmpty,
        isTrue,
      );
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('existujici sada zobrazi kontrolu s nazvem sady', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await switchToStatistics(tester);
      state.addStatsSetForTest(
        StatisticsSet(
          name: 'MojeSada',
          fieldNames: const ['Value'],
          records: [
            StatisticsRecord(values: [1]),
          ],
        ),
      );
      await tester.pumpAndSettle();
      ttsLog.clear();
      state.setDisplayForTest('42', 2);
      await tester.pump();
      await state.addSingleValueToStatsForTest();
      await tester.pumpAndSettle();
      expect(ttsLog.any((t) => t.contains('Připraveno 1 záznam')), isTrue);
      expect(hasReviewDialog(), isTrue);
      // overit ze summary v dialogu obsahuje nazev sady
      expect(find.textContaining('MojeSada'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('ceske sklonovani pomoci _getStatsCountForm', (tester) async {
      final state = await pumpApp(tester);
      expect(state.getStatsCountFormForTest(1), 'hodnota');
      expect(state.getStatsCountFormForTest(2), 'hodnoty');
      expect(state.getStatsCountFormForTest(3), 'hodnoty');
      expect(state.getStatsCountFormForTest(4), 'hodnoty');
      expect(state.getStatsCountFormForTest(5), 'hodnot');
      expect(state.getStatsCountFormForTest(11), 'hodnot');
      expect(state.getStatsCountFormForTest(21), 'hodnot');
      // kratky stisk pro 2 hodnoty otevre kontrolu (bez pole poctu)
      await switchToStatistics(tester);
      state.addStatsSetForTest(
        StatisticsSet(name: 'Test', fieldNames: const ['Value'], records: []),
      );
      await tester.pumpAndSettle();
      state.setDisplayForTest('1;2', 3);
      await state.addSingleValueToStatsForTest();
      await tester.pumpAndSettle();
      expect(hasReviewDialog(), isTrue);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(findCancelButton());
      await tester.pumpAndSettle();
      expect(state.statsMemoryForTest.length, 0);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('hodnota se dostane do sady az po Ulozit v kontrole', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await switchToStatistics(tester);
      state.addStatsSetForTest(
        StatisticsSet(name: 'Test', fieldNames: const ['Value'], records: []),
      );
      await tester.pumpAndSettle();
      final before = state.statsMemoryForTest.length;
      state.setDisplayForTest('7;8', 3);
      await state.addSingleValueToStatsForTest();
      await tester.pumpAndSettle();
      expect(
        state.statsMemoryForTest.length,
        before,
        reason: 'Pred potvrzenim nesmi byt ulozeno',
      );
      await tester.tap(findSaveButton());
      await tester.pumpAndSettle();
      // 2 zaznamy, kazdy prave jednou (bez nasobeni)
      expect(state.statsMemoryForTest.length, 2);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('M+ nespusti nesouvisejici obecnou TTS vysledku', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await switchToStatistics(tester);
      state.addStatsSetForTest(
        StatisticsSet(name: 'Test', fieldNames: const ['Value'], records: []),
      );
      await tester.pumpAndSettle();
      // nastavit _hasResult via vypocet
      state.setDisplayForTest('2+2', 3);
      state.calculateForTest();
      await tester.pump();
      // display je '' a _hasResult true, ale M+ s prazdnym display ma hlasit prazdny
      // pokud je display prazdny, nesmi se spustit "Výsledek je" nebo "resultOf"
      ttsLog.clear();
      state.setDisplayForTest('', 0);
      await state.addSingleValueToStatsForTest();
      await tester.pumpAndSettle();
      expect(
        ttsLog.any((t) => t.contains('Výsledek je') || t.contains('resultOf')),
        isFalse,
        reason: 'TTS log nesmi obsahovat obecnou hlasku vysledku: $ttsLog',
      );
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('M+ dlouhy stisk ve Statistickem rezimu', () {
    testWidgets('dlouhy stisk zachova pole pro pocet opakovani', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await switchToStatistics(tester);
      state.addStatsSetForTest(
        StatisticsSet(name: 'Test', fieldNames: const ['Value'], records: []),
      );
      await tester.pumpAndSettle();
      state.setDisplayForTest('7;8', 3);
      await tester.pump();
      await state.handleMultipleStatisticsAdditionForTest();
      await tester.pumpAndSettle();
      expect(hasRepeatDialog(), isTrue);
      expect(hasReviewDialog(), isFalse);
      // pole pro pocet je pritomno
      expect(find.byType(TextField), findsOneWidget);
      // zmenit pocet opakovani na 2
      await tester.enterText(find.byType(TextField), '2');
      await tester.pump();
      await tester.tap(findConfirmButton());
      await tester.pumpAndSettle();
      // 2 zaznamy * 2 = 4
      expect(state.statsMemoryForTest.length, 4);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('dlouhy stisk gestem na tlacitku M+ otevre repeat dialog', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await switchToStatistics(tester);
      state.addStatsSetForTest(
        StatisticsSet(name: 'Test', fieldNames: const ['Value'], records: []),
      );
      await tester.pumpAndSettle();
      state.setDisplayForTest('9', 1);
      await tester.pump();
      await tester.longPress(find.text('M+'));
      await tester.pumpAndSettle();
      expect(hasRepeatDialog(), isTrue);
      await tester.tap(findCancelButton());
      await tester.pumpAndSettle();
      expect(state.statsMemoryForTest.length, 0);
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
