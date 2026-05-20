import 'dart:typed_data';

import 'package:aqua/features/dlc/crypto/secp256k1_constants.dart';
import 'package:crypto/crypto.dart';

BigInt scalarFromBytes(Uint8List bytes) {
  var value = BigInt.zero;
  for (final byte in bytes) {
    value = (value << 8) + BigInt.from(byte);
  }
  return value % secp256k1OrderN;
}

Uint8List bigEndian32(BigInt value) {
  final normalized = value % secp256k1OrderN;
  final bytes = Uint8List(32);
  var v = normalized;
  for (var i = 31; i >= 0; i--) {
    bytes[i] = (v & BigInt.from(0xff)).toInt();
    v >>= 8;
  }
  return bytes;
}

BigInt modInverse(BigInt value) {
  if (value == BigInt.zero) {
    throw ArgumentError('Cannot invert zero');
  }
  return value.modInverse(secp256k1OrderN);
}

BigInt modAdd(BigInt a, BigInt b) => (a + b) % secp256k1OrderN;

BigInt modSub(BigInt a, BigInt b) => (a - b) % secp256k1OrderN;

BigInt modMul(BigInt a, BigInt b) => (a * b) % secp256k1OrderN;

/// Untagged hash used by DLEQ: `scalar(SHA256(tag || data))`.
BigInt hScalar(Uint8List tagPrefix, Uint8List data) {
  final digest = sha256.convert(<int>[...tagPrefix, ...data]).bytes;
  return scalarFromBytes(Uint8List.fromList(digest));
}

bool isZeroScalar(BigInt value) => value == BigInt.zero;

bool isValidScalar(BigInt value) =>
    value >= BigInt.zero && value < secp256k1OrderN;

bool isZeroPrivateKey(Uint8List key) =>
    key.length != 32 || key.every((b) => b == 0);
