import 'dart:convert';

import 'package:aqua/features/dlc/crypto/coordinator_wallet_signature.dart';
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

    test('coordinatorNonceMessageHex encodes utf-8 nonce as hex', () {
      expect(
        coordinatorNonceMessageHex('coordinator-test-nonce'),
        '636f6f7264696e61746f722d746573742d6e6f6e6365',
      );
    });

    test('coordinatorNonceSigningDigest double-hashes non-32-byte nonces', () {
      final digest = coordinatorNonceSigningDigest('coordinator-test-nonce');
      expect(digest.length, 32);
    });

    test('coordinatorNonceSigningDigest skips double hash for 32-byte nonces', () {
      final nonce = 'a' * 32;
      final digest = coordinatorNonceSigningDigest(nonce);
      expect(digest, utf8.encode(nonce));
    });

    test('signXpubNonceSignature returns DER hex with SIGHASH_ALL suffix', () {
      const mnemonic =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      const accountUserPath = [84 + 0x80000000, 0 + 0x80000000, 0 + 0x80000000];

      final signature = signer.signXpubNonceSignature(
        nonce: 'coordinator-test-nonce',
        mnemonic: mnemonic,
        accountUserPath: accountUserPath,
      );

      expect(signature, isNotEmpty);
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(signature), isTrue);
      expect(signature.endsWith('01'), isTrue);
      expect(signature.startsWith('30'), isTrue);
    });
  });
}
