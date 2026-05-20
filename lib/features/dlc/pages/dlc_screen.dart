import 'package:aqua/config/config.dart';
import 'package:aqua/features/dlc/pages/dlc_orders_panel.dart';
import 'package:aqua/features/dlc/pages/dlc_overview_panel.dart';
import 'package:aqua/features/dlc/pages/dlc_simulate_panel.dart';
import 'package:aqua/features/dlc/pages/dlc_trade_panel.dart';
import 'package:aqua/features/dlc/providers/dlc_provider.dart';
import 'package:aqua/features/dlc/widgets/dlc_shell_widgets.dart';
import 'package:aqua/features/shared/shared.dart';
class DlcScreen extends HookConsumerWidget {
  const DlcScreen({super.key});

  static const routeName = '/dlc';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dlcProvider);
    final notifier = ref.read(dlcProvider.notifier);

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
                    state.isSimulating ||
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
              Expanded(child: _DlcTabBody(selectedIndex: state.selectedTabIndex)),
            ],
          ),
          DlcActionLoadingOverlay(visible: dlcShellOverlayVisible(state)),
        ],
      ),
    );
  }
}

class _DlcTabBody extends StatelessWidget {
  const _DlcTabBody({required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return switch (selectedIndex) {
      0 => const DlcOverviewPanel(),
      1 => const DlcTradePanel(),
      2 => const DlcOrdersPanel(),
      3 => const DlcSimulatePanel(),
      _ => const DlcOverviewPanel(),
    };
  }
}
