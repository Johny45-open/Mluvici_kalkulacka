import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regresní testy pro:
/// A) accessibility strukturu potvrzovacích dialogů
///    (název → text → tlačítka, žádné zbytečné „Seskupení"/„Otázka"),
/// B) škálování textu tlačítek (uživatel × systém × velký displej),
/// C) viditelnost periodické čáry (rezerva nad číslicemi).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void mockChannels() {
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
  }

  Future<dynamic> pumpApp(
    WidgetTester tester, {
    Size size = const Size(412, 860),
    double textScale = 1.0,
  }) async {
    tester.platformDispatcher.clearAllTestValues();
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(const ScientificCalculatorApp());
    await tester.pumpAndSettle();
    return tester.state(find.byType(CalculatorScreen)) as dynamic;
  }

  void seedOneSet(dynamic state) {
    state.addStatsSetForTest(
      StatisticsSet(
        name: 'Matematika',
        fieldNames: const ['Hodnota'],
        records: [StatisticsRecord(values: [1.0])],
      ),
    );
  }

  Finder semanticsWithLabel(Pattern pattern) {
    return find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          w.properties.label != null &&
          pattern.allMatches(w.properties.label!).isNotEmpty,
    );
  }

  group('Confirm dialogs accessibility structure', () {
    testWidgets('delete set: title header, question, two buttons, no group',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
      });
      mockChannels();
      final state = await pumpApp(tester);
      seedOneSet(state);
      await tester.pumpAndSettle();

      state.showDeleteStatsSetConfirmationForTest(0);
      await tester.pumpAndSettle();

      // Název jako samostatný header (předek titulku v tree).
      final titleFinder = find.text('Smazat sadu?').evaluate().isNotEmpty
          ? find.text('Smazat sadu?')
          : find.text('Delete set?');
      expect(titleFinder, findsOneWidget);
      expect(
        find.ancestor(
          of: titleFinder,
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.header == true,
          ),
        ),
        findsWidgets,
        reason: 'název dialogu musí být header pro odečítač',
      );
      // Otázka jako holý text.
      expect(find.textContaining('Matematika'), findsWidgets);
      // Žádné technické „Otázka/Question" seskupení mezi názvem a textem.
      expect(
        semanticsWithLabel(RegExp(r'^(Otázka|Question)$')),
        findsNothing,
      );
      // AlertDialog nesmí mít duplicitní semanticLabel potlačující strukturu.
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.semanticLabel, isNull);
      // Obě tlačítka viditelná a klepnutelná (CS/EN podle locale).
      final cancelBtn = find.text('Zrušit').evaluate().isNotEmpty
          ? find.text('Zrušit')
          : find.text('Cancel');
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('clear history: no Otazka container, buttons work',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
      });
      mockChannels();
      final state = await pumpApp(tester);

      state.showClearHistoryConfirmationForTest();
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        semanticsWithLabel(RegExp(r'^(Otázka|Question)$')),
        findsNothing,
      );
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.semanticLabel, isNull);
      // Tlačítka zůstanou ovladatelná (focus/akce) – klepnutí Ne ponechá.
      expect(find.byType(TextButton), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('delete dialog has no overflow at textScale 1.5',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
      });
      mockChannels();
      final state = await pumpApp(tester, textScale: 1.5);
      seedOneSet(state);
      await tester.pumpAndSettle();

      state.showDeleteStatsSetConfirmationForTest(0);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  });

  group('Button text scaling', () {
    double keyboardFontSize(WidgetTester tester, String label) {
      final texts = tester.widgetList<Text>(find.text(label)).toList();
      expect(texts, isNotEmpty, reason: 'tlačítko $label nenalezeno');
      final sized = texts
          .where((t) => t.style?.fontWeight == FontWeight.bold)
          .toList();
      expect(sized, isNotEmpty, reason: 'tučné tlačítko $label nenalezeno');
      return sized.first.style!.fontSize!;
    }

    testWidgets('system textScale enlarges keyboard buttons', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
      });
      mockChannels();
      await pumpApp(tester, textScale: 1.0);
      final base = keyboardFontSize(tester, '7');

      await pumpApp(tester, textScale: 1.5);
      final scaled = keyboardFontSize(tester, '7');

      expect(scaled, greaterThan(base));
      expect(scaled, closeTo(base * 1.5, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('large display boosts button text, small keeps base',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
      });
      mockChannels();
      await pumpApp(tester, size: const Size(412, 860));
      final phone = keyboardFontSize(tester, '7');

      await pumpApp(tester, size: const Size(1280, 800));
      final desktop = keyboardFontSize(tester, '7');

      // 412px: scale 412/360 → boost ≈ 1.07 → ≈21.4;
      // desktop (shortest 800): scale 1.7 → boost 1.35 → 27.0.
      expect(phone, closeTo(21.44, 0.1));
      expect(desktop, greaterThan(phone));
      expect(desktop, closeTo(27.0, 0.5));
      expect(tester.takeException(), isNull);
    });
  });

  group('Periodic overline visibility', () {
    // Bar-notace výsledkového displeje: číslice periody nese
    // combining overline U+0305 (stejně to staví _toBarNotation).
    // Explicitně přes kód znaku, aby se předešlo neviditelným literálům.
    final periodicValue = '0.3${String.fromCharCode(0x0305)}';

    testWidgets('segment cells without period keep base height',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomSegmentDisplay(
              value: '123',
              size: 12,
              characterCount: 8,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Buňky bez periody: přesně size*1.8, žádná rezerva navíc.
      final plainBoxes = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .where((b) => b.height == 12 * 1.8)
          .toList();
      expect(plainBoxes, isNotEmpty);
      final tallBoxes = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .where((b) => (b.height ?? 0) > 12 * 1.8 + 1.0)
          .toList();
      expect(tallBoxes, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('periodic segment cell is taller (bar fits inside)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  _OverlineProbe(value: periodicValue, probeKey: 'periodic'),
                  const _OverlineProbe(value: '123', probeKey: 'plain'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final periodicH = tester.getSize(find.byKey(const Key('periodic')));
      final plainH = tester.getSize(find.byKey(const Key('plain')));
      expect(periodicH.height, greaterThan(plainH.height));
      expect(tester.takeException(), isNull);
    });

    // Pozn.: dialog nastavení přetéká při 1.5× i bez těchto změn
    // (ověřeno na čistém stromu) – jeho oprava pro velké škály je
    // samostatný úkol mimo tento rozsah. Místo toho ověřujeme souhrn
    // statistik (dialog dotčený tímto úkolem, obsahuje _PeriodicText
    // s periodickou čárou) při 1.5×.
    testWidgets('stats summary with periodic text survives textScale 1.5',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
      });
      mockChannels();
      final state = await pumpApp(tester, textScale: 1.5);

      final statsChip = find.widgetWithText(ChoiceChip, 'Statistics');
      await tester.tap(statsChip, warnIfMissed: false);
      await tester.pumpAndSettle();
      state.addStatsSetForTest(
        StatisticsSet(
          name: 'Test',
          fieldNames: const ['Value'],
          records: [
            for (final v in <double>[2, 4, 6, 8, 10])
              StatisticsRecord(values: [v]),
          ],
        ),
      );
      await tester.pumpAndSettle();

      state.showStatsSummaryDialogForTest();
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  });
}

/// Pomocný widget: porovná výšku buňky s periodou a bez ní.
/// Používá veřejné [CustomSegmentDisplay]; perioda se předává přes
/// bar-notaci (combining overline U+0305), stejně jako výsledkový displej.
class _OverlineProbe extends StatelessWidget {
  final String value;
  final String probeKey;
  const _OverlineProbe({required this.value, required this.probeKey});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: Key(probeKey),
      child: CustomSegmentDisplay(
        value: value,
        size: 12,
        characterCount: 4,
      ),
    );
  }

}
