import 'package:aqua/features/dlc/models/dlc_models.dart';
import 'package:aqua/features/dlc/providers/dlc_provider.dart';
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
          notifier: notifier,
          actionInProgress: state.processingOrder,
        ),
        const SizedBox(height: 12),
        _OrderGroupSection(
          title: 'Live orders',
          subtitle: 'Accept, fill, or settlement in progress',
          orders: live,
          showCancel: false,
          notifier: notifier,
          actionInProgress: state.processingOrder,
        ),
        const SizedBox(height: 12),
        _OrderGroupSection(
          title: 'Closed / settled',
          subtitle: 'Completed DLCs',
          orders: closed,
          showCancel: false,
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
    required this.notifier,
    required this.actionInProgress,
  });

  final String title;
  final String subtitle;
  final List<DlcOrder> orders;
  final bool showCancel;
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

class _CompactOrderEntry extends StatelessWidget {
  const _CompactOrderEntry({
    required this.order,
    required this.showCancel,
    required this.notifier,
    required this.actionInProgress,
  });

  final DlcOrder order;
  final bool showCancel;
  final DlcNotifier notifier;
  final bool actionInProgress;

  @override
  Widget build(BuildContext context) {
    final phase = resolveOrderInFlightPhase(order);
    final sideColor = DlcTradingColors.sideColor(order.side, isDark: false);

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
                    '${order.side.toUpperCase()} · ${formatDlcOrderRole(order)} · ${order.status}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: sideColor,
                        ),
                  ),
                ],
              ),
            ),
            if (phase != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.hourglass_top,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () => _showInFlightDialog(context, phase),
              ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.info_outline, size: 20),
              onPressed: () => _showOrderInfoDialog(context, order),
            ),
            if (showCancel && order.isOpen)
              TextButton(
                onPressed: actionInProgress
                    ? null
                    : () => _confirmCancel(context, order),
                child: const Text('Cancel'),
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

void _showInFlightDialog(BuildContext context, DlcOrderInFlightPhase phase) {
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

void _showOrderInfoDialog(BuildContext context, DlcOrder order) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
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
              _InfoRow('DLC status', order.dlcStatus!),
            _InfoRow('Order ID', order.orderId, selectable: true),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
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
