part of 'main.dart';

enum QuickSetupPreset { standard, blind, lowVision, custom }

class QuickSetupDraft {
  final AccessibilitySettings settings;
  final GlobalSettings globalSettings;
  final bool isDegreeMode;
  final CalculatorMode defaultMode;
  final ResultNotationPreference resultNotationPreference;

  const QuickSetupDraft({
    required this.settings,
    required this.globalSettings,
    required this.isDegreeMode,
    required this.defaultMode,
    required this.resultNotationPreference,
  });

  ThemeMode get themeMode => globalSettings.themeMode;
  ResultDisplayMode get resultDisplayMode => globalSettings.resultDisplayMode;
  bool get announceFractionAvailability =>
      globalSettings.announceFractionAvailability;

  factory QuickSetupDraft.fromRuntime({
    required AccessibilitySettings settings,
    required GlobalSettings globalSettings,
    required bool isDegreeMode,
    required CalculatorMode defaultMode,
    required ResultNotationPreference resultNotationPreference,
  }) => QuickSetupDraft(
    settings: settings.copyWith(),
    globalSettings: globalSettings.copyWith(),
    isDegreeMode: isDegreeMode,
    defaultMode: defaultMode,
    resultNotationPreference: resultNotationPreference,
  );

  factory QuickSetupDraft.defaults() => QuickSetupDraft(
    settings: AccessibilitySettings.defaultsStandard(),
    globalSettings: GlobalSettings.defaults(),
    isDegreeMode: true,
    defaultMode: CalculatorMode.scientific,
    resultNotationPreference: ResultNotationPreference.decimal,
  );

  QuickSetupDraft copyWith({
    AccessibilitySettings? settings,
    GlobalSettings? globalSettings,
    ThemeMode? themeMode,
    bool? isDegreeMode,
    CalculatorMode? defaultMode,
    ResultDisplayMode? resultDisplayMode,
    ResultNotationPreference? resultNotationPreference,
    bool? announceFractionAvailability,
  }) {
    var nextGlobal = globalSettings ?? this.globalSettings.copyWith();
    if (themeMode != null)
      nextGlobal = nextGlobal.copyWith(themeMode: themeMode);
    if (resultDisplayMode != null) {
      nextGlobal = nextGlobal.copyWith(resultDisplayMode: resultDisplayMode);
    }
    if (announceFractionAvailability != null) {
      nextGlobal = nextGlobal.copyWith(
        announceFractionAvailability: announceFractionAvailability,
      );
    }
    return QuickSetupDraft(
      settings: settings ?? this.settings.copyWith(),
      globalSettings: nextGlobal,
      isDegreeMode: isDegreeMode ?? this.isDegreeMode,
      defaultMode: defaultMode ?? this.defaultMode,
      resultNotationPreference:
          resultNotationPreference ?? this.resultNotationPreference,
    );
  }

  QuickSetupDraft applyPreset(QuickSetupPreset preset) {
    switch (preset) {
      case QuickSetupPreset.standard:
        return copyWith(settings: AccessibilitySettings.defaultsStandard());
      case QuickSetupPreset.blind:
        return copyWith(settings: AccessibilitySettings.defaultsBlind());
      case QuickSetupPreset.lowVision:
        return copyWith(settings: AccessibilitySettings.defaultsLowVision());
      case QuickSetupPreset.custom:
        return this;
    }
  }

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

bool _sameSettings(AccessibilitySettings a, AccessibilitySettings b) =>
    a.accessibilityType == b.accessibilityType &&
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
    a.inverseFormatPreference == b.inverseFormatPreference;
