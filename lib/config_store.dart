part of 'main.dart';

/// Testovatelná persistence/migration/apply vrstva pro rychlé nastavení.
///
/// Žádný nový persistentní formát: canonical source of truth je
/// `config_contract_v1`, SharedPreferences legacy keys jsou pouze
/// kompatibilní derivace.
///
/// Upozornění k „atomicitě": SharedPreferences není databázová transakce,
/// proto se zde používá pojem **safe commit workflow / canonical snapshot
/// commit**, nikoli „true atomic transaction".
///
/// Pořadí commitu: draft → validate → canonical snapshot → persist →
/// runtime apply (volá caller) → completion marker. Při chybě persistu
/// se runtime nesmí měnit a marker se nesmí nastavit.
const String kQuickSetupCompletedKey = 'quickSetupCompleted';

/// Čistá detekce skutečně uložené uživatelské konfigurace.
///
/// Rozlišuje runtime seed defaults (pouze v RAM) od skutečně persistované
/// konfigurace. Seednuté defaults v RAM samy o sobě NIKDY neznamenají,
/// že uživatel konfiguraci má.
bool hasPersistedUserConfiguration({
  required bool hasProfilesV2,
  required bool hasActiveProfileId,
  required bool hasModeQuestionAsked,
}) {
  // Stará validní instalace: profily v2 + aktivní profil + zodpovězená
  // otázka na režim. Všechny tři markery musí existovat, aby se stará
  // instalace nepovažovala za nového uživatele.
  if (hasProfilesV2 && hasActiveProfileId && hasModeQuestionAsked) return true;
  return false;
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
    hasProfilesV2: prefs.containsKey('accessibility_profiles_v2'),
    hasActiveProfileId: prefs.containsKey('activeProfileId'),
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

/// Sestaví canonical `config_contract_v1` z QuickSetup draftu.
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
    currencyFrom: currencyFrom,
    currencyTo: currencyTo,
    devEnabled: devEnabled,
    devAutoDiagnostic: devAutoDiagnostic,
    devDiagnosticDurationMs: devDiagnosticDurationMs,
    devPinCode: devPinCode,
    resultDisplayMode: draft.resultDisplayMode,
    historyExactFormat: historyExactFormat,
  );
}

/// Validace canonical kontraktu (delegace na existující validátor).
ValidationResult validateQuickSetupContract(Map<String, dynamic> contract) {
  return validateContract(contract);
}

/// Zapíše canonical kontrakt do SharedPreferences (safe commit workflow).
///
/// Zapisuje: profily v2 + activeId, globály (včetně theme jako int index
/// pro `main.dart`), a nakonec parity snapshot `config_contract_v1`.
/// Snapshot je pouze parita – jeho selhání commit neruší.
/// Při selhání kteréhokoli povinného zápisu vyhodí výjimku a caller
/// NESMÍ aplikovat nový runtime state ani nastavit completion marker.
Future<void> persistCanonicalContract(
  SharedPreferences prefs,
  Map<String, dynamic> contract,
) async {
  final parsed = parseContract(contract);
  final profileJson = jsonEncode(
    parsed.profiles.map((p) => p.toJson()).toList(),
  );
  // Povinné zápisy – každý awaitovaný. SharedPreferences na podporovaných
  // platformách zapisuje synchronně do paměti, takže částečný stav po
  // chybě znamená výhradně výjimku (žádné tiché „napůl").
  final writes = <Future<bool>>[
    prefs.setString('accessibility_profiles_v2', profileJson),
    prefs.setString('activeProfileId', parsed.activeProfileId),
    prefs.setBool('isDegreeMode', parsed.isDegreeMode),
    prefs.setString(
      'resultDisplayMode',
      _resultDisplayModeToString(parsed.resultDisplayMode),
    ),
    prefs.setString(
      'historyExactFormat',
      _historyExactFormatToString(parsed.historyExactFormat),
    ),
    prefs.setInt('defaultMode', parsed.defaultMode.index),
    prefs.setStringList(
      'statsSummaryOrder',
      parsed.statsSummaryOrder.map((e) => e.name).toList(),
    ),
    prefs.setStringList(
      'statsComputedOrder',
      parsed.statsComputedOrder.map((e) => e.name).toList(),
    ),
    prefs.setString('currencyFrom', parsed.currencyFrom),
    prefs.setString('currencyTo', parsed.currencyTo),
    prefs.setBool('devModeEnabled', parsed.devEnabled),
    prefs.setBool('devAutoDiagnosticEnabled', parsed.devAutoDiagnostic),
    prefs.setInt(
      'devDiagnosticDurationMs',
      parsed.devDiagnosticDurationMs,
    ),
    if (parsed.devPinCode != null)
      prefs.setString('devPinCode', parsed.devPinCode!)
    else
      prefs.remove('devPinCode').then((_) => true),
    prefs.setInt('themeMode', parsed.themeMode.index),
    prefs.setBool('modeQuestionAsked', true),
  ];
  for (final w in writes) {
    final ok = await w;
    if (!ok) throw StateError('QuickSetup persist failed');
  }
  // Parity snapshot až po úspěchu povinných zápisů.
  try {
    await prefs.setString('config_contract_v1', jsonEncode(contract));
  } catch (_) {}
}
