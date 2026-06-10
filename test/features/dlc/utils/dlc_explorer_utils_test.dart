import 'package:aqua/features/dlc/models/dlc_models.dart';
import 'package:aqua/features/dlc/utils/dlc_explorer_utils.dart';
import 'package:flutter_test/flutter_test.dart';

DlcOrder _order({String? dlcId = 'dlc-123'}) {
  return DlcOrder(
    orderId: 'order-1',
    instrumentId: 'BTCUSD-90000-C',
    side: 'sell',
    status: 'filled',
    quantity: 1,
    executions: dlcId == null
        ? const <DlcOrderExecution>[]
        : <DlcOrderExecution>[
            DlcOrderExecution(
              tradeId: 'trade-1',
              dlcId: dlcId,
              role: DlcExecutionRole.maker,
              status: DlcOrderExecution.statusExecuted,
            ),
          ],
    dlcId: dlcId,
    dlcStatus: dlcId == null ? null : 'funding_broadcasted',
  );
}

void main() {
  group('canOpenDlcExplorer', () {
    test('is true when dlc id and wallet token are present', () {
      expect(
        canOpenDlcExplorer(order: _order(), walletToken: 'wallet-token'),
        isTrue,
      );
    });

    test('is false without dlc id', () {
      expect(
        canOpenDlcExplorer(order: _order(dlcId: null), walletToken: 'token'),
        isFalse,
      );
    });

    test('is false without wallet token', () {
      expect(
        canOpenDlcExplorer(order: _order(), walletToken: null),
        isFalse,
      );
    });
  });

  group('buildDlcExplorerPostBody', () {
    test('url-encodes wallet_token and dlc_id fields', () {
      expect(
        buildDlcExplorerPostBody(
          walletToken: 'abc&token',
          dlcId: 'dlc-42',
        ),
        'wallet_token=abc%26token&dlc_id=dlc-42',
      );
    });
  });
}
