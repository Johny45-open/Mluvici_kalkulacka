import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regresní testy počátečního fokusu NVDA (kroky A + B).
///
/// A) Kořenový `Focus` má `includeSemantics: false` → po spuštění neexistuje
///    žádný bezjmenný fokusovatelný uzel („seskupení", které NVDA ohlašovalo
///    jako úvodní fokus). Bezjmenný prázdný `focusable` uzel zachycuje test 3.
///
/// B) Počáteční fokus `_mainFocusNode` + režim ovládání výrazu (Z1) se
///    nastaví v `initState` (`_initPrimaryFocus`), NEZÁVISLE na dokončení
///    `PackageInfo.fromPlatform()`. Test 1 = opožděná odpověď (5 s), test 2 =
///    chyba kanálu. Test 4 = živý kontrakt, že od startu funguje šipka bez
///    explicitního `requestFocus` v testu (fokus i Z1 musí zajistit app).
///
/// Widget testy dokazují jen Flutter semantiku a FocusManager — chování NVDA
/// na Windows musí potvrdit ruční test.
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
    ) async => 1);
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

  /// Postaví app BEZ explicitního `requestFocus` v testu — počáteční fokus
  /// musí zajistit app sama (initState → _initPrimaryFocus).
  Future<dynamic> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.localeTestValue = const Locale('cs');
    tester.platformDispatcher.textScaleFactorTestValue = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(const ScientificCalculatorApp(locale: Locale('cs')));
    await tester.pumpAndSettle();
    return tester.state(find.byType(CalculatorScreen)) as dynamic;
  }

  /// Všechny uzly stromu v DFS pořadí.
  List<SemanticsNode> allNodes(WidgetTester tester) {
    final owner = tester.binding.pipelineOwner.semanticsOwner;
    expect(owner, isNotNull, reason: 'Vyžaduje ensureSemantics()');
    final out = <SemanticsNode>[];
    void visit(SemanticsNode node) {
      out.add(node);
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(owner!.rootSemanticsNode!);
    return out;
  }

  group('B: počáteční fokus nezávisí na načtení verze', () {
    testWidgets('PackageInfo odpovídá až po 5 s — fokus a Z1 jsou hned', (
      tester,
    ) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/package_info'),
        (MethodCall call) async {
          // Odpověď až po 5 s — dříve visela inicializace fokusu zde.
          await Future<void>.delayed(const Duration(seconds: 5));
          return <String, Object>{
            'appName': 'mluvici_kalkulacka',
            'packageName': 'com.example.mluvici_kalkulacka',
            'version': '6.2.0',
            'buildNumber': '1',
          };
        },
      );

      final state = await pumpApp(tester);
      // Jedno pumpnutí navíc: fokus je aplikován při prvním attachi uzlu
      // (deferred requestFocus SDK), verze stále nedorazila.
      await tester.pump();

      expect(state.mainFocusNodeForTest.hasPrimaryFocus, isTrue);
      expect(state.expressionControlActiveForTest, isTrue);

      // Uvolní opožděný package_info i quickSetupTimer, aby test nekončil
      // s pending timery.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('PackageInfo hází PlatformException — app běží dál, fokus je', (
      tester,
    ) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/package_info'),
        (MethodCall call) async {
          throw PlatformException(code: 'unavailable');
        },
      );

      final state = await pumpApp(tester);
      await tester.pump();

      // Chyba verze nesmí uniknout ani bránit používání kalkulačky.
      expect(tester.takeException(), isNull);
      expect(state.mainFocusNodeForTest.hasPrimaryFocus, isTrue);
      expect(state.expressionControlActiveForTest, isTrue);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    });
  });

  group('A: žádný bezjmenný fokusovatelný uzel po startu', () {
    testWidgets('žádný fokusovatelný uzel bez jména; Displej zůstává', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        final state = await pumpApp(tester);
        state.setDisplayForTest('12+3', 2);
        await tester.pumpAndSettle();

        // Bezjmenný = nemá žádné jméno: ani label, hodnotu, ani tooltip
        // (tlačítka App baru nesou jméno v tooltip → ta jsou pojmenovaná).
        String nameOf(SemanticsData d) => '${d.label} ${d.value} ${d.tooltip}';
        final unnamed = allNodes(tester)
            .where(
              (n) =>
                  n.getSemanticsData().hasFlag(SemanticsFlag.isFocusable) &&
                  nameOf(n.getSemanticsData()).trim().isEmpty,
            )
            .toList();
        expect(
          unnamed,
          isEmpty,
          reason:
              'Kořenový Focus s includeSemantics: true vytváří bezjmenný '
              'fokusovatelný uzel (NVDA jej ohlašoval jako „seskupení").',
        );

        // Displej zůstává jediný a je fokusovatelný (cíl navigace NVDA).
        final displej = allNodes(
          tester,
        ).where((n) => n.getSemanticsData().label == 'Displej').toList();
        expect(displej, hasLength(1));
        expect(
          displej.single.getSemanticsData().hasFlag(SemanticsFlag.isFocusable),
          isTrue,
        );
      } finally {
        handle.dispose();
      }
    });
  });

  group('B: Z1 a kurzor fungují od startu bez requestFocus v testu', () {
    testWidgets('první šipka po startu přesune kurzor (fokus + Z1 z app)', (
      tester,
    ) async {
      final state = await pumpApp(tester);

      // Bez requestFocus v testu: fokus i režim musí zajistit initState.
      expect(state.mainFocusNodeForTest.hasPrimaryFocus, isTrue);
      expect(state.expressionControlActiveForTest, isTrue);

      state.setDisplayForTest('12+3', 2);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(state.cursorForTest, 3);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    });
  });
}
