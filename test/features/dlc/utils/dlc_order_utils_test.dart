import 'package:aqua/features/dlc/models/dlc_models.dart';
import 'package:aqua/features/dlc/services/dlc_negotiation_utils.dart';
import 'package:aqua/features/dlc/utils/dlc_order_utils.dart';
import 'package:flutter_test/flutter_test.dart';

DlcOrder _order({
  bool isMaker = false,
  bool signRequired = false,
  String? dlcId = 'dlc-1',
  String? dlcStatus,
  String status = 'filled',
}) {
  return DlcOrder(
    orderId: 'order-1',
    instrumentId: 'BTCUSD-90000-C',
    side: 'sell',
    status: status,
    quantity: 1,
    isMaker: isMaker,
    signRequired: signRequired,
    dlcId: dlcId,
    dlcStatus: dlcStatus,
  );
}

void main() {
  group('needsMakerSign', () {
    test('maker with accepted DLC always needs to sign', () {
      final order = _order(isMaker: true, dlcStatus: 'accepted');

      expect(order.needsMakerSign, isTrue);
      expect(orderNeedsNegotiation(order), isTrue);
      expect(
        resolveOrderInFlightPhase(order),
        DlcOrderInFlightPhase.makerSigningDlc,
      );
    });

    test('maker with accepted DLC needs sign even without sign_required', () {
      final order = _order(
        isMaker: true,
        signRequired: false,
        dlcStatus: 'accepted',
      );

      expect(order.needsMakerSign, isTrue);
    });

    test('taker with accepted DLC does not need maker sign', () {
      final order = _order(isMaker: false, dlcStatus: 'accepted');

      expect(order.needsMakerSign, isFalse);
    });

    test('maker with sign_required and offer_created still needs sign', () {
      final order = _order(
        isMaker: true,
        signRequired: true,
        dlcStatus: 'offer_created',
      );

      expect(order.needsMakerSign, isTrue);
    });
  });

  group('order section classification', () {
    test('resting open order shows in open section only', () {
      final order = _order(status: 'open', dlcId: null);

      expect(orderShowsInOpenSection(order), isTrue);
      expect(orderShowsInLiveSection(order), isFalse);
    });

    test('open order with dlc id stays open while status is open', () {
      final order = _order(status: 'open', dlcId: 'dlc-1');

      expect(orderShowsInOpenSection(order), isTrue);
      expect(orderShowsInLiveSection(order), isFalse);
    });

    test('filled order with dlc id shows in live section', () {
      final order = _order(status: 'filled', dlcId: 'dlc-1');

      expect(orderShowsInOpenSection(order), isFalse);
      expect(orderShowsInLiveSection(order), isTrue);
    });

    test('pending_accept order shows in live section', () {
      final order = _order(status: 'pending_accept', dlcId: null);

      expect(orderShowsInOpenSection(order), isFalse);
      expect(orderShowsInLiveSection(order), isTrue);
    });

    test('match-intent pending order shows in live section', () {
      final order = DlcOrder(
        orderId: 'local-pending-123',
        instrumentId: 'BTCUSD-90000-C',
        side: 'buy',
        status: 'pending_accept',
        quantity: 1,
        pendingMatchAccept: true,
      );

      expect(orderShowsInOpenSection(order), isFalse);
      expect(orderShowsInLiveSection(order), isTrue);
    });

    test('non-match pending order stays in open section', () {
      final order = DlcOrder(
        orderId: 'local-pending-123',
        instrumentId: 'BTCUSD-90000-C',
        side: 'buy',
        status: 'open',
        quantity: 1,
      );

      expect(orderShowsInOpenSection(order), isTrue);
      expect(orderShowsInLiveSection(order), isFalse);
    });

    test('open order with sign_required stays in open section', () {
      final order = _order(status: 'open', dlcId: null, signRequired: true);

      expect(orderShowsInOpenSection(order), isTrue);
      expect(orderShowsInLiveSection(order), isFalse);
    });

    test('create response match is detected', () {
      expect(
        createResponseIndicatesMatch(
          const DlcOrderResponse(
            orderId: 'order-1',
            dlcId: 'dlc-1',
            status: 'filled',
            pendingMatchAccept: false,
            signRequired: false,
          ),
        ),
        isTrue,
      );
      expect(
        createResponseIndicatesMatch(
          const DlcOrderResponse(
            orderId: 'order-1',
            dlcId: 'dlc-1',
            status: 'open',
            pendingMatchAccept: false,
            signRequired: true,
          ),
        ),
        isFalse,
      );
      expect(
        createResponseIndicatesMatch(
          const DlcOrderResponse(
            orderId: 'order-1',
            dlcId: '',
            status: 'open',
            pendingMatchAccept: false,
            signRequired: false,
          ),
        ),
        isFalse,
      );
    });

    test('signed DLC shows funding pending label', () {
      final order = _order(status: 'filled', dlcStatus: 'signed', dlcId: 'dlc-1');

      expect(formatDlcStatusLabel(order), 'Funding broadcast pending');
      expect(
        resolveOrderInFlightPhase(order),
        DlcOrderInFlightPhase.fundingBroadcastPending,
      );
    });

    test('signed with funding broadcast failure shows failed label', () {
      final order = DlcOrder(
        orderId: 'order-1',
        instrumentId: 'BTCUSD-90000-C',
        side: 'sell',
        status: 'filled',
        quantity: 1,
        dlcId: 'dlc-1',
        dlcStatus: 'signed',
        lastErrorReason: 'funding_broadcast_failed',
      );

      expect(formatDlcStatusLabel(order), 'Funding broadcast failed');
    });

    test('funding_broadcasted shows maturity label', () {
      final order = _order(
        status: 'filled',
        dlcStatus: 'funding_broadcasted',
        dlcId: 'dlc-1',
      );

      expect(
        formatDlcStatusLabel(order),
        'Funding broadcasted, awaiting oracle maturity',
      );
      expect(order.hasFundingCompleted, isTrue);
      expect(order.isSettlementEligible, isTrue);
    });
  });

  group('mempool explorer links', () {
    test('builds mainnet and testnet tx urls', () {
      expect(
        dlcMempoolTxUrl(txid: 'abc123', isTestnet: false),
        'https://mempool.space/tx/abc123',
      );
      expect(
        dlcMempoolTxUrl(txid: 'abc123', isTestnet: true),
        'https://mempool.space/testnet/tx/abc123',
      );
    });

    test('fundingTxidFromDetailJson reads funding_txid or txid', () {
      expect(
        DlcOrder.fundingTxidFromDetailJson({'funding_txid': 'abc'}),
        'abc',
      );
      expect(
        DlcOrder.fundingTxidFromDetailJson({'txid': 'def'}),
        'def',
      );
      expect(DlcOrder.fundingTxidFromDetailJson({}), isNull);
    });

    test('live funding txid only when funding_broadcasted', () {
      final funded = DlcOrder(
        orderId: 'order-1',
        instrumentId: 'BTCUSD-90000-C',
        side: 'sell',
        status: 'filled',
        quantity: 1,
        dlcStatus: 'funding_broadcasted',
        fundingTxid: 'funding-tx',
      );
      final signed = DlcOrder(
        orderId: 'order-1',
        instrumentId: 'BTCUSD-90000-C',
        side: 'sell',
        status: 'filled',
        quantity: 1,
        dlcStatus: 'signed',
        fundingTxid: 'funding-tx',
      );

      expect(liveOrderFundingTxid(funded), 'funding-tx');
      expect(liveOrderFundingTxid(signed), isNull);
    });

    test('settlement explorer links include closing and refund txids', () {
      final order = DlcOrder(
        orderId: 'order-1',
        instrumentId: 'BTCUSD-90000-C',
        side: 'sell',
        status: 'filled',
        quantity: 1,
        closingTxid: 'close-tx',
        refundTxid: 'refund-tx',
      );

      expect(
        orderSettlementExplorerLinks(order).map((link) => link.label).toList(),
        ['Settlement TX', 'Refund TX'],
      );
    });
  });

  group('closed orders', () {
    test('cancelled order status shows in closed section only', () {
      final order = _order(status: 'cancelled', dlcId: null);

      expect(isDlcClosedOrder(order), isTrue);
      expect(orderShowsInOpenSection(order), isFalse);
      expect(orderShowsInLiveSection(order), isFalse);
    });

    for (final dlcStatus in DlcOrder.terminalDlcStatuses) {
      test('dlc status $dlcStatus shows in closed section only', () {
        final order = _order(status: 'filled', dlcStatus: dlcStatus);

        expect(isDlcClosedOrder(order), isTrue);
        expect(orderShowsInOpenSection(order), isFalse);
        expect(orderShowsInLiveSection(order), isFalse);
      });
    }
  });
}
