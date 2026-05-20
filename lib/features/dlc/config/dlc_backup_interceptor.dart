import 'package:aqua/features/dlc/config/dlc_coordinator_http.dart';
import 'package:dio/dio.dart';

/// Retries failed coordinator requests against the backup base URL once.
class DlcBackupInterceptor extends Interceptor {
  DlcBackupInterceptor({
    required this.backupBaseUrl,
    required this.dioOptions,
  });

  final String backupBaseUrl;
  final BaseOptions dioOptions;

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
    try {
      final response = await backupDio.fetch(
        err.requestOptions.copyWith(extra: {
          ...err.requestOptions.extra,
          _retriedKey: true,
        }),
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
