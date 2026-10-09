import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/config_validator.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:mluvici_kalkulacka/surd.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void mockChannels() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (c) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.example.mluvici_kalkulacka/accessibility'),
      (c) async => false,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (c) async => <String, Object>{
        'appName': 'mluvici_kalkulacka',
        'packageName': 'com.example.mluvici_kalkulacka',
        'version': '6.2.0',
        'buildNumber': '1',
      },
    );
  }

  Future<dynamic> pumpApp(
    WidgetTester tester, {
    Locale locale = const Locale('cs'),
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'modeQuestionAsked': true,
    });
    mockChannels();
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ScientificCalculatorApp(locale: locale));
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(CalculatorScreen)) as dynamic;
    return state;
  }

  Semantics outerDisplaySemantics(WidgetTester tester) {
    final finder = find.descendant(
      of: find.byType(CalculatorScreen),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.label == 'Výsledek' ||
                w.properties.label == 'Result'),
      ),
    );
    expect(finder, findsOneWidget);
    return tester.widget<Semantics>(finder.first);
  }

  group('ResultDisplayMode – model a persistence', () {
    test('default všech profilů je segment (původní vzhled)', () {
      expect(
        AccessibilitySettings.defaultsStandard().resultDisplayMode,
        ResultDisplayMode.segment,
      );
      expect(
        AccessibilitySettings.defaultsBlind().resultDisplayMode,
        ResultDisplayMode.segment,
      );
      expect(
        AccessibilitySettings.defaultsLowVision().resultDisplayMode,
        ResultDisplayMode.segment,
      );
    });

    test('copyWith mění jen resultDisplayMode', () {
      final a = AccessibilitySettings.defaultsStandard();
      final b = a.copyWith(resultDisplayMode: ResultDisplayMode.text);
      expect(a.resultDisplayMode, ResultDisplayMode.segment);
      expect(b.resultDisplayMode, ResultDisplayMode.text);
    });

    test('fromJson čte legacy klíč (migrace), toJson ho nezapisuje', () {
      for (final m in ResultDisplayMode.values) {
        final restored = AccessibilitySettings.fromJson({
          'resultDisplayMode': m.index,
        });
        expect(restored.resultDisplayMode, m);
      }
      // Nově uložený profil klíč neobsahuje (globál je jediný zdroj).
      final fresh = AccessibilitySettings.defaultsStandard().toJson();
      expect(fresh.containsKey('resultDisplayMode'), isFalse);
    });

    test('starý profil bez klíče a neznámá hodnota -> segment', () {
      expect(
        AccessibilitySettings.fromJson({}).resultDisplayMode,
        ResultDisplayMode.segment,
      );
      expect(
        AccessibilitySettings.fromJson({
          'resultDisplayMode': 99,
        }).resultDisplayMode,
        ResultDisplayMode.segment,
      );
      expect(
        AccessibilitySettings.fromJson({
          'resultDisplayMode': 'text',
        }).resultDisplayMode,
        ResultDisplayMode.segment,
      );
    });
  });

  group('config contract – globální klíče', () {
    Map<String, dynamic> contractWith(ResultDisplayMode m) {
      final profile = AccessibilityProfile(
        id: 'standard',
        name: 'Standard',
        settings: AccessibilitySettings.defaultsStandard(),
        isBuiltIn: true,
      );
      return buildContractJson(
        profiles: [profile],
        activeProfileId: 'standard',
        themeMode: ThemeMode.dark,
        isDegreeMode: true,
        defaultMode: CalculatorMode.scientific,
        statsSummaryOrder: StatsSummarySection.values.toList(),
        statsComputedOrder: StatsComputedItem.values.toList(),
        currencyFrom: 'CZK',
        currencyTo: 'EUR',
        devEnabled: false,
        devAutoDiagnostic: false,
        devDiagnosticDurationMs: 700,
        devPinCode: null,
        resultDisplayMode: m,
        historyExactFormat: HistoryExactFormat.numeric,
      );
    }

    test('roundtrip zachová text/auto/segment v globalSettings', () {
      for (final m in ResultDisplayMode.values) {
        final raw =
            jsonDecode(jsonEncode(contractWith(m))) as Map<String, dynamic>;
        final parsed = parseContract(raw);
        expect(parsed.resultDisplayMode, m);
      }
      // Per-profil klíč se již nezapisuje.
      final raw = contractWith(ResultDisplayMode.text);
      expect(
        (raw['profiles'] as List).first['settings'].containsKey(
          'resultDisplayMode',
        ),
        isFalse,
      );
    });

    test('validace: známé hodnoty projdou, neznámá je chyba', () {
      final ok = validateContract(contractWith(ResultDisplayMode.auto));
      expect(ok.ok, isTrue);
      final bad = contractWith(ResultDisplayMode.auto);
      (bad['globalSettings'] as Map)['resultDisplayMode'] = 'krychle';
      final res = validateContract(bad);
      expect(res.ok, isFalse);
      expect(res.errors.any((e) => e.code == 'enum'), isTrue);
    });

    test('validace: chybějící globální klíč (starý export) projde', () {
      final c = contractWith(ResultDisplayMode.segment);
      (c['globalSettings'] as Map).remove('resultDisplayMode');
      (c['globalSettings'] as Map).remove('historyExactFormat');
      expect(validateContract(c).ok, isTrue);
      final parsed = parseContract(
        jsonDecode(jsonEncode(c)) as Map<String, dynamic>,
      );
      expect(parsed.resultDisplayMode, ResultDisplayMode.segment);
      expect(parsed.historyExactFormat, HistoryExactFormat.numeric);
    });
  });

  group('widget – segment/text/auto renderery', () {
    testWidgets('segment (default): √72 spočte numericky, vzhled beze změny', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      expect(
        state.resultDisplayModeForTest,
        ResultDisplayMode.segment,
      );
      state.setDisplayForTest('√(72)', 5);
      await tester.pump();
      state.calculateForTest();
      await tester.pumpAndSettle();
      // Numerický zdroj pravdy zachován, žádný surd string v _lastResult.
      expect(state.lastResultForTest, isNot(contains('√')));
      expect(
        double.parse(state.lastResultForTest.replaceAll(',', '.')),
        closeTo(8.4852813742, 1e-6),
      );
      // Exaktní metadata existují, ale segmentový renderer je ignoruje.
      expect(state.lastExactForTest, isA<SurdValue>());
      // Segmentový displej přítomen, surd text nikde.
      expect(find.byType(CustomSegmentDisplay), findsWidgets);
      expect(find.text('6√2'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('text: √72 se zobrazí jako 6√2', (tester) async {
      final state = await pumpApp(tester);
      state.setResultDisplayModeForTest(ResultDisplayMode.text);
      await tester.pump();
      state.setDisplayForTest('√(72)', 5);
      await tester.pump();
      state.calculateForTest();
      await tester.pumpAndSettle();
      expect(find.text('6√2'), findsOneWidget);
      // Numerická pravda pro ANS/historii zůstává.
      expect(state.lastResultForTest, isNot(contains('√')));
      expect(
        double.parse(state.lastResultForTest.replaceAll(',', '.')),
        closeTo(8.4852813742, 1e-6),
      );
      // Surd text je ve fontu MathText a bez vlastní semantics.
      final text = tester.widget<Text>(find.text('6√2'));
      expect(text.style?.fontFamily, 'MathText');
      expect(
        find.ancestor(
          of: find.text('6√2'),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('auto: 25 zůstane segmentově', (tester) async {
      final state = await pumpApp(tester);
      state.setResultDisplayModeForTest(ResultDisplayMode.auto);
      await tester.pump();
      state.setDisplayForTest('25', 2);
      await tester.pump();
      state.calculateForTest();
      await tester.pumpAndSettle();
      expect(find.byType(CustomSegmentDisplay), findsWidgets);
      expect(find.text('6√2'), findsNothing);
      expect(state.lastExactForTest, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('auto: √72 přepne na text 6√2', (tester) async {
      final state = await pumpApp(tester);
      state.setResultDisplayModeForTest(ResultDisplayMode.auto);
      await tester.pump();
      state.setDisplayForTest('√(72)', 5);
      await tester.pump();
      state.calculateForTest();
      await tester.pumpAndSettle();
      expect(find.text('6√2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('semantics – jeden logický prvek pro NVDA/TalkBack', () {
    testWidgets('auto + surd: čtečka dostane slovní tvar právě jednou', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      state.setResultDisplayModeForTest(ResultDisplayMode.auto);
      await tester.pump();
      state.setDisplayForTest('√(72)', 5);
      await tester.pump();
      state.calculateForTest();
      await tester.pumpAndSettle();
      final outer = outerDisplaySemantics(tester);
      // Slovní tvar surdu (cs "odmocnina" / en "root" podle locale testu,
      // stejně jako stávající testy akceptují obě varianty).
      final val = outer.properties.value ?? '';
      expect(val.contains('odmocnina') || val.contains('root'), isTrue);
      // Žádný jiný Semantics uzel nečte surd slovy (duplicitní čtení).
      final dups = find.byWidgetPredicate((w) {
        if (w is! Semantics || w == outer) return false;
        final v = w.properties.value ?? '';
        return v.contains('odmocnina') || v.contains('root');
      });
      expect(dups, findsNothing);
    });

    testWidgets('segment + surd: displej i čtečka numericky (sjednocený kontrakt)', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      state.setDisplayForTest('√(72)', 5);
      await tester.pump();
      state.calculateForTest();
      await tester.pumpAndSettle();
      // Vzhled beze změny: žádný surd text na displeji.
      expect(find.text('6√2'), findsNothing);
      // ZÁMĚRNÁ ZMĚNA kontraktu (surd hlasová oprava): hlas odpovídá
      // skutečně aktivní reprezentaci, tedy v segmentu numerice —
      // surd se hlasově nevnucuje. Surd-slovně čte jen text/auto.
      final outer = outerDisplaySemantics(tester);
      final val = outer.properties.value ?? '';
      expect(val.contains('odmocnina') || val.contains('root'), isFalse);
      final dups = find.byWidgetPredicate((w) {
        if (w is! Semantics || w == outer) return false;
        final v = w.properties.value ?? '';
        return v.contains('odmocnina') || v.contains('root');
      });
      expect(dups, findsNothing);
    });
  });

  group('globální ResultDisplayMode – nezávislost na profilu', () {
    testWidgets('změna platí po přepnutí profilu i pro vlastní profil', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      state.setResultDisplayModeForTest(ResultDisplayMode.text);
      await tester.pump();
      state.switchProfileForTest('blind');
      await tester.pump();
      expect(state.resultDisplayModeForTest, ResultDisplayMode.text);
      state.createProfileForTest('Vlastní', 'standard');
      await tester.pump();
      state.switchProfileForTest(state.profilesForTest.last.id);
      await tester.pump();
      expect(state.resultDisplayModeForTest, ResultDisplayMode.text);
    });

    testWidgets('změna je zachována po restartu (SharedPreferences)', (
      tester,
    ) async {
      var state = await pumpApp(tester);
      // Nejprve počkej na dokončení startup migrace (jinak by přepsala save).
      final prefs = await SharedPreferences.getInstance();
      for (var i = 0; i < 100 && !prefs.containsKey('resultDisplayMode'); i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(state.profilesLoadedForTest, isTrue);
      state.setResultDisplayModeForTest(ResultDisplayMode.auto);
      // _saveGlobalSettings je async: počkej na persistenci klíče.
      for (var i = 0; i < 100 && prefs.getString('resultDisplayMode') != 'auto'; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(prefs.getString('resultDisplayMode'), 'auto');
      // Restart: znovu build BEZ resetu mock prefs (setMockInitialValues
      // se nevolá) — druhá instance musí načíst 'auto'.
      await tester.pumpWidget(
        ScientificCalculatorApp(locale: const Locale('cs')),
      );
      await tester.pumpAndSettle();
      state = tester.state(find.byType(CalculatorScreen)) as dynamic;
      expect(state.resultDisplayModeForTest, ResultDisplayMode.auto);
    });

    testWidgets('nově uložený profil neobsahuje resultDisplayMode', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      expect(state.startEditingForTest('standard'), isTrue);
      state.updateEditingForTest(
        (AccessibilitySettings s) => s.copyWith(speechRate: 0.9),
      );
      await tester.pump();
      expect(await state.saveEditingForTest(), isTrue);
      await tester.pump();
      final prefs = await SharedPreferences.getInstance();
      final v2 = prefs.getString('accessibility_profiles_v2') ?? '';
      expect(v2, isNot(contains('resultDisplayMode')));
    });
  });

  group('speech – surd tvary', () {
    testWidgets('6√2/3∛2/2⁴√3 se čtou slovně (cs i en varianta)', (
      tester,
    ) async {
      final state = await pumpApp(tester);
      // Testovací locale čtečky není garantovaně české, proto akceptujeme
      // obě varianty stejně jako stávající testy (např. devátou/desátou).
      final s1 = state.spokenForDisplayForTest('6√2') as String;
      expect(s1.contains('odmocnina') || s1.contains('root'), isTrue);
      expect(s1.contains('dvou') || s1.contains(' 2'), isTrue);
      final s2 = state.spokenForDisplayForTest('3∛2') as String;
      expect(
        s2.contains('třetí odmocnina') || s2.contains('cube root'),
        isTrue,
      );
      final s3 = state.spokenForDisplayForTest('2⁴√3') as String;
      expect(
        s3.contains('čtvrtá odmocnina') || s3.contains('fourth root'),
        isTrue,
      );
    });
  });
}
