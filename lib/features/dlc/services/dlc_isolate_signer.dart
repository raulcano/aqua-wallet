import 'package:aqua/data/models/gdk_models.dart';
import 'package:aqua/features/dlc/models/dlc_models.dart';
import 'package:aqua/features/dlc/services/dlc_local_signer.dart';
import 'package:flutter/foundation.dart';

/// Runs DLC adaptor/ECDSA signing off the UI isolate.
Future<DlcSignatureBundle> signDlcContextInIsolate({
  required DlcSigningContext context,
  required String mnemonic,
  required List<int> accountUserPath,
  required List<GdkUnspentOutputs> walletUtxos,
  DlcFundingSignatureFormat fundingSignatureFormat =
      DlcFundingSignatureFormat.witnessWire,
}) {
  return compute(
    _signDlcContextEntry,
    _DlcSigningIsolateRequest(
      context: _DlcSigningContextWire.fromContext(context),
      mnemonic: mnemonic,
      accountUserPath: List<int>.from(accountUserPath),
      utxos: walletUtxos.map(_DlcSigningUtxoWire.fromGdk).toList(growable: false),
      fundingSignatureFormat: fundingSignatureFormat,
    ),
  );
}

DlcSignatureBundle _signDlcContextEntry(_DlcSigningIsolateRequest request) {
  const signer = DlcLocalSigner();
  return signer.signDlcContext(
    context: request.context.toContext(),
    mnemonic: request.mnemonic,
    accountUserPath: request.accountUserPath,
    walletUtxos: request.utxos.map((utxo) => utxo.toGdk()).toList(growable: false),
    fundingSignatureFormat: request.fundingSignatureFormat,
  );
}

class _DlcSigningIsolateRequest {
  const _DlcSigningIsolateRequest({
    required this.context,
    required this.mnemonic,
    required this.accountUserPath,
    required this.utxos,
    required this.fundingSignatureFormat,
  });

  final _DlcSigningContextWire context;
  final String mnemonic;
  final List<int> accountUserPath;
  final List<_DlcSigningUtxoWire> utxos;
  final DlcFundingSignatureFormat fundingSignatureFormat;
}

class _DlcSigningContextWire {
  const _DlcSigningContextWire({
    required this.contextFingerprint,
    required this.cetSigningJobs,
    required this.refundSighashHex,
    required this.fundingInputSighashesHex,
    required this.fundingInputOutpoints,
    required this.fundingInputAddresses,
    this.offerObjectHex,
    this.acceptObjectHex,
  });

  final String contextFingerprint;
  final List<Map<String, String>> cetSigningJobs;
  final String refundSighashHex;
  final List<String> fundingInputSighashesHex;
  final List<String> fundingInputOutpoints;
  final List<String> fundingInputAddresses;
  final String? offerObjectHex;
  final String? acceptObjectHex;

  factory _DlcSigningContextWire.fromContext(DlcSigningContext context) {
    return _DlcSigningContextWire(
      contextFingerprint: context.contextFingerprint,
      cetSigningJobs: context.cetSigningJobs
          .map(
            (job) => {
              'messageHashHex': job.messageHashHex,
              'adaptorPointHex': job.adaptorPointHex,
            },
          )
          .toList(growable: false),
      refundSighashHex: context.refundSighashHex,
      fundingInputSighashesHex:
          List<String>.from(context.fundingInputSighashesHex),
      fundingInputOutpoints: List<String>.from(context.fundingInputOutpoints),
      fundingInputAddresses: List<String>.from(context.fundingInputAddresses),
      offerObjectHex: context.offerObjectHex,
      acceptObjectHex: context.acceptObjectHex,
    );
  }

  DlcSigningContext toContext() => DlcSigningContext(
        contextFingerprint: contextFingerprint,
        cetSigningJobs: cetSigningJobs
            .map(
              (job) => DlcCetSigningJob(
                messageHashHex: job['messageHashHex'] ?? '',
                adaptorPointHex: job['adaptorPointHex'] ?? '',
              ),
            )
            .toList(growable: false),
        refundSighashHex: refundSighashHex,
        fundingInputSighashesHex: fundingInputSighashesHex,
        fundingInputOutpoints: fundingInputOutpoints,
        fundingInputAddresses: fundingInputAddresses,
        offerObjectHex: offerObjectHex,
        acceptObjectHex: acceptObjectHex,
      );
}

class _DlcSigningUtxoWire {
  const _DlcSigningUtxoWire({
    this.txhash,
    this.ptIdx,
    this.userPath,
    this.publicKey,
  });

  final String? txhash;
  final int? ptIdx;
  final List<int>? userPath;
  final String? publicKey;

  factory _DlcSigningUtxoWire.fromGdk(GdkUnspentOutputs utxo) {
    return _DlcSigningUtxoWire(
      txhash: utxo.txhash,
      ptIdx: utxo.ptIdx,
      userPath: utxo.userPath == null ? null : List<int>.from(utxo.userPath!),
      publicKey: utxo.publicKey,
    );
  }

  GdkUnspentOutputs toGdk() => GdkUnspentOutputs(
        txhash: txhash,
        ptIdx: ptIdx,
        userPath: userPath,
        publicKey: publicKey,
      );
}

/// Builds coordinator UTXO ownership proofs off the UI isolate.
Future<List<DlcUtxoProof>> buildUtxoProofsInIsolate({
  required String nonce,
  required String mnemonic,
  required List<int> accountUserPath,
  required List<GdkUnspentOutputs> utxos,
}) {
  return compute(
    _buildUtxoProofsEntry,
    _UtxoProofIsolateRequest(
      nonce: nonce,
      mnemonic: mnemonic,
      accountUserPath: List<int>.from(accountUserPath),
      utxos: utxos.map(_DlcSigningUtxoWire.fromGdk).toList(growable: false),
    ),
  );
}

List<DlcUtxoProof> _buildUtxoProofsEntry(_UtxoProofIsolateRequest request) {
  const signer = DlcLocalSigner();
  return signer.buildUtxoProofs(
    nonce: request.nonce,
    mnemonic: request.mnemonic,
    accountUserPath: request.accountUserPath,
    utxos: request.utxos.map((utxo) => utxo.toGdk()).toList(growable: false),
  );
}

class _UtxoProofIsolateRequest {
  const _UtxoProofIsolateRequest({
    required this.nonce,
    required this.mnemonic,
    required this.accountUserPath,
    required this.utxos,
  });

  final String nonce;
  final String mnemonic;
  final List<int> accountUserPath;
  final List<_DlcSigningUtxoWire> utxos;
}

/// Derives xpub registration signature candidates off the UI isolate.
Future<List<String>> signNonceProofCandidatesInIsolate({
  required String nonce,
  required String mnemonic,
  required List<int> accountUserPath,
}) {
  return compute(
    _signNonceProofCandidatesEntry,
    _NonceProofIsolateRequest(
      nonce: nonce,
      mnemonic: mnemonic,
      accountUserPath: List<int>.from(accountUserPath),
    ),
  );
}

List<String> _signNonceProofCandidatesEntry(_NonceProofIsolateRequest request) {
  const signer = DlcLocalSigner();
  return signer.signNonceProofCandidates(
    nonce: request.nonce,
    mnemonic: request.mnemonic,
    accountUserPath: request.accountUserPath,
  );
}

class _NonceProofIsolateRequest {
  const _NonceProofIsolateRequest({
    required this.nonce,
    required this.mnemonic,
    required this.accountUserPath,
  });

  final String nonce;
  final String mnemonic;
  final List<int> accountUserPath;
}
