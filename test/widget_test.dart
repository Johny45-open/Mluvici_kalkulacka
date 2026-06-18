// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mluvici_kalkulacka/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'accessibilityType': 0,
      'ttsEnabled': false,
    });
  });

  testWidgets('Scientific calculator app test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ScientificCalculatorApp());

    // Verify some text in the UI (e.g. title of the app bar)
    expect(find.text('Mluvící kalkulačka'), findsOneWidget);
  });

  testWidgets('MR ve statistickém režimu zobrazí dialog četností', (
    WidgetTester tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(const ScientificCalculatorApp());
      await tester.tap(find.text('Statistika'));
      await tester.pumpAndSettle();

      Future<void> addValueOne() async {
        await tester.tap(find.text('1').last);
        await tester.pump();
        await tester.tap(find.text('M+'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Potvrdit'));
        await tester.pumpAndSettle();
      }

      await addValueOne();
      await addValueOne();

      await tester.tap(find.text('MR'));
      await tester.pumpAndSettle();

      final dialog = find.byType(AlertDialog);
      expect(find.text('Statistická paměť'), findsOneWidget);
      expect(
        find.descendant(
          of: dialog,
          matching: find.text('Celkem hodnot: 2\nRůzných hodnot: 1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Hodnota')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Počet výskytů')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('1')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('2')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Hodnota 1, počet výskytů: 2.'),
        findsOneWidget,
      );
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets(
    'Elektro režim počítá napětí, proud i odpor podle zvoleného cíle',
    (WidgetTester tester) async {
      await tester.pumpWidget(const ScientificCalculatorApp());
      await tester.tap(find.text('Elektro'));
      await tester.pumpAndSettle();

      Future<void> tapButton(String label) async {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }

      Future<void> enterSequence(List<String> labels) async {
        for (final label in labels) {
          await tapButton(label);
        }
      }

      await tapButton('OHM_R');
      await enterSequence(['1', '2', ';', '2', '=']);

      await tapButton('OHM_V');
      await enterSequence(['2', ';', '6', '=']);

      await tapButton('OHM_I');
      await enterSequence(['1', '2', ';', '6', '=']);

      await tester.tap(find.byTooltip('Historie'));
      await tester.pumpAndSettle();

      final dialog = find.byType(AlertDialog);
      expect(
        find.descendant(of: dialog, matching: find.text('OHM_R(12;2)')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('6')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('OHM_V(2;6)')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('12')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('OHM_I(12;6)')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('2')),
        findsOneWidget,
      );
    },
  );
}
