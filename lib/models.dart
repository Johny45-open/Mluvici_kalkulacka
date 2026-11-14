part of 'main.dart';

enum CalculatorMode {
  basic,
  scientific,
  statistics,
  electrician,
  unitConversion,
  time,
  currency,
}

class _TimeInputException implements Exception {
  final String message;

  const _TimeInputException(this.message);

  @override
  String toString() => message;
}

enum AccessibilityType { none, blind, visuallyImpaired }

class AccessibilitySettings {
  final AccessibilityType accessibilityType;
  final ScreenReaderMode screenReaderMode;
  final double fontSizeMultiplier;
  final double dialogFontScale;
  final double dotMatrixZoom;
  final double resultZoom;
  final ThousandGroupGap thousandGroupGap;
  final DialogSize dialogSize;
  final bool useSixteenSegment;
  final bool usePeriodicNotation;
  final bool announceExpression;
  final bool announceFractionAvailability;
  final bool readStatsMemoryValues;
  final bool autoReadStatsSummary;
  final bool showStatsNavigationHint;
  final bool alignInputLeft;
  final double overlineThickness;
  final double overlineHeight;
  final double speechRate;
  final double speechVolume;
  final bool ttsEnabled;
  final ResultDisplayMode resultDisplayMode;
  final String? ttsEngine;
  final Map<String, String>? ttsVoice;
  final String? ttsVoiceName;
  final int? inverseFormatPreference;

  const AccessibilitySettings({
    required this.accessibilityType,
    required this.screenReaderMode,
    required this.fontSizeMultiplier,
    required this.dialogFontScale,
    required this.dotMatrixZoom,
    required this.resultZoom,
    required this.thousandGroupGap,
    required this.dialogSize,
    required this.useSixteenSegment,
    required this.usePeriodicNotation,
    required this.announceExpression,
    required this.announceFractionAvailability,
    required this.readStatsMemoryValues,
    required this.autoReadStatsSummary,
    required this.showStatsNavigationHint,
    required this.alignInputLeft,
    required this.overlineThickness,
    required this.overlineHeight,
    required this.speechRate,
    required this.speechVolume,
    required this.ttsEnabled,
    required this.resultDisplayMode,
    this.ttsEngine,
    this.ttsVoice,
    this.ttsVoiceName,
    this.inverseFormatPreference,
  });

  factory AccessibilitySettings.defaultsStandard() {
    return AccessibilitySettings(
      accessibilityType: AccessibilityType.none,
      screenReaderMode: ScreenReaderMode.auto,
      fontSizeMultiplier: 1.0,
      dialogFontScale: 1.0,
      dotMatrixZoom: 1.0,
      resultZoom: 1.0,
      thousandGroupGap: ThousandGroupGap.medium,
      dialogSize: DialogSize.compact,
      useSixteenSegment: false,
      usePeriodicNotation: true,
      announceExpression: false,
      announceFractionAvailability: true,
      readStatsMemoryValues: true,
      autoReadStatsSummary: true,
      showStatsNavigationHint: true,
      alignInputLeft: true,
      overlineThickness: 1.0,
      overlineHeight: 1.0,
      speechRate: 0.5,
      speechVolume: 1.0,
      ttsEnabled: true,
      resultDisplayMode: ResultDisplayMode.segment,
      ttsEngine: null,
      ttsVoice: null,
      ttsVoiceName: null,
      inverseFormatPreference: null,
    );
  }

  factory AccessibilitySettings.defaultsBlind() {
    return AccessibilitySettings(
      accessibilityType: AccessibilityType.blind,
      screenReaderMode: ScreenReaderMode.auto,
      fontSizeMultiplier: 1.0,
      dialogFontScale: 1.0,
      dotMatrixZoom: 1.0,
      resultZoom: 1.0,
      thousandGroupGap: ThousandGroupGap.medium,
      dialogSize: DialogSize.compact,
      useSixteenSegment: false,
      usePeriodicNotation: true,
      announceExpression: true,
      announceFractionAvailability: true,
      readStatsMemoryValues: true,
      autoReadStatsSummary: true,
      showStatsNavigationHint: true,
      alignInputLeft: true,
      overlineThickness: 1.0,
      overlineHeight: 1.0,
      speechRate: 0.5,
      speechVolume: 1.0,
      ttsEnabled: true,
      resultDisplayMode: ResultDisplayMode.segment,
      ttsEngine: null,
      ttsVoice: null,
      ttsVoiceName: null,
      inverseFormatPreference: null,
    );
  }

  factory AccessibilitySettings.defaultsLowVision() {
    return AccessibilitySettings(
      accessibilityType: AccessibilityType.visuallyImpaired,
      screenReaderMode: ScreenReaderMode.auto,
      fontSizeMultiplier: 1.75,
      dialogFontScale: 1.5,
      dotMatrixZoom: 1.25,
      resultZoom: 1.25,
      thousandGroupGap: ThousandGroupGap.large,
      dialogSize: DialogSize.wide,
      useSixteenSegment: true,
      usePeriodicNotation: true,
      announceExpression: false,
      announceFractionAvailability: true,
      readStatsMemoryValues: true,
      autoReadStatsSummary: true,
      showStatsNavigationHint: true,
      alignInputLeft: true,
      overlineThickness: 1.0,
      overlineHeight: 1.0,
      speechRate: 0.5,
      speechVolume: 1.0,
      ttsEnabled: true,
      resultDisplayMode: ResultDisplayMode.segment,
      ttsEngine: null,
      ttsVoice: null,
      ttsVoiceName: null,
      inverseFormatPreference: null,
    );
  }

  AccessibilitySettings copyWith({
    AccessibilityType? accessibilityType,
    ScreenReaderMode? screenReaderMode,
    double? fontSizeMultiplier,
    double? dialogFontScale,
    double? dotMatrixZoom,
    double? resultZoom,
    ThousandGroupGap? thousandGroupGap,
    DialogSize? dialogSize,
    bool? useSixteenSegment,
    bool? usePeriodicNotation,
    bool? announceExpression,
    bool? announceFractionAvailability,
    bool? readStatsMemoryValues,
    bool? autoReadStatsSummary,
    bool? showStatsNavigationHint,
    bool? alignInputLeft,
    double? overlineThickness,
    double? overlineHeight,
    double? speechRate,
    double? speechVolume,
    bool? ttsEnabled,
    ResultDisplayMode? resultDisplayMode,
    String? ttsEngine,
    bool clearTtsEngine = false,
    Map<String, String>? ttsVoice,
    bool clearTtsVoice = false,
    String? ttsVoiceName,
    bool clearTtsVoiceName = false,
    int? inverseFormatPreference,
    bool clearInverseFormatPreference = false,
  }) {
    return AccessibilitySettings(
      accessibilityType: accessibilityType ?? this.accessibilityType,
      screenReaderMode: screenReaderMode ?? this.screenReaderMode,
      fontSizeMultiplier: fontSizeMultiplier ?? this.fontSizeMultiplier,
      dialogFontScale: dialogFontScale ?? this.dialogFontScale,
      dotMatrixZoom: dotMatrixZoom ?? this.dotMatrixZoom,
      resultZoom: resultZoom ?? this.resultZoom,
      thousandGroupGap: thousandGroupGap ?? this.thousandGroupGap,
      dialogSize: dialogSize ?? this.dialogSize,
      useSixteenSegment: useSixteenSegment ?? this.useSixteenSegment,
      usePeriodicNotation: usePeriodicNotation ?? this.usePeriodicNotation,
      announceExpression: announceExpression ?? this.announceExpression,
      announceFractionAvailability:
          announceFractionAvailability ?? this.announceFractionAvailability,
      readStatsMemoryValues:
          readStatsMemoryValues ?? this.readStatsMemoryValues,
      autoReadStatsSummary: autoReadStatsSummary ?? this.autoReadStatsSummary,
      showStatsNavigationHint:
          showStatsNavigationHint ?? this.showStatsNavigationHint,
      alignInputLeft: alignInputLeft ?? this.alignInputLeft,
      overlineThickness: overlineThickness ?? this.overlineThickness,
      overlineHeight: overlineHeight ?? this.overlineHeight,
      speechRate: speechRate ?? this.speechRate,
      speechVolume: speechVolume ?? this.speechVolume,
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
      resultDisplayMode: resultDisplayMode ?? this.resultDisplayMode,
      ttsEngine: clearTtsEngine ? null : (ttsEngine ?? this.ttsEngine),
      ttsVoice: clearTtsVoice
          ? null
          : (ttsVoice != null
                ? Map<String, String>.from(ttsVoice)
                : (this.ttsVoice != null
                      ? Map<String, String>.from(this.ttsVoice!)
                      : null)),
      ttsVoiceName: clearTtsVoiceName
          ? null
          : (ttsVoiceName ?? this.ttsVoiceName),
      inverseFormatPreference: clearInverseFormatPreference
          ? null
          : (inverseFormatPreference ?? this.inverseFormatPreference),
    );
  }

  // resultDisplayMode je GLOBÁLNÍ nastavení aplikace (viz
  // _CalculatorScreenState._globalResultDisplayMode). Do profilu se již
  // nezapisuje; fromJson ho dál čte pouze pro jednorázovou migraci
  // starých profilů. Runtime ho nikdy nesmí číst z profilu.
  Map<String, dynamic> toJson() => {
    'accessibilityType': accessibilityType.index,
    'screenReaderMode': screenReaderMode.index,
    'fontSizeMultiplier': fontSizeMultiplier,
    'dialogFontScale': dialogFontScale,
    'dotMatrixZoom': dotMatrixZoom,
    'resultZoom': resultZoom,
    'thousandGroupGap': thousandGroupGap.index,
    'dialogSize': dialogSize.index,
    'useSixteenSegment': useSixteenSegment,
    'usePeriodicNotation': usePeriodicNotation,
    'announceExpression': announceExpression,
    'announceFractionAvailability': announceFractionAvailability,
    'readStatsMemoryValues': readStatsMemoryValues,
    'autoReadStatsSummary': autoReadStatsSummary,
    'showStatsNavigationHint': showStatsNavigationHint,
    'alignInputLeft': alignInputLeft,
    'overlineThickness': overlineThickness,
    'overlineHeight': overlineHeight,
    'speechRate': speechRate,
    'speechVolume': speechVolume,
    'ttsEnabled': ttsEnabled,
    'ttsEngine': ttsEngine,
    'ttsVoice': ttsVoice,
    'ttsVoiceName': ttsVoiceName,
    'inverseFormatPreference': inverseFormatPreference,
  };

  factory AccessibilitySettings.fromJson(Map<String, dynamic> json) {
    AccessibilityType parseType(dynamic v) {
      if (v is int && v >= 0 && v < AccessibilityType.values.length) {
        return AccessibilityType.values[v];
      }
      return AccessibilityType.none;
    }

    ScreenReaderMode parseMode(dynamic v) {
      if (v is int && v >= 0 && v < ScreenReaderMode.values.length) {
        return ScreenReaderMode.values[v];
      }
      return ScreenReaderMode.auto;
    }

    ThousandGroupGap parseGap(dynamic v) {
      if (v is int && v >= 0 && v < ThousandGroupGap.values.length) {
        return ThousandGroupGap.values[v];
      }
      return ThousandGroupGap.medium;
    }

    DialogSize parseSize(dynamic v) {
      if (v is int && v >= 0 && v < DialogSize.values.length) {
        return DialogSize.values[v];
      }
      return DialogSize.compact;
    }

    // Chybějící starší klíč nebo neznámá hodnota -> segment (původní vzhled).
    ResultDisplayMode parseResultDisplayMode(dynamic v) {
      if (v is int && v >= 0 && v < ResultDisplayMode.values.length) {
        return ResultDisplayMode.values[v];
      }
      return ResultDisplayMode.segment;
    }

    Map<String, String>? parseVoice(dynamic v) {
      if (v == null) return null;
      if (v is Map) {
        try {
          return Map<String, String>.from(
            v.map((k, val) => MapEntry(k.toString(), val.toString())),
          );
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    return AccessibilitySettings(
      accessibilityType: parseType(json['accessibilityType']),
      screenReaderMode: parseMode(json['screenReaderMode']),
      fontSizeMultiplier:
          (json['fontSizeMultiplier'] as num?)?.toDouble() ?? 1.0,
      dialogFontScale: (json['dialogFontScale'] as num?)?.toDouble() ?? 1.0,
      dotMatrixZoom: (json['dotMatrixZoom'] as num?)?.toDouble() ?? 1.0,
      resultZoom: (json['resultZoom'] as num?)?.toDouble() ?? 1.0,
      thousandGroupGap: parseGap(json['thousandGroupGap']),
      dialogSize: parseSize(json['dialogSize']),
      useSixteenSegment: json['useSixteenSegment'] as bool? ?? false,
      usePeriodicNotation: json['usePeriodicNotation'] as bool? ?? true,
      announceExpression: json['announceExpression'] as bool? ?? false,
      announceFractionAvailability:
          json['announceFractionAvailability'] as bool? ?? true,
      readStatsMemoryValues: json['readStatsMemoryValues'] as bool? ?? true,
      autoReadStatsSummary: json['autoReadStatsSummary'] as bool? ?? true,
      showStatsNavigationHint: json['showStatsNavigationHint'] as bool? ?? true,
      alignInputLeft: json['alignInputLeft'] as bool? ?? true,
      overlineThickness: (json['overlineThickness'] as num?)?.toDouble() ?? 1.0,
      overlineHeight: (json['overlineHeight'] as num?)?.toDouble() ?? 1.0,
      speechRate: (json['speechRate'] as num?)?.toDouble() ?? 0.5,
      speechVolume: (json['speechVolume'] as num?)?.toDouble() ?? 1.0,
      ttsEnabled: json['ttsEnabled'] as bool? ?? true,
      resultDisplayMode: parseResultDisplayMode(json['resultDisplayMode']),
      ttsEngine: json['ttsEngine'] as String?,
      ttsVoice: parseVoice(json['ttsVoice']),
      ttsVoiceName: json['ttsVoiceName'] as String?,
      inverseFormatPreference: (json['inverseFormatPreference'] as num?)
          ?.toInt(),
    );
  }
}

class AccessibilityProfile {
  final String id;
  final String name;
  final AccessibilitySettings settings;
  final bool isBuiltIn;

  AccessibilityProfile({
    required this.id,
    required this.name,
    required this.settings,
    this.isBuiltIn = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isBuiltIn': isBuiltIn,
    'settings': settings.toJson(),
  };

  factory AccessibilityProfile.fromJson(Map<String, dynamic> json) {
    final rawSettings = json['settings'];
    AccessibilitySettings parsedSettings;
    if (rawSettings is Map<String, dynamic>) {
      parsedSettings = AccessibilitySettings.fromJson(rawSettings);
    } else if (rawSettings is Map) {
      parsedSettings = AccessibilitySettings.fromJson(
        Map<String, dynamic>.from(rawSettings),
      );
    } else {
      parsedSettings = AccessibilitySettings.defaultsStandard();
    }
    return AccessibilityProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      settings: parsedSettings,
    );
  }

  AccessibilityProfile copyWith({
    String? name,
    AccessibilitySettings? settings,
    bool? isBuiltIn,
  }) {
    return AccessibilityProfile(
      id: id,
      name: name ?? this.name,
      settings: settings != null
          ? settings.copyWith()
          : this.settings.copyWith(),
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }
}

// Globální volba zobrazení částečně odmocněných výsledků v historii.
// numeric = vždy číselně (původní chování), exact = exaktně (6√2) pokud existuje.
enum HistoryExactFormat { numeric, exact }

// Jeden záznam historie výpočtů. Ukládá VÝHRADNĚ strukturovaná data,
// nikdy předformátovaný text — vizuální tvar vzniká až při renderu
// voláním formatSurd(), resp. Rational.toDisplayString(). numericResult je
// zdrojem pravdy pro ANS, vkládání i další výpočty; exact* i rational*
// jsou nullable metadata. Starý záznam bez metadat nikdy nedostává
// dodatečný přesný tvar odvozený z double.
class CalculationHistoryEntry {
  final String expression;
  final String numericResult;
  final double? resultDouble;
  final int? exactCoef;
  final int? exactRadicand;
  final int? exactIndex;
  // Přesná racionální hodnota jako desetinné řetězce BigInt (JSON-safe).
  final String? rationalNum;
  final String? rationalDen;

  const CalculationHistoryEntry({
    required this.expression,
    required this.numericResult,
    this.resultDouble,
    this.exactCoef,
    this.exactRadicand,
    this.exactIndex,
    this.rationalNum,
    this.rationalDen,
  });

  /// Exaktní tvar jako SurdValue, nebo null pokud neexistuje.
  SurdValue? get exact {
    final c = exactCoef;
    final r = exactRadicand;
    final i = exactIndex;
    if (c == null || r == null || i == null) return null;
    return SurdValue(coefficient: c, radicand: r, index: i);
  }

  /// Exaktní racionální tvar, nebo null pokud neexistuje.
  /// Nikdy se neodvozuje z resultDouble ani z textu výsledku.
  Rational? get rational => Rational.tryParseStorage(rationalNum, rationalDen);

  /// Nový záznam je autoritativní (exact/rational explicitně rozhodnut).
  /// Starý záznam (legacy exp|res) má resultDouble null a metadata null —
  /// pouze pro něj se smí použít trySurdFromExpression() jako fallback.
  bool get isLegacyExactUnknown =>
      resultDouble == null && exact == null && rational == null;

  factory CalculationHistoryEntry.fromSurd(
    String expression,
    String numericResult, {
    SurdValue? surd,
    Rational? rational,
    double? numericValue,
  }) {
    return CalculationHistoryEntry(
      expression: expression,
      numericResult: numericResult,
      resultDouble: numericValue,
      exactCoef: surd?.coefficient,
      exactRadicand: surd?.radicand,
      exactIndex: surd?.index,
      rationalNum: rational?.numerator.toString(),
      rationalDen: rational?.denominator.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'v': 1,
    'exp': expression,
    'res': numericResult,
    if (resultDouble != null) 'dbl': resultDouble,
    if (exactCoef != null) 'c': exactCoef,
    if (exactRadicand != null) 'r': exactRadicand,
    if (exactIndex != null) 'i': exactIndex,
    if (rationalNum != null) 'rn': rationalNum,
    if (rationalDen != null) 'rd': rationalDen,
  };

  factory CalculationHistoryEntry.fromJson(Map<String, dynamic> json) {
    int? asInt(dynamic v) =>
        v is int ? v : (v is num ? v.toInt() : int.tryParse('$v'));
    double? asDouble(dynamic v) =>
        v is double ? v : (v is num ? v.toDouble() : double.tryParse('$v'));
    String? asString(dynamic v) => v?.toString();
    return CalculationHistoryEntry(
      expression: json['exp'] as String? ?? '',
      numericResult: json['res'] as String? ?? '',
      resultDouble: asDouble(json['dbl']),
      exactCoef: asInt(json['c']),
      exactRadicand: asInt(json['r']),
      exactIndex: asInt(json['i']),
      rationalNum: asString(json['rn']),
      rationalDen: asString(json['rd']),
    );
  }

  /// Serializace do StringList 'history': nový JSON tvar, jinak legacy.
  String toStorageString() {
    // Záznam s metadaty (nebo číselnou hodnotou) -> JSON; čistý
    // textový záznam bez metadat -> legacy exp|res pro čitelnost zálohy.
    if (resultDouble != null || exact != null || rational != null) {
      return jsonEncode(toJson());
    }
    return '$expression|$numericResult';
  }

  /// Zpětně kompatibilní čtení: JSON, legacy exp|res, staré exp=res.
  factory CalculationHistoryEntry.fromStorageString(String raw) {
    final t = raw.trim();
    if (t.startsWith('{')) {
      try {
        final decoded = jsonDecode(t);
        if (decoded is Map<String, dynamic>) {
          return CalculationHistoryEntry.fromJson(decoded);
        }
        if (decoded is Map) {
          return CalculationHistoryEntry.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      } catch (_) {
        // pád na legacy parse níže
      }
    }
    if (t.contains('|')) {
      final idx = t.indexOf('|');
      return CalculationHistoryEntry(
        expression: t.substring(0, idx),
        numericResult: t.substring(idx + 1),
      );
    }
    if (t.contains('=')) {
      final idx = t.lastIndexOf('=');
      return CalculationHistoryEntry(
        expression: t.substring(0, idx).trim(),
        numericResult: t.substring(idx + 1).trim(),
      );
    }
    return CalculationHistoryEntry(expression: t, numericResult: '');
  }
}

/// Čisté parsování persistované historie (nový JSON i legacy
/// exp|res / exp=res). Vadný záznam nesmí shodit celou historii.
List<CalculationHistoryEntry> parseHistoryStrings(List<String> raw) {
  final parsed = <CalculationHistoryEntry>[];
  for (final s in raw) {
    try {
      parsed.add(CalculationHistoryEntry.fromStorageString(s));
    } catch (_) {
      continue;
    }
  }
  return parsed;
}

enum DisplayFormat { standard, fix, sci, eng }

enum ElectricianCalculation { voltage, current, resistance }

enum ScreenReaderMode { auto, on, off }

/// Kategorie aplikačního accessibility oznámení (R-architektura).
/// Jedna významná uživatelská akce → jedno oznámení právě jedním kanálem.
enum SpeechCategory {
  /// Změna editované hodnoty (číslice, operátor) – při aktivní čtečce
  /// explicitně publikováno Semantics kanálem (dedikovaný oznamovací
  /// liveRegion), bez vlastního TTS. Není odvoditelné od změny textu
  /// displeje (ta není live region), proto se publikuje vždy.
  valueChange,

  /// Potvrzení akce (výsledek, uložení, převod) – vždy právě jedna hláška.
  actionConfirm,

  /// Chyba – musí projít i při aktivní čtečce (jejím kanálem, ne TTS).
  error,

  /// Navigační změna (režim, vědecká stránka, dialog).
  navigation,

  /// Změna nastavení (hlasitost, zoom, profil, pořadí).
  settings,
}

enum DialogSize { compact, wide, fullscreen }

enum StatsSummarySection { header, dataValues, computed }

enum StatsComputedItem {
  mean,
  sum,
  variance,
  sd,
  median,
  min,
  max,
  mode,
  cv,
  wmean,
  wvar,
  wsd,
  wcv,
  sampleVariance,
  sampleSd,
  range,
  q1,
  q3,
  iqr,
  meanAbsoluteDeviation,
  geometricMean,
  harmonicMean,
  populationSkewness,
  sampleSkewness,
  populationExcessKurtosis,
  sampleExcessKurtosis,
}

enum StatsDisplayPreset { basic, extended, complete, custom }

enum StatsItemCategory { basic, advanced }

enum StatsUnitKind { sameAsData, squared, percent, dimensionless }

class StatsItemDefinition {
  final StatsComputedItem id;
  final String nameCs;
  final String nameEn;
  final String descriptionCs;
  final String descriptionEn;
  final StatsItemCategory category;
  final StatsUnitKind unit;
  final bool inBasic;
  final bool inExtended;
  final bool defaultVisible;
  final bool isAvailable;
  final bool requiresTwoFields;
  final String? domainCs;
  final String? domainEn;

  const StatsItemDefinition({
    required this.id,
    required this.nameCs,
    required this.nameEn,
    required this.descriptionCs,
    required this.descriptionEn,
    required this.category,
    required this.unit,
    required this.inBasic,
    required this.inExtended,
    required this.defaultVisible,
    this.isAvailable = true,
    this.requiresTwoFields = false,
    this.domainCs,
    this.domainEn,
  });

  String get stableId => id.name;
  String name(bool english) => english ? nameEn : nameCs;
  String description(bool english) => english ? descriptionEn : descriptionCs;

  bool visibleIn(StatsDisplayPreset preset) {
    switch (preset) {
      case StatsDisplayPreset.basic:
        return inBasic;
      case StatsDisplayPreset.extended:
        return inBasic || inExtended;
      case StatsDisplayPreset.complete:
        return true;
      case StatsDisplayPreset.custom:
        return false;
    }
  }
}

class StatsCatalog {
  static const List<StatsItemDefinition> definitions = [
    StatsItemDefinition(
      id: StatsComputedItem.mean,
      nameCs: 'Průměr',
      nameEn: 'Mean',
      descriptionCs: 'Aritmetický průměr',
      descriptionEn: 'Arithmetic mean',
      category: StatsItemCategory.basic,
      unit: StatsUnitKind.sameAsData,
      inBasic: true,
      inExtended: false,
      defaultVisible: true,
    ),
    StatsItemDefinition(
      id: StatsComputedItem.sum,
      nameCs: 'Součet',
      nameEn: 'Sum',
      descriptionCs: 'Součet hodnot',
      descriptionEn: 'Sum of values',
      category: StatsItemCategory.basic,
      unit: StatsUnitKind.sameAsData,
      inBasic: true,
      inExtended: false,
      defaultVisible: true,
    ),
    StatsItemDefinition(
      id: StatsComputedItem.variance,
      nameCs: 'Rozptyl',
      nameEn: 'Variance',
      descriptionCs: 'Populační rozptyl',
      descriptionEn: 'Population variance',
      category: StatsItemCategory.basic,
      unit: StatsUnitKind.squared,
      inBasic: true,
      inExtended: false,
      defaultVisible: true,
    ),
    StatsItemDefinition(
      id: StatsComputedItem.sd,
      nameCs: 'Směrodatná odchylka',
      nameEn: 'Standard deviation',
      descriptionCs: 'Populační směrodatná odchylka',
      descriptionEn: 'Population standard deviation',
      category: StatsItemCategory.basic,
      unit: StatsUnitKind.sameAsData,
      inBasic: true,
      inExtended: false,
      defaultVisible: true,
    ),
    StatsItemDefinition(
      id: StatsComputedItem.median,
      nameCs: 'Medián (Q2)',
      nameEn: 'Median (Q2)',
      descriptionCs: 'Medián, druhý kvartil',
      descriptionEn: 'Median, second quartile',
      category: StatsItemCategory.basic,
      unit: StatsUnitKind.sameAsData,
      inBasic: true,
      inExtended: false,
      defaultVisible: true,
    ),
    StatsItemDefinition(
      id: StatsComputedItem.min,
      nameCs: 'Minimum',
      nameEn: 'Minimum',
      descriptionCs: 'Nejmenší hodnota',
      descriptionEn: 'Smallest value',
      category: StatsItemCategory.basic,
      unit: StatsUnitKind.sameAsData,
      inBasic: true,
      inExtended: false,
      defaultVisible: true,
    ),
    StatsItemDefinition(
      id: StatsComputedItem.max,
      nameCs: 'Maximum',
      nameEn: 'Maximum',
      descriptionCs: 'Největší hodnota',
      descriptionEn: 'Largest value',
      category: StatsItemCategory.basic,
      unit: StatsUnitKind.sameAsData,
      inBasic: true,
      inExtended: false,
      defaultVisible: true,
    ),
    StatsItemDefinition(
      id: StatsComputedItem.mode,
      nameCs: 'Modus',
      nameEn: 'Mode',
      descriptionCs: 'Nejčastější hodnota',
      descriptionEn: 'Most frequent value',
      category: StatsItemCategory.basic,
      unit: StatsUnitKind.sameAsData,
      inBasic: true,
      inExtended: false,
      defaultVisible: true,
    ),
    StatsItemDefinition(
      id: StatsComputedItem.cv,
      nameCs: 'Variační koeficient',
      nameEn: 'Coefficient of variation',
      descriptionCs: 'Směrodatná odchylka v procentech absolutního průměru',
      descriptionEn: 'Standard deviation as a percentage of the absolute mean',
      category: StatsItemCategory.advanced,
      unit: StatsUnitKind.percent,
      inBasic: false,
      inExtended: true,
      defaultVisible: false,
      requiresTwoFields: true,
    ),
    StatsItemDefinition(
      id: StatsComputedItem.wmean,
      nameCs: 'Vážený průměr',
      nameEn: 'Weighted mean',
      descriptionCs: 'Vážený průměr (2 pole)',
      descriptionEn: 'Weighted mean (2 fields)',
      category: StatsItemCategory.advanced,
      unit: StatsUnitKind.sameAsData,
      inBasic: false,
      inExtended: true,
      defaultVisible: false,
      requiresTwoFields: true,
    ),
    StatsItemDefinition(
      id: StatsComputedItem.wvar,
      nameCs: 'Vážený rozptyl',
      nameEn: 'Weighted variance',
      descriptionCs: 'Populační rozptyl vážený druhým polem',
      descriptionEn: 'Population variance weighted by the second field',
      category: StatsItemCategory.advanced,
      unit: StatsUnitKind.squared,
      inBasic: false,
      inExtended: true,
      defaultVisible: false,
      requiresTwoFields: true,
    ),
    StatsItemDefinition(
      id: StatsComputedItem.wsd,
      nameCs: 'Vážená směrodatná odchylka',
      nameEn: 'Weighted standard deviation',
      descriptionCs: 'Odmocnina z váženého rozptylu',
      descriptionEn: 'Square root of weighted variance',
      category: StatsItemCategory.advanced,
      unit: StatsUnitKind.sameAsData,
      inBasic: false,
      inExtended: true,
      defaultVisible: false,
      requiresTwoFields: true,
    ),
    StatsItemDefinition(
      id: StatsComputedItem.wcv,
      nameCs: 'Vážený variační koeficient',
      nameEn: 'Weighted coefficient of variation',
      descriptionCs: 'Vážená odchylka v procentech absolutního průměru',
      descriptionEn: 'Weighted deviation as a percentage of the absolute mean',
      category: StatsItemCategory.advanced,
      unit: StatsUnitKind.percent,
      inBasic: false,
      inExtended: true,
      defaultVisible: false,
    ),
    StatsItemDefinition(
      id: StatsComputedItem.sampleVariance,
      nameCs: 'Výběrový rozptyl',
      nameEn: 'Sample variance',
      descriptionCs: 'Výběrový rozptyl s jmenovatelem n−1',
      descriptionEn: 'Sample variance with denominator n−1',
      category: StatsItemCategory.advanced,
      unit: StatsUnitKind.squared,
      inBasic: false,
      inExtended: true,
      defaultVisible: false,
    ),
    StatsItemDefinition(
      id: StatsComputedItem.sampleSd,
      nameCs: 'Výběrová směrodatná odchylka',
      nameEn: 'Sample standard deviation',
      descriptionCs: 'Odmocnina z výběrového rozptylu',
      descriptionEn: 'Square root of sample variance',
      category: StatsItemCategory.advanced,
      unit: StatsUnitKind.sameAsData,
      inBasic: false,
      inExtended: true,
      defaultVisible: false,
    ),
    StatsItemDefinition(
      id: StatsComputedItem.range,
      nameCs: 'Rozpětí',
      nameEn: 'Range',
      descriptionCs: 'Maximum minus minimum',
      descriptionEn: 'Maximum minus minimum',
      category: StatsItemCategory.basic,
      unit: StatsUnitKind.sameAsData,
      inBasic: true,
      inExtended: false,
      defaultVisible: true,
    ),
    StatsItemDefinition(
      id: StatsComputedItem.q1,
      nameCs: 'První kvartil (Q1)',
      nameEn: 'First quartile (Q1)',
      descriptionCs: '25. percentil, metoda R-7',
      descriptionEn: '25th percentile, R-7 method',
      category: StatsItemCategory.advanced,
      unit: StatsUnitKind.sameAsData,
      inBasic: false,
      inExtended: true,
      defaultVisible: false,
    ),
    StatsItemDefinition(
      id: StatsComputedItem.q3,
      nameCs: 'Třetí kvartil (Q3)',
      nameEn: 'Third quartile (Q3)',
      descriptionCs: '75. percentil, metoda R-7',
      descriptionEn: '75th percentile, R-7 method',
      category: StatsItemCategory.advanced,
      unit: StatsUnitKind.sameAsData,
      inBasic: false,
      inExtended: true,
      defaultVisible: false,
    ),
    StatsItemDefinition(
      id: StatsComputedItem.iqr,
      nameCs: 'Mezikvartilové rozpětí (IQR)',
      nameEn: 'Interquartile range (IQR)',
      descriptionCs: 'Rozdíl Q3 a Q1',
      descriptionEn: 'Difference between Q3 and Q1',
      category: StatsItemCategory.advanced,
      unit: StatsUnitKind.sameAsData,
      inBasic: false,
      inExtended: true,
      defaultVisible: false,
    ),
    StatsItemDefinition(
      id: StatsComputedItem.meanAbsoluteDeviation,
      nameCs: 'Průměrná absolutní odchylka',
      nameEn: 'Mean absolute deviation',
      descriptionCs: 'Průměrná absolutní odchylka od aritmetického průměru',
      descriptionEn: 'Mean absolute deviation from the arithmetic mean',
      category: StatsItemCategory.advanced,
      unit: StatsUnitKind.sameAsData,
      inBasic: false,
      inExtended: true,
      defaultVisible: false,
    ),
    StatsItemDefinition(
      id: StatsComputedItem.geometricMean,
      nameCs: 'Geometrický průměr',
      nameEn: 'Geometric mean',
      descriptionCs: 'Nezáporné hodnoty; nula dává výsledek nula',
      descriptionEn: 'Non-negative values; zero yields zero',
      category: StatsItemCategory.advanced,
      unit: StatsUnitKind.sameAsData,
      inBasic: false,
      inExtended: true,
      defaultVisible: false,
      domainCs: 'Nezáporné hodnoty',
      domainEn: 'Non-negative values',
    ),
    StatsItemDefinition(
      id: StatsComputedItem.harmonicMean,
      nameCs: 'Harmonický průměr',
      nameEn: 'Harmonic mean',
      descriptionCs: 'Pouze kladné hodnoty',
      descriptionEn: 'Positive values only',
      category: StatsItemCategory.advanced,
      unit: StatsUnitKind.sameAsData,
      inBasic: false,
      inExtended: true,
      defaultVisible: false,
      domainCs: 'Kladné hodnoty',
      domainEn: 'Positive values',
    ),
    StatsItemDefinition(
      id: StatsComputedItem.populationSkewness,
      nameCs: 'Populační šikmost',
      nameEn: 'Population skewness',
      descriptionCs: 'Třetí standardizovaný centrální moment',
      descriptionEn: 'Third standardized central moment',
      category: StatsItemCategory.advanced,
      unit: StatsUnitKind.dimensionless,
      inBasic: false,
      inExtended: false,
      defaultVisible: false,
    ),
    StatsItemDefinition(
      id: StatsComputedItem.sampleSkewness,
      nameCs: 'Výběrová šikmost (opravená)',
      nameEn: 'Adjusted sample skewness',
      descriptionCs: 'Výběrově opravená Fisherova–Pearsonova šikmost',
      descriptionEn: 'Adjusted Fisher–Pearson sample skewness',
      category: StatsItemCategory.advanced,
      unit: StatsUnitKind.dimensionless,
      inBasic: false,
      inExtended: false,
      defaultVisible: false,
    ),
    StatsItemDefinition(
      id: StatsComputedItem.populationExcessKurtosis,
      nameCs: 'Populační excess kurtosis',
      nameEn: 'Population excess kurtosis',
      descriptionCs: 'Populační kurtosis minus 3',
      descriptionEn: 'Population kurtosis minus 3',
      category: StatsItemCategory.advanced,
      unit: StatsUnitKind.dimensionless,
      inBasic: false,
      inExtended: false,
      defaultVisible: false,
    ),
    StatsItemDefinition(
      id: StatsComputedItem.sampleExcessKurtosis,
      nameCs: 'Výběrová excess kurtosis (opravená)',
      nameEn: 'Adjusted sample excess kurtosis',
      descriptionCs: 'Výběrově opravený Fisherův excess kurtosis',
      descriptionEn: 'Adjusted Fisher sample excess kurtosis',
      category: StatsItemCategory.advanced,
      unit: StatsUnitKind.dimensionless,
      inBasic: false,
      inExtended: false,
      defaultVisible: false,
    ),
  ];

  static StatsItemDefinition definition(StatsComputedItem item) =>
      definitions.firstWhere((definition) => definition.id == item);

  static List<StatsComputedItem> forPreset(StatsDisplayPreset preset) =>
      definitions
          .where((definition) => definition.visibleIn(preset))
          .map((definition) => definition.id)
          .toList();
}

class CustomPercentile {
  final String id;
  final double p;
  final bool visible;

  const CustomPercentile({
    required this.id,
    required this.p,
    this.visible = true,
  });

  factory CustomPercentile.create(
    double p, {
    Set<String> existingIds = const {},
  }) {
    var id = _generateStatsId();
    while (existingIds.contains(id)) {
      id = _generateStatsId();
    }
    return CustomPercentile(id: id, p: p);
  }

  CustomPercentile copyWith({double? p, bool? visible}) => CustomPercentile(
    id: id,
    p: p ?? this.p,
    visible: visible ?? this.visible,
  );

  Map<String, dynamic> toJson() => {'id': id, 'p': p, 'visible': visible};

  factory CustomPercentile.fromJson(Map<String, dynamic> json) =>
      CustomPercentile(
        id: json['id'] as String,
        p: (json['p'] as num).toDouble(),
        visible: json['visible'] as bool? ?? true,
      );
}

class StatsOrderEntry {
  final StatsComputedItem? fixedItem;
  final String? percentileId;

  const StatsOrderEntry.fixed(this.fixedItem) : percentileId = null;
  const StatsOrderEntry.percentile(this.percentileId) : fixedItem = null;

  Map<String, dynamic> toJson() => fixedItem != null
    ? {
        'kind': 'fixed',
        'id': StatsCatalog.definition(fixedItem!).stableId,
      }
      : {'kind': 'percentile', 'id': percentileId};

  factory StatsOrderEntry.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'];
    final id = json['id'];
    if (kind == 'fixed' && id is String) {
      for (final item in StatsComputedItem.values) {
        if (StatsCatalog.definition(item).stableId == id) {
          return StatsOrderEntry.fixed(item);
        }
      }
    } else if (kind == 'percentile' && id is String) {
      return StatsOrderEntry.percentile(id);
    }
    throw const FormatException('Invalid statistics order entry.');
  }

  @override
  bool operator ==(Object other) =>
      other is StatsOrderEntry &&
      other.fixedItem == fixedItem &&
      other.percentileId == percentileId;

  @override
  int get hashCode => Object.hash(fixedItem, percentileId);
}

List<StatsOrderEntry> normalizeStatsDisplayOrder(
  Iterable<StatsOrderEntry> raw,
  Iterable<CustomPercentile> percentiles,
) {
  final knownPercentileIds = percentiles.map((item) => item.id).toSet();
  final result = <StatsOrderEntry>[];
  for (final entry in raw) {
    final isKnown =
        entry.fixedItem != null ||
        (entry.percentileId != null &&
            knownPercentileIds.contains(entry.percentileId));
    if (isKnown && !result.contains(entry)) result.add(entry);
  }
  for (final item in StatsComputedItem.values) {
    final entry = StatsOrderEntry.fixed(item);
    if (!result.contains(entry)) result.add(entry);
  }
  for (final item in percentiles) {
    final entry = StatsOrderEntry.percentile(item.id);
    if (!result.contains(entry)) result.add(entry);
  }
  return result;
}

class StatsDisplayConfig {
  final StatsDisplayPreset preset;
  final bool customShowN;
  final Set<StatsComputedItem> customVisibleItems;
  final List<CustomPercentile> percentiles;
  final List<StatsOrderEntry> order;

  StatsDisplayConfig({
    required this.preset,
    required this.customShowN,
    required Set<StatsComputedItem> customVisibleItems,
    required List<CustomPercentile> percentiles,
    required List<StatsOrderEntry> order,
  }) : customVisibleItems = Set.unmodifiable(customVisibleItems),
       percentiles = List.unmodifiable(percentiles),
       order = List.unmodifiable(
         normalizeStatsDisplayOrder(order, percentiles),
       );

  factory StatsDisplayConfig.defaults() => StatsDisplayConfig(
    preset: StatsDisplayPreset.basic,
    customShowN: true,
    customVisibleItems: StatsCatalog.forPreset(
      StatsDisplayPreset.basic,
    ).toSet(),
    percentiles: const [],
    order: const [],
  );

  factory StatsDisplayConfig.fromLegacyOrder(
    Iterable<StatsComputedItem> legacyOrder,
  ) {
    const legacyVisibleItems = {
      StatsComputedItem.mean,
      StatsComputedItem.sum,
      StatsComputedItem.variance,
      StatsComputedItem.sd,
      StatsComputedItem.median,
      StatsComputedItem.min,
      StatsComputedItem.max,
      StatsComputedItem.mode,
      StatsComputedItem.cv,
      StatsComputedItem.wmean,
      StatsComputedItem.wvar,
      StatsComputedItem.wsd,
      StatsComputedItem.wcv,
    };
    return StatsDisplayConfig(
      preset: StatsDisplayPreset.custom,
      customShowN: true,
      customVisibleItems: legacyVisibleItems,
      percentiles: const [],
      order: legacyOrder.map(StatsOrderEntry.fixed).toList(),
    );
  }

  bool get showN => preset == StatsDisplayPreset.custom ? customShowN : true;

  Set<StatsComputedItem> get visibleItems => preset == StatsDisplayPreset.custom
      ? customVisibleItems
      : StatsCatalog.forPreset(preset).toSet();

  List<CustomPercentile> get visiblePercentiles => switch (preset) {
    StatsDisplayPreset.basic || StatsDisplayPreset.extended => const [],
    StatsDisplayPreset.complete => percentiles,
    StatsDisplayPreset.custom =>
      percentiles.where((item) => item.visible).toList(),
  };

  Map<String, dynamic> toJson() => {
    'preset': preset.name,
    'customShowN': customShowN,
    'customVisibleItems': customVisibleItems
        .map((item) => StatsCatalog.definition(item).stableId)
        .toList(),
    'percentiles': percentiles.map((item) => item.toJson()).toList(),
    'order': order.map((entry) => entry.toJson()).toList(),
  };

  factory StatsDisplayConfig.fromJson(Map<String, dynamic> json) {
    final presetName = json['preset'];
    final preset = StatsDisplayPreset.values.firstWhere(
      (item) => item.name == presetName,
      orElse: () => StatsDisplayPreset.custom,
    );
    final percentiles = (json['percentiles'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => CustomPercentile.fromJson(Map<String, dynamic>.from(item)),
        )
        .where(
          (item) =>
              item.id.isNotEmpty &&
              item.p.isFinite &&
              item.p >= 0 &&
              item.p <= 100,
        )
        .toList();
    final percentileIds = <String>{};
    final uniquePercentiles = percentiles
        .where((item) => percentileIds.add(item.id))
        .toList();
    final visibleNames = (json['customVisibleItems'] as List? ?? const [])
        .whereType<String>()
        .toSet();
    final visibleItems = StatsCatalog.definitions
        .where((definition) => visibleNames.contains(definition.stableId))
        .map((definition) => definition.id)
        .toSet();
    final rawOrder = (json['order'] as List? ?? const []).whereType<Map>().map((
      item,
    ) {
      try {
        return StatsOrderEntry.fromJson(Map<String, dynamic>.from(item));
      } on FormatException {
        return null;
      }
    }).whereType<StatsOrderEntry>();
    return StatsDisplayConfig(
      preset: preset,
      customShowN: json['customShowN'] as bool? ?? true,
      customVisibleItems: visibleItems,
      percentiles: uniquePercentiles,
      order: rawOrder.toList(),
    );
  }
}

/// Doplň chybějící položky a odstraní duplicity.
///
/// Stará uložená i stará importovaná pořadí mají 10 položek. Po
/// rozšíření enumu se nesmí zahodit – zachová se uživatelské
/// uspořádání a nové vážené položky se připojí na konec (v pořadí
/// enumu). Výsledek je vždy úplné a unikátní pořadí.
List<StatsComputedItem> normalizeStatsComputedOrder(
  Iterable<StatsComputedItem> raw,
) {
  final result = <StatsComputedItem>[];
  for (final item in raw) {
    if (!result.contains(item)) result.add(item);
  }
  for (final item in StatsComputedItem.values) {
    if (!result.contains(item)) result.add(item);
  }
  return result;
}

/// Důvod, proč nelze vážené charakteristiky spočítat.
///
/// Jednotné kategorie chyby pro všechny vážené výpočty – text hlášky
/// se zvolí až v UI, podle aktivního jazyka.
enum WeightedStatsFailure {
  /// Některý záznam nemá hodnotu ani váhu (nebo je pole prázdné).
  missingRecord,

  /// Hodnota nebo váha není konečné číslo (NaN/Infinity).
  nonFinite,

  /// Váha je záporná. Nulová váha je povolena.
  negativeWeight,

  /// Součet vah není větší než nula.
  zeroWeightSum,

  /// Při součtu nebo násobení vzniklo nekonečno.
  overflow,
}

/// Výsledek sdíleného výpočtu vážených charakteristik.
///
/// Všechny čtyři hodnoty vznikají společně po jedné validaci a stabilním
/// průchodu daty, takže mezi nimi nemůže dojít k rozporu. Při chybě jsou všechny hodnoty `null`
/// a [failure] určuje důvod – nikdy se nevrací NaN ani Infinity.
/// WCV může být `null` i při úspěchu, když je vážený průměr nulový.
class WeightedStatsResult {
  final double? wmean;
  final double? wvar;
  final double? wsd;
  final double? wcv;
  final WeightedStatsFailure? failure;

  const WeightedStatsResult({
    this.wmean,
    this.wvar,
    this.wsd,
    this.wcv,
    this.failure,
  });

  bool get isOk => failure == null;
}

/// Vážené charakteristiky: první pole = hodnoty, druhé pole = váhy.
///
/// - μw  = Σ(xᵢ·wᵢ) / Σwᵢ
/// - WVAR = Σ[wᵢ·(xᵢ − μw)²] / Σwᵢ  (populační, stejně jako běžný VAR)
/// - WSD  = √WVAR
/// - WCV  = (WSD / |μw|) · 100 %, při μw = 0 nelze spočítat (null)
///
/// Validace je společná pro všechny čtyři hodnoty: obě pole musí mít
/// stejnou nenulovou délku, všechny hodnoty i váhy musí být konečné,
/// váhy nesmí být záporné (nulová váha je povolena) a součet vah musí
/// být větší než nula. Přetečení při matematických operacích je
/// zachyceno jako [WeightedStatsFailure.overflow].
WeightedStatsResult computeWeightedStats(
  List<double> values,
  List<double> weights,
) {
  if (values.isEmpty || values.length != weights.length) {
    return const WeightedStatsResult(
      failure: WeightedStatsFailure.missingRecord,
    );
  }
  var maxWeight = 0.0;
  var anchor = 0.0;
  var hasAnchor = false;
  var maxDeviation = 0.0;
  var maxAbsValue = 0.0;
  var useCenteredValues = true;
  for (var i = 0; i < values.length; i++) {
    final x = values[i];
    final w = weights[i];
    if (!x.isFinite || !w.isFinite) {
      return const WeightedStatsResult(failure: WeightedStatsFailure.nonFinite);
    }
    if (w < 0) {
      return const WeightedStatsResult(
        failure: WeightedStatsFailure.negativeWeight,
      );
    }
    maxWeight = math.max(maxWeight, w);
    if (w > 0) {
      maxAbsValue = math.max(maxAbsValue, x.abs());
      if (!hasAnchor) {
        anchor = x;
        hasAnchor = true;
      } else {
        final deviation = x - anchor;
        if (deviation.isFinite) {
          maxDeviation = math.max(maxDeviation, deviation.abs());
        } else {
          useCenteredValues = false;
        }
      }
    }
  }
  if (maxWeight == 0) {
    return const WeightedStatsResult(
      failure: WeightedStatsFailure.zeroWeightSum,
    );
  }
  if (useCenteredValues && maxDeviation == 0) {
    return WeightedStatsResult(
      wmean: anchor,
      wvar: 0,
      wsd: 0,
      wcv: anchor == 0 ? null : 0,
    );
  }
  var sumW = 0.0;
  var meanScaled = 0.0;
  var m2Scaled = 0.0;
  final scale = useCenteredValues ? maxDeviation : maxAbsValue;
  for (var i = 0; i < values.length; i++) {
    final weight = weights[i] / maxWeight;
    if (weight == 0) continue;
    final nextSumW = sumW + weight;
    final valueScaled = useCenteredValues
        ? (values[i] - anchor) / scale
        : values[i] / scale;
    final delta = valueScaled - meanScaled;
    final nextMean = meanScaled + delta * (weight / nextSumW);
    m2Scaled += weight * delta * (valueScaled - nextMean);
    sumW = nextSumW;
    meanScaled = nextMean;
    if (!sumW.isFinite || !meanScaled.isFinite || !m2Scaled.isFinite) {
      return const WeightedStatsResult(failure: WeightedStatsFailure.overflow);
    }
  }
  if (sumW <= 0) {
    return const WeightedStatsResult(
      failure: WeightedStatsFailure.zeroWeightSum,
    );
  }
  final wmean = useCenteredValues
      ? anchor + meanScaled * scale
      : meanScaled * scale;
  final varianceScaled = m2Scaled / sumW;
  final sd = math.sqrt(varianceScaled) * scale;
  final varianceIntermediate = varianceScaled * scale;
  final wvar = varianceIntermediate * scale;
  if (!wmean.isFinite ||
      !sd.isFinite ||
      !wvar.isFinite ||
      wvar < 0 ||
      varianceScaled < 0) {
    return const WeightedStatsResult(failure: WeightedStatsFailure.overflow);
  }
  final wcv = wmean == 0 ? null : (sd / wmean.abs()) * 100;
  if (wcv != null && !wcv.isFinite) {
    return const WeightedStatsResult(failure: WeightedStatsFailure.overflow);
  }
  return WeightedStatsResult(wmean: wmean, wvar: wvar, wsd: sd, wcv: wcv);
}

enum StatsOrderPreset { def, valuesFirst, statsFirst, headerLast, custom }

enum ThousandGroupGap { small, medium, large }

class _ElectricianInputException implements Exception {
  final String message;

  const _ElectricianInputException(this.message);

  @override
  String toString() => message;
}

class _MathDomainException implements Exception {
  final String message;

  const _MathDomainException(this.message);

  @override
  String toString() => message;
}

/// Centrální kategorie chyby výpočtu (R1: přesné chyby při výpočtech).
/// Klasifikace je strukturální (vyhodnocený jmenovatel / argument),
/// nikdy se neodvozuje z anglického textu výjimky knihovny.
enum CalcErrorKind {
  divisionByZero,
  syntax,
  domain,
  overflow,
  invalidOperation,
}

/// Přesný důvod chyby uvnitř [CalcErrorKind].
/// Slouží pro přesné hlášky, logy a testy; není klasifikačním mechanismem.
enum CalcErrorReason {
  zeroDenominator,
  zeroToNegativePower,
  sqrtOfNegative,
  logNonPositiveArg,
  logBadBase,
  asinOutOfRange,
  acosOutOfRange,
  tanUndefined,
  overflowInfinite,
  syntaxParens,
  syntaxGeneral,
  unknown,
}

/// Typizovaná chyba výpočtu: kategorie + přesný důvod + debug detail.
/// Debug detail je pouze pro `debugPrint`, nikdy pro klasifikaci ani UI.
class CalcError implements Exception {
  final CalcErrorKind kind;
  final CalcErrorReason reason;
  final String debugDetail;

  const CalcError(this.kind, this.reason, [this.debugDetail = '']);

  @override
  String toString() => 'CalcError($kind, $reason): $debugDetail';
}

class _StatisticsSnapshot {
  final double? sum;
  final double mean;
  final double? variance;
  final double? sd;
  final double median;
  final double min;
  final double max;
  final List<double> modes;
  final int modeOccurrenceCount;
  final bool modeExists;
  final double? cv;
  final double? wmean;
  final double? weightedVariance;
  final double? weightedSd;
  final double? weightedCv;
  final Map<double, int> frequencies;
  final double? sampleVariance;
  final double? sampleSd;
  final double? range;
  final double? q1;
  final double? q3;
  final double? iqr;
  final double? meanAbsoluteDeviation;
  final double? geometricMean;
  final double? harmonicMean;
  final double? populationSkewness;
  final double? sampleSkewness;
  final double? populationExcessKurtosis;
  final double? sampleExcessKurtosis;
  final Map<String, double> customPercentiles;

  const _StatisticsSnapshot({
    required this.sum,
    required this.mean,
    required this.variance,
    required this.sd,
    required this.median,
    required this.min,
    required this.max,
    required this.modes,
    required this.modeOccurrenceCount,
    required this.modeExists,
    required this.cv,
    this.wmean,
    this.weightedVariance,
    this.weightedSd,
    this.weightedCv,
    this.sampleVariance,
    this.sampleSd,
    this.range,
    this.q1,
    this.q3,
    this.iqr,
    this.meanAbsoluteDeviation,
    this.geometricMean,
    this.harmonicMean,
    this.populationSkewness,
    this.sampleSkewness,
    this.populationExcessKurtosis,
    this.sampleExcessKurtosis,
    this.customPercentiles = const {},
    required this.frequencies,
  });
}

class StatisticsRecord {
  final List<double> values;

  StatisticsRecord({required this.values});

  Map<String, dynamic> toJson() => {'values': values};

  factory StatisticsRecord.fromJson(Map<String, dynamic> json) {
    return StatisticsRecord(
      values: (json['values'] as List)
          .map((e) => (e as num).toDouble())
          .toList(),
    );
  }

  StatisticsRecord copyWith({List<double>? values}) {
    return StatisticsRecord(values: values ?? this.values);
  }
}

String _generateStatsId() {
  final ts = DateTime.now().microsecondsSinceEpoch;
  final rnd = math.Random().nextInt(1 << 32);
  return '${ts}_$rnd';
}

class StatisticsFolder {
  String id;
  String name;
  int colorIndex;
  String iconName;
  int sortOrder;
  DateTime createdAt;

  StatisticsFolder({
    required this.id,
    required this.name,
    this.colorIndex = 0,
    this.iconName = 'folder',
    this.sortOrder = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'colorIndex': colorIndex,
    'iconName': iconName,
    'sortOrder': sortOrder,
    'createdAt': createdAt.toIso8601String(),
  };

  factory StatisticsFolder.fromJson(Map<String, dynamic> json) {
    return StatisticsFolder(
      id: json['id'] as String? ?? _generateStatsId(),
      name: json['name'] as String,
      colorIndex: (json['colorIndex'] as num?)?.toInt() ?? 0,
      iconName: json['iconName'] as String? ?? 'folder',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  StatisticsFolder copyWith({
    String? name,
    int? colorIndex,
    String? iconName,
    int? sortOrder,
  }) {
    return StatisticsFolder(
      id: id,
      name: name ?? this.name,
      colorIndex: colorIndex ?? this.colorIndex,
      iconName: iconName ?? this.iconName,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
    );
  }
}

class StatisticsSet {
  String id;
  String name;
  final List<String> fieldNames;
  final List<String?> fieldUnits;
  final List<StatisticsRecord> records;
  DateTime createdAt;
  DateTime updatedAt;
  DateTime lastUsedAt;
  bool pinned;
  bool archived;
  String? folderId;
  int colorIndex;
  String iconName;

  StatisticsSet({
    String? id,
    required this.name,
    required this.fieldNames,
    required this.records,
    List<String?>? fieldUnits,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastUsedAt,
    this.pinned = false,
    this.archived = false,
    this.folderId,
    this.colorIndex = 0,
    this.iconName = 'dataset',
  }) : id = id ?? _generateStatsId(),
       fieldUnits = fieldUnits ?? List.filled(fieldNames.length, null),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now(),
       lastUsedAt = lastUsedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'fieldNames': fieldNames,
    'fieldUnits': fieldUnits,
    'records': records.map((r) => r.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'lastUsedAt': lastUsedAt.toIso8601String(),
    'pinned': pinned,
    'archived': archived,
    'folderId': folderId,
    'colorIndex': colorIndex,
    'iconName': iconName,
  };

  factory StatisticsSet.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('data')) {
      final data = (json['data'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
      return StatisticsSet(
        id: json['id'] as String? ?? _generateStatsId(),
        name: json['name'] as String,
        fieldNames: ['Hodnota'],
        records: data.map((v) => StatisticsRecord(values: [v])).toList(),
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'] as String)
            : null,
        lastUsedAt: json['lastUsedAt'] != null
            ? DateTime.tryParse(json['lastUsedAt'] as String)
            : null,
        pinned: json['pinned'] as bool? ?? false,
        archived: json['archived'] as bool? ?? false,
        folderId: json['folderId'] as String?,
        colorIndex: (json['colorIndex'] as num?)?.toInt() ?? 0,
        iconName: json['iconName'] as String? ?? 'dataset',
      );
    }
    final fieldNames = (json['fieldNames'] as List).cast<String>();
    final fieldUnits = json['fieldUnits'] != null
        ? (json['fieldUnits'] as List).map((e) => e as String?).toList()
        : List<String?>.filled(fieldNames.length, null);
    return StatisticsSet(
      id: json['id'] as String? ?? _generateStatsId(),
      name: json['name'] as String,
      fieldNames: fieldNames,
      fieldUnits: fieldUnits,
      records: (json['records'] as List)
          .map((e) => StatisticsRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.tryParse(json['lastUsedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      pinned: json['pinned'] as bool? ?? false,
      archived: json['archived'] as bool? ?? false,
      folderId: json['folderId'] as String?,
      colorIndex: (json['colorIndex'] as num?)?.toInt() ?? 0,
      iconName: json['iconName'] as String? ?? 'dataset',
    );
  }

  StatisticsSet copyWith({
    String? name,
    List<String>? fieldNames,
    List<String?>? fieldUnits,
    List<StatisticsRecord>? records,
    bool? pinned,
    bool? archived,
    String? folderId,
    bool clearFolderId = false,
    int? colorIndex,
    String? iconName,
  }) {
    return StatisticsSet(
      id: id,
      name: name ?? this.name,
      fieldNames: fieldNames ?? List<String>.from(this.fieldNames),
      fieldUnits: fieldUnits ?? List<String?>.from(this.fieldUnits),
      records: records ?? List<StatisticsRecord>.from(this.records),
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      lastUsedAt: lastUsedAt,
      pinned: pinned ?? this.pinned,
      archived: archived ?? this.archived,
      folderId: clearFolderId ? null : (folderId ?? this.folderId),
      colorIndex: colorIndex ?? this.colorIndex,
      iconName: iconName ?? this.iconName,
    );
  }

  void touch() {
    lastUsedAt = DateTime.now();
    updatedAt = DateTime.now();
  }
}
