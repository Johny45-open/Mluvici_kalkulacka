import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Validace poctu opakovani v dialogu dlouheho stisku M+:
// neplatny vstup nesmi nic ulozit, nesmi vymazat displej a dialog zustava
// otevreny pro opravu. Hranice 1 a 1000 (kMaxStatsRepeatCount) projdou.
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

  bool hasRepeatDialog() {
    return find.text('Počet opakování').evaluate().isNotEmpty ||
        find.text('Repeat count').evaluate().isNotEmpty;
  }

  Finder findConfirmButton() {
    var f = find.widgetWithText(TextButton, 'Potvrdit');
    if (f.evaluate().isEmpty) f = find.widgetWithText(TextButton, 'Confirm');
    return f;
  }

  Future<void> openRepeatDialog(WidgetTester tester, dynamic state) async {
    state.addStatsSetForTest(
      StatisticsSet(name: 'Test', fieldNames: const ['Value'], records: []),
    );
    await tester.pumpAndSettle();
    state.setDisplayForTest('5', 1);
    await tester.pump();
    await state.handleMultipleStatisticsAdditionForTest();
    await tester.pumpAndSettle();
    expect(hasRepeatDialog(), isTrue);
    expect(find.byType(TextField), findsOneWidget);
  }

  group('validace poctu opakovani', () {
    for (final bad in <String>[
      '',
      'abc',
      '0',
      '-2',
      '3.5',
      '1001',
      '1000000',
      '99999999999999999999999',
    ]) {
      testWidgets('neplatny pocet "$bad": nic se neulozi, dialog zustava', (
        tester,
      ) async {
        final state = await pumpApp(tester);
        await switchToStatistics(tester);
        await openRepeatDialog(tester, state);
        ttsLog.clear();
        await tester.enterText(find.byType(TextField), bad);
        await tester.pump();
        await tester.tap(findConfirmButton());
        await tester.pumpAndSettle();
        // nic se neulozilo
        expect(state.statsMemoryForTest.length, 0);
        // displej se nevymazal
        expect(state.displayForTest, '5');
        // dialog zustava otevreny pro opravu
        expect(hasRepeatDialog(), isTrue);
        // viditelna chyba v poli + jedno oznameni rozsahu
        expect(find.textContaining('od 1 do 1000'), findsOneWidget);
        expect(
          ttsLog.any((t) => t.contains('od 1 do 1000')),
          isTrue,
          reason: 'TTS log: $ttsLog',
        );
        await tester.pump(const Duration(seconds: 1));
      });
    }

    testWidgets('hranice 1 projde a ulozi prave jednou', (tester) async {
      final state = await pumpApp(tester);
      await switchToStatistics(tester);
      await openRepeatDialog(tester, state);
      await tester.enterText(find.byType(TextField), '1');
      await tester.pump();
      await tester.tap(findConfirmButton());
      await tester.pumpAndSettle();
      expect(state.statsMemoryForTest.length, 1);
      expect(hasRepeatDialog(), isFalse);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('hranice 1000 projde a ulozi presne 1000 zaznamu', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await switchToStatistics(tester);
      await openRepeatDialog(tester, state);
      await tester.enterText(find.byType(TextField), '1000');
      await tester.pump();
      await tester.tap(findConfirmButton());
      await tester.pumpAndSettle();
      expect(state.statsMemoryForTest.length, 1000);
      expect(hasRepeatDialog(), isFalse);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('po chybe lze opravit a ulozit', (tester) async {
      final state = await pumpApp(tester);
      await switchToStatistics(tester);
      await openRepeatDialog(tester, state);
      await tester.enterText(find.byType(TextField), '0');
      await tester.pump();
      await tester.tap(findConfirmButton());
      await tester.pumpAndSettle();
      expect(state.statsMemoryForTest.length, 0);
      expect(hasRepeatDialog(), isTrue);
      // oprava vstupu a potvrzeni
      await tester.enterText(find.byType(TextField), '3');
      await tester.pump();
      await tester.tap(findConfirmButton());
      await tester.pumpAndSettle();
      expect(state.statsMemoryForTest.length, 3);
      expect(hasRepeatDialog(), isFalse);
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
