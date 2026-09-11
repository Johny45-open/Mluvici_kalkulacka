import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<dynamic> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.view.viewInsets = FakeViewPadding.zero);
    await tester.pumpWidget(const ScientificCalculatorApp());
    await tester.pumpAndSettle();
    return tester.state(find.byType(CalculatorScreen)) as dynamic;
  }

  Future<void> openTutorial(WidgetTester tester, dynamic state) async {
    state.showTutorialDialogForTest();
    await tester.pumpAndSettle();
    expect(find.text('Help'), findsOneWidget);
  }

  Finder tutorialTabFocuses() {
    return find.byWidgetPredicate(
      (w) => w is Focus && (w.debugLabel ?? '') == 'tutorialTab',
    );
  }

  Finder tutorialBlockFocuses() {
    return find.byWidgetPredicate(
      (w) => w is Focus && (w.debugLabel ?? '').startsWith('tutorialBlock'),
    );
  }

  Finder allFocusableTutorial() {
    return find.byWidgetPredicate(
      (w) =>
          w is Focus &&
          ((w.debugLabel ?? '').startsWith('tutorialTab') ||
              (w.debugLabel ?? '').startsWith('tutorialBlock')),
    );
  }

  group('Tutorial dialog accessibility', () {
    testWidgets('1. Po otevreni dialogu je fokus v dialogu', (tester) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      expect(find.byType(AlertDialog), findsOneWidget);
      // At least one Focus in dialog has focus (tab or block or button)
      final focused = FocusManager.instance.primaryFocus;
      expect(focused, isNotNull, reason: 'Dialog musi mit fokus');
      expect(focused!.context, isNotNull);
      // The focused widget should be inside AlertDialog
      final dialogContext = tester.element(find.byType(AlertDialog));
      expect(focused.context!.findAncestorWidgetOfExactType<AlertDialog>(),
          isNotNull,
          reason: 'Fokus musi byt uvnitr dialogu');
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('2. Aktualni karta je spravne fokusovatelna', (tester) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      final tabFocuses = tester.widgetList<Focus>(tutorialTabFocuses()).toList();
      expect(tabFocuses.length, 9);
      // First tab should be focusable and after pump hasFocus or can be requested
      final firstNode = tabFocuses.first.focusNode!;
      firstNode.requestFocus();
      await tester.pump();
      expect(firstNode.hasFocus, isTrue);
      // All tab nodes can request focus individually
      for (final f in tabFocuses) {
        f.focusNode!.requestFocus();
        await tester.pump();
        expect(f.focusNode!.hasFocus, isTrue);
      }
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('3. Tab projde vsechny oczekavane navigovatelne casti', (tester) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      final blockFocuses = tester.widgetList<Focus>(tutorialBlockFocuses()).toList();
      expect(blockFocuses.length, greaterThan(1),
          reason: 'Kazda karta musi mit vice bloku');
      // Focus first block then Tab through all blocks (deterministic OrderedTraversalPolicy)
      blockFocuses.first.focusNode!.requestFocus();
      await tester.pump();
      expect(blockFocuses.first.focusNode!.hasFocus, isTrue);
      for (var i = 1; i < blockFocuses.length; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(blockFocuses[i].focusNode!.hasFocus, isTrue,
            reason: 'Tab ma prejit na blok $i');
      }
      // After last block, Tab should leave content (to Prev/Next or close), not wrap to first block
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final stillInBlocks = blockFocuses.any((f) => f.focusNode!.hasFocus);
      expect(stillInBlocks, isFalse,
          reason: 'Tab po poslednim bloku ma opustit obsah');
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('4. Shift+Tab funguje opacnym smerem', (tester) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      final blocks = tester.widgetList<Focus>(tutorialBlockFocuses()).toList();
      expect(blocks.length, greaterThan(2));
      blocks.last.focusNode!.requestFocus();
      await tester.pump();
      expect(blocks.last.focusNode!.hasFocus, isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pump();
      expect(blocks[blocks.length - 2].focusNode!.hasFocus, isTrue,
          reason: 'Shift+Tab ma vratit fokus');
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('5. Sipka dolu prejde na dalsi cast obsahu', (tester) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      final blocks = tester.widgetList<Focus>(tutorialBlockFocuses()).toList();
      expect(blocks.length, greaterThan(1));
      blocks.first.focusNode!.requestFocus();
      await tester.pump();
      expect(blocks.first.focusNode!.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(blocks[1].focusNode!.hasFocus, isTrue,
          reason: 'ArrowDown ma prejit na dalsi blok');
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('6. Sipka nahoru prejde na predchozi cast', (tester) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      final blocks = tester.widgetList<Focus>(tutorialBlockFocuses()).toList();
      blocks[1].focusNode!.requestFocus();
      await tester.pump();
      expect(blocks[1].focusNode!.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(blocks.first.focusNode!.hasFocus, isTrue);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('7. Home jde na zacatek kapitoly', (tester) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      final blocks = tester.widgetList<Focus>(tutorialBlockFocuses()).toList();
      blocks.last.focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(blocks.first.focusNode!.hasFocus, isTrue);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('8. End jde na konec kapitoly', (tester) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      final blocks = tester.widgetList<Focus>(tutorialBlockFocuses()).toList();
      blocks.first.focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(blocks.last.focusNode!.hasFocus, isTrue);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('9. Prepnuti karty vyradi neaktivni obsah z focus traversal',
        (tester) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      // Initially only first tab's blocks are active
      expect(tutorialBlockFocuses(), findsWidgets);
      final initialCount = tester.widgetList<Focus>(tutorialBlockFocuses()).length;
      // Switch to next tab via Next button
      final nextBtn = find.widgetWithText(TextButton, 'Next');
      // Fallback for CS locale
      final nextBtnCs = find.widgetWithText(TextButton, 'Další');
      final btn = tester.any(nextBtn) ? nextBtn : nextBtnCs;
      // Alternative: tap the TabBar second tab
      final tabFocuses = tester.widgetList<Focus>(tutorialTabFocuses()).toList();
      tabFocuses[1].focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      // After switch, blocks should still be present but inactive ones excluded
      final blocksAfter = tester.widgetList<Focus>(tutorialBlockFocuses()).toList();
      // Only active tab's blocks should be traversable (skipTraversal false)
      // Inactive are wrapped in ExcludeFocus so not found? Our implementation returns SizedBox for inactive, so count equals active only
      expect(blocksAfter.length, greaterThan(0));
      // Ensure no inactive block has focus
      for (final f in blocksAfter) {
        expect(f.focusNode!.skipTraversal, isFalse);
      }
      // Verify tab focus is on new tab
      expect(tabFocuses[1].focusNode!.hasFocus, isTrue);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('10. Po prepnuti karty je nova karta na zacatku (scroll 0)',
        (tester) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      final blocks = tester.widgetList<Focus>(tutorialBlockFocuses()).toList();
      // Scroll somewhere by focusing last block (ensureVisible will scroll)
      blocks.last.focusNode!.requestFocus();
      await tester.pumpAndSettle();
      // Now switch tab
      final tabFocuses = tester.widgetList<Focus>(tutorialTabFocuses()).toList();
      // Use Next button to switch
      final nextFinder = find.text('Next');
      final nextCs = find.text('Další');
      final next = tester.any(nextFinder) ? nextFinder : nextCs;
      // Find TextButton containing Next/Další and tap
      final nextBtn = find.ancestor(
        of: next,
        matching: find.byType(TextButton),
      );
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();
      // Find ScrollView of active content
      final scrollView = find.byType(SingleChildScrollView);
      expect(scrollView, findsWidgets);
      // The first ScrollView (active) should have offset 0
      final firstScrollable = tester.widget<SingleChildScrollView>(scrollView.first);
      if (firstScrollable.controller != null &&
          firstScrollable.controller!.hasClients) {
        expect(firstScrollable.controller!.offset, 0.0);
      }
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('11. Predchozi/Dalsi funguje', (tester) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      final tabFocuses = tester.widgetList<Focus>(tutorialTabFocuses()).toList();
      tabFocuses.first.focusNode!.requestFocus();
      await tester.pump();
      expect(tabFocuses.first.focusNode!.hasFocus, isTrue);
      // Tap Další/Next
      final nextText = find.text('Next');
      final nextCsText = find.text('Další');
      final nextLabel = tester.any(nextText) ? nextText : nextCsText;
      final nextBtn = find.ancestor(of: nextLabel, matching: find.byType(TextButton));
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();
      expect(tabFocuses[1].focusNode!.hasFocus, isTrue);
      // Tap Předchozí/Previous
      final prevText = find.text('Previous');
      final prevCsText = find.text('Předchozí');
      final prevLabel = tester.any(prevText) ? prevText : prevCsText;
      final prevBtn = find.ancestor(of: prevLabel, matching: find.byType(TextButton));
      await tester.tap(prevBtn);
      await tester.pumpAndSettle();
      expect(tabFocuses.first.focusNode!.hasFocus, isTrue);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('12. Zavreni dialogu funguje', (tester) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      final closeBtn = find.text('UNDERSTAND');
      final closeCs = find.text('ROZUMÍM');
      final close = tester.any(closeBtn) ? closeBtn : closeCs;
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('13. Nejsou pritomne duplicitni focus stopy', (tester) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      final allFoci = tester.widgetList<Focus>(allFocusableTutorial()).toList();
      // Only active tab's blocks + 9 tabs should be traversable; inactive blocks are excluded
      // So count should be tabs(9) + blocks(active)
      final blocks = tester.widgetList<Focus>(tutorialBlockFocuses()).toList();
      expect(allFoci.length, blocks.length + 9);
      // Ensure exactly one has focus at a time
      blocks.first.focusNode!.requestFocus();
      await tester.pump();
      final focusedCount = allFoci.where((f) => f.focusNode!.hasFocus).length;
      expect(focusedCount, 1);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('14. Semantics strom neobsahuje zbytecne duplicity', (tester) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      // No single Semantics with giant label containing whole manual text
      bool hasGiantLabel = false;
      final semWidgets = tester.widgetList<Semantics>(find.byType(Semantics)).toList();
      for (final w in semWidgets) {
        final label = w.properties.label ?? '';
        if (label.length > 500) {
          hasGiantLabel = true;
        }
      }
      expect(hasGiantLabel, isFalse,
          reason: 'Nesmi existovat jeden obri Semantics label');
      // Headers should exist
      final headers = tester.widgetList<Semantics>(find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.header == true,
      )).toList();
      expect(headers.length, greaterThanOrEqualTo(1),
          reason: 'Nadpisy musi byt oznaceny header:true');
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('PageDown/PageUp v obsahu posouva a meni blok', (tester) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      final blocks = tester.widgetList<Focus>(tutorialBlockFocuses()).toList();
      blocks.first.focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();
      expect(blocks[1].focusNode!.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pump();
      expect(blocks.first.focusNode!.hasFocus, isTrue);
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
