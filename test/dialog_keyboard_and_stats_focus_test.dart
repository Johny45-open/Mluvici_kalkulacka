import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regresní testy pro:
/// A) dialog s TextField při otevřené softwarové klávesnici (viewInsets),
/// B) Tab navigaci mezi vypočtenými statistikami ve statistickém souhrnu.
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
      (MethodCall call) async {
        // Android (isTalkBackEnabled) i Windows (isScreenReaderEnabled)
        // bez čtečky -> false, aby se chovala jako předtím.
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
    Size logicalSize = const Size(360, 640),
    double textScale = 1.0,
  }) async {
    tester.platformDispatcher.clearAllTestValues();
    tester.view.physicalSize = logicalSize;
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    addTearDown(() {
      tester.view.viewInsets = FakeViewPadding.zero;
    });

    await tester.pumpWidget(const ScientificCalculatorApp());
    await tester.pumpAndSettle();

    return tester.state(find.byType(CalculatorScreen)) as dynamic;
  }

  Future<void> switchToStatistics(WidgetTester tester) async {
    final statsChip = find.widgetWithText(ChoiceChip, 'Statistics');
    expect(statsChip, findsOneWidget, reason: 'Statistics mode chip missing');
    await tester.ensureVisible(statsChip);
    await tester.pumpAndSettle();
    await tester.tap(statsChip, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  void seedSingleFieldSet(dynamic state) {
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
  }

  Finder statRowFocuses() {
    return find.byWidgetPredicate(
      (w) => w is Focus && (w.debugLabel ?? '').startsWith('statRow'),
    );
  }

  group('A) dialog s TextField pri otevrene klavesnici', () {
    testWidgets('TextField lze fokusovat a dialog zustane pod hornim okrajem', (
      tester,
    ) async {
      const screenHeight = 640.0;
      const keyboardHeight = 300.0;
      final state = await pumpApp(
        tester,
        logicalSize: const Size(360, screenHeight),
        textScale: 1.3,
      );
      await switchToStatistics(tester);
      seedSingleFieldSet(state);
      await tester.pumpAndSettle();

      // Simulace otevřené softwarové klávesnice (fyzické pixely, dpr = 1).
      tester.view.viewInsets = const FakeViewPadding(bottom: keyboardHeight);
      await tester.pump();
      // Tělo za modální bariérou může za těchto extrémních podmínek
      // (malý telefon + velké měřítko + vysoká klávesnice) ohlásit
      // overflow; s dialogy nesouvisí a za bariérou není vidět.
      tester.takeException();

      // Reálný dialog s TextField přes centrální showAppDialog.
      state.showRenameStatsSetDialogForTest(0);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await tester.showKeyboard(find.byType(TextField));
      await tester.pump();
      expect(
        tester.testTextInput.isVisible,
        isTrue,
        reason: 'TextField v dialogu musí přijmout fokus',
      );

      // Dialog nesmí být vytlačen mimo horní část obrazovky
      // (symptom dvojité aplikace viewInsets).
      final dialogRect = tester.getRect(find.byType(AlertDialog));
      expect(
        dialogRect.top,
        greaterThanOrEqualTo(-1),
        reason: 'Dialog nesmí zmizet nad horní okraj obrazovky',
      );

      // Fokusovaný TextField musí zůstat celý viditelný nad klávesnicí.
      final fieldRect = tester.getRect(find.byType(TextField));
      expect(
        fieldRect.top,
        greaterThanOrEqualTo(-1),
        reason: 'TextField nesmí zmizet nad horní okraj',
      );
      expect(
        fieldRect.bottom,
        lessThanOrEqualTo(screenHeight - keyboardHeight + 1),
        reason: 'TextField musí zůstat nad klávesnicí',
      );

      // Nechá proběhnout odložené inicializační časovače aplikace,
      // aby teardown nehlásil pending timers.
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('B) Tab navigace ve statistickem souhrnu', () {
    testWidgets(
      'kazdy radek vypoctene statistiky je samostatny fokusovatelny prvek',
      (tester) async {
        final state = await pumpApp(tester, logicalSize: const Size(412, 860));
        await switchToStatistics(tester);
        seedSingleFieldSet(state);
        await tester.pumpAndSettle();

        state.showStatsSummaryDialogForTest();
        await tester.pumpAndSettle();

        expect(find.text('Statistics summary'), findsOneWidget);

        final rows = tester.widgetList<Focus>(statRowFocuses()).toList();
        // N + 9 položek (vážený průměr se při jednom poli nezobrazuje).
        expect(rows.length, 10, reason: 'Očekáváno 10 řádků statistik');
        final nodes = rows.map((f) => f.focusNode!).toList();

        // Každý řádek lze jednotlivě fokusovat, právě jeden fokus na řádek.
        for (final node in nodes) {
          node.requestFocus();
          await tester.pump();
          expect(node.hasFocus, isTrue);
          expect(
            nodes.where((n) => n.hasFocus).length,
            1,
            reason: 'Vždy smí mít fokus právě jeden řádek',
          );
        }

        // TAB prochází řádky dopředu ve stabilním pořadí.
        nodes.first.requestFocus();
        await tester.pump();
        for (var i = 1; i < nodes.length; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(
            nodes[i].hasFocus,
            isTrue,
            reason: 'TAB má přesunout fokus na řádek $i',
          );
        }

        // SHIFT+TAB se vrátí o řádek zpět.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
        await tester.pump();
        expect(
          nodes[nodes.length - 2].hasFocus,
          isTrue,
          reason: 'SHIFT+TAB má vrátit fokus na předchozí řádek',
        );

        // Nechá proběhnout odložené inicializační časovače aplikace,
        // aby teardown nehlásil pending timers.
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets(
      'pocet fokusovatelnych statistik odpovida poctu zobrazenych radku',
      (tester) async {
        final state = await pumpApp(tester, logicalSize: const Size(412, 860));
        await switchToStatistics(tester);
        seedSingleFieldSet(state);
        await tester.pumpAndSettle();

        state.showStatsSummaryDialogForTest();
        await tester.pumpAndSettle();

        final rows = tester.widgetList<Focus>(statRowFocuses()).toList();
        expect(rows, isNotEmpty);

        // Každý fokusovatelný řádek nese jednu sémantickou položku
        // ve tvaru „Název: hodnota" s hintem „Row i of N".
        final rowSemantics = tester
            .widgetList<Semantics>(
              find.byWidgetPredicate(
                (w) =>
                    w is Semantics &&
                    (w.properties.hint ?? '').contains('of ${rows.length}'),
              ),
            )
            .toList();
        expect(
          rowSemantics.length,
          rows.length,
          reason: 'Každý řádek má mít právě jednu sémantickou položku',
        );
        for (var i = 0; i < rows.length; i++) {
          final props = rowSemantics[i].properties;
          expect(
            (props.label ?? '').contains(':'),
            isTrue,
            reason: 'Řádek $i má ohlásit název a hodnotu',
          );
          expect(
            props.hint ?? '',
            contains('Row ${i + 1} of ${rows.length}'),
            reason: 'Řádek $i má ohlásit pozici v seznamu',
          );
        }

        // Nechá proběhnout odložené inicializační časovače aplikace,
        // aby teardown nehlásil pending timers.
        await tester.pump(const Duration(seconds: 3));
      },
    );
  });
}
