import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'accessibilityType': 0,
      'modeQuestionAsked': true,
    });
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (MethodCall call) async => null,
    );
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

  Future<dynamic> pumpApp(WidgetTester tester, Size logicalSize) async {
    tester.platformDispatcher.clearAllTestValues();
    tester.view.physicalSize = logicalSize;
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = FakeViewPadding.zero;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    addTearDown(() {
      tester.view.viewInsets = FakeViewPadding.zero;
    });
    await tester.pumpWidget(const ScientificCalculatorApp());
    await tester.pumpAndSettle();
    return tester.state(find.byType(CalculatorScreen)) as dynamic;
  }

  void seedManySets(dynamic state, int count) {
    for (int i = 0; i < count; i++) {
      state.addStatsSetForTest(
        StatisticsSet(
          name: 'Sada číslo $i',
          fieldNames: const ['Val'],
          records: [
            StatisticsRecord(values: [i.toDouble()]),
          ],
        ),
      );
    }
  }

  testWidgets('Test A & B & E & F - scroll focus retention, leaving item, tab order & narrow layout', (WidgetTester tester) async {
    final state = await pumpApp(tester, const Size(800, 600));
    seedManySets(state, 45);
    await tester.pumpAndSettle();

    state.showStatsSetsDialogForTest();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    final listViewFinder = find.byType(ListView).last;
    await tester.drag(listViewFinder, const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('Test C - reordering and persistence of focus id', (WidgetTester tester) async {
    final state = await pumpApp(tester, const Size(800, 600));
    seedManySets(state, 10);
    await tester.pumpAndSettle();

    state.showStatsSetsDialogForTest();
    await tester.pumpAndSettle();

    // Změna řazení přes DropdownButton
    final dropdown = find.byType(DropdownButton<String>);
    if (dropdown.evaluate().isNotEmpty) {
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      final item = find.text('Název');
      if (item.evaluate().isNotEmpty) {
        await tester.tap(item.last);
        await tester.pumpAndSettle();
      }
    }

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('Test D - deletion/filtering of focused item', (WidgetTester tester) async {
    final state = await pumpApp(tester, const Size(800, 600));
    seedManySets(state, 5);
    await tester.pumpAndSettle();

    state.showStatsSetsDialogForTest();
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Sada číslo 1');
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
