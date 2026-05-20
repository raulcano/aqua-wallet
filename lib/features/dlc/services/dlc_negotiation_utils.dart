import 'package:aqua/features/dlc/models/dlc_models.dart';
import 'package:aqua/features/dlc/services/dlc_api_exception.dart';

bool isDlcContextMismatch(DlcApiException error) {
  final message = error.message.toLowerCase();
  return message.contains('context_mismatch') ||
      message.contains('stale_context') ||
      message.contains('stale context');
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

String createOrderDraftFingerprint({
  required String instrumentId,
  required String side,
  required num quantity,
  required String fundingPubkeyHex,
}) =>
    '$instrumentId|$side|$quantity|$fundingPubkeyHex';
