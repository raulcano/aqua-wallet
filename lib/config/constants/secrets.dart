import 'package:envied/envied.dart';

part 'secrets.g.dart';

@Envied(path: '.env', obfuscate: true)
abstract class Secrets {
  @EnviedField(varName: 'MELD_PROD_PUBLIC_KEY')
  static final String kMeldProdPublicKey = _Secrets.kMeldProdPublicKey;
  @EnviedField(varName: 'MELD_SANDBOX_PUBLIC_KEY')
  static final String kMeldSandboxPublicKey = _Secrets.kMeldSandboxPublicKey;

  @EnviedField(varName: 'DLC_COORDINATOR_URL', defaultValue: 'http://localhost:8000')
  static final String kDlcCoordinatorUrl = _Secrets.kDlcCoordinatorUrl;

  @EnviedField(varName: 'DLC_COORDINATOR_BACKUP_URL', defaultValue: '')
  static final String kDlcCoordinatorBackupUrl = _Secrets.kDlcCoordinatorBackupUrl;

  @EnviedField(
    varName: 'DLC_COORDINATOR_TEST_URL',
    defaultValue: 'http://localhost:8000',
  )
  static final String kDlcCoordinatorTestUrl = _Secrets.kDlcCoordinatorTestUrl;

  @EnviedField(varName: 'DLC_COORDINATOR_TEST_BACKUP_URL', defaultValue: '')
  static final String kDlcCoordinatorTestBackupUrl =
      _Secrets.kDlcCoordinatorTestBackupUrl;

  @EnviedField(varName: 'DLC_COORDINATOR_PARTNER_ID', defaultValue: '')
  static final String kDlcCoordinatorPartnerId = _Secrets.kDlcCoordinatorPartnerId;

  @EnviedField(varName: 'DLC_COORDINATOR_PARTNER_TOKEN', defaultValue: '')
  static final String kDlcCoordinatorPartnerToken =
      _Secrets.kDlcCoordinatorPartnerToken;

  @EnviedField(
    varName: 'DLC_BTC_USD_TICKER_URL',
    defaultValue: 'https://api.coinbase.com/v2/prices/BTC-USD/spot',
  )
  static final String kDlcBtcUsdTickerUrl = _Secrets.kDlcBtcUsdTickerUrl;

  @EnviedField(
    varName: 'DLC_DEFAULT_PREMIUM_SATOSHIS_PER_CONTRACT',
    defaultValue: 5030000,
  )
  static final int kDlcDefaultPremiumSatoshisPerContract =
      _Secrets.kDlcDefaultPremiumSatoshisPerContract;

  @EnviedField(varName: 'DLC_SHOW_EXPIRED_INSTRUMENTS', defaultValue: false)
  static final bool kDlcShowExpiredInstruments = _Secrets.kDlcShowExpiredInstruments;
}
