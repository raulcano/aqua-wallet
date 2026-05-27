import 'dart:convert';
import 'dart:typed_data';

import 'package:aqua/features/dlc/crypto/low_s.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// UTF-8 nonce encoded as hex (`nonce.encode("utf-8").hex()` in Python).
String coordinatorNonceMessageHex(String nonce) =>
    hex.encode(utf8.encode(nonce));

/// Digest passed to ECDSA for coordinator wallet-registration nonce signing.
///
/// Mirrors bitcoinlib `sign(message_hex, key)` and backend verification:
/// - decode `message_hex` to bytes
/// - if length is not 32, apply double-SHA256
/// - otherwise sign the 32-byte message directly
Uint8List coordinatorNonceSigningDigest(String nonce) {
  final messageBytes = Uint8List.fromList(utf8.encode(nonce));
  if (messageBytes.length == 32) {
    return messageBytes;
  }
  return _doubleSha256(messageBytes);
}

/// DER-encoded ECDSA signature hex for coordinator wallet registration.
///
/// Output matches `bitcoinlib_sign(...).as_der_encoded().hex()` (DER + SIGHASH_ALL).
String signCoordinatorNonceDerHex({
  required String nonce,
  required String accountPrivateKeyHex,
}) {
  final digest = coordinatorNonceSigningDigest(nonce);
  var signature = _signDigest(
    digest: digest,
    privateKeyHex: accountPrivateKeyHex,
  );
  final normalizedS = normalizeToLowS(signature.s);
  if (normalizedS != signature.s) {
    signature = ECSignature(signature.r, normalizedS);
  }
  return _derEncodeWithHashType(signature);
}

ECSignature _signDigest({
  required Uint8List digest,
  required String privateKeyHex,
}) {
  final params = ECDomainParameters('secp256k1');
  final privateKey = ECPrivateKey(
    BigInt.parse(privateKeyHex, radix: 16),
    params,
  );
  final signer = ECDSASigner(null, HMac(SHA256Digest(), 64));
  signer.init(true, PrivateKeyParameter<ECPrivateKey>(privateKey));
  return signer.generateSignature(digest) as ECSignature;
}

String _derEncodeWithHashType(ECSignature signature) {
  final r = _encodeDerInt(signature.r);
  final s = _encodeDerInt(signature.s);
  final body = <int>[0x02, r.length, ...r, 0x02, s.length, ...s];
  return hex.encode(<int>[0x30, body.length, ...body, 0x01]);
}

List<int> _encodeDerInt(BigInt value) {
  var bytes = value.toRadixString(16);
  if (bytes.length.isOdd) {
    bytes = '0$bytes';
  }
  final out = hex.decode(bytes);
  if (out.isNotEmpty && out.first >= 0x80) {
    return <int>[0x00, ...out];
  }
  return out;
}

Uint8List _doubleSha256(Uint8List data) {
  final first = sha256.convert(data);
  return Uint8List.fromList(sha256.convert(first.bytes).bytes);
}
