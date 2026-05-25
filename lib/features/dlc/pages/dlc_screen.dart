import 'package:aqua/config/config.dart';
import 'package:aqua/features/dlc/pages/dlc_orders_panel.dart';
import 'package:aqua/features/dlc/pages/dlc_overview_panel.dart';
import 'package:aqua/features/dlc/pages/dlc_simulate_panel.dart';
import 'package:aqua/features/dlc/pages/dlc_trade_panel.dart';
import 'package:aqua/features/dlc/providers/dlc_provider.dart';
import 'package:aqua/features/dlc/widgets/dlc_shell_widgets.dart';
import 'package:aqua/features/shared/shared.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class DlcScreen extends HookConsumerWidget {
  const DlcScreen({super.key});

  static const routeName = '/dlc';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dlcProvider);
    final notifier = ref.read(dlcProvider.notifier);
    final simulateLoading = useState(false);

    return Scaffold(
      appBar: AquaAppBar(
        showBackButton: true,
        showActionButton: false,
        title: 'Bitcoin options',
        backgroundColor: Theme.of(context).colors.appBarBackgroundColor,
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DlcColdPayAttribution(),
              DlcTopNav(
                selectedIndex: state.selectedTabIndex,
                onSelect: notifier.setTab,
                isDisabled: state.isLoading ||
                    simulateLoading.value ||
                    state.actionInProgress,
              ),
              if (state.errorMessage != null)
                DlcMessageBanner(
                  message: state.errorMessage!,
                  isError: true,
                  onDismiss: notifier.clearTransientMessages,
                ),
              if (state.infoMessage != null)
                DlcMessageBanner(
                  message: state.infoMessage!,
                  isError: false,
                  onDismiss: notifier.clearTransientMessages,
                ),
              if (state.activationInProgress)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Linking wallet to coordinator. You can keep using the app.',
                        ),
                      ),
                    ],
                  ),
                ),
              if (state.walletSyncInProgress)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Syncing wallet UTXOs with coordinator. You can keep using the app.',
                        ),
                      ),
                    ],
                  ),
                ),
              if (state.negotiationInProgress)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'DLC signing in progress. You can keep using the app.',
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _DlcTabBody(
                  selectedIndex: state.selectedTabIndex,
                  onSimulateLoadingChanged: (loading) {
                    simulateLoading.value = loading;
                  },
                ),
              ),
            ],
          ),
          DlcActionLoadingOverlay(
            visible: dlcShellOverlayVisible(
              state,
              simulateLoading: simulateLoading.value,
            ),
          ),
        ],
      ),
    );
  }
}

class _DlcTabBody extends StatelessWidget {
  const _DlcTabBody({
    required this.selectedIndex,
    required this.onSimulateLoadingChanged,
  });

  final int selectedIndex;
  final ValueChanged<bool> onSimulateLoadingChanged;

  @override
  Widget build(BuildContext context) {
    return switch (selectedIndex) {
      0 => const DlcOverviewPanel(),
      1 => const DlcTradePanel(),
      2 => const DlcOrdersPanel(),
      3 => DlcSimulatePanel(onLoadingChanged: onSimulateLoadingChanged),
      _ => const DlcOverviewPanel(),
    };
  }
}
