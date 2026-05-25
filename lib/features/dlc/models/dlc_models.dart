class DlcInstrument {
  const DlcInstrument({
    required this.instrumentId,
    this.numericId,
    this.expiresAt,
  });

  final String instrumentId;
  final int? numericId;
  final DateTime? expiresAt;

  factory DlcInstrument.fromJson(Map<String, dynamic> json) => DlcInstrument(
        instrumentId: json['instrument_id'] as String? ?? '',
        numericId: json['id'] as int?,
        expiresAt: json['expires_at'] != null
            ? DateTime.tryParse(json['expires_at'] as String)
            : null,
      );
}

class DlcWalletAuth {
  const DlcWalletAuth({
    required this.walletOriginId,
    required this.walletLabel,
    required this.walletXpub,
    required this.walletId,
    required this.walletToken,
    required this.expiresAt,
  });

  final String walletOriginId;
  final String walletLabel;
  final String walletXpub;
  final String walletId;
  final String walletToken;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'wallet_origin_id': walletOriginId,
        'wallet_label': walletLabel,
        'wallet_xpub': walletXpub,
        'wallet_id': walletId,
        'wallet_token': walletToken,
        'expires_at': expiresAt.toIso8601String(),
      };

  factory DlcWalletAuth.fromJson(Map<String, dynamic> json) => DlcWalletAuth(
        walletOriginId: json['wallet_origin_id'] as String? ?? '',
        walletLabel: json['wallet_label'] as String? ?? '',
        walletXpub: json['wallet_xpub'] as String? ?? '',
        walletId: json['wallet_id'] as String? ?? '',
        walletToken: json['wallet_token'] as String? ?? '',
        expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class DlcUtxoProof {
  const DlcUtxoProof({
    required this.txid,
    required this.vout,
    required this.signature,
    required this.publicKey,
  });

  final String txid;
  final int vout;
  final String signature;
  final String publicKey;

  Map<String, dynamic> toJson() => {
        'txid': txid,
        'vout': vout,
        'signature': signature,
        'public_key': publicKey,
      };
}

class DlcWalletRegistration {
  const DlcWalletRegistration({
    required this.walletId,
    required this.walletToken,
    required this.expiresAt,
  });

  final String walletId;
  final String walletToken;
  final DateTime expiresAt;

  factory DlcWalletRegistration.fromJson(Map<String, dynamic> json) =>
      DlcWalletRegistration(
        walletId: json['wallet_id'] as String? ?? '',
        walletToken: json['wallet_token'] as String? ?? '',
        expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class DlcWalletSyncResult {
  const DlcWalletSyncResult({
    required this.totalBalanceSat,
    required this.availableBalanceSat,
    required this.reservedBalanceSat,
    this.warning,
    this.utxoSyncError,
    this.cancelledOrders = const [],
  });

  final int totalBalanceSat;
  final int availableBalanceSat;
  final int reservedBalanceSat;
  final String? warning;
  final String? utxoSyncError;
  final List<String> cancelledOrders;

  factory DlcWalletSyncResult.fromJson(Map<String, dynamic> json) =>
      DlcWalletSyncResult(
        totalBalanceSat: json['total_balance'] as int? ?? 0,
        availableBalanceSat: json['available_balance'] as int? ?? 0,
        reservedBalanceSat: json['reserved_balance'] as int? ?? 0,
        warning: json['warning'] as String?,
        utxoSyncError: json['utxo_sync_error'] as String?,
        cancelledOrders: (json['cancelled_orders'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}

class DlcPartnerConfig {
  const DlcPartnerConfig({
    required this.id,
    required this.tokenValid,
    this.tokenExpiresAt,
    this.relativeFeeMaker,
    this.relativeFeeTaker,
    this.premiumPaidUpfront = false,
  });

  final String id;
  final bool tokenValid;
  final DateTime? tokenExpiresAt;
  final double? relativeFeeMaker;
  final double? relativeFeeTaker;
  final bool premiumPaidUpfront;

  factory DlcPartnerConfig.fromJson(Map<String, dynamic> json) =>
      DlcPartnerConfig(
        id: json['id'] as String? ?? '',
        tokenValid: json['token_valid'] as bool? ?? false,
        tokenExpiresAt: json['token_expires_at'] != null
            ? DateTime.tryParse(json['token_expires_at'] as String)
            : null,
        relativeFeeMaker:
            (json['relative_fee_maker'] as num?)?.toDouble(),
        relativeFeeTaker:
            (json['relative_fee_taker'] as num?)?.toDouble(),
        premiumPaidUpfront: json['premium_paid_upfront'] as bool? ?? false,
      );
}

class DlcSystemReadiness {
  const DlcSystemReadiness({
    required this.network,
    required this.tradingReady,
    required this.blockers,
    this.chainBackendOk = true,
    this.chainBackendError,
  });

  final String network;
  final bool tradingReady;
  final List<String> blockers;
  final bool chainBackendOk;
  final String? chainBackendError;

  factory DlcSystemReadiness.fromJson(Map<String, dynamic> json) {
    final chainBackend =
        json['chain_backend'] as Map<String, dynamic>? ?? const {};
    final blockers = (json['blockers'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    return DlcSystemReadiness(
      network: json['network'] as String? ?? '',
      tradingReady: json['trading_ready'] as bool? ?? false,
      blockers: blockers,
      chainBackendOk: chainBackend['ok'] as bool? ?? true,
      chainBackendError: chainBackend['error'] as String?,
    );
  }
}

class DlcOrder {
  const DlcOrder({
    required this.orderId,
    required this.instrumentId,
    required this.side,
    required this.status,
    required this.quantity,
    this.price,
    this.dlcId,
    this.signRequired = false,
    this.isMaker = false,
    this.pendingMatchAccept = false,
    this.dlcStatus,
    this.fundingTxid,
    this.cancellationReason,
    this.idempotencyKey,
    this.matchRole,
    this.settlementType,
    this.oracleOutcomeValue,
    this.closingTxid,
    this.refundTxid,
  });

  final String orderId;
  final String instrumentId;
  final String side;
  final String status;
  final num quantity;
  final num? price;
  final String? dlcId;
  final bool signRequired;
  final bool isMaker;
  final bool pendingMatchAccept;
  final String? dlcStatus;
  final String? fundingTxid;
  final String? cancellationReason;
  final String? idempotencyKey;
  final String? matchRole;
  final String? settlementType;
  final String? oracleOutcomeValue;
  final String? closingTxid;
  final String? refundTxid;

  static const terminalDlcStatuses = {
    'cet_broadcasted',
    'refund_broadcasted',
    'cet_closed',
    'refund_closed',
    'terminated',
  };

  bool get isOpen => status == 'open';
  bool get needsTakerAccept =>
      status == 'pending_accept' || pendingMatchAccept;
  bool get needsMakerSign {
    if (!isMaker || dlcId == null || dlcId!.isEmpty) {
      return false;
    }
    // After the taker accepts, the maker must sign even if sign_required is
    // missing from a stale list-orders payload.
    if (dlcStatus == 'accepted') {
      return true;
    }
    return signRequired &&
        (dlcStatus == null || dlcStatus == 'offer_created');
  }

  bool get isLiveDlc =>
      dlcStatus != null && !terminalDlcStatuses.contains(dlcStatus);

  DlcOrder mergeSettlement(Map<String, dynamic> json) => DlcOrder(
        orderId: orderId,
        instrumentId: instrumentId,
        side: side,
        status: status,
        quantity: quantity,
        price: price,
        dlcId: dlcId,
        signRequired: signRequired,
        isMaker: isMaker,
        pendingMatchAccept: pendingMatchAccept,
        dlcStatus: json['status'] as String? ?? dlcStatus,
        fundingTxid: json['funding_txid'] as String? ?? fundingTxid,
        cancellationReason: cancellationReason,
        idempotencyKey: idempotencyKey,
        matchRole: matchRole,
        settlementType:
            json['settlement_type'] as String? ?? settlementType,
        oracleOutcomeValue: json['oracle_outcome_value']?.toString() ??
            oracleOutcomeValue,
        closingTxid: json['closing_txid'] as String? ?? closingTxid,
        refundTxid: json['refund_txid'] as String? ?? refundTxid,
      );

  factory DlcOrder.fromJson(Map<String, dynamic> json) => DlcOrder(
        orderId: json['order_id'] as String? ?? '',
        instrumentId: json['instrument_id'] as String? ?? '',
        side: json['side'] as String? ?? '',
        status: json['status'] as String? ?? '',
        quantity: json['quantity'] as num? ?? 0,
        price: json['price'] as num?,
        dlcId: json['dlc_id'] as String?,
        signRequired: json['sign_required'] as bool? ?? false,
        isMaker: json['is_maker'] as bool? ?? false,
        pendingMatchAccept: json['pending_match_accept'] as bool? ?? false,
        dlcStatus: json['dlc_status'] as String?,
        fundingTxid: json['funding_txid'] as String?,
        cancellationReason: json['cancellation_reason'] as String?,
        idempotencyKey: json['idempotency_key'] as String?,
        matchRole: json['match_role'] as String?,
        settlementType: json['settlement_type'] as String?,
        oracleOutcomeValue: json['oracle_outcome_value']?.toString(),
        closingTxid: json['closing_txid'] as String?,
        refundTxid: json['refund_txid'] as String?,
      );
}

class DlcOrderResponse {
  const DlcOrderResponse({
    required this.orderId,
    required this.dlcId,
    required this.status,
    required this.pendingMatchAccept,
    required this.signRequired,
  });

  final String orderId;
  final String dlcId;
  final String status;
  final bool pendingMatchAccept;
  final bool signRequired;

  factory DlcOrderResponse.fromJson(Map<String, dynamic> json) =>
      DlcOrderResponse(
        orderId: json['order_id'] as String? ?? '',
        dlcId: json['dlc_id'] as String? ?? '',
        status: json['status'] as String? ?? '',
        pendingMatchAccept: json['pending_match_accept'] as bool? ?? false,
        signRequired: json['sign_required'] as bool? ?? false,
      );
}

class DlcCetSigningJob {
  const DlcCetSigningJob({
    required this.messageHashHex,
    required this.adaptorPointHex,
  });

  final String messageHashHex;
  final String adaptorPointHex;

  factory DlcCetSigningJob.fromJson(Map<String, dynamic> json) =>
      DlcCetSigningJob(
        messageHashHex: json['message_hash_hex'] as String? ?? '',
        adaptorPointHex: json['adaptor_point_hex'] as String? ?? '',
      );
}

class DlcSigningContext {
  const DlcSigningContext({
    required this.contextFingerprint,
    required this.cetSigningJobs,
    required this.refundSighashHex,
    required this.fundingInputSighashesHex,
    required this.fundingInputOutpoints,
    this.fundingInputAddresses = const [],
    this.offerObjectHex,
    this.acceptObjectHex,
  });

  final String contextFingerprint;
  final List<DlcCetSigningJob> cetSigningJobs;
  final String refundSighashHex;
  final List<String> fundingInputSighashesHex;
  final List<String> fundingInputOutpoints;
  final List<String> fundingInputAddresses;
  final String? offerObjectHex;
  final String? acceptObjectHex;

  String get signContextFingerprint =>
      contextFingerprint.isNotEmpty
          ? contextFingerprint
          : '${offerObjectHex ?? ''}:${acceptObjectHex ?? ''}';

  factory DlcSigningContext.fromJson(Map<String, dynamic> json) =>
      DlcSigningContext(
        contextFingerprint: json['context_fingerprint'] as String? ?? '',
        cetSigningJobs: (json['cet_signing_jobs'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(DlcCetSigningJob.fromJson)
            .toList(),
        refundSighashHex: json['refund_sighash_hex'] as String? ?? '',
        fundingInputSighashesHex:
            (json['funding_input_sighashes_hex'] as List<dynamic>? ?? [])
                .map((item) => item.toString())
                .toList(),
        fundingInputOutpoints:
            (json['funding_input_outpoints'] as List<dynamic>? ?? [])
                .map((item) => item.toString())
                .toList(),
        fundingInputAddresses:
            (json['funding_input_addresses'] as List<dynamic>? ?? [])
                .map((item) => item.toString())
                .toList(),
        offerObjectHex: json['offer_object_hex'] as String?,
        acceptObjectHex: json['accept_object_hex'] as String?,
      );
}

class DlcFundingPubkey {
  const DlcFundingPubkey({
    required this.pubkeyHex,
    required this.derivationPath,
  });

  final String pubkeyHex;
  final String derivationPath;
}

/// How per-input funding signatures are encoded for the coordinator API.
enum DlcFundingSignatureFormat {
  /// Legacy per-input compact `r ‖ s` (128 hex chars).
  compact,

  /// Coordinator-compatible: one hex entry — DLC `FundingSignatures` container.
  witnessWire,
}

class DlcSignatureBundle {
  const DlcSignatureBundle({
    required this.cetAdaptorSignaturesHex,
    required this.refundSignatureHex,
    required this.fundingSignaturesHex,
  });

  final List<String> cetAdaptorSignaturesHex;
  final String refundSignatureHex;
  final List<String> fundingSignaturesHex;
}
