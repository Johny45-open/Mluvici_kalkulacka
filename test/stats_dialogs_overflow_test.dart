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

  Future<void> openCreateDialog(
    WidgetTester tester, {
    required Size logicalSize,
    double textScale = 1.0,
  }) async {
    tester.platformDispatcher.clearAllTestValues();
    tester.view.physicalSize = logicalSize;
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(const ScientificCalculatorApp());
    await tester.pumpAndSettle();

    final statsChip = find.widgetWithText(ChoiceChip, 'Statistics');
    expect(statsChip, findsOneWidget, reason: 'Statistics mode chip missing');
    await tester.ensureVisible(statsChip);
    await tester.pumpAndSettle();
    await tester.tap(statsChip, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('SETS'), findsOneWidget);
    await tester.tap(find.text('SETS'));
    await tester.pumpAndSettle();

    final createButton = find.text('Create new set');
    expect(createButton, findsOneWidget, reason: 'Sets dialog did not open');
    await tester.tap(createButton);
    await tester.pumpAndSettle();
  }

  Future<void> addFields(WidgetTester tester, int count) async {
    for (var i = 0; i < count; i++) {
      final addField = find.text('Add field');
      expect(addField, findsOneWidget);
      await tester.ensureVisible(addField);
      await tester.tap(addField);
      await tester.pumpAndSettle();
    }
  }

  group('statistics set dialogs do not overflow', () {
    testWidgets('create dialog with many fields on 10" tablet landscape', (
      tester,
    ) async {
      await openCreateDialog(
        tester,
        logicalSize: const Size(1280, 800),
        textScale: 1.3,
      );
      await addFields(tester, 8);

      final confirm = find.text('Confirm');
      expect(confirm, findsOneWidget);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
    });

    testWidgets('edit fields dialog with many fields on 10" tablet', (
      tester,
    ) async {
      await openCreateDialog(
        tester,
        logicalSize: const Size(800, 1280),
        textScale: 1.3,
      );
      await addFields(tester, 6);

      final confirm = find.text('Confirm');
      expect(confirm, findsOneWidget);
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      await tester.tap(find.text('SETS'), warnIfMissed: false);
      await tester.pumpAndSettle();

      final editFieldsIcon = find.byIcon(Icons.view_list);
      expect(editFieldsIcon, findsOneWidget);
      await tester.tap(editFieldsIcon.first);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Fields of set'),
        findsOneWidget,
        reason: 'Edit fields dialog did not open',
      );
    });

    testWidgets('create dialog with many fields on small phone', (
      tester,
    ) async {
      await openCreateDialog(
        tester,
        logicalSize: const Size(412, 860),
        textScale: 1.3,
      );
      await addFields(tester, 6);

      final confirm = find.text('Confirm');
      expect(confirm, findsOneWidget);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
    });
  });
}
