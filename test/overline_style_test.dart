import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Testy vzhledu periodické čáry (výška + tloušťka):
/// 1) výchozí hodnoty existují,
/// 2) změna výšky se projeví,
/// 3) změna tloušťky se projeví,
/// 4) hodnoty se uloží,
/// 5) hodnoty se po restartu načtou,
/// 6) reset vrátí výchozí hodnoty,
/// 7) náhled používá stejné hodnoty jako skutečné vykreslení,
/// 8) krajní hodnoty nerozbijí aplikaci.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const heightUpCs = 'Zvýšit výšku periodické čáry';
  const heightUpEn = 'Increase repeating bar height';
  const heightDownCs = 'Snížit výšku periodické čáry';
  const heightDownEn = 'Decrease repeating bar height';
  const thicknessUpCs = 'Zvětšit tloušťku periodické čárky';
  const thicknessUpEn = 'Increase repeating bar thickness';
  const resetCs = 'Obnovit výchozí vzhled periodické čáry';
  const resetEn = 'Reset repeating bar appearance';

  void mockChannels() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (MethodCall call) async => null,
    );

    messenger.setMockMethodCallHandler(
      const MethodChannel('com.example.mluvici_kalkulacka/accessibility'),
      (MethodCall call) async {
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
  }

  Future<dynamic> pumpApp(WidgetTester tester) async {
    tester.platformDispatcher.clearAllTestValues();
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(const ScientificCalculatorApp());
    await tester.pumpAndSettle();
    return tester.state(find.byType(CalculatorScreen)) as dynamic;
  }

  Finder bySemanticsLabel(List<String> labels) {
    return find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label != null &&
          labels.contains(widget.properties.label),
    );
  }

  Future<void> openSettings(WidgetTester tester, dynamic state) async {
    state.showAccessibilityDialogForTest();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsWidgets);
  }

  Future<void> tapControl(WidgetTester tester, List<String> labels) async {
    final target = bySemanticsLabel(labels);
    expect(target, findsWidgets);
    await tester.ensureVisible(target.first);
    await tester.pumpAndSettle();
    await tester.tap(target.first);
    await tester.pumpAndSettle();
  }

  CustomSegmentDisplay previewSegment(WidgetTester tester) {
    // Náhled v dialogu je první CustomSegmentDisplay v AlertDialogu.
    final dialog = find.byType(AlertDialog).first;
    final finder = find.descendant(
      of: dialog,
      matching: find.byType(CustomSegmentDisplay),
    );
    expect(finder, findsWidgets);
    return tester.widget<CustomSegmentDisplay>(finder.first);
  }

  CustomDotMatrixDisplay previewDotMatrix(WidgetTester tester) {
    final dialog = find.byType(AlertDialog).first;
    final finder = find.descendant(
      of: dialog,
      matching: find.byType(CustomDotMatrixDisplay),
    );
    expect(finder, findsWidgets);
    return tester.widget<CustomDotMatrixDisplay>(finder.first);
  }

  group('Overline style settings', () {
    testWidgets('1) výchozí hodnoty existují', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
      });
      mockChannels();
      final state = await pumpApp(tester);

      expect(state.overlineThicknessForTest, 1.0);
      expect(state.overlineHeightForTest, 1.0);
    });

    testWidgets(
      '2+3+4+7) změna výšky i tloušťky se projeví, uloží a náhled sedí',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'modeQuestionAsked': true,
        });
        mockChannels();
        final state = await pumpApp(tester);
        await openSettings(tester, state);

        await tapControl(tester, [heightUpEn, heightUpCs]);
        expect(state.overlineHeightForTest, closeTo(1.1, 1e-9));
        expect(
          previewSegment(tester).overlineHeight,
          closeTo(state.overlineHeightForTest as double, 1e-9),
        );
        expect(
          previewDotMatrix(tester).overlineHeight,
          closeTo(state.overlineHeightForTest as double, 1e-9),
        );

        await tapControl(tester, [thicknessUpEn, thicknessUpCs]);
        expect(state.overlineThicknessForTest, closeTo(1.2, 1e-9));
        expect(
          previewSegment(tester).overlineThickness,
          closeTo(state.overlineThicknessForTest as double, 1e-9),
        );
        expect(
          previewDotMatrix(tester).overlineThickness,
          closeTo(state.overlineThicknessForTest as double, 1e-9),
        );

        // 4) trvalé uložení
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getDouble('overlineHeight'), closeTo(1.1, 1e-9));
        expect(prefs.getDouble('overlineThickness'), closeTo(1.2, 1e-9));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('5) hodnoty se po restartu načtou', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
        'overlineHeight': 1.7,
        'overlineThickness': 2.4,
      });
      mockChannels();
      final state = await pumpApp(tester);

      expect(state.overlineHeightForTest, closeTo(1.7, 1e-9));
      expect(state.overlineThicknessForTest, closeTo(2.4, 1e-9));

      // Náhled po restartu používá načtené hodnoty.
      await openSettings(tester, state);
      expect(previewSegment(tester).overlineHeight, closeTo(1.7, 1e-9));
      expect(previewSegment(tester).overlineThickness, closeTo(2.4, 1e-9));
      expect(tester.takeException(), isNull);
    });

    testWidgets('6) reset vrátí výchozí hodnoty', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
        'overlineHeight': 1.7,
        'overlineThickness': 2.4,
      });
      mockChannels();
      final state = await pumpApp(tester);
      await openSettings(tester, state);

      final reset = find.text(resetEn, skipOffstage: false);
      final resetCsFinder = find.text(resetCs, skipOffstage: false);
      final resetTarget = reset.evaluate().isNotEmpty ? reset : resetCsFinder;
      expect(resetTarget, findsWidgets);
      await tester.ensureVisible(resetTarget.first);
      await tester.pumpAndSettle();
      await tester.tap(resetTarget.first);
      await tester.pumpAndSettle();

      expect(state.overlineHeightForTest, 1.0);
      expect(state.overlineThicknessForTest, 1.0);
      expect(previewSegment(tester).overlineHeight, 1.0);
      expect(previewSegment(tester).overlineThickness, 1.0);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('overlineHeight'), 1.0);
      expect(prefs.getDouble('overlineThickness'), 1.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('8) krajní hodnoty aplikaci nerozbijí', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
      });
      mockChannels();
      final state = await pumpApp(tester);
      await openSettings(tester, state);

      // Snížit výšku až na minimum 0.5 (krok 0.1 → 5× stačí, přidáme rezervu).
      for (var i = 0; i < 10; i++) {
        await tapControl(tester, [heightDownEn, heightDownCs]);
      }
      expect(state.overlineHeightForTest, 0.5);

      // Zvýšit výšku až na maximum 2.0.
      for (var i = 0; i < 20; i++) {
        await tapControl(tester, [heightUpEn, heightUpCs]);
      }
      expect(state.overlineHeightForTest, 2.0);

      // Zvýšit tloušťku až na maximum 4.0.
      for (var i = 0; i < 20; i++) {
        await tapControl(tester, [thicknessUpEn, thicknessUpCs]);
      }
      expect(state.overlineThicknessForTest, closeTo(4.0, 1e-9));

      expect(previewSegment(tester).overlineHeight, 2.0);
      expect(tester.takeException(), isNull);
    });
  });

  group('Overline rendering extremes', () {
    Future<void> pumpDisplays(
      WidgetTester tester, {
      required String value,
      required double thickness,
      required double height,
    }) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  CustomSegmentDisplay(
                    value: value,
                    size: 12,
                    characterCount: 8,
                    overlineThickness: thickness,
                    overlineHeight: height,
                  ),
                  CustomSegmentDisplay(
                    value: value,
                    size: 12,
                    characterCount: 8,
                    isSixteenSegment: true,
                    overlineThickness: thickness,
                    overlineHeight: height,
                  ),
                  CustomDotMatrixDisplay(
                    text: value,
                    ledSize: 2.5,
                    ledSpacing: 0.6,
                    overlineThickness: thickness,
                    overlineHeight: height,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    testWidgets('jedna číslice periody, min/max', (tester) async {
      await pumpDisplays(
        tester,
        value: '0.3\u0305',
        thickness: 0.8,
        height: 0.5,
      );
      await pumpDisplays(
        tester,
        value: '0.3\u0305',
        thickness: 4.0,
        height: 2.0,
      );
    });

    testWidgets('více číslic periody, min/max', (tester) async {
      await pumpDisplays(
        tester,
        value: '1.2345\u0305\u0305',
        thickness: 0.8,
        height: 0.5,
      );
      await pumpDisplays(
        tester,
        value: '1.2345\u0305\u0305',
        thickness: 4.0,
        height: 2.0,
      );
    });

    testWidgets('číslo bez periodické části', (tester) async {
      await pumpDisplays(tester, value: '123.45', thickness: 4.0, height: 2.0);
    });
  });
}
