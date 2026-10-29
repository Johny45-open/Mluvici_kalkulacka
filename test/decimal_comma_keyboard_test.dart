import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Desetinná čárka z fyzické klávesnice (Windows, české rozložení).
///
/// Příčina regrese: `_handleKeyboardInput` měl dvě oddělené cesty pro
/// jednoznakové klávesy. Cesta bez odečítače čárku normalizovala na tečku,
/// cesta S aktivním odečítačem však filtr `^[0-9.+\-*/^%]$` odmítl znak
/// `,` dřív, než se dostal k `_handleButtonPressed` — čárka se při zapnuté
/// čtečce zahodila. Oprava normalizuje `,` -> `.` na začátku handleru,
/// tedy PŘED oběma filtry, a numerickou desetinnou klávesu řeší zálohou
/// podle logické klávesy `numpadDecimal`, když engin znak nepošle.
///
/// Ověřuje:
/// 1. čárka se vloží jako tečka PŘI zapnutém odečítači;
/// 2. čárka se vloží jako tečka i PŘI vypnutém odečítači (regrese obou cest);
/// 3. `numpadDecimal` bez znaku vloží tečku (Android/klávesnice bez WM_CHAR);
/// 4. `numpadDecimal` SE znakem `,` vloží právě JEDNU tečku (bez dvojzpracování);
/// 5. `Ctrl+,` nadále otevírá nastavení přístupnosti, i s aktivním odečítačem;
/// 6. oprava nespolkne cizí znaky — písmena s odečítačem dál propadávají čtečce.
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

  /// Spustí appku a nechá primární fokus na hlavním uzlu (potřeba pro
  /// `_handleKeyboardInput`, který vyžaduje `hasPrimaryFocus` jen u šipek).
  Future<dynamic> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.localeTestValue = const Locale('cs');
    tester.platformDispatcher.textScaleFactorTestValue = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(
      const ScientificCalculatorApp(locale: Locale('cs')),
    );
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(CalculatorScreen)) as dynamic;
    (state.mainFocusNodeForTest as FocusNode).requestFocus();
    await tester.pumpAndSettle();
    return state;
  }

  /// Přepne režim odečítače a ověří, že se nastavení projevilo.
  Future<void> setReader(
    WidgetTester tester,
    dynamic state,
    bool enabled,
  ) async {
    state.updateActiveSettingsForTest(
      (s) => s.copyWith(
        screenReaderMode: enabled ? ScreenReaderMode.on : ScreenReaderMode.off,
      ),
    );
    await tester.pumpAndSettle();
    expect(state.isScreenReaderActiveForTest, enabled);
  }

  /// Sestaví `KeyDownEvent` se znakem (Windows české rozložení vydává
  /// `character: ','` pro desetinnou klávesu).
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

  group('Desetinná čárka z fyzické klávesnice', () {
    testWidgets('1. odečítač ZAPNUTÝ: čárka se vloží jako tečka', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await setReader(tester, state, true);

      state.setDisplayForTest('1', 1);
      await tester.pumpAndSettle();

      // Windows české rozložení: fyzická desetinná klávesa nese znak ','.
      final result = state.handleKeyEventForTest(
        keyDown(
          PhysicalKeyboardKey.comma,
          LogicalKeyboardKey.comma,
          character: ',',
        ),
      );
      await tester.pumpAndSettle();

      // Konzumace se nemění: větev čtečky vrací ignored jako dřív.
      expect(result, KeyEventResult.ignored);
      expect(
        state.displayForTest,
        '1.',
        reason: 'Čárka musí projít jako tečka, ne se zahodit',
      );
      expect(state.displayForTest, isNot(contains(',')));
      expect(state.cursorForTest, 2);
    });

    testWidgets('2. odečítač VYPNUTÝ: čárka se vloží jako tečka (regrese)', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await setReader(tester, state, false);

      state.setDisplayForTest('2', 1);
      await tester.pumpAndSettle();

      final result = state.handleKeyEventForTest(
        keyDown(
          PhysicalKeyboardKey.comma,
          LogicalKeyboardKey.comma,
          character: ',',
        ),
      );
      await tester.pumpAndSettle();

      expect(result, KeyEventResult.ignored);
      expect(state.displayForTest, '2.');
      expect(state.displayForTest, isNot(contains(',')));
      expect(state.cursorForTest, 2);
    });

    testWidgets('3. numpadDecimal BEZ znaku: vloží se tečka (odečítač i bez)', (
      tester,
    ) async {
      final state = await pumpApp(tester);

      // Bez odečítače.
      await setReader(tester, state, false);
      state.setDisplayForTest('3', 1);
      await tester.pumpAndSettle();
      state.handleKeyEventForTest(
        keyDown(
          PhysicalKeyboardKey.numpadDecimal,
          LogicalKeyboardKey.numpadDecimal,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        state.displayForTest,
        '3.',
        reason:
            'Numerická desetinná klávesa bez znaku musí použít logickou klávesu',
      );
      expect(state.cursorForTest, 2);

      // S odečítačem.
      await setReader(tester, state, true);
      state.setDisplayForTest('4', 1);
      await tester.pumpAndSettle();
      state.handleKeyEventForTest(
        keyDown(
          PhysicalKeyboardKey.numpadDecimal,
          LogicalKeyboardKey.numpadDecimal,
        ),
      );
      await tester.pumpAndSettle();
      expect(state.displayForTest, '4.');
      expect(state.cursorForTest, 2);
    });

    testWidgets('4. numpadDecimal SE znakem „,“: právě jedna tečka', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await setReader(tester, state, true);

      state.setDisplayForTest('5', 1);
      await tester.pumpAndSettle();

      // Windows: numpadDecimal přijde se znakem ','. Znak se normalizuje
      // na '.'; fallback podle logické klávesy NESMÍ spustit znovu.
      state.handleKeyEventForTest(
        keyDown(
          PhysicalKeyboardKey.numpadDecimal,
          LogicalKeyboardKey.numpadDecimal,
          character: ',',
        ),
      );
      await tester.pumpAndSettle();

      expect(
        state.displayForTest,
        '5.',
        reason: 'Tentýž stisk nesmí vložit dvě tečky',
      );
      expect(
        '.'.allMatches(state.displayForTest).length,
        1,
        reason: 'Právě jedna desetinná tečka',
      );
    });

    testWidgets('5. Ctrl+, otevře nastavení přístupnosti (i s odečítačem)', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await setReader(tester, state, true);

      // Známý výraz, abych ověřil, že se do něj nic nevložilo.
      state.setDisplayForTest('12', 2);
      await tester.pumpAndSettle();
      expect(state.dialogDepthForTest, 0);

      // Cesta skutečným focus stromem: Ctrl podržen + klávesa čárky.
      // Znak u Ctrl+klávesy engin neposílá, rozhoduje logická klávesa —
      // nesmí se normalizovat na vložení tečky, musí se zachytit zkratka.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.comma);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(
        state.dialogDepthForTest,
        greaterThan(0),
        reason: 'Ctrl+, musí stále otevírat nastavení přístupnosti',
      );
      // Nesmí se zároveň vložit tečka do výrazu.
      expect(
        state.displayForTest,
        '12',
        reason: 'Ctrl+, nesmí vkládat desetinný oddělovač do výrazu',
      );
    });

    testWidgets('6. oprava nespolkne cizí znaky: písmeno odečítači propadne', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await setReader(tester, state, true);

      state.setDisplayForTest('6', 1);
      await tester.pumpAndSettle();

      // Písmeno nemá procházet do výrazu — patří čtečce (ignored, beze změny).
      final result = state.handleKeyEventForTest(
        keyDown(
          PhysicalKeyboardKey.keyS,
          LogicalKeyboardKey.keyS,
          character: 's',
        ),
      );
      await tester.pumpAndSettle();

      expect(result, KeyEventResult.ignored);
      expect(
        state.displayForTest,
        '6',
        reason: 'Písmeno se nesmí vložit do výrazu, patří čtečce',
      );
    });

    testWidgets('7. čárka uprostřed výrazu: kurzor se chová stejně', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await setReader(tester, state, true);

      // Vložení tečky na pozici kurzoru 2 ve výrazu '12'.
      state.setDisplayForTest('12', 2);
      await tester.pumpAndSettle();
      state.handleKeyEventForTest(
        keyDown(
          PhysicalKeyboardKey.comma,
          LogicalKeyboardKey.comma,
          character: ',',
        ),
      );
      await tester.pumpAndSettle();

      expect(state.displayForTest, '12.');
      expect(state.cursorForTest, 3);
    });
  });
}
