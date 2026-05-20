import 'package:aqua/features/dlc/crypto/secp256k1_constants.dart';
import 'package:aqua/features/dlc/crypto/secp256k1_scalar.dart';

/// BIP62 canonical ECDSA: if `s > n/2`, replace with `n - s`.
BigInt normalizeToLowS(BigInt s) {
  final halfOrder = secp256k1OrderN >> 1;
  if (s > halfOrder) {
    return modSub(secp256k1OrderN, s);
  }
  return s;
}
