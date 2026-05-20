import 'dart:typed_data';

import 'package:aqua/features/dlc/crypto/ecdsa_adaptor.dart';
import 'package:aqua/features/dlc/crypto/secp256k1_point.dart';
import 'package:aqua/features/dlc/crypto/secp256k1_scalar.dart';
import 'package:aqua/features/dlc/models/dlc_models.dart';
import 'package:convert/convert.dart';

/// Signs coordinator-provided CET adaptor jobs (message hash + adaptor point).
class CoordinatorCetSigner {
  const CoordinatorCetSigner();

  List<String> signJobs({
    required List<DlcCetSigningJob> jobs,
    required Uint8List fundingPrivateKey32,
  }) {
    if (isZeroPrivateKey(fundingPrivateKey32)) {
      throw ArgumentError('Invalid funding private key');
    }
    final privateKey = scalarFromBytes(fundingPrivateKey32);
    return jobs.map((job) {
      final messageHash = Uint8List.fromList(hex.decode(job.messageHashHex));
      final adaptorPoint = Secp256k1Point.fromCompressed(
        Uint8List.fromList(hex.decode(job.adaptorPointHex)),
      );
      final signature = adaptorEncrypt(
        privateKey: privateKey,
        adaptorPointY: adaptorPoint,
        messageHash: messageHash,
      );
      return hex.encode(signature.serializeWire());
    }).toList();
  }
}
