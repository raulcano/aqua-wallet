import 'package:aqua/data/provider/fiat_provider.dart';
import 'package:aqua/features/shared/shared.dart';

final moonBtcPriceProvider =
    NotifierProvider<MoonBtcPriceNotifier, void>(MoonBtcPriceNotifier.new);

class MoonBtcPriceNotifier extends Notifier<void> {
  @override
  void build() {}

  double get getUsdtTopUpFeePercentage => 0.0;

  FiatProvider getMoonUsdFiatProvider(Ref ref) => ref.read(fiatProvider);

  String getSatsToFiatDisplay(int satoshi) {
    // Synchronous fallback used by legacy UI call sites.
    // The async conversion still happens via fiatProvider in core flows.
    if (satoshi <= 0) {
      return '0.00';
    }
    return '0.00';
  }
}
