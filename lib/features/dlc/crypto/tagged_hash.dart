import 'dart:convert';
import 'dart:typed_data';

import 'package:aqua/features/dlc/crypto/secp256k1_constants.dart';
import 'package:aqua/features/dlc/crypto/secp256k1_scalar.dart';
import 'package:crypto/crypto.dart';

final Map<String, Uint8List> _tagPrefixCache = {};

Uint8List taggedHashPrefix(String tag) {
  return _tagPrefixCache.putIfAbsent(tag, () {
    final tagBytes = utf8.encode(tag);
    final hash = sha256.convert(tagBytes).bytes;
    return Uint8List.fromList(<int>[...hash, ...hash]);
  });
}

Uint8List taggedHash(String tag, Uint8List data) {
  final prefix = taggedHashPrefix(tag);
  final digest = sha256.convert(<int>[...prefix, ...data]).bytes;
  return Uint8List.fromList(digest);
}

BigInt taggedHashScalar(String tag, Uint8List data) =>
    scalarFromBytes(taggedHash(tag, data));

Uint8List dleqTagPrefix() => taggedHashPrefix(dleqTagAscii);
