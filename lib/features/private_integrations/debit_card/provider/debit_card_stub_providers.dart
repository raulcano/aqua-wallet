import 'package:aqua/features/account/models/api_models.dart';
import 'package:aqua/features/shared/shared.dart';

class TopUpInputStateSimple {
  const TopUpInputStateSimple({
    this.amountInUsd = '0',
  });

  final String amountInUsd;
}

class TopUpInvoiceSimple {
  const TopUpInvoiceSimple({this.id});

  final String? id;
}

class TopUpInvoiceStateSimple {
  const TopUpInvoiceStateSimple({this.invoice});

  final TopUpInvoiceSimple? invoice;
}

final moonCardsProvider = FutureProvider.autoDispose<List<CardResponse>>(
  (ref) async => const <CardResponse>[],
);

final topUpInputStateProvider =
    StateProvider.autoDispose<AsyncValue<TopUpInputStateSimple>>(
  (ref) => const AsyncValue.data(TopUpInputStateSimple()),
);

final topUpInvoiceProvider =
    FutureProvider.autoDispose<TopUpInvoiceStateSimple>(
  (ref) async => const TopUpInvoiceStateSimple(),
);
