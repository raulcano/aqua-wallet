import 'dart:convert';
import 'dart:typed_data';

import 'package:aqua/data/models/gdk_models.dart';
import 'package:aqua/features/dlc/crypto/coordinator_cet_signer.dart';
import 'package:aqua/features/dlc/crypto/coordinator_wallet_signature.dart';
import 'package:aqua/features/dlc/crypto/dlc_ecdsa_der.dart';
import 'package:aqua/features/dlc/crypto/dlc_funding_signature_wire.dart';
import 'package:aqua/features/dlc/crypto/ecdsa_adaptor_signature.dart';
import 'package:aqua/features/dlc/models/dlc_models.dart';
import 'package:aqua/features/dlc/services/dlc_funding_key_resolve.dart';
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

  String derivePublicKeyHexAtPath(String mnemonic, String path) =>
      hex.encode(_masterNode(mnemonic).derivePath(path).publicKey);

  /// Signs the coordinator nonce for wallet registration (`xpub_signature`).
  ///
  /// Uses the account-level private key that matches the submitted xpub and
  /// bitcoinlib-compatible message normalization over `nonce.encode('utf-8').hex()`.
  String signXpubNonceSignature({
    required String nonce,
    required String mnemonic,
    required List<int> accountUserPath,
  }) {
    final accountPath = accountDerivationPath(accountUserPath);
    final privateKeyHex = derivePrivateKeyHexAtPath(mnemonic, accountPath);
    return signCoordinatorNonceDerHex(
      nonce: nonce,
      accountPrivateKeyHex: privateKeyHex,
    );
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
    DlcFundingSignatureFormat fundingSignatureFormat =
        DlcFundingSignatureFormat.witnessWire,
  }) {
    final fundingPath = fundingDerivationPath(accountUserPath);
    final fundingPrivateKeyHex = derivePrivateKeyHexAtPath(mnemonic, fundingPath);

    final fundingPrivateKey = Uint8List.fromList(hex.decode(fundingPrivateKeyHex));
    final cetAdaptorSignaturesHex = _cetSigner.signJobs(
      jobs: context.cetSigningJobs,
      fundingPrivateKey32: fundingPrivateKey,
    );

    final refundSignatureHex = signSighashHex(
      sighashHex: context.refundSighashHex,
      privateKeyHex: fundingPrivateKeyHex,
    );

    final accountPath = accountDerivationPath(accountUserPath);
    final fundingMaterials = resolveFundingInputSigningMaterials(
      mnemonic: mnemonic,
      accountDerivationPath: accountPath,
      walletUtxos: walletUtxos,
      fundingInputSighashesHex: context.fundingInputSighashesHex,
      fundingInputAddresses: context.fundingInputAddresses,
      fundingInputOutpoints: context.fundingInputOutpoints,
      derivePrivateKeyHex: derivePrivateKeyHexAtPath,
      derivePublicKeyHex: derivePublicKeyHexAtPath,
    );

    final fundingSignaturesHex = <String>[];
    if (fundingSignatureFormat == DlcFundingSignatureFormat.witnessWire) {
      final witnessStacks = <Uint8List>[];
      for (var i = 0; i < fundingMaterials.length; i++) {
        witnessStacks.add(
          _signFundingInputWitnessStack(
            sighashHex: context.fundingInputSighashesHex[i],
            privateKeyHex: fundingMaterials[i].privateKeyHex,
            publicKeyHex: fundingMaterials[i].publicKeyHex,
          ),
        );
      }
      if (witnessStacks.isNotEmpty) {
        fundingSignaturesHex.add(
          hex.encode(encodeFundingSignaturesContainer(witnessStacks)),
        );
      }
    } else {
      for (var i = 0; i < fundingMaterials.length; i++) {
        fundingSignaturesHex.add(
          signSighashHex(
            sighashHex: context.fundingInputSighashesHex[i],
            privateKeyHex: fundingMaterials[i].privateKeyHex,
          ),
        );
      }
    }

    return DlcSignatureBundle(
      cetAdaptorSignaturesHex: cetAdaptorSignaturesHex,
      refundSignatureHex: refundSignatureHex,
      fundingSignaturesHex: fundingSignaturesHex,
    );
  }

  Uint8List _signFundingInputWitnessStack({
    required String sighashHex,
    required String privateKeyHex,
    required String publicKeyHex,
  }) {
    final digest = Uint8List.fromList(hex.decode(sighashHex));
    final compactSignature = Uint8List.fromList(
      hex.decode(_signDigestCompactHex(digest: digest, privateKeyHex: privateKeyHex)),
    );
    final derSignature = Uint8List.fromList(
      hex.decode(
        compactSecp256k1SignatureToDerHex(
          compactSignature,
          includeHashType: true,
        ),
      ),
    );
    final publicKey = Uint8List.fromList(
      hex.decode(_normalizeCompressedPubkeyHex(publicKeyHex)),
    );
    return encodeP2wpkhWitnessStack(
      derSignatureWithSighash: derSignature,
      compressedPublicKey: publicKey,
    );
  }

  String _normalizeCompressedPubkeyHex(String publicKeyHex) {
    final normalized = publicKeyHex.toLowerCase().replaceFirst(RegExp('^0x'), '');
    if (normalized.length != 66) {
      throw StateError('Expected compressed public key (66 hex chars)');
    }
    return normalized;
  }

  String signSighashHex({
    required String sighashHex,
    required String privateKeyHex,
  }) {
    final digest = Uint8List.fromList(hex.decode(sighashHex));
    return _signDigestCompactHex(digest: digest, privateKeyHex: privateKeyHex);
  }

  String signSighashDerHex({
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
    final signature = _signDigest(digest: digest, privateKeyHex: privateKeyHex);
    return _derEncode(signature);
  }

  /// DLC coordinator messages expect compact `r ‖ s` (64 bytes / 128 hex).
  String _signDigestCompactHex({
    required Uint8List digest,
    required String privateKeyHex,
  }) {
    final signature = _signDigest(digest: digest, privateKeyHex: privateKeyHex);
    return hex.encode(
      EcdsaSignature(r: signature.r, s: signature.s).serialize(),
    );
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
