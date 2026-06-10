import 'package:aqua/common/providers/launch_url_provider.dart';
import 'package:aqua/features/dlc/config/dlc_config.dart';
import 'package:aqua/features/dlc/models/dlc_models.dart';
import 'package:aqua/features/dlc/pages/dlc_explorer_screen.dart';
import 'package:aqua/features/dlc/providers/dlc_provider.dart';
import 'package:aqua/features/dlc/utils/dlc_explorer_utils.dart';
import 'package:aqua/features/dlc/utils/dlc_order_utils.dart';
import 'package:aqua/features/dlc/widgets/dlc_shell_widgets.dart';
import 'package:aqua/features/dlc/widgets/dlc_trading_colors.dart';
import 'package:aqua/features/shared/shared.dart';

class DlcOrdersPanel extends ConsumerWidget {
  const DlcOrdersPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dlcProvider);
    final notifier = ref.read(dlcProvider.notifier);

    if (!state.isRegistered) {
      return DlcTabScrollView(
        onRefresh: notifier.refreshOrdersTab,
        children: const [
          Text('Activate your wallet on Overview to view orders.'),
        ],
      );
    }

    final open =
        state.orders.where(orderShowsInOpenSection).toList(growable: false);
    final live =
        state.orders.where(orderShowsInLiveSection).toList(growable: false);
    final closed =
        state.orders.where(isDlcClosedOrder).toList(growable: false);

    return DlcTabScrollView(
      onRefresh: notifier.refreshOrdersTab,
      children: [
        _OrderGroupSection(
          title: 'Open orders',
          subtitle: 'Waiting for a match',
          orders: open,
          showCancel: true,
          showFundingExplorerLink: false,
          showSettlementExplorerLinks: false,
          notifier: notifier,
          actionInProgress: state.processingOrder,
        ),
        const SizedBox(height: 12),
        _OrderGroupSection(
          title: 'Live orders',
          subtitle: 'Accept, fill, or settlement in progress',
          orders: live,
          showCancel: false,
          showFundingExplorerLink: true,
          showSettlementExplorerLinks: false,
          notifier: notifier,
          actionInProgress: state.processingOrder,
        ),
        const SizedBox(height: 12),
        _OrderGroupSection(
          title: 'Closed / settled',
          subtitle: 'Completed DLCs',
          orders: closed,
          showCancel: false,
          showFundingExplorerLink: false,
          showSettlementExplorerLinks: true,
          notifier: notifier,
          actionInProgress: state.processingOrder,
        ),
      ],
    );
  }
}

class _OrderGroupSection extends StatelessWidget {
  const _OrderGroupSection({
    required this.title,
    required this.subtitle,
    required this.orders,
    required this.showCancel,
    required this.showFundingExplorerLink,
    required this.showSettlementExplorerLinks,
    required this.notifier,
    required this.actionInProgress,
  });

  final String title;
  final String subtitle;
  final List<DlcOrder> orders;
  final bool showCancel;
  final bool showFundingExplorerLink;
  final bool showSettlementExplorerLinks;
  final DlcNotifier notifier;
  final bool actionInProgress;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            if (orders.isEmpty)
              const ListTile(
                dense: true,
                title: Text('No orders in this section'),
              )
            else
              ...orders.map(
                (order) => _CompactOrderEntry(
                  order: order,
                  showCancel: showCancel,
                  showFundingExplorerLink: showFundingExplorerLink,
                  showSettlementExplorerLinks: showSettlementExplorerLinks,
                  notifier: notifier,
                  actionInProgress: actionInProgress,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CompactOrderEntry extends ConsumerWidget {
  const _CompactOrderEntry({
    required this.order,
    required this.showCancel,
    required this.showFundingExplorerLink,
    required this.showSettlementExplorerLinks,
    required this.notifier,
    required this.actionInProgress,
  });

  final DlcOrder order;
  final bool showCancel;
  final bool showFundingExplorerLink;
  final bool showSettlementExplorerLinks;
  final DlcNotifier notifier;
  final bool actionInProgress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = resolveOrderInFlightPhase(order);
    final sideColor = DlcTradingColors.sideColor(order.side, isDark: false);
    final fundingTxid =
        showFundingExplorerLink ? liveOrderFundingTxid(order) : null;
    final settlementLinks = showSettlementExplorerLinks
        ? orderSettlementExplorerLinks(order)
        : const <({String label, String txid})>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.instrumentId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${order.side.toUpperCase()} · '
                    'You: ${formatDlcOrderRole(order)} · '
                    '${formatOrderStatusLine(order)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: sideColor,
                        ),
                  ),
                ],
              ),
            ),
            if (fundingTxid != null)
              _MempoolTxIconButton(
                txid: fundingTxid,
                tooltip: 'View funding transaction',
              ),
            for (final link in settlementLinks)
              _MempoolTxIconButton(
                txid: link.txid,
                tooltip: 'View ${link.label.toLowerCase()}',
              ),
            if (phase != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.hourglass_top,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () => _showInFlightDialog(context, phase, order),
              ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.info_outline, size: 20),
              onPressed: () => _showOrderInfoDialog(context, ref, order),
            ),
            if (showCancel && order.isOpen)
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Cancel order',
                onPressed: actionInProgress
                    ? null
                    : () => _confirmCancel(context, order),
                icon: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, DlcOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel order?'),
        content: const Text(
          'This removes your order from the coordinator orderbook.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await notifier.cancelOrder(order.orderId);
    }
  }
}

class _MempoolTxIconButton extends ConsumerWidget {
  const _MempoolTxIconButton({
    required this.txid,
    required this.tooltip,
  });

  final String txid;
  final String tooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTestnet = ref.watch(dlcConfigProvider).network ==
        DlcCoordinatorNetwork.testnet3;
    final url = dlcMempoolTxUrl(txid: txid, isTestnet: isTestnet);

    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: tooltip,
      icon: Icon(
        Icons.open_in_new,
        size: 20,
        color: Theme.of(context).colorScheme.primary,
      ),
      onPressed: () => ref.read(launchUrlProvider.notifier).launchUrl(url),
    );
  }
}

void _showInFlightDialog(
  BuildContext context,
  DlcOrderInFlightPhase phase,
  DlcOrder order,
) {
  final (title, body) = switch (phase) {
    DlcOrderInFlightPhase.creatingOnCoordinator => (
        'Opening order',
        'Submitting your order to the coordinator.',
      ),
    DlcOrderInFlightPhase.takerSigningAccept => (
        'Signing acceptance',
        'Background signing is in progress. You can keep using the app.',
      ),
    DlcOrderInFlightPhase.matchedAwaitingTakerAccept => (
        'Match in progress',
        'Waiting for accept flow to complete.',
      ),
    DlcOrderInFlightPhase.makerSigningDlc => (
        'Maker signing',
        'DLC CET signing may take a minute. The app polls every 15s.',
      ),
    DlcOrderInFlightPhase.fundingBroadcastPending => (
        'Funding broadcast pending',
        order.lastErrorReason == 'funding_broadcast_failed'
            ? 'Protocol signing is complete, but funding broadcast failed. '
                'The app keeps polling until funding is broadcast.'
            : 'Protocol signing is complete. Waiting for the coordinator to '
                'broadcast the funding transaction.',
      ),
  };
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

void _showOrderInfoDialog(
  BuildContext context,
  WidgetRef ref,
  DlcOrder order,
) {
  final fundingTxid = liveOrderFundingTxid(order);
  final settlementLinks = orderSettlementExplorerLinks(order);
  final walletToken = ref.read(dlcProvider).auth?.walletToken;
  final config = ref.read(dlcConfigProvider);
  final showDlcExplorer = canOpenDlcExplorer(
    order: order,
    walletToken: walletToken,
  );

  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Order details'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _InfoRow('Instrument', order.instrumentId),
            _InfoRow('Side', order.side),
            _InfoRow('Role', formatDlcOrderRole(order)),
            _InfoRow('Contracts', order.quantity.toString()),
            _InfoRow('Order status', order.status),
            if (order.dlcStatus != null)
              _InfoRow('DLC status', formatDlcStatusLabel(order)),
            if (order.lastErrorReason != null)
              _InfoRow('Last error', order.lastErrorReason!),
            if (fundingTxid != null)
              _InfoLinkRow(
                ref: ref,
                label: 'Funding TX',
                txid: fundingTxid,
              ),
            for (final link in settlementLinks)
              _InfoLinkRow(
                ref: ref,
                label: link.label,
                txid: link.txid,
              ),
            if (order.dlcId != null && order.dlcId!.isNotEmpty)
              _InfoRow('DLC ID', order.dlcId!, selectable: true),
            if (order.currentExecution != null &&
                order.currentExecution!.tradeId.isNotEmpty)
              _InfoRow(
                'Trade ID',
                order.currentExecution!.tradeId,
                selectable: true,
              ),
            _InfoRow('Order ID', order.orderId, selectable: true),
            if (order.executions.length > 1) ...[
              const SizedBox(height: 4),
              _ExecutionHistoryBlock(order: order),
            ],
          ],
        ),
      ),
      actions: [
        if (showDlcExplorer)
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              openDlcExplorerScreen(
                context,
                dashboardUrl: config.explorerDashboardUrl,
                walletToken: walletToken!,
                dlcId: order.dlcId!,
              );
            },
            child: const Text('DLC Explorer'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _InfoLinkRow extends StatelessWidget {
  const _InfoLinkRow({
    required this.ref,
    required this.label,
    required this.txid,
  });

  final WidgetRef ref;
  final String label;
  final String txid;

  @override
  Widget build(BuildContext context) {
    final isTestnet = ref.watch(dlcConfigProvider).network ==
        DlcCoordinatorNetwork.testnet3;
    final url = dlcMempoolTxUrl(txid: txid, isTestnet: isTestnet);
    final linkColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => ref.read(launchUrlProvider.notifier).launchUrl(url),
            child: Text(
              'see here',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: linkColor,
                    decoration: TextDecoration.underline,
                    decorationColor: linkColor,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExecutionHistoryBlock extends StatelessWidget {
  const _ExecutionHistoryBlock({required this.order});

  final DlcOrder order;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Execution history', style: textTheme.labelSmall),
        const SizedBox(height: 4),
        for (var i = 0; i < order.executions.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              _formatExecutionLine(i + 1, order.executions[i]),
              style: textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  static String _formatExecutionLine(int index, DlcOrderExecution execution) {
    final pieces = <String>[
      '#$index',
      execution.role == DlcExecutionRole.maker ? 'maker' : 'taker',
      execution.status,
      if (execution.dlcStatus != null) 'dlc=${execution.dlcStatus}',
      if (execution.tradeId.isNotEmpty)
        'trade=${_shortHash(execution.tradeId)}',
    ];
    final base = pieces.join(' · ');
    final reason = execution.lastErrorReason;
    if (reason != null && reason.isNotEmpty) {
      return '$base — $reason';
    }
    return base;
  }

  static String _shortHash(String value) {
    if (value.length <= 12) return value;
    return '${value.substring(0, 6)}…${value.substring(value.length - 4)}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.selectable = false});

  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          selectable
              ? SelectableText(value)
              : Text(value, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
