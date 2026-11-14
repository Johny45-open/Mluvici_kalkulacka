import 'package:flutter_test/flutter_test.dart';
import 'package:mluvici_kalkulacka/config_validator.dart';
import 'package:mluvici_kalkulacka/main.dart';

void main() {
  group('StatsDisplayConfig', () {
    test('preset changes visibility without deleting custom percentiles', () {
      const percentile = CustomPercentile(
        id: 'percentile-stable-id',
        p: 10,
        visible: true,
      );
      final config = StatsDisplayConfig(
        preset: StatsDisplayPreset.basic,
        customShowN: false,
        customVisibleItems: const {StatsComputedItem.mean},
        percentiles: const [percentile],
        order: const [
          StatsOrderEntry.percentile('percentile-stable-id'),
          StatsOrderEntry.fixed(StatsComputedItem.mean),
        ],
      );

      expect(config.showN, isTrue);
      expect(config.visiblePercentiles, isEmpty);
      expect(config.percentiles.single.id, percentile.id);

      final complete = StatsDisplayConfig(
        preset: StatsDisplayPreset.complete,
        customShowN: config.customShowN,
        customVisibleItems: config.customVisibleItems,
        percentiles: config.percentiles,
        order: config.order,
      );
      expect(complete.showN, isTrue);
      expect(complete.visibleItems, StatsComputedItem.values.toSet());
      expect(complete.visiblePercentiles.single.id, percentile.id);
    });

    test(
      'round trip preserves custom selection and percentile order by ID',
      () {
        const percentile = CustomPercentile(
          id: 'percentile-id-not-derived-from-p',
          p: 10,
          visible: true,
        );
        final config = StatsDisplayConfig(
          preset: StatsDisplayPreset.custom,
          customShowN: false,
          customVisibleItems: const {
            StatsComputedItem.mean,
            StatsComputedItem.sampleVariance,
          },
          percentiles: const [percentile],
          order: const [
            StatsOrderEntry.fixed(StatsComputedItem.sampleVariance),
            StatsOrderEntry.percentile('percentile-id-not-derived-from-p'),
            StatsOrderEntry.fixed(StatsComputedItem.mean),
          ],
        );

        final restored = StatsDisplayConfig.fromJson(config.toJson());

        expect(restored.preset, StatsDisplayPreset.custom);
        expect(restored.showN, isFalse);
        expect(restored.visibleItems, config.visibleItems);
        expect(restored.percentiles.single.id, percentile.id);
        expect(restored.order.take(3), config.order.take(3));
      },
    );

    test('v2 contract validates and round-trips statistics configuration', () {
      const percentile = CustomPercentile(id: 'custom-p-90-id', p: 90);
      final config = StatsDisplayConfig(
        preset: StatsDisplayPreset.custom,
        customShowN: false,
        customVisibleItems: const {StatsComputedItem.mean},
        percentiles: const [percentile],
        order: const [
          StatsOrderEntry.percentile('custom-p-90-id'),
          StatsOrderEntry.fixed(StatsComputedItem.mean),
        ],
      );
      final contract = buildQuickSetupContract(
        draft: QuickSetupDraft.defaults(),
        profiles: const [],
        activeProfileId: 'standard',
        statsSummaryOrder: StatsSummarySection.values,
        statsComputedOrder: StatsComputedItem.values,
        statsDisplayConfig: config,
        currencyFrom: 'CZK',
        currencyTo: 'EUR',
        devEnabled: false,
        devAutoDiagnostic: false,
        devDiagnosticDurationMs: 1000,
        devPinCode: null,
        historyExactFormat: HistoryExactFormat.numeric,
      );

      expect(contract['schemaVersion'], 2);
      expect(validateContract(contract).ok, isTrue);
      final restored = parseContract(contract).statsDisplayConfig!;
      expect(restored.preset, StatsDisplayPreset.custom);
      expect(restored.showN, isFalse);
      expect(restored.percentiles.single.id, percentile.id);
      expect(
        restored.order.first,
        const StatsOrderEntry.percentile('custom-p-90-id'),
      );
    });
  });
}
