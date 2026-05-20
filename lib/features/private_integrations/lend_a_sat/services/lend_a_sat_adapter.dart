import 'package:aqua/features/lending/lending.dart';
import 'package:aqua/features/shared/shared.dart';

final lendASatAdapterProvider = Provider<LendingService>((ref) {
  return const _LendASatAdapter();
});

class _LendASatAdapter implements LendingService {
  const _LendASatAdapter();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> clearApiKey() async {}

  @override
  Future<LoanContract> getContract(String contractId) async {
    throw UnimplementedError('Lend-a-sat adapter unavailable in this build');
  }

  @override
  Future<List<LoanContract>> getContracts() async => const [];

  @override
  Future<CollateralPsbt> getClaimCollateralPsbt(
      String contractId, int feeRate) async {
    throw UnimplementedError('Lend-a-sat adapter unavailable in this build');
  }

  @override
  Future<String?> getApiKey() async => null;

  @override
  Future<List<LoanOffer>> getLoanOffers() async => const [];

  @override
  Future<void> markContractAsRepaid(
      String contractId, String transactionId) async {}

  @override
  Future<String> postClaimTx(String contractId, String signedTx) async {
    throw UnimplementedError('Lend-a-sat adapter unavailable in this build');
  }

  @override
  Future<LoanContract> requestContract(ContractRequest request) async {
    throw UnimplementedError('Lend-a-sat adapter unavailable in this build');
  }

  @override
  bool get requiresApiKey => false;

  @override
  bool get requiresKyc => false;

  @override
  String get serviceDescription => 'Lend a Sat';

  @override
  String get serviceIconPath => '';

  @override
  String? get serviceKycUrl => null;

  @override
  String get serviceName => 'Lend a Sat';

  @override
  String get servicePrivacyUrl => '';

  @override
  String get serviceSupportUrl => '';

  @override
  String get serviceTermsUrl => '';

  @override
  String get serviceWebsiteUrl => '';

  @override
  Future<void> setApiKey(String apiKey) async {}
}
