import 'package:aqua/features/dlc/config/dlc_coordinator_http.dart';
import 'package:dio/dio.dart';

/// Retries failed coordinator requests against the backup base URL once.
class DlcBackupInterceptor extends Interceptor {
  DlcBackupInterceptor({
    required this.backupBaseUrl,
    required this.dioOptions,
    required this.partnerToken,
  });

  final String backupBaseUrl;
  final BaseOptions dioOptions;
  final String partnerToken;

  static const _retriedKey = 'dlc_backup_retried';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (backupBaseUrl.isEmpty ||
        err.requestOptions.extra[_retriedKey] == true ||
        err.requestOptions.extra[DlcCoordinatorHttp.skipBackupExtraKey] == true ||
        !_shouldRetry(err)) {
      return handler.next(err);
    }

    final backupDio = Dio(dioOptions.copyWith(baseUrl: backupBaseUrl));
    if (partnerToken.isNotEmpty) {
      backupDio.options.headers['X-Partner-Token'] = partnerToken;
    }
    try {
      final response = await backupDio.fetch(
        err.requestOptions.copyWith(
          extra: {
            ...err.requestOptions.extra,
            _retriedKey: true,
          },
          headers: {
            ...err.requestOptions.headers,
            if (partnerToken.isNotEmpty) 'X-Partner-Token': partnerToken,
          },
        ),
      );
      handler.resolve(response);
    } catch (_) {
      handler.next(err);
    }
  }

  bool _shouldRetry(DioException err) =>
      err.type == DioExceptionType.connectionError ||
      err.type == DioExceptionType.connectionTimeout ||
      err.type == DioExceptionType.receiveTimeout ||
      err.type == DioExceptionType.sendTimeout;
}
