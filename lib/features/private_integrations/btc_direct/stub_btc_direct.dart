import 'package:aqua/features/marketplace/models/models.dart';
import 'package:aqua/features/marketplace/providers/on_ramp_setup_provider.dart';
import 'package:aqua/features/marketplace/services/on_ramp_price_fetchers.dart';
import 'package:aqua/features/shared/shared.dart';

class BTCDirectApiService {
  const BTCDirectApiService();

  Future<String> createCheckoutUrl(OnRampIntegration integration) async {
    return integration.refLinkMainnet ?? integration.refLinkTestnet ?? '';
  }

  Future<String?> getBtcPriceLabel() async => null;
}

final btcDirectApiServiceProvider =
    Provider<BTCDirectApiService>((ref) => const BTCDirectApiService());

class BTCDirectPriceFetcher implements OnRampPriceFetcher {
  BTCDirectPriceFetcher(this._service);

  final BTCDirectApiService _service;

  @override
  Future<String?> fetchPrice(OnRampIntegration integration, Ref ref) async {
    return _service.getBtcPriceLabel();
  }
}

class BTCDirectIntegrationHandler implements OnRampIntegrationHandler {
  BTCDirectIntegrationHandler({
    required BTCDirectApiService btcDirectService,
    required this.bitcoinProvider,
    required this.getUserHashId,
  }) : _btcDirectService = btcDirectService;

  final BTCDirectApiService _btcDirectService;
  final dynamic bitcoinProvider;
  final Future<String?> Function() getUserHashId;

  @override
  Future<String> getIntegrationUrl(OnRampIntegration integration) async {
    return _btcDirectService.createCheckoutUrl(integration);
  }
}
