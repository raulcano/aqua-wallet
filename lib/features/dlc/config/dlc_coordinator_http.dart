import 'package:dio/dio.dart';

/// HTTP conventions for the DLC coordinator client (aligned with BullBitcoin).
abstract final class DlcCoordinatorHttp {
  static const skipBackupExtraKey = 'dlc_skip_backup';

  static const Duration writeReceiveTimeout = Duration(seconds: 90);
  static const Duration writeSendTimeout = Duration(seconds: 30);

  static Options writeOptions({Map<String, dynamic>? extra}) => Options(
        receiveTimeout: writeReceiveTimeout,
        sendTimeout: writeSendTimeout,
        extra: {
          skipBackupExtraKey: true,
          ...?extra,
        },
      );

  static Options bearerOptions(String walletToken) => Options(
        headers: {'Authorization': 'Bearer $walletToken'},
      );

  static Options bearerWriteOptions(
    String walletToken, {
    Map<String, dynamic>? extra,
  }) =>
      Options(
        headers: {'Authorization': 'Bearer $walletToken'},
        receiveTimeout: writeReceiveTimeout,
        sendTimeout: writeSendTimeout,
        extra: {
          skipBackupExtraKey: true,
          ...?extra,
        },
      );
}
