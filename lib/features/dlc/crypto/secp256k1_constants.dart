import 'package:pointycastle/ecc/curves/secp256k1.dart';

/// secp256k1 curve parameters (Pointycastle-backed).
final secp256k1Curve = ECCurve_secp256k1();

/// Curve order *n*.
final BigInt secp256k1OrderN = secp256k1Curve.n;

/// Field modulus *p*.
final BigInt secp256k1FieldP = BigInt.parse(
  'fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f',
  radix: 16,
);

/// Standard generator *G* (uncompressed encoding used internally).
final generatorPoint = secp256k1Curve.G;

/// BIP62 high-S threshold.
final BigInt bip62HighSMax = BigInt.parse(
  '7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E73357A4501DDFE92F46681B20A0',
  radix: 16,
);

/// BIP62 low-S replacement constant.
final BigInt bip62ReplacementS = BigInt.parse(
  'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141',
  radix: 16,
);

const String oracleAttestationTag = 'DLC/oracle/attestation/v0';
const String bip340ChallengeTag = 'BIP0340/challenge';
const String dleqTagAscii = 'DLEQ';

const int kWireEcdsaAdaptorBytes = 65;
const int kWireDleqProofBytes = 97;
const int kWireCetAdaptorEntryBytes = 162;
const int kEncryptedAdaptorTotalBytes = 162;
