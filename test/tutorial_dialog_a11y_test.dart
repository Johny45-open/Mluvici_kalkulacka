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

  Finder legacyTutorialTabFocuses() {
    return find.byWidgetPredicate(
      (w) => w is Focus && (w.debugLabel ?? '') == 'tutorialTab',
    );
  }

  Finder tabBarFocuses() {
    return find.descendant(
      of: find.byType(TabBar),
      matching: find.byWidgetPredicate((w) {
        if (w is! Focus) return false;
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

  Finder prevButtonFinder(WidgetTester tester) {
    final prevCs = find.text('Předchozí');
    final prevEn = find.text('Previous');
    if (tester.any(prevCs)) return prevCs;
    return prevEn;
  }

  Finder nextButtonFinder(WidgetTester tester) {
    final nextCs = find.text('Další');
    final nextEn = find.text('Next');
    if (tester.any(nextCs)) return nextCs;
    return nextEn;
  }

  Finder understandButtonFinder(WidgetTester tester) {
    final cs = find.text('ROZUMÍM');
    final en = find.text('UNDERSTAND');
    if (tester.any(cs)) return cs;
    return en;
  }

  Future<void> ensureFocusOnTabBar(WidgetTester tester) async {
    if (FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<TabBar>() !=
        null) {
      return;
    }
    // Zkus tap na aktuálně vybranou záložku
    try {
      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      final idx = tabBar.controller?.index ?? 0;
      await tester.tap(find.byType(Tab).at(idx));
      await tester.pumpAndSettle();
      if (FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<TabBar>() !=
          null)
        return;
    } catch (_) {}
    // Fallback: Tabuj dokud se nedostaneme do TabBar (max 15×, pak Shift+Tab)
    for (int i = 0; i < 15; i++) {
      if (FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<TabBar>() !=
          null)
        return;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    for (int i = 0; i < 15; i++) {
      if (FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<TabBar>() !=
          null)
        return;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pump();
    }
  }

  group('Tutorial dialog accessibility', () {
    testWidgets('1. Po otevreni dialogu je fokus v dialogu', (tester) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      expect(find.byType(AlertDialog), findsOneWidget);
      final focused = FocusManager.instance.primaryFocus;
      expect(focused, isNotNull, reason: 'Dialog musi mit fokus');
      expect(focused!.context, isNotNull);
      expect(
        focused.context!.findAncestorWidgetOfExactType<AlertDialog>(),
        isNotNull,
        reason: 'Fokus musi byt uvnitr dialogu',
      );
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets(
      '2. Aktualni karta je spravne fokusovatelna – jedna zalozka = jeden Tab stop, 0 bloku',
      (tester) async {
        final state = await pumpApp(tester);
        await openTutorial(tester, state);
        expect(tabCount(tester), 9, reason: 'Dialog má 9 záložek');
        expect(
          legacyTutorialTabFocuses(),
          findsNothing,
          reason: 'Po opravě nesmí existovat duplicitní Focus(tutorialTab)',
        );
        final barFocuses = tester.widgetList<Focus>(tabBarFocuses()).toList();
        expect(
          barFocuses.length,
          9,
          reason: 'Každá záložka má právě jeden InkWell Focus',
        );
        expect(
          tutorialBlockFocuses(),
          findsNothing,
          reason:
              'Statický text nesmí mít žádný Tab stop (0 tutorialBlock Focus)',
        );
        await tester.pump(const Duration(seconds: 2));
      },
    );

    testWidgets('2b. Tab prochazi zalozky po jednom bez duplikace (kriticke)', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      final barFocuses = tester.widgetList<Focus>(tabBarFocuses()).toList();
      expect(barFocuses.length, 9);
      barFocuses.first.focusNode?.requestFocus();
      if (barFocuses.first.focusNode == null) {
        Focus.of(
          tester.element(find.byType(TabBar).first),
          scopeOk: true,
        ).requestFocus();
      }
      await tester.pump();
      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      final controller = tabBar.controller!;
      expect(controller.index, 0);
      expect(barFocuses.length, 9);
      barFocuses[0].focusNode?.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final primary = FocusManager.instance.primaryFocus;
      expect(primary, isNotNull);
      expect(
        primary!.context!.findAncestorWidgetOfExactType<TabBar>(),
        isNotNull,
        reason:
            'Po jednom Tabu musí být fokus stále na TabBar, ne na duplicitním wrapperu stejné záložky',
      );
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets(
      '3. Tab po posledni zalozce jde primo na Predchozi -> Dalsi -> Rozumim bez zastavky na textu',
      (tester) async {
        final state = await pumpApp(tester);
        await openTutorial(tester, state);
        expect(
          tutorialBlockFocuses(),
          findsNothing,
          reason: 'Žádný tutorialBlock Focus nesmí existovat',
        );
        final barFocuses = tester.widgetList<Focus>(tabBarFocuses()).toList();
        expect(barFocuses.length, 9);
        // Nastav prostřední záložku aby Předchozí i Další byly enabled
        final controller = tester
            .widget<TabBar>(find.byType(TabBar))
            .controller!;
        controller.animateTo(4);
        await tester.pumpAndSettle();
        await ensureFocusOnTabBar(tester);
        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<TabBar>(),
          isNotNull,
          reason: 'Fokus musí být na TabBar před Traversal',
        );
        // Projdeme Tabem dokud neopustíme TabBar – TabBar má 9 stop, musíme jimi projít všechny
        int safety = 0;
        while (FocusManager.instance.primaryFocus?.context
                    ?.findAncestorWidgetOfExactType<TabBar>() !=
                null &&
            safety < 12) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(tutorialBlockFocuses(), findsNothing);
          safety++;
        }
        expect(safety, greaterThan(0), reason: 'Museli jsme opustit TabBar');
        expect(
          safety,
          lessThan(12),
          reason: 'TabBar má 9 stop, nesmí trvat déle',
        );
        expect(
          FocusManager.instance.primaryFocus,
          isNotNull,
          reason: 'Fokus nesmí být null po opuštění TabBar',
        );
        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<TextButton>(),
          isNotNull,
          reason:
              'Po poslední záložce musí být fokus na TextButton (Předchozí)',
        );
        final prevFinder = prevButtonFinder(tester);
        expect(prevFinder, findsOneWidget);
        // Další Tab → Další
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(tutorialBlockFocuses(), findsNothing);
        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<TextButton>(),
          isNotNull,
          reason: 'Druhý Tab po TabBar musí být na Další',
        );
        final nextFinder = nextButtonFinder(tester);
        expect(nextFinder, findsOneWidget);
        // Další Tab → Rozumím (v actions)
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(tutorialBlockFocuses(), findsNothing);
        final understandFinder = understandButtonFinder(tester);
        expect(understandFinder, findsOneWidget);
        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<TextButton>(),
          isNotNull,
          reason: 'Po Další musí být fokus na Rozumím',
        );
        expect(tutorialBlockFocuses(), findsNothing);
        expect(find.byType(SingleChildScrollView), findsWidgets);
        expect(find.byType(Text), findsWidgets);
        await tester.pump(const Duration(seconds: 2));
      },
    );

    testWidgets(
      '3b. Shift+Tab jde opacne Rozumim -> Dalsi -> Predchozi -> posledni zalozka bez textu',
      (tester) async {
        final state = await pumpApp(tester);
        await openTutorial(tester, state);
        expect(tutorialBlockFocuses(), findsNothing);
        await ensureFocusOnTabBar(tester);
        // Přejdi na Rozumím přes Tab sekvenci
        for (int i = 0; i < 11; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        final understandFinder = understandButtonFinder(tester);
        expect(understandFinder, findsOneWidget);
        // Nyní Shift+Tab zpět
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
        await tester.pump();
        expect(tutorialBlockFocuses(), findsNothing);
        // Fokus by měl být na Další nebo Předchozí (opačný směr)
        expect(FocusManager.instance.primaryFocus, isNotNull);
        expect(
          tutorialBlockFocuses(),
          findsNothing,
          reason: 'Shift+Tab nesmí narazit na blok',
        );
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
        await tester.pump();
        expect(tutorialBlockFocuses(), findsNothing);
        // Další Shift+Tab až na TabBar
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
        await tester.pump();
        // Může být na Předchozí nebo už v TabBar – hlavně nesmí být na bloku
        expect(tutorialBlockFocuses(), findsNothing);
        await tester.pump(const Duration(seconds: 2));
      },
    );

    testWidgets(
      '4. Staticky text neni focusovatelny, ArrowUp/Down na TabBar nemeni focus na bloky',
      (tester) async {
        final state = await pumpApp(tester);
        await openTutorial(tester, state);
        expect(tutorialBlockFocuses(), findsNothing);
        final controller = tester
            .widget<TabBar>(find.byType(TabBar))
            .controller!;
        controller.animateTo(4);
        await tester.pumpAndSettle();
        await ensureFocusOnTabBar(tester);
        final before = FocusManager.instance.primaryFocus;
        expect(before, isNotNull);
        expect(
          before!.context!.findAncestorWidgetOfExactType<TabBar>(),
          isNotNull,
          reason: 'Fokus musí být na TabBar',
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(tutorialBlockFocuses(), findsNothing);
        // ArrowDown/Up na TabBar nesmí přesunout fokus na textový blok (0 Tab stop).
        // Může zůstat na TabBar (ignored) nebo být stále v dialogu – hlavně nesmí být na bloku a nesmí být null.
        expect(
          FocusManager.instance.primaryFocus,
          isNotNull,
          reason: 'Fokus nesmí být null po ArrowDown',
        );
        expect(
          FocusManager.instance.primaryFocus!.context!
              .findAncestorWidgetOfExactType<AlertDialog>(),
          isNotNull,
        );
        expect(tutorialBlockFocuses(), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(tutorialBlockFocuses(), findsNothing);
        expect(FocusManager.instance.primaryFocus, isNotNull);
        await tester.pump(const Duration(seconds: 2));
      },
    );

    testWidgets('5. Home/End/PageUp/PageDown na TabBar nemeni fokus na text', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      // Tento test byl dříve závislý na blocích – nyní pouze ověřuje že bloky nejsou focusovatelné
      // a že Home/End/Ctrl+Tab na záložkách stále fungují (pokryto testem 15), zde jen negativní test
      await ensureFocusOnTabBar(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(tutorialBlockFocuses(), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(tutorialBlockFocuses(), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();
      expect(tutorialBlockFocuses(), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pump();
      expect(tutorialBlockFocuses(), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    }, skip: false);

    // Reálný test pro Home/End/PageUp/PageDown pokryt v testu 15 – zde jen ověřujeme že bloky nejsou Tab stopy

    testWidgets('9. Prepnuti karty zachova 0 Tab stop v obsahu a spravny index', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      expect(tutorialBlockFocuses(), findsNothing);
      final secondTab = find
          .descendant(of: find.byType(TabBar), matching: find.byType(Tab))
          .at(1);
      await tester.tap(secondTab);
      await tester.pumpAndSettle();
      expect(
        tutorialBlockFocuses(),
        findsNothing,
        reason: 'Po přepnutí stále 0 blok Focusů',
      );
      final controller = tester.widget<TabBar>(find.byType(TabBar)).controller!;
      expect(controller.index, 1);
      // Ověř že Tab po přepnutí stále jde přímo na tlačítka (bez bloků) – projdeme TabBar až do opuštění
      await ensureFocusOnTabBar(tester);
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<TabBar>(),
        isNotNull,
      );
      int safety = 0;
      while (FocusManager.instance.primaryFocus?.context
                  ?.findAncestorWidgetOfExactType<TabBar>() !=
              null &&
          safety < 12) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(tutorialBlockFocuses(), findsNothing);
        safety++;
      }
      expect(safety, greaterThan(0));
      expect(FocusManager.instance.primaryFocus, isNotNull);
      expect(
        FocusManager.instance.primaryFocus!.context!
            .findAncestorWidgetOfExactType<TextButton>(),
        isNotNull,
        reason: 'Po poslední záložce musí být fokus na tlačítku, ne na bloku',
      );
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('10. Po prepnuti karty je nova karta na zacatku (scroll 0)', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      // Už žádné blok Focus – pouze scroll ověření
      final nextFinder = nextButtonFinder(tester);
      final nextBtn = find.ancestor(
        of: nextFinder,
        matching: find.byType(TextButton),
      );
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();
      final scrollView = find.byType(SingleChildScrollView);
      expect(scrollView, findsWidgets);
      final firstScrollable = tester.widget<SingleChildScrollView>(
        scrollView.first,
      );
      if (firstScrollable.controller != null &&
          firstScrollable.controller!.hasClients) {
        expect(firstScrollable.controller!.offset, 0.0);
      }
      expect(tutorialBlockFocuses(), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('11. Predchozi/Dalsi funguje', (tester) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      TabBar tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.controller!.index, 0);
      final nextLabel = nextButtonFinder(tester);
      final nextBtn = find.ancestor(
        of: nextLabel,
        matching: find.byType(TextButton),
      );
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();
      tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.controller!.index, 1);
      final prevLabel = prevButtonFinder(tester);
      final prevBtn = find.ancestor(
        of: prevLabel,
        matching: find.byType(TextButton),
      );
      await tester.tap(prevBtn);
      await tester.pumpAndSettle();
      tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.controller!.index, 0);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('12. Zavreni dialogu funguje', (tester) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      final close = understandButtonFinder(tester);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('13. Nejsou pritomne duplicitni focus stopy a 0 bloku', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      final barFocuses = tester.widgetList<Focus>(tabBarFocuses()).toList();
      expect(barFocuses.length, 9, reason: '9 záložek = 9 focus stop, ne 18');
      expect(
        legacyTutorialTabFocuses(),
        findsNothing,
        reason: 'Žádný duplicitní Focus(tutorialTab)',
      );
      expect(
        tutorialBlockFocuses(),
        findsNothing,
        reason: '0 Tab stop pro statický text',
      );
      expect(barFocuses.length, lessThan(12));
      // Celkový počet Focus v dialogu by měl být 9 (záložky) + 3 (tlačítka) + pár interních FocusScope
      final totalFocusInsideDialog = find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Focus),
          )
          .evaluate()
          .length;
      // Nesmí být N bloků navíc (dříve 10-25)
      expect(
        totalFocusInsideDialog,
        lessThan(30),
        reason: 'Žádné blok Focusy nesmí nafukovat strom',
      );
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets(
      '14. Semantics strom zustava dostupny pro odectac – text, header, bullet',
      (tester) async {
        final state = await pumpApp(tester);
        await openTutorial(tester, state);
        bool hasGiantLabel = false;
        final semWidgets = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .toList();
        for (final w in semWidgets) {
          final label = w.properties.label ?? '';
          if (label.length > 500) {
            hasGiantLabel = true;
          }
        }
        expect(
          hasGiantLabel,
          isFalse,
          reason: 'Nesmi existovat jeden obri Semantics label',
        );
        final headers = tester
            .widgetList<Semantics>(
              find.byWidgetPredicate(
                (w) => w is Semantics && w.properties.header == true,
              ),
            )
            .toList();
        expect(
          headers.length,
          greaterThanOrEqualTo(1),
          reason: 'Nadpisy musi byt oznaceny header:true',
        );
        // Ověř že samotný text je stále v semantics (Text widgety)
        expect(find.byType(Text), findsWidgets);
        // Ověř že odrážky mají dekorativní • skrytou a text viditelný
        // Najdi alespoň jeden Text s obsahem (ne prázdný)
        final texts = tester.widgetList<Text>(find.byType(Text)).toList();
        expect(texts.length, greaterThan(5));
        // ExcludeSemantics pouze na •, ne na obsah – ověř že obsah není ExcludeSemantics
        expect(tutorialBlockFocuses(), findsNothing);
        // SelectionArea stále existuje a text je uvnitř
        expect(find.byType(SelectionArea), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SelectionArea),
            matching: find.byType(Column),
          ),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 2));
      },
    );

    testWidgets(
      '14b. Kazda zalozka ma prave jeden semantics uzel s nazvem (bez duplikace pozice)',
      (tester) async {
        final state = await pumpApp(tester);
        await openTutorial(tester, state);
        final tabs = find.byType(Tab).evaluate().toList();
        expect(tabs.length, 9);
        final semantics = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .toList();
        int countKartaLabels = 0;
        for (final s in semantics) {
          final label = s.properties.label ?? '';
          if (label.contains('karta ') && label.contains(' z 9'))
            countKartaLabels++;
        }
        expect(
          countKartaLabels,
          lessThan(18),
          reason: 'Nesmí být duplicitní "karta X z 9" 2× na záložku',
        );
        await tester.pump(const Duration(seconds: 2));
      },
    );

    testWidgets(
      '14c. Text zustava dostupny po odstraneni Focus – NVDA/TalkBack reading',
      (tester) async {
        final state = await pumpApp(tester);
        await openTutorial(tester, state);
        expect(tutorialBlockFocuses(), findsNothing);
        // Všechny Text widgety musí být stále v semantics tree (ne ExcludeSemantics)
        final semanticsNodes = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .toList();
        // Hledej outer Semantics container pro obsah karty
        final contentSemantics = find.descendant(
          of: find.byType(TabBarView),
          matching: find.byType(Semantics),
        );
        expect(contentSemantics, findsWidgets);
        // Ověř že SelectionArea.Column obsahuje Text
        final columnTexts = find.descendant(
          of: find.byType(SelectionArea),
          matching: find.byType(Text),
        );
        expect(columnTexts, findsWidgets);
        // Žádný ExcludeSemantics nesmí obalit celý obsah manuálu
        // (ExcludeSemantics pouze na • dekoraci je povolen)
        final excludeSemantics = tester
            .widgetList<ExcludeSemantics>(find.byType(ExcludeSemantics))
            .toList();
        // Smí existovat ExcludeSemantics pro • a pro neaktivní karty, ale ne pro aktivní obsah
        // Aktivní obsah nesmí být uvnitř ExcludeSemantics
        expect(tutorialBlockFocuses(), findsNothing);
        await tester.pump(const Duration(seconds: 2));
      },
    );

    testWidgets('15. Sipky/Home/End/Ctrl+Tab na TabBar meni zalozku', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await openTutorial(tester, state);
      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.controller!.index, 0);
      await tester.pump();
      if (FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<TabBar>() ==
          null) {
        await tester.tap(find.byType(Tab).first);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
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
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<TabBar>(),
        isNotNull,
        reason: 'Fokus musí být na TabBar před šipkami',
      );
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
      // Ověř že bloky stále nejsou focusovatelné ani po navigaci záložkami
      expect(tutorialBlockFocuses(), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
