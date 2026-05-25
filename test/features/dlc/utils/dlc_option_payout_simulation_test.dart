import 'package:aqua/features/dlc/models/dlc_trade_models.dart';
import 'package:aqua/features/dlc/utils/dlc_option_payout_simulation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dlcPayoutChartStrikeOutcomeXAxis', () {
    test('focuses window around strike and outcome', () {
      final axis = dlcPayoutChartStrikeOutcomeXAxis(
        strikeUsd: 100000,
        outcomeUsd: 95000,
      );
      expect(axis.min, 61750);
      expect(axis.max, 135000);
    });

    test('uses larger outcome for upper bound', () {
      final axis = dlcPayoutChartStrikeOutcomeXAxis(
        strikeUsd: 100000,
        outcomeUsd: 120000,
      );
      expect(axis.min, 65000);
      expect(axis.max, 162000);
    });

    test('clamps xMin to zero', () {
      final axis = dlcPayoutChartStrikeOutcomeXAxis(
        strikeUsd: 5000,
        outcomeUsd: 4000,
      );
      expect(axis.min, 2600);
      expect(axis.max, 6750);
    });

    test('degenerate guard when strike equals outcome', () {
      final axis = dlcPayoutChartStrikeOutcomeXAxis(
        strikeUsd: 70000,
        outcomeUsd: 70000,
      );
      expect(axis.min, 45500);
      expect(axis.max, 94500);
    });
  });

  group('dlcPayoutChartYExtentsForX', () {
    test('considers only points inside x window', () {
      final extents = dlcPayoutChartYExtentsForX(
        xMin: 65000,
        xMax: 135000,
        intervals: const [
          DlcPayoutChartInterval(
            outcomeLo: 0,
            outcomeHi: 50000,
            payoutSats: 999999,
          ),
          DlcPayoutChartInterval(
            outcomeLo: 70000,
            outcomeHi: 80000,
            payoutSats: 1000,
          ),
        ],
        canonicalPoints: const [],
      );
      expect(extents.min, lessThan(1000));
      expect(extents.max, greaterThan(1000));
      expect(extents.max, lessThan(999999));
    });

    test('falls back to 0..1 when no visible points', () {
      final extents = dlcPayoutChartYExtentsForX(
        xMin: 65000,
        xMax: 135000,
        intervals: const [],
        canonicalPoints: const [],
      );
      expect(extents.min, 0);
      expect(extents.max, 1);
    });
  });

  group('compact formatters', () {
    test('dlcPayoutChartCompactUsd', () {
      expect(dlcPayoutChartCompactUsd(750), '750');
      expect(dlcPayoutChartCompactUsd(65000), '65.0k');
      expect(dlcPayoutChartCompactUsd(101250), '101.3k');
      expect(dlcPayoutChartCompactUsd(1200000), '1.20M');
    });

    test('dlcPayoutChartCompactSats', () {
      expect(dlcPayoutChartCompactSats(-500), '-500');
      expect(dlcPayoutChartCompactSats(1200), '1.2k');
      expect(dlcPayoutChartCompactSats(2400000), '2.40M');
    });
  });
}
