import 'dart:typed_data';

import 'package:aqua/features/dlc/crypto/dleq.dart';
import 'package:aqua/features/dlc/crypto/ecdsa_adaptor_signature.dart';
import 'package:aqua/features/dlc/crypto/low_s.dart';
import 'package:aqua/features/dlc/crypto/nonce_generator.dart';
import 'package:aqua/features/dlc/crypto/secp256k1_point.dart';
import 'package:aqua/features/dlc/crypto/secp256k1_constants.dart';
import 'package:aqua/features/dlc/crypto/secp256k1_scalar.dart';

/// Encrypt/sign a CET funding input using ECDSA adaptor signatures.
EcdsaAdaptorSignature adaptorEncrypt({
  required BigInt privateKey,
  required Secp256k1Point adaptorPointY,
  required Uint8List messageHash,
  NonceSampler? nonceSampler,
}) {
  if (privateKey == BigInt.zero) {
    throw ArgumentError('Invalid private key');
  }
  if (messageHash.length != 32) {
    throw ArgumentError('message_hash must be 32 bytes');
  }
  if (adaptorPointY.isInfinity) {
    throw ArgumentError('Adaptor point must not be infinity');
  }

  final xBytes = bigEndian32(privateKey);
  final nonceInput = Uint8List.fromList(<int>[
    ...adaptorPointY.toCompressed(),
    ...messageHash,
    ...xBytes,
  ]);
  final k = sampleNonceNonZero(nonceInput, sampler: nonceSampler);
  final m = scalarFromBytes(messageHash);
  final raPoint = scalarBaseMult(k);
  final rPoint = adaptorPointY.multiply(k);
  if (rPoint.isInfinity || raPoint.isInfinity) {
    throw StateError('Derived R or R_a is infinity');
  }
  final proof = dleqProve(k, raPoint, adaptorPointY, rPoint, nonceSampler: nonceSampler);
  final r = rPoint.xScalar();
  final sA = modMul(modInverse(k), modAdd(m, modMul(r, privateKey)));
  return EcdsaAdaptorSignature(
    rPoint: rPoint,
    raPoint: raPoint,
    sA: sA,
    proof: proof,
  );
}

bool adaptorVerify({
  required Secp256k1Point signerPublicKey,
  required Secp256k1Point adaptorPointY,
  required Uint8List messageHash,
  required EcdsaAdaptorSignature signature,
}) {
  if (messageHash.length != 32) {
    return false;
  }
  final primitive = signature.toEncryptedAdaptorBytes();
  try {
    final parsed = EcdsaAdaptorSignature.deserializePrimitive(primitive);
    if (!dleqVerify(parsed.raPoint, adaptorPointY, parsed.rPoint, parsed.proof)) {
      return false;
    }
    final m = scalarFromBytes(messageHash);
    final r = parsed.rPoint.xScalar();
    final u1 = modMul(modInverse(parsed.sA), m);
    final u2 = modMul(modInverse(parsed.sA), r);
    final lhs = scalarBaseMult(u1).add(signerPublicKey.multiply(u2));
    return lhs == parsed.raPoint;
  } catch (_) {
    return false;
  }
}

EcdsaSignature adaptorDecrypt({
  required EcdsaAdaptorSignature signature,
  required BigInt decryptionKey,
}) {
  final primitive = signature.toEncryptedAdaptorBytes();
  final parsed = EcdsaAdaptorSignature.deserializePrimitive(primitive);
  final s = normalizeToLowS(modMul(parsed.sA, modInverse(decryptionKey)));
  final r = parsed.rPoint.xScalar();
  return EcdsaSignature(r: r, s: s);
}

BigInt adaptorRecover({
  required Secp256k1Point adaptorPointY,
  required EcdsaAdaptorSignature signature,
  required EcdsaSignature decryptedSignature,
}) {
  final primitive = signature.toEncryptedAdaptorBytes();
  final parsed = EcdsaAdaptorSignature.deserializePrimitive(primitive);
  final rImplied = parsed.rPoint.xScalar();
  if (rImplied != decryptedSignature.r) {
    throw ArgumentError('R value does not match decrypted signature');
  }
  final y = modMul(modInverse(decryptedSignature.s), parsed.sA);
  final yPoint = scalarBaseMult(y);
  if (yPoint == adaptorPointY) {
    return y;
  }
  final negY = modSub(secp256k1OrderN, y);
  if (yPoint == adaptorPointY.negate()) {
    return negY;
  }
  throw ArgumentError('Y_implied does not match Y or -Y');
}
