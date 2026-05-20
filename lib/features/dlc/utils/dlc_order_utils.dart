import 'package:aqua/features/dlc/models/dlc_models.dart';
import 'package:aqua/features/dlc/models/dlc_trade_models.dart';

enum DlcOrderInFlightPhase {
  creatingOnCoordinator,
  takerSigningAccept,
  matchedAwaitingTakerAccept,
  makerSigningDlc,
}

bool isDlcClosedOrder(DlcOrder order) {
  if (order.status == 'cancelled' || order.status == 'closed') {
    return true;
  }
  final dlcStatus = order.dlcStatus;
  if (dlcStatus == null) {
    return false;
  }
  return const {
    'cet_closed',
    'refund_closed',
    'terminated',
  }.contains(dlcStatus);
}

bool orderShowsInOpenSection(DlcOrder order) {
  if (order.orderId.startsWith('local-pending-')) {
    return true;
  }
  return order.isOpen;
}

bool orderShowsInLiveSection(DlcOrder order) {
  if (orderShowsInOpenSection(order) || isDlcClosedOrder(order)) {
    return false;
  }
  return order.needsTakerAccept ||
      order.needsMakerSign ||
      order.isLiveDlc ||
      order.status == 'filled' ||
      order.status == 'pending_accept' ||
      (order.dlcId?.isNotEmpty ?? false);
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
  if (order.signRequired && !order.isMaker) {
    return DlcOrderInFlightPhase.takerSigningAccept;
  }
  return null;
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
