import 'dart:convert';
import 'dart:typed_data';

import 'package:aqua/data/models/gdk_models.dart';
import 'package:aqua/features/dlc/crypto/coordinator_cet_signer.dart';
import 'package:aqua/features/dlc/models/dlc_models.dart';
import 'package:aqua/features/wallet/utils/derivation_path_utils.dart';
import 'package:bip32/bip32.dart' as bip32;
import 'package:bip39/bip39.dart' as bip39;
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

class DlcLocalSigner {
  const DlcLocalSigner({CoordinatorCetSigner? cetSigner})
      : _cetSigner = cetSigner ?? const CoordinatorCetSigner();

  final CoordinatorCetSigner _cetSigner;

  bip32.BIP32 _masterNode(String mnemonic) {
    final seed = bip39.mnemonicToSeed(mnemonic.trim());
    return bip32.BIP32.fromSeed(seed);
  }

  String accountDerivationPath(List<int> userPath) {
    if (userPath.length < 3) {
      throw StateError('Invalid account user path for DLC signing');
    }
    return userPathToBip32Path(userPath.sublist(0, 3));
  }

  String fundingDerivationPath(List<int> accountUserPath) =>
      '${accountDerivationPath(accountUserPath)}/0/0';

  String deriveAccountXpub(String mnemonic, List<int> accountUserPath) {
    final accountNode =
        _masterNode(mnemonic).derivePath(accountDerivationPath(accountUserPath));
    return accountNode.neutered().toBase58();
  }

  DlcFundingPubkey deriveFundingPubkey(
    String mnemonic,
    List<int> accountUserPath,
  ) {
    final path = fundingDerivationPath(accountUserPath);
    final node = _masterNode(mnemonic).derivePath(path);
    return DlcFundingPubkey(
      pubkeyHex: hex.encode(node.publicKey),
      derivationPath: path,
    );
  }

  String derivePrivateKeyHexAtPath(String mnemonic, String path) {
    final node = _masterNode(mnemonic).derivePath(path);
    final privateKey = node.privateKey;
    if (privateKey == null) {
      throw StateError('Cannot derive private key at $path');
    }
    return hex.encode(privateKey);
  }

  List<String> signNonceProofCandidates({
    required String nonce,
    required String mnemonic,
    required List<int> accountUserPath,
  }) {
    final accountPath = accountDerivationPath(accountUserPath);
    final fundingPath = fundingDerivationPath(accountUserPath);
    final keys = <String>{
      derivePrivateKeyHexAtPath(mnemonic, accountPath),
      derivePrivateKeyHexAtPath(mnemonic, fundingPath),
    };

    final digests = <Uint8List>{
      Uint8List.fromList(sha256.convert(utf8.encode(nonce)).bytes),
      Uint8List.fromList(
        sha256.convert(utf8.encode(hex.encode(utf8.encode(nonce)))).bytes,
      ),
      Uint8List.fromList(
        sha256
            .convert(sha256.convert(utf8.encode(nonce)).bytes)
            .bytes,
      ),
    };

    final signatures = <String>{};
    for (final key in keys) {
      for (final digest in digests) {
        signatures.add(_signDigestHex(digest: digest, privateKeyHex: key));
      }
    }
    return signatures.toList();
  }

  List<DlcUtxoProof> buildUtxoProofs({
    required String nonce,
    required String mnemonic,
    required List<GdkUnspentOutputs> utxos,
    required List<int> accountUserPath,
  }) {
    final proofs = <DlcUtxoProof>[];
    for (final utxo in utxos) {
      final txid = utxo.txhash;
      final vout = utxo.ptIdx;
      final userPath = utxo.userPath;
      if (txid == null || vout == null || userPath == null) {
        continue;
      }
      final path = userPathToBip32Path(userPath);
      final privateKeyHex = derivePrivateKeyHexAtPath(mnemonic, path);
      final digest = sha256.convert(
        utf8.encode('$txid$vout$nonce'),
      );
      final signature = _signDigestHex(
        digest: Uint8List.fromList(digest.bytes),
        privateKeyHex: privateKeyHex,
      );
      final publicKey = utxo.publicKey?.replaceFirst(RegExp('^0x'), '') ??
          hex.encode(
            _masterNode(mnemonic).derivePath(path).publicKey,
          );
      proofs.add(
        DlcUtxoProof(
          txid: txid,
          vout: vout,
          signature: signature,
          publicKey: publicKey,
        ),
      );
    }
    return proofs;
  }

  DlcSignatureBundle signDlcContext({
    required DlcSigningContext context,
    required String mnemonic,
    required List<int> accountUserPath,
    required List<GdkUnspentOutputs> walletUtxos,
  }) {
    final fundingPrivateKeyHex = derivePrivateKeyHexAtPath(
      mnemonic,
      fundingDerivationPath(accountUserPath),
    );

    final fundingPrivateKey = Uint8List.fromList(hex.decode(fundingPrivateKeyHex));
    final cetAdaptorSignaturesHex = _cetSigner.signJobs(
      jobs: context.cetSigningJobs,
      fundingPrivateKey32: fundingPrivateKey,
    );

    final refundSignatureHex = signSighashHex(
      sighashHex: context.refundSighashHex,
      privateKeyHex: fundingPrivateKeyHex,
    );

    final fundingSignaturesHex = <String>[];
    for (var i = 0; i < context.fundingInputSighashesHex.length; i++) {
      final sighash = context.fundingInputSighashesHex[i];
      final outpoint = i < context.fundingInputOutpoints.length
          ? context.fundingInputOutpoints[i]
          : null;
      final privateKeyHex = _resolveFundingInputPrivateKeyHex(
        mnemonic: mnemonic,
        walletUtxos: walletUtxos,
        outpoint: outpoint,
        fallbackPrivateKeyHex: fundingPrivateKeyHex,
      );
      fundingSignaturesHex.add(
        signSighashHex(sighashHex: sighash, privateKeyHex: privateKeyHex),
      );
    }

    return DlcSignatureBundle(
      cetAdaptorSignaturesHex: cetAdaptorSignaturesHex,
      refundSignatureHex: refundSignatureHex,
      fundingSignaturesHex: fundingSignaturesHex,
    );
  }

  String _resolveFundingInputPrivateKeyHex({
    required String mnemonic,
    required List<GdkUnspentOutputs> walletUtxos,
    required String? outpoint,
    required String fallbackPrivateKeyHex,
  }) {
    if (outpoint == null) {
      return fallbackPrivateKeyHex;
    }
    final parts = outpoint.split(':');
    if (parts.length != 2) {
      return fallbackPrivateKeyHex;
    }
    final txid = parts[0];
    final vout = int.tryParse(parts[1]);
    if (vout == null) {
      return fallbackPrivateKeyHex;
    }
    GdkUnspentOutputs? match;
    for (final utxo in walletUtxos) {
      if (utxo.txhash == txid && utxo.ptIdx == vout) {
        match = utxo;
        break;
      }
    }
    final userPath = match?.userPath;
    if (userPath == null) {
      return fallbackPrivateKeyHex;
    }
    return derivePrivateKeyHexAtPath(mnemonic, userPathToBip32Path(userPath));
  }

  String signSighashHex({
    required String sighashHex,
    required String privateKeyHex,
  }) {
    final digest = Uint8List.fromList(hex.decode(sighashHex));
    return _signDigestHex(digest: digest, privateKeyHex: privateKeyHex);
  }

  String _signDigestHex({
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
    final signature = signer.generateSignature(digest) as ECSignature;
    return _derEncode(signature);
  }

  String _derEncode(ECSignature signature) {
    final r = _encodeInt(signature.r);
    final s = _encodeInt(signature.s);
    final body = <int>[0x02, r.length, ...r, 0x02, s.length, ...s];
    final der = <int>[0x30, body.length, ...body, 0x01];
    return hex.encode(der);
  }

  List<int> _encodeInt(BigInt value) {
    var bytes = value.toRadixString(16);
    if (bytes.length % 2 != 0) {
      bytes = '0$bytes';
    }
    final out = hex.decode(bytes);
    if (out.isNotEmpty && out.first >= 0x80) {
      return <int>[0x00, ...out];
    }
    return out;
  }
}

String userPathToBip32Path(List<int> userPath) {
  final parts = userPath.map((index) {
    final unhardened = DerivationPathUtils.unhardenIndex(index);
    final isHardened = DerivationPathUtils.isHardened(index);
    return isHardened ? "$unhardened'" : '$unhardened';
  }).join('/');
  return 'm/$parts';
}
