import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regresní testy hromadného mazání paměti (A,B,C,D,E,F,X,Y,M):
/// souhrn 9/9, částečné/singulár, prázdná paměť, uložená 0,
/// konzistence CLR vs. dialog, racionální regrese 1/3,
/// persistence obsazenosti + migrace starých dat, cs/en, duplicita.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const memoryVars = ['A', 'B', 'C', 'D', 'E', 'F', 'X', 'Y', 'M'];
  final List<String> ttsLog = [];

  setUp(() {
    ttsLog.clear();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'accessibilityType': 0,
      'modeQuestionAsked': true,
    });

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    final docsDir = Directory.systemTemp.createTempSync('memclear_docs');
    addTearDown(() {
      try {
        docsDir.deleteSync(recursive: true);
      } catch (_) {}
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return docsDir.path;
        }
        return null;
      },
    );
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
    tester.platformDispatcher.clearAllTestValues();
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.localeTestValue = locale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(ScientificCalculatorApp(locale: locale));
    await tester.pumpAndSettle();
    return tester.state(find.byType(CalculatorScreen)) as dynamic;
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

  Finder snackTextContaining(String part) => find.byWidgetPredicate(
    (w) => w is Text && w.data != null && w.data!.contains(part),
  );

  group('Hlášení mazání (cs)', () {
    testWidgets('9/9: krátký souhrn bez vyjmenování', (tester) async {
      final state = await pumpApp(tester);
      await setReaderMode(tester, state, ScreenReaderMode.off);
      for (final v in memoryVars) {
        state.setMemoryForTest(v, 1.0);
      }
      await tester.pump();
      ttsLog.clear();
      await state.handleButtonPressedForTest('CLR');
      await tester.pumpAndSettle();
      for (final v in memoryVars) {
        expect(state.memoryForTest[v], 0.0);
      }
      expect((state.occupiedMemoryForTest as Set), isEmpty);
      expect(snackTextContaining('všech paměťových proměnných'), findsWidgets);
      // Žádný výčet jednotlivých názvů v souhrnné hlášce.
      expect(ttsLog, hasLength(1));
      expect(ttsLog.single, contains('všech paměťových proměnných'));
      expect(ttsLog.single.contains('A, B'), isFalse);
    });

    testWidgets('Částečné A,C,M: vyjmenuje jen smazané', (tester) async {
      final state = await pumpApp(tester);
      await setReaderMode(tester, state, ScreenReaderMode.off);
      state.clearMemoryStateForTest();
      state.setMemoryForTest('A', 10.0);
      state.setMemoryForTest('C', 30.0);
      state.setMemoryForTest('M', 50.0);
      await tester.pump();
      ttsLog.clear();
      await state.handleButtonPressedForTest('CLR');
      await tester.pumpAndSettle();
      expect(state.memoryForTest['A'], 0.0);
      expect(state.memoryForTest['C'], 0.0);
      expect(state.memoryForTest['M'], 0.0);
      expect(ttsLog, hasLength(1));
      expect(ttsLog.single, contains('A'));
      expect(ttsLog.single, contains('C'));
      expect(ttsLog.single, contains('M'));
      expect(ttsLog.single.contains('B'), isFalse);
      expect(ttsLog.single, contains('hodnoty proměnných'));
    });

    testWidgets('Singulár 1 proměnná: správná gramatika', (tester) async {
      final state = await pumpApp(tester);
      await setReaderMode(tester, state, ScreenReaderMode.off);
      state.clearMemoryStateForTest();
      state.setMemoryForTest('A', 5.0);
      await tester.pump();
      ttsLog.clear();
      await state.handleButtonPressedForTest('CLR');
      await tester.pumpAndSettle();
      expect(ttsLog, hasLength(1));
      expect(ttsLog.single, contains('hodnota proměnné A'));
    });

    testWidgets('Prázdná paměť: netvrdí smazání', (tester) async {
      final state = await pumpApp(tester);
      await setReaderMode(tester, state, ScreenReaderMode.off);
      state.clearMemoryStateForTest();
      await tester.pump();
      ttsLog.clear();
      await state.handleButtonPressedForTest('CLR');
      await tester.pumpAndSettle();
      expect(ttsLog, hasLength(1));
      expect(ttsLog.single, contains('již prázdná'));
      expect(ttsLog.single.contains('Smazány byly'), isFalse);
    });

    testWidgets('Dialog ANO dává stejnou hlášku jako CLR', (tester) async {
      final state = await pumpApp(tester);
      await setReaderMode(tester, state, ScreenReaderMode.off);
      state.clearMemoryStateForTest();
      state.setMemoryForTest('A', 10.0);
      state.setMemoryForTest('C', 30.0);
      await tester.pump();
      // Dialogová cesta přes potvrzovací dialog.
      state.showClearMemoryConfirmationForTest();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      ttsLog.clear();
      await tester.tap(find.text('ANO, SMAZAT'));
      await tester.pumpAndSettle();
      expect(state.memoryForTest['A'], 0.0);
      expect(state.memoryForTest['C'], 0.0);
      expect(ttsLog, hasLength(1));
      expect(ttsLog.single, contains('A'));
      expect(ttsLog.single, contains('C'));
      expect(ttsLog.single, contains('hodnoty proměnných'));
    });
  });

  group('Hlášení mazání (en)', () {
    testWidgets('9/9 + partial + empty anglicky', (tester) async {
      final state = await pumpApp(tester, locale: const Locale('en'));
      await setReaderMode(tester, state, ScreenReaderMode.off);
      for (final v in memoryVars) {
        state.setMemoryForTest(v, 1.0);
      }
      await tester.pump();
      ttsLog.clear();
      await state.handleButtonPressedForTest('CLR');
      await tester.pumpAndSettle();
      expect(ttsLog, hasLength(1));
      expect(ttsLog.single, contains('All memory variable values'));

      state.clearMemoryStateForTest();
      state.setMemoryForTest('A', 1.0);
      state.setMemoryForTest('M', 2.0);
      await tester.pump();
      ttsLog.clear();
      await state.handleButtonPressedForTest('CLR');
      await tester.pumpAndSettle();
      expect(ttsLog, hasLength(1));
      expect(ttsLog.single, contains('A'));
      expect(ttsLog.single, contains('M'));

      state.clearMemoryStateForTest();
      await tester.pump();
      ttsLog.clear();
      await state.handleButtonPressedForTest('CLR');
      await tester.pumpAndSettle();
      expect(ttsLog, hasLength(1));
      expect(ttsLog.single, contains('already empty'));
    });
  });

  group('Uložená nula', () {
    testWidgets('STO 0 je obsazená a ohlásí se při mazání', (tester) async {
      final state = await pumpApp(tester);
      await setReaderMode(tester, state, ScreenReaderMode.off);
      state.clearMemoryStateForTest();
      state.setDisplayForTest('0', 1);
      await tester.pump();
      final ok = state.storeCurrentValueToMemory('B') as bool;
      expect(ok, isTrue);
      expect(state.memoryForTest['B'], 0.0);
      expect((state.occupiedMemoryForTest as Set).contains('B'), isTrue);
      ttsLog.clear();
      await state.handleButtonPressedForTest('CLR');
      await tester.pumpAndSettle();
      expect(ttsLog, hasLength(1));
      expect(ttsLog.single, contains('B'));
      expect(ttsLog.single.contains('prázdná'), isFalse);
    });
  });

  group('Racionální regrese 1/3', () {
    testWidgets('Po CLR nelze vyvolat zastaralou 1/3', (tester) async {
      final state = await pumpApp(tester);
      await setReaderMode(tester, state, ScreenReaderMode.off);
      state.clearMemoryStateForTest();
      state.setDisplayForTest('1/3', 3);
      await tester.pump();
      final ok = state.storeCurrentValueToMemory('A') as bool;
      expect(ok, isTrue);
      expect((state.rationalMemoryForTest as Map).containsKey('A'), isTrue);
      await state.handleButtonPressedForTest('CLR');
      await tester.pumpAndSettle();
      expect((state.rationalMemoryForTest as Map), isEmpty);
      expect(state.memoryForTest['A'], 0.0);
      state.setDisplayForTest('', 0);
      await tester.pump();
      state.recallMemoryVariable('A');
      await tester.pump();
      final display = state.displayForTest as String;
      expect(display.contains('1/3'), isFalse);
      expect(display.contains('/3'), isFalse);
    });
  });

  group('Persistence obsazenosti', () {
    testWidgets('P3: běžné uložení zapíše memoryOccupied', (tester) async {
      final state = await pumpApp(tester);
      state.clearMemoryStateForTest();
      state.setDisplayForTest('42', 2);
      await tester.pump();
      state.storeCurrentValueToMemory('A');
      state.setDisplayForTest('0', 1);
      await tester.pump();
      state.storeCurrentValueToMemory('C');
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      final occ = prefs.getStringList('memoryOccupied');
      expect(occ, isNotNull);
      expect(occ, contains('A'));
      expect(occ, contains('C'));
      final raw = prefs.getString('memoryVariables');
      expect(raw, isNotNull);
      expect(raw, contains('"A"'));
    });

    testWidgets('P1: nula přežije obnovení stavu a ohlásí se', (tester) async {
      final state = await pumpApp(tester);
      state.clearMemoryStateForTest();
      state.setDisplayForTest('0', 1);
      await tester.pump();
      expect(state.storeCurrentValueToMemory('B') as bool, isTrue);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      // Simulace restartu: zahodit stav v paměti, znovu načíst z prefs
      // stejným produkčním kódem jako startup.
      state.clearMemoryStateForTest();
      await tester.pump();
      await state.reloadMemoryForTest();
      await tester.pump();
      expect(state.memoryForTest['B'], 0.0);
      expect((state.occupiedMemoryForTest as Set).contains('B'), isTrue);
      await setReaderMode(tester, state, ScreenReaderMode.off);
      ttsLog.clear();
      await state.handleButtonPressedForTest('CLR');
      await tester.pumpAndSettle();
      expect(ttsLog, hasLength(1));
      expect(ttsLog.single, contains('B'));
    });

    testWidgets('P2: stará data bez příznaku — migrace', (tester) async {
      final state = await pumpApp(tester);
      // Starý formát: pouze memoryVariables, žádný memoryOccupied.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('memoryVariables', '{"A":5.0,"B":0.0}');
      await prefs.remove('memoryOccupied');
      state.clearMemoryStateForTest();
      await tester.pump();
      await state.reloadMemoryForTest();
      await tester.pump();
      // Nenulová hodnota zachována + obsazená; historická nula je
      // nerozlišitelná od prázdné (zdokumentované omezení).
      expect(state.memoryForTest['A'], 5.0);
      expect(state.memoryForTest['B'], 0.0);
      expect((state.occupiedMemoryForTest as Set).contains('A'), isTrue);
      expect((state.occupiedMemoryForTest as Set).contains('B'), isFalse);
      await setReaderMode(tester, state, ScreenReaderMode.off);
      ttsLog.clear();
      await state.handleButtonPressedForTest('CLR');
      await tester.pumpAndSettle();
      expect(ttsLog, hasLength(1));
      expect(ttsLog.single, contains('A'));
      // B není hlášena — její historická obsazenost je neobnovitelná.
      expect(ttsLog.single.contains('B='), isFalse);
    });
  });

  group('Neduplicita oznámení', () {
    testWidgets('SR OFF: právě jedno TTS', (tester) async {
      final state = await pumpApp(tester);
      await setReaderMode(tester, state, ScreenReaderMode.off);
      state.clearMemoryStateForTest();
      state.setMemoryForTest('A', 1.0);
      state.setMemoryForTest('C', 2.0);
      await tester.pump();
      ttsLog.clear();
      final semBefore = state.publishedAnnouncementCountForTest as int;
      await state.handleButtonPressedForTest('CLR');
      await tester.pumpAndSettle();
      expect(ttsLog, hasLength(1));
      expect(state.publishedAnnouncementCountForTest as int, semBefore);
    });

    testWidgets('SR ON: právě jedno Semantics, žádné TTS', (tester) async {
      final state = await pumpApp(tester);
      await setReaderMode(tester, state, ScreenReaderMode.on);
      state.clearMemoryStateForTest();
      state.setMemoryForTest('A', 1.0);
      await tester.pump();
      ttsLog.clear();
      final semBefore = state.publishedAnnouncementCountForTest as int;
      await state.handleButtonPressedForTest('CLR');
      await tester.pumpAndSettle();
      expect(ttsLog, isEmpty);
      expect(state.publishedAnnouncementCountForTest as int, semBefore + 1);
      expect(
        state.lastAnnouncementForTest as String,
        contains('hodnota proměnné A'),
      );
    });
  });
}
