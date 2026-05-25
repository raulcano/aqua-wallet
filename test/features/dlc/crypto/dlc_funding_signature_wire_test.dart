import 'dart:typed_data';

import 'package:aqua/features/dlc/crypto/dlc_funding_signature_wire.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dlc_funding_signature_wire', () {
    test('encodeP2wpkhWitnessStack uses BigSize prefixes', () {
      final derSig = Uint8List.fromList(List<int>.generate(72, (index) => index));
      final pubkey =
          Uint8List.fromList(List<int>.generate(33, (index) => 0x20 + index));

      final encoded = encodeP2wpkhWitnessStack(
        derSignatureWithSighash: derSig,
        compressedPublicKey: pubkey,
      );

      expect(encoded.length, 1 + 1 + 72 + 1 + 33);
      expect(encoded[0], 0x02);
      expect(encoded[1], 0x48);
      expect(encoded[2], 0x00);
      expect(encoded[74], 0x21);
      expect(encoded[75], 0x20);
    });

    test('encodeFundingSignaturesContainer wraps all stacks in one payload', () {
      final stack = encodeP2wpkhWitnessStack(
        derSignatureWithSighash: Uint8List.fromList([0x30, 0x01]),
        compressedPublicKey: Uint8List(33),
      );

      final encoded = encodeFundingSignaturesContainer([stack, stack]);

      expect(encoded[0], 0x02);
      expect(encoded.sublist(1, 1 + stack.length), stack);
      expect(encoded.sublist(1 + stack.length), stack);
    });
  });
}
