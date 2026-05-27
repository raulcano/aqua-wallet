import 'package:aqua/features/dlc/config/dlc_config.dart';
import 'package:aqua/features/dlc/providers/dlc_provider.dart';
import 'package:aqua/features/dlc/utils/dlc_instrument_utils.dart';
import 'package:aqua/features/dlc/widgets/dlc_shell_widgets.dart';
import 'package:aqua/features/dlc/widgets/dlc_strike_orderbook_table.dart';
import 'package:aqua/features/shared/shared.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class DlcTradePanel extends HookConsumerWidget {
  const DlcTradePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dlcProvider);
    final notifier = ref.read(dlcProvider.notifier);
    final config = ref.watch(dlcConfigProvider);
    final quantityController = useTextEditingController(text: '0.01');
    final premiumController = useTextEditingController(
      text: config.defaultPremiumSatoshisPerContract.toString(),
    );

    final tradeInstruments = state.tradeInstruments;
    final selectedTemplate = state.templateInstrumentId;
    final premium = num.tryParse(premiumController.text.trim()) ?? 0;
    final quantity = num.tryParse(quantityController.text.trim()) ?? 0;
    final estimatedTotal = (premium * quantity).round();

    return DlcTabScrollView(
      onRefresh: notifier.refreshTradeData,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DlcSectionHeader(
                  icon: Icons.menu_book_outlined,
                  title: 'Orderbook',
                  trailing: null,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: state.optionRight,
                        items: const [
                          DropdownMenuItem(value: 'C', child: Text('Calls')),
                          DropdownMenuItem(value: 'P', child: Text('Puts')),
                        ],
                        onChanged: state.isLoadingTradeData
                            ? null
                            : (v) {
                                if (v != null) notifier.setOptionRight(v);
                              },
                        decoration: dlcInputDecoration(
                          context,
                          labelText: 'Option type',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: state.isLoadingTradeData
                          ? null
                          : notifier.refreshTradeData,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh strikes & books',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: tradeInstruments.any(
                    (i) => i.instrumentId == selectedTemplate,
                  )
                      ? selectedTemplate
                      : null,
                  items: tradeInstruments
                      .map(
                        (i) => DropdownMenuItem(
                          value: i.instrumentId,
                          child: Text(
                            i.instrumentId,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: notifier.setTemplateInstrumentId,
                  decoration: dlcInputDecoration(
                    context,
                    labelText: 'Instrument template',
                  ),
                ),
                if (state.btcUsdSpot != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'BTC-USD spot: \$${state.btcUsdSpot!.round()}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 12),
                DlcStrikeOrderbookTable(
                  snapshots: state.strikeOrderbooks,
                  selectedStrike: state.selectedStrike,
                  isLoading: state.isLoadingTradeData,
                  hasInstrument: selectedTemplate != null,
                  onStrikeTap: (snapshot) {
                    notifier.setSelectedStrike(snapshot.strike);
                    showDlcStrikeOrderbookDialog(
                      context,
                      snapshot: snapshot,
                      onDepthRowTap: ({
                        required side,
                        required quantity,
                        required premium,
                      }) {
                        notifier.applyCreateOrderFromDepth(
                          strike: snapshot.strike,
                          side: side,
                          quantity: quantity,
                          premiumSats: premium,
                        );
                        notifier.setCreateSide(side);
                        quantityController.text = quantity.toString();
                        premiumController.text = premium.round().toString();
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: DlcSectionHeader(
                        icon: Icons.add_chart,
                        title: 'Create order',
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline, size: 20),
                      onPressed: () => _showCreateInfoDialog(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (!state.isRegistered)
                  const Text(
                    'Activate your wallet before creating orders.',
                  )
                else ...[
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'buy', label: Text('Buy')),
                      ButtonSegment(value: 'sell', label: Text('Sell')),
                    ],
                    selected: {state.createSide},
                    onSelectionChanged: state.isTradingBlocked
                        ? null
                        : (s) => notifier.setCreateSide(s.first),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<num>(
                    value: state.suggestedStrikes.contains(state.selectedStrike)
                        ? state.selectedStrike
                        : null,
                    items: state.suggestedStrikes
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text('\$${s.round()}'),
                          ),
                        )
                        .toList(),
                    onChanged: notifier.setSelectedStrike,
                    decoration: dlcInputDecoration(
                      context,
                      labelText: 'Strike (USD)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: dlcInputDecoration(
                      context,
                      labelText: 'Number of contracts',
                      helperText:
                          '1 contract = 1 BTC. Minimum 0.01 contracts.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: premiumController,
                    keyboardType: TextInputType.number,
                    decoration: dlcInputDecoration(
                      context,
                      labelText: 'Premium per contract (option price)',
                      helperText:
                          'Satoshis per contract (informational; coordinator matches on book).',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Estimated total: $estimatedTotal sats',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: state.actionInProgress ||
                              state.isTradingBlocked ||
                              selectedTemplate == null ||
                              (dlcInstrumentHasStrikePlaceholder(
                                    selectedTemplate,
                                  ) &&
                                  state.selectedStrike == null)
                          ? null
                          : () => notifier.createOrder(quantity: quantity),
                      icon: const Icon(Icons.add),
                      label: const Text('Create'),
                    ),
                  ),
                  if (state.isTradingBlocked)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Trading blocked: fix coordinator environment hint on Overview.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

void _showCreateInfoDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Matching rules'),
      content: const Text(
        'Matching is exact quantity only — no partial fills. '
        '"Filled" reflects market state, not final DLC settlement. '
        'Premium on create is informational; the coordinator uses orderbook liquidity.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
