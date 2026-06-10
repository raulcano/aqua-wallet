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
  if (order.status == 'rejected' || order.status == 'expired') {
    final hasExecution = order.executions.any((e) => !e.isTerminal);
    if (!hasExecution) {
      return true;
    }
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

/// True when `POST /orders` came back with an attached execution (immediate
/// taker match). Unmatched orders only carry a draft offer.
bool createResponseIndicatesMatch(DlcOrderResponse response) =>
    response.isMatchedImmediately;

/// Builds a local optimistic order from `POST /orders` while we wait for the
/// next `GET /orders` reconcile to fetch full execution detail. Mirrors how
/// the coordinator returns DLC live state at the top level of the order.
DlcOrder orderFromCreateResponse({
  required DlcOrderResponse response,
  required DlcOrder pendingOrder,
}) {
  final latest =
      response.executions.isEmpty ? null : response.executions.last;
  final dlcId = response.dlcId ?? latest?.dlcId;
  return DlcOrder(
    orderId: response.orderId,
    instrumentId: pendingOrder.instrumentId,
    side: pendingOrder.side,
    status: response.status,
    quantity: pendingOrder.quantity,
    draftOfferObjectHex: response.executions.isEmpty
        ? response.offerObjectHex
        : null,
    executions: response.executions,
    dlcId: (dlcId == null || dlcId.isEmpty) ? null : dlcId,
    // Immediate match always parks the trade in pending_accept until the
    // taker submits accept-match.
    dlcStatus:
        response.executions.isEmpty ? null : latest?.dlcStatus ?? 'pending_accept',
  );
}

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
  final execution = order.currentExecution;
  if (execution != null &&
      execution.role == DlcExecutionRole.taker &&
      order.status == 'pending_accept' &&
      execution.isPendingAccept) {
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
    if (_lastErrorReason(order) == 'funding_broadcast_failed') {
      return 'Funding broadcast failed';
    }
    return 'Funding broadcast pending';
  }
  if (status == DlcOrder.dlcStatusFundingBroadcasted) {
    return 'Funding broadcasted, awaiting oracle maturity';
  }
  return status.replaceAll('_', ' ');
}

/// Human-readable description of the live order's current signing/broadcast
/// step from the perspective of this wallet. Returns the empty string when the
/// order is not in a signing/broadcast phase (e.g. fresh resting order).
///
/// Knowing which side is signing is important: in the canonical-DLC model the
/// taker drives `accept-match` first, then the maker drives `/sign`. Surfacing
/// "Taker signing" vs "Awaiting maker signature" tells the user whose action is
/// pending without having to inspect raw DLC statuses.
String formatLiveOrderActivity(DlcOrder order) {
  final execution = order.currentExecution;
  final dlcStatus = order.dlcStatus;

  // No execution yet: only meaningful for the optimistic local-pending order.
  if (execution == null) {
    if (order.status == 'pending_accept') {
      return 'Match in progress';
    }
    return '';
  }

  // Acceptance phase.
  if (dlcStatus == 'pending_accept' || order.status == 'pending_accept') {
    return order.isTaker
        ? 'Taker signing acceptance'
        : 'Awaiting taker acceptance';
  }

  // Sign phase.
  if (dlcStatus == 'accepted') {
    return order.isMaker
        ? 'Maker signing DLC'
        : 'Awaiting maker signature';
  }

  if (dlcStatus == DlcOrder.dlcStatusSigned) {
    if (_lastErrorReason(order) == 'funding_broadcast_failed') {
      return 'Both signed · funding broadcast failed';
    }
    return 'Both signed · funding broadcast pending';
  }

  if (dlcStatus == DlcOrder.dlcStatusFundingBroadcasted) {
    return 'Both signed · funding broadcasted';
  }

  return '';
}

String formatOrderStatusLine(DlcOrder order) {
  final activity = formatLiveOrderActivity(order);
  if (activity.isNotEmpty) {
    return activity;
  }
  final dlcLabel = formatDlcStatusLabel(order);
  if (dlcLabel.isNotEmpty) {
    return dlcLabel;
  }
  return order.status;
}

String formatDlcOrderRole(DlcOrder order) {
  switch (order.walletRole) {
    case DlcExecutionRole.maker:
      return 'Maker';
    case DlcExecutionRole.taker:
      return 'Taker';
    case DlcExecutionRole.unknown:
      // Resting orders without an execution yet — surface as "Maker"
      // because the wallet posted a resting order on the book.
      return order.isOpen ? 'Maker' : 'Pending';
  }
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
  // Once both parties have signed (dlc_status reaches `signed` or beyond),
  // the funding transaction is constructed and its txid is available. We
  // surface the mempool link as soon as the coordinator returns the txid,
  // regardless of whether broadcast already confirmed.
  final dlcStatus = order.dlcStatus;
  if (dlcStatus == null || dlcStatus.isEmpty) {
    return null;
  }
  const fundingExposedStatuses = <String>{
    DlcOrder.dlcStatusSigned,
    DlcOrder.dlcStatusFundingBroadcasted,
    'matured',
    'attested',
  };
  if (!fundingExposedStatuses.contains(dlcStatus)) {
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

String? _lastErrorReason(DlcOrder order) {
  if (order.lastErrorReason != null && order.lastErrorReason!.isNotEmpty) {
    return order.lastErrorReason;
  }
  return order.currentExecution?.lastErrorReason;
}
