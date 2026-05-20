import 'package:aqua/features/dlc/models/dlc_models.dart';
import 'package:aqua/features/dlc/providers/dlc_provider.dart';
import 'package:aqua/features/dlc/widgets/dlc_shell_widgets.dart';
import 'package:aqua/features/dlc/widgets/dlc_trading_colors.dart';
import 'package:aqua/features/shared/shared.dart';

class DlcOverviewPanel extends ConsumerWidget {
  const DlcOverviewPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dlcProvider);
    final notifier = ref.read(dlcProvider.notifier);
    final counts = state.orderCounts;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DlcTabScrollView(
      onRefresh: notifier.refreshOverviewTab,
      children: [
        if (state.coordinatorHint != null) ...[
          _CoordinatorHintCard(message: state.coordinatorHint!),
          const SizedBox(height: 12),
        ],
        _ActivationCard(state: state, notifier: notifier),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryStatCard(
                title: 'Wallet PnL',
                value: state.isRegistered && state.walletPnlSats != null
                    ? '${state.walletPnlSats! >= 0 ? '+' : ''}${state.walletPnlSats} sats'
                    : state.isRegistered
                        ? '—'
                        : '—',
                subtitle: state.isRegistered
                    ? 'At current BTC-USD spot (estimated)'
                    : 'Activate to estimate',
                valueColor: state.walletPnlSats != null
                    ? DlcTradingColors.pnlColor(
                        state.walletPnlSats!,
                        isDark: isDark,
                      )
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryStatCard(
                title: 'Open / Live / Closed',
                value: state.isRegistered
                    ? '${counts.open} / ${counts.live} / ${counts.closed}'
                    : '— / — / —',
                subtitle: 'Order sections',
                valueColor: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (state.balances != null)
          _BalanceSplitCard(balances: state.balances!),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DlcSectionHeader(
                  icon: Icons.shield_outlined,
                  title: 'Risk disclosure',
                ),
                const SizedBox(height: 8),
                Text(
                  'DLC options lock collateral on-chain. Only xpubs and signatures '
                  'leave this device; your seed stays local. Coordinator balances '
                  'reflect UTXOs you sync — not your full wallet balance.',
                  style: Theme.of(context).textTheme.bodySmall,
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
                const DlcSectionHeader(
                  icon: Icons.history,
                  title: 'Recent DLC events',
                ),
                const SizedBox(height: 8),
                Text(
                  'No dedicated events endpoint exposed by the coordinator API yet.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        if (state.isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

class _CoordinatorHintCard extends StatelessWidget {
  const _CoordinatorHintCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.error),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivationCard extends StatelessWidget {
  const _ActivationCard({required this.state, required this.notifier});

  final DlcState state;
  final DlcNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final registered = state.isRegistered;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DlcSectionHeader(
              icon: registered ? Icons.verified_outlined : Icons.account_balance_wallet_outlined,
              title: registered ? 'Wallet registered' : 'Activate wallet',
            ),
            const SizedBox(height: 8),
            if (registered && state.auth != null) ...[
              Text(
                state.activeWalletName ?? state.auth!.walletLabel,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Coordinator ID: ${state.auth!.walletId}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (state.auth!.walletLabel.isNotEmpty &&
                  state.activeWalletName != null &&
                  state.auth!.walletLabel != state.activeWalletName)
                Text(
                  'Label on coordinator: ${state.auth!.walletLabel}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ] else ...[
              Text(
                state.activeWalletName == null
                    ? 'Open Marketplace from a wallet to use DLC options.'
                    : 'Link ${state.activeWalletName} to the coordinator to sync '
                        'balances, orders, and UTXOs for this wallet only.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            if (state.activeWalletId != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: state.actionInProgress || state.isLoading
                      ? null
                      : () {
                          if (registered) {
                            notifier.refreshOverviewTab();
                          } else {
                            notifier.registerActiveWallet();
                          }
                        },
                  icon: Icon(registered ? Icons.sync : Icons.link),
                  label: Text(registered ? 'Re-sync wallet' : 'Activate'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStatCard extends StatelessWidget {
  const _SummaryStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.valueColor,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelMedium),
              const Spacer(),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: valueColor,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceSplitCard extends StatelessWidget {
  const _BalanceSplitCard({required this.balances});

  final DlcWalletSyncResult balances;

  @override
  Widget build(BuildContext context) {
    final total = balances.totalBalanceSat;
    final available = balances.availableBalanceSat;
    final reserved = balances.reservedBalanceSat;
    final ratio = total > 0 ? available / total : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DlcSectionHeader(
              icon: Icons.pie_chart_outline,
              title: 'Balance split',
            ),
            const SizedBox(height: 8),
            Text(
              'Coordinator-visible balances. Sync UTXOs after funding or settlement.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Available: $available sats · Reserved: $reserved sats',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (balances.warning != null) ...[
              const SizedBox(height: 8),
              Text(
                balances.warning!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
