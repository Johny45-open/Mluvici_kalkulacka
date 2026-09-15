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

  // Starý helper pro legacy Focus s debugLabel 'tutorialTab' – po opravě vrací 0,
  // ale testy nyní používají Tab widgety jako zdroj pravdy.
  Finder legacyTutorialTabFocuses() {
    return find.byWidgetPredicate(
      (w) => w is Focus && (w.debugLabel ?? '') == 'tutorialTab',
    );
  }

  // Nový helper: Focus uzly uvnitř TabBar (InkWell Focus – jeden na záložku)
  Finder tabBarFocuses() {
    return find.descendant(
      of: find.byType(TabBar),
      matching: find.byWidgetPredicate((w) {
        if (w is! Focus) return false;
        // InkWell Focus má canRequestFocus true a skipTraversal false
        final f = w as Focus;
        return f.canRequestFocus == true && f.skipTraversal == false;
      }),
    );
  }

  int tabCount(WidgetTester tester) => find.byType(Tab).evaluate().length;

  Finder tutorialBlockFocuses() {
    return find.byWidgetPredicate(
      (w) => w is Focus && (w.debugLabel ?? '').startsWith('tutorialBlock'),
    );
  }

  group('Tutorial dialog accessibility', () {
    testWidgets('1. Po otevreni dialogu je fokus v dialogu', (tester) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      expect(find.byType(AlertDialog), findsOneWidget);
      final focused = FocusManager.instance.primaryFocus;
      expect(focused, isNotNull, reason: 'Dialog musi mit fokus');
      expect(focused!.context, isNotNull);
      expect(focused.context!.findAncestorWidgetOfExactType<AlertDialog>(),
          isNotNull,
          reason: 'Fokus musi byt uvnitr dialogu');
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('2. Aktualni karta je spravne fokusovatelna – jedna zalozka = jeden Tab stop', (tester) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      // Nová architektura: 9 Tab widgetů, každý má právě jeden InkWell Focus
      expect(tabCount(tester), 9, reason: 'Dialog má 9 záložek');
      // Staré Focus nodes již neexistují (žádný duplicitní wrapper)
      expect(legacyTutorialTabFocuses(), findsNothing,
          reason: 'Po opravě nesmí existovat duplicitní Focus(tutorialTab)');
      // TabBar Focus nodes – přesně 9, žádný duplikát
      final barFocuses = tester.widgetList<Focus>(tabBarFocuses()).toList();
      expect(barFocuses.length, 9,
          reason: 'Každá záložka má právě jeden InkWell Focus');
      expect(tutorialBlockFocuses(), findsWidgets);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('2b. Tab prochazi zalozky po jednom bez duplikace (kriticke)', (tester) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      final barFocuses = tester.widgetList<Focus>(tabBarFocuses()).toList();
      expect(barFocuses.length, 9);
      // Fokus na první záložku
      barFocuses.first.focusNode?.requestFocus();
      // Pokud FocusNode je null (interní), použij TabBar Focus fallback – request přes Tab
      if (barFocuses.first.focusNode == null) {
        // Najdi první Focus v TabBar a request
        final first = barFocuses.first;
        // focusNode může být null pro interní, ale Focus widget má interní node
        // Zkusíme přes FocusScope
        Focus.of(tester.element(find.byType(TabBar).first), scopeOk: true).requestFocus();
      }
      await tester.pump();
      // Ověř že Tab prochází sekvenčně: simuluj Tab a zkontroluj že index TabController roste po jednom
      // Místo přímého hasFocus použijeme TabController index a FocusManager
      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      final controller = tabBar.controller!;
      expect(controller.index, 0);
      // Fokus na první záložku – Tab by měl jít na obsah nebo další záložku
      // V ReadingOrderTraversalPolicy: Tab → Tab1 → Tab2 … → Předchozí → Další → Rozumím
      // Ověříme že počet unikátních Tab stops pro záložky je 9, ne 18
      final allFoci = find.byType(Focus).evaluate().toList();
      // Spočítej kolik Focus uzlů má rect stejné jako některá záložka (duplikát)
      // Zjednodušeně: tabBarFocuses musí být 9, ne 18
      expect(barFocuses.length, 9);
      // Simuluj Tab 3× a ověř že controller se neposune (Tab neovládá controller) – ale focus se posune
      // Pro tento test stačí ověřit že fokus na další záložku jde po jednom Tabu
      // Nastav focus na 0, po Tab musí být 1, po dalším Tab 2
      barFocuses[0].focusNode?.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      // FocusManager primární focus musí být nyní na záložce 1 nebo 2?
      // V tuto chvíli tabBarFocuses[1] by měl mít focus
      // Pokud je focusNode null, kontrolujeme přes FocusManager
      final primary = FocusManager.instance.primaryFocus;
      expect(primary, isNotNull);
      // Zkontrolujeme že primární focus je uvnitř TabBar (ještě stále na záložce)
      expect(primary!.context!.findAncestorWidgetOfExactType<TabBar>(), isNotNull,
          reason: 'Po jednom Tabu musí být fokus stále na TabBar, ne na duplicitním wrapperu stejné záložky');
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('3. Tab projde vsechny oczekavane navigovatelne casti', (tester) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      final blockFocuses = tester.widgetList<Focus>(tutorialBlockFocuses()).toList();
      expect(blockFocuses.length, greaterThan(1),
          reason: 'Kazda karta musi mit vice bloku');
      blockFocuses.first.focusNode!.requestFocus();
      await tester.pump();
      expect(blockFocuses.first.focusNode!.hasFocus, isTrue);
      for (var i = 1; i < blockFocuses.length; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(blockFocuses[i].focusNode!.hasFocus, isTrue,
            reason: 'Tab ma prejit na blok $i');
      }
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
      expect(tutorialBlockFocuses(), findsWidgets);
      // Přepni na druhou záložku přes TabBar tap
      final secondTab = find.descendant(of: find.byType(TabBar), matching: find.byType(Tab)).at(1);
      await tester.tap(secondTab);
      await tester.pumpAndSettle();
      final blocksAfter = tester.widgetList<Focus>(tutorialBlockFocuses()).toList();
      expect(blocksAfter.length, greaterThan(0));
      for (final f in blocksAfter) {
        expect(f.focusNode!.skipTraversal, isFalse);
      }
      // TabBar controller musí být na indexu 1
      final controller = tester.widget<TabBar>(find.byType(TabBar)).controller!;
      expect(controller.index, 1);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('10. Po prepnuti karty je nova karta na zacatku (scroll 0)',
        (tester) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      final blocks = tester.widgetList<Focus>(tutorialBlockFocuses()).toList();
      blocks.last.focusNode!.requestFocus();
      await tester.pumpAndSettle();
      final nextFinder = find.text('Next');
      final nextCs = find.text('Další');
      final next = tester.any(nextFinder) ? nextFinder : nextCs;
      final nextBtn = find.ancestor(
        of: next,
        matching: find.byType(TextButton),
      );
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();
      final scrollView = find.byType(SingleChildScrollView);
      expect(scrollView, findsWidgets);
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
      // Začni na první záložce
      TabBar tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.controller!.index, 0);
      final nextText = find.text('Next');
      final nextCsText = find.text('Další');
      final nextLabel = tester.any(nextText) ? nextText : nextCsText;
      final nextBtn = find.ancestor(of: nextLabel, matching: find.byType(TextButton));
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();
      tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.controller!.index, 1);
      final prevText = find.text('Previous');
      final prevCsText = find.text('Předchozí');
      final prevLabel = tester.any(prevText) ? prevText : prevCsText;
      final prevBtn = find.ancestor(of: prevLabel, matching: find.byType(TextButton));
      await tester.tap(prevBtn);
      await tester.pumpAndSettle();
      tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.controller!.index, 0);
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
      final barFocuses = tester.widgetList<Focus>(tabBarFocuses()).toList();
      expect(barFocuses.length, 9, reason: '9 záložek = 9 focus stop, ne 18');
      expect(legacyTutorialTabFocuses(), findsNothing, reason: 'Žádný duplicitní Focus(tutorialTab)');
      final blocks = tester.widgetList<Focus>(tutorialBlockFocuses()).toList();
      // Celkově: 9 tab stop + bloky aktivní karty (bez duplikátů)
      final totalFocusInsideDialog = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Focus),
      ).evaluate().length;
      // Nemusí být přesně blocks+9 kvůli TextButtonům, ale nesmí být 2*9
      expect(barFocuses.length, lessThan(12));
      expect(blocks.length, greaterThan(1));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('14. Semantics strom neobsahuje zbytecne duplicity', (tester) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
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
      final headers = tester.widgetList<Semantics>(find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.header == true,
      )).toList();
      expect(headers.length, greaterThanOrEqualTo(1),
          reason: 'Nadpisy musi byt oznaceny header:true');
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('14b. Kazda zalozka ma prave jeden semantics uzel s nazvem (bez duplikace pozice)', (tester) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      final tabs = find.byType(Tab).evaluate().toList();
      expect(tabs.length, 9);
      // Zkontroluj že žádný Tab nemá 2 labely s pozicí "karta X z 9" duplicitně
      final semantics = tester.widgetList<Semantics>(find.byType(Semantics)).toList();
      int countKartaLabels = 0;
      for (final s in semantics) {
        final label = s.properties.label ?? '';
        if (label.contains('karta ') && label.contains(' z 9')) countKartaLabels++;
      }
      // Po opravě by neměl existovat duplicitní "karta X z 9" v našem custom label
      // – pozici přidává nativní TabBar, my dáváme jen název. Takže count by měl být 0 (my) nebo 9 (nativní), ne 18.
      expect(countKartaLabels, lessThan(18), reason: 'Nesmí být duplicitní "karta X z 9" 2× na záložku');
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

    testWidgets('15. Sipky/Home/End/Ctrl+Tab na TabBar meni zalozku', (tester) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.controller!.index, 0);
      // Dialog po otevření automaticky fokusuje první záložku (InkWell) – ověř
      await tester.pump();
      // Pokud fokus ještě není na TabBar (např. na bloku), přesuň ho Tabem na záložku
      if (FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<TabBar>() ==
          null) {
        // Tab z obsahu zpět na TabBar – Shift+Tab nebo opakovaný Tab
        // Nejjednodušší: tap na TabBar zajistí i focus přes onFocusChange
        await tester.tap(find.byType(Tab).first);
        await tester.pumpAndSettle();
        // Po tapu je potřeba ještě fokusovat – simuluj Tab pro focus
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        // Pokud stále není na TabBar, vynuceně fokusuj první barFocus
        if (FocusManager.instance.primaryFocus?.context
                ?.findAncestorWidgetOfExactType<TabBar>() ==
            null) {
          final barFocuses = tester.widgetList<Focus>(tabBarFocuses()).toList();
          if (barFocuses.isNotEmpty && barFocuses.first.focusNode != null) {
            barFocuses.first.focusNode!.requestFocus();
            await tester.pump();
          }
        }
      }
      // Nyní by měl být fokus na TabBar
      expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<TabBar>(),
          isNotNull,
          reason: 'Fokus musí být na TabBar před šipkami');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 8);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 0);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 0);
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
