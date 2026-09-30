import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';
import 'package:mluvici_kalkulacka/surd.dart';
import 'package:mluvici_kalkulacka/config_validator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regresní testy jednotného „Rychlého nastavení kalkulačky".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void mockChannels() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (MethodCall call) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.example.mluvici_kalkulacka/accessibility'),
      (MethodCall call) async {
        if (call.method == 'isTalkBackEnabled' ||
            call.method == 'isScreenReaderEnabled') {
          return false;
        }
        return false;
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
  }

  Future<dynamic> pumpApp(WidgetTester tester) async {
    tester.platformDispatcher.clearAllTestValues();
    tester.view.physicalSize = const Size(412, 860);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(const ScientificCalculatorApp());
    await tester.pumpAndSettle();
    return tester.state(find.byType(CalculatorScreen)) as dynamic;
  }

  String seedV2Json() {
    final profiles = [
      AccessibilityProfile(
        id: 'standard',
        name: 'Standard',
        isBuiltIn: true,
        settings: AccessibilitySettings.defaultsStandard(),
      ),
      AccessibilityProfile(
        id: 'blind',
        name: 'Blind',
        isBuiltIn: true,
        settings: AccessibilitySettings.defaultsBlind(),
      ),
      AccessibilityProfile(
        id: 'lowvision',
        name: 'Low vision',
        isBuiltIn: true,
        settings: AccessibilitySettings.defaultsLowVision(),
      ),
    ];
    return jsonEncode(profiles.map((p) => p.toJson()).toList());
  }

  group('first-run detekce', () {
    test('1) prazdne prefs -> first run', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      expect(await isQuickSetupFirstRun(prefs), isTrue);
    });

    test('3) stara validni instalace -> migrace, zadny onboarding', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'accessibility_profiles_v2': seedV2Json(),
        'activeProfileId': 'blind',
        'modeQuestionAsked': true,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(await isQuickSetupFirstRun(prefs), isFalse);
      // Migrace markeru probehla.
      expect(prefs.getBool('quickSetupCompleted'), isTrue);
      // Konfigurace zustava nedotcena.
      expect(prefs.getString('activeProfileId'), 'blind');
    });

    test('4) seed defaults v RAM != ulozena konfigurace', () {
      // Seed zapise v2+activeId, ale bez modeQuestionAsked to NENI
      // skutecne ulozena uzivatelska konfigurace.
      expect(
        hasPersistedUserConfiguration(
          hasProfilesV2: true,
          hasActiveProfileId: true,
          hasModeQuestionAsked: false,
        ),
        isFalse,
      );
      expect(
        hasPersistedUserConfiguration(
          hasProfilesV2: true,
          hasActiveProfileId: true,
          hasModeQuestionAsked: true,
        ),
        isTrue,
      );
      expect(
        hasPersistedUserConfiguration(
          hasProfilesV2: false,
          hasActiveProfileId: false,
          hasModeQuestionAsked: false,
        ),
        isFalse,
      );
    });

    test('quickSetupCompleted == true -> nikdy first run', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'quickSetupCompleted': true,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(await isQuickSetupFirstRun(prefs), isFalse);
    });
  });

  group('presety a draft', () {
    test('5) standard preset', () {
      final d = QuickSetupDraft.defaults().applyPreset(
        QuickSetupPreset.standard,
      );
      expect(d.settings.accessibilityType, AccessibilityType.none);
      expect(d.settings.fontSizeMultiplier, 1.0);
      expect(d.detectedPreset, QuickSetupPreset.standard);
    });

    test('6) blind preset', () {
      final d = QuickSetupDraft.defaults().applyPreset(QuickSetupPreset.blind);
      expect(d.settings.accessibilityType, AccessibilityType.blind);
      expect(d.settings.announceExpression, isTrue);
      expect(d.detectedPreset, QuickSetupPreset.blind);
    });

    test('7) low vision preset', () {
      final d = QuickSetupDraft.defaults().applyPreset(
        QuickSetupPreset.lowVision,
      );
      expect(
        d.settings.accessibilityType,
        AccessibilityType.visuallyImpaired,
      );
      expect(d.settings.fontSizeMultiplier, 1.75);
      expect(d.settings.useSixteenSegment, isTrue);
      expect(d.detectedPreset, QuickSetupPreset.lowVision);
    });

    test('8) custom draft', () {
      final d = QuickSetupDraft.defaults()
          .applyPreset(QuickSetupPreset.standard)
          .copyWith(
            settings: AccessibilitySettings.defaultsStandard().copyWith(
              speechRate: 0.9,
            ),
          );
      expect(d.detectedPreset, QuickSetupPreset.custom);
      expect(d.settings.speechRate, 0.9);
    });

    test('9) draft mutace nemeni prefs', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final before = prefs.getKeys().toSet();
      var d = QuickSetupDraft.defaults();
      d = d.applyPreset(QuickSetupPreset.blind);
      d = d.copyWith(isDegreeMode: false, defaultMode: CalculatorMode.basic);
      expect(prefs.getKeys().toSet(), before);
      expect(prefs.containsKey('quickSetupCompleted'), isFalse);
    });
  });

  group('cancel / apply protokol', () {
    test('10+11) cancel nemeni konfiguraci, jen marker', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'accessibility_profiles_v2': seedV2Json(),
        'activeProfileId': 'standard',
        'modeQuestionAsked': true,
        'isDegreeMode': true,
        'themeMode': ThemeMode.dark.index,
      });
      final prefs = await SharedPreferences.getInstance();
      await markQuickSetupSeen(prefs);
      expect(prefs.getBool('quickSetupCompleted'), isTrue);
      expect(prefs.getString('activeProfileId'), 'standard');
      expect(prefs.getBool('isDegreeMode'), isTrue);
      expect(prefs.getInt('themeMode'), ThemeMode.dark.index);
    });

    test('12+13) apply ulozi cely config, restart ho obnovi', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final draft = QuickSetupDraft.defaults()
          .applyPreset(QuickSetupPreset.blind)
          .copyWith(
            themeMode: ThemeMode.light,
            isDegreeMode: false,
            defaultMode: CalculatorMode.basic,
            resultDisplayMode: ResultDisplayMode.text,
          );
      final contract = buildQuickSetupContract(
        draft: draft,
        profiles: [
          AccessibilityProfile(
            id: 'standard',
            name: 'Standard',
            isBuiltIn: true,
            settings: AccessibilitySettings.defaultsStandard(),
          ),
        ],
        activeProfileId: 'standard',
        statsSummaryOrder: const [
          StatsSummarySection.header,
          StatsSummarySection.dataValues,
          StatsSummarySection.computed,
        ],
        statsComputedOrder: StatsComputedItem.values,
        currencyFrom: 'CZK',
        currencyTo: 'EUR',
        devEnabled: false,
        devAutoDiagnostic: false,
        devDiagnosticDurationMs: 700,
        devPinCode: null,
        historyExactFormat: HistoryExactFormat.numeric,
      );
      expect(validateQuickSetupContract(contract).ok, isTrue);
      await persistCanonicalContract(prefs, contract);
      await markQuickSetupSeen(prefs);

      expect(prefs.getString('activeProfileId'), 'standard');
      expect(prefs.getBool('isDegreeMode'), isFalse);
      expect(prefs.getInt('defaultMode'), CalculatorMode.basic.index);
      expect(prefs.getString('resultDisplayMode'), 'text');
      expect(prefs.getInt('themeMode'), ThemeMode.light.index);
      expect(prefs.getBool('modeQuestionAsked'), isTrue);
      expect(prefs.getBool('quickSetupCompleted'), isTrue);

      // Restart: cteni z tehoz uloziste.
      final reloaded = await SharedPreferences.getInstance();
      expect(reloaded.getBool('isDegreeMode'), isFalse);
      final snapshot =
          jsonDecode(reloaded.getString('config_contract_v1')!) as Map<String, dynamic>;
      final parsed = parseContract(snapshot);
      expect(parsed.isDegreeMode, isFalse);
      expect(parsed.defaultMode, CalculatorMode.basic);
      expect(parsed.resultDisplayMode, ResultDisplayMode.text);
      expect(parsed.themeMode, ThemeMode.light);
      expect(
        parsed.profiles.firstWhere((p) => p.id == 'standard').settings.accessibilityType,
        AccessibilityType.blind,
      );
    });

    test('14) nevalidni kontrakt se nesmi persistovat', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final draft = QuickSetupDraft.defaults();
      final contract = buildQuickSetupContract(
        draft: draft,
        profiles: [
          AccessibilityProfile(
            id: 'standard',
            name: 'Standard',
            isBuiltIn: true,
            settings: AccessibilitySettings.defaultsStandard(),
          ),
        ],
        activeProfileId: 'standard',
        statsSummaryOrder: const [
          StatsSummarySection.header,
          StatsSummarySection.dataValues,
          StatsSummarySection.computed,
        ],
        statsComputedOrder: StatsComputedItem.values,
        currencyFrom: 'CZK',
        currencyTo: 'EUR',
        devEnabled: false,
        devAutoDiagnostic: false,
        devDiagnosticDurationMs: 700,
        devPinCode: null,
        historyExactFormat: HistoryExactFormat.numeric,
      );
      // Poskozene globalSettings -> validace selze -> caller nesmi volat persist.
      final broken = Map<String, dynamic>.from(contract);
      broken['globalSettings'] = <String, dynamic>{
        ...Map<String, dynamic>.from(contract['globalSettings'] as Map),
        'defaultMode': 'neexistujici_rezim',
      };
      expect(validateQuickSetupContract(broken).ok, isFalse);
      expect(prefs.containsKey('accessibility_profiles_v2'), isFalse);
      expect(prefs.containsKey('quickSetupCompleted'), isFalse);
    });
  });

  group('voice fallback', () {
    final available = [
      {'name': 'Czech Voice A', 'locale': 'cs-CZ'},
      {'name': 'English Voice', 'locale': 'en-US'},
    ];

    test('15) exact voice', () {
      final r = resolveVoice(
        {'name': 'Czech Voice A', 'locale': 'cs-CZ'},
        available,
      );
      expect(r, {'name': 'Czech Voice A', 'locale': 'cs-CZ'});
    });

    test('16) locale fallback', () {
      final r = resolveVoice(
        {'name': 'Neexistujici hlas', 'locale': 'cs-CZ'},
        available,
      );
      expect(r, {'name': 'Czech Voice A', 'locale': 'cs-CZ'});
    });

    test('17) default fallback (null)', () {
      expect(resolveVoice({'name': 'X', 'locale': 'de-DE'}, available), isNull);
      expect(resolveVoice(null, available), isNull);
      expect(resolveVoice({'name': 'X', 'locale': 'de-DE'}, []), isNull);
    });

    test('18) neznamy voice nezhodi import ani validaci', () {
      final contract = buildContractJson(
        profiles: [
          AccessibilityProfile(
            id: 'standard',
            name: 'Standard',
            isBuiltIn: true,
            settings: AccessibilitySettings.defaultsStandard().copyWith(
              ttsVoice: {'name': 'Mrtvy hlas', 'locale': 'xx-XX'},
              ttsVoiceName: 'Mrtvy hlas',
            ),
          ),
        ],
        activeProfileId: 'standard',
        themeMode: ThemeMode.dark,
        isDegreeMode: true,
        defaultMode: CalculatorMode.scientific,
        statsSummaryOrder: const [
          StatsSummarySection.header,
          StatsSummarySection.dataValues,
          StatsSummarySection.computed,
        ],
        statsComputedOrder: StatsComputedItem.values,
        currencyFrom: 'CZK',
        currencyTo: 'EUR',
        devEnabled: false,
        devAutoDiagnostic: false,
        devDiagnosticDurationMs: 700,
        devPinCode: null,
        resultDisplayMode: ResultDisplayMode.segment,
        historyExactFormat: HistoryExactFormat.numeric,
      );
      expect(validateContract(contract).ok, isTrue);
      final parsed = parseContract(contract);
      final resolved = resolveVoice(
        parsed.profiles.first.settings.ttsVoice,
        available,
      );
      expect(resolved, isNull); // default hlas, zadny pad
    });
  });

  group('global vs profil', () {
    test('19) resultDisplayMode je pouze global', () {
      final contract = buildContractJson(
        profiles: [
          AccessibilityProfile(
            id: 'standard',
            name: 'Standard',
            isBuiltIn: true,
            settings: AccessibilitySettings.defaultsStandard(),
          ),
        ],
        activeProfileId: 'standard',
        themeMode: ThemeMode.dark,
        isDegreeMode: true,
        defaultMode: CalculatorMode.scientific,
        statsSummaryOrder: const [
          StatsSummarySection.header,
          StatsSummarySection.dataValues,
          StatsSummarySection.computed,
        ],
        statsComputedOrder: StatsComputedItem.values,
        currencyFrom: 'CZK',
        currencyTo: 'EUR',
        devEnabled: false,
        devAutoDiagnostic: false,
        devDiagnosticDurationMs: 700,
        devPinCode: null,
        resultDisplayMode: ResultDisplayMode.auto,
        historyExactFormat: HistoryExactFormat.numeric,
      );
      final settings =
          (contract['profiles'] as List).first['settings'] as Map;
      expect(settings.containsKey('resultDisplayMode'), isFalse);
      expect(
        (contract['globalSettings'] as Map)['resultDisplayMode'],
        'auto',
      );
      final parsed = parseContract(contract);
      expect(parsed.resultDisplayMode, ResultDisplayMode.auto);
      // Profil zustava na migracnim defaultu.
      expect(
        parsed.profiles.first.settings.resultDisplayMode,
        ResultDisplayMode.segment,
      );
      // Stary export s profilovym rdm se migruje do globalu.
      final legacySettings = Map<String, dynamic>.from(settings)
        ..['resultDisplayMode'] = 'text';
      final legacy = Map<String, dynamic>.from(contract)
        ..['profiles'] = [
          {
            'id': 'standard',
            'name': 'Standard',
            'isBuiltIn': true,
            'settings': legacySettings,
          },
        ]
        ..remove('globalSettings');
      final gs = Map<String, dynamic>.from(
        contract['globalSettings'] as Map,
      )..remove('resultDisplayMode');
      legacy['globalSettings'] = gs;
      expect(parseContract(legacy).resultDisplayMode, ResultDisplayMode.text);
    });

    test('20) historyExactFormat zustava global (persist + contract)', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final draft = QuickSetupDraft.defaults();
      final contract = buildQuickSetupContract(
        draft: draft,
        profiles: [
          AccessibilityProfile(
            id: 'standard',
            name: 'Standard',
            isBuiltIn: true,
            settings: AccessibilitySettings.defaultsStandard(),
          ),
        ],
        activeProfileId: 'standard',
        statsSummaryOrder: const [
          StatsSummarySection.header,
          StatsSummarySection.dataValues,
          StatsSummarySection.computed,
        ],
        statsComputedOrder: StatsComputedItem.values,
        currencyFrom: 'CZK',
        currencyTo: 'EUR',
        devEnabled: false,
        devAutoDiagnostic: false,
        devDiagnosticDurationMs: 700,
        devPinCode: null,
        historyExactFormat: HistoryExactFormat.exact,
      );
      expect((contract['globalSettings'] as Map)['historyExactFormat'], 'exact');
      await persistCanonicalContract(prefs, contract);
      expect(prefs.getString('historyExactFormat'), 'exact');
      final snapshot =
          jsonDecode(prefs.getString('config_contract_v1')!) as Map<String, dynamic>;
      expect(
        (snapshot['globalSettings'] as Map)['historyExactFormat'],
        'exact',
      );
    });

    test('21) schema obsahuje nove globalni klice', () async {
      final raw = await rootBundle.loadString(
        'assets/config_schema_v1.json',
      );
      final schema = jsonDecode(raw) as Map<String, dynamic>;
      final defs = schema[r'$defs'] as Map<String, dynamic>;
      final global = defs['globalSettings'] as Map<String, dynamic>;
      final props = global['properties'] as Map<String, dynamic>;
      expect(props.containsKey('resultDisplayMode'), isTrue);
      expect(props.containsKey('historyExactFormat'), isTrue);
    });

    test('22+23) contract + import/export round-trip', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final draft = QuickSetupDraft.defaults()
          .applyPreset(QuickSetupPreset.lowVision)
          .copyWith(resultDisplayMode: ResultDisplayMode.auto);
      final contract = buildQuickSetupContract(
        draft: draft,
        profiles: [
          AccessibilityProfile(
            id: 'standard',
            name: 'Standard',
            isBuiltIn: true,
            settings: AccessibilitySettings.defaultsStandard(),
          ),
          AccessibilityProfile(
            id: 'blind',
            name: 'Blind',
            isBuiltIn: true,
            settings: AccessibilitySettings.defaultsBlind(),
          ),
        ],
        activeProfileId: 'blind',
        statsSummaryOrder: const [
          StatsSummarySection.header,
          StatsSummarySection.dataValues,
          StatsSummarySection.computed,
        ],
        statsComputedOrder: StatsComputedItem.values,
        currencyFrom: 'CZK',
        currencyTo: 'EUR',
        devEnabled: false,
        devAutoDiagnostic: false,
        devDiagnosticDurationMs: 700,
        devPinCode: null,
        historyExactFormat: HistoryExactFormat.numeric,
      );
      // Export -> parse -> save -> load -> export beze ztrat.
      final exported = jsonDecode(jsonEncode(contract)) as Map<String, dynamic>;
      expect(validateContract(exported).ok, isTrue);
      await persistCanonicalContract(prefs, exported);
      final snapshot =
          jsonDecode(prefs.getString('config_contract_v1')!) as Map<String, dynamic>;
      final reparsed = parseContract(snapshot);
      expect(reparsed.resultDisplayMode, ResultDisplayMode.auto);
      expect(reparsed.activeProfileId, 'blind');
      // Draft (lowVision preset) se aplikuje do AKTIVNIHO profilu 'blind'.
      expect(
        reparsed.profiles
            .firstWhere((p) => p.id == 'blind')
            .settings
            .fontSizeMultiplier,
        1.75,
      );
    });
  });

  group('startup widget', () {
    testWidgets('2) first run zobrazi Quick Setup pouze jednou', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      mockChannels();
      await pumpApp(tester);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Quick calculator setup'), findsOneWidget);
      expect(find.text('Apply settings'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Storno: dialog zmizi, marker se ulozi.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Quick calculator setup'), findsNothing);
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('quickSetupCompleted'), isTrue);

      // Restart: dialog se uz neukaze.
      await tester.pumpWidget(const ScientificCalculatorApp());
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Quick calculator setup'), findsNothing);
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('quickSetupCompleted'), isTrue);
    });

    testWidgets('stara instalace neukazuje onboarding', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'accessibility_profiles_v2': seedV2Json(),
        'activeProfileId': 'standard',
        'modeQuestionAsked': true,
      });
      mockChannels();
      await pumpApp(tester);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Quick calculator setup'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('activeProfileId'), 'standard');
    });

    testWidgets('apply z dialogu ulozi blind preset', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      mockChannels();
      await pumpApp(tester);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Quick calculator setup'), findsOneWidget);
      // Predvolba Nevidomy (prvni vyskyt 'Blind' patri predvolbam).
      await tester.tap(find.text('Blind').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply settings'));
      await tester.pumpAndSettle();
      expect(find.text('Quick calculator setup'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('quickSetupCompleted'), isTrue);
      final v2 =
          jsonDecode(prefs.getString('accessibility_profiles_v2')!) as List;
      final active = (v2.firstWhere(
        (e) => (e as Map)['id'] == prefs.getString('activeProfileId'),
      ) as Map)['settings'] as Map;
      expect(active['accessibilityType'], AccessibilityType.blind.index);
    });
  });
}
