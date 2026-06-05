import 'package:aqua/features/dlc/models/dlc_models.dart';
import 'package:aqua/features/dlc/models/dlc_trade_models.dart';

enum DlcOrderInFlightPhase {
  creatingOnCoordinator,
  takerSigningAccept,
  matchedAwaitingTakerAccept,
  makerSigningDlc,
  fundingBroadcastPending,
}

bool isDlcClosedOrder(DlcOrder order) {
  if (order.status == 'cancelled' || order.status == 'closed') {
    return true;
  }
  final dlcStatus = order.dlcStatus;
  return dlcStatus != null && DlcOrder.terminalDlcStatuses.contains(dlcStatus);
}

bool orderShowsInOpenSection(DlcOrder order) {
  if (isDlcClosedOrder(order)) {
    return false;
  }
  return order.status == 'open';
}

bool orderShowsInLiveSection(DlcOrder order) {
  if (isDlcClosedOrder(order) || orderShowsInOpenSection(order)) {
    return false;
  }
  return order.status == 'pending_accept' || order.status == 'filled';
}

bool createResponseIndicatesMatch(DlcOrderResponse response) =>
    response.status == 'pending_accept' || response.status == 'filled';

DlcOrder orderFromCreateResponse({
  required DlcOrderResponse response,
  required DlcOrder pendingOrder,
}) =>
    DlcOrder(
      orderId: response.orderId,
      instrumentId: pendingOrder.instrumentId,
      side: pendingOrder.side,
      status: response.status,
      quantity: pendingOrder.quantity,
      dlcId: response.dlcId.isEmpty ? null : response.dlcId,
      signRequired: response.signRequired,
      pendingMatchAccept: response.pendingMatchAccept,
    );

DlcOrderInFlightPhase? resolveOrderInFlightPhase(DlcOrder order) {
  if (order.orderId.startsWith('local-pending-')) {
    return DlcOrderInFlightPhase.creatingOnCoordinator;
  }
  if (order.needsTakerAccept) {
    return DlcOrderInFlightPhase.matchedAwaitingTakerAccept;
  }
  if (order.needsMakerSign) {
    return DlcOrderInFlightPhase.makerSigningDlc;
  }
  if (order.signRequired && !order.isMaker) {
    return DlcOrderInFlightPhase.takerSigningAccept;
  }
  if (order.isFundingPending) {
    return DlcOrderInFlightPhase.fundingBroadcastPending;
  }
  return null;
}

String formatDlcStatusLabel(DlcOrder order) {
  final status = order.dlcStatus;
  if (status == null || status.isEmpty) {
    return '';
  }
  if (status == DlcOrder.dlcStatusSigned) {
    if (order.lastErrorReason == 'funding_broadcast_failed') {
      return 'Funding broadcast failed';
    }
    return 'Funding broadcast pending';
  }
  if (status == DlcOrder.dlcStatusFundingBroadcasted) {
    return 'Funding broadcasted, awaiting oracle maturity';
  }
  return status.replaceAll('_', ' ');
}

String formatOrderStatusLine(DlcOrder order) {
  final dlcLabel = formatDlcStatusLabel(order);
  if (dlcLabel.isNotEmpty) {
    return dlcLabel;
  }
  return order.status;
}

String formatDlcOrderRole(DlcOrder order) {
  if (order.isMaker) {
    return 'Maker';
  }
  if (order.matchRole != null && order.matchRole!.isNotEmpty) {
    return order.matchRole!;
  }
  return 'Taker';
}

({int open, int live, int closed}) countDlcOrdersBySection(
  List<DlcOrder> orders,
) {
  var open = 0;
  var live = 0;
  var closed = 0;
  for (final order in orders) {
    if (orderShowsInOpenSection(order)) {
      open++;
    } else if (orderShowsInLiveSection(order)) {
      live++;
    } else if (isDlcClosedOrder(order)) {
      closed++;
    }
  }
  return (open: open, live: live, closed: closed);
}

String? bestBidPremiumSats(DlcStrikeOrderbookSnapshot snapshot) {
  final bids = snapshot.orderbook?.bids ?? const [];
  if (bids.isEmpty) {
    return null;
  }
  return bids.first.price.toString();
}

String? bestAskPremiumSats(DlcStrikeOrderbookSnapshot snapshot) {
  final asks = snapshot.orderbook?.asks ?? const [];
  if (asks.isEmpty) {
    return null;
  }
  return asks.first.price.toString();
}

String dlcMempoolTxUrl({
  required String txid,
  required bool isTestnet,
}) {
  final base = isTestnet
      ? 'https://mempool.space/testnet/tx'
      : 'https://mempool.space/tx';
  return '$base/$txid';
}

String? liveOrderFundingTxid(DlcOrder order) {
  if (!order.isFundingBroadcasted) {
    return null;
  }
  final txid = order.fundingTxid;
  if (txid == null || txid.isEmpty) {
    return null;
  }
  return txid;
}

List<({String label, String txid})> orderSettlementExplorerLinks(
  DlcOrder order,
) {
  final links = <({String label, String txid})>[];
  final closingTxid = order.closingTxid;
  if (closingTxid != null && closingTxid.isNotEmpty) {
    links.add((label: 'Settlement TX', txid: closingTxid));
  }
  final refundTxid = order.refundTxid;
  if (refundTxid != null && refundTxid.isNotEmpty) {
    links.add((label: 'Refund TX', txid: refundTxid));
  }
  return links;
}
