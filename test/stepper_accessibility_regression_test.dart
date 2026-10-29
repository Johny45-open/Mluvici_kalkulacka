import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';

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
    },
  );
}
