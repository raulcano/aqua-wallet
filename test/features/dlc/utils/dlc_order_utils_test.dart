import 'package:aqua/features/dlc/models/dlc_models.dart';
import 'package:aqua/features/dlc/services/dlc_negotiation_utils.dart';
import 'package:aqua/features/dlc/utils/dlc_order_utils.dart';
import 'package:flutter_test/flutter_test.dart';

DlcOrderExecution _execution({
  String tradeId = 'trade-1',
  String dlcId = 'dlc-1',
  DlcExecutionRole role = DlcExecutionRole.taker,
  String status = DlcOrderExecution.statusExecuted,
  String? dlcStatus,
  String? fundingTxid,
  String? closingTxid,
  String? refundTxid,
  String? makerOrderId,
  String? takerOrderId,
  String? lastErrorReason,
}) {
  return DlcOrderExecution(
    tradeId: tradeId,
    dlcId: dlcId,
    role: role,
    status: status,
    dlcStatus: dlcStatus,
    fundingTxid: fundingTxid,
    closingTxid: closingTxid,
    refundTxid: refundTxid,
    makerOrderId: makerOrderId,
    takerOrderId: takerOrderId,
    lastErrorReason: lastErrorReason,
  );
}

DlcOrder _order({
  String orderId = 'order-1',
  String status = 'filled',
  List<DlcOrderExecution>? executions,
  DlcExecutionRole role = DlcExecutionRole.taker,
  String executionStatus = DlcOrderExecution.statusExecuted,
  String? dlcId = 'dlc-1',
  String? dlcStatus,
  String? draftOfferObjectHex,
  String? lastErrorReason,
}) {
  final orderExecutions = executions ??
      (dlcId == null
          ? const <DlcOrderExecution>[]
          : <DlcOrderExecution>[
              _execution(
                dlcId: dlcId,
                role: role,
                status: executionStatus,
              ),
            ]);
  // Mirror what `DlcOrder.fromJson` does: real coordinator responses carry
  // `dlc_status` / `dlc_id` at the top level of the order, not inside each
  // execution. When tests pass an explicit `executions` list (with a
  // per-execution `dlcStatus`) we hoist that to the top level so the assertion
  // surface matches real responses.
  final latest = orderExecutions.isEmpty ? null : orderExecutions.last;
  final resolvedDlcStatus = dlcStatus ?? latest?.dlcStatus;
  final resolvedDlcId = orderExecutions.isEmpty
      ? null
      : ((latest?.dlcId.isNotEmpty ?? false) ? latest?.dlcId : dlcId);
  return DlcOrder(
    orderId: orderId,
    instrumentId: 'BTCUSD-90000-C',
    side: 'sell',
    status: status,
    quantity: 1,
    draftOfferObjectHex: draftOfferObjectHex,
    executions: orderExecutions,
    lastErrorReason: lastErrorReason ?? latest?.lastErrorReason,
    dlcId: resolvedDlcId,
    dlcStatus: resolvedDlcStatus,
    fundingTxid: latest?.fundingTxid,
    closingTxid: latest?.closingTxid,
    refundTxid: latest?.refundTxid,
  );
}

void main() {
  group('needsMakerSign', () {
    test('maker with accepted DLC needs to sign', () {
      final order = _order(role: DlcExecutionRole.maker, dlcStatus: 'accepted');

      expect(order.needsMakerSign, isTrue);
      expect(orderNeedsNegotiation(order), isTrue);
      expect(
        resolveOrderInFlightPhase(order),
        DlcOrderInFlightPhase.makerSigningDlc,
      );
    });

    test('taker with accepted DLC does not need maker sign', () {
      final order = _order(role: DlcExecutionRole.taker, dlcStatus: 'accepted');

      expect(order.needsMakerSign, isFalse);
    });

    test('maker without an execution yet does not need to sign', () {
      final order = _order(status: 'open', executions: const [], dlcId: null);

      expect(order.needsMakerSign, isFalse);
      expect(order.dlcId, isNull);
    });

    // Regression: real coordinator responses put `dlc_status` at the top level
    // of the order (not inside `executions[]`). After the taker submits
    // accept-match, the maker polls and must see `needsMakerSign == true` even
    // though no execution entry carries `dlc_status`.
    test('maker sees needsMakerSign from top-level dlc_status after taker accept',
        () {
      final order = DlcOrder.fromJson(<String, dynamic>{
        'order_id': 'maker-order',
        'instrument_id': 'BTCUSD-90000-C',
        'side': 'sell',
        'status': 'filled',
        'quantity': 1,
        'dlc_id': 'dlc-canonical',
        'dlc_status': 'accepted',
        'executions': <Map<String, dynamic>>[
          {
            'trade_id': 'trade-1',
            'dlc_id': 'dlc-canonical',
            'role': 'maker',
            'counterparty_order_id': 'taker-order',
            'status': 'executed',
          },
        ],
      });

      expect(order.walletRole, DlcExecutionRole.maker);
      expect(order.dlcId, 'dlc-canonical');
      expect(order.dlcStatus, 'accepted');
      expect(order.needsMakerSign, isTrue);
      expect(orderNeedsNegotiation(order), isTrue);
    });

    test('maker does not sign while DLC is still pending_accept', () {
      final order = DlcOrder.fromJson(<String, dynamic>{
        'order_id': 'maker-order',
        'instrument_id': 'BTCUSD-90000-C',
        'side': 'sell',
        'status': 'pending_accept',
        'quantity': 1,
        'dlc_id': 'dlc-canonical',
        'dlc_status': 'pending_accept',
        'executions': <Map<String, dynamic>>[
          {
            'trade_id': 'trade-1',
            'dlc_id': 'dlc-canonical',
            'role': 'maker',
            'counterparty_order_id': 'taker-order',
            'status': 'pending_accept',
          },
        ],
      });

      expect(order.needsMakerSign, isFalse);
    });
  });

  group('needsTakerAccept', () {
    test('taker pending_accept execution triggers taker accept', () {
      final order = _order(
        status: 'pending_accept',
        role: DlcExecutionRole.taker,
        executionStatus: DlcOrderExecution.statusPendingAccept,
        dlcStatus: 'pending_accept',
      );

      expect(order.needsTakerAccept, isTrue);
      expect(
        resolveOrderInFlightPhase(order),
        DlcOrderInFlightPhase.matchedAwaitingTakerAccept,
      );
    });

    test('maker pending_accept never needs taker accept', () {
      final order = _order(
        status: 'pending_accept',
        role: DlcExecutionRole.maker,
        executionStatus: DlcOrderExecution.statusPendingAccept,
        dlcStatus: 'pending_accept',
      );

      expect(order.needsTakerAccept, isFalse);
      expect(order.needsMakerSign, isFalse);
    });
  });

  group('order section classification', () {
    test('resting open order shows in open section only', () {
      final order = _order(status: 'open', executions: const [], dlcId: null);

      expect(orderShowsInOpenSection(order), isTrue);
      expect(orderShowsInLiveSection(order), isFalse);
    });

    test('filled order with execution shows in live section', () {
      final order = _order(status: 'filled');

      expect(orderShowsInOpenSection(order), isFalse);
      expect(orderShowsInLiveSection(order), isTrue);
    });

    test('pending_accept order shows in live section', () {
      final order = _order(
        status: 'pending_accept',
        executionStatus: DlcOrderExecution.statusPendingAccept,
        dlcStatus: 'pending_accept',
      );

      expect(orderShowsInOpenSection(order), isFalse);
      expect(orderShowsInLiveSection(order), isTrue);
    });

    test('local pending optimistic order shows in live section', () {
      const order = DlcOrder(
        orderId: 'local-pending-123',
        instrumentId: 'BTCUSD-90000-C',
        side: 'buy',
        status: 'pending_accept',
        quantity: 1,
      );

      expect(orderShowsInOpenSection(order), isFalse);
      expect(orderShowsInLiveSection(order), isTrue);
    });

    test('non-match pending order stays in open section', () {
      const order = DlcOrder(
        orderId: 'local-pending-123',
        instrumentId: 'BTCUSD-90000-C',
        side: 'buy',
        status: 'open',
        quantity: 1,
      );

      expect(orderShowsInOpenSection(order), isTrue);
      expect(orderShowsInLiveSection(order), isFalse);
    });

    test('signed DLC shows funding pending label', () {
      final order = _order(status: 'filled', dlcStatus: 'signed');

      expect(formatDlcStatusLabel(order), 'Funding broadcast pending');
      expect(
        resolveOrderInFlightPhase(order),
        DlcOrderInFlightPhase.fundingBroadcastPending,
      );
    });

    test('signed with funding broadcast failure shows failed label', () {
      final order = _order(
        status: 'filled',
        dlcStatus: 'signed',
        lastErrorReason: 'funding_broadcast_failed',
      );

      expect(formatDlcStatusLabel(order), 'Funding broadcast failed');
    });

    test('funding_broadcasted shows maturity label', () {
      final order = _order(
        status: 'filled',
        dlcStatus: 'funding_broadcasted',
      );

      expect(
        formatDlcStatusLabel(order),
        'Funding broadcasted, awaiting oracle maturity',
      );
      expect(order.hasFundingCompleted, isTrue);
      expect(order.isSettlementEligible, isTrue);
    });
  });

  group('live signing activity', () {
    test('taker pending_accept shows the taker is signing', () {
      final order = _order(
        status: 'pending_accept',
        role: DlcExecutionRole.taker,
        executionStatus: DlcOrderExecution.statusPendingAccept,
        dlcStatus: 'pending_accept',
      );

      expect(formatLiveOrderActivity(order), 'Taker signing acceptance');
      expect(formatOrderStatusLine(order), 'Taker signing acceptance');
    });

    test('maker pending_accept shows we are awaiting taker', () {
      final order = _order(
        status: 'pending_accept',
        role: DlcExecutionRole.maker,
        executionStatus: DlcOrderExecution.statusPendingAccept,
        dlcStatus: 'pending_accept',
      );

      expect(formatLiveOrderActivity(order), 'Awaiting taker acceptance');
    });

    test('maker with accepted DLC shows the maker is signing', () {
      final order = _order(
        role: DlcExecutionRole.maker,
        dlcStatus: 'accepted',
      );

      expect(formatLiveOrderActivity(order), 'Maker signing DLC');
    });

    test('taker with accepted DLC waits for the maker to sign', () {
      final order = _order(
        role: DlcExecutionRole.taker,
        dlcStatus: 'accepted',
      );

      expect(formatLiveOrderActivity(order), 'Awaiting maker signature');
    });

    test('signed DLC marks both parties signed', () {
      final order = _order(dlcStatus: 'signed');

      expect(
        formatLiveOrderActivity(order),
        'Both signed · funding broadcast pending',
      );
    });

    test('funding_broadcasted marks both signed and broadcasted', () {
      final order = _order(dlcStatus: 'funding_broadcasted');

      expect(
        formatLiveOrderActivity(order),
        'Both signed · funding broadcasted',
      );
    });
  });

  group('create response handling', () {
    test('unmatched response indicates no immediate match', () {
      const response = DlcOrderResponse(
        orderId: 'order-1',
        status: 'open',
        offerObjectHex: 'deadbeef',
      );
      expect(createResponseIndicatesMatch(response), isFalse);
      expect(response.isMatchedImmediately, isFalse);
      expect(response.executions, isEmpty);
      expect(response.offerObjectHex, 'deadbeef');
    });

    test('immediate match response carries a taker execution', () {
      const response = DlcOrderResponse(
        orderId: 'taker-order',
        status: 'pending_accept',
        dlcId: 'dlc-x',
        offerObjectHex: 'finalized',
        executions: <DlcOrderExecution>[
          DlcOrderExecution(
            tradeId: 'trade-x',
            dlcId: 'dlc-x',
            role: DlcExecutionRole.taker,
            status: DlcOrderExecution.statusPendingAccept,
            counterpartyOrderId: 'maker-order',
          ),
        ],
      );

      expect(response.isMatchedImmediately, isTrue);
      expect(createResponseIndicatesMatch(response), isTrue);
      expect(response.executions.first.role, DlcExecutionRole.taker);
    });

    test('orderFromCreateResponse keeps draft offer when unmatched', () {
      final pending = _order(status: 'open', executions: const [], dlcId: null);
      const response = DlcOrderResponse(
        orderId: 'order-1',
        status: 'open',
        offerObjectHex: 'deadbeef',
      );

      final order = orderFromCreateResponse(
        response: response,
        pendingOrder: pending,
      );
      expect(order.draftOfferObjectHex, 'deadbeef');
      expect(order.executions, isEmpty);
      expect(order.dlcId, isNull);
    });

    test('orderFromCreateResponse takes over execution on immediate match', () {
      final pending = _order(status: 'open', executions: const [], dlcId: null);
      const response = DlcOrderResponse(
        orderId: 'taker-order',
        status: 'pending_accept',
        dlcId: 'dlc-x',
        executions: <DlcOrderExecution>[
          DlcOrderExecution(
            tradeId: 'trade-x',
            dlcId: 'dlc-x',
            role: DlcExecutionRole.taker,
            status: DlcOrderExecution.statusPendingAccept,
          ),
        ],
      );

      final order = orderFromCreateResponse(
        response: response,
        pendingOrder: pending,
      );
      expect(order.draftOfferObjectHex, isNull);
      expect(order.executions.single.role, DlcExecutionRole.taker);
      expect(order.dlcId, 'dlc-x');
    });
  });

  group('role detection via canonical DLC', () {
    test('roleForOrderId returns maker for the maker order id', () {
      const dlc = DlcCanonicalDlc(
        dlcId: 'dlc-1',
        tradeId: 'trade-1',
        makerOrderId: 'maker-order',
        takerOrderId: 'taker-order',
        status: 'accepted',
      );
      expect(dlc.roleForOrderId('maker-order'), DlcExecutionRole.maker);
      expect(dlc.roleForOrderId('taker-order'), DlcExecutionRole.taker);
      expect(dlc.roleForOrderId('other'), DlcExecutionRole.unknown);
    });
  });

  group('execution history', () {
    test('a failed execution does not block a later successful one', () {
      final order = _order(
        status: 'filled',
        // Top-level reflects the latest (successful) execution.
        dlcId: 'dlc-ok',
        dlcStatus: 'funding_broadcasted',
        executions: <DlcOrderExecution>[
          _execution(
            tradeId: 'trade-failed',
            dlcId: 'dlc-failed',
            status: DlcOrderExecution.statusFailed,
            dlcStatus: 'terminated',
          ),
          _execution(
            tradeId: 'trade-ok',
            dlcId: 'dlc-ok',
            status: DlcOrderExecution.statusExecuted,
            dlcStatus: 'funding_broadcasted',
            fundingTxid: 'funding-tx',
          ),
        ],
      );

      expect(order.dlcId, 'dlc-ok');
      expect(order.dlcStatus, 'funding_broadcasted');
      expect(order.executions.length, 2);
    });

    test('mergeDlcDetail updates only the current execution', () {
      final order = _order(
        status: 'filled',
        dlcStatus: 'accepted',
        role: DlcExecutionRole.maker,
      );
      final merged = order.mergeDlcDetail(<String, dynamic>{
        'status': 'funding_broadcasted',
        'funding_txid': 'tx-abc',
      });
      expect(merged.dlcStatus, 'funding_broadcasted');
      expect(merged.fundingTxid, 'tx-abc');
      expect(merged.executions.length, 1);
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

    test('live funding txid surfaces once both parties have signed', () {
      final funded = _order(
        status: 'filled',
        executions: <DlcOrderExecution>[
          _execution(dlcStatus: 'funding_broadcasted', fundingTxid: 'funding-tx'),
        ],
      );
      final signed = _order(
        status: 'filled',
        executions: <DlcOrderExecution>[
          _execution(dlcStatus: 'signed', fundingTxid: 'funding-tx'),
        ],
      );
      final accepted = _order(
        status: 'filled',
        executions: <DlcOrderExecution>[
          _execution(dlcStatus: 'accepted'),
        ],
      );

      expect(liveOrderFundingTxid(funded), 'funding-tx');
      // Both signed but broadcast may have failed — link still shows because
      // the funding tx itself was constructed.
      expect(liveOrderFundingTxid(signed), 'funding-tx');
      // Only one side has signed (taker accept) — no funding tx yet.
      expect(liveOrderFundingTxid(accepted), isNull);
    });

    test('settlement explorer links include closing and refund txids', () {
      final order = _order(
        executions: <DlcOrderExecution>[
          _execution(
            closingTxid: 'close-tx',
            refundTxid: 'refund-tx',
          ),
        ],
      );

      expect(
        orderSettlementExplorerLinks(order).map((link) => link.label).toList(),
        ['Settlement TX', 'Refund TX'],
      );
    });
  });

  group('closed orders', () {
    test('cancelled order status shows in closed section only', () {
      final order = _order(
        status: 'cancelled',
        executions: const [],
        dlcId: null,
      );

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
