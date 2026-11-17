part of 'main.dart';

/// Testovatelná persistence/migration/apply vrstva pro rychlé nastavení.
///
/// Žádný nový persistentní formát: canonical source of truth je
/// `config_contract_v3` (nebo zachované starší snapshoty) je
/// kanonický kontrakt; SharedPreferences legacy keys jsou kompatibilní derivace.
///
/// Upozornění k „atomicitě": SharedPreferences není databázová transakce,
/// proto se zde používá pojem **safe commit workflow / canonical snapshot
/// commit**, nikoli „true atomic transaction".
///
/// Pořadí commitu: draft → validate → persist canonical settings (migration
/// marker last) → runtime apply by the caller. A persistence failure rolls
/// back written preferences and must not change runtime state.
const String kQuickSetupCompletedKey = 'quickSetupCompleted';

/// Čistá detekce skutečně uložené uživatelské konfigurace.
///
/// Rozlišuje runtime seed defaults (pouze v RAM) od skutečně persistované
/// konfigurace. Seednuté defaults v RAM samy o sobě NIKDY neznamenají,
/// že uživatel konfiguraci má.
bool hasPersistedUserConfiguration({
  required String? profilesV2Json,
  required String? activeProfileId,
  required bool hasModeQuestionAsked,
}) {
  if (!hasModeQuestionAsked ||
      activeProfileId == null ||
      activeProfileId.isEmpty ||
      profilesV2Json == null ||
      profilesV2Json.isEmpty) {
    return false;
  }
  try {
    final decoded = jsonDecode(profilesV2Json);
    if (decoded is! List || decoded.isEmpty) return false;
    bool foundActive = false;
    for (final p in decoded) {
      if (p is Map) {
        final id = p['id']?.toString();
        if (id != null && id == activeProfileId) {
          foundActive = true;
          break;
        }
      }
    }
    return foundActive;
  } catch (_) {
    return false;
  }
}

/// First-run detekce nad skutečnými SharedPreferences.
///
/// A) `quickSetupCompleted == true` → false (není first run).
/// B) marker chybí, ale existuje platná stará konfigurace → migrace
///    markeru (nastaví `quickSetupCompleted = true`), vrátí false.
/// C) jinak → true (skutečný first run).
Future<bool> isQuickSetupFirstRun(SharedPreferences prefs) async {
  if (prefs.getBool(kQuickSetupCompletedKey) == true) return false;
  final hasOld = hasPersistedUserConfiguration(
    profilesV2Json: prefs.getString('accessibility_profiles_v2'),
    activeProfileId: prefs.getString('activeProfileId'),
    hasModeQuestionAsked: prefs.getBool('modeQuestionAsked') == true,
  );
  if (hasOld) {
    try {
      await prefs.setBool(kQuickSetupCompletedKey, true);
    } catch (_) {}
    return false;
  }
  return true;
}

/// Marker pro Storno: uživatel onboarding viděl a přeskočil ho.
/// Jediná povolená změna při Stornu.
Future<void> markQuickSetupSeen(SharedPreferences prefs) async {
  await prefs.setBool(kQuickSetupCompletedKey, true);
}

/// Normalizuje jeden hlasový záznam do `{name, locale}`.
/// Vrací null pro neplatné záznamy (místo pádu celého importu).
Map<String, String>? normalizeVoiceMap(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map) {
    final name = raw['name']?.toString();
    final locale = raw['locale']?.toString();
    if (name != null &&
        name.isNotEmpty &&
        locale != null &&
        locale.isNotEmpty) {
      return {'name': name, 'locale': locale};
    }
  }
  return null;
}

/// Voice resolution s fallbackem. Nikdy nevyhodí výjimku.
///
/// Priorita: 1) exact `{name, locale}` → 2) jiný dostupný hlas se stejným
/// locale → 3) systémový/default (reprezentováno `null`) → 4) `null`.
/// Neznámý/importovaný hlas NIKDY nezpůsobí failure celého importu.
Map<String, String>? resolveVoice(
  Map<String, String>? requested,
  List<dynamic> availableVoices,
) {
  final req = normalizeVoiceMap(requested);
  if (req == null) return null;
  final reqName = req['name']!.toLowerCase();
  final reqLocale = req['locale']!.toLowerCase();
  Map<String, String>? sameLocale;
  for (final v in availableVoices) {
    final norm = normalizeVoiceMap(v);
    if (norm == null) continue;
    final name = norm['name']!.toLowerCase();
    final locale = norm['locale']!.toLowerCase();
    if (name == reqName && locale == reqLocale) return norm;
    sameLocale ??= locale == reqLocale ? norm : null;
  }
  // Exact nenaiden → kompatibilní hlas stejného locale, jinak default.
  return sameLocale;
}

/// Sestaví aktuální canonical kontrakt z QuickSetup draftu.
///
/// Profily: nastavení aktivního profilu se nahradí `draft.settings`
/// (id/name/isBuiltIn se zachovají). Ostatní profily, statistické sady,
/// měnové kurzy ani dev hodnoty se nemění – přebírají se z aktuálního
/// runtime stavu předaného callerem.
Map<String, dynamic> buildQuickSetupContract({
  required QuickSetupDraft draft,
  required List<AccessibilityProfile> profiles,
  required String activeProfileId,
  required List<StatsSummarySection> statsSummaryOrder,
  required List<StatsComputedItem> statsComputedOrder,
  StatsDisplayConfig? statsDisplayConfig,
  required String currencyFrom,
  required String currencyTo,
  required bool devEnabled,
  required bool devAutoDiagnostic,
  required int devDiagnosticDurationMs,
  required String? devPinCode,
  required HistoryExactFormat historyExactFormat,
}) {
  final effectiveProfiles = profiles.isNotEmpty
      ? profiles
            .map(
              (p) => p.id == activeProfileId
                  ? AccessibilityProfile(
                      id: p.id,
                      name: p.name,
                      isBuiltIn: p.isBuiltIn,
                      settings: draft.settings.copyWith(),
                    )
                  : p,
            )
            .toList()
      : [
          AccessibilityProfile(
            id: activeProfileId,
            name: activeProfileId,
            isBuiltIn: true,
            settings: draft.settings.copyWith(),
          ),
        ];
  return buildContractJson(
    profiles: effectiveProfiles,
    activeProfileId: activeProfileId,
    themeMode: draft.themeMode,
    isDegreeMode: draft.isDegreeMode,
    defaultMode: draft.defaultMode,
    statsSummaryOrder: statsSummaryOrder,
    statsComputedOrder: statsComputedOrder,
    statsDisplayConfig: statsDisplayConfig,
    currencyFrom: currencyFrom,
    currencyTo: currencyTo,
    devEnabled: devEnabled,
    devAutoDiagnostic: devAutoDiagnostic,
    devDiagnosticDurationMs: devDiagnosticDurationMs,
    devPinCode: devPinCode,
    resultDisplayMode: draft.resultDisplayMode,
    resultNotationPreference: draft.resultNotationPreference,
    historyExactFormat: historyExactFormat,
    announceFractionAvailability: draft.announceFractionAvailability,
    globalSettings: draft.globalSettings,
  );
}

/// Validace canonical kontraktu (delegace na existující validátor).
ValidationResult validateQuickSetupContract(Map<String, dynamic> contract) {
  return validateContract(contract);
}

/// Zapíše canonical kontrakt do SharedPreferences (safe commit workflow).
///
/// Zapisuje: profily v2 + activeId, globály (včetně theme jako int index
/// pro `main.dart`), a nakonec parity snapshot ve verzi odpovídající kontraktu.
/// Snapshot je pouze parita – jeho selhání commit neruší.
/// Při selhání kteréhokoli povinného zápisu vyhodí výjimku a caller
/// NESMÍ aplikovat nový runtime state ani nastavit completion marker.
Future<void> persistCanonicalContract(
  SharedPreferences prefs,
  Map<String, dynamic> contract,
) async {
  final parsed = parseContract(contract);
  final canonicalSnapshot = buildContractJson(
    profiles: parsed.profiles,
    activeProfileId: parsed.activeProfileId,
    themeMode: parsed.themeMode,
    isDegreeMode: parsed.isDegreeMode,
    defaultMode: parsed.defaultMode,
    statsSummaryOrder: parsed.statsSummaryOrder,
    statsComputedOrder: parsed.statsComputedOrder,
    currencyFrom: parsed.currencyFrom,
    currencyTo: parsed.currencyTo,
    devEnabled: parsed.devEnabled,
    devAutoDiagnostic: parsed.devAutoDiagnostic,
    devDiagnosticDurationMs: parsed.devDiagnosticDurationMs,
    devPinCode: parsed.devPinCode,
    resultDisplayMode: parsed.resultDisplayMode,
    resultNotationPreference: parsed.resultNotationPreference,
    historyExactFormat: parsed.historyExactFormat,
    announceFractionAvailability: parsed.announceFractionAvailability,
    globalSettings: parsed.globalSettings,
    statsDisplayConfig:
        parsed.statsDisplayConfig ?? StatsDisplayConfig.defaults(),
  );
  final profileJson = jsonEncode(
    parsed.profiles.map((p) => p.toJson()).toList(),
  );
  final writes = <String, Future<bool> Function()>{
    'accessibility_profiles_v2': () =>
        prefs.setString('accessibility_profiles_v2', profileJson),
    'activeProfileId': () =>
        prefs.setString('activeProfileId', parsed.activeProfileId),
    'isDegreeMode': () => prefs.setBool('isDegreeMode', parsed.isDegreeMode),
    'resultNotationPreference': () => prefs.setString(
      'resultNotationPreference',
      _resultNotationPreferenceToString(parsed.resultNotationPreference),
    ),
    'historyExactFormat': () => prefs.setString(
      'historyExactFormat',
      _historyExactFormatToString(parsed.historyExactFormat),
    ),
    'defaultMode': () => prefs.setInt('defaultMode', parsed.defaultMode.index),
    'statsSummaryOrder': () => prefs.setStringList(
      'statsSummaryOrder',
      parsed.statsSummaryOrder.map((e) => e.name).toList(),
    ),
    'statsComputedOrder': () => prefs.setStringList(
      'statsComputedOrder',
      parsed.statsComputedOrder.map((e) => e.name).toList(),
    ),
    'statsDisplayConfig': () => prefs.setString(
      'statsDisplayConfig',
      jsonEncode(
        (parsed.statsDisplayConfig ?? StatsDisplayConfig.defaults()).toJson(),
      ),
    ),
    'currencyFrom': () => prefs.setString('currencyFrom', parsed.currencyFrom),
    'currencyTo': () => prefs.setString('currencyTo', parsed.currencyTo),
    'devModeEnabled': () => prefs.setBool('devModeEnabled', parsed.devEnabled),
    'devAutoDiagnosticEnabled': () =>
        prefs.setBool('devAutoDiagnosticEnabled', parsed.devAutoDiagnostic),
    'devDiagnosticDurationMs': () =>
        prefs.setInt('devDiagnosticDurationMs', parsed.devDiagnosticDurationMs),
    'devPinCode': () => parsed.devPinCode != null
        ? prefs.setString('devPinCode', parsed.devPinCode!)
        : prefs.remove('devPinCode'),
    'themeMode': () => prefs.setInt('themeMode', parsed.themeMode.index),
    'globalSettingsV3': () => prefs.setString(
      'globalSettingsV3',
      jsonEncode(parsed.globalSettings.toJson()..remove('themeMode')),
    ),
    'modeQuestionAsked': () => prefs.setBool('modeQuestionAsked', true),
    'globalSettingsMigratedV3': () =>
        prefs.setBool('globalSettingsMigratedV3', true),
  };
  final previous = {for (final key in writes.keys) key: prefs.get(key)};
  try {
    for (final entry in writes.entries) {
      if (!await entry.value()) {
        throw StateError('QuickSetup persist failed for ${entry.key}');
      }
    }
  } catch (error, stackTrace) {
    for (final key in writes.keys.toList().reversed) {
      final value = previous[key];
      try {
        final restored = switch (value) {
          null => await prefs.remove(key),
          String() => await prefs.setString(key, value),
          bool() => await prefs.setBool(key, value),
          int() => await prefs.setInt(key, value),
          List<String>() => await prefs.setStringList(key, value),
          _ => throw StateError('Unsupported SharedPreferences value for $key'),
        };
        if (!restored) {
          debugPrint('QuickSetup persistence rollback failed for $key.');
        }
      } catch (rollbackError) {
        debugPrint(
          'QuickSetup persistence rollback failed for $key: $rollbackError',
        );
      }
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
  // Parity snapshot až po úspěchu povinných zápisů.
  try {
    const snapshotKey = 'config_contract_v3';
    await prefs.setString(snapshotKey, jsonEncode(canonicalSnapshot));
  } catch (error) {
    debugPrint('QuickSetup contract snapshot failed: $error');
  }
}
