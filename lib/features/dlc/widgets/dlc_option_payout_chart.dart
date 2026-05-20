import 'package:aqua/features/dlc/models/dlc_trade_models.dart';
import 'package:aqua/features/dlc/widgets/dlc_trading_colors.dart';
import 'package:flutter/material.dart';
import 'package:ui_components/ui_components.dart';

class DlcOptionPayoutChart extends StatelessWidget {
  const DlcOptionPayoutChart({
    super.key,
    required this.result,
    this.strikePrice,
    this.outcomePrice,
    this.height = 200,
  });

  final DlcOptionPayoutSimulationResult result;
  final num? strikePrice;
  final num? outcomePrice;
  final double height;

  @override
  Widget build(BuildContext context) {
    final strike = strikePrice ?? result.strikePrice;
    final outcome = outcomePrice ?? result.outcomePrice;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _DlcPayoutChartPainter(
              intervals: result.intervals,
              canonicalPoints: result.canonicalPoints,
              strikePrice: strike,
              outcomePrice: outcome,
              actualColor: scheme.primary,
              canonicalColor: scheme.outline,
              strikeColor: DlcTradingColors.buy,
              outcomeColor: AquaPrimitiveColors.bitcoin,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _LegendChip(
              color: scheme.primary,
              label: 'Actual payout',
              dashed: false,
            ),
            if (result.canonicalPoints.isNotEmpty)
              _LegendChip(
                color: scheme.outline,
                label: 'Canonical payout',
                dashed: true,
              ),
            if (strike != null)
              _LegendChip(
                color: DlcTradingColors.buy,
                label: 'Strike',
                dashed: false,
              ),
            if (outcome != null)
              _LegendChip(
                color: AquaPrimitiveColors.bitcoin,
                label: 'Outcome',
                dashed: false,
              ),
          ],
        ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.color,
    required this.label,
    required this.dashed,
  });

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: dashed ? Colors.transparent : color,
            border: dashed ? Border(bottom: BorderSide(color: color)) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _DlcPayoutChartPainter extends CustomPainter {
  _DlcPayoutChartPainter({
    required this.intervals,
    required this.canonicalPoints,
    required this.strikePrice,
    required this.outcomePrice,
    required this.actualColor,
    required this.canonicalColor,
    required this.strikeColor,
    required this.outcomeColor,
  });

  final List<DlcPayoutChartInterval> intervals;
  final List<DlcPayoutChartPoint> canonicalPoints;
  final num? strikePrice;
  final num? outcomePrice;
  final Color actualColor;
  final Color canonicalColor;
  final Color strikeColor;
  final Color outcomeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final padding = 8.0;
    final chartRect = Rect.fromLTWH(
      padding,
      padding,
      size.width - padding * 2,
      size.height - padding * 2,
    );

    var minX = double.infinity;
    var maxX = -double.infinity;
    var minY = double.infinity;
    var maxY = -double.infinity;

    void consider(num x, num y) {
      minX = minX < x ? minX : x.toDouble();
      maxX = maxX > x ? maxX : x.toDouble();
      minY = minY < y ? minY : y.toDouble();
      maxY = maxY > y ? maxY : y.toDouble();
    }

    for (final interval in intervals) {
      consider(interval.outcomeLo, interval.payoutSats);
      consider(interval.outcomeHi, interval.payoutSats);
    }
    for (final point in canonicalPoints) {
      consider(point.outcomePrice, point.payoutSats);
    }
    if (strikePrice != null) {
      minX = minX < strikePrice! ? minX : strikePrice!.toDouble();
      maxX = maxX > strikePrice! ? maxX : strikePrice!.toDouble();
    }
    if (outcomePrice != null) {
      minX = minX < outcomePrice! ? minX : outcomePrice!.toDouble();
      maxX = maxX > outcomePrice! ? maxX : outcomePrice!.toDouble();
    }

    if (minX == double.infinity) {
      _drawEmpty(canvas, size);
      return;
    }

    if (minX == maxX) {
      maxX = minX + 1;
    }
    if (minY == maxY) {
      maxY = minY + 1;
    }

    Offset map(num x, num y) {
      final nx = (x - minX) / (maxX - minX);
      final ny = (y - minY) / (maxY - minY);
      return Offset(
        chartRect.left + nx * chartRect.width,
        chartRect.bottom - ny * chartRect.height,
      );
    }

    final gridPaint = Paint()
      ..color = canonicalColor.withOpacity(0.2)
      ..strokeWidth = 1;
    canvas.drawRect(chartRect, gridPaint);

    if (canonicalPoints.length >= 2) {
      final path = Path();
      final sorted = [...canonicalPoints]
        ..sort((a, b) => a.outcomePrice.compareTo(b.outcomePrice));
      path.moveTo(
        map(sorted.first.outcomePrice, sorted.first.payoutSats).dx,
        map(sorted.first.outcomePrice, sorted.first.payoutSats).dy,
      );
      for (var i = 1; i < sorted.length; i++) {
        path.lineTo(
          map(sorted[i].outcomePrice, sorted[i].payoutSats).dx,
          map(sorted[i].outcomePrice, sorted[i].payoutSats).dy,
        );
      }
      _drawDashedPath(canvas, path, canonicalColor, 1.5);
    }

    if (intervals.isNotEmpty) {
      final sorted = [...intervals]
        ..sort((a, b) => a.outcomeLo.compareTo(b.outcomeLo));
      final path = Path();
      final first = sorted.first;
      path.moveTo(
        map(first.outcomeLo, first.payoutSats).dx,
        map(first.outcomeLo, first.payoutSats).dy,
      );
      for (final interval in sorted) {
        final lo = map(interval.outcomeLo, interval.payoutSats);
        final hi = map(interval.outcomeHi, interval.payoutSats);
        path.lineTo(hi.dx, lo.dy);
        path.lineTo(hi.dx, hi.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = actualColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    void drawMarker(num? x, Color color) {
      if (x == null) {
        return;
      }
      final top = Offset(map(x, maxY).dx, chartRect.top);
      final bottom = Offset(map(x, maxY).dx, chartRect.bottom);
      canvas.drawLine(
        top,
        bottom,
        Paint()
          ..color = color.withOpacity(0.75)
          ..strokeWidth = 1.5,
      );
    }

    drawMarker(strikePrice, strikeColor);
    drawMarker(outcomePrice, outcomeColor);
  }

  void _drawEmpty(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'No chart intervals in response',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  void _drawDashedPath(Canvas canvas, Path path, Color color, double width) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dash = 6.0;
      const gap = 4.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DlcPayoutChartPainter oldDelegate) => true;
}
