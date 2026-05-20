import 'package:aqua/features/dlc/config/dlc_config.dart';
import 'package:aqua/features/dlc/models/dlc_models.dart';
import 'package:aqua/features/dlc/models/dlc_trade_models.dart';
import 'package:aqua/features/dlc/services/dlc_api_exception.dart';
import 'package:aqua/features/dlc/services/dlc_api_service.dart';
import 'package:aqua/features/dlc/services/dlc_auth_storage.dart';
import 'package:aqua/features/dlc/services/dlc_idempotency_storage.dart';
import 'package:aqua/features/dlc/services/dlc_local_signer.dart';
import 'package:aqua/features/dlc/services/dlc_negotiation_utils.dart';
import 'package:aqua/features/dlc/services/dlc_spot_price_service.dart';
import 'package:aqua/features/dlc/services/dlc_wallet_context.dart';
import 'package:aqua/features/dlc/utils/dlc_instrument_utils.dart';
import 'package:aqua/features/dlc/utils/dlc_order_utils.dart';
import 'package:aqua/features/shared/shared.dart';

class DlcRepository {
  DlcRepository({
    required DlcApiService api,
    required DlcAuthStorage authStorage,
    required DlcIdempotencyStorage idempotencyStorage,
    required DlcLocalSigner signer,
    required DlcWalletContextResolver contextResolver,
    required DlcSpotPriceService spotPriceService,
    required DlcConfig config,
  })  : _api = api,
        _authStorage = authStorage,
        _idempotencyStorage = idempotencyStorage,
        _signer = signer,
        _contextResolver = contextResolver,
        _spotPriceService = spotPriceService,
        _config = config;

  final DlcApiService _api;
  final DlcAuthStorage _authStorage;
  final DlcIdempotencyStorage _idempotencyStorage;
  final DlcLocalSigner _signer;
  final DlcWalletContextResolver _contextResolver;
  final DlcSpotPriceService _spotPriceService;
  final DlcConfig _config;

  Future<DlcSystemReadiness> getSystemReadiness() => _api.getSystemReadiness();

  Future<DlcPartnerConfig?> getPartnerConfig() =>
      _api.getPartnerConfig(_config.partnerId);

  String? networkMismatchHint(DlcSystemReadiness readiness) {
    final coordinatorNetwork = readiness.network.toLowerCase();
    final expected = _config.network.coordinatorNetwork;
    if (coordinatorNetwork.isEmpty) {
      return null;
    }
    if (coordinatorNetwork != expected) {
      return 'Coordinator is on $coordinatorNetwork but the app is configured for $expected';
    }
    return null;
  }

  Future<DlcWalletAuth?> loadAuth(String walletOriginId) =>
      _authStorage.loadForWallet(walletOriginId);

  /// Validates stored bearer token against the coordinator; clears on 401/403/404.
  Future<DlcWalletAuth?> validateStoredAuth(DlcWalletAuth auth) async {
    try {
      await _api.getWallet(
        walletId: auth.walletId,
        walletToken: auth.walletToken,
      );
      return auth;
    } on DlcApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 404) {
        await _authStorage.remove(auth.walletOriginId);
        return null;
      }
      rethrow;
    }
  }

  Future<void> clearAuth(String walletOriginId) =>
      _authStorage.remove(walletOriginId);

  Future<DlcWalletAuth> registerWallet({
    required String walletOriginId,
    required String walletLabel,
    required String mnemonic,
  }) async {
    final context = await _contextResolver.resolve(
      walletId: walletOriginId,
      walletLabel: walletLabel,
      mnemonic: mnemonic,
    );

    if (context.coordinatorXpub.isEmpty) {
      throw StateError('Could not read Bitcoin account xpub for registration');
    }

    final nonce = await _api.createNonce();
    final utxoProofs = _signer.buildUtxoProofs(
      nonce: nonce,
      mnemonic: mnemonic,
      utxos: context.utxos,
      accountUserPath: context.accountUserPath,
    );

    final signatureCandidates = _signer.signNonceProofCandidates(
      nonce: nonce,
      mnemonic: mnemonic,
      accountUserPath: context.accountUserPath,
    );

    DlcApiException? lastError;
    for (final signature in signatureCandidates) {
      try {
        final registration = await _api.registerWallet(
          xpub: context.coordinatorXpub,
          nonce: nonce,
          xpubSignature: signature,
          label: walletLabel,
          utxos: utxoProofs,
        );
        final auth = DlcWalletAuth(
          walletOriginId: walletOriginId,
          walletLabel: walletLabel,
          walletXpub: context.coordinatorXpub,
          walletId: registration.walletId,
          walletToken: registration.walletToken,
          expiresAt: registration.expiresAt,
        );
        await _authStorage.store(auth);
        return auth;
      } on DlcApiException catch (e) {
        lastError = e;
        if (e.statusCode != null && e.statusCode! >= 400 && e.statusCode! < 500) {
          final message = e.message.toLowerCase();
          if (!message.contains('signature') && !message.contains('nonce')) {
            rethrow;
          }
        }
      }
    }
    throw lastError ?? DlcApiException(message: 'Wallet registration failed');
  }

  Future<DlcWalletSyncResult> syncWalletUtxos({
    required DlcWalletAuth auth,
    required String mnemonic,
  }) async {
    final context = await _contextResolver.resolve(
      walletId: auth.walletOriginId,
      walletLabel: auth.walletLabel,
      mnemonic: mnemonic,
    );
    final nonce = await _api.createNonce();
    final utxoProofs = _signer.buildUtxoProofs(
      nonce: nonce,
      mnemonic: mnemonic,
      utxos: context.utxos,
      accountUserPath: context.accountUserPath,
    );
    return _api.syncUtxos(
      walletId: auth.walletId,
      walletToken: auth.walletToken,
      nonce: nonce,
      utxos: utxoProofs,
    );
  }

  Future<List<DlcInstrument>> listInstruments(String? walletToken) =>
      _api.listInstruments(
        instrumentsPath: _config.instrumentsPath,
        walletToken: walletToken,
      );

  Future<num?> fetchBtcUsdSpotPrice() => _spotPriceService.fetchBtcUsdSpot();

  Future<DlcOrderbookSnapshot> getOrderbook(String instrumentId) async {
    final json = await _api.getOrderbook(instrumentId);
    return DlcOrderbookSnapshot.fromJson(json);
  }

  Future<List<DlcStrikeOrderbookSnapshot>> fetchStrikeOrderbooks({
    required String templateInstrumentId,
    required List<num> strikes,
    String? walletToken,
  }) async {
    final instruments = await listInstruments(walletToken);
    final snapshots = <DlcStrikeOrderbookSnapshot>[];

    for (final strike in strikes) {
      final strikeToken = dlcNormalizeStrikeToken(strike);
      final instrumentId = dlcResolveInstrumentId(
        templateOrId: templateInstrumentId,
        strikeToken: strikeToken,
        instruments: instruments,
        allowUnresolvedInCatalog: _config.showExpiredInstruments,
      );
      if (instrumentId == null) {
        snapshots.add(
          DlcStrikeOrderbookSnapshot(
            strike: strike,
            instrumentId: '',
            orderbook: null,
            errorMessage: 'No instrument for strike $strikeToken',
          ),
        );
        continue;
      }

      final instrument = instruments.firstWhere(
        (i) => i.instrumentId == instrumentId,
        orElse: () => DlcInstrument(instrumentId: instrumentId),
      );
      if (dlcIsInstrumentExpired(
        instrument,
        allowExpired: _config.showExpiredInstruments,
      )) {
        snapshots.add(
          DlcStrikeOrderbookSnapshot(
            strike: strike,
            instrumentId: instrumentId,
            orderbook: null,
            errorMessage: 'Instrument expired',
          ),
        );
        continue;
      }

      try {
        final book = await getOrderbook(instrumentId);
        snapshots.add(
          DlcStrikeOrderbookSnapshot(
            strike: strike,
            instrumentId: instrumentId,
            orderbook: book,
          ),
        );
      } on DlcApiException catch (e) {
        snapshots.add(
          DlcStrikeOrderbookSnapshot(
            strike: strike,
            instrumentId: instrumentId,
            orderbook: null,
            errorMessage: e.message,
          ),
        );
      }
    }

    return snapshots;
  }

  Future<DlcOptionPayoutSimulationResult> simulateOptionPayout({
    required DlcWalletAuth auth,
    required DlcOptionPayoutSimulationRequest request,
  }) async {
    final json = await _api.simulateOptionPayout(
      walletToken: auth.walletToken,
      body: request.toJson(),
    );
    return DlcOptionPayoutSimulationResult.fromJson(json);
  }

  /// Rough aggregate PnL at [outcomePrice] across open/live positions.
  Future<num?> estimateWalletPnlSats({
    required DlcWalletAuth auth,
    required List<DlcOrder> orders,
    required num outcomePrice,
  }) async {
    final positions = orders
        .where(
          (order) =>
              orderShowsInOpenSection(order) || orderShowsInLiveSection(order),
        )
        .take(8)
        .toList();
    if (positions.isEmpty) {
      return null;
    }

    num total = 0;
    var counted = 0;
    for (final order in positions) {
      final strike = dlcStrikeUsdFromInstrumentId(order.instrumentId);
      final optionRight =
          dlcOptionRightFromInstrumentId(order.instrumentId) ?? 'C';
      if (strike == null) {
        continue;
      }
      try {
        final result = await simulateOptionPayout(
          auth: auth,
          request: DlcOptionPayoutSimulationRequest(
            side: order.side,
            role: order.isMaker ? 'maker' : 'taker',
            optionRight: optionRight,
            numContracts: order.quantity,
            strike: strike,
            premiumPerContractSats: order.price ?? 0,
            outcomePrice: outcomePrice,
            premiumPaidUpfront: true,
          ),
        );
        if (result.walletPnlSats != null) {
          total += result.walletPnlSats!;
          counted++;
        }
      } on DlcApiException {
        continue;
      }
    }
    return counted > 0 ? total : null;
  }

  Future<String> resolveCreateInstrumentId({
    required String templateOrId,
    required num strike,
    String? walletToken,
  }) async {
    final instruments = await listInstruments(walletToken);
    final strikeToken = dlcNormalizeStrikeToken(strike);
    final resolved = dlcResolveInstrumentId(
      templateOrId: templateOrId,
      strikeToken: strikeToken,
      instruments: instruments,
      allowUnresolvedInCatalog: _config.showExpiredInstruments,
    );
    if (resolved == null || resolved.isEmpty) {
      throw DlcApiException(
        message: 'Unknown or expired instrument for strike $strikeToken',
        statusCode: 404,
      );
    }
    final instrument = instruments.firstWhere(
      (i) => i.instrumentId == resolved,
      orElse: () => DlcInstrument(instrumentId: resolved),
    );
    if (dlcIsInstrumentExpired(
      instrument,
      allowExpired: _config.showExpiredInstruments,
    )) {
      throw DlcApiException(
        message: 'Instrument $resolved has expired',
        statusCode: 400,
      );
    }
    return resolved;
  }

  Future<List<DlcOrder>> listOrders(
    DlcWalletAuth auth, {
    bool enrichSettlement = false,
  }) async {
    final orders = await _api.listOrders(walletToken: auth.walletToken);
    if (!enrichSettlement) {
      return orders;
    }
    return Future.wait(
      orders.map((order) => _enrichOrderSettlement(auth, order)),
    );
  }

  Future<DlcOrderResponse> createOrder({
    required DlcWalletAuth auth,
    required String mnemonic,
    required String instrumentId,
    required String side,
    required num quantity,
    num? strike,
  }) async {
    final resolvedInstrumentId = strike != null
        ? await resolveCreateInstrumentId(
            templateOrId: instrumentId,
            strike: strike,
            walletToken: auth.walletToken,
          )
        : instrumentId;

    if (strike == null &&
        dlcInstrumentHasStrikePlaceholder(instrumentId)) {
      throw DlcApiException(
        message: 'Select a strike before creating an order',
        statusCode: 400,
      );
    }

    await syncWalletUtxos(auth: auth, mnemonic: mnemonic);
    final context = await _contextResolver.resolve(
      walletId: auth.walletOriginId,
      walletLabel: auth.walletLabel,
      mnemonic: mnemonic,
    );
    final funding = _signer.deriveFundingPubkey(
      mnemonic,
      context.accountUserPath,
    );
    final draftFingerprint = createOrderDraftFingerprint(
      instrumentId: resolvedInstrumentId,
      side: side,
      quantity: quantity,
      fundingPubkeyHex: funding.pubkeyHex,
    );
    final idempotencyKey = await _idempotencyStorage.getOrCreateCreateKey(
      draftFingerprint,
    );

    try {
      final response = await _api.createOrder(
        walletToken: auth.walletToken,
        instrumentId: resolvedInstrumentId,
        side: side,
        quantity: quantity,
        fundingPubkeyHex: funding.pubkeyHex,
        idempotencyKey: idempotencyKey,
      );
      await _idempotencyStorage.clearCreateKey(draftFingerprint);
      return response;
    } on DlcApiException catch (e) {
      if (e.statusCode == 409 || e.isTimeout || e.isConnectionError) {
        final reconciled = await _reconcileCreatedOrder(
          auth: auth,
          idempotencyKey: idempotencyKey,
        );
        if (reconciled != null) {
          await _idempotencyStorage.clearCreateKey(draftFingerprint);
          return reconciled;
        }
      }
      if (e.statusCode != 409) {
        await _idempotencyStorage.clearCreateKey(draftFingerprint);
      }
      rethrow;
    }
  }

  Future<DlcOrder> cancelOrder({
    required DlcWalletAuth auth,
    required String orderId,
    required String mnemonic,
  }) async {
    final order = await _api.cancelOrder(
      walletToken: auth.walletToken,
      orderId: orderId,
    );
    await syncWalletUtxos(auth: auth, mnemonic: mnemonic);
    return order;
  }

  Future<void> runNegotiationPass({
    required DlcWalletAuth auth,
    required String mnemonic,
  }) async {
    final orders = await listOrders(auth);
    for (final order in orders) {
      if (!orderNeedsNegotiation(order)) {
        continue;
      }
      try {
        if (order.needsTakerAccept) {
          await _submitTakerAccept(
            auth: auth,
            mnemonic: mnemonic,
            order: order,
          );
        } else if (order.needsMakerSign && order.dlcId != null) {
          await _submitMakerSign(
            auth: auth,
            mnemonic: mnemonic,
            order: order,
            dlcId: order.dlcId!,
          );
        }
      } on DlcApiException catch (e) {
        if (e.statusCode == 404) {
          continue;
        }
        rethrow;
      }
    }
  }

  Future<void> _submitTakerAccept({
    required DlcWalletAuth auth,
    required String mnemonic,
    required DlcOrder order,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _submitTakerAcceptOnce(
          auth: auth,
          mnemonic: mnemonic,
          order: order,
        );
        return;
      } on DlcApiException catch (e) {
        if (attempt == 0 && isDlcContextMismatch(e)) {
          continue;
        }
        rethrow;
      }
    }
  }

  Future<void> _submitTakerAcceptOnce({
    required DlcWalletAuth auth,
    required String mnemonic,
    required DlcOrder order,
  }) async {
    final context = await _contextResolver.resolve(
      walletId: auth.walletOriginId,
      walletLabel: auth.walletLabel,
      mnemonic: mnemonic,
    );
    await syncWalletUtxos(auth: auth, mnemonic: mnemonic);
    final funding = _signer.deriveFundingPubkey(
      mnemonic,
      context.accountUserPath,
    );
    final acceptContext = await _api.getAcceptContext(
      walletToken: auth.walletToken,
      orderId: order.orderId,
      fundingPubkeyHex: funding.pubkeyHex,
    );
    final idempotencyKey = await _idempotencyStorage.getOrCreateAcceptKey(
      orderId: order.orderId,
      contextFingerprint: acceptContext.contextFingerprint,
    );
    final signatures = _signer.signDlcContext(
      context: acceptContext,
      mnemonic: mnemonic,
      accountUserPath: context.accountUserPath,
      walletUtxos: context.utxos,
    );
    try {
      await _api.submitAcceptMatch(
        walletToken: auth.walletToken,
        orderId: order.orderId,
        fundingPubkeyHex: funding.pubkeyHex,
        contextFingerprint: acceptContext.contextFingerprint,
        contextSnapshot: acceptContextToSnapshot(acceptContext),
        idempotencyKey: idempotencyKey,
        cetAdaptorSignaturesHex: signatures.cetAdaptorSignaturesHex,
        refundSignatureHex: signatures.refundSignatureHex,
        fundingSignaturesHex: signatures.fundingSignaturesHex,
      );
    } on DlcApiException catch (e) {
      if (isDlcContextMismatch(e)) {
        await _idempotencyStorage.rotateAcceptKey(
          orderId: order.orderId,
          contextFingerprint: acceptContext.contextFingerprint,
        );
      }
      rethrow;
    }
    await syncWalletUtxos(auth: auth, mnemonic: mnemonic);
  }

  Future<void> _submitMakerSign({
    required DlcWalletAuth auth,
    required String mnemonic,
    required DlcOrder order,
    required String dlcId,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _submitMakerSignOnce(
          auth: auth,
          mnemonic: mnemonic,
          order: order,
          dlcId: dlcId,
        );
        return;
      } on DlcApiException catch (e) {
        if (attempt == 0 && isDlcContextMismatch(e)) {
          continue;
        }
        rethrow;
      }
    }
  }

  Future<void> _submitMakerSignOnce({
    required DlcWalletAuth auth,
    required String mnemonic,
    required DlcOrder order,
    required String dlcId,
  }) async {
    final context = await _contextResolver.resolve(
      walletId: auth.walletOriginId,
      walletLabel: auth.walletLabel,
      mnemonic: mnemonic,
    );
    final signContext = await _api.getSignContext(
      walletToken: auth.walletToken,
      dlcId: dlcId,
    );
    final fingerprint = signContext.signContextFingerprint;
    final idempotencyKey = await _idempotencyStorage.getOrCreateSignKey(
      dlcId: dlcId,
      contextFingerprint: fingerprint,
    );
    final signatures = _signer.signDlcContext(
      context: signContext,
      mnemonic: mnemonic,
      accountUserPath: context.accountUserPath,
      walletUtxos: context.utxos,
    );
    try {
      await _api.submitSign(
        walletToken: auth.walletToken,
        dlcId: dlcId,
        idempotencyKey: idempotencyKey,
        cetAdaptorSignaturesHex: signatures.cetAdaptorSignaturesHex,
        refundSignatureHex: signatures.refundSignatureHex,
        fundingSignaturesHex: signatures.fundingSignaturesHex,
      );
    } on DlcApiException catch (e) {
      if (isDlcContextMismatch(e)) {
        await _idempotencyStorage.rotateSignKey(
          dlcId: dlcId,
          contextFingerprint: fingerprint,
        );
      }
      rethrow;
    }
    await syncWalletUtxos(auth: auth, mnemonic: mnemonic);
  }

  Future<DlcOrderResponse?> _reconcileCreatedOrder({
    required DlcWalletAuth auth,
    required String idempotencyKey,
  }) async {
    final orders = await _api.listOrders(walletToken: auth.walletToken);
    for (final order in orders) {
      if (order.idempotencyKey == idempotencyKey) {
        return DlcOrderResponse(
          orderId: order.orderId,
          dlcId: order.dlcId ?? '',
          status: order.status,
          pendingMatchAccept: order.pendingMatchAccept,
          signRequired: order.signRequired,
        );
      }
    }
    return null;
  }

  Future<DlcOrder> _enrichOrderSettlement(
    DlcWalletAuth auth,
    DlcOrder order,
  ) async {
    final dlcId = order.dlcId;
    if (dlcId == null || dlcId.isEmpty || !order.isLiveDlc) {
      return order;
    }
    try {
      final settlement = await _api.getSettlementStatus(
        walletToken: auth.walletToken,
        dlcId: dlcId,
      );
      return order.mergeSettlement(settlement);
    } on DlcApiException catch (e) {
      if (e.statusCode == 404) {
        return order;
      }
      rethrow;
    }
  }
}

Map<String, dynamic> acceptContextToSnapshot(DlcSigningContext context) => {
      'context_fingerprint': context.contextFingerprint,
      'cet_signing_jobs': context.cetSigningJobs
          .map(
            (job) => {
              'message_hash_hex': job.messageHashHex,
              'adaptor_point_hex': job.adaptorPointHex,
            },
          )
          .toList(),
      'refund_sighash_hex': context.refundSighashHex,
      'funding_input_sighashes_hex': context.fundingInputSighashesHex,
      'funding_input_outpoints': context.fundingInputOutpoints,
      if (context.offerObjectHex != null)
        'offer_object_hex': context.offerObjectHex,
    };

final dlcRepositoryProvider = Provider<DlcRepository>((ref) {
  return DlcRepository(
    api: ref.read(dlcApiServiceProvider),
    authStorage: ref.read(dlcAuthStorageProvider),
    idempotencyStorage: ref.read(dlcIdempotencyStorageProvider),
    signer: const DlcLocalSigner(),
    contextResolver: ref.read(dlcWalletContextResolverProvider),
    spotPriceService: ref.read(dlcSpotPriceServiceProvider),
    config: ref.watch(dlcConfigProvider),
  );
});
