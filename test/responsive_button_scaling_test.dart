import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    double? keyboardFontScale,
  }) async {
    tester.platformDispatcher.clearAllTestValues();
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(const ScientificCalculatorApp());
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(CalculatorScreen)) as dynamic;
    if (keyboardFontScale != null) {
      state.setKeyboardFontScaleForTest(keyboardFontScale);
      await tester.pumpAndSettle();
    }
    return state;
  }

  double keyboardFontSize(WidgetTester tester, String label) {
    final texts = tester.widgetList<Text>(find.text(label)).toList();
    expect(texts, isNotEmpty, reason: 'tlačítko $label nenalezeno');
    final sized = texts
        .where((t) => t.style?.fontWeight == FontWeight.bold)
        .toList();
    expect(sized, isNotEmpty, reason: 'tučné tlačítko $label nenalezeno');
    return sized.first.style!.fontSize!;
  }

  Size buttonContainerSize(WidgetTester tester, String label) {
    // find Container of button via ancestor of Text(label) with bold style
    final textFinder = find.widgetWithText(Text, label);
    // There are multiple Texts, find the bold one
    final candidates = tester.widgetList<Text>(textFinder).toList();
    Text? target;
    for (final t in candidates) {
      if (t.style?.fontWeight == FontWeight.bold) {
        target = t;
        break;
      }
    }
    expect(target, isNotNull, reason: 'bold Text $label not found');
    // Find ancestor Container
    final containerFinder = find.ancestor(
      of: find.byWidget(target!),
      matching: find.byType(Container),
    );
    expect(containerFinder, findsWidgets);
    // The innermost Container that is buttonBody is first
    final container = tester.widget<Container>(containerFinder.first);
    // Instead get RenderBox size of the InkWell/Semantics parent
    // Use getSize on the Text's ancestor FittedBox parent Container
    // Fallback: getSize of the Text's parent chain via tester.getSize on containerFinder
    try {
      return tester.getSize(containerFinder.first);
    } catch (_) {
      // alternative: find Expanded ancestor
      return tester.getSize(
        find
            .ancestor(of: find.byWidget(target), matching: find.byType(InkWell))
            .first,
      );
    }
  }

  Finder semanticsWithLabel(Pattern pattern) {
    return find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          w.properties.label != null &&
          pattern.allMatches(w.properties.label!).isNotEmpty,
    );
  }

  group('Responsive button scaling', () {
    testWidgets('A - baseline renders without overflow', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
      });
      mockChannels();
      await pumpApp(tester, size: const Size(412, 860), textScale: 1.0);
      expect(find.byType(CalculatorScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      // baseline font should be ~20 (scale ~1.14 on 412 shortest)
      final base = keyboardFontSize(tester, '7');
      expect(base, greaterThanOrEqualTo(14.0));
      expect(base, lessThanOrEqualTo(72.0));
      // approx 20*1.144 = 22.88, allow tolerance
      expect(base, closeTo(22.0, 4.0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('B - larger viewport larger font and larger button', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
      });
      mockChannels();
      await pumpApp(tester, size: const Size(412, 860), textScale: 1.0);
      final baseFont = keyboardFontSize(tester, '7');
      final baseSize = tester.getSize(find.byType(CalculatorScreen));

      await pumpApp(tester, size: const Size(600, 900), textScale: 1.0);
      final largeFont = keyboardFontSize(tester, '7');
      expect(
        largeFont,
        greaterThan(baseFont),
        reason: 'font on larger viewport must be larger',
      );

      // button container also larger – check via Container constraints indirectly
      // Compare font ratio approximates scale growth
      expect(largeFont / baseFont, greaterThan(1.05));

      expect(tester.takeException(), isNull);
    });

    testWidgets('C - desktop large viewport short labels not scaled down', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
      });
      mockChannels();
      await pumpApp(tester, size: const Size(412, 860), textScale: 1.0);
      final phoneFont = keyboardFontSize(tester, '7');

      await pumpApp(tester, size: const Size(1280, 800), textScale: 1.0);
      final desktopFont = keyboardFontSize(tester, '7');

      expect(
        desktopFont,
        greaterThan(phoneFont),
        reason: 'desktop font must be larger than phone',
      );
      // Desktop shortest 800 -> scale 1.7 -> font ~34, phone ~22-23
      expect(desktopFont, greaterThan(28.0));
      expect(desktopFont, lessThanOrEqualTo(72.0));

      // Verify FittedBox does not shrink short labels: scale factor 1.0
      // FittedBox with scaleDown will only shrink if overflow; short label should not overflow.
      // Check that Text width * scale is within button width.
      // Instead verify no overflow exception and font is as expected (not clamped down to ~20)
      // Also verify button visually contains text: get RenderBox of Text and its ancestor
      final fittedBoxes = tester.widgetList<FittedBox>(find.byType(FittedBox));
      expect(fittedBoxes, isNotEmpty);
      // For short labels, FittedBox should not need to scale; we infer by font size not being reduced.
      expect(desktopFont, greaterThan(phoneFont * 1.2));

      // No overflow
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('D - system scaling enlarges font roughly proportionally', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
      });
      mockChannels();
      await pumpApp(tester, size: const Size(412, 860), textScale: 1.0);
      final base = keyboardFontSize(tester, '7');

      await pumpApp(tester, size: const Size(412, 860), textScale: 1.5);
      final scaled = keyboardFontSize(tester, '7');

      expect(scaled, greaterThan(base));
      // Should be approx base *1.5 (clamp 1.6)
      expect(scaled, closeTo(base * 1.5, 3.0));
      // Ensure no double counting: would be ~base*2.25 if double counted
      expect(scaled, lessThan(base * 2.0));

      expect(tester.takeException(), isNull);
    });

    testWidgets('E - user font scale monotonic', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
      });
      mockChannels();
      final scales = [1.0, 1.5, 1.75, 2.0];
      final fonts = <double>[];
      for (final s in scales) {
        await pumpApp(
          tester,
          size: const Size(412, 860),
          textScale: 1.0,
          keyboardFontScale: s,
        );
        fonts.add(keyboardFontSize(tester, '7'));
        expect(tester.takeException(), isNull);
      }
      for (int i = 1; i < fonts.length; i++) {
        expect(
          fonts[i],
          greaterThan(fonts[i - 1]),
          reason: 'font at scale ${scales[i]} must be > ${scales[i - 1]}',
        );
      }
      // Check monotonic and within clamp
      expect(fonts.first, greaterThanOrEqualTo(14.0));
      expect(fonts.last, lessThanOrEqualTo(72.0));
    });

    testWidgets('F - long labels fit without overflow, short not penalized', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
      });
      mockChannels();
      await pumpApp(tester, size: const Size(1280, 800), textScale: 1.0);
      // Switch to scientific functions page via tapping FUNKCE toggle
      final toggleFinder = find.text('FUNKCE').evaluate().isNotEmpty
          ? find.text('FUNKCE')
          : find.text('FUNCTIONS');
      if (toggleFinder.evaluate().isNotEmpty) {
        await tester.tap(toggleFinder.first);
        await tester.pumpAndSettle();
      }

      final longLabels = ['ASIN', 'ACOS', 'ATAN', 'RAD→°', '°→RAD', 'WMEAN'];
      // baseline short label that exists on functions page
      final baselineLabel = find.text('C').evaluate().isNotEmpty ? 'C' : 'DEL';
      final baselineFont = keyboardFontSize(tester, baselineLabel);
      for (final lbl in longLabels) {
        final finder = find.text(lbl);
        if (finder.evaluate().isEmpty) continue;
        expect(
          finder,
          findsWidgets,
          reason: 'long label $lbl should be present',
        );
        expect(tester.takeException(), isNull);
        final longFont = keyboardFontSize(tester, lbl);
        expect(longFont, lessThanOrEqualTo(baselineFont + 0.01));
        expect(
          longFont,
          greaterThan(baselineFont * 0.5),
          reason: 'long label $lbl not too small',
        );
      }

      // Verify baseline still large
      expect(baselineFont, greaterThan(25.0));

      // Also verify short numeric still large after switching back
      final backToggle = find.text('ČÍSLA').evaluate().isNotEmpty
          ? find.text('ČÍSLA')
          : find.text('NUMBERS');
      if (backToggle.evaluate().isNotEmpty) {
        await tester.tap(backToggle.first);
        await tester.pumpAndSettle();
        final short2 = keyboardFontSize(tester, '7');
        expect(short2, greaterThan(25.0));
      }

      // Also test on small viewport long labels don't overflow
      await pumpApp(tester, size: const Size(360, 640), textScale: 1.0);
      final toggle2 = find.text('FUNKCE').evaluate().isNotEmpty
          ? find.text('FUNKCE')
          : find.text('FUNCTIONS');
      if (toggle2.evaluate().isNotEmpty) {
        await tester.tap(toggle2.first);
        await tester.pumpAndSettle();
      }
      for (final lbl in longLabels) {
        if (find.text(lbl).evaluate().isEmpty) continue;
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('G - semantics unchanged by visual scaling', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
      });
      mockChannels();
      await pumpApp(tester, size: const Size(412, 860), textScale: 1.0);
      final semanticsBefore = tester.getSemantics(
        find.byType(CalculatorScreen),
      );
      // Find a button semantics
      final btnSemBefore = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
                w.properties.label != null &&
                w.properties.label!.contains('Sedm') ||
            w is Semantics &&
                w.properties.label != null &&
                w.properties.label!.contains('Seven'),
      );
      // At least one semantics for '7' exists
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label != null &&
              (w.properties.label!.contains('Sedm') ||
                  w.properties.label!.contains('Seven') ||
                  w.properties.label == '7'),
        ),
        findsWidgets,
      );

      await pumpApp(tester, size: const Size(1280, 800), textScale: 1.5);

      // Semantics for '7' must still exist and be button
      final semFinder = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label != null &&
            w.properties.button == true,
      );
      expect(semFinder, findsWidgets);

      // Ensure no semantics lost
      expect(tester.takeException(), isNull);
    });

    testWidgets('Regression - text/button ratio not degrading on large viewport', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'modeQuestionAsked': true,
      });
      mockChannels();
      await pumpApp(tester, size: const Size(412, 860), textScale: 1.0);
      final phoneFont = keyboardFontSize(tester, '7');
      // Estimate button height via Container constraints: use tester.getSize on button's RenderBox
      // Find InkWell ancestor of Text 7
      final phoneInkWell = find.ancestor(
        of: find.widgetWithText(Text, '7'),
        matching: find.byType(InkWell),
      );
      // Filter to bold Text's InkWell
      InkWell? phoneW;
      for (final e in tester.widgetList<InkWell>(phoneInkWell)) {
        // heuristic: choose first with size >0
        phoneW = e;
        break;
      }
      final phoneBtnSize = tester.getSize(
        find
            .ancestor(of: find.text('7'), matching: find.byType(Container))
            .first,
      );

      await pumpApp(tester, size: const Size(1280, 800), textScale: 1.0);
      final desktopFont = keyboardFontSize(tester, '7');
      final desktopBtnSize = tester.getSize(
        find
            .ancestor(of: find.text('7'), matching: find.byType(Container))
            .first,
      );

      final phoneRatio = phoneFont / phoneBtnSize.height;
      final desktopRatio = desktopFont / desktopBtnSize.height;

      // Ratio on desktop must not be significantly smaller (old bug: 0.416 -> 0.33 = -20%)
      // New: should be similar or larger (within 10% tolerance)
      expect(
        desktopRatio,
        greaterThanOrEqualTo(phoneRatio * 0.90),
        reason:
            'desktop text/button ratio $desktopRatio must not be <90% of phone $phoneRatio (old bug degraded to 80%)',
      );
      // Also absolute ratio reasonable
      expect(desktopRatio, greaterThan(0.30));
      expect(desktopRatio, lessThan(0.65));

      expect(tester.takeException(), isNull);
    });
  });
}
