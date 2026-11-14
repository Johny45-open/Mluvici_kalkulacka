import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/main.dart';

void main() {
  group('computeWeightedStats', () {
    test('uses the absolute weighted mean in weighted CV', () {
      final result = computeWeightedStats([-3, -1], [1, 1]);

      expect(result.isOk, isTrue);
      expect(result.wmean, -2);
      expect(result.wvar, 1);
      expect(result.wsd, 1);
      expect(result.wcv, 50);
    });

    test('rejects negative weights and a zero total weight', () {
      expect(
        computeWeightedStats([1, 2], [1, -1]).failure,
        WeightedStatsFailure.negativeWeight,
      );
      expect(
        computeWeightedStats([1, 2], [0, 0]).failure,
        WeightedStatsFailure.zeroWeightSum,
      );
    });

    test('keeps weighted variance stable for close, large values', () {
      final lower = 1e150;
      final upper = lower + 1e140;
      final delta = upper - lower;
      final result = computeWeightedStats([lower, upper], [1, 1]);

      expect(result.isOk, isTrue);
      expect(result.wvar, closeTo(delta * delta / 4, delta * delta * 1e-12));
      expect(result.wsd, closeTo(delta / 2, delta * 1e-12));
    });
  });
}
