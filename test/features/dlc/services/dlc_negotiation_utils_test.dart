import 'package:aqua/features/dlc/models/dlc_models.dart';
import 'package:aqua/features/dlc/services/dlc_api_exception.dart';
import 'package:aqua/features/dlc/services/dlc_negotiation_utils.dart';
import 'package:flutter_test/flutter_test.dart';

DlcOrder _order({
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
    dlcId: dlcId,
    dlcStatus: dlcStatus,
  );
}

void main() {
  group('isDlcContextMismatch', () {
    test('matches coordinator fingerprint mismatch message', () {
      final error = DlcApiException(
        message: 'Sign signing context fingerprint mismatch',
        statusCode: 409,
      );

      expect(isDlcContextMismatch(error), isTrue);
    });

    test('matches structured context_mismatch error code', () {
      final error = DlcApiException(
        message: 'Conflict',
        statusCode: 409,
        errorCode: 'context_mismatch',
      );

      expect(isDlcContextMismatch(error), isTrue);
    });

    test('does not match unrelated 409 errors', () {
      final error = DlcApiException(
        message: 'Order already exists',
        statusCode: 409,
      );

      expect(isDlcContextMismatch(error), isFalse);
    });
  });

  group('funding monitor helpers', () {
    test('orderNeedsFundingMonitor is true only for signed DLCs', () {
      final signed = _order(dlcStatus: 'signed');
      final funded = _order(dlcStatus: 'funding_broadcasted');

      expect(orderNeedsFundingMonitor(signed), isTrue);
      expect(orderNeedsFundingMonitor(funded), isFalse);
      expect(orderNeedsDlcBackgroundWork(signed), isTrue);
    });

    test('shouldSyncUtxosForFundingTransition detects first funding txid', () {
      final before = _order(dlcStatus: 'signed');
      final after = DlcOrder(
        orderId: before.orderId,
        instrumentId: before.instrumentId,
        side: before.side,
        status: before.status,
        quantity: before.quantity,
        dlcId: before.dlcId,
        dlcStatus: DlcOrder.dlcStatusFundingBroadcasted,
        fundingTxid: 'abc123',
      );

      expect(shouldSyncUtxosForFundingTransition(before, after), isTrue);
    });
  });
}
