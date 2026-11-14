import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/statistics_math.dart';

void main() {
  group('StatisticsMath', () {
    test('computes population and sample characteristics', () {
      final result = StatisticsMath.compute([1, 2, 3, 4, 5]);

      expect(result.mean, 3);
      expect(result.sum, 15);
      expect(result.populationVariance, 2);
      expect(result.populationStandardDeviation, closeTo(math.sqrt(2), 1e-12));
      expect(result.sampleVariance, 2.5);
      expect(result.sampleStandardDeviation, closeTo(math.sqrt(2.5), 1e-12));
      expect(result.range, 4);
      expect(result.median, 3);
      expect(result.q1, 2);
      expect(result.q3, 4);
      expect(result.interquartileRange, 2);
      expect(result.meanAbsoluteDeviation, 1.2);
      expect(result.populationSkewness, closeTo(0, 1e-12));
      expect(result.populationExcessKurtosis, closeTo(-1.3, 1e-12));
      expect(result.sampleExcessKurtosis, closeTo(-1.2, 1e-12));
    });

    test('uses R-7 for endpoints, singleton, integer h, and interpolation', () {
      expect(StatisticsMath.percentile([1, 2, 3, 4], 0), 1);
      expect(StatisticsMath.percentile([1, 2, 3, 4], 100), 4);
      expect(StatisticsMath.percentile([7], 50), 7);
      expect(StatisticsMath.percentile([1, 2, 3, 4, 5], 25), 2);
      expect(StatisticsMath.percentile([1, 2, 3, 4, 5], 50), 3);
      expect(StatisticsMath.percentile([1, 2, 3, 4, 5], 10), 1.4);
    });

    test('rejects empty data and invalid percentile arguments', () {
      expect(
        () => StatisticsMath.compute([]),
        throwsA(isA<StatisticsMathException>()),
      );
      expect(
        () => StatisticsMath.percentile([], 50),
        throwsA(isA<StatisticsMathException>()),
      );
      expect(
        () => StatisticsMath.percentile([1], 101),
        throwsA(isA<StatisticsMathException>()),
      );
      expect(
        () => StatisticsMath.compute([1, double.infinity]),
        throwsA(isA<StatisticsMathException>()),
      );
    });

    test('handles domains and a zero mean coefficient of variation', () {
      final zeroMean = StatisticsMath.compute([-1, 1]);
      expect(zeroMean.coefficientOfVariation, isNull);

      final withZero = StatisticsMath.compute([0, 1, 4]);
      expect(withZero.geometricMean, 0);
      expect(withZero.harmonicMean, isNull);

      final negative = StatisticsMath.compute([-1, 4]);
      expect(negative.geometricMean, isNull);
      expect(negative.harmonicMean, isNull);

      expect(StatisticsMath.compute([1, 4, 16]).geometricMean, 4);
      expect(
        StatisticsMath.compute([1, 2, 4]).harmonicMean,
        closeTo(12 / 7, 1e-12),
      );
    });

    test('retains precision for close values with a large common offset', () {
      final result = StatisticsMath.compute([1e12, 1e12 + 1, 1e12 + 2]);
      expect(result.mean, 1e12 + 1);
      expect(result.populationVariance, closeTo(2 / 3, 1e-12));
      expect(result.sampleVariance, closeTo(1, 1e-12));
    });

    test('returns undefined higher moments for constant samples', () {
      final result = StatisticsMath.compute([4, 4, 4, 4]);
      expect(result.populationVariance, 0);
      expect(result.sampleVariance, 0);
      expect(result.meanAbsoluteDeviation, 0);
      expect(result.populationSkewness, isNull);
      expect(result.sampleSkewness, isNull);
      expect(result.populationExcessKurtosis, isNull);
      expect(result.sampleExcessKurtosis, isNull);
    });

    test(
      'handles overflowing sums and unrepresentable variance explicitly',
      () {
        final sameLarge = StatisticsMath.compute([
          double.maxFinite,
          double.maxFinite,
        ]);
        expect(sameLarge.mean, double.maxFinite);
        expect(sameLarge.sum, isNull);
        expect(sameLarge.populationVariance, 0);

        final opposite = StatisticsMath.compute([
          -double.maxFinite,
          double.maxFinite,
        ]);
        expect(opposite.mean, 0);
        expect(opposite.populationVariance, isNull);
        expect(opposite.populationStandardDeviation, isNull);
      },
    );

    test('returns undefined sample statistics for a singleton', () {
      final result = StatisticsMath.compute([9]);
      expect(result.sampleVariance, isNull);
      expect(result.sampleStandardDeviation, isNull);
      expect(result.populationVariance, 0);
      expect(result.populationStandardDeviation, 0);
      expect(result.q1, 9);
      expect(result.q3, 9);
    });
  });
}
