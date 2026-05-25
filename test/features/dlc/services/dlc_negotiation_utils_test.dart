import 'package:aqua/features/dlc/services/dlc_api_exception.dart';
import 'package:aqua/features/dlc/services/dlc_negotiation_utils.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
