import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

// E1 regrese: viditelnost OBSAHU displeje (bodová mřížka + segmentový
// výsledek) na desktopových velikostech okna — 1280x720, 1024x768,
// 800x600 (DPR 1.0), základní i vědecký režim.
//
// Příčina z etapy E0: `_responsiveScale` se na desktopu vymkl na 1,7
// (nejmenší strana = výška okna), rám displeje spořádal celý slot a
// `availableH` kleslo na 0 -> nic se nevykreslilo.
//
// Doplňky z etapy E3: svislý margin a svislý padding rámu byly zmenšeny
// z 8*s na 4*s (úspora 18,4 log při s=1.15 šla 1:1 do availableH), takže
// i při 800x600 ve vědeckém režimu se obsah vejde BEZ nouzového scrollu.
//
// Tento test NESTAČÍ ověřit přítomnost widgetu ve stromu — měříme
// skutečné rozměry (vel > 0), polohu vůči kořeni i k dostupné oblasti
// displeje (ne oříznuté), nepřekrytí mřížky a výsledku, absenci
// RenderFlex overflow a chování nouzové posuvné větve (Scrollbar).
//
// Dvě úrovně kontroly:
//  * expectStrictVisible — běžné scénáře: oba řádky plně viditelné
//    BEZ posunu (kritérium "nejsou svisle oříznuté").
//  * expectEmergencyScrollWorks — extrémní zoom a hraniční textové
//    měřítko 1.5 na 800x600: dle návrhu kódu je nouzový vertikální
//    scroll legitimní; ověřuje se, že Scrollbar existuje a obsah je
//    posunem plně dosažitelný.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<Size> windowSizes = <Size>[
    const Size(1280, 720),
    const Size(1024, 768),
    const Size(800, 600),
  ];

  void mockChannels() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (MethodCall call) async => 1,
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

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'modeQuestionAsked': true,
    });
    mockChannels();
  });

  /// Stejný vzorec jako `_responsiveScale` (po E1: kap 1.15).
  double scaleFor(Size size) => (size.shortestSide / 360.0).clamp(1.0, 1.15);

  /// Kořen displeje: Container s dekorací #121212 a rámečkem
  /// (svislý margin 4*s + border 3*s + svislý padding 4*s; E3 —
  /// vodorovně zůstává 8*s).
  Finder displayRootPredicate() => find.byWidgetPredicate(
    (w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration! as BoxDecoration).color == const Color(0xFF121212) &&
        (w.decoration! as BoxDecoration).border is Border,
    description: 'koren displeje #121212',
  );

  Future<dynamic> pumpSized(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.localeTestValue = const Locale('cs');
    tester.platformDispatcher.textScaleFactorTestValue = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(
      ScientificCalculatorApp(locale: const Locale('cs')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    return tester.state(find.byType(CalculatorScreen)) as dynamic;
  }

  /// Rect elementu (identita widgetu => vždy právě jedna shoda).
  Rect rectOfElement(WidgetTester tester, Element e) =>
      tester.getRect(find.byElementPredicate((x) => identical(x, e)));

  /// Největší (hlavní) výsledkový renderer uvnitř daného finderu.
  Rect largestRect(WidgetTester tester, Finder f) {
    Rect best = Rect.zero;
    for (final e in f.evaluate()) {
      final r = rectOfElement(tester, e);
      if (r.width * r.height > best.width * best.height) best = r;
    }
    return best;
  }

  /// Kontroluje jen svislé uložení uvnitř oblasti. Vodorovně obsah může
  /// přesahovat (horizontální scroll dlouhého výrazu, nebo oříznutí
  /// clippingem nouzové svislé větve) — to řeší zvláštní aserce.
  bool isVerticallyInside(Rect outer, Rect inner) =>
      inner.top >= outer.top - 0.5 && inner.bottom <= outer.bottom + 0.5;

  /// Naměří a ověří základní geometrii: existence obou rendererů,
  /// kladné rozměry, pořadí řádků, umístění uvnitř KOŘENE displeje,
  /// žádná výjimka (RenderFlex overflow apod.).
  ///
  /// Umístění uvnitř kořeme se v nouzové (fallback) větvi před posunem
  /// nekontroluje: obsah je záměrně naložen vyšší než viewport a
  /// ořízne ho clipping scrollovacího pohledu — to řeší
  /// [expectEmergencyScrollWorks].
  ({
    Finder root,
    Rect rootRect,
    Rect dotRect,
    Rect segRect,
    double innerTop,
    double innerBottom,
    bool fallback,
  })
  measure(WidgetTester tester, {required Size size, required String mode}) {
    expect(
      tester.takeException(),
      isNull,
      reason: '$mode @ $size: nesmí vzniknout overflow ani jiná výjimka',
    );

    final dots = find.byType(CustomDotMatrixDisplay);
    expect(
      dots,
      findsWidgets,
      reason: '$mode @ $size: bodová mřížka není ve stromu',
    );

    final root = find
        .ancestor(of: dots.first, matching: displayRootPredicate())
        .first;
    final rootRect = tester.getRect(root);
    expect(
      rootRect.height,
      greaterThan(0.0),
      reason: '$mode @ $size: kořen displeje má výšku ${rootRect.height}',
    );

    final segInDisplay = find.descendant(
      of: root,
      matching: find.byType(CustomSegmentDisplay),
    );
    expect(
      segInDisplay,
      findsWidgets,
      reason: '$mode @ $size: segmentový výsledek není uvnitř displeje',
    );

    final dotRect = rectOfElement(tester, dots.first.evaluate().single);
    final segRect = largestRect(tester, segInDisplay);

    final double s = scaleFor(size);
    // Jednostranný "kůžový" prostor displeje (od vnějšího okraje kořene
    // po vnitřní obsah na JEDNÉ straně): svislý margin 4*s + border 3*s
    // + svislý padding 4*s (E3: dříve 8*s/8*s). Vodorovně 8*s, ale tam
    // se vnitřní hranice netestuje (dlouhý výraz může přesahovat).
    final double chrome = 4 * s + 3 * s.clamp(1.0, 1.3) + 4 * s;
    final double innerTop = rootRect.top + chrome;
    final double innerBottom = rootRect.bottom - chrome;

    final fallbackFinder = find.descendant(
      of: root,
      matching: find.byWidgetPredicate(
        (w) => w is SingleChildScrollView && w.scrollDirection == Axis.vertical,
      ),
    );
    final bool hasFallback = fallbackFinder.evaluate().isNotEmpty;

    // ignore: avoid_print
    print(
      'E1-MEAS size=$size mode=$mode '
      'rootH=${rootRect.height.toStringAsFixed(1)} '
      'dotH=${dotRect.height.toStringAsFixed(1)} '
      'segH=${segRect.height.toStringAsFixed(1)} '
      'dotTop=${dotRect.top.toStringAsFixed(1)} '
      'segTop=${segRect.top.toStringAsFixed(1)} '
      'segBottom=${segRect.bottom.toStringAsFixed(1)} '
      'innerTop=${innerTop.toStringAsFixed(1)} '
      'innerBottom=${innerBottom.toStringAsFixed(1)} '
      'fallback=$hasFallback '
      'segVisibleInitially=${segRect.bottom <= innerBottom + 0.5}',
    );

    // 1) skutečné rozměry > 0 (a ne jen nepatrný proužek)
    expect(
      dotRect.height,
      greaterThan(5.0),
      reason: '$mode @ $size: výška bodové mřížky je ${dotRect.height}',
    );
    expect(
      segRect.height,
      greaterThan(5.0),
      reason: '$mode @ $size: výška segmentového výsledku je ${segRect.height}',
    );
    expect(dotRect.width, greaterThan(0.0));

    // mřížka výš, výsledek níž, bez překryvu
    expect(
      dotRect.bottom,
      lessThanOrEqualTo(segRect.top + 0.5),
      reason: '$mode @ $size: mřížka a výsledek se překrývají',
    );

    if (!hasFallback) {
      // Běžná větev: celý obsah se vejde svisle uvnitř kořene displeje.
      // Vodorovně může dlouhý výraz přesahovat (scroll), proto jen svisle.
      expect(
        isVerticallyInside(rootRect, dotRect),
        isTrue,
        reason:
            '$mode @ $size: mřížka svisle mimo displej '
            '(dotRect=$dotRect vs rootRect=$rootRect)',
      );
      expect(
        isVerticallyInside(rootRect, segRect),
        isTrue,
        reason:
            '$mode @ $size: výsledek svisle mimo displej '
            '(segRect=$segRect vs rootRect=$rootRect)',
      );
    }

    expect(
      tester.takeException(),
      isNull,
      reason: '$mode @ $size: žádná výjimka po změření geometrie',
    );

    return (
      root: root,
      rootRect: rootRect,
      dotRect: dotRect,
      segRect: segRect,
      innerTop: innerTop,
      innerBottom: innerBottom,
      fallback: hasFallback,
    );
  }

  /// PŘÍSNÁ viditelnost pro běžné scénáře: oba řádky jsou v úvodním
  /// stavu (bez posunu) plně uvnitř dostupné oblasti displeje.
  Future<void> expectStrictVisible(
    WidgetTester tester, {
    required Size size,
    required String mode,
  }) async {
    final g = measure(tester, size: size, mode: mode);

    expect(
      g.dotRect.top,
      greaterThanOrEqualTo(g.innerTop - 0.5),
      reason: '$mode @ $size: mřížka je nad dostupnou oblastí',
    );
    expect(
      g.segRect.bottom,
      lessThanOrEqualTo(g.innerBottom + 0.5),
      reason:
          '$mode @ $size: výsledek je svisle oříznutý/neviditelný — '
          'segBottom=${g.segRect.bottom} > innerBottom=${g.innerBottom} '
          '(fallback=${g.fallback})',
    );
    expect(
      isVerticallyInside(g.rootRect, g.dotRect) &&
          isVerticallyInside(g.rootRect, g.segRect),
      isTrue,
      reason: '$mode @ $size: obsah svisle mimo kořen displeje',
    );
    // E3: při standardním textovém měřítku a zoomu nesmí být aktivní
    // nouzová svislá posuvná větev — obsah se musí vejít bez posunu.
    expect(
      g.fallback,
      isFalse,
      reason:
          '$mode @ $size: nouzový vertikální scroll je zapnutý '
          '(fitScale narazil na podlahu 0,36) — displej není kompletně '
          'viditelný bez posunu',
    );
    expect(tester.takeException(), isNull);
  }

  /// Nouzová (fallback) větev: Scrollbar je přítomný a obsah je posunem
  /// plně dosažitelný — v bodě 0 je viditelná mřížka, na konci výsledek.
  Future<void> expectEmergencyScrollWorks(
    WidgetTester tester, {
    required Size size,
    required String mode,
  }) async {
    final g = measure(tester, size: size, mode: mode);
    expect(
      g.fallback,
      isTrue,
      reason: '$mode @ $size: měla by být aktivní nouzová větev',
    );

    final scrollbar = find.descendant(
      of: g.root,
      matching: find.byType(Scrollbar),
    );
    expect(
      scrollbar,
      findsOneWidget,
      reason: '$mode @ $size: nouzová větev musí mít viditelný Scrollbar',
    );

    final verticalScrollable = find.descendant(
      of: g.root,
      matching: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ),
    );
    expect(verticalScrollable, findsOneWidget);
    final st = tester.state<ScrollableState>(verticalScrollable);

    // Bod 0: horní hrana mřížky = začátek obsahu (dosažitelné posunem nahoru).
    st.position.jumpTo(0);
    await tester.pumpAndSettle();
    final dotTopRect = rectOfElement(
      tester,
      find.byType(CustomDotMatrixDisplay).first.evaluate().single,
    );
    expect(
      dotTopRect.top,
      greaterThanOrEqualTo(g.innerTop - 0.5),
      reason:
          '$mode @ $size: po posunu na začátek není mřížka nahoře '
          '(dotTop=${dotTopRect.top} < innerTop=${g.innerTop})',
    );
    expect(
      isVerticallyInside(g.rootRect, dotTopRect),
      isTrue,
      reason: '$mode @ $size: mřížka svisle mimo kořen displeje',
    );

    // Konec: výsledek plně uvnitř dostupné oblasti.
    st.position.jumpTo(st.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final segInDisplay = find.descendant(
      of: g.root,
      matching: find.byType(CustomSegmentDisplay),
    );
    final segEnd = largestRect(tester, segInDisplay);
    expect(
      segEnd.top >= g.innerTop - 0.5 && segEnd.bottom <= g.innerBottom + 0.5,
      isTrue,
      reason:
          '$mode @ $size: po posunu na konec není výsledek vidět celý '
          '(segEnd=$segEnd, inner=[${g.innerTop}..${g.innerBottom}])',
    );

    // Průběžná kontrola: žádná výjimka (overflow) po posunech.
    expect(
      tester.takeException(),
      isNull,
      reason: '$mode @ $size: bez výjimky po posunech nouzové větve',
    );
  }

  group('E1 - viditelnost displeje na desktopových velikostech okna', () {
    testWidgets('vědecký režim: 1280x720, 1024x768, 800x600', (tester) async {
      for (final size in windowSizes) {
        final state = await pumpSized(tester, size);
        state.switchModeForTest(CalculatorMode.scientific);
        await tester.pumpAndSettle();
        expect(state.currentModeForTest, CalculatorMode.scientific);
        await expectStrictVisible(tester, size: size, mode: 'scientific');
      }
    });

    testWidgets('základní režim: 1280x720, 1024x768, 800x600', (tester) async {
      for (final size in windowSizes) {
        final state = await pumpSized(tester, size);
        state.switchModeForTest(CalculatorMode.basic);
        await tester.pumpAndSettle();
        expect(state.currentModeForTest, CalculatorMode.basic);
        await expectStrictVisible(tester, size: size, mode: 'basic');
      }
    });

    testWidgets('změna velikosti okna za běhu displej nezničí', (tester) async {
      final state = await pumpSized(tester, const Size(1280, 720));
      state.switchModeForTest(CalculatorMode.scientific);
      await tester.pumpAndSettle();
      await expectStrictVisible(
        tester,
        size: const Size(1280, 720),
        mode: 'resize-start',
      );

      for (final size in <Size>[
        const Size(1024, 768),
        const Size(800, 600),
        const Size(1280, 720),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'resize na $size bez výjimky',
        );
        await expectStrictVisible(tester, size: size, mode: 'resized');
      }
    });

    testWidgets('přepínání základní <-> vědecký displej nezmaže', (
      tester,
    ) async {
      const size = Size(1024, 768);
      final state = await pumpSized(tester, size);
      for (final mode in <CalculatorMode>[
        CalculatorMode.basic,
        CalculatorMode.scientific,
        CalculatorMode.basic,
      ]) {
        state.switchModeForTest(mode);
        await tester.pumpAndSettle();
        expect(state.currentModeForTest, mode);
        await expectStrictVisible(
          tester,
          size: size,
          mode: 'switched-${mode.name}',
        );
      }
    });

    testWidgets('dlouhý výraz: horizontální posun bez svislého poškození', (
      tester,
    ) async {
      const size = Size(1280, 720);
      final state = await pumpSized(tester, size);
      state.switchModeForTest(CalculatorMode.scientific);
      await tester.pumpAndSettle();

      // Na širokém okně se musí výraz dostatečně natáhnout (~170 znaků),
      // aby vůbec vznikl horizontální posun.
      final expr = '1234567890+1234567890*' * 8;
      state.setDisplayForTest(expr, expr.length);
      await tester.pumpAndSettle();
      expect(state.displayForTest, expr);

      final g = measure(tester, size: size, mode: 'long-expression');

      // Horizontální scrollovatelnost: alespoň jeden vodorovný Scrollable
      // uvnitř displeje má kladný maxScrollExtent a jde posunout.
      final horizontal = find.descendant(
        of: g.root,
        matching: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
        ),
      );
      expect(horizontal, findsWidgets, reason: 'vodorovné scrollování chybí');
      bool movable = false;
      for (final e in horizontal.evaluate()) {
        final st = tester.state<ScrollableState>(
          find.byElementPredicate((x) => identical(x, e)),
        );
        if (st.position.maxScrollExtent > 0) {
          st.position.jumpTo(40);
          movable = true;
          break;
        }
      }
      expect(
        movable,
        isTrue,
        reason: 'dlouhý výraz musí být horizontálně posunovatelný',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Po posunu zůstává svislé rozvržení netknuté (řádky se nepřekryjí,
      // obsah zůstává uvnitř displeje).
      final g2 = measure(tester, size: size, mode: 'long-after-scroll');
      expect(
        g2.dotRect.bottom,
        lessThanOrEqualTo(g2.segRect.top + 0.5),
        reason: 'po horizontálním posunu se nesmí překrýt řádky',
      );
      expect(isVerticallyInside(g2.rootRect, g2.dotRect), isTrue);
      expect(isVerticallyInside(g2.rootRect, g2.segRect), isTrue);
      expect(
        g2.segRect.bottom,
        lessThanOrEqualTo(g2.innerBottom + 0.5),
        reason: 'po posunu musí být výsledek plně viditelný',
      );
    });

    testWidgets('nouzová posuvná větev: extrémní zoom + Scrollbar', (
      tester,
    ) async {
      const size = Size(1280, 720);
      final state = await pumpSized(tester, size);
      state.switchModeForTest(CalculatorMode.scientific);
      await tester.pumpAndSettle();

      // Běžný stav bez zoomu: standardní větev.
      await expectStrictVisible(tester, size: size, mode: 'no-zoom');

      // Extrémní zoom (obě šipky = 5): fitScale narazí na podlahu 0,35
      // a musí se zapnout nouzová větev se Scrollbarem a plnou
      // dosažitelností obsahu posunem.
      state.updateActiveSettingsForTest(
        (s) => s.copyWith(dotMatrixZoom: 5.0, resultZoom: 5.0),
      );
      await tester.pumpAndSettle();
      expect(state.dotMatrixZoomForTest, 5.0);
      expect(state.resultZoomForTest, 5.0);
      await expectEmergencyScrollWorks(tester, size: size, mode: 'zoom-5x');
    });

    testWidgets('hraniční textové měřítko 1.5: 800x600 vědecký režim', (
      tester,
    ) async {
      // E3 dodatečný hraniční scénář: systémové zvětšení textu 1.5
      // (sysFactor má v kódu strop 1.5) na nejmenším podporovaném
      // desktopovém okně. Produkční algoritmus se NEMĚNIL.
      //
      // Naměřeno (E3): fitScale narazí na podlahu 0,35 (availableH ≈ 19,9
      // proti potřebě 30,9 = 0,35 * neededH 88,4), takže se zapíná
      // nouzová větev — stejně jako při extrémním zoomu níže. Úplné
      // zobrazení BEZ posunu by vyžadovalo další produkční zásah
      // (např. odstranění zbylého margin/paddingu rámu nebo neskalování
      // řádku názvu režimu), což je mimo rozsah E3. Proto tento scénář
      // ověřuje nižší (ale legitimní) úroveň: obsah je nouzovým
      // scrollem plně dosažitelný a nic se nepřekrývá.
      const size = Size(800, 600);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.localeTestValue = const Locale('cs');
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.pumpWidget(
        ScientificCalculatorApp(locale: const Locale('cs')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final state = tester.state(find.byType(CalculatorScreen)) as dynamic;
      state.switchModeForTest(CalculatorMode.scientific);
      await tester.pumpAndSettle();
      expect(state.currentModeForTest, CalculatorMode.scientific);
      await expectEmergencyScrollWorks(
        tester,
        size: size,
        mode: 'sci-textScale1.5',
      );
    });
  });
}
