import 'package:aqua/features/dlc/models/dlc_models.dart';
import 'package:aqua/features/dlc/services/dlc_api_exception.dart';

bool isDlcContextMismatch(DlcApiException error) {
  final message = error.message.toLowerCase();
  final code = error.errorCode?.toLowerCase() ?? '';

  if (code.contains('context_mismatch') ||
      code.contains('stale_context') ||
      code.contains('stale_accept_context')) {
    return true;
  }

  return message.contains('context_mismatch') ||
      message.contains('stale_context') ||
      message.contains('stale context') ||
      message.contains('stale_accept_context') ||
      message.contains('fingerprint mismatch') ||
      message.contains('signing context fingerprint') ||
      message.contains('context fingerprint');
}

bool isDlcPartnerConfigError(DlcApiException error) {
  if (error.statusCode != 403) {
    return false;
  }
  final message = error.message.toLowerCase();
  return message.contains('partner') || message.contains('x-partner-token');
}

bool orderNeedsNegotiation(DlcOrder order) =>
    order.needsTakerAccept || order.needsMakerSign;

bool orderNeedsFundingMonitor(DlcOrder order) =>
    order.isFundingPending && (order.dlcId?.isNotEmpty ?? false);

/// Live orders whose canonical DLC may move forward without local signing,
/// e.g. waiting for the maker counterparty to call `/sign`, or the taker
/// counterparty to call `/accept-match`. We use the order's top-level
/// `dlc_status` (the maker side of the matched trade) as the source of truth.
bool orderNeedsExecutionRefresh(DlcOrder order) {
  final execution = order.currentExecution;
  if (execution == null) {
    return false;
  }
  if (execution.isTerminal) {
    return false;
  }
  final dlcId = order.dlcId;
  if (dlcId == null || dlcId.isEmpty) {
    return false;
  }
  final status = order.dlcStatus;
  if (status == null) {
    return execution.isPendingAccept;
  }
  if (DlcOrder.terminalDlcStatuses.contains(status)) {
    return false;
  }
  // Anything between pending_accept and funding_broadcasted should be
  // polled until it terminates or transitions into the funding monitor.
  return status != DlcOrder.dlcStatusFundingBroadcasted;
}

bool orderNeedsDlcBackgroundWork(DlcOrder order) =>
    orderNeedsNegotiation(order) ||
    orderNeedsFundingMonitor(order) ||
    orderNeedsExecutionRefresh(order);

bool shouldSyncUtxosForFundingTransition(DlcOrder before, DlcOrder after) {
  if (after.hasFundingCompleted && !before.hasFundingCompleted) {
    return true;
  }
  final beforeTxid = before.fundingTxid;
  final afterTxid = after.fundingTxid;
  return afterTxid != null &&
      afterTxid.isNotEmpty &&
      beforeTxid != afterTxid;
}

String createOrderDraftFingerprint({
  required String instrumentId,
  required String side,
  required num quantity,
  required String fundingPubkeyHex,
}) =>
    '$instrumentId|$side|$quantity|$fundingPubkeyHex';
