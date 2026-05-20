import 'dart:typed_data';

import 'package:aqua/features/dlc/crypto/secp256k1_constants.dart';
import 'package:aqua/features/dlc/crypto/secp256k1_scalar.dart';
import 'package:pointycastle/ecc/api.dart';

/// Wrapper around a secp256k1 point (Pointycastle [ECPoint]).
class Secp256k1Point {
  Secp256k1Point._(this._point);

  final ECPoint _point;

  bool get isInfinity => _point.isInfinity;

  factory Secp256k1Point.fromCompressed(Uint8List bytes) {
    if (bytes.length != 33) {
      throw ArgumentError('Compressed point must be 33 bytes');
    }
    final point = secp256k1Curve.curve.decodePoint(bytes);
    if (point == null || point.isInfinity) {
      throw ArgumentError('Invalid compressed point');
    }
    return Secp256k1Point._(point);
  }

  factory Secp256k1Point.generator() => Secp256k1Point._(generatorPoint);

  static final Secp256k1Point infinity = Secp256k1Point._(
    secp256k1Curve.curve.infinity!,
  );

  Uint8List toCompressed() {
    if (isInfinity) {
      throw StateError('Cannot compress point at infinity');
    }
    return _point.getEncoded(true);
  }

  Uint8List toXOnly() {
    if (isInfinity) {
      throw StateError('Cannot get x-only for point at infinity');
    }
    return bigEndian32(_point.x!.toBigInteger()!);
  }

  BigInt xScalar() {
    if (isInfinity) {
      throw StateError('Cannot get x coordinate of infinity');
    }
    return scalarFromBytes(toXOnly());
  }

  Secp256k1Point negate() {
    if (isInfinity) {
      return infinity;
    }
    final field = secp256k1FieldP;
    final y = _point.y!.toBigInteger()!;
    final negY = field - y;
    final negated = secp256k1Curve.curve.createPoint(
      _point.x!.toBigInteger()!,
      negY,
    );
    return Secp256k1Point._(negated);
  }

  Secp256k1Point add(Secp256k1Point other) {
    if (isInfinity) {
      return other;
    }
    if (other.isInfinity) {
      return this;
    }
    final result = _point + other._point;
    if (result == null || result.isInfinity) {
      return infinity;
    }
    return Secp256k1Point._(result);
  }

  Secp256k1Point subtract(Secp256k1Point other) => add(other.negate());

  Secp256k1Point multiply(BigInt scalar) {
    final k = scalar % secp256k1OrderN;
    if (k == BigInt.zero || isInfinity) {
      return infinity;
    }
    final result = _point * k;
    if (result == null || result.isInfinity) {
      return infinity;
    }
    return Secp256k1Point._(result);
  }

  @override
  bool operator ==(Object other) {
    if (other is! Secp256k1Point) {
      return false;
    }
    if (isInfinity && other.isInfinity) {
      return true;
    }
    if (isInfinity || other.isInfinity) {
      return false;
    }
    return toCompressed().toString() == other.toCompressed().toString();
  }

  @override
  int get hashCode => toCompressed().hashCode;
}

Secp256k1Point scalarBaseMult(BigInt scalar) =>
    Secp256k1Point.generator().multiply(scalar);
