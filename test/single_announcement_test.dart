import 'dart:async';

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Z3: jedna událost = nejvýše jedno oznámení stejným sdělením.
//
// Kanály se měří deltou, nikoli konečnou hodnotou:
// - TTS kanál: delta ttsLog (mock zachytí každé tts.speak),
// - Semantics kanál: delta publishedAnnouncementCountForTest (Z3-krok 0).
// lastAnnouncementForTest nese pouze POSLEDNÍ hodnotu, takže samotná
// přítomnost textu není důkazem právě jednoho oznámení.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<String> ttsLog = [];
  const accessibilityEventsChannel = EventChannel(
    'com.example.mluvici_kalkulacka/accessibility_events',
  );

  /// Chování mocku detekce čtečky; null = metoda visí (stav UNKNOWN).
  bool? accessibilityMockResult = false;
  bool hangDetection = false;
  Completer<bool?>? delayedAccessibilityDetection;
  bool accessibilityEventsInitialValue = false;
  MockStreamHandlerEventSink? accessibilityEventSink;
  int accessibilityEventsListenCount = 0;
  int accessibilityEventsCancelCount = 0;

  setUp(() {
    ttsLog.clear();
    accessibilityMockResult = false;
    hangDetection = false;
    delayedAccessibilityDetection = null;
    accessibilityEventsInitialValue = false;
    accessibilityEventSink = null;
    accessibilityEventsListenCount = 0;
    accessibilityEventsCancelCount = 0;
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
          // Nikdy se nedokončí (žádný Timer → žádný pending-timer problém):
          // detekce zůstane ve stavu UNKNOWN.
          await Completer<bool?>().future;
          return null;
        }
        final delayedDetection = delayedAccessibilityDetection;
        if (delayedDetection != null) return delayedDetection.future;
        return accessibilityMockResult;
      },
    );
    messenger.setMockStreamHandler(
      accessibilityEventsChannel,
      MockStreamHandler.inline(
        onListen: (_, events) {
          accessibilityEventsListenCount++;
          accessibilityEventSink = events;
          events.success(accessibilityEventsInitialValue);
        },
        onCancel: (_) {
          accessibilityEventsCancelCount++;
          accessibilityEventSink = null;
        },
      ),
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
    List<String> history = const [],
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'modeQuestionAsked': true,
      'history': history,
      'currencyLastUpdate': DateTime.now().toIso8601String(),
    });
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.localeTestValue = locale;
    tester.platformDispatcher.textScaleFactorTestValue = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(ScientificCalculatorApp(locale: locale));
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(CalculatorScreen)) as dynamic;
    if (history.isNotEmpty) {
      final expectedExpressions = history
          .map(
            (raw) => CalculationHistoryEntry.fromStorageString(raw).expression,
          )
          .toList();
      final loadedExpressions = (state.historyForTest as List)
          .map((entry) => entry.expression)
          .toList();
      if (loadedExpressions.isEmpty) {
        for (final raw in history.reversed) {
          state.addHistoryEntryForTest(
            CalculationHistoryEntry.fromStorageString(raw),
          );
        }
      } else {
        expect(loadedExpressions, expectedExpressions);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('history', history);
      await tester.pump();
    }
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

  void enableAndroidAccessibilityEvents() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });
  }

  Future<void> emitAccessibilityState(WidgetTester tester, bool enabled) async {
    accessibilityMockResult = enabled;
    final sink = accessibilityEventSink;
    expect(sink, isNotNull);
    sink!.success(enabled);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> openHistoryDialog(WidgetTester tester, dynamic state) async {
    state.showHistoryDialogForTest();
    await tester.pumpAndSettle();
  }

  Future<void> expectPersistedHistory(List<String> expected) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getStringList('history'), expected);
  }

  /// MC bez existující sady v režimu statistiky: potvrzený pár
  /// speak() + _showAccessibleSnackBar() se stejnou zprávou.
  /// Vrací hodnotu čítače Semantics publikování před akcí.
  Future<int> pressMcWithoutSet(WidgetTester tester, dynamic state) async {
    state.switchModeForTest(CalculatorMode.statistics);
    await tester.pumpAndSettle();
    ttsLog.clear();
    final semBefore = state.publishedAnnouncementCountForTest as int;
    await state.handleButtonPressedForTest('MC');
    await tester.pumpAndSettle();
    return semBefore;
  }

  group('Z3-krok 0: infrastruktura měří počet, ne jen hodnotu', () {
    testWidgets('dvojí publikování stejné zprávy = delta čítače 2', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await setReaderMode(tester, state, ScreenReaderMode.on);
      expect(state.isScreenReaderActiveForTest, isTrue);
      final before = state.publishedAnnouncementCountForTest as int;
      await state.announceEvent(
        'Test shody',
        category: SpeechCategory.actionConfirm,
      );
      await state.announceEvent(
        'Test shody',
        category: SpeechCategory.actionConfirm,
      );
      await tester.pumpAndSettle();
      // Stejná zpráva dvakrát: lastAnnouncementForTest by rozdíl neukázal,
      // čítač ano. Tím je citlivost infrastruktury prokázána.
      expect(state.publishedAnnouncementCountForTest as int, before + 2);
      expect(state.lastAnnouncementForTest as String, contains('Test shody'));
      expect(ttsLog, isEmpty);
    });
  });

  group('Z3: MC bez sady = právě jedno oznámení', () {
    testWidgets('OFF: právě jedno TTS, žádné Semantics publikování', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await setReaderMode(tester, state, ScreenReaderMode.off);
      expect(state.isScreenReaderActiveForTest, isFalse);
      final semBefore = await pressMcWithoutSet(tester, state);
      expect(ttsLog, hasLength(1));
      expect(ttsLog.single, contains('Není vytvořena žádná sada'));
      expect(state.publishedAnnouncementCountForTest as int, semBefore);
    });

    testWidgets('ON: právě jedno Semantics, žádné TTS', (tester) async {
      final state = await pumpApp(tester);
      await setReaderMode(tester, state, ScreenReaderMode.on);
      expect(state.isScreenReaderActiveForTest, isTrue);
      final semBefore = await pressMcWithoutSet(tester, state);
      expect(ttsLog, isEmpty);
      expect(state.publishedAnnouncementCountForTest as int, semBefore + 1);
      expect(
        state.lastAnnouncementForTest as String,
        contains('Není vytvořena žádná sada'),
      );
    });

    testWidgets('auto + detekce true: Semantics kanál, bez TTS', (
      tester,
    ) async {
      accessibilityMockResult = true;
      final state = await pumpApp(tester);
      await tester.pumpAndSettle();
      expect(state.isScreenReaderActiveForTest, isTrue);
      final semBefore = await pressMcWithoutSet(tester, state);
      expect(ttsLog, isEmpty);
      expect(state.publishedAnnouncementCountForTest as int, semBefore + 1);
    });

    testWidgets('auto + UNKNOWN: ticho na obou kanálech', (tester) async {
      hangDetection = true;
      final state = await pumpApp(tester);
      await tester.pumpAndSettle();
      // Detekce nedoběhla: UNKNOWN (záměrné R5 ticho, žádný double-speech).
      expect(state.isScreenReaderActiveForTest, isNull);
      final semBefore = await pressMcWithoutSet(tester, state);
      expect(ttsLog, isEmpty);
      expect(state.publishedAnnouncementCountForTest as int, semBefore);
    });
  });

  group('Změny systémového stavu čtečky za běhu', () {
    testWidgets('auto false → true používá právě Semantics', (tester) async {
      enableAndroidAccessibilityEvents();
      accessibilityEventsInitialValue = false;
      accessibilityMockResult = false;
      final state = await pumpApp(tester);
      await setReaderMode(tester, state, ScreenReaderMode.auto);
      expect(accessibilityEventsListenCount, 1);
      expect(state.isScreenReaderActiveForTest, isFalse);

      await emitAccessibilityState(tester, true);
      ttsLog.clear();
      final semBefore = state.publishedAnnouncementCountForTest as int;
      await state.handleButtonPressedForTest('7');
      await tester.pumpAndSettle();

      expect(state.isScreenReaderActiveForTest, isTrue);
      expect(state.publishedAnnouncementCountForTest as int, semBefore + 1);
      expect(state.lastAnnouncementForTest, '7');
      expect(ttsLog, isEmpty);
    });

    testWidgets('auto true → false používá právě vlastní TTS', (tester) async {
      enableAndroidAccessibilityEvents();
      accessibilityEventsInitialValue = true;
      accessibilityMockResult = true;
      final state = await pumpApp(tester);
      await setReaderMode(tester, state, ScreenReaderMode.auto);
      expect(state.isScreenReaderActiveForTest, isTrue);

      await emitAccessibilityState(tester, false);
      ttsLog.clear();
      final semBefore = state.publishedAnnouncementCountForTest as int;
      await state.handleButtonPressedForTest('7');
      await tester.pumpAndSettle();

      expect(state.isScreenReaderActiveForTest, isFalse);
      expect(state.publishedAnnouncementCountForTest as int, semBefore);
      expect(ttsLog, ['7']);
    });

    testWidgets('opakované přepínání mění kanál po každé události', (
      tester,
    ) async {
      enableAndroidAccessibilityEvents();
      accessibilityEventsInitialValue = false;
      accessibilityMockResult = false;
      final state = await pumpApp(tester);
      await setReaderMode(tester, state, ScreenReaderMode.auto);

      for (final enabled in [true, false, true]) {
        await emitAccessibilityState(tester, enabled);
        ttsLog.clear();
        final semBefore = state.publishedAnnouncementCountForTest as int;
        await state.handleButtonPressedForTest('7');
        await tester.pumpAndSettle();

        expect(state.isScreenReaderActiveForTest, enabled);
        if (enabled) {
          expect(state.publishedAnnouncementCountForTest as int, semBefore + 1);
          expect(ttsLog, isEmpty);
        } else {
          expect(state.publishedAnnouncementCountForTest as int, semBefore);
          expect(ttsLog, ['7']);
        }
      }
    });

    testWidgets('vynucené režimy ignorují změnu systémového routování', (
      tester,
    ) async {
      enableAndroidAccessibilityEvents();
      accessibilityEventsInitialValue = false;
      accessibilityMockResult = false;
      final state = await pumpApp(tester);

      await setReaderMode(tester, state, ScreenReaderMode.on);
      await emitAccessibilityState(tester, false);
      final semBeforeOn = state.publishedAnnouncementCountForTest as int;
      ttsLog.clear();
      await state.handleButtonPressedForTest('7');
      await tester.pumpAndSettle();
      expect(state.isScreenReaderActiveForTest, isTrue);
      expect(state.publishedAnnouncementCountForTest as int, semBeforeOn + 1);
      expect(ttsLog, isEmpty);

      await setReaderMode(tester, state, ScreenReaderMode.off);
      await emitAccessibilityState(tester, true);
      final semBeforeOff = state.publishedAnnouncementCountForTest as int;
      ttsLog.clear();
      await state.handleButtonPressedForTest('7');
      await tester.pumpAndSettle();
      expect(state.isScreenReaderActiveForTest, isFalse);
      expect(state.publishedAnnouncementCountForTest as int, semBeforeOff);
      expect(ttsLog, ['7']);
    });

    testWidgets('přechod off → auto znovu načte systémový stav', (
      tester,
    ) async {
      enableAndroidAccessibilityEvents();
      accessibilityEventsInitialValue = false;
      accessibilityMockResult = false;
      final state = await pumpApp(tester);
      await setReaderMode(tester, state, ScreenReaderMode.off);
      expect(state.isScreenReaderActiveForTest, isFalse);

      accessibilityMockResult = true;
      await setReaderMode(tester, state, ScreenReaderMode.auto);
      expect(state.isScreenReaderActiveForTest, isTrue);

      ttsLog.clear();
      final semBefore = state.publishedAnnouncementCountForTest as int;
      await state.handleButtonPressedForTest('7');
      await tester.pumpAndSettle();
      expect(state.publishedAnnouncementCountForTest as int, semBefore + 1);
      expect(ttsLog, isEmpty);
    });

    testWidgets('starší MethodChannel odpověď nepřepíše novější událost', (
      tester,
    ) async {
      enableAndroidAccessibilityEvents();
      accessibilityEventsInitialValue = false;
      accessibilityMockResult = false;
      final state = await pumpApp(tester);
      await setReaderMode(tester, state, ScreenReaderMode.auto);

      final delayedDetection = Completer<bool?>();
      delayedAccessibilityDetection = delayedDetection;
      final staleRefresh =
          state.refreshAccessibilityStateForTest() as Future<void>;
      await tester.pump();

      await emitAccessibilityState(tester, true);
      delayedDetection.complete(false);
      await staleRefresh;
      await tester.pumpAndSettle();

      expect(state.isScreenReaderActiveForTest, isTrue);
    });

    testWidgets('dispose zruší odběr a pozdní event nezpůsobí výjimku', (
      tester,
    ) async {
      enableAndroidAccessibilityEvents();
      accessibilityEventsInitialValue = false;
      final state = await pumpApp(tester);
      expect(accessibilityEventsListenCount, 1);
      final staleSink = accessibilityEventSink!;

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump();

      expect(accessibilityEventsCancelCount, greaterThan(0));
      staleSink.success(true);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(state.mounted, isFalse);
    });
  });

  group('Mazání historie: jedno oznámení a persistovaný stav', () {
    testWidgets('ON: běžné smazání publikuje právě jedno Semantics oznámení', (
      tester,
    ) async {
      final state = await pumpApp(tester, history: const ['2+2|4', '3+3|6']);
      await setReaderMode(tester, state, ScreenReaderMode.on);
      await openHistoryDialog(tester, state);
      expect((state.historyForTest as List).length, 2);

      ttsLog.clear();
      final semBefore = state.publishedAnnouncementCountForTest as int;
      await tester.tap(find.byTooltip('Smazat záznam 2+2'));
      await tester.pumpAndSettle();

      expect((state.historyForTest as List).map((entry) => entry.expression), [
        '3+3',
      ]);
      expect(state.publishedAnnouncementCountForTest as int, semBefore + 1);
      expect(state.lastAnnouncementForTest, 'Záznam smazán.');
      expect(ttsLog, isEmpty);
      expect(find.byType(AlertDialog), findsOneWidget);
      await expectPersistedHistory(const ['3+3|6']);
    });

    testWidgets('ON s vypnutým TTS stále publikuje přes Semantics', (
      tester,
    ) async {
      final state = await pumpApp(tester, history: const ['2+2|4', '3+3|6']);
      await setReaderMode(tester, state, ScreenReaderMode.on);
      state.updateActiveSettingsForTest((s) => s.copyWith(ttsEnabled: false));
      await tester.pumpAndSettle();
      await openHistoryDialog(tester, state);

      ttsLog.clear();
      final semBefore = state.publishedAnnouncementCountForTest as int;
      await tester.tap(find.byTooltip('Smazat záznam 2+2'));
      await tester.pumpAndSettle();

      expect((state.historyForTest as List).single.expression, '3+3');
      expect(state.publishedAnnouncementCountForTest as int, semBefore + 1);
      expect(state.lastAnnouncementForTest, 'Záznam smazán.');
      expect(ttsLog, isEmpty);
      await expectPersistedHistory(const ['3+3|6']);
    });

    testWidgets('OFF: běžné smazání používá právě jedno vlastní TTS', (
      tester,
    ) async {
      final state = await pumpApp(tester, history: const ['2+2|4', '3+3|6']);
      await setReaderMode(tester, state, ScreenReaderMode.off);
      await openHistoryDialog(tester, state);

      ttsLog.clear();
      final semBefore = state.publishedAnnouncementCountForTest as int;
      await tester.tap(find.byTooltip('Smazat záznam 2+2'));
      await tester.pumpAndSettle();

      expect((state.historyForTest as List).single.expression, '3+3');
      expect(state.publishedAnnouncementCountForTest as int, semBefore);
      expect(ttsLog, ['Záznam smazán.']);
      await expectPersistedHistory(const ['3+3|6']);
    });

    testWidgets('AUTO s aktivní čtečkou se chová jako ON', (tester) async {
      accessibilityMockResult = true;
      final state = await pumpApp(tester, history: const ['2+2|4', '3+3|6']);
      expect(state.isScreenReaderActiveForTest, isTrue);
      await openHistoryDialog(tester, state);

      ttsLog.clear();
      final semBefore = state.publishedAnnouncementCountForTest as int;
      await tester.tap(find.byTooltip('Smazat záznam 2+2'));
      await tester.pumpAndSettle();

      expect((state.historyForTest as List).single.expression, '3+3');
      expect(state.publishedAnnouncementCountForTest as int, semBefore + 1);
      expect(state.lastAnnouncementForTest, 'Záznam smazán.');
      expect(ttsLog, isEmpty);
      await expectPersistedHistory(const ['3+3|6']);
    });

    testWidgets('AUTO + UNKNOWN: smazání nevyvolá hlasové oznámení', (
      tester,
    ) async {
      hangDetection = true;
      final state = await pumpApp(tester, history: const ['2+2|4', '3+3|6']);
      expect(state.isScreenReaderActiveForTest, isNull);
      await openHistoryDialog(tester, state);

      ttsLog.clear();
      final semBefore = state.publishedAnnouncementCountForTest as int;
      await tester.tap(find.byTooltip('Smazat záznam 2+2'));
      await tester.pumpAndSettle();

      expect((state.historyForTest as List).single.expression, '3+3');
      expect(state.publishedAnnouncementCountForTest as int, semBefore);
      expect(ttsLog, isEmpty);
      await expectPersistedHistory(const ['3+3|6']);
    });

    testWidgets('opakovaná smazání stejného textu publikují každé zvlášť', (
      tester,
    ) async {
      final state = await pumpApp(
        tester,
        history: const ['2+2|4', '3+3|6', '4+4|8'],
      );
      await setReaderMode(tester, state, ScreenReaderMode.on);
      await openHistoryDialog(tester, state);

      for (final expression in ['2+2', '3+3']) {
        ttsLog.clear();
        final semBefore = state.publishedAnnouncementCountForTest as int;
        await tester.tap(find.byTooltip('Smazat záznam $expression'));
        await tester.pumpAndSettle();

        expect(state.publishedAnnouncementCountForTest as int, semBefore + 1);
        expect(state.lastAnnouncementForTest, 'Záznam smazán.');
        expect(ttsLog, isEmpty);
        expect(
          (state.historyForTest as List).map((entry) => entry.expression),
          expression == '2+2' ? ['3+3', '4+4'] : ['4+4'],
        );
      }
      await expectPersistedHistory(const ['4+4|8']);
    });

    testWidgets('smazání posledního záznamu oznámí i prázdnou historii', (
      tester,
    ) async {
      final state = await pumpApp(tester, history: const ['2+2|4']);
      await setReaderMode(tester, state, ScreenReaderMode.on);
      await openHistoryDialog(tester, state);

      ttsLog.clear();
      final semBefore = state.publishedAnnouncementCountForTest as int;
      await tester.tap(find.byTooltip('Smazat záznam 2+2'));
      await tester.pumpAndSettle();

      expect(state.historyForTest, isEmpty);
      expect(find.text('Historie je prázdná.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(state.publishedAnnouncementCountForTest as int, semBefore + 1);
      expect(
        state.lastAnnouncementForTest,
        'Záznam smazán. Historie je nyní prázdná.',
      );
      expect(ttsLog, isEmpty);
      await expectPersistedHistory(const []);
    });

    testWidgets('last deletion announces the empty history in English', (
      tester,
    ) async {
      final state = await pumpApp(
        tester,
        locale: const Locale('en'),
        history: const ['2+2|4'],
      );
      await setReaderMode(tester, state, ScreenReaderMode.on);
      await openHistoryDialog(tester, state);

      ttsLog.clear();
      final semBefore = state.publishedAnnouncementCountForTest as int;
      await tester.tap(find.byTooltip('Delete record 2+2'));
      await tester.pumpAndSettle();

      expect(state.historyForTest, isEmpty);
      expect(find.text('History is empty.'), findsOneWidget);
      expect(state.publishedAnnouncementCountForTest as int, semBefore + 1);
      expect(
        state.lastAnnouncementForTest,
        'Record deleted. History is now empty.',
      );
      expect(ttsLog, isEmpty);
      await expectPersistedHistory(const []);
    });

    testWidgets('hromadné mazání publikuje právě jedno SnackBar oznámení', (
      tester,
    ) async {
      final state = await pumpApp(tester, history: const ['2+2|4', '3+3|6']);
      await setReaderMode(tester, state, ScreenReaderMode.on);
      await openHistoryDialog(tester, state);

      await tester.tap(find.text('VYMAZAT HISTORII'));
      await tester.pumpAndSettle();
      ttsLog.clear();
      final semBefore = state.publishedAnnouncementCountForTest as int;
      await tester.tap(find.text('ANO, SMAZAT'));
      await tester.pumpAndSettle();

      expect(state.historyForTest, isEmpty);
      expect(state.publishedAnnouncementCountForTest as int, semBefore + 1);
      expect(state.lastAnnouncementForTest, 'Historie smazána');
      expect(ttsLog, isEmpty);
      expect(find.text('Historie smazána'), findsOneWidget);
      await expectPersistedHistory(const []);
    });
  });
}
