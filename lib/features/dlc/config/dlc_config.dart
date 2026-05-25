import 'package:aqua/config/config.dart';
import 'package:aqua/features/dlc/config/dlc_backup_interceptor.dart';
import 'package:aqua/features/dlc/config/dlc_coordinator_http.dart';
import 'package:aqua/features/shared/shared.dart';
import 'package:dio/dio.dart';

/// Coordinator deployment target for the active Aqua environment.
enum DlcCoordinatorNetwork {
  mainnet('mainnet'),
  testnet3('testnet3');

  const DlcCoordinatorNetwork(this.coordinatorNetwork);

  final String coordinatorNetwork;
}

class DlcConfig {
  const DlcConfig({
    required this.baseUrl,
    required this.backupBaseUrl,
    required this.network,
    required this.partnerId,
    required this.partnerToken,
    required this.btcUsdTickerUrl,
    required this.defaultPremiumSatoshisPerContract,
    required this.showExpiredInstruments,
  });

  final String baseUrl;
  final String backupBaseUrl;
  final DlcCoordinatorNetwork network;
  final String partnerId;
  final String partnerToken;
  final String btcUsdTickerUrl;
  final int defaultPremiumSatoshisPerContract;
  final bool showExpiredInstruments;

  String get storageSuffix => network == DlcCoordinatorNetwork.testnet3
      ? 'testnet'
      : 'mainnet';

  String get instrumentsPath => showExpiredInstruments
      ? '/instruments'
      : '/instruments/non-expired';
}

DlcConfig _dlcConfigForEnv(Env env) {
  final network = switch (env) {
    Env.testnet => DlcCoordinatorNetwork.testnet3,
    Env.mainnet || Env.regtest => DlcCoordinatorNetwork.mainnet,
  };

  final baseUrl = switch (env) {
    Env.testnet => Secrets.kDlcCoordinatorTestUrl,
    Env.mainnet || Env.regtest => Secrets.kDlcCoordinatorUrl,
  };

  final backupBaseUrl = switch (env) {
    Env.testnet => Secrets.kDlcCoordinatorTestBackupUrl,
    Env.mainnet || Env.regtest => Secrets.kDlcCoordinatorBackupUrl,
  };

  return DlcConfig(
    baseUrl: baseUrl,
    backupBaseUrl: backupBaseUrl,
    network: network,
    partnerId: Secrets.kDlcCoordinatorPartnerId,
    partnerToken: Secrets.kDlcCoordinatorPartnerToken,
    btcUsdTickerUrl: Secrets.kDlcBtcUsdTickerUrl,
    defaultPremiumSatoshisPerContract:
        Secrets.kDlcDefaultPremiumSatoshisPerContract,
    showExpiredInstruments: Secrets.kDlcShowExpiredInstruments,
  );
}

final dlcConfigProvider = Provider<DlcConfig>((ref) {
  return _dlcConfigForEnv(ref.watch(envProvider));
});

final dlcDioProvider = Provider<Dio>((ref) {
  final config = ref.watch(dlcConfigProvider);
  final baseOptions = BaseOptions(
    baseUrl: config.baseUrl,
    connectTimeout: DlcCoordinatorHttp.defaultConnectTimeout,
    receiveTimeout: DlcCoordinatorHttp.defaultReceiveTimeout,
    sendTimeout: DlcCoordinatorHttp.defaultSendTimeout,
    headers: const {'Content-Type': 'application/json'},
    // Avoid Uvicorn/httptools issues with back-to-back POSTs on keep-alive.
    persistentConnection: false,
  );
  final dio = Dio(baseOptions);

  if (config.partnerToken.isNotEmpty) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['X-Partner-Token'] = config.partnerToken;
          handler.next(options);
        },
      ),
    );
  }

  if (config.backupBaseUrl.isNotEmpty) {
    dio.interceptors.add(
      DlcBackupInterceptor(
        backupBaseUrl: config.backupBaseUrl,
        dioOptions: baseOptions,
      ),
    );
  }

  return dio;
});
