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

enum DisplayFormat { standard, fix, sci, eng }

enum ElectricianCalculation { voltage, current, resistance }

enum ScreenReaderMode { auto, on, off }

enum DialogSize { compact, wide, fullscreen }

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
