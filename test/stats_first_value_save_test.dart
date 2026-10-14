import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Ulozeni prvni statisticke hodnoty: vytvoreni sady nesmi vynechat kontrolu
// ani zpusobit dvojite ulozeni. Kratky stisk -> po vytvoreni review dialog,
// dlouhy stisk -> po vytvoreni repeat dialog.
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

  bool hasReviewDialog() {
    return find.text('Kontrola dat před uložením').evaluate().isNotEmpty ||
        find.text('Review data before saving').evaluate().isNotEmpty;
  }

  bool hasRepeatDialog() {
    return find.text('Počet opakování').evaluate().isNotEmpty ||
        find.text('Repeat count').evaluate().isNotEmpty;
  }

  bool hasCreateSetDialog() {
    return find.text('Vytvořit novou sadu').evaluate().isNotEmpty ||
        find.text('Create new set').evaluate().isNotEmpty;
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

  group('ulozeni prvni statisticke hodnoty', () {
    testWidgets('kratky stisk: po vytvoreni sady probehne kontrola', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await switchToStatistics(tester);
      expect(state.statsSetsCountForTest, 0);
      state.setDisplayForTest('5', 1);
      await tester.pump();
      await state.addSingleValueToStatsForTest();
      await tester.pumpAndSettle();
      expect(hasCreateSetDialog(), isTrue);
      // potvrdit vytvoreni sady (vychozi nazev)
      await tester.tap(findConfirmButton());
      await tester.pumpAndSettle();
      // sada existuje, ale zatim nic ulozeno – ceka kontrola
      expect(state.statsSetsCountForTest, 1);
      expect(hasReviewDialog(), isTrue);
      expect(state.statsMemoryForTest.length, 0);
      // ulozit prave jednou
      await tester.tap(findSaveButton());
      await tester.pumpAndSettle();
      expect(state.statsMemoryForTest.length, 1);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('kratky stisk: zruseni kontroly po vytvoreni nic neulozi', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await switchToStatistics(tester);
      state.setDisplayForTest('5', 1);
      await tester.pump();
      await state.addSingleValueToStatsForTest();
      await tester.pumpAndSettle();
      await tester.tap(findConfirmButton());
      await tester.pumpAndSettle();
      expect(hasReviewDialog(), isTrue);
      await tester.tap(findCancelButton());
      await tester.pumpAndSettle();
      expect(state.statsSetsCountForTest, 1);
      expect(state.statsMemoryForTest.length, 0);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('dlouhy stisk: po vytvoreni sady zustane repeat dialog', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await switchToStatistics(tester);
      state.setDisplayForTest('5', 1);
      await tester.pump();
      await state.handleMultipleStatisticsAdditionForTest();
      await tester.pumpAndSettle();
      expect(hasCreateSetDialog(), isTrue);
      await tester.tap(findConfirmButton());
      await tester.pumpAndSettle();
      expect(state.statsSetsCountForTest, 1);
      expect(hasRepeatDialog(), isTrue);
      expect(state.statsMemoryForTest.length, 0);
      // opakovat 2x -> presne 2 zaznamy
      await tester.enterText(find.byType(TextField), '2');
      await tester.pump();
      await tester.tap(findConfirmButton());
      await tester.pumpAndSettle();
      expect(state.statsMemoryForTest.length, 2);
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
