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

/// Role of a wallet inside a specific execution.
enum DlcExecutionRole {
  maker,
  taker,
  unknown,
}

DlcExecutionRole _executionRoleFromString(String? value) {
  switch (value) {
    case 'maker':
      return DlcExecutionRole.maker;
    case 'taker':
      return DlcExecutionRole.taker;
    default:
      return DlcExecutionRole.unknown;
  }
}

String _executionRoleToString(DlcExecutionRole role) {
  switch (role) {
    case DlcExecutionRole.maker:
      return 'maker';
    case DlcExecutionRole.taker:
      return 'taker';
    case DlcExecutionRole.unknown:
      return 'unknown';
  }
}

/// One match attempt produced by the coordinator.
///
/// A single order may eventually own multiple executions (e.g. when the first
/// attempt fails or expires and a later match succeeds). The coordinator
/// guarantees a single canonical [dlcId] per execution shared by both
/// counterparties.
class DlcOrderExecution {
  const DlcOrderExecution({
    required this.tradeId,
    required this.dlcId,
    required this.role,
    required this.status,
    this.counterpartyOrderId,
    this.makerOrderId,
    this.takerOrderId,
    this.quantity,
    this.price,
    this.dlcStatus,
    this.fundingTxid,
    this.closingTxid,
    this.refundTxid,
    this.settlementType,
    this.oracleOutcomeValue,
    this.lastErrorReason,
    this.lastErrorMessage,
    this.reservedAt,
    this.executedAt,
  });

  static const statusPendingAccept = 'pending_accept';
  static const statusExecuted = 'executed';
  static const statusFailed = 'failed';
  static const statusExpired = 'expired';

  static const terminalStatuses = {
    statusFailed,
    statusExpired,
  };

  final String tradeId;
  final String dlcId;
  final DlcExecutionRole role;
  final String status;
  final String? counterpartyOrderId;
  final String? makerOrderId;
  final String? takerOrderId;
  final num? quantity;
  final num? price;
  final String? dlcStatus;
  final String? fundingTxid;
  final String? closingTxid;
  final String? refundTxid;
  final String? settlementType;
  final String? oracleOutcomeValue;
  final String? lastErrorReason;
  final String? lastErrorMessage;
  final DateTime? reservedAt;
  final DateTime? executedAt;

  bool get isPendingAccept => status == statusPendingAccept;
  bool get isExecuted => status == statusExecuted;
  bool get isFailed => status == statusFailed;
  bool get isExpired => status == statusExpired;
  bool get isTerminal => terminalStatuses.contains(status);

  factory DlcOrderExecution.fromJson(Map<String, dynamic> json) =>
      DlcOrderExecution(
        tradeId: json['trade_id'] as String? ?? '',
        dlcId: json['dlc_id'] as String? ?? '',
        role: _executionRoleFromString(json['role'] as String?),
        status: json['status'] as String? ?? '',
        counterpartyOrderId: json['counterparty_order_id'] as String?,
        makerOrderId: json['maker_order_id'] as String?,
        takerOrderId: json['taker_order_id'] as String?,
        quantity: json['quantity'] as num?,
        price: json['price'] as num?,
        dlcStatus: json['dlc_status'] as String?,
        fundingTxid: DlcOrder.fundingTxidFromDetailJson(json),
        closingTxid: json['closing_txid'] as String?,
        refundTxid: json['refund_txid'] as String?,
        settlementType: json['settlement_type'] as String?,
        oracleOutcomeValue: json['oracle_outcome_value']?.toString(),
        lastErrorReason: json['last_error_reason'] as String?,
        lastErrorMessage: json['last_error_message'] as String?,
        reservedAt: json['reserved_at'] != null
            ? DateTime.tryParse(json['reserved_at'] as String)
            : null,
        executedAt: json['executed_at'] != null
            ? DateTime.tryParse(json['executed_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'trade_id': tradeId,
        'dlc_id': dlcId,
        'role': _executionRoleToString(role),
        'status': status,
        if (counterpartyOrderId != null)
          'counterparty_order_id': counterpartyOrderId,
        if (makerOrderId != null) 'maker_order_id': makerOrderId,
        if (takerOrderId != null) 'taker_order_id': takerOrderId,
        if (quantity != null) 'quantity': quantity,
        if (price != null) 'price': price,
        if (dlcStatus != null) 'dlc_status': dlcStatus,
        if (fundingTxid != null) 'funding_txid': fundingTxid,
        if (closingTxid != null) 'closing_txid': closingTxid,
        if (refundTxid != null) 'refund_txid': refundTxid,
        if (settlementType != null) 'settlement_type': settlementType,
        if (oracleOutcomeValue != null)
          'oracle_outcome_value': oracleOutcomeValue,
        if (lastErrorReason != null) 'last_error_reason': lastErrorReason,
        if (lastErrorMessage != null) 'last_error_message': lastErrorMessage,
        if (reservedAt != null) 'reserved_at': reservedAt!.toIso8601String(),
        if (executedAt != null) 'executed_at': executedAt!.toIso8601String(),
      };

  DlcOrderExecution mergeDlcDetail(Map<String, dynamic> json) =>
      DlcOrderExecution(
        tradeId: tradeId,
        dlcId: dlcId,
        role: role,
        status: status,
        counterpartyOrderId: counterpartyOrderId,
        makerOrderId: json['maker_order_id'] as String? ?? makerOrderId,
        takerOrderId: json['taker_order_id'] as String? ?? takerOrderId,
        quantity: quantity,
        price: price,
        dlcStatus: json['status'] as String? ??
            json['dlc_status'] as String? ??
            dlcStatus,
        fundingTxid:
            DlcOrder.fundingTxidFromDetailJson(json) ?? fundingTxid,
        closingTxid: json['closing_txid'] as String? ?? closingTxid,
        refundTxid: json['refund_txid'] as String? ?? refundTxid,
        settlementType: json['settlement_type'] as String? ?? settlementType,
        oracleOutcomeValue:
            json['oracle_outcome_value']?.toString() ?? oracleOutcomeValue,
        lastErrorReason: json['last_error_reason'] as String? ?? lastErrorReason,
        lastErrorMessage:
            json['last_error_message'] as String? ?? lastErrorMessage,
        reservedAt: reservedAt,
        executedAt: executedAt,
      );
}

/// Canonical DLC record shared by both wallets in a trade.
class DlcCanonicalDlc {
  const DlcCanonicalDlc({
    required this.dlcId,
    required this.tradeId,
    required this.makerOrderId,
    required this.takerOrderId,
    required this.status,
    this.fundingTxid,
    this.closingTxid,
    this.refundTxid,
    this.settlementType,
    this.oracleOutcomeValue,
    this.lastErrorReason,
    this.lastErrorMessage,
  });

  final String dlcId;
  final String tradeId;
  final String makerOrderId;
  final String takerOrderId;
  final String status;
  final String? fundingTxid;
  final String? closingTxid;
  final String? refundTxid;
  final String? settlementType;
  final String? oracleOutcomeValue;
  final String? lastErrorReason;
  final String? lastErrorMessage;

  factory DlcCanonicalDlc.fromJson(Map<String, dynamic> json) =>
      DlcCanonicalDlc(
        dlcId: json['dlc_id'] as String? ?? '',
        tradeId: json['trade_id'] as String? ?? '',
        makerOrderId: json['maker_order_id'] as String? ?? '',
        takerOrderId: json['taker_order_id'] as String? ?? '',
        status: json['status'] as String? ?? '',
        fundingTxid: DlcOrder.fundingTxidFromDetailJson(json),
        closingTxid: json['closing_txid'] as String?,
        refundTxid: json['refund_txid'] as String?,
        settlementType: json['settlement_type'] as String?,
        oracleOutcomeValue: json['oracle_outcome_value']?.toString(),
        lastErrorReason: json['last_error_reason'] as String?,
        lastErrorMessage: json['last_error_message'] as String?,
      );

  /// Determines the wallet's role by comparing its order id to the canonical
  /// maker/taker order ids.
  DlcExecutionRole roleForOrderId(String orderId) {
    if (orderId.isEmpty) return DlcExecutionRole.unknown;
    if (orderId == makerOrderId) return DlcExecutionRole.maker;
    if (orderId == takerOrderId) return DlcExecutionRole.taker;
    return DlcExecutionRole.unknown;
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
    this.filledQuantity = 0,
    this.remainingQuantity,
    this.draftOfferObjectHex,
    this.executions = const <DlcOrderExecution>[],
    this.cancellationReason,
    this.idempotencyKey,
    this.lastErrorReason,
    this.lastErrorMessage,
    this.dlcId,
    this.dlcStatus,
    this.fundingTxid,
    this.closingTxid,
    this.refundTxid,
    this.settlementType,
    this.oracleOutcomeValue,
  });

  static const dlcStatusSigned = 'signed';
  static const dlcStatusFundingBroadcasted = 'funding_broadcasted';

  static const terminalDlcStatuses = {
    'cet_broadcasted',
    'refund_broadcasted',
    'cet_closed',
    'refund_closed',
    'terminated',
  };

  final String orderId;
  final String instrumentId;
  final String side;
  final String status;
  final num quantity;
  final num? price;
  final num filledQuantity;
  final num? remainingQuantity;
  final String? draftOfferObjectHex;
  final List<DlcOrderExecution> executions;
  final String? cancellationReason;
  final String? idempotencyKey;
  final String? lastErrorReason;
  final String? lastErrorMessage;

  // Top-level DLC live state from the order payload. Per migration spec these
  // mirror the canonical DLC state of the latest execution and are populated
  // by the coordinator at the top level of order responses; older execution
  // entries in `executions[]` are historical records and do not contain a
  // `dlc_status` field of their own.
  final String? dlcId;
  final String? dlcStatus;
  final String? fundingTxid;
  final String? closingTxid;
  final String? refundTxid;
  final String? settlementType;
  final String? oracleOutcomeValue;

  /// Most recent execution. The coordinator may keep failed/expired executions
  /// in `executions[]`, so the last entry represents the current execution.
  DlcOrderExecution? get latestExecution =>
      executions.isEmpty ? null : executions.last;

  /// Per migration spec: "Use the last execution for current display."
  DlcOrderExecution? get currentExecution => latestExecution;

  /// Latest execution's role for this wallet.
  DlcExecutionRole get walletRole =>
      currentExecution?.role ?? DlcExecutionRole.unknown;

  bool get isMaker => walletRole == DlcExecutionRole.maker;
  bool get isTaker => walletRole == DlcExecutionRole.taker;

  /// True for resting orders waiting for a match.
  bool get isOpen => status == 'open';

  /// True when the taker wallet must run the accept workflow.
  ///
  /// Pre-conditions per spec:
  ///   order.status = pending_accept
  ///   latest execution: role = taker, status = pending_accept
  bool get needsTakerAccept {
    if (status != 'pending_accept') return false;
    final execution = currentExecution;
    if (execution == null) return false;
    return execution.role == DlcExecutionRole.taker &&
        execution.status == DlcOrderExecution.statusPendingAccept;
  }

  /// True when the maker wallet must call `POST /dlcs/{canonical_dlc_id}/sign`.
  ///
  /// Pre-conditions per migration spec:
  ///   order.status     = filled        (taker accepted)
  ///   execution.status = executed      (trade was accepted)
  ///   dlc_status       = accepted      (canonical DLC waiting on maker sign)
  ///   role             = maker
  ///
  /// `dlc_status` is read from the order's top-level field; executions in
  /// `executions[]` do not carry their own `dlc_status` in coordinator
  /// responses.
  bool get needsMakerSign {
    if (walletRole != DlcExecutionRole.maker) return false;
    final id = dlcId;
    if (id == null || id.isEmpty) return false;
    if (dlcStatus != 'accepted') return false;
    // Defensive: only run when the trade has actually been accepted.
    final execution = currentExecution;
    if (execution == null) return false;
    if (execution.isTerminal) return false;
    return status == 'filled' || status == 'pending_accept';
  }

  bool get isFundingPending => dlcStatus == dlcStatusSigned;

  bool get isFundingBroadcasted => dlcStatus == dlcStatusFundingBroadcasted;

  bool get hasFundingCompleted =>
      isFundingBroadcasted ||
      ((fundingTxid?.isNotEmpty ?? false) && !isFundingPending);

  bool get isLiveDlc =>
      dlcStatus != null && !terminalDlcStatuses.contains(dlcStatus);

  bool get isSettlementEligible => isLiveDlc && hasFundingCompleted;

  /// Reads a funding txid from DLC detail or funding-transaction payloads.
  static String? fundingTxidFromDetailJson(Map<String, dynamic> json) {
    final fundingTxid = json['funding_txid'];
    if (fundingTxid is String && fundingTxid.isNotEmpty) {
      return fundingTxid;
    }
    final txid = json['txid'];
    if (txid is String && txid.isNotEmpty) {
      return txid;
    }
    return null;
  }

  /// Apply `GET /dlcs/{id}` or `GET /dlcs/{id}/funding-transaction` JSON to the
  /// order's top-level DLC state.
  DlcOrder mergeDlcDetail(Map<String, dynamic> json) => copyWith(
        dlcId: (json['dlc_id'] as String?) ?? dlcId,
        dlcStatus: (json['status'] as String?) ??
            (json['dlc_status'] as String?) ??
            dlcStatus,
        fundingTxid: fundingTxidFromDetailJson(json) ?? fundingTxid,
        lastErrorReason: (json['last_error_reason'] as String?) ?? lastErrorReason,
        lastErrorMessage:
            (json['last_error_message'] as String?) ?? lastErrorMessage,
      );

  /// Apply `GET /dlcs/{id}/settlement-status` JSON to the order's top-level
  /// settlement state.
  DlcOrder mergeSettlement(Map<String, dynamic> json) => copyWith(
        dlcStatus: (json['status'] as String?) ?? dlcStatus,
        fundingTxid: fundingTxidFromDetailJson(json) ?? fundingTxid,
        closingTxid: (json['closing_txid'] as String?) ?? closingTxid,
        refundTxid: (json['refund_txid'] as String?) ?? refundTxid,
        settlementType: (json['settlement_type'] as String?) ?? settlementType,
        oracleOutcomeValue:
            json['oracle_outcome_value']?.toString() ?? oracleOutcomeValue,
        lastErrorReason: (json['last_error_reason'] as String?) ?? lastErrorReason,
        lastErrorMessage:
            (json['last_error_message'] as String?) ?? lastErrorMessage,
      );

  DlcOrder copyWith({
    String? status,
    num? filledQuantity,
    num? remainingQuantity,
    String? draftOfferObjectHex,
    List<DlcOrderExecution>? executions,
    String? cancellationReason,
    String? idempotencyKey,
    String? lastErrorReason,
    String? lastErrorMessage,
    String? dlcId,
    String? dlcStatus,
    String? fundingTxid,
    String? closingTxid,
    String? refundTxid,
    String? settlementType,
    String? oracleOutcomeValue,
  }) =>
      DlcOrder(
        orderId: orderId,
        instrumentId: instrumentId,
        side: side,
        status: status ?? this.status,
        quantity: quantity,
        price: price,
        filledQuantity: filledQuantity ?? this.filledQuantity,
        remainingQuantity: remainingQuantity ?? this.remainingQuantity,
        draftOfferObjectHex: draftOfferObjectHex ?? this.draftOfferObjectHex,
        executions: executions ?? this.executions,
        cancellationReason: cancellationReason ?? this.cancellationReason,
        idempotencyKey: idempotencyKey ?? this.idempotencyKey,
        lastErrorReason: lastErrorReason ?? this.lastErrorReason,
        lastErrorMessage: lastErrorMessage ?? this.lastErrorMessage,
        dlcId: dlcId ?? this.dlcId,
        dlcStatus: dlcStatus ?? this.dlcStatus,
        fundingTxid: fundingTxid ?? this.fundingTxid,
        closingTxid: closingTxid ?? this.closingTxid,
        refundTxid: refundTxid ?? this.refundTxid,
        settlementType: settlementType ?? this.settlementType,
        oracleOutcomeValue: oracleOutcomeValue ?? this.oracleOutcomeValue,
      );

  factory DlcOrder.fromJson(Map<String, dynamic> json) {
    final executions = (json['executions'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(DlcOrderExecution.fromJson)
        .toList(growable: false);
    final latest = executions.isEmpty ? null : executions.last;
    // Prefer the order's top-level DLC live state; fall back to the latest
    // execution's recorded values when the top-level field is omitted (some
    // historical/cached payloads). This is what makes `needsMakerSign` work
    // correctly after the taker has accepted: the coordinator returns
    // `dlc_status: accepted` at the top level of the maker's order.
    final topLevelDlcId = json['dlc_id'] as String?;
    final topLevelDlcStatus = json['dlc_status'] as String?;
    final topLevelFundingTxid = fundingTxidFromDetailJson(json);
    return DlcOrder(
      orderId: json['order_id'] as String? ?? '',
      instrumentId: json['instrument_id'] as String? ?? '',
      side: json['side'] as String? ?? '',
      status: json['status'] as String? ?? '',
      quantity: json['quantity'] as num? ?? 0,
      price: json['price'] as num?,
      filledQuantity: json['filled_quantity'] as num? ?? 0,
      remainingQuantity: json['remaining_quantity'] as num?,
      draftOfferObjectHex: json['draft_offer_object_hex'] as String? ??
          json['offer_object_hex'] as String?,
      executions: executions,
      cancellationReason: json['cancellation_reason'] as String?,
      idempotencyKey: json['idempotency_key'] as String?,
      lastErrorReason: json['last_error_reason'] as String?,
      lastErrorMessage: json['last_error_message'] as String?,
      dlcId: (topLevelDlcId != null && topLevelDlcId.isNotEmpty)
          ? topLevelDlcId
          : (latest?.dlcId.isNotEmpty ?? false ? latest?.dlcId : null),
      dlcStatus: topLevelDlcStatus ?? latest?.dlcStatus,
      fundingTxid: topLevelFundingTxid ?? latest?.fundingTxid,
      closingTxid: json['closing_txid'] as String? ?? latest?.closingTxid,
      refundTxid: json['refund_txid'] as String? ?? latest?.refundTxid,
      settlementType:
          json['settlement_type'] as String? ?? latest?.settlementType,
      oracleOutcomeValue: json['oracle_outcome_value']?.toString() ??
          latest?.oracleOutcomeValue,
    );
  }
}

/// Server response to `POST /orders`.
///
/// Unmatched orders return `dlc_id == null`, `executions == []`, and a draft
/// `offer_object_hex`. Immediate taker matches return one execution.
class DlcOrderResponse {
  const DlcOrderResponse({
    required this.orderId,
    required this.status,
    this.dlcId,
    this.offerObjectHex,
    this.executions = const <DlcOrderExecution>[],
  });

  final String orderId;
  final String status;
  final String? dlcId;
  final String? offerObjectHex;
  final List<DlcOrderExecution> executions;

  /// True when the response carries an execution the wallet must process.
  bool get isMatchedImmediately =>
      executions.isNotEmpty || (dlcId != null && dlcId!.isNotEmpty);

  factory DlcOrderResponse.fromJson(Map<String, dynamic> json) =>
      DlcOrderResponse(
        orderId: json['order_id'] as String? ?? '',
        status: json['status'] as String? ?? '',
        dlcId: json['dlc_id'] as String?,
        offerObjectHex: json['offer_object_hex'] as String?,
        executions: (json['executions'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(DlcOrderExecution.fromJson)
            .toList(growable: false),
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
