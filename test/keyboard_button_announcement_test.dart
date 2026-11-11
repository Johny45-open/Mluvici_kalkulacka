import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Testovací sada pro ověření implementace podle:
/// plans/keyboard_screen_reader_announcement_plan.md
///
/// Spolehlivé oznámení stisknutých tlačítek klávesnice při aktivní čtečce
/// obrazovky (TalkBack / NVDA). Scénáře 1 až 8 (A až H).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<String> ttsLog = [];
  bool? accessibilityMockResult = false;
  bool hangDetection = false;

  setUp(() {
    ttsLog.clear();
    accessibilityMockResult = false;
    hangDetection = false;
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
      (MethodCall call) async {
        if (hangDetection) {
          await Completer<bool?>().future;
          return null;
        }
        return accessibilityMockResult;
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
    (state.mainFocusNodeForTest as FocusNode).requestFocus();
    await tester.pumpAndSettle();
    return state;
  }

  Future<void> setReaderMode(
    WidgetTester tester,
    dynamic state,
    ScreenReaderMode mode,
  ) async {
    state.updateActiveSettingsForTest(
      (s) => s.copyWith(screenReaderMode: mode),
    );
    await tester.pumpAndSettle();
  }

  String displayValue(WidgetTester tester) {
    final fields = find.descendant(
      of: find.byType(CalculatorScreen),
      matching: find.byType(EditableText),
    );
    if (fields.evaluate().isNotEmpty) {
      return tester.widget<EditableText>(fields.first).controller.text;
    }
    final finder = find.descendant(
      of: find.byType(CalculatorScreen),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.label == 'Displej' ||
                w.properties.label == 'Display'),
      ),
    );
    expect(finder, findsOneWidget);
    return tester.widget<Semantics>(finder.first).properties.value ?? '';
  }

  group('Spolehlivé oznámení stisknutých tlačítek (scénáře A-H)', () {
    testWidgets('1. TalkBack ON – stisk číslice 7: Semantics oznámení a nulový ttsLog', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await setReaderMode(tester, state, ScreenReaderMode.on);
      expect(state.isScreenReaderActiveForTest, isTrue);

      final countBefore = state.publishedAnnouncementCountForTest as int;
      ttsLog.clear();

      await state.handleButtonPressedForTest('7');
      await tester.pumpAndSettle();

      expect(ttsLog, isEmpty, reason: 'Při aktivní čtečce nesmí běžet paralelní TTS');
      expect(state.lastAnnouncementForTest as String, '7');
      expect(state.publishedAnnouncementCountForTest as int, countBefore + 1);
      expect(displayValue(tester), '7');
      expect(tester.takeException(), isNull);
    });

    testWidgets('2. TalkBack ON – posloupnost 7, +, 3: každá akce vygeneruje právě jedno Semantics oznámení', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await setReaderMode(tester, state, ScreenReaderMode.on);
      expect(state.isScreenReaderActiveForTest, isTrue);

      ttsLog.clear();
      final countBefore = state.publishedAnnouncementCountForTest as int;

      await state.handleButtonPressedForTest('7');
      await tester.pumpAndSettle();
      expect(ttsLog, isEmpty);
      expect(state.lastAnnouncementForTest as String, '7');
      expect(state.publishedAnnouncementCountForTest as int, countBefore + 1);

      await state.handleButtonPressedForTest('+');
      await tester.pumpAndSettle();
      expect(ttsLog, isEmpty);
      expect(state.lastAnnouncementForTest as String, 'Plus');
      expect(state.publishedAnnouncementCountForTest as int, countBefore + 2);

      await state.handleButtonPressedForTest('3');
      await tester.pumpAndSettle();
      expect(ttsLog, isEmpty);
      expect(state.lastAnnouncementForTest as String, '3');
      expect(state.publishedAnnouncementCountForTest as int, countBefore + 3);

      expect(displayValue(tester), '7+3');
      expect(tester.takeException(), isNull);
    });

    testWidgets('3. TalkBack OFF – stisk 7: právě jedno TTS volání, žádné Semantics publikování pro tlačítko', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await setReaderMode(tester, state, ScreenReaderMode.off);
      expect(state.isScreenReaderActiveForTest, isFalse);

      final semBefore = state.publishedAnnouncementCountForTest as int;
      ttsLog.clear();

      await state.handleButtonPressedForTest('7');
      await tester.pumpAndSettle();

      expect(ttsLog, hasLength(1), reason: 'TTS log: $ttsLog');
      expect(ttsLog.single, '7');
      expect(state.publishedAnnouncementCountForTest as int, semBefore);
      expect(tester.takeException(), isNull);
    });

    testWidgets('4. Auto + detekce true: chování shodné s SR ON', (
      tester,
    ) async {
      accessibilityMockResult = true;
      hangDetection = false;

      final state = await pumpApp(tester);
      await setReaderMode(tester, state, ScreenReaderMode.auto);
      await tester.pumpAndSettle();

      expect(state.isScreenReaderActiveForTest, isTrue);

      final countBefore = state.publishedAnnouncementCountForTest as int;
      ttsLog.clear();

      await state.handleButtonPressedForTest('7');
      await tester.pumpAndSettle();

      expect(ttsLog, isEmpty);
      expect(state.lastAnnouncementForTest as String, '7');
      expect(state.publishedAnnouncementCountForTest as int, countBefore + 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('5. Auto + UNKNOWN: bezpečný režim bez duplicitního hlasu', (
      tester,
    ) async {
      hangDetection = true;
      final state = await pumpApp(tester);
      await setReaderMode(tester, state, ScreenReaderMode.auto);
      await tester.pumpAndSettle();

      expect(state.isScreenReaderActiveForTest, isNull);

      final countBefore = state.publishedAnnouncementCountForTest as int;
      ttsLog.clear();

      await state.handleButtonPressedForTest('7');
      await tester.pumpAndSettle();

      expect(ttsLog, isEmpty, reason: 'V UNKNOWN stavu nesmí běžet TTS');
      expect(state.publishedAnnouncementCountForTest as int, countBefore,
          reason: 'V UNKNOWN stavu se stisk tlačítka nepublikuje přes Semantics');
      expect(tester.takeException(), isNull);
    });

    testWidgets('6. Tlačítka DEL a C: správná a právě jedna hláška odpovídající akci', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await setReaderMode(tester, state, ScreenReaderMode.on);

      state.setDisplayForTest('12', 2);
      await tester.pumpAndSettle();

      ttsLog.clear();
      final countBeforeDel = state.publishedAnnouncementCountForTest as int;

      await state.handleButtonPressedForTest('DEL');
      await tester.pumpAndSettle();

      expect(ttsLog, isEmpty);
      expect(state.lastAnnouncementForTest as String, contains('Smazáno'));
      expect(state.publishedAnnouncementCountForTest as int, countBeforeDel + 1);
      expect(state.displayForTest, '1');

      ttsLog.clear();
      final countBeforeC = state.publishedAnnouncementCountForTest as int;

      await state.handleButtonPressedForTest('C');
      await tester.pumpAndSettle();

      expect(ttsLog, isEmpty);
      expect(state.lastAnnouncementForTest as String, contains('Vymazáno'));
      expect(state.publishedAnnouncementCountForTest as int, countBeforeC + 1);
      expect(state.displayForTest, '');
      expect(tester.takeException(), isNull);
    });

    testWidgets('7. Fyzická klávesnice: silent=true i KeyEvent při TalkBack ON', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await setReaderMode(tester, state, ScreenReaderMode.on);

      // 7a: silent: true nevydá žádné oznámení
      final countBeforeSilent = state.publishedAnnouncementCountForTest as int;
      ttsLog.clear();
      state.append('5', silent: true);
      await tester.pumpAndSettle();

      expect(ttsLog, isEmpty);
      expect(state.publishedAnnouncementCountForTest as int, countBeforeSilent);

      // 7b: fyzická klávesnice přes KeyEvent: propouští se do čtečky (ignored)
      // a používá silent: true, aby nedošlo k dvojímu čtení s odečítačem.
      final countBeforeKey = state.publishedAnnouncementCountForTest as int;
      ttsLog.clear();

      final result = state.handleKeyEventForTest(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.digit7,
          logicalKey: LogicalKeyboardKey.digit7,
          timeStamp: Duration.zero,
          character: '7',
        ),
      );
      await tester.pumpAndSettle();

      expect(result, KeyEventResult.ignored);
      expect(ttsLog, isEmpty);
      expect(state.publishedAnnouncementCountForTest as int, countBeforeKey);
      expect(state.displayForTest, '57');
      expect(tester.takeException(), isNull);
    });

    testWidgets('8. Displej vs. tlačítko: kontrola duplicity hlášek', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await setReaderMode(tester, state, ScreenReaderMode.on);

      ttsLog.clear();
      final countBefore = state.publishedAnnouncementCountForTest as int;

      await state.handleButtonPressedForTest('7');
      await tester.pumpAndSettle();

      // Právě jedno oznámení — změna v EditableText nevytváří druhý liveRegion event
      expect(state.publishedAnnouncementCountForTest as int, countBefore + 1);
      expect(state.displayForTest, '7');
      expect(state.a11yProxyValueForTest.text, '7');
      expect(ttsLog, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}
