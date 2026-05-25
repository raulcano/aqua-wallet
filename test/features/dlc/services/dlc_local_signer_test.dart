import 'package:aqua/features/dlc/services/dlc_local_signer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DlcLocalSigner', () {
    const signer = DlcLocalSigner();
    const privateKeyHex =
        '0000000000000000000000000000000000000000000000000000000000000001';
    const sighashHex =
        '0000000000000000000000000000000000000000000000000000000000000001';

    test('signSighashHex returns compact 128 hex characters', () {
      final signature = signer.signSighashHex(
        sighashHex: sighashHex,
        privateKeyHex: privateKeyHex,
      );

      expect(signature.length, 128);
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(signature), isTrue);
    });

    test('signSighashDerHex returns DER + SIGHASH', () {
      final signature = signer.signSighashDerHex(
        sighashHex: sighashHex,
        privateKeyHex: privateKeyHex,
      );

      expect(signature.length, greaterThan(128));
      expect(signature.endsWith('01'), isTrue);
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(signature), isTrue);
    });
  });
}
