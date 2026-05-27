class DlcApiException implements Exception {
  DlcApiException({
    required this.message,
    this.statusCode,
    this.errorCode,
    this.isTimeout = false,
    this.isConnectionError = false,
  });

  final String message;
  final int? statusCode;
  final String? errorCode;
  final bool isTimeout;
  final bool isConnectionError;

  @override
  String toString() => message;
}

String readDlcApiErrorMessage(dynamic error) {
  if (error is DlcApiException) {
    if (isDlcDnsLookupFailure(error.message)) {
      return '${error.message}\n\n'
          'This device cannot resolve the coordinator hostname. '
          'Check Wi‑Fi or mobile data, turn off Private DNS/VPN, or set '
          'DLC_COORDINATOR_URL to http://<server-ip>:8000 in .env, add that '
          'IP to network_security_config.xml, then rebuild.';
    }
    return error.message;
  }
  return error.toString();
}

bool isDlcDnsLookupFailure(String message) {
  final normalized = message.toLowerCase();
  return normalized.contains('failed host lookup') ||
      normalized.contains('no address associated with hostname') ||
      normalized.contains('name or service not known');
}

String dlcCoordinatorConnectionHint({
  required String baseUrl,
  required DlcApiException error,
}) {
  final detail = error.isTimeout
      ? 'timed out'
      : isDlcDnsLookupFailure(error.message)
          ? error.message
          : error.isConnectionError
              ? (error.message.isNotEmpty ? error.message : 'could not connect')
              : error.message;
  final buffer = StringBuffer('Coordinator unreachable at $baseUrl ($detail).');
  if (isDlcDnsLookupFailure(error.message)) {
    buffer.write(
      ' Check Wi‑Fi/mobile data and Private DNS on this device. '
      'You can also point DLC_COORDINATOR_URL at the server IP in .env '
      'and allow that IP for cleartext HTTP in network_security_config.xml.',
    );
  } else if (baseUrl.startsWith('http://') &&
      !baseUrl.contains('localhost') &&
      !baseUrl.contains('127.0.0.1')) {
    buffer.write(
      ' Android blocks cleartext HTTP unless the host is listed in '
      'network_security_config.xml.',
    );
  }
  buffer.write(
    ' After editing .env, run `dart run build_runner build` and rebuild the app.',
  );
  return buffer.toString();
}
