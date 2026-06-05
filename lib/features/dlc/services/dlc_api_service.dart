import 'package:aqua/features/dlc/config/dlc_config.dart';
import 'package:aqua/features/dlc/config/dlc_coordinator_http.dart';
import 'package:aqua/features/dlc/models/dlc_models.dart';
import 'package:aqua/features/dlc/services/dlc_api_exception.dart';
import 'package:aqua/features/shared/shared.dart';
import 'package:dio/dio.dart';

class DlcApiService {
  DlcApiService(this._dio, this._config);

  final Dio _dio;
  final DlcConfig _config;

  static Options _bearerOptions(String walletToken) =>
      DlcCoordinatorHttp.bearerOptions(walletToken);

  Future<DlcSystemReadiness> getSystemReadiness() async {
    final response = await _get<Map<String, dynamic>>('/auth/system-readiness');
    return DlcSystemReadiness.fromJson(response);
  }

  Future<String> createNonce() async {
    final partnerToken = _config.partnerToken;
    if (partnerToken.isEmpty) {
      throw DlcApiException(
        message: 'DLC partner token is not configured in .env',
        statusCode: 401,
      );
    }
    final response = await _post<Map<String, dynamic>>(
      '/auth/nonce',
      {},
      options: DlcCoordinatorHttp.partnerWriteOptions(partnerToken),
    );
    return response['nonce'] as String? ?? '';
  }

  Future<DlcWalletRegistration> registerWallet({
    required String xpub,
    required String nonce,
    required String xpubSignature,
    required String label,
    required List<DlcUtxoProof> utxos,
  }) async {
    final partnerToken = _config.partnerToken;
    if (partnerToken.isEmpty) {
      throw DlcApiException(
        message: 'DLC partner token is not configured in .env',
        statusCode: 401,
      );
    }
    final response = await _post<Map<String, dynamic>>(
      '/auth/wallet',
      {
        'xpub': xpub,
        'nonce': nonce,
        'xpub_signature': xpubSignature,
        'label': label,
        'utxos': utxos.map((u) => u.toJson()).toList(),
      },
      options: DlcCoordinatorHttp.partnerWriteOptions(partnerToken),
    );
    return DlcWalletRegistration.fromJson(response);
  }

  Future<Map<String, dynamic>> getWallet({
    required String walletId,
    required String walletToken,
  }) async {
    return _get<Map<String, dynamic>>(
      '/auth/wallet/$walletId',
      options: _bearerOptions(walletToken),
    );
  }

  Future<DlcWalletSyncResult> syncUtxos({
    required String walletId,
    required String walletToken,
    required String nonce,
    required List<DlcUtxoProof> utxos,
  }) async {
    final response = await _post<Map<String, dynamic>>(
      '/auth/wallet/$walletId/sync-utxos',
      {
        'nonce': nonce,
        'utxos': utxos.map((u) => u.toJson()).toList(),
      },
      options: DlcCoordinatorHttp.bearerWriteOptions(walletToken),
    );
    return DlcWalletSyncResult.fromJson(response);
  }

  Future<DlcPartnerConfig?> getPartnerConfig(String partnerId) async {
    if (partnerId.isEmpty) {
      return null;
    }
    try {
      final response = await _get<Map<String, dynamic>>(
        '/partners/$partnerId/config',
      );
      return DlcPartnerConfig.fromJson(response);
    } on DlcApiException catch (e) {
      if (e.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  Future<List<DlcInstrument>> listInstruments({
    required String instrumentsPath,
    String? walletToken,
  }) async {
    final response = await _get<List<dynamic>>(
      instrumentsPath,
      options: walletToken == null
          ? null
          : _bearerOptions(walletToken),
    );
    return response
        .whereType<Map<String, dynamic>>()
        .map(DlcInstrument.fromJson)
        .toList();
  }

  Future<DlcOrderResponse> createOrder({
    required String walletToken,
    required String instrumentId,
    required String side,
    required num quantity,
    required String fundingPubkeyHex,
    required String idempotencyKey,
  }) async {
    final response = await _post<Map<String, dynamic>>(
      '/orders',
      {
        'instrument_id': instrumentId,
        'side': side,
        'quantity': quantity,
        'price': null,
        'idempotency_key': idempotencyKey,
        'funding_pubkey_hex': fundingPubkeyHex,
      },
      options: DlcCoordinatorHttp.bearerWriteOptions(walletToken),
    );
    return DlcOrderResponse.fromJson(response);
  }

  Future<List<DlcOrder>> listOrders({
    required String walletToken,
  }) async {
    final response = await _get<List<dynamic>>(
      '/orders',
      options: _bearerOptions(walletToken),
    );
    return response
        .whereType<Map<String, dynamic>>()
        .map(DlcOrder.fromJson)
        .toList();
  }

  Future<DlcOrder> getOrder({
    required String walletToken,
    required String orderId,
  }) async {
    final response = await _get<Map<String, dynamic>>(
      '/orders/$orderId',
      options: _bearerOptions(walletToken),
    );
    return DlcOrder.fromJson(response);
  }

  Future<DlcOrder> cancelOrder({
    required String walletToken,
    required String orderId,
  }) async {
    final response = await _post<Map<String, dynamic>>(
      '/orders/$orderId/cancel',
      {},
      options: DlcCoordinatorHttp.bearerWriteOptions(walletToken),
    );
    return DlcOrder.fromJson(response);
  }

  Future<Map<String, dynamic>> getOrderbook(String instrumentId) async {
    return _get<Map<String, dynamic>>('/orderbook/$instrumentId');
  }

  Future<Map<String, dynamic>> simulateOptionPayout({
    String? walletToken,
    required Map<String, dynamic> body,
  }) async {
    return _post<Map<String, dynamic>>(
      '/orders/option-payout-simulation',
      body,
      options: walletToken == null || walletToken.isEmpty
          ? DlcCoordinatorHttp.writeOptions()
          : DlcCoordinatorHttp.bearerWriteOptions(walletToken),
    );
  }

  Future<DlcSigningContext> getAcceptContext({
    required String walletToken,
    required String orderId,
    required String fundingPubkeyHex,
  }) async {
    final response = await _post<Map<String, dynamic>>(
      '/orders/$orderId/accept-context',
      {'funding_pubkey_hex': fundingPubkeyHex},
      options: DlcCoordinatorHttp.bearerWriteOptions(walletToken),
    );
    return DlcSigningContext.fromJson(response);
  }

  Future<DlcOrder> submitAcceptMatch({
    required String walletToken,
    required String orderId,
    required String fundingPubkeyHex,
    required String contextFingerprint,
    required Map<String, dynamic> contextSnapshot,
    required String idempotencyKey,
    required List<String> cetAdaptorSignaturesHex,
    required String refundSignatureHex,
    required List<String> fundingSignaturesHex,
  }) async {
    final response = await _post<Map<String, dynamic>>(
      '/orders/$orderId/accept-match',
      {
        'funding_pubkey_hex': fundingPubkeyHex,
        'context_fingerprint': contextFingerprint,
        'context_snapshot': contextSnapshot,
        'idempotency_key': idempotencyKey,
        'cet_adaptor_signatures_hex': cetAdaptorSignaturesHex,
        'refund_signature_hex': refundSignatureHex,
        'funding_signatures_hex': fundingSignaturesHex,
      },
      options: DlcCoordinatorHttp.bearerWriteOptions(walletToken),
    );
    return DlcOrder.fromJson(response);
  }

  Future<DlcSigningContext> getSignContext({
    required String walletToken,
    required String dlcId,
  }) async {
    final response = await _get<Map<String, dynamic>>(
      '/dlcs/$dlcId/sign-context',
      options: Options(
        headers: {'Authorization': 'Bearer $walletToken'},
        receiveTimeout: DlcCoordinatorHttp.writeReceiveTimeout,
        extra: {DlcCoordinatorHttp.skipBackupExtraKey: true},
      ),
    );
    return DlcSigningContext.fromJson(response);
  }

  Future<Map<String, dynamic>> getDlc({
    required String walletToken,
    required String dlcId,
  }) async {
    return _get<Map<String, dynamic>>(
      '/dlcs/$dlcId',
      options: _bearerOptions(walletToken),
    );
  }

  Future<Map<String, dynamic>> getFundingTransaction({
    required String walletToken,
    required String dlcId,
  }) async {
    return _get<Map<String, dynamic>>(
      '/dlcs/$dlcId/funding-transaction',
      options: _bearerOptions(walletToken),
    );
  }

  Future<Map<String, dynamic>> getSettlementStatus({
    required String walletToken,
    required String dlcId,
  }) async {
    return _get<Map<String, dynamic>>(
      '/dlcs/$dlcId/settlement-status',
      options: _bearerOptions(walletToken),
    );
  }

  Future<Map<String, dynamic>> submitSign({
    required String walletToken,
    required String dlcId,
    required String idempotencyKey,
    required List<String> cetAdaptorSignaturesHex,
    required String refundSignatureHex,
    required List<String> fundingSignaturesHex,
  }) async {
    return _post<Map<String, dynamic>>(
      '/dlcs/$dlcId/sign',
      {
        'idempotency_key': idempotencyKey,
        'cet_adaptor_signatures_hex': cetAdaptorSignaturesHex,
        'refund_signature_hex': refundSignatureHex,
        'funding_signatures_hex': fundingSignaturesHex,
      },
      options: DlcCoordinatorHttp.bearerWriteOptions(walletToken),
    );
  }

  Future<T> _get<T>(
    String path, {
    Options? options,
  }) async {
    try {
      final response = await _dio.get<dynamic>(path, options: options);
      return _parseBody<T>(response.data);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<T> _post<T>(
    String path,
    Map<String, dynamic> data, {
    Options? options,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: data,
        options: options,
      );
      return _parseBody<T>(response.data);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  T _parseBody<T>(dynamic data) {
    if (data is T) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data) as T;
    }
    if (data is List) {
      return data as T;
    }
    throw DlcApiException(message: 'Unexpected response body type');
  }

  DlcApiException _toApiException(DioException error) {
    final response = error.response;
    final statusCode = response?.statusCode;
    var message = error.message ?? 'Network error';
    String? errorCode;
    final data = response?.data;
    if (data is Map<String, dynamic>) {
      errorCode = _readErrorCode(data);
      final detail = data['detail'];
      if (detail is String) {
        message = detail;
      } else if (detail is Map) {
        errorCode ??= _readErrorCode(Map<String, dynamic>.from(detail));
        message = detail['message']?.toString() ??
            detail['reason']?.toString() ??
            detail['detail']?.toString() ??
            message;
      } else if (detail is List && detail.isNotEmpty) {
        message = detail.first.toString();
      } else {
        message = data['message']?.toString() ?? message;
      }
    }
    return DlcApiException(
      message: message,
      statusCode: statusCode,
      errorCode: errorCode,
      isTimeout: error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.connectionTimeout,
      isConnectionError: error.type == DioExceptionType.connectionError,
    );
  }

  String? _readErrorCode(Map<String, dynamic> data) {
    for (final key in ['code', 'error', 'reason']) {
      final value = data[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }
}

final dlcApiServiceProvider = Provider<DlcApiService>(
  (ref) => DlcApiService(
    ref.read(dlcDioProvider),
    ref.read(dlcConfigProvider),
  ),
);
