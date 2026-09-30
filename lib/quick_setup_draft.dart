part of 'main.dart';

/// Předvolba rychlého nastavení. Pouze mění draft v paměti.
enum QuickSetupPreset { standard, blind, lowVision, custom }

/// Jednotný pracovní draft pro „Rychlé nastavení kalkulačky".
///
/// Čistý value-object: ŽÁDNÉ SharedPreferences, ŽÁDNÁ persistence,
/// ŽÁDNÁ UI logika, ŽÁDNÁ přímá závislost na TTS.
///
/// `historyExactFormat` záměrně NENÍ součástí UI draftu – aktuální
/// renderer ho ve všech případech nereflektuje, zůstává pouze
/// v kontraktu/persistenci jako globální údaj.
class QuickSetupDraft {
  final AccessibilitySettings settings;
  final ThemeMode themeMode;
  final bool isDegreeMode;
  final CalculatorMode defaultMode;
  final ResultDisplayMode resultDisplayMode;

  const QuickSetupDraft({
    required this.settings,
    required this.themeMode,
    required this.isDegreeMode,
    required this.defaultMode,
    required this.resultDisplayMode,
  });

  /// Sestaví draft z aktuálního runtime stavu (bez zápisu).
  factory QuickSetupDraft.fromRuntime({
    required AccessibilitySettings settings,
    required ThemeMode themeMode,
    required bool isDegreeMode,
    required CalculatorMode defaultMode,
    required ResultDisplayMode resultDisplayMode,
  }) {
    return QuickSetupDraft(
      settings: settings.copyWith(),
      themeMode: themeMode,
      isDegreeMode: isDegreeMode,
      defaultMode: defaultMode,
      resultDisplayMode: resultDisplayMode,
    );
  }

  /// Výchozí draft pro úplně první spuštění (odpovídá standardnímu profilu).
  factory QuickSetupDraft.defaults() {
    return QuickSetupDraft(
      settings: AccessibilitySettings.defaultsStandard(),
      themeMode: ThemeMode.dark,
      isDegreeMode: true,
      defaultMode: CalculatorMode.scientific,
      resultDisplayMode: ResultDisplayMode.segment,
    );
  }

  QuickSetupDraft copyWith({
    AccessibilitySettings? settings,
    ThemeMode? themeMode,
    bool? isDegreeMode,
    CalculatorMode? defaultMode,
    ResultDisplayMode? resultDisplayMode,
  }) {
    return QuickSetupDraft(
      settings: settings ?? this.settings.copyWith(),
      themeMode: themeMode ?? this.themeMode,
      isDegreeMode: isDegreeMode ?? this.isDegreeMode,
      defaultMode: defaultMode ?? this.defaultMode,
      resultDisplayMode: resultDisplayMode ?? this.resultDisplayMode,
    );
  }

  /// Předvolba pouze změní draft v paměti. Nic se nezapisuje.
  QuickSetupDraft applyPreset(QuickSetupPreset preset) {
    switch (preset) {
      case QuickSetupPreset.standard:
        return copyWith(
          settings: AccessibilitySettings.defaultsStandard(),
        );
      case QuickSetupPreset.blind:
        return copyWith(
          settings: AccessibilitySettings.defaultsBlind(),
        );
      case QuickSetupPreset.lowVision:
        return copyWith(
          settings: AccessibilitySettings.defaultsLowVision(),
        );
      case QuickSetupPreset.custom:
        return this;
    }
  }

  /// Detekce aktuální předvolby pro UI `selected` stav.
  QuickSetupPreset get detectedPreset {
    if (_sameSettings(settings, AccessibilitySettings.defaultsStandard())) {
      return QuickSetupPreset.standard;
    }
    if (_sameSettings(settings, AccessibilitySettings.defaultsBlind())) {
      return QuickSetupPreset.blind;
    }
    if (_sameSettings(settings, AccessibilitySettings.defaultsLowVision())) {
      return QuickSetupPreset.lowVision;
    }
    return QuickSetupPreset.custom;
  }
}

/// Porovnání nastavení pro detekci presetu (bez resultDisplayMode,
/// který je globální, a bez display-only ttsVoiceName).
bool _sameSettings(AccessibilitySettings a, AccessibilitySettings b) {
  return a.accessibilityType == b.accessibilityType &&
      a.screenReaderMode == b.screenReaderMode &&
      a.fontSizeMultiplier == b.fontSizeMultiplier &&
      a.dialogFontScale == b.dialogFontScale &&
      a.dotMatrixZoom == b.dotMatrixZoom &&
      a.resultZoom == b.resultZoom &&
      a.thousandGroupGap == b.thousandGroupGap &&
      a.dialogSize == b.dialogSize &&
      a.useSixteenSegment == b.useSixteenSegment &&
      a.usePeriodicNotation == b.usePeriodicNotation &&
      a.announceExpression == b.announceExpression &&
      a.readStatsMemoryValues == b.readStatsMemoryValues &&
      a.autoReadStatsSummary == b.autoReadStatsSummary &&
      a.showStatsNavigationHint == b.showStatsNavigationHint &&
      a.alignInputLeft == b.alignInputLeft &&
      a.overlineThickness == b.overlineThickness &&
      a.overlineHeight == b.overlineHeight &&
      a.speechRate == b.speechRate &&
      a.speechVolume == b.speechVolume &&
      a.ttsEnabled == b.ttsEnabled &&
      a.inverseFormatPreference == b.inverseFormatPreference;
}
