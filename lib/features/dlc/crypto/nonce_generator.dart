import 'dart:math';
import 'dart:typed_data';

import 'package:aqua/features/dlc/crypto/secp256k1_constants.dart';
import 'package:aqua/features/dlc/crypto/secp256k1_scalar.dart';
import 'package:crypto/crypto.dart';

typedef NonceSampler = BigInt Function(Uint8List input);

/// `scalar(SHA256(data || random_32_bytes))` per DLC spec.
BigInt sampleNonce(
  Uint8List data, {
  NonceSampler? sampler,
  Uint8List? randomOverride,
}) {
  if (sampler != null) {
    return sampler(data) % secp256k1OrderN;
  }
  final randomBytes = randomOverride ?? _secureRandom32();
  final digest = sha256.convert(<int>[...data, ...randomBytes]).bytes;
  return scalarFromBytes(Uint8List.fromList(digest));
}

Uint8List _secureRandom32() {
  final random = Random.secure();
  return Uint8List.fromList(List<int>.generate(32, (_) => random.nextInt(256)));
}

BigInt sampleNonceNonZero(
  Uint8List data, {
  NonceSampler? sampler,
  Uint8List? randomOverride,
}) {
  var nonce = sampleNonce(
    data,
    sampler: sampler,
    randomOverride: randomOverride,
  );
  var attempts = 0;
  while (nonce == BigInt.zero && attempts < 32) {
    nonce = sampleNonce(data, sampler: sampler);
    attempts++;
  }
  if (nonce == BigInt.zero) {
    throw StateError('Failed to sample non-zero nonce');
  }
  return nonce;
}
