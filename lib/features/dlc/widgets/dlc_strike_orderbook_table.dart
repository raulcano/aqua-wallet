import 'package:aqua/features/dlc/models/dlc_trade_models.dart';
import 'package:aqua/features/dlc/utils/dlc_order_utils.dart';
import 'package:aqua/features/dlc/widgets/dlc_trading_colors.dart';
import 'package:flutter/material.dart';

class DlcStrikeOrderbookTable extends StatelessWidget {
  const DlcStrikeOrderbookTable({
    super.key,
    required this.snapshots,
    required this.selectedStrike,
    required this.isLoading,
    required this.hasInstrument,
    required this.onStrikeTap,
  });

  final List<DlcStrikeOrderbookSnapshot> snapshots;
  final num? selectedStrike;
  final bool isLoading;
  final bool hasInstrument;
  final ValueChanged<DlcStrikeOrderbookSnapshot> onStrikeTap;

  @override
  Widget build(BuildContext context) {
    if (!hasInstrument) {
      return const Text('Select an instrument to view strikes.');
    }
    if (isLoading && snapshots.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (snapshots.isEmpty) {
      return const Text('No liquidity on any strike yet.');
    }

    final sorted = [...snapshots]..sort((a, b) => a.strike.compareTo(b.strike));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Table(
          columnWidths: const {
            0: IntrinsicColumnWidth(),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
              TableRow(
                children: [
                  _HeaderCell(
                    'Strike',
                    padding: const EdgeInsets.fromLTRB(0, 6, 16, 6),
                  ),
                  _HeaderCell(
                    'Ask',
                    align: TextAlign.end,
                    padding: const EdgeInsets.fromLTRB(0, 6, 16, 6),
                  ),
                  _HeaderCell('Bid', align: TextAlign.end),
                ],
              ),
              for (final snapshot in sorted)
                TableRow(
                  children: [
                    _StrikeCell(
                      snapshot: snapshot,
                      isSelected: snapshot.strike == selectedStrike,
                      onTap: () => onStrikeTap(snapshot),
                    ),
                    _PremiumCell(
                      text: bestAskPremiumSats(snapshot) ?? '—',
                      color: DlcTradingColors.sell,
                      align: TextAlign.end,
                      padding: const EdgeInsets.fromLTRB(0, 8, 16, 8),
                    ),
                    _PremiumCell(
                      text: bestBidPremiumSats(snapshot) ?? '—',
                      color: DlcTradingColors.buy,
                      align: TextAlign.end,
                    ),
                  ],
                ),
            ],
          ),
        const SizedBox(height: 8),
        Text(
          'Tap a strike to view full depth. Premiums are per contract (sats).',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(
    this.text, {
    this.align = TextAlign.start,
    this.padding = const EdgeInsets.symmetric(vertical: 6),
  });

  final String text;
  final TextAlign align;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        text,
        textAlign: align,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _StrikeCell extends StatelessWidget {
  const _StrikeCell({
    required this.snapshot,
    required this.isSelected,
    required this.onTap,
  });

  final DlcStrikeOrderbookSnapshot snapshot;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 16, 8),
        child: Text(
          '\$${snapshot.strike.round()}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                decoration:
                    isSelected ? TextDecoration.underline : TextDecoration.none,
              ),
        ),
      ),
    );
  }
}

class _PremiumCell extends StatelessWidget {
  const _PremiumCell({
    required this.text,
    required this.color,
    this.align = TextAlign.start,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  });

  final String text;
  final Color color;
  final TextAlign align;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        text,
        textAlign: align,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
      ),
    );
  }
}

void showDlcStrikeOrderbookDialog(
  BuildContext context, {
  required DlcStrikeOrderbookSnapshot snapshot,
  required void Function({
    required String side,
    required num quantity,
    required num premium,
  }) onDepthRowTap,
}) {
  final book = snapshot.orderbook;
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(snapshot.instrumentId),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Strike \$${snapshot.strike.round()}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Text('Asks', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            ..._depthRows(
              context,
              book?.asks ?? const [],
              side: 'buy',
              onDepthRowTap: onDepthRowTap,
            ),
            const SizedBox(height: 12),
            Text('Bids', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            ..._depthRows(
              context,
              book?.bids ?? const [],
              side: 'sell',
              onDepthRowTap: onDepthRowTap,
            ),
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

List<Widget> _depthRows(
  BuildContext context,
  List<DlcOrderbookLevel> levels, {
  required String side,
  required void Function({
    required String side,
    required num quantity,
    required num premium,
  }) onDepthRowTap,
}) {
  if (levels.isEmpty) {
    return [const Text('—')];
  }
  return levels.take(10).map((level) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('${level.price} sats × ${level.quantity}'),
      onTap: () {
        Navigator.pop(context);
        onDepthRowTap(
          side: side,
          quantity: level.quantity,
          premium: level.price,
        );
      },
    );
  }).toList();
}
