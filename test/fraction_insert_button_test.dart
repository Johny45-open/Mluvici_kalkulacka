import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Regrese NVDA na Windows: tlačítko „Vložit zlomek“ musí nést Semantics
// akci tap (mapuje se na UIA Invoke pattern). Bez ní odečítač tlačítko
// najde v objektové navigaci, ale nemůže jej aktivovat Enterem — a
// excludeSemantics: true navíc shazovalo příznak focusable, takže NVDA
// Tab tlačítko přeskakovalo. Viz _buildFractionInsertButton.
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

  Future<dynamic> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'modeQuestionAsked': true,
    });
    mockChannels();
    tester.platformDispatcher.clearAllTestValues();
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(const ScientificCalculatorApp());
    await tester.pumpAndSettle();
    return tester.state(find.byType(CalculatorScreen)) as dynamic;
  }

  Finder insertButton() => find.byKey(const ValueKey('fraction_insert'));

  group('Vložit zlomek – semantika aktivace (regrese NVDA)', () {
    testWidgets('1. Uzel tlačítka má button + tap akci (UIA Invoke)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpApp(tester);

        expect(insertButton(), findsOneWidget);
        final data = tester.getSemantics(insertButton()).getSemanticsData();

        expect(
          data.flagsCollection.isButton,
          isTrue,
          reason: 'Tlačítko musí být pro odečítač označeno jako button',
        );
        expect(
          data.hasAction(SemanticsAction.tap),
          isTrue,
          reason:
              'Bez SemanticsAction.tap nemá NVDA na Windows co aktivovat '
              'Enterem (chybí UIA Invoke pattern)',
        );
        expect(
          data.label,
          anyOf(contains('Vložit zlomek'), contains('Insert fraction')),
          reason: 'Label se po sloučení nesmí ztratit ani zdvojit',
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('2. Akce tap otevře dialog Čitatel/Jmenovatel', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpApp(tester);

        // Cesta, kterou používá odečítač: semantická akce, ne fyzický tap.
        final node = tester.semantics.find(insertButton());
        node.owner!.performAction(node.id, SemanticsAction.tap);
        await tester.pumpAndSettle();

        expect(
          find.byType(TextField),
          findsNWidgets(2),
          reason: 'Dialog Čitatel/Jmenovatel má dvě textová pole',
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('3. Bez excludeSemantics se label nezdvojí', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpApp(tester);

        final data = tester.getSemantics(insertButton()).getSemanticsData();
        // Ověření proti regresi na dvojí oznámení: vnější Semantics label a
        // vnitřní Text jsou shodné, výsledný label musí být právě jeden.
        expect(data.label, isNot(contains(', ')));
      } finally {
        handle.dispose();
      }
    });
  });
}
