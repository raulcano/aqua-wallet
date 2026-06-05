import 'package:aqua/features/dlc/models/dlc_models.dart';

/// Whether the order has enough data to open the ColdPay DLC Explorer dashboard.
bool canOpenDlcExplorer({
  required DlcOrder order,
  required String? walletToken,
}) {
  final dlcId = order.dlcId;
  final token = walletToken;
  return dlcId != null &&
      dlcId.isNotEmpty &&
      token != null &&
      token.isNotEmpty;
}

/// application/x-www-form-urlencoded POST body for the DLC Explorer dashboard.
String buildDlcExplorerPostBody({
  required String walletToken,
  required String dlcId,
}) {
  return 'wallet_token=${Uri.encodeQueryComponent(walletToken)}&'
      'dlc_id=${Uri.encodeQueryComponent(dlcId)}';
}
