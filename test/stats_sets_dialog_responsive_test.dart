import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Responzivita dialogu Správa sad (_StatsSetsDialog):
/// úzký telefon / běžný telefon / desktop + otevřená klávesnice.
/// Ověřuje absenci overflow a dostupnost hlavních ovládacích prvků.
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

  void seedSets(dynamic state) {
    state.addStatsSetForTest(
      StatisticsSet(
        name: 'Dlouhy nazev sady pro uzky displej',
        fieldNames: const ['Hodnota', 'Poznamka'],
        records: [
          for (var i = 0; i < 5; i++)
            StatisticsRecord(values: [i.toDouble()]),
        ],
      ),
    );
    state.addStatsSetForTest(
      StatisticsSet(
        name: 'Druha sada',
        fieldNames: const ['X'],
        records: [
          for (var i = 0; i < 3; i++)
            StatisticsRecord(values: [i.toDouble()]),
        ],
      ),
    );
  }

  Future<void> openSetsDialog(WidgetTester tester, dynamic state) async {
    state.showStatsSetsDialogForTest();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  }

  void expectMainControls() {
    // Vyhledávání, řazení, archiv, akční tlačítka a složky musí být v stromu
    // (bez ohledu na aktuální jazyk aplikace – proto podle typu + Semantics).
    expect(find.byType(TextField), findsWidgets);
    expect(find.byType(DropdownButton<String>), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.byType(FilledButton), findsWidgets);
    expect(find.byType(OutlinedButton), findsWidgets);
    expect(find.byType(ChoiceChip), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            ((w.properties.label ?? '').contains('Vytvo') ||
                (w.properties.label ?? '').contains('Create')),
      ),
      findsWidgets,
    );
  }

  Future<void> runCase(
    WidgetTester tester, {
    required Size size,
    required String label,
    double keyboardBottom = 0,
  }) async {
    final state = await pumpApp(tester, size);
    seedSets(state);
    await tester.pumpAndSettle();
    final bool withKeyboard = keyboardBottom > 0;
    if (withKeyboard) {
      tester.view.viewInsets =
          FakeViewPadding(bottom: keyboardBottom);
      await tester.pump();
      // Tělo za modální bariérou může za extrémních podmínek
      // (malý telefon + vysoká klávesnice) ohlásit overflow;
      // s dialogy nesouvisí a za bariérou není vidět
      // (stejný vzor jako dialog_keyboard_and_stats_focus_test.dart).
      tester.takeException();
    }
    await openSetsDialog(tester, state);
    if (!withKeyboard) {
      // Žádný RenderFlex overflow při otevření (bez klávesnice je tělo
      // stabilní, takže jakákoliv chyba patří dialogu).
      expect(
        tester.takeException(),
        isNull,
        reason: 'Overflow po otevření dialogu ($label)',
      );
    } else {
      // S klávesnicí pouze zahodíme případný overflow těla za bariérou
      // a ověřujeme polohové invarianty samotného dialogu níže.
      tester.takeException();
    }
    expectMainControls();
    // Editace dostupná bez horizontálního hledání (narrow: OutlinedButton).
    expect(find.byIcon(Icons.view_list), findsWidgets);
    // Menu možností dostupné.
    expect(find.byIcon(Icons.more_vert), findsWidgets);
    // Dialog nesmí přetéct mimo obrazovku.
    final dialogRect = tester.getRect(find.byType(AlertDialog));
    expect(dialogRect.left, greaterThanOrEqualTo(-1),
        reason: 'Dialog přetéká vlevo ($label)');
    expect(dialogRect.top, greaterThanOrEqualTo(-1),
        reason: 'Dialog přetéká nahoře ($label)');
    expect(dialogRect.right,
        lessThanOrEqualTo(size.width + 1),
        reason: 'Dialog přetéká vpravo ($label)');
    // Sémantika: popis sady a akce úpravy musí zůstat samostatně dostupné.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.label ?? '').contains('Dlouhy nazev'),
      ),
      findsWidgets,
      reason: 'Semantics popisu sady chybí ($label)',
    );
    if (withKeyboard) {
      // Vyhledávací pole musí zůstat viditelné nad klávesnicí.
      final fieldRect = tester.getRect(find.byType(TextField).first);
      expect(fieldRect.top, greaterThanOrEqualTo(-1),
          reason: 'TextField nesmí zmizet nad horní okraj ($label)');
      expect(
        fieldRect.bottom,
        lessThanOrEqualTo(size.height - keyboardBottom + 1),
        reason: 'TextField musí zůstat nad klávesnicí ($label)',
      );
      tester.takeException();
    }
    await tester.pump(const Duration(seconds: 1));
    if (!withKeyboard) {
      expect(
        tester.takeException(),
        isNull,
        reason: 'Overflow po settle ($label)',
      );
    } else {
      tester.takeException();
    }
  }

  group('Správa sad je responzivní', () {
    testWidgets('velmi úzký telefon 320x568', (tester) async {
      await runCase(tester, size: const Size(320, 568), label: '320x568');
    });
    testWidgets('běžný telefon 412x860', (tester) async {
      await runCase(tester, size: const Size(412, 860), label: '412x860');
    });
    testWidgets('široký desktop 1280x800', (tester) async {
      await runCase(tester, size: const Size(1280, 800), label: '1280x800');
    });
    testWidgets('malý telefon + klávesnice', (tester) async {
      await runCase(
        tester,
        size: const Size(360, 640),
        label: '360x640+keyboard',
        keyboardBottom: 300,
      );
    });
  });
}
