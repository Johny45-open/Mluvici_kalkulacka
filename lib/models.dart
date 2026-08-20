part of 'main.dart';

enum CalculatorMode {
  basic,
  scientific,
  statistics,
  electrician,
  unitConversion,
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

class StatisticsSet {
  String name;
  final List<String> fieldNames;
  final List<String?> fieldUnits;
  final List<StatisticsRecord> records;

  StatisticsSet({
    required this.name,
    required this.fieldNames,
    required this.records,
    List<String?>? fieldUnits,
  }) : fieldUnits = fieldUnits ?? List.filled(fieldNames.length, null);

  Map<String, dynamic> toJson() => {
    'name': name,
    'fieldNames': fieldNames,
    'fieldUnits': fieldUnits,
    'records': records.map((r) => r.toJson()).toList(),
  };

  factory StatisticsSet.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('data')) {
      final data = (json['data'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
      return StatisticsSet(
        name: json['name'] as String,
        fieldNames: ['Hodnota'],
        records: data.map((v) => StatisticsRecord(values: [v])).toList(),
      );
    }
    final fieldNames = (json['fieldNames'] as List).cast<String>();
    final fieldUnits = json['fieldUnits'] != null
        ? (json['fieldUnits'] as List).map((e) => e as String?).toList()
        : List<String?>.filled(fieldNames.length, null);
    return StatisticsSet(
      name: json['name'] as String,
      fieldNames: fieldNames,
      fieldUnits: fieldUnits,
      records: (json['records'] as List)
          .map((e) => StatisticsRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
