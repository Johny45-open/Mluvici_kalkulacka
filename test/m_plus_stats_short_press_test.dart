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
    testWidgets('M+ s jednou hodnotou oznami Připravena 1 hodnota', (
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
      // musi oznamit pocet pripravenych hodnot ceskou hlaskou
      expect(
        ttsLog.any((t) => t.contains('Připravena 1 hodnota')),
        isTrue,
        reason: 'TTS log: $ttsLog',
      );
      // nesmi spustit nesouvisejici obecnou hlasku "Přidat do statistické paměti" jako samostatny speak
      // (ta je jen semantics label, ne speak pri tapu)
      // overit ze se nehlasi jako duplicitni – povoleno max 1 speak s count
      // a zadny speak nesmi byt presne "Přidat do statistické paměti"
      expect(
        ttsLog.any((t) => t == 'Přidat do statistické paměti'),
        isFalse,
        reason: 'Nesmi se spustit obecna hlaska tlacitka: $ttsLog',
      );
      // hodnota se opravdu dostane do sady az v dialogu – zatim prazdne
      expect(state.statsMemoryForTest.length, 0);
      // dialog pro pocet opakovani je zobrazen
      expect(hasRepeatDialog(), isTrue);
      // potvrdit 1x
      await tester.tap(findConfirmButton());
      await tester.pumpAndSettle();
      expect(state.statsMemoryForTest.length, 1);
      expect(state.displayForTest, '');
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('M+ se dvema hodnotami oznami Připraveny 2 hodnoty', (
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
      expect(
        ttsLog.any((t) => t.contains('Připraveny 2 hodnoty')),
        isTrue,
        reason: 'TTS log: $ttsLog',
      );
      expect(state.statsMemoryForTest.length, 0);
      expect(hasRepeatDialog(), isTrue);
      // zrusit
      await tester.tap(findCancelButton());
      await tester.pumpAndSettle();
      expect(state.statsMemoryForTest.length, 0);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('M+ s peti hodnotami oznami Připraveno 5 hodnot', (
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
      expect(
        ttsLog.any((t) => t.contains('Připraveno 5 hodnot')),
        isTrue,
        reason: 'TTS log: $ttsLog',
      );
      expect(hasRepeatDialog(), isTrue);
      await tester.tap(findCancelButton());
      await tester.pumpAndSettle();
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

    testWidgets('existujici sada projde do repeat dialogu', (tester) async {
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
      expect(ttsLog.any((t) => t.contains('Připravena 1 hodnota')), isTrue);
      expect(hasRepeatDialog(), isTrue);
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
      // dale overit ze M+ pouziva spravny tvar v TTS
      await switchToStatistics(tester);
      state.addStatsSetForTest(
        StatisticsSet(name: 'Test', fieldNames: const ['Value'], records: []),
      );
      await tester.pumpAndSettle();
      // 2 hodnoty -> hodnoty
      ttsLog.clear();
      state.setDisplayForTest('1;2', 3);
      await state.addSingleValueToStatsForTest();
      await tester.pumpAndSettle();
      expect(ttsLog.any((t) => t.contains('hodnoty')), isTrue);
      await tester.tap(findCancelButton());
      await tester.pumpAndSettle();
      // 5 hodnot -> hodnot
      ttsLog.clear();
      state.setDisplayForTest('1;2;3;4;5', 9);
      await state.addSingleValueToStatsForTest();
      await tester.pumpAndSettle();
      expect(
        ttsLog.any((t) => t.contains('hodnot') && t.contains('5')),
        isTrue,
      );
      await tester.tap(findCancelButton());
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('hodnota se dostane do sady az po potvrzeni repeat dialogu', (
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
      // zmenit pocet opakovani na 2
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      await tester.enterText(textField, '2');
      await tester.pump();
      await tester.tap(findConfirmButton());
      await tester.pumpAndSettle();
      // 2 zaznamy *2 =4
      expect(state.statsMemoryForTest.length, 4);
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
}
