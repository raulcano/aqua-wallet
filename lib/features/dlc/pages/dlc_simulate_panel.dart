import 'package:aqua/features/dlc/config/dlc_config.dart';
import 'package:aqua/features/dlc/models/dlc_trade_models.dart';
import 'package:aqua/features/dlc/providers/dlc_provider.dart';
import 'package:aqua/features/dlc/services/dlc_api_exception.dart';
import 'package:aqua/features/dlc/services/dlc_repository.dart';
import 'package:aqua/features/dlc/widgets/dlc_option_payout_chart.dart';
import 'package:aqua/features/dlc/widgets/dlc_shell_widgets.dart';
import 'package:aqua/features/dlc/widgets/dlc_trading_colors.dart';
import 'package:aqua/features/shared/shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

const _kSimulateStrikeFallbackUsd = 70000;

class DlcSimulatePanel extends ConsumerStatefulWidget {
  const DlcSimulatePanel({
    super.key,
    required this.onLoadingChanged,
  });

  final ValueChanged<bool> onLoadingChanged;

  @override
  ConsumerState<DlcSimulatePanel> createState() => _DlcSimulatePanelState();
}

class _DlcSimulatePanelState extends ConsumerState<DlcSimulatePanel> {
  late final TextEditingController _contractsController;
  late final TextEditingController _strikeController;
  late final TextEditingController _premiumController;
  late final TextEditingController _expiryBtcUsdController;
  late final TextEditingController _networkFeeController;

  String _side = 'buy';
  String _optionRight = 'C';
  String _orderRole = 'maker';

  bool _loading = false;
  String? _error;
  DlcOptionPayoutSimulationResult? _result;

  int _chartStrikeUsd = 0;
  int _chartOutcomeUsd = 0;
  final _payoutChartKey = GlobalKey();

  num? _lastKnownSpot;

  @override
  void initState() {
    super.initState();
    final dlcState = ref.read(dlcProvider);
    final config = ref.read(dlcConfigProvider);
    final spot = dlcState.btcUsdSpot?.round();
    _lastKnownSpot = spot;

    _contractsController = TextEditingController(text: '1');
    _strikeController = TextEditingController(
      text: (spot ?? _kSimulateStrikeFallbackUsd).toString(),
    );
    _premiumController = TextEditingController(
      text: config.defaultPremiumSatoshisPerContract.toString(),
    );
    _expiryBtcUsdController = TextEditingController(
      text: spot?.toString() ?? '',
    );
    _networkFeeController = TextEditingController(text: '0');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshSimulateStrikeFromSpotIfNeeded();
    });
  }

  @override
  void dispose() {
    _contractsController.dispose();
    _strikeController.dispose();
    _premiumController.dispose();
    _expiryBtcUsdController.dispose();
    _networkFeeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dlcState = ref.watch(dlcProvider);
    final spot = dlcState.btcUsdSpot?.round();
    if (spot != null && spot != _lastKnownSpot) {
      _lastKnownSpot = spot;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _upgradeStrikeIfStillFallback(spot);
      });
    }

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
                _buildInputHeader(context),
                const SizedBox(height: 16),
                _SentenceWrap(
                  spacing: 6,
                  runSpacing: 12,
                  children: [
                    const Text('I am the'),
                    _SideSegmentedButton(
                      side: _side,
                      onChanged: (v) => setState(() => _side = v),
                    ),
                    const Text('of'),
                    _ContractsField(controller: _contractsController),
                    const Text('contracts of'),
                    _OptionTypeSegmentedButton(
                      optionRight: _optionRight,
                      onChanged: (v) => setState(() => _optionRight = v),
                    ),
                    const Text('Bitcoin option.'),
                  ],
                ),
                const SizedBox(height: 12),
                _SentenceWrap(
                  spacing: 6,
                  runSpacing: 12,
                  children: [
                    const Text('My order role:'),
                    _OrderRoleSegmentedButton(
                      role: _orderRole,
                      onChanged: (v) => setState(() => _orderRole = v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SentenceWrap(
                  spacing: 6,
                  runSpacing: 12,
                  children: [
                    const Text('The strike price is set at'),
                    _UsdField(
                      controller: _strikeController,
                      width: 112,
                      hint: 'strike',
                    ),
                    const Text('and the premium per contract is'),
                    _PremiumField(controller: _premiumController),
                    const Text('.'),
                  ],
                ),
                const SizedBox(height: 12),
                _SentenceWrap(
                  spacing: 6,
                  runSpacing: 12,
                  children: [
                    const Text(
                      'Check my profit or loss if the Bitcoin price at expiry is',
                    ),
                    _UsdField(
                      controller: _expiryBtcUsdController,
                      width: 120,
                      hint: 'BTC/USD',
                      digitsOnly: true,
                    ),
                    const Text('.'),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Estimated network fee you pay (on-chain)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _networkFeeController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: dlcInputDecoration(
                      context,
                      labelText: 'Network fees',
                      suffixText: 'sats',
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                          ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _runSimulation,
                    icon: const Icon(Icons.play_arrow_outlined),
                    label: const Text('SIMULATE'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_result != null) ...[
          const SizedBox(height: 12),
          Card(
            key: _payoutChartKey,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.show_chart_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _simulatePayoutCurveTitle(
                            side: _side,
                            optionRight: _optionRight,
                          ),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DlcOptionPayoutChart(
                    result: _result!,
                    strikeUsd: _chartStrikeUsd,
                    outcomeUsd: _chartOutcomeUsd,
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
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Simulation results',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._buildMetricRows(context, _result!, isDark: isDark),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInputHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.calculate_outlined, size: 18, color: scheme.primary),
        const SizedBox(width: 8),
        Text(
          'Simulate payout',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.info_outline),
          tooltip: 'About simulate payout',
          onPressed: () => _showAboutSimulateDialog(context),
        ),
      ],
    );
  }

  List<Widget> _buildMetricRows(
    BuildContext context,
    DlcOptionPayoutSimulationResult result, {
    required bool isDark,
  }) {
    final roundedPnl = result.roundedPnlSats;
    final networkFee = result.networkFeeSats ?? 0;
    final walletFee = result.walletFeeSats ?? result.partnerFeeSats ?? 0;
    final pnlColor = roundedPnl != null
        ? _simulationPnlValueColor(roundedPnl, isDark: isDark)
        : null;

    return [
      if (roundedPnl != null)
        _SimulateMetricRow(
          label: 'PnL (rounded)',
          value: _formatSimSatsSigned(roundedPnl.round()),
          emphasize: true,
          valueColor: pnlColor,
        ),
      if (roundedPnl != null)
        _SimulateMetricRow(
          label: 'PnL (no fees incl.)',
          value: _formatSimSatsSigned(
            (roundedPnl + networkFee + walletFee).round(),
          ),
          emphasize: true,
          valueColor: _simulationPnlValueColor(
            roundedPnl + networkFee + walletFee,
            isDark: isDark,
          ),
        ),
      if (result.walletCollateralSats != null)
        _SimulateMetricRow(
          label: 'Posted collateral',
          value: _formatSimSatsUnsigned(result.walletCollateralSats!.round()),
        ),
      if (result.premiumPaidSats != null)
        _SimulateMetricRow(
          label: 'Premium paid (upfront)',
          value: _formatSimSatsUnsigned(result.premiumPaidSats!.round()),
        ),
      if (result.premiumReceivedSats != null)
        _SimulateMetricRow(
          label: 'Premium received (upfront)',
          value: _formatSimSatsUnsigned(result.premiumReceivedSats!.round()),
        ),
      if (result.premiumEmbeddedInDlcSats != null)
        _SimulateMetricRow(
          label: 'Premium embedded in DLC',
          value:
              _formatSimSatsUnsigned(result.premiumEmbeddedInDlcSats!.round()),
        ),
      if (result.roundedSettlementPayoutSats != null)
        _SimulateMetricRow(
          label: 'Rounded settlement payout',
          value: _formatSimSatsUnsigned(
            result.roundedSettlementPayoutSats!.round(),
          ),
        ),
      if (result.canonicalPayoutSats != null)
        _SimulateMetricRow(
          label: 'Canonical payout',
          value: _formatSimSatsUnsigned(result.canonicalPayoutSats!.round()),
        ),
      if (result.networkFeeSats != null)
        _SimulateMetricRow(
          label: 'Network fees',
          value: _formatSimSatsUnsigned(result.networkFeeSats!.round()),
        ),
      if (result.walletFeeSats != null || result.partnerFeeSats != null)
        _SimulateMetricRow(
          label: 'Wallet/service fees',
          value: _formatSimSatsUnsigned(walletFee.round()),
        ),
      if (result.totalFeeSats != null)
        _SimulateMetricRow(
          label: 'Total fees',
          value: _formatSimSatsUnsigned(result.totalFeeSats!.round()),
        ),
      if (result.roundingDeltaSats != null)
        _SimulateMetricRow(
          label: 'Rounding delta',
          value: _formatSimSatsSigned(result.roundingDeltaSats!.round()),
          onInfoTap: () => _showRoundingDeltaDialog(context),
        ),
    ];
  }

  Future<void> _refreshSimulateStrikeFromSpotIfNeeded() async {
    final spot = ref.read(dlcProvider).btcUsdSpot;
    if (spot != null) {
      _upgradeStrikeIfStillFallback(spot.round());
      return;
    }
    try {
      final live =
          await ref.read(dlcRepositoryProvider).fetchBtcUsdSpotPrice();
      if (!mounted || live == null) {
        return;
      }
      _upgradeStrikeIfStillFallback(live.round());
    } catch (_) {
      // Silent background refresh.
    }
  }

  void _upgradeStrikeIfStillFallback(int spotUsd) {
    if (_strikeController.text.trim() ==
        _kSimulateStrikeFallbackUsd.toString()) {
      _strikeController.text = spotUsd.toString();
    }
  }

  Future<void> _runSimulation() async {
    FocusScope.of(context).unfocus();

    final qty = num.tryParse(_contractsController.text.trim());
    final strike = num.tryParse(_strikeController.text.trim());
    final premium = num.tryParse(_premiumController.text.trim());
    final outcome = num.tryParse(_expiryBtcUsdController.text.trim());
    final networkFee =
        num.tryParse(_networkFeeController.text.trim()) ?? 0;

    if (qty == null || qty <= 0) {
      _showSnackBar('Enter a valid number of contracts (> 0).');
      return;
    }
    if (strike == null || strike < 1) {
      _showSnackBar('Strike must be at least 1 (whole BTC/USD units).');
      return;
    }
    if (premium == null || premium < 0) {
      _showSnackBar(
        'Premium per contract must be a whole sats amount ≥ 0.',
      );
      return;
    }
    if (outcome == null || outcome < 0) {
      _showSnackBar('Expiry BTC/USD must be a whole number ≥ 0.');
      return;
    }
    if (networkFee < 0) {
      _showSnackBar('Network fee estimate cannot be negative.');
      return;
    }

    final strikeInt = strike.round();
    final outcomeInt = outcome.round();

    setState(() {
      _loading = true;
      _error = null;
    });
    widget.onLoadingChanged(true);

    try {
      final auth = ref.read(dlcProvider).auth;
      final req = DlcOptionPayoutSimulationRequest(
        side: _side,
        role: _orderRole,
        optionRight: _optionRight,
        numContracts: qty,
        strike: strikeInt,
        premiumPerContractSats: premium.round(),
        outcomePrice: outcomeInt,
        premiumPaidUpfront: true,
        networkFeeSats: networkFee.round(),
      );
      final result = await ref
          .read(dlcRepositoryProvider)
          .simulateOptionPayout(auth: auth, request: req);

      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
        _chartStrikeUsd = strikeInt;
        _chartOutcomeUsd = outcomeInt;
        _loading = false;
      });
      widget.onLoadingChanged(false);
      _scrollToPayoutChart();
    } on DlcApiException catch (e) {
      _handleSimulationError(e.message);
    } catch (e) {
      _handleSimulationError(e.toString());
    }
  }

  void _handleSimulationError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      _error = message;
      _result = null;
    });
    widget.onLoadingChanged(false);
    _showSnackBar(message);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _scrollToPayoutChart() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _payoutChartKey.currentContext;
      if (ctx == null) {
        return;
      }
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.08,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }
}

String _simulatePayoutCurveTitle({
  required String side,
  required String optionRight,
}) {
  final direction = side == 'buy' ? 'LONG' : 'SHORT';
  final right = optionRight == 'C' ? 'CALL' : 'PUT';
  return 'Payout for $direction $right';
}

String _formatSimSatsUnsigned(int sats) =>
    '${NumberFormat.decimalPattern().format(sats)} sats';

String _formatSimSatsSigned(int sats) {
  final fmt = NumberFormat.decimalPattern();
  if (sats == 0) {
    return '${fmt.format(0)} sats';
  }
  final sign = sats > 0 ? '+' : '';
  return '$sign${fmt.format(sats)} sats';
}

Color _simulationPnlValueColor(num value, {required bool isDark}) {
  if (value < 0) {
    return DlcTradingColors.sell;
  }
  if (value > 0) {
    return isDark ? DlcTradingColors.positivePnlDark : DlcTradingColors.buy;
  }
  return isDark ? Colors.white70 : Colors.black54;
}

void _showAboutSimulateDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('About simulate payout'),
      content: const Text(
        'Use this tool to explore what payout you could receive for the role, '
        'contracts, strike, premium, and BTC/USD outcome you enter.\n\n'
        'Tapping Simulate only runs a calculation against the coordinator — '
        'no funds move, no order is placed, and nothing is signed on-chain. '
        'It is a hypothetical exercise to help you understand settlement '
        'before you trade.',
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

void _showRoundingDeltaDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Rounding delta'),
      content: const Text(
        'The coordinator expresses DLC payouts as a stepped curve: oracle '
        'outcomes are grouped into intervals, and each interval has a fixed '
        'wallet payout (see the chart).\n\n'
        'Rounding delta is the gap between that stepped (rounded) payout and '
        'the smooth theoretical payout at the same BTC/USD price — in other '
        'words, how much interval rounding moves your settlement versus the '
        'ideal curve.\n\n'
        'Positive means the rounded payout is higher than the canonical value '
        'at this outcome; negative means it is lower.',
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

class _SentenceWrap extends StatelessWidget {
  const _SentenceWrap({
    required this.children,
    this.spacing = 4,
    this.runSpacing = 8,
  });

  final List<Widget> children;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: spacing,
      runSpacing: runSpacing,
      children: children,
    );
  }
}

class _SideSegmentedButton extends StatelessWidget {
  const _SideSegmentedButton({
    required this.side,
    required this.onChanged,
  });

  final String side;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'buy', label: Text('buyer')),
        ButtonSegment(value: 'sell', label: Text('seller')),
      ],
      selected: {side},
      showSelectedIcon: false,
      style: _compactSegmentStyle(),
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _OptionTypeSegmentedButton extends StatelessWidget {
  const _OptionTypeSegmentedButton({
    required this.optionRight,
    required this.onChanged,
  });

  final String optionRight;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'P', label: Text('PUT')),
        ButtonSegment(value: 'C', label: Text('CALL')),
      ],
      selected: {optionRight},
      showSelectedIcon: false,
      style: _compactSegmentStyle(),
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _OrderRoleSegmentedButton extends StatelessWidget {
  const _OrderRoleSegmentedButton({
    required this.role,
    required this.onChanged,
  });

  final String role;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'maker', label: Text('Maker')),
        ButtonSegment(value: 'taker', label: Text('Taker')),
      ],
      selected: {role},
      showSelectedIcon: false,
      style: _compactSegmentStyle(),
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

ButtonStyle _compactSegmentStyle() {
  return const ButtonStyle(
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    minimumSize: WidgetStatePropertyAll(Size(0, 34)),
  );
}

class _ContractsField extends StatelessWidget {
  const _ContractsField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: dlcInputDecoration(context, hintText: 'qty'),
      ),
    );
  }
}

class _PremiumField extends StatelessWidget {
  const _PremiumField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: dlcInputDecoration(
          context,
          hintText: 'premium',
          suffixText: 'sats',
        ),
      ),
    );
  }
}

class _UsdField extends StatelessWidget {
  const _UsdField({
    required this.controller,
    required this.width,
    required this.hint,
    this.digitsOnly = false,
  });

  final TextEditingController controller;
  final double width;
  final String hint;
  final bool digitsOnly;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: digitsOnly
            ? TextInputType.number
            : const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: digitsOnly
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        decoration: dlcInputDecoration(
          context,
          hintText: hint,
          suffixText: 'USD',
        ),
      ),
    );
  }
}

class _SimulateMetricRow extends StatelessWidget {
  const _SimulateMetricRow({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.valueColor,
    this.onInfoTap,
  });

  final String label;
  final String value;
  final bool emphasize;
  final Color? valueColor;
  final VoidCallback? onInfoTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface,
                        ),
                  ),
                ),
                if (onInfoTap != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.info_outline,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                    onPressed: onInfoTap,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            textAlign: TextAlign.right,
            style: (emphasize
                    ? Theme.of(context).textTheme.bodyMedium
                    : Theme.of(context).textTheme.bodyMedium)
                ?.copyWith(
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              color: valueColor ?? (emphasize ? scheme.primary : null),
            ),
          ),
        ],
      ),
    );
  }
}
