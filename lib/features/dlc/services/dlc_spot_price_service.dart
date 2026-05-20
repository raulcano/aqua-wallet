import 'dart:convert';

import 'package:aqua/features/dlc/config/dlc_config.dart';
import 'package:aqua/features/shared/shared.dart';
import 'package:http/http.dart' as http;

class DlcSpotPriceService {
  DlcSpotPriceService(this._config);

  final DlcConfig _config;

  Future<num?> fetchBtcUsdSpot() async {
    final url = _config.btcUsdTickerUrl;
    if (url.isEmpty) {
      return null;
    }
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final data = decoded['data'];
      if (data is Map<String, dynamic>) {
        final amount = data['amount'];
        if (amount is num) {
          return amount;
        }
        if (amount is String) {
          return num.tryParse(amount);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

final dlcSpotPriceServiceProvider = Provider<DlcSpotPriceService>((ref) {
  return DlcSpotPriceService(ref.watch(dlcConfigProvider));
});
