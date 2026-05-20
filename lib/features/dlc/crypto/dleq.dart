import 'dart:typed_data';

import 'package:aqua/features/dlc/crypto/nonce_generator.dart';
import 'package:aqua/features/dlc/crypto/secp256k1_point.dart';
import 'package:aqua/features/dlc/crypto/secp256k1_scalar.dart';
import 'package:aqua/features/dlc/crypto/tagged_hash.dart';

Uint8List dleqProve(
  BigInt witnessK,
  Secp256k1Point xPoint,
  Secp256k1Point yPoint,
  Secp256k1Point zPoint, {
  NonceSampler? nonceSampler,
}) {
  final tag = dleqTagPrefix();
  final kBytes = bigEndian32(witnessK);
  final nonceInput = Uint8List.fromList(<int>[
    ...tag,
    ...xPoint.toCompressed(),
    ...yPoint.toCompressed(),
    ...zPoint.toCompressed(),
    ...kBytes,
  ]);
  final a = sampleNonceNonZero(nonceInput, sampler: nonceSampler);
  final aG = scalarBaseMult(a);
  final aY = yPoint.multiply(a);
  final challengeInput = Uint8List.fromList(<int>[
    ...xPoint.toCompressed(),
    ...yPoint.toCompressed(),
    ...zPoint.toCompressed(),
    ...aG.toCompressed(),
    ...aY.toCompressed(),
  ]);
  final b = hScalar(tag, challengeInput);
  final c = modAdd(a, modMul(b, witnessK));
  return Uint8List.fromList(<int>[...bigEndian32(b), ...bigEndian32(c)]);
}

bool dleqVerify(
  Secp256k1Point xPoint,
  Secp256k1Point yPoint,
  Secp256k1Point zPoint,
  Uint8List proof,
) {
  if (proof.length != 64) {
    return false;
  }
  final tag = dleqTagPrefix();
  final b = scalarFromBytes(proof.sublist(0, 32));
  final c = scalarFromBytes(proof.sublist(32, 64));
  final aG = scalarBaseMult(c).subtract(xPoint.multiply(b));
  final aY = yPoint.multiply(c).subtract(zPoint.multiply(b));
  final challengeInput = Uint8List.fromList(<int>[
    ...xPoint.toCompressed(),
    ...yPoint.toCompressed(),
    ...zPoint.toCompressed(),
    ...aG.toCompressed(),
    ...aY.toCompressed(),
  ]);
  final impliedB = hScalar(tag, challengeInput);
  return impliedB == b;
}
