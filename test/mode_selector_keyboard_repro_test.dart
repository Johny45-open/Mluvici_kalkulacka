import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regrese klávesnicové navigace přepínače režimů: po přepnutí režimu
/// přes chip (Enter) fokus nezmizí, zůstane na čipu a Tab jde dál
/// na další prvek – žádné uvíznutí ani ztráta fokusu.
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

  Future<dynamic> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.localeTestValue = const Locale('cs');
    tester.platformDispatcher.textScaleFactorTestValue = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(
      const ScientificCalculatorApp(locale: Locale('cs')),
    );
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(CalculatorScreen)) as dynamic;
    (state.mainFocusNodeForTest as FocusNode).requestFocus();
    await tester.pumpAndSettle();
    return state;
  }

  /// Focus uvnitř prvního chipu přepínače režimů.
  FocusNode firstChipNode(WidgetTester tester) {
    final chip = find.byType(ChoiceChip).first;
    final text = find.descendant(of: chip, matching: find.byType(Text)).first;
    return Focus.of(tester.element(text));
  }

  testWidgets('Enter na chipu přepne režim a fokus na čipu zůstává', (
    tester,
  ) async {
    final state = await pumpApp(tester);
    final chipNode = firstChipNode(tester);

    // Fokus jde získat i na chip (je součástí tab pořadí).
    chipNode.requestFocus();
    await tester.pumpAndSettle();
    expect(chipNode.hasPrimaryFocus, isTrue,
        reason: 'Chip musí jít zaměřit klávesnicí');

    // Aktivace Enterem: první chip je „Základní", výchozí režim scientific.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(state.currentModeForTest, CalculatorMode.basic,
        reason: 'Enter musí přepnout režim');

    // Fokus po přepnutí zůstává na čipu – čtečka nepřijde o kontext
    // a další Tab navazuje tam, kde uživatel je.
    expect(identical(FocusManager.instance.primaryFocus, chipNode), isTrue,
        reason: 'Po přepnutí režimu nesmí fokus z čipu zmizet');

    expect(tester.takeException(), isNull);
  });

  testWidgets('Tab po přepnutí režimu jde dál a neuvízne v cyklu', (
    tester,
  ) async {
    final state = await pumpApp(tester);
    final chipNode = firstChipNode(tester);

    chipNode.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(state.currentModeForTest, CalculatorMode.basic);

    // První Tab musí odejít z chipu na jiný prvek (ne na null).
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final after = FocusManager.instance.primaryFocus;
    expect(after, isNotNull, reason: 'Po Tab nesmí být fokus null');
    expect(identical(after, chipNode), isFalse,
        reason: 'Tab musí z chipu odejít');

    // Další Taby nesmí uvíznout v krátkém cyklu.
    final visited = <int>{};
    for (var i = 0; i < 15; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final pf = FocusManager.instance.primaryFocus;
      expect(pf, isNotNull, reason: 'Tab $i: fokus nesmí být null');
      visited.add(identityHashCode(pf));
    }
    expect(visited.length, greaterThan(2),
        reason: 'Tab traversal musí projít více uzlů');

    expect(tester.takeException(), isNull);
  });
}
