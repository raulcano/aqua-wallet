class DlcApiException implements Exception {
  DlcApiException({
    required this.message,
    this.statusCode,
    this.isTimeout = false,
    this.isConnectionError = false,
  });

  final String message;
  final int? statusCode;
  final bool isTimeout;
  final bool isConnectionError;

  @override
  String toString() => message;
}

String readDlcApiErrorMessage(dynamic error) {
  if (error is DlcApiException) {
    return error.message;
  }
  return error.toString();
}
