import 'dart:typed_data';

import 'package:aqua/data/models/gdk_models.dart';
import 'package:aqua/features/wallet/utils/derivation_path_utils.dart';
import 'package:bech32/bech32.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/digests/ripemd160.dart';

class DlcFundingInputSigningMaterial {
  const DlcFundingInputSigningMaterial({
    required this.privateKeyHex,
    required this.publicKeyHex,
  });

  final String privateKeyHex;
  final String publicKeyHex;
}

/// Resolves one BIP32 key per coordinator funding input (address-first, then outpoint).
List<DlcFundingInputSigningMaterial> resolveFundingInputSigningMaterials({
  required String mnemonic,
  required String accountDerivationPath,
  required List<GdkUnspentOutputs> walletUtxos,
  required List<String> fundingInputSighashesHex,
  required List<String> fundingInputAddresses,
  required List<String> fundingInputOutpoints,
  required String Function(String mnemonic, String path) derivePrivateKeyHex,
  required String Function(String mnemonic, String path) derivePublicKeyHex,
}) {
  if (fundingInputSighashesHex.isEmpty) {
    return const [];
  }

  final outpointToPath = _buildOutpointPathMap(walletUtxos);
  final scriptToPath = _buildScriptPathMap(
    mnemonic: mnemonic,
    walletUtxos: walletUtxos,
    derivePublicKeyHex: derivePublicKeyHex,
  );

  final materials = <DlcFundingInputSigningMaterial>[];
  for (var i = 0; i < fundingInputSighashesHex.length; i++) {
    final path = _resolvePathForInput(
      index: i,
      mnemonic: mnemonic,
      accountDerivationPath: accountDerivationPath,
      fundingInputAddresses: fundingInputAddresses,
      fundingInputOutpoints: fundingInputOutpoints,
      outpointToPath: outpointToPath,
      scriptToPath: scriptToPath,
      derivePublicKeyHex: derivePublicKeyHex,
    );
    if (path == null) {
      throw StateError(
        'No private key for DLC funding input ${i + 1} of '
        '${fundingInputSighashesHex.length}',
      );
    }
    materials.add(
      DlcFundingInputSigningMaterial(
        privateKeyHex: derivePrivateKeyHex(mnemonic, path),
        publicKeyHex: derivePublicKeyHex(mnemonic, path),
      ),
    );
  }
  return materials;
}

String? _resolvePathForInput({
  required int index,
  required String mnemonic,
  required String accountDerivationPath,
  required List<String> fundingInputAddresses,
  required List<String> fundingInputOutpoints,
  required Map<String, String> outpointToPath,
  required Map<String, String> scriptToPath,
  required String Function(String mnemonic, String path) derivePublicKeyHex,
}) {
  if (index < fundingInputAddresses.length) {
    final address = fundingInputAddresses[index].trim();
    if (address.isNotEmpty) {
      final scriptHex = p2wpkhScriptHexFromAddress(address);
      if (scriptHex != null) {
        final path = scriptToPath[scriptHex];
        if (path != null) {
          return path;
        }
      }
      final scanned = _scanPathForAddress(
        mnemonic: mnemonic,
        accountDerivationPath: accountDerivationPath,
        address: address,
        derivePublicKeyHex: derivePublicKeyHex,
      );
      if (scanned != null) {
        return scanned;
      }
    }
  }

  if (index < fundingInputOutpoints.length) {
    final outpoint = fundingInputOutpoints[index].trim();
    if (outpoint.isNotEmpty) {
      final path = outpointToPath[_normalizeOutpoint(outpoint)];
      if (path != null) {
        return path;
      }
    }
  }

  return null;
}

Map<String, String> _buildOutpointPathMap(List<GdkUnspentOutputs> utxos) {
  final map = <String, String>{};
  for (final utxo in utxos) {
    final txhash = utxo.txhash;
    final vout = utxo.ptIdx;
    final userPath = utxo.userPath;
    if (txhash == null || vout == null || userPath == null) {
      continue;
    }
    final path = _userPathToBip32Path(userPath);
    final normalizedTxid = _normalizeHex(txid: txhash);
    map[_normalizeOutpoint('$normalizedTxid:$vout')] = path;
    map[_normalizeOutpoint('${_reverseHexBytes(normalizedTxid)}:$vout')] = path;
  }
  return map;
}

Map<String, String> _buildScriptPathMap({
  required String mnemonic,
  required List<GdkUnspentOutputs> walletUtxos,
  required String Function(String mnemonic, String path) derivePublicKeyHex,
}) {
  final map = <String, String>{};
  for (final utxo in walletUtxos) {
    final userPath = utxo.userPath;
    if (userPath == null) {
      continue;
    }
    final path = _userPathToBip32Path(userPath);
    final scriptHex = _utxoScriptHex(utxo) ??
        p2wpkhScriptHexFromPubkeyHex(
          derivePublicKeyHex(mnemonic, path),
        );
    if (scriptHex != null) {
      map[scriptHex] = path;
    }
  }
  return map;
}

String? _utxoScriptHex(GdkUnspentOutputs utxo) {
  final script = utxo.script ?? utxo.prevoutScript;
  if (script == null || script.isEmpty) {
    return null;
  }
  return _normalizeHex(txid: script);
}

String? _scanPathForAddress({
  required String mnemonic,
  required String accountDerivationPath,
  required String address,
  required String Function(String mnemonic, String path) derivePublicKeyHex,
}) {
  final targetScript = p2wpkhScriptHexFromAddress(address);
  if (targetScript == null) {
    return null;
  }
  for (final chain in [0, 1]) {
    for (var index = 0; index < 1000; index++) {
      final path = '$accountDerivationPath/$chain/$index';
      final script = p2wpkhScriptHexFromPubkeyHex(
        derivePublicKeyHex(mnemonic, path),
      );
      if (script == targetScript) {
        return path;
      }
    }
  }
  return null;
}

String? p2wpkhScriptHexFromAddress(String address) {
  try {
    final decoded = const Bech32Codec().decode(address, address.length);
    if (decoded.hrp != 'bc' && decoded.hrp != 'tb') {
      return null;
    }
    if (decoded.data.isEmpty || decoded.data.first != 0) {
      return null;
    }
    final program = _convertBits(decoded.data.sublist(1), 5, 8, false);
    if (program.length != 20) {
      return null;
    }
    return '0014${hex.encode(program)}';
  } catch (_) {
    return null;
  }
}

String p2wpkhScriptHexFromPubkeyHex(String publicKeyHex) {
  final normalized = publicKeyHex.toLowerCase().replaceFirst(RegExp('^0x'), '');
  final pubkeyBytes = hex.decode(normalized);
  final hash = _hash160(pubkeyBytes);
  return '0014${hex.encode(hash)}';
}

Uint8List _hash160(List<int> bytes) {
  final sha = crypto.sha256.convert(bytes).bytes;
  return RIPEMD160Digest().process(Uint8List.fromList(sha));
}

List<int> _convertBits(
  List<int> data,
  int fromBits,
  int toBits,
  bool pad,
) {
  var acc = 0;
  var bits = 0;
  final maxv = (1 << toBits) - 1;
  final result = <int>[];
  for (final value in data) {
    acc = (acc << fromBits) | value;
    bits += fromBits;
    while (bits >= toBits) {
      bits -= toBits;
      result.add((acc >> bits) & maxv);
    }
  }
  if (pad) {
    if (bits > 0) {
      result.add((acc << (toBits - bits)) & maxv);
    }
  } else if (bits >= fromBits || ((acc << (toBits - bits)) & maxv) != 0) {
    throw ArgumentError('Invalid bech32 padding');
  }
  return result;
}

String _normalizeOutpoint(String outpoint) => outpoint.trim().toLowerCase();

String _normalizeHex({required String txid}) =>
    txid.toLowerCase().replaceFirst(RegExp('^0x'), '');

String _reverseHexBytes(String value) {
  final bytes = <int>[
    for (var i = 0; i < value.length; i += 2)
      int.parse(value.substring(i, i + 2), radix: 16),
  ];
  return bytes
      .reversed
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

bool isBitcoinTestnetAccountPath(List<int> accountUserPath) {
  if (accountUserPath.length < 2) {
    return false;
  }
  return DerivationPathUtils.unhardenIndex(accountUserPath[1]) == 1;
}

String _userPathToBip32Path(List<int> userPath) {
  final parts = userPath.map((index) {
    final unhardened = DerivationPathUtils.unhardenIndex(index);
    final isHardened = DerivationPathUtils.isHardened(index);
    return isHardened ? "$unhardened'" : '$unhardened';
  }).join('/');
  return 'm/$parts';
}
