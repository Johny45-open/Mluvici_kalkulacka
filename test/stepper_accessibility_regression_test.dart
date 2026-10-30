import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'Regresní testy přístupnosti stepperů (QuickSetup & Accessibility Editor)',
    () {
      testWidgets(
        'QuickSetupDialog steppery mají samostatné sémantické uzly bez MergeSemantics',
        (tester) async {
          tester.view.physicalSize = const Size(800, 2400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => QuickSetupDialog(
                      initialDraft: QuickSetupDraft.defaults(),
                      availableVoices: Future.value(
                        const <Map<String, String>>[],
                      ),
                      onApply: (_) {},
                      onCancel: () {},
                      announce: (_) {},
                      tr: (cs, _) => cs,
                      isFirstRun: true,
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          );

          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();

          // Rozbalit pokročilá nastavení při prvním spuštění
          await tester.tap(find.text('Pokročilá nastavení'));
          await tester.pumpAndSettle();

          // Ověření, že tlačítka pro snížení a zvýšení rychlosti/hlasitosti existují a mají samostatnou sémantiku
          expect(find.bySemanticsLabel('Snížit rychlost'), findsOneWidget);
          expect(find.bySemanticsLabel('Zvýšit rychlost'), findsOneWidget);
          expect(find.bySemanticsLabel('Snížit hlasitost'), findsOneWidget);
          expect(find.bySemanticsLabel('Zvýšit hlasitost'), findsOneWidget);
          expect(
            find.bySemanticsLabel('Zmenšit písmo tlačítek'),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel('Zvětšit písmo tlačítek'),
            findsOneWidget,
          );

          // Zkontrolujeme, že sémantické uzly pro minus tlačítko, hodnotu a plus tlačítko jsou oddělené (nejsou sloučené v jeden uzel)
          final semanticsMinus = tester.getSemantics(
            find.bySemanticsLabel('Snížit rychlost'),
          );
          final semanticsPlus = tester.getSemantics(
            find.bySemanticsLabel('Zvýšit rychlost'),
          );
          expect(semanticsMinus, isNotNull);
          expect(semanticsPlus, isNotNull);
          expect(semanticsMinus != semanticsPlus, isTrue);
        },
      );

      testWidgets(
        'AccessibilityProfileEditorDialog speech rate and volume steppers have correct semantics and functionality',
        (tester) async {
          SharedPreferences.setMockInitialValues(<String, Object>{
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
          messenger.setMockMethodCallHandler(
            const MethodChannel('com.example.mluvici_kalkulacka/tts_settings'),
            (MethodCall call) async => null,
          );

          tester.view.physicalSize = const Size(800, 2400);
          tester.view.devicePixelRatio = 1.0;
          tester.platformDispatcher.localeTestValue = const Locale('cs', 'CZ');
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearAllTestValues);

          await tester.pumpWidget(const ScientificCalculatorApp());
          await tester.pumpAndSettle();
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();

          final state = tester.state(find.byType(CalculatorScreen)) as dynamic;
          state.showAccessibilityDialogForTest();
          await tester.pumpAndSettle();

          final standardFinder = find.text('Standard');
          final standardCsFinder = find.text('Standardní');
          if (standardFinder.evaluate().isNotEmpty) {
            await tester.tap(standardFinder.first);
          } else if (standardCsFinder.evaluate().isNotEmpty) {
            await tester.tap(standardCsFinder.first);
          }
          await tester.pumpAndSettle();

          final editFinder = find.text('Upravit');
          final editEnFinder = find.text('Edit');
          if (editFinder.evaluate().isNotEmpty) {
            await tester.tap(editFinder.first);
          } else if (editEnFinder.evaluate().isNotEmpty) {
            await tester.tap(editEnFinder.first);
          }
          await tester.pumpAndSettle();

          // Verify steppers exist with correct semantics labels
          expect(find.bySemanticsLabel('Zvýšit rychlost řeči'), findsOneWidget);
          expect(find.bySemanticsLabel('Zmenšit rychlost řeči'), findsOneWidget);
          expect(find.bySemanticsLabel('Zvýšit hlasitost řeči'), findsOneWidget);
          expect(find.bySemanticsLabel('Snížit hlasitost řeči'), findsOneWidget);

          // Check semantics data for button role and tap action
          final incRateSemantics = tester.getSemantics(find.bySemanticsLabel('Zvýšit rychlost řeči'));
          expect(incRateSemantics.getSemanticsData().flagsCollection.isButton, isTrue);
          expect(incRateSemantics.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

          final initialRate = state.editingDraftForTest.settings.speechRate;

          // Tap increase speech rate
          await tester.tap(find.bySemanticsLabel('Zvýšit rychlost řeči'));
          await tester.pumpAndSettle();

          final newRate = state.editingDraftForTest.settings.speechRate;
          expect(newRate > initialRate, isTrue);

          // Tap decrease speech rate
          await tester.tap(find.bySemanticsLabel('Zmenšit rychlost řeči'));
          await tester.pumpAndSettle();

          expect(state.editingDraftForTest.settings.speechRate, closeTo(initialRate, 0.001));

          // Test volume
          final initialVolume = state.editingDraftForTest.settings.speechVolume;
          await tester.tap(find.bySemanticsLabel('Snížit hlasitost řeči'));
          await tester.pumpAndSettle();

          expect(state.editingDraftForTest.settings.speechVolume < initialVolume, isTrue);

          await tester.tap(find.bySemanticsLabel('Zvýšit hlasitost řeči'));
          await tester.pumpAndSettle();

          expect(state.editingDraftForTest.settings.speechVolume, closeTo(initialVolume, 0.001));

          // Close editor
          state.discardEditingForTest();
          await tester.pumpAndSettle();
        },
      );
    },
  );
}
