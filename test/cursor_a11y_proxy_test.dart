import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gated BUILD spike: skrytá `EditableText` proxy vstupního výrazu.
///
/// Ověřuje: jedinou přístupnou reprezentaci displeje, collapsed selection
/// odvozenou z `_cursorPosition`, pohyb po znacích, hranice, vložení/mazání
/// uprostřed, jedno-kanálové oznámení pozice a focus/klávesnicové invarianty.
/// Duplicitu způsobenou samotným TalkBackem tyto testy neprokazují — tu musí
/// potvrdit manuální test na zařízení.
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
    final keys = tester.widget<KeyboardListener>(
      find.byType(KeyboardListener).first,
    );
    keys.focusNode.requestFocus();
    await tester.pumpAndSettle();
    return state;
  }

  Future<dynamic> pumpAppSrOn(WidgetTester tester) async {
    final state = await pumpApp(tester);
    state.updateActiveSettingsForTest(
      (s) => s.copyWith(screenReaderMode: ScreenReaderMode.on),
    );
    await tester.pumpAndSettle();
    expect(state.isScreenReaderActiveForTest, isTrue);
    return state;
  }

  /// Jediný uzel textového pole v celém Semantics stromě.
  SemanticsNode displayFieldNode(WidgetTester tester) {
    final owner = tester.binding.pipelineOwner.semanticsOwner;
    expect(owner, isNotNull, reason: 'Vyžaduje ensureSemantics()');
    final root = owner!.rootSemanticsNode;
    expect(root, isNotNull);
    final fields = <SemanticsNode>[];
    void visit(SemanticsNode node) {
      if (node.getSemanticsData().flagsCollection.isTextField) {
        fields.add(node);
      }
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(root!);
    expect(fields, hasLength(1), reason: 'Právě jedno textové pole displeje');
    return fields.single;
  }

  /// Počet uzlů s příznakem textového pole v celém Semantics stromě.
  int countTextFields(WidgetTester tester) {
    final owner = tester.binding.pipelineOwner.semanticsOwner;
    expect(owner, isNotNull, reason: 'Vyžaduje ensureSemantics()');
    final root = owner!.rootSemanticsNode;
    expect(root, isNotNull);
    var count = 0;
    void visit(SemanticsNode node) {
      if (node.getSemanticsData().flagsCollection.isTextField) {
        count++;
      }
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(root!);
    return count;
  }

  group('A11y proxy displeje', () {
    testWidgets('1. prazdny stav bez pole, editace s prave jednim polem', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        final state = await pumpApp(tester);

        // Prázdný výraz: proxy ve stromě není (stav beze změny — wrapper
        // nese "Prázdno" / řeč výsledku), žádné textové pole.
        state.setDisplayForTest('', 0);
        await tester.pumpAndSettle();
        expect(find.byType(EditableText), findsNothing);
        expect(countTextFields(tester), 0);

        // Při editaci je proxy jediným textovým polem displeje.
        state.setDisplayForTest('12+3', 2);
        await tester.pumpAndSettle();
        expect(find.byType(EditableText), findsOneWidget);
        expect(state.a11yProxyValueForTest.text, '12+3');
        expect(countTextFields(tester), 1);
        await tester.pump(const Duration(seconds: 1));
      } finally {
        handle.dispose();
      }
    });
    testWidgets('2. vychozi collapsed selection na spravnem offsetu', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('123+45', 0);
      await tester.pumpAndSettle();
      expect(
        state.a11yProxyValueForTest.selection,
        const TextSelection.collapsed(offset: 0),
      );
      state.setDisplayForTest('123+45', 6);
      await tester.pumpAndSettle();
      expect(
        state.a11yProxyValueForTest.selection,
        const TextSelection.collapsed(offset: 6),
      );
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('3. pohyb o znak syncuje proxy', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12+3', 1);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(state.cursorForTest, 2);
      expect(state.a11yProxyValueForTest.text, '12+3');
      expect(
        state.a11yProxyValueForTest.selection,
        const TextSelection.collapsed(offset: 2),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(state.cursorForTest, 0);
      expect(
        state.a11yProxyValueForTest.selection,
        const TextSelection.collapsed(offset: 0),
      );
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('4. hranice a neplatne offsety', (tester) async {
      final state = await pumpAppSrOn(tester);
      state.setDisplayForTest('12+3', 0);
      await tester.pumpAndSettle();
      ttsLog.clear();
      final before = state.lastAnnouncementForTest as String;

      // Clamp-noop za hranicí: kurzor beze změny, žádné hlášení.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(state.cursorForTest, 0);
      expect(state.lastAnnouncementForTest as String, before);
      expect(ttsLog, isEmpty);

      state.setDisplayForTest('12+3', 4);
      await tester.pumpAndSettle();
      final beforeEnd = state.lastAnnouncementForTest as String;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(state.cursorForTest, 4);
      expect(state.lastAnnouncementForTest as String, beforeEnd);

      // AT selection mimo rozsah se clampne.
      state.handleA11ySelectionForTest(
        const TextSelection(baseOffset: 99, extentOffset: 99),
      );
      await tester.pumpAndSettle();
      expect(state.cursorForTest, 4);
      state.handleA11ySelectionForTest(
        const TextSelection(baseOffset: 0, extentOffset: 0),
      );
      await tester.pumpAndSettle();
      expect(state.cursorForTest, 0);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('5. vlozeni a mazani uprostred', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12+45', 3);
      await tester.pumpAndSettle();

      await state.handleButtonPressedForTest('3');
      await tester.pumpAndSettle();
      expect(state.displayForTest, '12+345');
      expect(state.cursorForTest, 4);
      expect(state.a11yProxyValueForTest.text, '12+345');
      expect(
        state.a11yProxyValueForTest.selection,
        const TextSelection.collapsed(offset: 4),
      );

      state.backspaceForTest();
      await tester.pumpAndSettle();
      expect(state.displayForTest, '12+45');
      expect(state.cursorForTest, 3);
      expect(state.a11yProxyValueForTest.text, '12+45');
      expect(
        state.a11yProxyValueForTest.selection,
        const TextSelection.collapsed(offset: 3),
      );
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('6. sync po zmene textu i po cistem pohybu', (tester) async {
      final state = await pumpApp(tester);
      // Změna textu (post-frame sync z buildu).
      state.setDisplayForTest('7', 1);
      await tester.pumpAndSettle();
      expect(state.a11yProxyValueForTest.text, '7');
      expect(
        state.a11yProxyValueForTest.selection,
        const TextSelection.collapsed(offset: 1),
      );
      // Čistý pohyb kurzoru (synchronní sync v handleru).
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(state.a11yProxyValueForTest.text, '7');
      expect(
        state.a11yProxyValueForTest.selection,
        const TextSelection.collapsed(offset: 0),
      );
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('8. akce pohybu po znacich v Semantics', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final state = await pumpApp(tester);
        state.setDisplayForTest('12+3', 2);
        await tester.pumpAndSettle();

        expect(find.byType(EditableText), findsOneWidget);
        final data = displayFieldNode(tester).getSemanticsData();
        expect(data.flagsCollection.isTextField, isTrue);
        expect(data.flagsCollection.isReadOnly, isTrue);
        expect(data.attributedValue.string, '12+3');
        expect(
          data.textSelection,
          const TextSelection(baseOffset: 2, extentOffset: 2),
        );
        expect(
          data.hasAction(SemanticsAction.moveCursorForwardByCharacter),
          isTrue,
        );
        expect(
          data.hasAction(SemanticsAction.moveCursorBackwardByCharacter),
          isTrue,
        );
        // Známý device-gate: bez input focusu RenderEditable setSelection
        // nepublikuje (ověřeno v SDK). Hrany řeší pohybové akce + Home/End.
        expect(
          data.hasAction(SemanticsAction.setSelection),
          isFalse,
          reason: 'Unfocused proxy nesmí slibovat setSelection',
        );
        await tester.pump(const Duration(seconds: 1));
      } finally {
        handle.dispose();
      }
    });

    testWidgets('9. prave jedno oznameni pri realnem pohybu', (tester) async {
      final state = await pumpAppSrOn(tester);
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();
      ttsLog.clear();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      // display[3] == '3' → česky "Před číslem 3, pozice 4 z 5".
      expect(
        state.lastAnnouncementForTest as String,
        'Před číslem 3, pozice 4 z 5',
      );
      expect(ttsLog, isEmpty);

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(
        state.lastAnnouncementForTest as String,
        'Začátek výrazu',
      );
      expect(ttsLog, isEmpty);

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(state.lastAnnouncementForTest as String, 'Konec výrazu');
      expect(ttsLog, isEmpty);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('9b. anglicke zneni pozice', (tester) async {
      final state = await pumpAppSrOn(tester);
      tester.platformDispatcher.localeTestValue = const Locale('en');
      await tester.pumpAndSettle();
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        state.lastAnnouncementForTest as String,
        'Before digit 3, position 4 of 5',
      );
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('10. focus node a zadna klavesnice', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();
      final FocusNode proxyFocus = state.a11yProxyFocusNodeForTest as FocusNode;
      expect(proxyFocus.skipTraversal, isTrue);
      expect(proxyFocus.canRequestFocus, isTrue);
      expect(proxyFocus.hasFocus, isFalse);
      // Klávesnicový focus zůstává na hlavním uzlu.
      final keys = tester.widget<KeyboardListener>(
        find.byType(KeyboardListener).first,
      );
      expect(keys.focusNode.hasFocus, isTrue);
      // Proxy je read-only → žádný input connection, žádná klávesnice.
      final EditableText proxy = tester.widget<EditableText>(
        find.byType(EditableText),
      );
      expect(proxy.readOnly, isTrue);
      expect(proxy.showCursor, isFalse);
      expect(proxy.showSelectionHandles, isFalse);
      expect(proxy.enableInteractiveSelection, isTrue);
      expect(proxy.keyboardType, TextInputType.none);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('rozsirena selection se sjednoti na kurzor', (tester) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('12+3', 2);
      await tester.pumpAndSettle();

      state.handleA11ySelectionForTest(
        const TextSelection(baseOffset: 1, extentOffset: 3),
      );
      await tester.pumpAndSettle();
      expect(state.cursorForTest, 3);
      expect(state.displayForTest, '12+3');
      expect(
        state.a11yProxyValueForTest.selection,
        const TextSelection.collapsed(offset: 3),
      );
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
