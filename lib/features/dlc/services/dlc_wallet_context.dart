import 'package:aqua/data/models/gdk_models.dart';
import 'package:aqua/data/provider/bitcoin_provider.dart';
import 'package:aqua/data/provider/network_frontend.dart';
import 'package:aqua/features/dlc/config/dlc_config.dart';
import 'package:aqua/features/settings/manage_assets/models/assets.dart';
import 'package:aqua/features/shared/shared.dart';
import 'package:aqua/features/wallet/utils/derivation_path_utils.dart';
import 'package:aqua/features/wallet/wallet.dart';

/// Resolves the active on-chain Bitcoin subaccount and UTXOs for DLC coordinator ops.
class DlcWalletContextResolver {
  DlcWalletContextResolver(this._ref);

  final Ref _ref;

  Future<DlcBitcoinWalletContext> resolve({
    required String walletId,
    required String walletLabel,
    required String mnemonic,
  }) async {
    final config = _ref.read(dlcConfigProvider);
    final subaccount = _findBitcoinSubaccount(config.network);
    if (subaccount == null) {
      throw StateError(
        'No native segwit Bitcoin subaccount found for DLC trading',
      );
    }

    final userPath = subaccount.subaccount.userPath;
    if (userPath == null || userPath.length < 3) {
      throw StateError('Bitcoin subaccount is missing a derivation path');
    }

    final utxos = await _loadBitcoinUtxos();
    return DlcBitcoinWalletContext(
      walletOriginId: walletId,
      walletLabel: walletLabel,
      mnemonic: mnemonic,
      subaccount: subaccount,
      accountUserPath: userPath,
      coordinatorXpub: subaccount.exportData,
      utxos: utxos,
    );
  }

  Subaccount? _findBitcoinSubaccount(DlcCoordinatorNetwork network) {
    final expectedCoinType =
        network == DlcCoordinatorNetwork.testnet3 ? 1 : 0;
    final subaccounts =
        _ref.read(subaccountsProvider).value?.subaccounts ?? const [];

    bool isNativeSegwitBitcoin(Subaccount s) =>
        s.networkType == NetworkType.bitcoin &&
        s.subaccount.type == GdkSubaccountTypeEnum.type_p2wpkh &&
        s.subaccount.userPath != null &&
        s.subaccount.userPath!.length >= 3;

    final exactMatch = subaccounts.firstWhereOrNull(
      (s) =>
          isNativeSegwitBitcoin(s) &&
          DerivationPathUtils.unhardenIndex(s.subaccount.userPath![1]) ==
              expectedCoinType,
    );
    if (exactMatch != null) {
      return exactMatch;
    }

    return subaccounts.firstWhereOrNull(isNativeSegwitBitcoin);
  }

  Future<List<GdkUnspentOutputs>> _loadBitcoinUtxos() async {
    final utxoReply = await _ref.read(bitcoinProvider).getUnspentOutputs();
    final btcUtxos = utxoReply?.unsentOutputs?[AssetIds.btc] ?? const [];
    return btcUtxos
        .where((u) => u.isSpent != true && (u.satoshi ?? 0) > 0)
        .toList();
  }
}

class DlcBitcoinWalletContext {
  const DlcBitcoinWalletContext({
    required this.walletOriginId,
    required this.walletLabel,
    required this.mnemonic,
    required this.subaccount,
    required this.accountUserPath,
    required this.coordinatorXpub,
    required this.utxos,
  });

  final String walletOriginId;
  final String walletLabel;
  final String mnemonic;
  final Subaccount subaccount;
  final List<int> accountUserPath;
  final String coordinatorXpub;
  final List<GdkUnspentOutputs> utxos;
}

final dlcWalletContextResolverProvider = Provider<DlcWalletContextResolver>(
  (ref) => DlcWalletContextResolver(ref),
);
