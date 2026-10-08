import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Navigace kurzoru ve výrazu kalkulačky.
///
/// Jediný zdroj pravdy je `_cursorPosition` (test hook `cursorForTest`).
/// Displej s neprázdným výrazem je vystaven jako read-only textové pole
/// (`textField: true`, `readOnly: true`, `value == display`) s kurzorovými
/// akcemi `onMoveCursorForward/BackwardByCharacter` a `onSetSelection`.
/// Kurzorové cesty negenerují vlastní TTS/announce hlášky.
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

  Future<dynamic> pumpApp(
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
    final state = tester.state(find.byType(CalculatorScreen)) as dynamic;
    // Klávesové testy potřebují fokus na _mainFocusNode (KeyboardListener).
    final keys = tester.widget<KeyboardListener>(
      find.byType(KeyboardListener).first,
    );
    keys.focusNode.requestFocus();
    await tester.pumpAndSettle();
    return state;
  }

  /// Skutečný SemanticsNode displeje včetně publikované selection.
  SemanticsNode displaySemantics(WidgetTester tester) {
    final finder = find.byKey(const ValueKey('expression_semantics_bridge'));
    expect(finder, findsOneWidget, reason: 'Displej node musí existovat');
    return tester.getSemantics(finder);
  }

  void performSemanticsAction(
    WidgetTester tester,
    SemanticsNode node,
    SemanticsAction action, [
    Object? args,
  ]) {
    tester.binding.pipelineOwner.semanticsOwner!.performAction(
      node.id,
      action,
      args,
    );
  }

  group('Kurzor ve výrazu', () {
    testWidgets('1. kurzor na zacatku', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12+3', 0);
      await tester.pumpAndSettle();

      expect(state.cursorForTest, 0);
      final sem = displaySemantics(tester);
      expect(sem.value, '12+3');
      expect(sem.textSelection, const TextSelection.collapsed(offset: 0));
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('2. kurzor na konci', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12+3', 4);
      await tester.pumpAndSettle();

      expect(state.cursorForTest, 4);
      expect(state.cursorForTest, state.displayForTest.length);
      final sem = displaySemantics(tester);
      expect(sem.value, '12+3');
      expect(sem.textSelection, const TextSelection.collapsed(offset: 4));
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('3. Left vcetne clamp na 0', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12+3', 3);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(state.cursorForTest, 2);
      expect(state.displayForTest, '12+3');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(state.cursorForTest, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(state.cursorForTest, 0);
      expect(state.displayForTest, '12+3');
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('4. Right vcetne clamp na konec', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12+3', 0);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(state.cursorForTest, 2);

      for (var i = 0; i < 10; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
      }
      expect(state.cursorForTest, 4);
      expect(state.displayForTest, '12+3');
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('5. Home nemeni display', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(state.cursorForTest, 0);
      expect(state.displayForTest, '12+3');
      expect(
        displaySemantics(tester).textSelection,
        const TextSelection.collapsed(offset: 0),
      );
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('6. End nemeni display', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12+3', 1);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(state.cursorForTest, state.displayForTest.length);
      expect(state.displayForTest, '12+3');
      expect(
        displaySemantics(tester).textSelection,
        const TextSelection.collapsed(offset: 4),
      );
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('7. vlozeni znaku uprostred vyrazu', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('13', 1);
      await tester.pumpAndSettle();

      await state.handleButtonPressedForTest('2');
      await tester.pumpAndSettle();
      expect(state.displayForTest, '123');
      expect(state.cursorForTest, 2);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('8. Backspace uprostred', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('123', 2);
      await tester.pumpAndSettle();

      state.backspaceForTest();
      await tester.pumpAndSettle();
      expect(state.displayForTest, '13');
      expect(state.cursorForTest, 1);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('9. dlouhy vyraz a autoscroll bez vyjimky', (tester) async {
      final state = await pumpApp(tester);
      const long = '1234567890+1234567890+1234567890+1234567890';
      state.setDisplayForTest(long, long.length);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(state.cursorForTest, 0);
      expect(tester.takeException(), isNull);

      state.setDisplayForTest(long, long.length ~/ 2);
      await tester.pumpAndSettle();
      expect(state.cursorForTest, long.length ~/ 2);
      expect(tester.takeException(), isNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(state.cursorForTest, long.length);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('10. zmena vyrazu pri aktivnim screen readeru', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      state.updateActiveSettingsForTest(
        (s) => s.copyWith(screenReaderMode: ScreenReaderMode.on),
      );
      await tester.pumpAndSettle();
      expect(state.isScreenReaderActiveForTest, isTrue);

      ttsLog.clear();
      final before = state.lastAnnouncementForTest as String;
      state.setDisplayForTest('12', 2);
      await tester.pumpAndSettle();
      await state.handleButtonPressedForTest('3');
      await tester.pumpAndSettle();

      expect(state.displayForTest, '123');
      expect(state.cursorForTest, 3);
      final sem = displaySemantics(tester);
      expect(sem.value, '123');
      expect(sem.textSelection, const TextSelection.collapsed(offset: 3));
      // Kurzorové/editační cesty nepřidávají vlastní TTS ani publish hlášku.
      expect(ttsLog, isEmpty);
      expect(state.lastAnnouncementForTest as String, before);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('11. Semantics cursor actions', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();

      var sem = displaySemantics(tester);
      final data = sem.getSemanticsData();
      expect(data.hasFlag(SemanticsFlag.isTextField), isTrue);
      expect(data.hasFlag(SemanticsFlag.isReadOnly), isTrue);
      expect(sem.value, '12+3');
      expect(sem.textSelection, const TextSelection.collapsed(offset: 2));
      final childMergeStates = <bool>[];
      sem.visitChildren((child) {
        childMergeStates.add(child.isMergedIntoParent);
        return true;
      });
      expect(
        childMergeStates,
        everyElement(isTrue),
        reason: 'Vizuální potomci nesmí být dalšími logickými prvky displeje',
      );
      expect(
        data.hasAction(SemanticsAction.moveCursorForwardByCharacter),
        isTrue,
        reason: 'move forward by character musí existovat',
      );
      expect(
        data.hasAction(SemanticsAction.moveCursorBackwardByCharacter),
        isTrue,
        reason: 'move backward by character musí existovat',
      );
      expect(
        data.hasAction(SemanticsAction.setSelection),
        isTrue,
        reason: 'set selection musí existovat',
      );

      performSemanticsAction(
        tester,
        sem,
        SemanticsAction.moveCursorForwardByCharacter,
        false,
      );
      await tester.pumpAndSettle();
      expect(state.cursorForTest, 3);
      expect(
        displaySemantics(tester).textSelection,
        const TextSelection.collapsed(offset: 3),
      );

      sem = displaySemantics(tester);
      performSemanticsAction(
        tester,
        sem,
        SemanticsAction.moveCursorBackwardByCharacter,
        false,
      );
      await tester.pumpAndSettle();
      expect(state.cursorForTest, 2);

      sem = displaySemantics(tester);
      performSemanticsAction(
        tester,
        sem,
        SemanticsAction.setSelection,
        <String, int>{'base': 0, 'extent': 0},
      );
      await tester.pumpAndSettle();
      expect(state.cursorForTest, 0);

      sem = displaySemantics(tester);
      performSemanticsAction(
        tester,
        sem,
        SemanticsAction.setSelection,
        <String, int>{'base': 4, 'extent': 4},
      );
      await tester.pumpAndSettle();
      expect(state.cursorForTest, 4);
      expect(state.displayForTest, '12+3');
      expect(
        displaySemantics(tester).textSelection,
        const TextSelection.collapsed(offset: 4),
      );
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('123+456 publikuje selection při celé navigaci', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('123+456', 0);
      await tester.pumpAndSettle();

      void expectCursor(int offset) {
        expect(state.cursorForTest, offset);
        expect(
          displaySemantics(tester).textSelection,
          TextSelection.collapsed(offset: offset),
        );
        expect(displaySemantics(tester).value, '123+456');
      }

      expectCursor(0);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expectCursor(1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expectCursor(2);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expectCursor(1);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expectCursor(0);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expectCursor(0);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expectCursor(7);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expectCursor(7);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('12. focus zustava a dialog ho vrati', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();

      final keys = tester.widget<KeyboardListener>(
        find.byType(KeyboardListener).first,
      );
      expect(keys.focusNode.hasFocus, isTrue);

      state.showHistoryDialogForTest();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsWidgets);

      Navigator.of(state.contextForTest as BuildContext).pop();
      await tester.pumpAndSettle();
      // Focus restore observer vrací focus openeru se zpožděním 150 ms.
      await tester.pump(const Duration(milliseconds: 300));
      expect(keys.focusNode.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(state.cursorForTest, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(state.cursorForTest, 4);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('13. selection sleduje vsechny zmeny autoritativniho stavu', (
      tester,
    ) async {
      final state = await pumpApp(tester);

      void expectSelection(int offset, String expectedDisplay) {
        final sem = displaySemantics(tester);
        expect(sem.value, expectedDisplay);
        expect(sem.textSelection, TextSelection.collapsed(offset: offset));
      }

      state.setDisplayForTest('123+456', 3);
      await tester.pumpAndSettle();
      expectSelection(3, '123+456');

      await state.handleButtonPressedForTest('9');
      await tester.pumpAndSettle();
      expectSelection(4, '1239+456');

      state.backspaceForTest();
      await tester.pumpAndSettle();
      expectSelection(3, '123+456');

      state.setDisplayForTest('123+456', 3);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(state.displayForTest, isEmpty);
      expectSelection(0, '');

      state.setDisplayForTest('98', 1);
      await tester.pumpAndSettle();
      state.clearForTest();
      await tester.pumpAndSettle();
      expectSelection(0, '');

      state.setDisplayForTest('12', 1);
      await tester.pumpAndSettle();
      state.switchModeForTest(CalculatorMode.basic);
      await tester.pumpAndSettle();
      expectSelection(0, '');
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('prazdny displej publikuje collapsed selection', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('', 0);
      await tester.pumpAndSettle();

      final sem = displaySemantics(tester);
      final data = sem.getSemanticsData();
      expect(data.hasFlag(SemanticsFlag.isTextField), isTrue);
      expect(sem.value, isEmpty);
      expect(sem.textSelection, const TextSelection.collapsed(offset: 0));
      expect(data.hasAction(SemanticsAction.setSelection), isFalse);
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
