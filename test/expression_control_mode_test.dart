import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Z1: režim ovládání výrazu + konzumace kláves (`Focus.onKeyEvent`).
///
/// Ověřuje chování a návratové hodnoty handleru (`handled`/`ignored`),
/// nikoli pouze přítomnost widgetu:
/// 1. primární fokus + režim ON: šipky/Home/End hýbou kurzorem (handled);
/// 2. fokus na tlačítku: šipka kurzor nehýbe (ignored) — past předka;
/// 3. režim OFF + primární fokus: šipka kurzor nehýbe (ignored);
/// 4. počáteční requestFocus režim aktivuje, listener jej nevypne;
/// 5. aktivace displeje režim zapne a callback jej nezruší;
/// 6. dialog režim vypne, návrat fokusu jej nezapne;
/// 7. KeyRepeatEvent/KeyUpEvent kurzor nehýbou;
/// 8. SR-passthrough, Tab, Ctrl+Tab, Delete, Escape, Enter beze změny;
/// 9. právě jedno oznámení, žádná synchronizační smyčka;
/// 10. žádná softwarová klávesnice (readOnly + TextInputType.none).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<String> ttsLog = [];

  setUp(() {
    ttsLog.clear();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'modeQuestionAsked': true,
    });
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
      MethodCall call,
    ) async {
      if (call.method == 'speak') {
        ttsLog.add(call.arguments as String? ?? '');
      }
      return 1;
    });
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

  /// Spustí aplikaci bez ručního fokusování (pro test počátečního stavu).
  Future<dynamic> pumpAppRaw(
    WidgetTester tester, {
    Locale locale = const Locale('cs'),
  }) async {
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.localeTestValue = locale;
    tester.platformDispatcher.textScaleFactorTestValue = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(ScientificCalculatorApp(locale: locale));
    await tester.pumpAndSettle();
    return tester.state(find.byType(CalculatorScreen)) as dynamic;
  }

  Future<dynamic> pumpApp(
    WidgetTester tester, {
    Locale locale = const Locale('cs'),
  }) async {
    final state = await pumpAppRaw(tester, locale: locale);
    (state.mainFocusNodeForTest as FocusNode).requestFocus();
    await tester.pumpAndSettle();
    return state;
  }

  KeyDownEvent keyDown(
    PhysicalKeyboardKey physical,
    LogicalKeyboardKey logical, {
    String? character,
  }) {
    return KeyDownEvent(
      physicalKey: physical,
      logicalKey: logical,
      timeStamp: Duration.zero,
      character: character,
    );
  }

  group('Z1 režim ovládání výrazu', () {
    testWidgets('1. primární fokus + ON: šipky/Home/End hýbou (handled)',
        (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();
      expect(state.expressionControlActiveForTest, isTrue);
      final FocusNode main = state.mainFocusNodeForTest as FocusNode;
      expect(main.hasPrimaryFocus, isTrue);

      // Návratové hodnoty přímým voláním.
      expect(
        state.handleKeyEventForTest(
          keyDown(PhysicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowLeft),
        ),
        KeyEventResult.handled,
      );
      expect(
        state.handleKeyEventForTest(
          keyDown(PhysicalKeyboardKey.arrowRight, LogicalKeyboardKey.arrowRight),
        ),
        KeyEventResult.handled,
      );
      expect(
        state.handleKeyEventForTest(
          keyDown(PhysicalKeyboardKey.home, LogicalKeyboardKey.home),
        ),
        KeyEventResult.handled,
      );
      expect(
        state.handleKeyEventForTest(
          keyDown(PhysicalKeyboardKey.end, LogicalKeyboardKey.end),
        ),
        KeyEventResult.handled,
      );

      // Reálná cesta přes focus strom.
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(state.cursorForTest, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(state.cursorForTest, 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(state.cursorForTest, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(state.cursorForTest, 4);
    });

    testWidgets('2. fokus na tlačítku: šipka nehýbe (ignored)', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();

      // Odchod primárního fokusu na potomka (tlačítko kalkulačky).
      final BuildContext ctx = state.contextForTest as BuildContext;
      FocusScope.of(ctx).nextFocus();
      await tester.pumpAndSettle();

      final FocusNode main = state.mainFocusNodeForTest as FocusNode;
      expect(
        FocusManager.instance.primaryFocus,
        isNot(main),
        reason: 'Primární fokus musí odejít z kořene',
      );
      // Past předka: kořen má stále hasFocus (potomek fokusován),
      // ale NEMÁ hasPrimaryFocus — brána stojí na hasPrimaryFocus.
      expect(main.hasFocus, isTrue);
      expect(main.hasPrimaryFocus, isFalse);
      expect(state.expressionControlActiveForTest, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(state.cursorForTest, 2);
      expect(
        state.handleKeyEventForTest(
          keyDown(PhysicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowLeft),
        ),
        KeyEventResult.ignored,
      );
      expect(
        state.handleKeyEventForTest(
          keyDown(PhysicalKeyboardKey.end, LogicalKeyboardKey.end),
        ),
        KeyEventResult.ignored,
      );
    });

    testWidgets('3. režim OFF + primární fokus: šipka reaktivuje', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();
      // Přímý setter (důvod none = např. po ztrátě AT-fokusu): při hloubce
      // dialogů 0 smí první šipka armovat i bez důvodu traversal.
      state.setExpressionControlActiveForTest(false);
      await tester.pumpAndSettle();

      final FocusNode main = state.mainFocusNodeForTest as FocusNode;
      expect(main.hasPrimaryFocus, isTrue);
      expect(
        state.handleKeyEventForTest(
          keyDown(PhysicalKeyboardKey.arrowRight, LogicalKeyboardKey.arrowRight),
        ),
        KeyEventResult.handled,
      );
      expect(state.expressionControlActiveForTest, isTrue);
      expect(state.cursorForTest, 2);
      // Druhá už hýbe.
      expect(
        state.handleKeyEventForTest(
          keyDown(PhysicalKeyboardKey.arrowRight, LogicalKeyboardKey.arrowRight),
        ),
        KeyEventResult.handled,
      );
      expect(state.cursorForTest, 3);
    });

    testWidgets('4. počáteční requestFocus režim aktivuje', (tester) async {
      final state = await pumpAppRaw(tester);
      final FocusNode main = state.mainFocusNodeForTest as FocusNode;
      // _initAppVersion provedl bezpodmínečný requestFocus (F3 auditu).
      expect(FocusManager.instance.primaryFocus, main);
      // Listener jej předčasně nevypnul (při rovnosti nic neshazuje).
      expect(state.expressionControlActiveForTest, isTrue);
    });

    testWidgets('5. aktivace displeje zapne a callback nezruší',
        (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();
      state.setExpressionControlActiveForTest(false);
      await tester.pumpAndSettle();

      // Aktivace displeje = produkční onTap vnějšího GestureDetectoru.
      // Volá se přímo jeho closure (pointer-tap v tomto scrollovatelném
      // layoutu v testech nespolehlivě prochází gestickou arénou; doručení
      // dotyku se ověřuje manuálně na zařízení).
      final displayTap = find.byWidgetPredicate(
        (w) => w is GestureDetector && w.onDoubleTap != null,
      );
      expect(displayTap, findsOneWidget);
      tester.widget<GestureDetector>(displayTap).onTap!();
      await tester.pumpAndSettle();
      final FocusNode main = state.mainFocusNodeForTest as FocusNode;
      expect(main.hasPrimaryFocus, isTrue);
      expect(state.expressionControlActiveForTest, isTrue);

      // Doplňkový AT signál je navázán na existující uzel (bez nového obalu).
      final sem = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.label == 'Displej' ||
                  w.properties.label == 'Display'),
        ),
      );
      expect(sem.properties.onDidLoseAccessibilityFocus, isNotNull);
      // Jeho vyvolání režim vypne, kurzor/selection/fokus nemění.
      sem.properties.onDidLoseAccessibilityFocus!();
      await tester.pumpAndSettle();
      expect(state.expressionControlActiveForTest, isFalse);
      expect(state.cursorForTest, 2);
      expect(main.hasPrimaryFocus, isTrue);
    });

    testWidgets('6. dialog vypne, návrat fokusu nezapne', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();
      expect(state.expressionControlActiveForTest, isTrue);

      state.showQuickMemoryDialogForTest();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsWidgets);
      expect(state.expressionControlActiveForTest, isFalse);

      Navigator.of(state.contextForTest as BuildContext).pop();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      final FocusNode main = state.mainFocusNodeForTest as FocusNode;
      expect(main.hasFocus, isTrue);
      // Režim se samotným návratem neaktivoval…
      expect(state.expressionControlActiveForTest, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      // …první šipka armuje bez pohybu kurzoru.
      expect(state.cursorForTest, 2);
      expect(state.expressionControlActiveForTest, isTrue);
      // Druhá už hýbe.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(state.cursorForTest, 1);
    });

    testWidgets('7. KeyRepeatEvent/KeyUpEvent kurzor nehýbou',
        (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();

      const repeat = KeyRepeatEvent(
        physicalKey: PhysicalKeyboardKey.arrowLeft,
        logicalKey: LogicalKeyboardKey.arrowLeft,
        timeStamp: Duration.zero,
      );
      expect(
        state.handleKeyEventForTest(repeat),
        KeyEventResult.ignored,
      );
      const up = KeyUpEvent(
        physicalKey: PhysicalKeyboardKey.arrowLeft,
        logicalKey: LogicalKeyboardKey.arrowLeft,
        timeStamp: Duration.zero,
      );
      expect(state.handleKeyEventForTest(up), KeyEventResult.ignored);
      expect(state.cursorForTest, 2);
    });

    testWidgets('8. SR-passthrough, Tab, Delete, Escape, Enter', (tester) async {
      final state = await pumpApp(tester);
      state.updateActiveSettingsForTest(
        (s) => s.copyWith(screenReaderMode: ScreenReaderMode.on),
      );
      await tester.pumpAndSettle();
      expect(state.isScreenReaderActiveForTest, isTrue);
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();

      // Jednoznakové písmeno patří čtečce (ignored, výraz beze změny).
      expect(
        state.handleKeyEventForTest(
          keyDown(
            PhysicalKeyboardKey.keyS,
            LogicalKeyboardKey.keyS,
            character: 's',
          ),
        ),
        KeyEventResult.ignored,
      );
      expect(state.displayForTest, '12+3');
      expect(state.cursorForTest, 2);

      // Číslice se při SR stále zpracuje (akce proběhne, propagace zůstává
      // jako dříve — kořen nekonzumuje, aby neblokoval potomky).
      expect(
        state.handleKeyEventForTest(
          keyDown(
            PhysicalKeyboardKey.digit5,
            LogicalKeyboardKey.digit5,
            character: '5',
          ),
        ),
        KeyEventResult.ignored,
      );

      // Prostý Tab (bez Ctrl) nepatří aplikaci — traversál zůstává.
      expect(
        state.handleKeyEventForTest(
          keyDown(PhysicalKeyboardKey.tab, LogicalKeyboardKey.tab),
        ),
        KeyEventResult.ignored,
      );

      // Delete = clear(), Escape = clear(), Enter = výpočet. Akce proběhnou,
      // propagace zůstává jako dříve (ignored — fokusovaný potomek, např.
      // fraction toggle, si ponechává svůj aktivační intent).
      expect(
        state.handleKeyEventForTest(
          keyDown(PhysicalKeyboardKey.delete, LogicalKeyboardKey.delete),
        ),
        KeyEventResult.ignored,
      );
      expect(state.displayForTest, '');
      state.setDisplayForTest('12+3', 4);
      await tester.pumpAndSettle();
      expect(
        state.handleKeyEventForTest(
          keyDown(PhysicalKeyboardKey.escape, LogicalKeyboardKey.escape),
        ),
        KeyEventResult.ignored,
      );
      expect(state.displayForTest, '');
      state.setDisplayForTest('12+3', 4);
      await tester.pumpAndSettle();
      expect(
        state.handleKeyEventForTest(
          keyDown(PhysicalKeyboardKey.enter, LogicalKeyboardKey.enter),
        ),
        KeyEventResult.ignored,
      );
      expect(state.displayForTest, isEmpty);

      // Backspace maže před kurzorem (akce proběhne, propagace ignored).
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();
      expect(
        state.handleKeyEventForTest(
          keyDown(PhysicalKeyboardKey.backspace, LogicalKeyboardKey.backspace),
        ),
        KeyEventResult.ignored,
      );
      expect(state.displayForTest, '1+3');
      expect(state.cursorForTest, 1);
    });

    testWidgets('9. právě jedno oznámení, žádná smyčka', (tester) async {
      final state = await pumpApp(tester);
      state.updateActiveSettingsForTest(
        (s) => s.copyWith(screenReaderMode: ScreenReaderMode.on),
      );
      await tester.pumpAndSettle();
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();

      final before = state.lastAnnouncementForTest as String;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      final after = state.lastAnnouncementForTest as String;
      expect(after, isNot(before));
      // Po ustálení už nic dalšího nepřichází (žádná smyčka/duplicita).
      await tester.pump(const Duration(seconds: 1));
      expect(state.lastAnnouncementForTest as String, after);
      expect(state.cursorForTest, 3);

      // Clamp-noop na hranici mlčí.
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      final atEnd = state.lastAnnouncementForTest as String;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(state.cursorForTest, 4);
      expect(state.lastAnnouncementForTest as String, atEnd);
    });

    testWidgets('10. žádná softwarová klávesnice', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();
      final EditableText proxy = tester.widget<EditableText>(
        find.byType(EditableText),
      );
      expect(proxy.readOnly, isTrue);
      expect(proxy.keyboardType, TextInputType.none);
      expect(proxy.autofocus, isFalse);
    });
  });

  group('Z1-dokončení: reaktivace bez myši', () {
    testWidgets('T1. Tab pryč → šipka reaktivuje → další hýbe', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();
      expect(state.expressionControlActiveForTest, isTrue);

      // Odchod Tabem na tlačítko: režim OFF z důvodu traversal.
      final BuildContext ctx = state.contextForTest as BuildContext;
      FocusScope.of(ctx).nextFocus();
      await tester.pumpAndSettle();
      final FocusNode main = state.mainFocusNodeForTest as FocusNode;
      expect(FocusManager.instance.primaryFocus, isNot(main));
      expect(state.expressionControlActiveForTest, isFalse);
      expect(state.expressionControlOffReasonForTest, 'traversal');

      // Návrat primárního fokusu programově (samotný návrat nic nezapíná).
      main.requestFocus();
      await tester.pumpAndSettle();
      expect(main.hasPrimaryFocus, isTrue);
      expect(state.expressionControlActiveForTest, isFalse);

      // První šipka: reaktivace (handled), kurzor stojí, 1 oznámení.
      // V SR-off režimu jde reaktivace vlastním TTS (jednotný kanál).
      final ttsBefore = ttsLog.length;
      expect(
        state.handleKeyEventForTest(
          keyDown(PhysicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowLeft),
        ),
        KeyEventResult.handled,
      );
      expect(state.expressionControlActiveForTest, isTrue);
      expect(state.expressionControlOffReasonForTest, 'none');
      expect(state.cursorForTest, 2);
      await tester.pumpAndSettle();
      expect(ttsLog.length, ttsBefore + 1);
      expect(ttsLog.last, contains('Režim ovládání výrazu'));
      await tester.pump(const Duration(seconds: 1));
      expect(ttsLog.length, ttsBefore + 1);

      // Druhá šipka už skutečně hýbe.
      expect(
        state.handleKeyEventForTest(
          keyDown(PhysicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowLeft),
        ),
        KeyEventResult.handled,
      );
      expect(state.cursorForTest, 1);
    });

    testWidgets('T2. důvod dialog: po zavření armuje až šipka', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();

      state.showQuickMemoryDialogForTest();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsWidgets);
      expect(state.expressionControlActiveForTest, isFalse);
      expect(state.expressionControlOffReasonForTest, 'dialog');
      expect(state.dialogDepthForTest, 1);

      Navigator.of(state.contextForTest as BuildContext).pop();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      final FocusNode main = state.mainFocusNodeForTest as FocusNode;
      expect(main.hasFocus, isTrue);
      expect(state.dialogDepthForTest, 0);
      // Samotný návrat režim nezapnul…
      expect(state.expressionControlActiveForTest, isFalse);
      // …první šipka ano (bez pohybu kurzoru).
      expect(
        state.handleKeyEventForTest(
          keyDown(PhysicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowLeft),
        ),
        KeyEventResult.handled,
      );
      expect(state.expressionControlActiveForTest, isTrue);
      expect(state.expressionControlOffReasonForTest, 'none');
      expect(state.cursorForTest, 2);
      // Druhá už hýbe.
      expect(
        state.handleKeyEventForTest(
          keyDown(PhysicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowLeft),
        ),
        KeyEventResult.handled,
      );
      expect(state.cursorForTest, 1);
    });

    testWidgets('T3. kořen je dosažitelný běžným Tabem', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();
      final FocusNode main = state.mainFocusNodeForTest as FocusNode;

      // Odchod z kořene prvním Tabem.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, isNot(main));
      expect(state.expressionControlActiveForTest, isFalse);
      expect(state.expressionControlOffReasonForTest, 'traversal');

      // Cyklický Tab se musí umět vrátit až na kořen (bez requestFocus).
      var arrived = false;
      for (var i = 0; i < 60; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        if (FocusManager.instance.primaryFocus == main) {
          arrived = true;
          break;
        }
      }
      expect(
        arrived,
        isTrue,
        reason: 'Kořen musí být dosažitelný běžnou Tab navigací',
      );
      // Samotný návrat režim nezapíná — až první šipka (T1).
      expect(state.expressionControlActiveForTest, isFalse);
      expect(state.cursorForTest, 2);
    });

    testWidgets('T4. reaktivace funguje i při aktivní čtečce', (tester) async {
      final state = await pumpApp(tester);
      state.updateActiveSettingsForTest(
        (s) => s.copyWith(screenReaderMode: ScreenReaderMode.on),
      );
      await tester.pumpAndSettle();
      expect(state.isScreenReaderActiveForTest, isTrue);
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();

      final BuildContext ctx = state.contextForTest as BuildContext;
      FocusScope.of(ctx).nextFocus();
      await tester.pumpAndSettle();
      expect(state.expressionControlActiveForTest, isFalse);
      (state.mainFocusNodeForTest as FocusNode).requestFocus();
      await tester.pumpAndSettle();

      // Reaktivace projde Semantics kanálem (SR ON), právě jednou.
      final before = state.lastAnnouncementForTest as String;
      expect(
        state.handleKeyEventForTest(
          keyDown(PhysicalKeyboardKey.arrowRight, LogicalKeyboardKey.arrowRight),
        ),
        KeyEventResult.handled,
      );
      expect(state.expressionControlActiveForTest, isTrue);
      expect(state.cursorForTest, 2);
      final armed = state.lastAnnouncementForTest as String;
      expect(armed, isNot(before));
      await tester.pump(const Duration(seconds: 1));
      expect(state.lastAnnouncementForTest as String, armed);
    });

    testWidgets('T5. programový návrat fokusu sám nic nezapíná', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();
      state.setExpressionControlActiveForTest(false);
      await tester.pumpAndSettle();
      // Simulace návratu z dialogu: fokus zpět, režim zůstává OFF…
      (state.mainFocusNodeForTest as FocusNode).requestFocus();
      await tester.pumpAndSettle();
      expect(state.expressionControlActiveForTest, isFalse);
      // …až první klávesa Home armuje (bez pohybu).
      expect(
        state.handleKeyEventForTest(
          keyDown(PhysicalKeyboardKey.home, LogicalKeyboardKey.home),
        ),
        KeyEventResult.handled,
      );
      expect(state.expressionControlActiveForTest, isTrue);
      expect(state.cursorForTest, 2);
    });

    testWidgets('T6. listener reaguje na primaryFocus, ne hasFocus',
        (tester) async {
      final state = await pumpApp(tester);
      await tester.pumpAndSettle();
      final FocusNode main = state.mainFocusNodeForTest as FocusNode;
      expect(state.expressionControlActiveForTest, isTrue);

      // Přesun na potomka: předek má stále hasFocus, ale ztratil primary.
      final BuildContext ctx = state.contextForTest as BuildContext;
      FocusScope.of(ctx).nextFocus();
      await tester.pumpAndSettle();
      expect(main.hasFocus, isTrue);
      expect(main.hasPrimaryFocus, isFalse);
      // Právě změna primaryFocus režim vypnula (důkaz reakce listeneru).
      expect(state.expressionControlActiveForTest, isFalse);
      expect(state.expressionControlOffReasonForTest, 'traversal');
    });
  });

  group('Z1-reaktivace-po-dialogu', () {
    testWidgets('D1. otevřený dialog: žádná reaktivace', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();

      state.showQuickMemoryDialogForTest();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsWidgets);
      expect(state.expressionControlActiveForTest, isFalse);
      expect(state.dialogDepthForTest, 1);

      // I kdyby se primární fokus ocitl na kořeni za otevřeným dialogem,
      // klávesa dialog nesmí obejít ani armovat režim za ním.
      (state.mainFocusNodeForTest as FocusNode).requestFocus();
      await tester.pumpAndSettle();
      expect(
        state.handleKeyEventForTest(
          keyDown(PhysicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowLeft),
        ),
        KeyEventResult.ignored,
      );
      expect(state.expressionControlActiveForTest, isFalse);
      expect(state.cursorForTest, 2);
      expect(state.dialogDepthForTest, 1);

      Navigator.of(state.contextForTest as BuildContext).pop();
      await tester.pumpAndSettle();
    });

    testWidgets('D2. po zavření: 1. šipka armuje, 2. hýbe', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();

      state.showQuickMemoryDialogForTest();
      await tester.pumpAndSettle();
      Navigator.of(state.contextForTest as BuildContext).pop();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.dialogDepthForTest, 0);
      expect(FocusManager.instance.primaryFocus,
          state.mainFocusNodeForTest as FocusNode);
      expect(state.expressionControlActiveForTest, isFalse);

      // První šipka: handled + oznámení právě jednou, kurzor stojí.
      final ttsBefore = ttsLog.length;
      expect(
        state.handleKeyEventForTest(
          keyDown(PhysicalKeyboardKey.arrowRight, LogicalKeyboardKey.arrowRight),
        ),
        KeyEventResult.handled,
      );
      expect(state.expressionControlActiveForTest, isTrue);
      expect(state.cursorForTest, 2);
      await tester.pumpAndSettle();
      expect(ttsLog.length, ttsBefore + 1);
      expect(ttsLog.last, contains('Režim ovládání výrazu'));
      await tester.pump(const Duration(seconds: 1));
      expect(ttsLog.length, ttsBefore + 1);

      // Druhá šipka: přesně jeden krok.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(state.cursorForTest, 3);
    });

    testWidgets('D3. stejné pravidlo pro Home a End', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();

      state.showQuickMemoryDialogForTest();
      await tester.pumpAndSettle();
      Navigator.of(state.contextForTest as BuildContext).pop();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.expressionControlActiveForTest, isFalse);

      // Home armuje bez pohybu…
      expect(
        state.handleKeyEventForTest(
          keyDown(PhysicalKeyboardKey.home, LogicalKeyboardKey.home),
        ),
        KeyEventResult.handled,
      );
      expect(state.expressionControlActiveForTest, isTrue);
      expect(state.cursorForTest, 2);
      // …další Home skočí na začátek.
      expect(
        state.handleKeyEventForTest(
          keyDown(PhysicalKeyboardKey.home, LogicalKeyboardKey.home),
        ),
        KeyEventResult.handled,
      );
      expect(state.cursorForTest, 0);

      // End po novém vypnutí: opět nejdřív arm bez pohybu.
      state.setExpressionControlActiveForTest(false);
      await tester.pumpAndSettle();
      expect(
        state.handleKeyEventForTest(
          keyDown(PhysicalKeyboardKey.end, LogicalKeyboardKey.end),
        ),
        KeyEventResult.handled,
      );
      expect(state.expressionControlActiveForTest, isTrue);
      expect(state.cursorForTest, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(state.cursorForTest, 4);
    });

    testWidgets('D4. vnořené dialogy: až po zavření všech', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();
      // Nenulová paměť, aby vymazání otevřelo potvrzovací dialog.
      state.setMemoryForTest('A', 5.0);
      await tester.pumpAndSettle();

      // Vnější dialog Paměť…
      state.showQuickMemoryDialogForTest();
      await tester.pumpAndSettle();
      expect(state.dialogDepthForTest, 1);
      // …a přes něj potvrzovací dialog vymazání paměti.
      await tester.tap(find.text('Vymazat paměť'));
      await tester.pumpAndSettle();
      expect(state.dialogDepthForTest, 2);
      expect(state.expressionControlActiveForTest, isFalse);

      // Zavření jen vnořeného: stále blokováno (i s primárním fokusem).
      Navigator.of(state.contextForTest as BuildContext).pop();
      await tester.pumpAndSettle();
      expect(state.dialogDepthForTest, 1);
      (state.mainFocusNodeForTest as FocusNode).requestFocus();
      await tester.pumpAndSettle();
      expect(
        state.handleKeyEventForTest(
          keyDown(PhysicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowLeft),
        ),
        KeyEventResult.ignored,
      );
      expect(state.expressionControlActiveForTest, isFalse);
      expect(state.cursorForTest, 2);

      // Zavření i vnějšího + obnova fokusu: reaktivace možná.
      Navigator.of(state.contextForTest as BuildContext).pop();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.dialogDepthForTest, 0);
      expect(
        state.handleKeyEventForTest(
          keyDown(PhysicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowLeft),
        ),
        KeyEventResult.handled,
      );
      expect(state.expressionControlActiveForTest, isTrue);
      expect(state.cursorForTest, 2);
    });
  });
}
