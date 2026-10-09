import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Speech contract (R1-R10): jedna významná uživatelská akce
// → právě jedno aplikační accessibility oznámení správným kanálem.
// SR OFF -> vlastní TTS (ttsLog), právě 1 záznam na akci.
// SR ON  -> Semantics kanál (lastAnnouncementForTest), ttsLog prázdný,
//           žádné paralelní vlastní TTS (ani force).
// Netestuje se skutečný TTS engine, pouze generovaný text a kanál.
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
    return tester.state(find.byType(CalculatorScreen)) as dynamic;
  }

  Future<void> setScreenReader(
    WidgetTester tester,
    dynamic state,
    bool on,
  ) async {
    state.updateActiveSettingsForTest(
      (s) => s.copyWith(
        screenReaderMode: on ? ScreenReaderMode.on : ScreenReaderMode.off,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> calculate(
    WidgetTester tester,
    dynamic state,
    String expr,
  ) async {
    state.setDisplayForTest(expr, expr.length);
    await tester.pump();
    ttsLog.clear();
    state.calculateForTest();
    await tester.pumpAndSettle();
  }

  /// Počet nových TTS záznamů vzniklých akcí [action].
  Future<int> countNewTts(
    WidgetTester tester,
    Future<void> Function() action,
  ) async {
    final before = ttsLog.length;
    await action();
    await tester.pumpAndSettle();
    return ttsLog.length - before;
  }

  /// Přístupná hodnota displeje: výraz nese stabilní skrytá proxy
  /// (`EditableText`, přítomná i při prázdném výrazu). Odpovídá
  /// implementaci proxy (stabilní BUILD spike).
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

  group('R1 – jeden stisk = jedno oznámení (SR OFF)', () {
    testWidgets('7 -> právě jedno "7"', (tester) async {
      final state = await pumpApp(tester);
      await setScreenReader(tester, state, false);
      ttsLog.clear();
      final added = await countNewTts(
        tester,
        () => state.handleButtonPressedForTest('7'),
      );
      expect(added, 1, reason: 'TTS log: $ttsLog');
      expect(ttsLog.last, '7');
      expect(tester.takeException(), isNull);
    });

    testWidgets('* -> právě jedno "Krát"', (tester) async {
      final state = await pumpApp(tester);
      await setScreenReader(tester, state, false);
      ttsLog.clear();
      final added = await countNewTts(
        tester,
        () => state.handleButtonPressedForTest('*'),
      );
      expect(added, 1, reason: 'TTS log: $ttsLog');
      expect(ttsLog.last, contains('Krát'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('/ -> právě jedno "Lomeno"', (tester) async {
      final state = await pumpApp(tester);
      await setScreenReader(tester, state, false);
      ttsLog.clear();
      final added = await countNewTts(
        tester,
        () => state.handleButtonPressedForTest('/'),
      );
      expect(added, 1, reason: 'TTS log: $ttsLog');
      expect(ttsLog.last, contains('Lomeno'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('EXP -> právě jedno "krát deset na" (ne písmeno E)', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await setScreenReader(tester, state, false);
      ttsLog.clear();
      final added = await countNewTts(
        tester,
        () => state.handleButtonPressedForTest('EXP'),
      );
      expect(added, 1, reason: 'TTS log: $ttsLog');
      expect(ttsLog.last, contains('krát deset na'));
      expect(tester.takeException(), isNull);
    });
  });

  group('R1/R3 – DEL a C (SR OFF)', () {
    testWidgets('DEL -> právě jedno "Smazáno"', (tester) async {
      final state = await pumpApp(tester);
      await setScreenReader(tester, state, false);
      state.setDisplayForTest('12', 2);
      await tester.pump();
      ttsLog.clear();
      final added = await countNewTts(tester, () async {
        state.backspaceForTest();
      });
      expect(added, 1, reason: 'TTS log: $ttsLog');
      expect(ttsLog.last, contains('Smazáno'));
      expect(ttsLog.any((t) => t.contains('Smazat poslední')), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('C -> právě jedno "Vymazáno" (ne infinitiv)', (tester) async {
      final state = await pumpApp(tester);
      await setScreenReader(tester, state, false);
      state.setDisplayForTest('12', 2);
      await tester.pump();
      ttsLog.clear();
      final added = await countNewTts(
        tester,
        () => state.handleButtonPressedForTest('C'),
      );
      expect(added, 1, reason: 'TTS log: $ttsLog');
      expect(ttsLog.last, contains('Vymazáno'));
      expect(ttsLog.any((t) => t.contains('Smazat displej')), isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('R2 – výsledek (SR OFF: jedno TTS, SR ON: Semantics)', () {
    testWidgets('2+2= -> právě jedna "Výsledek je 4" (cs)', (tester) async {
      final state = await pumpApp(tester);
      await setScreenReader(tester, state, false);
      await calculate(tester, state, '2+2');
      expect(ttsLog, hasLength(1), reason: 'TTS log: $ttsLog');
      expect(ttsLog.single, contains('Výsledek je 4'));
      expect(ttsLog.single.contains('Rovná se'), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('2+2= (en) -> "The result is 4"', (tester) async {
      final state = await pumpApp(tester, locale: const Locale('en'));
      await setScreenReader(tester, state, false);
      await calculate(tester, state, '2+2');
      expect(ttsLog, hasLength(1), reason: 'TTS log: $ttsLog');
      expect(ttsLog.single, contains('The result is 4'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('2+2= SR ON -> žádné TTS, výsledek Semantics kanálem', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await setScreenReader(tester, state, true);
      await calculate(tester, state, '2+2');
      expect(ttsLog, isEmpty, reason: 'TTS log: $ttsLog');
      expect(
        state.lastAnnouncementForTest as String,
        contains('Výsledek je'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('√(72) -> jedna hláška s odmocninou', (tester) async {
      final state = await pumpApp(tester);
      await setScreenReader(tester, state, false);
      await calculate(tester, state, '√(72)');
      expect(ttsLog, hasLength(1), reason: 'TTS log: $ttsLog');
      expect(ttsLog.single, contains('odmocnina'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('5/0 -> právě jedna "Nulou nelze dělit" + Error', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await setScreenReader(tester, state, false);
      await calculate(tester, state, '5/0');
      // Non-finite výsledek (Infinity/NaN) je chyba, ne výsledek.
      expect(ttsLog, hasLength(1), reason: 'TTS log: $ttsLog');
      expect(ttsLog.single, contains('Nulou nelze dělit'));
      expect(state.lastResultForTest, 'Error');
      // R7: chybový stav čte displej lokalizovaně.
      expect(state.currentResultSpeechForTest(), 'Chyba');
      expect(tester.takeException(), isNull);
    });

    testWidgets('5+ -> právě jedna chyba, stav Error, řeč "Chyba"', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      await setScreenReader(tester, state, false);
      await calculate(tester, state, '5+');
      expect(ttsLog, hasLength(1), reason: 'TTS log: $ttsLog');
      expect(state.lastResultForTest, 'Error');
      // R7: chybový stav čte displej lokalizovaně.
      expect(state.currentResultSpeechForTest(), 'Chyba');
      expect(tester.takeException(), isNull);
    });
  });

  group('R1 – SR ON: žádný duplicitní event, displej oznamuje', () {
    testWidgets('7 SR ON -> žádné TTS, displej obsahuje 7', (tester) async {
      final state = await pumpApp(tester);
      await setScreenReader(tester, state, true);
      ttsLog.clear();
      await state.handleButtonPressedForTest('7');
      await tester.pumpAndSettle();
      expect(ttsLog, isEmpty, reason: 'TTS log: $ttsLog');
      expect(displayValue(tester), contains('7'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('DEL SR ON -> žádné TTS, displej aktualizován', (tester) async {
      final state = await pumpApp(tester);
      await setScreenReader(tester, state, true);
      state.setDisplayForTest('12', 2);
      await tester.pump();
      ttsLog.clear();
      state.backspaceForTest();
      await tester.pumpAndSettle();
      expect(ttsLog, isEmpty, reason: 'TTS log: $ttsLog');
      expect(displayValue(tester), contains('1'));
      expect(tester.takeException(), isNull);
    });
  });

  group('R6 – číselný vs. větný formatter', () {
    testWidgets('exponent E+ s tečkou i čárkou (cs)', (tester) async {
      final state = await pumpApp(tester);
      expect(state.numberToSpeechForTest('1.5E+03'), contains('třetí'));
      expect(state.numberToSpeechForTest('1,5E+03'), contains('třetí'));
      expect(state.numberToSpeechForTest('1,5E-03'), contains('mínus'));
      expect(
        state.numberToSpeechForTest('1.5E+03').contains('E+'),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('exponent (en) -> times ten to, tečka zůstává', (tester) async {
      final state = await pumpApp(tester, locale: const Locale('en'));
      final spoken = state.numberToSpeechForTest('1.5E+03') as String;
      expect(spoken, contains('times ten to'));
      expect(spoken.contains('E+'), isFalse);
      expect(state.numberToSpeechForTest('3,14'), contains('3.14'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('desetinná čárka podle jazyka', (tester) async {
      final state = await pumpApp(tester);
      expect(state.numberToSpeechForTest('3.14'), contains('3,14'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('věta "Enter a number first." beze změny tečky', (
      tester,
    ) async {
      final state = await pumpApp(tester, locale: const Locale('en'));
      expect(
        state.sentenceToSpeechForTest('Enter a number first.'),
        equals('Enter a number first.'),
      );
      expect(
        state.formatForSpeechForTest('Enter a number first.'),
        equals('Enter a number first.'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('česká věta s tečkou beze změny', (tester) async {
      final state = await pumpApp(tester);
      expect(
        state.sentenceToSpeechForTest('Nejprve zadejte číslo.'),
        equals('Nejprve zadejte číslo.'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('surd ve větě se přečte slovně', (tester) async {
      final state = await pumpApp(tester);
      final spoken =
          state.numberToSpeechForTest('Výsledek je 6√2') as String;
      expect(spoken, contains('odmocnina'));
      expect(spoken.contains('√'), isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('R7 – režim a vědecká stránka', () {
    testWidgets('změna režimu -> právě jedno "Přepnuto na"', (tester) async {
      final state = await pumpApp(tester);
      await setScreenReader(tester, state, false);
      ttsLog.clear();
      final added = await countNewTts(tester, () async {
        state.switchModeForTest(CalculatorMode.statistics);
      });
      expect(added, 1, reason: 'TTS log: $ttsLog');
      expect(ttsLog.last, contains('Přepnuto na'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('změna režimu SR ON -> Semantics, žádné TTS', (tester) async {
      final state = await pumpApp(tester);
      await setScreenReader(tester, state, true);
      ttsLog.clear();
      state.switchModeForTest(CalculatorMode.scientific);
      await tester.pumpAndSettle();
      expect(ttsLog, isEmpty, reason: 'TTS log: $ttsLog');
      expect(
        state.lastAnnouncementForTest as String,
        contains('Přepnuto na'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('vědecká stránka tam a zpět, sjednocený text', (tester) async {
      final state = await pumpApp(tester);
      await setScreenReader(tester, state, false);
      ttsLog.clear();
      var added = await countNewTts(tester, () async {
        state.toggleScientificPageForTest();
      });
      expect(added, 1, reason: 'TTS log: $ttsLog');
      expect(ttsLog.last, contains('Stránka funkcí'));
      added = await countNewTts(tester, () async {
        state.toggleScientificPageForTest();
      });
      expect(added, 1, reason: 'TTS log: $ttsLog');
      expect(ttsLog.last, contains('Číselná stránka'));
      expect(tester.takeException(), isNull);
    });
  });

  group('R9 – nastavení a profil', () {
    testWidgets('zoom horního řádku -> právě jedno potvrzení', (tester) async {
      final state = await pumpApp(tester);
      await setScreenReader(tester, state, false);
      expect(state.startEditingForTest('standard'), isTrue);
      final dialogFuture = state.openEditorDialogForTest();
      await tester.pumpAndSettle();
      final header = find.text('Zoom horního řádku').evaluate().isNotEmpty
          ? find.text('Zoom horního řádku')
          : find.text('Upper row zoom');
      expect(header, findsOneWidget);
      // Najdi sloupec hlavičky a v něm tlačítko '+'.
      final cols = find.ancestor(
        of: header,
        matching: find.byType(Column),
      );
      final plusCandidates = <Finder>[];
      for (final el in cols.evaluate()) {
        final candidate = find.descendant(
          of: find.byWidgetPredicate((w) => identical(w, el.widget)),
          matching: find.widgetWithText(ElevatedButton, '+'),
        );
        if (candidate.evaluate().isNotEmpty) {
          plusCandidates.add(candidate.first);
        }
      }
      expect(plusCandidates, isNotEmpty);
      final plus = plusCandidates.first;
      await tester.ensureVisible(plus);
      await tester.pumpAndSettle();
      ttsLog.clear();
      await tester.tap(plus);
      await tester.pumpAndSettle();
      expect(ttsLog, hasLength(1), reason: 'TTS log: $ttsLog');
      expect(ttsLog.single, contains('Zoom'));
      expect(tester.takeException(), isNull);
      // Dialog necháme otevřený; addTearDown resetuje strom.
      // ignore: unawaited_futures
      dialogFuture.then((_) {});
    });

    testWidgets('TTS OFF -> ticho; TTS ON -> potvrzení', (tester) async {
      final state = await pumpApp(tester);
      await setScreenReader(tester, state, false);
      state.updateActiveSettingsForTest(
        (s) => s.copyWith(ttsEnabled: false),
      );
      await tester.pumpAndSettle();
      ttsLog.clear();
      await state.handleButtonPressedForTest('7');
      await tester.pumpAndSettle();
      expect(ttsLog, isEmpty, reason: 'TTS log: $ttsLog');
      state.updateActiveSettingsForTest((s) => s.copyWith(ttsEnabled: true));
      await tester.pumpAndSettle();
      ttsLog.clear();
      final added = await countNewTts(
        tester,
        () => state.handleButtonPressedForTest('7'),
      );
      expect(added, 1, reason: 'TTS log: $ttsLog');
      expect(tester.takeException(), isNull);
    });

    testWidgets('TTS OFF + SR ON -> výsledek přesto Semantics kanálem', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      state.updateActiveSettingsForTest(
        (s) => s.copyWith(ttsEnabled: false),
      );
      await setScreenReader(tester, state, true);
      await calculate(tester, state, '2+2');
      // Potvrzení nesmí záviset na vypnutém TTS (R9).
      expect(ttsLog, isEmpty, reason: 'TTS log: $ttsLog');
      expect(
        state.lastAnnouncementForTest as String,
        contains('Výsledek je'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('aktivace profilu -> právě jedno oznámení', (tester) async {
      final state = await pumpApp(tester);
      await setScreenReader(tester, state, false);
      final profiles = (state.profilesForTest as List)
          .where((p) => p.id != state.activeProfileIdForTest)
          .toList();
      expect(profiles, isNotEmpty);
      ttsLog.clear();
      await state.applyAccessibilityProfile(
        profiles.first,
        announcement: 'Profil aktivován',
      );
      await tester.pumpAndSettle();
      expect(ttsLog, hasLength(1), reason: 'TTS log: $ttsLog');
      expect(ttsLog.single, contains('Profil aktivován'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('aktivace profilu SR ON -> Semantics, žádné TTS', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      // Přepni na jiný profil a persistuj do něj režim čtečky ON
      // (aktivace aplikuje uložené nastavení profilu).
      final otherId = (state.profilesForTest as List)
          .firstWhere((p) => p.id != state.activeProfileIdForTest)
          .id as String;
      state.switchProfileForTest(otherId);
      await tester.pumpAndSettle();
      await setScreenReader(tester, state, true);
      final target = (state.profilesForTest as List).firstWhere(
        (p) => p.id == otherId,
      );
      ttsLog.clear();
      await state.applyAccessibilityProfile(
        target,
        announcement: 'Profil aktivován',
      );
      await tester.pumpAndSettle();
      expect(ttsLog, isEmpty, reason: 'TTS log: $ttsLog');
      expect(
        state.lastAnnouncementForTest as String,
        contains('Profil aktivován'),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('R10 – statistika', () {
    Future<dynamic> pumpStats(WidgetTester tester) async {
      final state = await pumpApp(tester);
      await setScreenReader(tester, state, false);
      var chip = find.widgetWithText(ChoiceChip, 'Statistika');
      if (chip.evaluate().isEmpty) {
        chip = find.widgetWithText(ChoiceChip, 'Statistics');
      }
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip, warnIfMissed: false);
      await tester.pumpAndSettle();
      state.addStatsSetForTest(
        StatisticsSet(name: 'Test', fieldNames: const ['Value'], records: []),
      );
      await tester.pumpAndSettle();
      return state;
    }

    testWidgets('M+ -> právě jedna hláška "Připravena 1 hodnota"', (
      tester,
    ) async {
      final state = await pumpStats(tester);
      state.setDisplayForTest('5', 1);
      await tester.pump();
      ttsLog.clear();
      await state.addSingleValueToStatsForTest();
      await tester.pumpAndSettle();
      final ready = ttsLog.where((t) => t.contains('Připraven')).toList();
      expect(ready, hasLength(1), reason: 'TTS log: $ttsLog');
      expect(ready.single, contains('Připravena 1 hodnota'));
      expect(
        ttsLog.any((t) => t == 'Přidat do statistické paměti'),
        isFalse,
        reason: 'TTS log: $ttsLog',
      );
      expect(tester.takeException(), isNull);
    });
  });
}
