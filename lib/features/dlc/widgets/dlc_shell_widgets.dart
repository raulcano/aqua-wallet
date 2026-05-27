import 'package:aqua/common/providers/launch_url_provider.dart';
import 'package:aqua/features/dlc/providers/dlc_provider.dart';
import 'package:aqua/features/shared/shared.dart';
import 'package:ui_components/ui_components.dart';

class DlcTopNav extends StatelessWidget {
  const DlcTopNav({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.isDisabled,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool isDisabled;

  static const _tabs = [
    (icon: Icons.dashboard_outlined, label: 'Overview'),
    (icon: Icons.candlestick_chart_outlined, label: 'Trade'),
    (icon: Icons.list_alt_outlined, label: 'My orders'),
    (icon: Icons.calculate_outlined, label: 'Simulate'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: isDisabled ? 0.42 : 1,
      child: IgnorePointer(
        ignoring: isDisabled,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: _DlcTopNavItem(
                    icon: _tabs[i].icon,
                    label: _tabs[i].label,
                    isSelected: selectedIndex == i,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DlcTopNavItem extends StatelessWidget {
  const _DlcTopNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? scheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: isSelected
                ? Border.all(color: scheme.outlineVariant)
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 23,
                color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? scheme.onSurface
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DlcMessageBanner extends StatelessWidget {
  const DlcMessageBanner({
    super.key,
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background =
        isError ? scheme.errorContainer : scheme.primaryContainer;
    final foreground =
        isError ? scheme.onErrorContainer : scheme.onPrimaryContainer;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: background,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.info_outline,
                color: foreground,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: foreground),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close, color: foreground, size: 18),
                onPressed: onDismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DlcActionLoadingOverlay extends StatelessWidget {
  const DlcActionLoadingOverlay({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withOpacity(0.45),
        child: const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Working…'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DlcSectionHeader extends StatelessWidget {
  const DlcSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class DlcTabScrollView extends StatelessWidget {
  const DlcTabScrollView({
    super.key,
    required this.onRefresh,
    required this.children,
  });

  final Future<void> Function() onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottomInset),
        children: children,
      ),
    );
  }
}

class DlcColdPayAttribution extends ConsumerWidget {
  const DlcColdPayAttribution({super.key});

  static const _url = 'https://www.coldpay.me';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11);
    final dotSize = (style?.fontSize ?? 11) * 1.65;
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () =>
            ref.read(launchUrlProvider.notifier).launchUrl(_url),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Powered by ',
                style: style?.copyWith(fontStyle: FontStyle.italic),
              ),
              TextSpan(text: 'ColdPay', style: style),
              TextSpan(
                text: '.',
                style: style?.copyWith(
                  fontSize: dotSize,
                  height: 1,
                  color: AquaPrimitiveColors.bitcoin,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Input decoration for DLC text fields and dropdowns on [Card] surfaces.
InputDecoration dlcInputDecoration(
  BuildContext context, {
  String? labelText,
  String? hintText,
  String? helperText,
  String? suffixText,
}) {
  final scheme = Theme.of(context).colorScheme;
  final enabledBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: scheme.outlineVariant.withOpacity(0.55)),
  );
  final focusedBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: scheme.primary),
  );

  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    helperText: helperText,
    suffixText: suffixText,
    isDense: true,
    filled: true,
    fillColor: scheme.surfaceContainerLow,
    border: enabledBorder,
    enabledBorder: enabledBorder,
    focusedBorder: focusedBorder,
  );
}

bool dlcShellOverlayVisible(
  DlcState state, {
  bool simulateLoading = false,
}) =>
    state.actionInProgress ||
    state.isLoadingTradeData ||
    simulateLoading;
