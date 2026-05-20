import 'package:aqua/features/dlc/config/dlc_config.dart';
import 'package:aqua/features/dlc/providers/dlc_provider.dart';
import 'package:aqua/features/dlc/widgets/dlc_option_payout_chart.dart';
import 'package:aqua/features/dlc/widgets/dlc_shell_widgets.dart';
import 'package:aqua/features/dlc/widgets/dlc_trading_colors.dart';
import 'package:aqua/features/shared/shared.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class DlcSimulatePanel extends HookConsumerWidget {
  const DlcSimulatePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dlcProvider);
    final notifier = ref.read(dlcProvider.notifier);
    final config = ref.watch(dlcConfigProvider);

    final side = useState('buy');
    final optionRight = useState('C');
    final role = useState('maker');
    final qtyController = useTextEditingController(text: '1');
    final strikeController = useTextEditingController(
      text: state.btcUsdSpot?.round().toString() ?? '70000',
    );
    final premiumController = useTextEditingController(
      text: config.defaultPremiumSatoshisPerContract.toString(),
    );
    final outcomeController = useTextEditingController(
      text: state.btcUsdSpot?.round().toString() ?? '',
    );
    final feeController = useTextEditingController(text: '0');

    useEffect(() {
      if (state.btcUsdSpot != null) {
        if (strikeController.text.isEmpty) {
          strikeController.text = state.btcUsdSpot!.round().toString();
        }
        if (outcomeController.text.isEmpty) {
          outcomeController.text = state.btcUsdSpot!.round().toString();
        }
      }
      return null;
    }, [state.btcUsdSpot]);

    final simulation = state.payoutSimulation;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DlcTabScrollView(
      onRefresh: () async {},
      children: [
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
                        icon: Icons.calculate_outlined,
                        title: 'Hypothetical scenario',
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline, size: 20),
                      onPressed: () => _showSimulateInfo(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SentenceLine(
                  children: [
                    const Text('I am the '),
                    _SegmentedPair(
                      left: 'buyer',
                      right: 'seller',
                      selectedLeft: side.value == 'buy',
                      onLeft: () => side.value = 'buy',
                      onRight: () => side.value = 'sell',
                    ),
                    const Text(' of '),
                    SizedBox(
                      width: 56,
                      child: TextField(
                        controller: qtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const Text(' contracts of '),
                    _SegmentedPair(
                      left: 'PUT',
                      right: 'CALL',
                      selectedLeft: optionRight.value == 'P',
                      onLeft: () => optionRight.value = 'P',
                      onRight: () => optionRight.value = 'C',
                    ),
                    const Text(' Bitcoin option.'),
                  ],
                ),
                const SizedBox(height: 12),
                _SentenceLine(
                  children: [
                    const Text('My order role: '),
                    _SegmentedPair(
                      left: 'Maker',
                      right: 'Taker',
                      selectedLeft: role.value == 'maker',
                      onLeft: () => role.value = 'maker',
                      onRight: () => role.value = 'taker',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SentenceLine(
                  children: [
                    const Text('Strike '),
                    _UsdField(controller: strikeController),
                    const Text(' · Premium '),
                    _SatsField(controller: premiumController),
                    const Text(' sats/contract.'),
                  ],
                ),
                const SizedBox(height: 12),
                _SentenceLine(
                  children: [
                    const Text('Outcome BTC/USD at expiry: '),
                    _UsdField(controller: outcomeController),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: feeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Network fees (sats)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: state.isSimulating
                        ? null
                        : () => _runSimulation(
                              context,
                              notifier: notifier,
                              side: side.value,
                              role: role.value,
                              optionRight: optionRight.value,
                              qtyController: qtyController,
                              strikeController: strikeController,
                              premiumController: premiumController,
                              outcomeController: outcomeController,
                              feeController: feeController,
                            ),
                    child: state.isSimulating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('SIMULATE'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (simulation != null) ...[
          const SizedBox(height: 12),
          if (simulation.hasChartData)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payout curve',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    DlcOptionPayoutChart(
                      result: simulation,
                      strikePrice: num.tryParse(strikeController.text.trim()),
                      outcomePrice:
                          num.tryParse(outcomeController.text.trim()),
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
                  Text(
                    'Simulation results',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (simulation.walletPnlSats != null)
                    _MetricRow(
                      label: 'PnL (rounded)',
                      value: '${simulation.walletPnlSats} sats',
                      color: DlcTradingColors.pnlColor(
                        simulation.walletPnlSats!,
                        isDark: isDark,
                      ),
                      emphasized: true,
                    ),
                  if (simulation.walletCollateralSats != null)
                    _MetricRow(
                      label: 'Posted collateral',
                      value: '${simulation.walletCollateralSats} sats',
                    ),
                  if (simulation.premiumPaidSats != null)
                    _MetricRow(
                      label: 'Premium paid upfront',
                      value: '${simulation.premiumPaidSats} sats',
                    ),
                  if (simulation.premiumReceivedSats != null)
                    _MetricRow(
                      label: 'Premium received upfront',
                      value: '${simulation.premiumReceivedSats} sats',
                    ),
                  if (simulation.roundedSettlementPayoutSats != null)
                    _MetricRow(
                      label: 'Rounded settlement payout',
                      value: '${simulation.roundedSettlementPayoutSats} sats',
                    ),
                  if (simulation.partnerFeeSats != null)
                    _MetricRow(
                      label: 'Partner fee',
                      value: '${simulation.partnerFeeSats} sats',
                    ),
                  if (simulation.roundingDeltaSats != null)
                    _MetricRow(
                      label: 'Rounding delta',
                      value: '${simulation.roundingDeltaSats} sats',
                    ),
                  if (simulation.canonicalPayoutSats != null)
                    _MetricRow(
                      label: 'Canonical payout',
                      value: '${simulation.canonicalPayoutSats} sats',
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

void _runSimulation(
  BuildContext context, {
  required DlcNotifier notifier,
  required String side,
  required String role,
  required String optionRight,
  required TextEditingController qtyController,
  required TextEditingController strikeController,
  required TextEditingController premiumController,
  required TextEditingController outcomeController,
  required TextEditingController feeController,
}) {
  final qty = num.tryParse(qtyController.text.trim());
  final strike = num.tryParse(strikeController.text.trim());
  final premium = num.tryParse(premiumController.text.trim());
  final outcome = num.tryParse(outcomeController.text.trim());
  final fee = num.tryParse(feeController.text.trim()) ?? 0;

  if (qty == null || qty <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enter a valid number of contracts')),
    );
    return;
  }
  if (strike == null || strike <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enter a valid strike (USD)')),
    );
    return;
  }
  if (premium == null || premium < 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enter a valid premium (sats)')),
    );
    return;
  }
  if (outcome == null || outcome <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enter a valid outcome price (USD)')),
    );
    return;
  }

  notifier.runPayoutSimulation(
    side: side,
    role: role,
    optionRight: optionRight,
    quantity: qty,
    strike: strike,
    premiumPerContractSats: premium,
    outcomePrice: outcome,
    networkFeeSats: fee,
  );
}

void _showSimulateInfo(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Simulate'),
      content: const Text(
        'No funds move and no order is placed. Results come from the '
        'coordinator payout simulation endpoint.',
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

class _SentenceLine extends StatelessWidget {
  const _SentenceLine({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 8,
      children: children,
    );
  }
}

class _SegmentedPair extends StatelessWidget {
  const _SegmentedPair({
    required this.left,
    required this.right,
    required this.selectedLeft,
    required this.onLeft,
    required this.onRight,
  });

  final String left;
  final String right;
  final bool selectedLeft;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      segments: [
        ButtonSegment(value: true, label: Text(left)),
        ButtonSegment(value: false, label: Text(right)),
      ],
      selected: {selectedLeft},
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onSelectionChanged: (s) {
        if (s.first) {
          onLeft();
        } else {
          onRight();
        }
      },
    );
  }
}

class _UsdField extends StatelessWidget {
  const _UsdField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          prefixText: '\$',
          isDense: true,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _SatsField extends StatelessWidget {
  const _SatsField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    this.color,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final Color? color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(
            value,
            style: (emphasized
                    ? Theme.of(context).textTheme.titleSmall
                    : Theme.of(context).textTheme.bodyMedium)
                ?.copyWith(
              color: color,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
