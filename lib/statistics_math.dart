import 'dart:math' as math;

class StatisticsMathResult {
  final double? sum;
  final double mean;
  final double? populationVariance;
  final double? populationStandardDeviation;
  final double? sampleVariance;
  final double? sampleStandardDeviation;
  final double median;
  final double min;
  final double max;
  final double? range;
  final double? meanAbsoluteDeviation;
  final double? geometricMean;
  final double? harmonicMean;
  final double? coefficientOfVariation;
  final double? q1;
  final double? q3;
  final double? interquartileRange;
  final double? populationSkewness;
  final double? sampleSkewness;
  final double? populationExcessKurtosis;
  final double? sampleExcessKurtosis;
  final List<double> modes;
  final bool modeExists;
  final int modeOccurrenceCount;
  final Map<double, int> frequencies;

  const StatisticsMathResult({
    required this.sum,
    required this.mean,
    required this.populationVariance,
    required this.populationStandardDeviation,
    required this.sampleVariance,
    required this.sampleStandardDeviation,
    required this.median,
    required this.min,
    required this.max,
    required this.range,
    required this.meanAbsoluteDeviation,
    required this.geometricMean,
    required this.harmonicMean,
    required this.coefficientOfVariation,
    required this.q1,
    required this.q3,
    required this.interquartileRange,
    required this.populationSkewness,
    required this.sampleSkewness,
    required this.populationExcessKurtosis,
    required this.sampleExcessKurtosis,
    required this.modes,
    required this.modeExists,
    required this.modeOccurrenceCount,
    required this.frequencies,
  });
}

class StatisticsMathException implements Exception {
  final String message;

  const StatisticsMathException(this.message);

  @override
  String toString() => message;
}

class StatisticsMath {
  static StatisticsMathResult compute(List<double> values) {
    if (values.isEmpty) {
      throw const StatisticsMathException('Statistics require at least one value.');
    }
    if (values.any((value) => !value.isFinite)) {
      throw const StatisticsMathException('All statistical values must be finite.');
    }

    var mean = 0.0;
    var m2 = 0.0;
    var m2IsFinite = true;
    var sum = 0.0;
    var compensation = 0.0;
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      final count = i + 1;
      final delta = value - mean;
      final nextMean = delta.isFinite
          ? mean + delta / count
          : mean / 2 + value / 2;
      if (m2IsFinite) {
        final deltaAfterMean = value - nextMean;
        final nextM2 = m2 + delta * deltaAfterMean;
        if (delta.isFinite && deltaAfterMean.isFinite && nextM2.isFinite) {
          m2 = nextM2;
        } else {
          m2IsFinite = false;
        }
      }
      mean = nextMean;

      final adjusted = value - compensation;
      final nextSum = sum + adjusted;
      compensation = (nextSum - sum) - adjusted;
      sum = nextSum;
    }

    final sumResult = sum.isFinite ? sum : null;
    final populationVariance = m2IsFinite ? m2 / values.length : null;
    final sampleVariance = m2IsFinite && values.length > 1
        ? m2 / (values.length - 1)
        : null;
    final populationSd = populationVariance == null
        ? null
        : math.sqrt(populationVariance);
    final sampleSd = sampleVariance == null ? null : math.sqrt(sampleVariance);

    final sorted = List<double>.of(values)..sort();
    final min = sorted.first;
    final max = sorted.last;
    final rangeValue = max - min;
    final range = rangeValue.isFinite ? rangeValue : null;
    final median = percentile(sorted, 50);
    final q1 = percentile(sorted, 25);
    final q3 = percentile(sorted, 75);

    final counts = <double, int>{};
    for (final value in values) {
      counts[value] = (counts[value] ?? 0) + 1;
    }
    final maxCount = counts.values.reduce((a, b) => a > b ? a : b);
    final modes = counts.entries
        .where((entry) => entry.value == maxCount)
        .map((entry) => entry.key)
        .toList()
      ..sort();
    final sortedEntries = counts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final frequencies = Map<double, int>.fromEntries(sortedEntries);

    final maxDeviation = values
        .map((value) => (value - mean).abs())
        .fold<double>(0, math.max);
    double? meanAbsoluteDeviation;
    double? populationSkewness;
    double? sampleSkewness;
    double? populationExcessKurtosis;
    double? sampleExcessKurtosis;
    if (maxDeviation == 0) {
      meanAbsoluteDeviation = 0;
    } else if (maxDeviation.isFinite) {
      var absoluteDeviationSum = 0.0;
      var normalizedThird = 0.0;
      var normalizedFourth = 0.0;
      var normalizedSecond = 0.0;
      for (final value in values) {
        final normalized = (value - mean) / maxDeviation;
        absoluteDeviationSum += normalized.abs();
        normalizedSecond += normalized * normalized;
        normalizedThird += normalized * normalized * normalized;
        final square = normalized * normalized;
        normalizedFourth += square * square;
      }
      final mad = (absoluteDeviationSum / values.length) * maxDeviation;
      if (mad.isFinite) meanAbsoluteDeviation = mad;
      if (normalizedSecond > 0) {
        final secondMoment = normalizedSecond / values.length;
        final thirdMoment = normalizedThird / values.length;
        final fourthMoment = normalizedFourth / values.length;
        final skew =
            thirdMoment / (secondMoment * math.sqrt(secondMoment));
        final excess = fourthMoment / (secondMoment * secondMoment) - 3;
        if (skew.isFinite) {
          populationSkewness = skew;
          if (values.length > 2) {
            final corrected =
                math.sqrt(values.length * (values.length - 1)) /
                (values.length - 2) *
                skew;
            if (corrected.isFinite) sampleSkewness = corrected;
          }
        }
        if (excess.isFinite) {
          populationExcessKurtosis = excess;
          if (values.length > 3) {
            final corrected =
                (values.length - 1) /
                ((values.length - 2) * (values.length - 3)) *
                ((values.length + 1) * excess + 6);
            if (corrected.isFinite) sampleExcessKurtosis = corrected;
          }
        }
      }
    }

    final geometricMean = _geometricMean(values);
    final harmonicMean = _harmonicMean(values);
    final cv = populationSd == null || mean == 0
        ? null
        : (populationSd / mean.abs()) * 100;
    final iqrValue = q3 - q1;

    return StatisticsMathResult(
      sum: sumResult,
      mean: mean,
      populationVariance: populationVariance,
      populationStandardDeviation: populationSd,
      sampleVariance: sampleVariance,
      sampleStandardDeviation: sampleSd,
      median: median,
      min: min,
      max: max,
      range: range,
      meanAbsoluteDeviation: meanAbsoluteDeviation,
      geometricMean: geometricMean,
      harmonicMean: harmonicMean,
      coefficientOfVariation: cv != null && cv.isFinite ? cv : null,
      q1: q1,
      q3: q3,
      interquartileRange: iqrValue.isFinite ? iqrValue : null,
      populationSkewness: populationSkewness,
      sampleSkewness: sampleSkewness,
      populationExcessKurtosis: populationExcessKurtosis,
      sampleExcessKurtosis: sampleExcessKurtosis,
      modes: modes,
      modeExists: maxCount > 1,
      modeOccurrenceCount: maxCount,
      frequencies: frequencies,
    );
  }

  static double percentile(List<double> sortedValues, double percentile) {
    if (sortedValues.isEmpty) {
      throw const StatisticsMathException(
        'Percentiles require at least one value.',
      );
    }
    if (!percentile.isFinite || percentile < 0 || percentile > 100) {
      throw const StatisticsMathException(
        'Percentile must be a finite value between 0 and 100.',
      );
    }
    final n = sortedValues.length;
    if (n == 1 || percentile == 0) return sortedValues.first;
    if (percentile == 100) return sortedValues.last;

    final p = percentile / 100;
    final h = 1 + (n - 1) * p;
    final lowerOneBased = h.floor();
    final fraction = h - lowerOneBased;
    final lowerIndex = lowerOneBased - 1;
    if (fraction == 0 || lowerIndex >= n - 1) {
      return sortedValues[lowerIndex.clamp(0, n - 1).toInt()];
    }
    final lower = sortedValues[lowerIndex];
    final upper = sortedValues[lowerIndex + 1];
    return (1 - fraction) * lower + fraction * upper;
  }

  static double? _geometricMean(List<double> values) {
    if (values.any((value) => value < 0)) return null;
    if (values.any((value) => value == 0)) return 0;
    final logMean =
        values.fold<double>(0, (sum, value) => sum + math.log(value)) /
        values.length;
    final result = math.exp(logMean);
    return result.isFinite ? result : null;
  }

  static double? _harmonicMean(List<double> values) {
    if (values.any((value) => value <= 0)) return null;
    final minValue = values.reduce(math.min);
    final scaledReciprocalSum = values.fold<double>(
      0,
      (sum, value) => sum + minValue / value,
    );
    final result = minValue * values.length / scaledReciprocalSum;
    return result.isFinite ? result : null;
  }
}
