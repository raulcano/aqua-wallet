import 'dart:typed_data';

import 'package:aqua/features/dlc/crypto/dlc_ecdsa_der.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('compactSecp256k1SignatureToDerHex', () {
    test('encodes 64-byte compact signature as DER', () {
      final compact = Uint8List.fromList(List<int>.filled(64, 1));
      compact[0] = 0x01;
      compact[32] = 0x02;

      final der = compactSecp256k1SignatureToDerHex(compact);

      expect(der.startsWith('30'), isTrue);
      expect(der.length, greaterThan(64));
    });

    test('appends SIGHASH_ALL when requested', () {
      final compact = Uint8List.fromList(List<int>.filled(64, 1));

      final der = compactSecp256k1SignatureToDerHex(
        compact,
        includeHashType: true,
      );

      expect(der.endsWith('01'), isTrue);
    });
  });
}
