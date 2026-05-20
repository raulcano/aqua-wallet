import 'dart:typed_data';

import 'package:aqua/features/dlc/crypto/low_s.dart';
import 'package:aqua/features/dlc/crypto/secp256k1_constants.dart';
import 'package:aqua/features/dlc/crypto/secp256k1_point.dart';
import 'package:aqua/features/dlc/crypto/secp256k1_scalar.dart';

class EcdsaAdaptorSignature {
  EcdsaAdaptorSignature({
    required this.rPoint,
    required this.raPoint,
    required this.sA,
    required this.proof,
  }) {
    if (rPoint.isInfinity || raPoint.isInfinity) {
      throw ArgumentError('Adaptor signature points must not be infinity');
    }
    if (proof.length != 64) {
      throw ArgumentError('DLEQ proof must be 64 bytes');
    }
    if (!isValidScalar(sA)) {
      throw ArgumentError('s_a out of range');
    }
  }

  final Secp256k1Point rPoint;
  final Secp256k1Point raPoint;
  final BigInt sA;
  final Uint8List proof;

  /// DLC coordinator wire layout: `R ‖ s_a ‖ R_a ‖ proof` (162 bytes).
  Uint8List serializeWire() => Uint8List.fromList(<int>[
        ...rPoint.toCompressed(),
        ...bigEndian32(sA),
        ...raPoint.toCompressed(),
        ...proof,
      ]);

  /// Primitive / verify-decrypt layout: `R ‖ R_a ‖ s_a ‖ proof` (162 bytes).
  Uint8List toEncryptedAdaptorBytes() => Uint8List.fromList(<int>[
        ...rPoint.toCompressed(),
        ...raPoint.toCompressed(),
        ...bigEndian32(sA),
        ...proof,
      ]);

  static EcdsaAdaptorSignature deserializePrimitive(Uint8List data) {
    if (data.length != kEncryptedAdaptorTotalBytes) {
      throw ArgumentError('Invalid adaptor signature length');
    }
    return EcdsaAdaptorSignature(
      rPoint: Secp256k1Point.fromCompressed(data.sublist(0, 33)),
      raPoint: Secp256k1Point.fromCompressed(data.sublist(33, 66)),
      sA: scalarFromBytes(data.sublist(66, 98)),
      proof: Uint8List.fromList(data.sublist(98, 162)),
    );
  }

  static EcdsaAdaptorSignature deserializeWire(Uint8List data) {
    if (data.length != kWireCetAdaptorEntryBytes) {
      throw ArgumentError('Invalid wire adaptor signature length');
    }
    return EcdsaAdaptorSignature(
      rPoint: Secp256k1Point.fromCompressed(data.sublist(0, 33)),
      sA: scalarFromBytes(data.sublist(33, 65)),
      raPoint: Secp256k1Point.fromCompressed(data.sublist(65, 98)),
      proof: Uint8List.fromList(data.sublist(98, 162)),
    );
  }
}

class EcdsaSignature {
  EcdsaSignature({required this.r, required this.s});

  final BigInt r;
  final BigInt s;

  Uint8List serialize() => Uint8List.fromList(<int>[
        ...bigEndian32(r),
        ...bigEndian32(normalizeToLowS(s)),
      ]);

  static EcdsaSignature deserialize(Uint8List data) {
    if (data.length != 64) {
      throw ArgumentError('ECDSA signature must be 64 bytes');
    }
    return EcdsaSignature(
      r: scalarFromBytes(data.sublist(0, 32)),
      s: scalarFromBytes(data.sublist(32, 64)),
    );
  }
}
