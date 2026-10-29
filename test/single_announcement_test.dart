import 'dart:async';

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

  /// Chování mocku detekce čtečky; null = metoda visí (stav UNKNOWN).
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
          // Nikdy se nedokončí (žádný Timer → žádný pending-timer problém):
          // detekce zůstane ve stavu UNKNOWN.
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
}
