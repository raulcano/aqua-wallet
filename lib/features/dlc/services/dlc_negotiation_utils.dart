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

bool orderNeedsDlcBackgroundWork(DlcOrder order) =>
    orderNeedsNegotiation(order) || orderNeedsFundingMonitor(order);

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
