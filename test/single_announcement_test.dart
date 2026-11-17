import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _historyAnnouncementKey = ValueKey<String>(
  'history_announcement_live_region',
);

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
    await state.updateGlobalSettingsForTest(
      (GlobalSettings s) => s.copyWith(screenReaderMode: mode),
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

  Future<void> withHistoryDialog(
    WidgetTester tester,
    dynamic state,
    Future<void> Function() runAssertions,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      state.showHistoryDialogForTest();
      await tester.pumpAndSettle();
      await runAssertions();
    } finally {
      semantics.dispose();
    }
  }

  Future<void> pumpAnnouncement(WidgetTester tester) async {
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);
  }

  List<SemanticsNode> semanticsNodes(WidgetTester tester) {
    // The test binding exposes its active semantics tree through this owner.
    // ignore: deprecated_member_use
    final owner = tester.binding.pipelineOwner.semanticsOwner;
    expect(owner, isNotNull, reason: 'Vyžaduje ensureSemantics()');
    final nodes = <SemanticsNode>[];
    void visit(SemanticsNode node) {
      nodes.add(node);
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(owner!.rootSemanticsNode!);
    return nodes;
  }

  List<SemanticsNode> liveRegionNodes(WidgetTester tester) =>
      semanticsNodes(tester)
          .where((node) => node.getSemanticsData().flagsCollection.isLiveRegion)
          .toList();

  List<SemanticsNode> nodesWithLabel(WidgetTester tester, String label) =>
      semanticsNodes(
        tester,
      ).where((node) => node.getSemanticsData().label == label).toList();

  void expectHistoryAnnouncement(WidgetTester tester, String? expected) {
    final liveRegion = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byKey(_historyAnnouncementKey),
    );
    if (expected == null) {
      expect(liveRegion, findsNothing);
      return;
    }
    expect(liveRegion, findsOneWidget);
    final node = tester.getSemantics(liveRegion);
    expect(node.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
    expect(node.label, expected);
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

  testWidgets('DMS na ciselne strance oznami jednotku prave jednou', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final state = await pumpApp(tester);
      state.switchModeForTest(CalculatorMode.scientific);
      await tester.pumpAndSettle();
      await setReaderMode(tester, state, ScreenReaderMode.on);
      state.setDisplayForTest('36', 2);
      await tester.pump();
      ttsLog.clear();
      final announcementsBefore =
          state.publishedAnnouncementCountForTest as int;
      final dmsButton = find.descendant(
        of: find.byKey(const ValueKey('keypad_grid')),
        matching: find.text('DMS'),
      );

      expect(state.scientificFunctionsPageForTest, isFalse);
      expect(dmsButton, findsOneWidget);
      await tester.tap(dmsButton);
      await tester.pumpAndSettle();

      expect(state.displayForTest, '36°');
      expect(state.scientificFunctionsPageForTest, isFalse);
      expect(
        state.publishedAnnouncementCountForTest as int,
        announcementsBefore + 1,
      );
      expect(
        (state.lastAnnouncementForTest as String).toLowerCase(),
        contains('stupňů'),
      );
      expect(ttsLog, isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
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
      await withHistoryDialog(tester, state, () async {
        expect((state.historyForTest as List).length, 2);

        ttsLog.clear();
        final semBefore = state.publishedAnnouncementCountForTest as int;
        await tester.tap(find.byTooltip('Smazat záznam 2+2'));
        await tester.pumpAndSettle();

        expect(
          (state.historyForTest as List).map((entry) => entry.expression),
          ['3+3'],
        );
        expect(state.publishedAnnouncementCountForTest as int, semBefore + 1);
        const message = 'Záznam 2 plus 2 byl smazán.';
        expect(state.lastAnnouncementForTest, message);
        expectHistoryAnnouncement(tester, message);
        expect(ttsLog, isEmpty);
        expect(find.byType(AlertDialog), findsOneWidget);
        await expectPersistedHistory(const ['3+3|6']);
      });
    });

    testWidgets('ON s vypnutým TTS stále publikuje přes Semantics', (
      tester,
    ) async {
      final state = await pumpApp(tester, history: const ['2+2|4', '3+3|6']);
      await setReaderMode(tester, state, ScreenReaderMode.on);
      await state.updateGlobalSettingsForTest(
        (GlobalSettings s) => s.copyWith(ttsEnabled: false),
      );
      await tester.pumpAndSettle();
      await withHistoryDialog(tester, state, () async {
        ttsLog.clear();
        final semBefore = state.publishedAnnouncementCountForTest as int;
        await tester.tap(find.byTooltip('Smazat záznam 2+2'));
        await tester.pumpAndSettle();

        expect((state.historyForTest as List).single.expression, '3+3');
        expect(state.publishedAnnouncementCountForTest as int, semBefore + 1);
        const message = 'Záznam 2 plus 2 byl smazán.';
        expect(state.lastAnnouncementForTest, message);
        expectHistoryAnnouncement(tester, message);
        expect(ttsLog, isEmpty);
        await expectPersistedHistory(const ['3+3|6']);
      });
    });

    testWidgets('OFF: běžné smazání používá právě jedno vlastní TTS', (
      tester,
    ) async {
      final state = await pumpApp(tester, history: const ['2+2|4', '3+3|6']);
      await setReaderMode(tester, state, ScreenReaderMode.off);
      await withHistoryDialog(tester, state, () async {
        ttsLog.clear();
        final semBefore = state.publishedAnnouncementCountForTest as int;
        await tester.tap(find.byTooltip('Smazat záznam 2+2'));
        await tester.pumpAndSettle();

        expect((state.historyForTest as List).single.expression, '3+3');
        expect(state.publishedAnnouncementCountForTest as int, semBefore);
        expect(ttsLog, ['Záznam 2 plus 2 byl smazán.']);
        expectHistoryAnnouncement(tester, null);
        await expectPersistedHistory(const ['3+3|6']);
      });
    });

    testWidgets('AUTO s aktivní čtečkou se chová jako ON', (tester) async {
      accessibilityMockResult = true;
      final state = await pumpApp(tester, history: const ['2+2|4', '3+3|6']);
      expect(state.isScreenReaderActiveForTest, isTrue);
      await withHistoryDialog(tester, state, () async {
        ttsLog.clear();
        final semBefore = state.publishedAnnouncementCountForTest as int;
        await tester.tap(find.byTooltip('Smazat záznam 2+2'));
        await tester.pumpAndSettle();

        expect((state.historyForTest as List).single.expression, '3+3');
        expect(state.publishedAnnouncementCountForTest as int, semBefore + 1);
        const message = 'Záznam 2 plus 2 byl smazán.';
        expect(state.lastAnnouncementForTest, message);
        expectHistoryAnnouncement(tester, message);
        expect(ttsLog, isEmpty);
        await expectPersistedHistory(const ['3+3|6']);
      });
    });

    testWidgets('AUTO + UNKNOWN: smazání nevyvolá hlasové oznámení', (
      tester,
    ) async {
      hangDetection = true;
      final state = await pumpApp(tester, history: const ['2+2|4', '3+3|6']);
      expect(state.isScreenReaderActiveForTest, isNull);
      await withHistoryDialog(tester, state, () async {
        ttsLog.clear();
        final semBefore = state.publishedAnnouncementCountForTest as int;
        await tester.tap(find.byTooltip('Smazat záznam 2+2'));
        await tester.pumpAndSettle();

        expect((state.historyForTest as List).single.expression, '3+3');
        expect(state.publishedAnnouncementCountForTest as int, semBefore);
        expect(ttsLog, isEmpty);
        expectHistoryAnnouncement(tester, null);
        await expectPersistedHistory(const ['3+3|6']);
      });
    });

    testWidgets('opakovaná smazání oznámí konkrétní odstraněné výrazy', (
      tester,
    ) async {
      final state = await pumpApp(
        tester,
        history: const ['2+2|4', '3+3|6', '4+4|8'],
      );
      await setReaderMode(tester, state, ScreenReaderMode.on);
      await withHistoryDialog(tester, state, () async {
        for (final expression in ['2+2', '3+3']) {
          ttsLog.clear();
          final semBefore = state.publishedAnnouncementCountForTest as int;
          await tester.tap(find.byTooltip('Smazat záznam $expression'));
          await tester.pumpAndSettle();

          expect(state.publishedAnnouncementCountForTest as int, semBefore + 1);
          final message = expression == '2+2'
              ? 'Záznam 2 plus 2 byl smazán.'
              : 'Záznam 3 plus 3 byl smazán.';
          expect(state.lastAnnouncementForTest, message);
          expectHistoryAnnouncement(tester, message);
          expect(ttsLog, isEmpty);
          expect(
            (state.historyForTest as List).map((entry) => entry.expression),
            expression == '2+2' ? ['3+3', '4+4'] : ['4+4'],
          );
        }
        await expectPersistedHistory(const ['4+4|8']);
      });
    });

    testWidgets('stejná zpráva dvakrát vyprázdní a znovu naplní live region', (
      tester,
    ) async {
      final state = await pumpApp(tester, history: const ['2+2|4']);
      await setReaderMode(tester, state, ScreenReaderMode.on);
      await withHistoryDialog(tester, state, () async {
        const message = 'Záznam 2 plus 2 byl smazán.';
        final semBefore = state.publishedAnnouncementCountForTest as int;
        final nodesBefore = semanticsNodes(tester).length;
        final liveRegionsBefore = liveRegionNodes(tester).length;
        for (var i = 0; i < 2; i++) {
          await state.announceEvent(
            message,
            category: SpeechCategory.actionConfirm,
          );
          await tester.pump(Duration.zero);
          expectHistoryAnnouncement(tester, null);
          await tester.pump(Duration.zero);
          expectHistoryAnnouncement(tester, message);
          expect(nodesWithLabel(tester, message), hasLength(1));
          expect(semanticsNodes(tester), hasLength(nodesBefore + 1));
          expect(liveRegionNodes(tester), hasLength(liveRegionsBefore + 1));
        }

        expect(state.publishedAnnouncementCountForTest as int, semBefore + 2);
        expect(ttsLog, isEmpty);

        await tester.pump(const Duration(seconds: 5));
        expectHistoryAnnouncement(tester, null);
        expect(nodesWithLabel(tester, message), isEmpty);
        expect(semanticsNodes(tester), hasLength(nodesBefore));
        expect(liveRegionNodes(tester), hasLength(liveRegionsBefore));

        await state.announceEvent(
          message,
          category: SpeechCategory.actionConfirm,
        );
        await pumpAnnouncement(tester);
        expectHistoryAnnouncement(tester, message);
        expect(liveRegionNodes(tester), hasLength(liveRegionsBefore + 1));
      });
    });

    testWidgets('zastaralý timer neodstraní novější oznámení', (tester) async {
      final state = await pumpApp(tester, history: const ['2+2|4']);
      await setReaderMode(tester, state, ScreenReaderMode.on);
      await withHistoryDialog(tester, state, () async {
        const first = 'První oznámení';
        const second = 'Druhé oznámení';
        final liveRegionsBefore = liveRegionNodes(tester).length;

        await state.announceEvent(
          first,
          category: SpeechCategory.actionConfirm,
        );
        await pumpAnnouncement(tester);
        expect(nodesWithLabel(tester, first), hasLength(1));

        await tester.pump(const Duration(milliseconds: 4900));
        await state.announceEvent(
          second,
          category: SpeechCategory.actionConfirm,
        );
        await pumpAnnouncement(tester);
        expect(nodesWithLabel(tester, first), isEmpty);
        expect(nodesWithLabel(tester, second), hasLength(1));

        await tester.pump(const Duration(milliseconds: 100));
        expect(nodesWithLabel(tester, second), hasLength(1));
        expect(liveRegionNodes(tester), hasLength(liveRegionsBefore + 1));

        await tester.pump(const Duration(milliseconds: 4900));
        expect(nodesWithLabel(tester, second), isEmpty);
        expect(liveRegionNodes(tester), hasLength(liveRegionsBefore));
      });
    });

    testWidgets('rychlé publikování použije nejnovější callback', (
      tester,
    ) async {
      final state = await pumpApp(tester, history: const ['2+2|4']);
      await setReaderMode(tester, state, ScreenReaderMode.on);
      await withHistoryDialog(tester, state, () async {
        const first = 'Starší oznámení';
        const second = 'Novější oznámení';
        final semBefore = state.publishedAnnouncementCountForTest as int;
        final liveRegionsBefore = liveRegionNodes(tester).length;

        await state.announceEvent(
          first,
          category: SpeechCategory.actionConfirm,
        );
        await state.announceEvent(
          second,
          category: SpeechCategory.actionConfirm,
        );
        await pumpAnnouncement(tester);

        expect(state.publishedAnnouncementCountForTest as int, semBefore + 2);
        expect(nodesWithLabel(tester, first), isEmpty);
        expect(nodesWithLabel(tester, second), hasLength(1));
        expect(liveRegionNodes(tester), hasLength(liveRegionsBefore + 1));
      });
    });

    testWidgets('zavření během čekání bezpečně zneplatní callback', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        final state = await pumpApp(tester, history: const ['2+2|4']);
        await setReaderMode(tester, state, ScreenReaderMode.on);
        state.showHistoryDialogForTest();
        await tester.pumpAndSettle();

        const message = 'Oznámení při zavírání';
        await state.announceEvent(
          message,
          category: SpeechCategory.actionConfirm,
        );
        Navigator.of(state.contextForTest as BuildContext).pop();
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);

        await tester.pump(const Duration(seconds: 5));
        expect(nodesWithLabel(tester, message), isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('dispose kalkulačky zruší globální a vědecký timer', (
      tester,
    ) async {
      enableAndroidAccessibilityEvents();
      final handle = tester.ensureSemantics();
      try {
        final state = await pumpApp(tester);
        state.switchModeForTest(CalculatorMode.scientific);
        await tester.pumpAndSettle();
        await setReaderMode(tester, state, ScreenReaderMode.on);

        state.toggleScientificPageForTest();
        await pumpAnnouncement(tester);
        await state.announceEvent(
          'Oznámení před dispose',
          category: SpeechCategory.actionConfirm,
        );
        await pumpAnnouncement(tester);

        expect(nodesWithLabel(tester, 'Stránka funkcí'), hasLength(1));
        expect(nodesWithLabel(tester, 'Oznámení před dispose'), hasLength(1));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
        await tester.pump(const Duration(seconds: 5));
        expect(tester.takeException(), isNull);
        expect(nodesWithLabel(tester, 'Stránka funkcí'), isEmpty);
        expect(nodesWithLabel(tester, 'Oznámení před dispose'), isEmpty);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('globální live region po expiraci zmizí z celého stromu', (
      tester,
    ) async {
      enableAndroidAccessibilityEvents();
      final handle = tester.ensureSemantics();
      try {
        final state = await pumpApp(tester);
        expect(debugDefaultTargetPlatformOverride, TargetPlatform.android);
        await setReaderMode(tester, state, ScreenReaderMode.on);
        const message = 'Globální přechodné oznámení';
        final nodesBefore = semanticsNodes(tester).length;
        final liveRegionsBefore = liveRegionNodes(tester).length;

        await state.announceEvent(
          message,
          category: SpeechCategory.actionConfirm,
        );
        await pumpAnnouncement(tester);
        expect(nodesWithLabel(tester, message), hasLength(1));
        expect(semanticsNodes(tester), hasLength(nodesBefore + 1));
        expect(liveRegionNodes(tester), hasLength(liveRegionsBefore + 1));
        expect(ttsLog, isEmpty);

        await tester.pump(const Duration(seconds: 5));
        expect(nodesWithLabel(tester, message), isEmpty);
        expect(semanticsNodes(tester), hasLength(nodesBefore));
        expect(liveRegionNodes(tester), hasLength(liveRegionsBefore));
      } finally {
        handle.dispose();
      }
    });

    testWidgets('starší globální oznámení se po dialogu nevrátí', (
      tester,
    ) async {
      enableAndroidAccessibilityEvents();
      final handle = tester.ensureSemantics();
      try {
        final state = await pumpApp(tester, history: const ['2+2|4']);
        await setReaderMode(tester, state, ScreenReaderMode.on);
        const message = 'Předchozí globální oznámení';

        await state.announceEvent(
          message,
          category: SpeechCategory.actionConfirm,
        );
        await pumpAnnouncement(tester);
        expect(nodesWithLabel(tester, message), hasLength(1));

        state.showHistoryDialogForTest();
        await tester.pumpAndSettle();
        await tester.tap(find.text('ZAVŘÍT'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(nodesWithLabel(tester, message), isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('vědecké oznámení po expiraci zmizí z celého stromu', (
      tester,
    ) async {
      enableAndroidAccessibilityEvents();
      final handle = tester.ensureSemantics();
      try {
        final state = await pumpApp(tester);
        state.switchModeForTest(CalculatorMode.scientific);
        await tester.pumpAndSettle();
        await setReaderMode(tester, state, ScreenReaderMode.on);
        ttsLog.clear();

        state.toggleScientificPageForTest();
        await tester.pump(Duration.zero);
        final nodesBefore = semanticsNodes(tester).length;
        final liveRegionsBefore = liveRegionNodes(tester).length;
        await tester.pump(Duration.zero);

        const message = 'Stránka funkcí';
        expect(nodesWithLabel(tester, message), hasLength(1));
        expect(semanticsNodes(tester), hasLength(nodesBefore + 1));
        expect(liveRegionNodes(tester), hasLength(liveRegionsBefore + 1));
        expect(ttsLog, isEmpty);

        await tester.pump(const Duration(seconds: 5));
        expect(nodesWithLabel(tester, message), isEmpty);
        expect(semanticsNodes(tester), hasLength(nodesBefore));
        expect(liveRegionNodes(tester), hasLength(liveRegionsBefore));
      } finally {
        handle.dispose();
      }
    });

    testWidgets(
      'po odstranění fokusovaného tlačítka dialog zůstává ovladatelný',
      (tester) async {
        final state = await pumpApp(tester, history: const ['2+2|4', '3+3|6']);
        await setReaderMode(tester, state, ScreenReaderMode.on);
        await withHistoryDialog(tester, state, () async {
          final closeButton = find.text('ZAVŘÍT');
          final focusScope = FocusScope.of(tester.element(closeButton));
          expect(focusScope.hasFocus, isTrue);

          final deleteButton = find.byWidgetPredicate(
            (widget) =>
                widget is IconButton && widget.tooltip == 'Smazat záznam 2+2',
          );
          bool deleteButtonHasKeyboardFocus() {
            final primaryContext = FocusManager.instance.primaryFocus?.context;
            if (primaryContext is! Element) return false;
            final buttonElement = tester.element(deleteButton);
            var isDescendant = false;
            primaryContext.visitAncestorElements((element) {
              if (identical(element, buttonElement)) {
                isDescendant = true;
                return false;
              }
              return true;
            });
            return isDescendant;
          }

          for (
            var attempt = 0;
            attempt < 12 && !deleteButtonHasKeyboardFocus();
            attempt++
          ) {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pump();
          }
          expect(deleteButtonHasKeyboardFocus(), isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();

          expect(find.byType(AlertDialog), findsOneWidget);
          expect(closeButton, findsOneWidget);
          expect(FocusScope.of(tester.element(closeButton)).hasFocus, isTrue);
          expect(find.byTooltip('Smazat záznam 3+3'), findsOneWidget);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(find.byType(AlertDialog), findsOneWidget);
        });
      },
    );

    testWidgets('zavření dialogu odregistruje jeho live region', (
      tester,
    ) async {
      final state = await pumpApp(tester, history: const ['2+2|4']);
      await setReaderMode(tester, state, ScreenReaderMode.on);
      await withHistoryDialog(tester, state, () async {
        await tester.tap(find.text('ZAVŘÍT'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);

        final semBefore = state.publishedAnnouncementCountForTest as int;
        await state.announceEvent(
          'Oznámení po zavření',
          category: SpeechCategory.actionConfirm,
        );
        await tester.pumpAndSettle();

        expect(state.publishedAnnouncementCountForTest as int, semBefore + 1);
        expect(state.lastAnnouncementForTest, 'Oznámení po zavření');
      });
    });

    testWidgets('smazání posledního záznamu oznámí i prázdnou historii', (
      tester,
    ) async {
      final state = await pumpApp(tester, history: const ['2+2|4']);
      await setReaderMode(tester, state, ScreenReaderMode.on);
      await withHistoryDialog(tester, state, () async {
        ttsLog.clear();
        final semBefore = state.publishedAnnouncementCountForTest as int;
        await tester.tap(find.byTooltip('Smazat záznam 2+2'));
        await tester.pumpAndSettle();

        expect(state.historyForTest, isEmpty);
        expect(find.text('Historie je prázdná.'), findsOneWidget);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(state.publishedAnnouncementCountForTest as int, semBefore + 1);
        const message = 'Záznam 2 plus 2 byl smazán. Historie je nyní prázdná.';
        expect(state.lastAnnouncementForTest, message);
        expectHistoryAnnouncement(tester, message);
        expect(ttsLog, isEmpty);
        final tree = semanticsNodes(tester);
        expect(
          tree.any(
            (node) =>
                node.getSemanticsData().label.contains('Historie je prázdná.'),
          ),
          isTrue,
        );
        final clearButton = tree.singleWhere((node) {
          final data = node.getSemanticsData();
          return data.flagsCollection.isButton == true &&
              data.label.contains('VYMAZAT HISTORII');
        });
        expect(
          clearButton.getSemanticsData().flagsCollection.isEnabled,
          Tristate.isFalse,
        );
        final closeButton = tree.singleWhere((node) {
          final data = node.getSemanticsData();
          return data.flagsCollection.isButton == true &&
              data.label.contains('ZAVŘÍT');
        });
        expect(
          closeButton.getSemanticsData().flagsCollection.isEnabled,
          Tristate.isTrue,
        );
        await expectPersistedHistory(const []);

        await tester.pump(const Duration(seconds: 5));
        expectHistoryAnnouncement(tester, null);
        expect(nodesWithLabel(tester, message), isEmpty);
        final afterExpiration = semanticsNodes(tester);
        expect(
          afterExpiration.any(
            (node) =>
                node.getSemanticsData().label.contains('Historie je prázdná.'),
          ),
          isTrue,
        );
        expect(
          afterExpiration.any((node) {
            final data = node.getSemanticsData();
            return data.flagsCollection.isButton == true &&
                data.label.contains('VYMAZAT HISTORII') &&
                data.flagsCollection.isEnabled == Tristate.isFalse;
          }),
          isTrue,
        );
        expect(
          afterExpiration.any((node) {
            final data = node.getSemanticsData();
            return data.flagsCollection.isButton == true &&
                data.label.contains('ZAVŘÍT') &&
                data.flagsCollection.isEnabled == Tristate.isTrue;
          }),
          isTrue,
        );
      });
    });

    testWidgets('běžné smazání oznamuje výraz anglicky', (tester) async {
      final state = await pumpApp(
        tester,
        locale: const Locale('en'),
        history: const ['2+2|4', '3+3|6'],
      );
      await setReaderMode(tester, state, ScreenReaderMode.on);
      await withHistoryDialog(tester, state, () async {
        ttsLog.clear();
        final semBefore = state.publishedAnnouncementCountForTest as int;
        await tester.tap(find.byTooltip('Delete record 2+2'));
        await tester.pumpAndSettle();

        const message = 'Record 2 plus 2 was deleted.';
        expect(state.publishedAnnouncementCountForTest as int, semBefore + 1);
        expectHistoryAnnouncement(tester, message);
        expect(state.lastAnnouncementForTest, message);
        expect(ttsLog, isEmpty);
        await expectPersistedHistory(const ['3+3|6']);
      });
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
      await withHistoryDialog(tester, state, () async {
        ttsLog.clear();
        final semBefore = state.publishedAnnouncementCountForTest as int;
        await tester.tap(find.byTooltip('Delete record 2+2'));
        await tester.pumpAndSettle();

        expect(state.historyForTest, isEmpty);
        expect(find.text('History is empty.'), findsOneWidget);
        expect(state.publishedAnnouncementCountForTest as int, semBefore + 1);
        const message =
            'Record 2 plus 2 was deleted. The history is now empty.';
        expect(state.lastAnnouncementForTest, message);
        expectHistoryAnnouncement(tester, message);
        expect(ttsLog, isEmpty);
        await expectPersistedHistory(const []);
      });
    });

    testWidgets('hromadné mazání publikuje právě jedno SnackBar oznámení', (
      tester,
    ) async {
      final state = await pumpApp(tester, history: const ['2+2|4', '3+3|6']);
      await setReaderMode(tester, state, ScreenReaderMode.on);
      await withHistoryDialog(tester, state, () async {
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
  });
}
