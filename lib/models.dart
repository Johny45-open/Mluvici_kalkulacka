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
  final bool readStatsMemoryValues;
  final bool autoReadStatsSummary;
  final bool showStatsNavigationHint;
  final bool alignInputLeft;
  final double overlineThickness;
  final double overlineHeight;
  final double speechRate;
  final double speechVolume;
  final bool ttsEnabled;
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
    required this.readStatsMemoryValues,
    required this.autoReadStatsSummary,
    required this.showStatsNavigationHint,
    required this.alignInputLeft,
    required this.overlineThickness,
    required this.overlineHeight,
    required this.speechRate,
    required this.speechVolume,
    required this.ttsEnabled,
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
      readStatsMemoryValues: true,
      autoReadStatsSummary: true,
      showStatsNavigationHint: true,
      alignInputLeft: true,
      overlineThickness: 1.0,
      overlineHeight: 1.0,
      speechRate: 0.5,
      speechVolume: 1.0,
      ttsEnabled: true,
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
      readStatsMemoryValues: true,
      autoReadStatsSummary: true,
      showStatsNavigationHint: true,
      alignInputLeft: true,
      overlineThickness: 1.0,
      overlineHeight: 1.0,
      speechRate: 0.5,
      speechVolume: 1.0,
      ttsEnabled: true,
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
      readStatsMemoryValues: true,
      autoReadStatsSummary: true,
      showStatsNavigationHint: true,
      alignInputLeft: true,
      overlineThickness: 1.0,
      overlineHeight: 1.0,
      speechRate: 0.5,
      speechVolume: 1.0,
      ttsEnabled: true,
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
    bool? readStatsMemoryValues,
    bool? autoReadStatsSummary,
    bool? showStatsNavigationHint,
    bool? alignInputLeft,
    double? overlineThickness,
    double? overlineHeight,
    double? speechRate,
    double? speechVolume,
    bool? ttsEnabled,
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
      readStatsMemoryValues: readStatsMemoryValues ?? this.readStatsMemoryValues,
      autoReadStatsSummary: autoReadStatsSummary ?? this.autoReadStatsSummary,
      showStatsNavigationHint:
          showStatsNavigationHint ?? this.showStatsNavigationHint,
      alignInputLeft: alignInputLeft ?? this.alignInputLeft,
      overlineThickness: overlineThickness ?? this.overlineThickness,
      overlineHeight: overlineHeight ?? this.overlineHeight,
      speechRate: speechRate ?? this.speechRate,
      speechVolume: speechVolume ?? this.speechVolume,
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
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

    Map<String, String>? parseVoice(dynamic v) {
      if (v == null) return null;
      if (v is Map) {
        try {
          return Map<String, String>.from(
              v.map((k, val) => MapEntry(k.toString(), val.toString())));
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
      readStatsMemoryValues: json['readStatsMemoryValues'] as bool? ?? true,
      autoReadStatsSummary: json['autoReadStatsSummary'] as bool? ?? true,
      showStatsNavigationHint:
          json['showStatsNavigationHint'] as bool? ?? true,
      alignInputLeft: json['alignInputLeft'] as bool? ?? true,
      overlineThickness: (json['overlineThickness'] as num?)?.toDouble() ?? 1.0,
      overlineHeight: (json['overlineHeight'] as num?)?.toDouble() ?? 1.0,
      speechRate: (json['speechRate'] as num?)?.toDouble() ?? 0.5,
      speechVolume: (json['speechVolume'] as num?)?.toDouble() ?? 1.0,
      ttsEnabled: json['ttsEnabled'] as bool? ?? true,
      ttsEngine: json['ttsEngine'] as String?,
      ttsVoice: parseVoice(json['ttsVoice']),
      ttsVoiceName: json['ttsVoiceName'] as String?,
      inverseFormatPreference: (json['inverseFormatPreference'] as num?)?.toInt(),
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
      parsedSettings =
          AccessibilitySettings.fromJson(Map<String, dynamic>.from(rawSettings));
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

enum DisplayFormat { standard, fix, sci, eng }

enum ElectricianCalculation { voltage, current, resistance }

enum ScreenReaderMode { auto, on, off }

enum DialogSize { compact, wide, fullscreen }

enum StatsSummarySection { header, dataValues, computed }

enum StatsComputedItem { mean, sum, variance, sd, median, min, max, mode, cv, wmean }

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

class _StatisticsSnapshot {
  final double sum;
  final double mean;
  final double variance;
  final double sd;
  final double median;
  final double min;
  final double max;
  final List<double> modes;
  final int modeOccurrenceCount;
  final bool modeExists;
  final double? cv;
  final double? wmean;
  final Map<double, int> frequencies;

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
  })  : id = id ?? _generateStatsId(),
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
