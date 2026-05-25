import 'dart:math' as math;

import 'package:aqua/features/dlc/models/dlc_trade_models.dart';
import 'package:aqua/features/dlc/utils/dlc_option_payout_simulation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

class DlcOptionPayoutChart extends StatelessWidget {
  const DlcOptionPayoutChart({
    super.key,
    required this.result,
    required this.strikeUsd,
    required this.outcomeUsd,
  });

  final DlcOptionPayoutSimulationResult result;
  final int strikeUsd;
  final int outcomeUsd;

  static const _chartHeight = 228.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final usdFmt = NumberFormat.decimalPattern();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _chartHeight,
          width: double.infinity,
          child: CustomPaint(
            painter: _DlcPayoutChartPainter(
              result: result,
              strikeUsd: strikeUsd,
              outcomeUsd: outcomeUsd,
              scheme: scheme,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: [
            _LegendChip(
              color: scheme.primary,
              label: 'Actual payout',
            ),
            if (result.canonicalPoints.isNotEmpty)
              _LegendChip(
                color: scheme.onSurfaceVariant.withOpacity(0.75),
                label: 'Canonical payout',
                dashed: true,
              ),
            _LegendChip(
              color: scheme.tertiary,
              label: 'Strike (${usdFmt.format(strikeUsd)} USD)',
              thin: true,
            ),
            _LegendChip(
              color: scheme.secondary,
              label: 'Outcome (${usdFmt.format(outcomeUsd)} USD)',
              thin: true,
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
    this.dashed = false,
    this.thin = false,
  });

  final Color color;
  final String label;
  final bool dashed;
  final bool thin;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dashed)
          CustomPaint(
            size: const Size(16, 2.5),
            painter: _MiniDashPainter(color: color),
          )
        else
          Container(
            width: 16,
            height: thin ? 1.5 : 2.5,
            color: color,
          ),
        const SizedBox(width: 4),
        Text(label, style: textStyle),
      ],
    );
  }
}

class _MiniDashPainter extends CustomPainter {
  _MiniDashPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const dash = 4.0;
    const gap = 3.0;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      final end = math.min(x + dash, size.width);
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _MiniDashPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _DlcPayoutChartPainter extends CustomPainter {
  _DlcPayoutChartPainter({
    required this.result,
    required this.strikeUsd,
    required this.outcomeUsd,
    required this.scheme,
  });

  final DlcOptionPayoutSimulationResult result;
  final int strikeUsd;
  final int outcomeUsd;
  final ColorScheme scheme;

  static const _padLeft = 52.0;
  static const _padTop = 14.0;
  static const _padRight = 10.0;
  static const _padBottom = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTWH(
      _padLeft,
      _padTop,
      size.width - _padLeft - _padRight,
      size.height - _padTop - _padBottom,
    );

    if (chart.width <= 0 || chart.height <= 0) {
      return;
    }

    final xAxis = dlcPayoutChartStrikeOutcomeXAxis(
      strikeUsd: strikeUsd,
      outcomeUsd: outcomeUsd,
    );
    final xMin = xAxis.min;
    final xMax = xAxis.max;

    final yAxis = dlcPayoutChartYExtentsForX(
      xMin: xMin,
      xMax: xMax,
      intervals: result.intervals,
      canonicalPoints: result.canonicalPoints,
    );
    final yMin = yAxis.min;
    final yMax = yAxis.max;

    double tx(num x) =>
        chart.left + (x.toDouble() - xMin) / (xMax - xMin) * chart.width;

    double ty(num y) =>
        chart.bottom - (y.toDouble() - yMin) / (yMax - yMin) * chart.height;

    // 1. Plot background
    canvas.drawRect(
      chart,
      Paint()..color = scheme.surfaceContainerHighest.withOpacity(0.35),
    );

    // 2. Horizontal grid lines
    final gridPaint = Paint()
      ..color = scheme.outlineVariant.withOpacity(0.35)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final yVal = yMin + (yMax - yMin) * i / 4;
      final y = ty(yVal);
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      _drawText(
        canvas,
        dlcPayoutChartCompactSats(yVal),
        Offset(chart.left - 6, y),
        scheme.onSurfaceVariant,
        align: TextAlign.right,
        fontSize: 10,
      );
    }

    // 3. Outcome interval band
    final band = result.outcomeInterval;
    if (band != null) {
      final bandLeft = tx(band.start).clamp(chart.left, chart.right);
      final bandRight = tx(band.end).clamp(chart.left, chart.right);
      if (bandRight > bandLeft) {
        canvas.drawRect(
          Rect.fromLTRB(bandLeft, chart.top, bandRight, chart.bottom),
          Paint()
            ..color = scheme.primaryContainer.withOpacity(0.28),
        );
      }
    }

    // 4–5. Strike and outcome vertical guides + tags
    _drawVerticalGuide(
      canvas,
      chart: chart,
      x: tx(strikeUsd),
      color: scheme.tertiary,
      tag: 'Strike',
    );
    _drawVerticalGuide(
      canvas,
      chart: chart,
      x: tx(outcomeUsd),
      color: scheme.secondary,
      tag: 'Expiry',
    );

    // 6–8. Curves (clipped)
    canvas.save();
    canvas.clipRect(chart);

    if (result.intervals.isNotEmpty) {
      final sorted = [...result.intervals]
        ..sort((a, b) => a.outcomeLo.compareTo(b.outcomeLo));
      final path = Path();
      final first = sorted.first;
      path.moveTo(tx(first.outcomeLo), ty(first.payoutSats));
      for (var i = 0; i < sorted.length; i++) {
        final interval = sorted[i];
        path.lineTo(tx(interval.outcomeHi), ty(interval.payoutSats));
        if (i + 1 < sorted.length) {
          final next = sorted[i + 1];
          if (next.payoutSats != interval.payoutSats) {
            path.lineTo(
              tx(interval.outcomeHi),
              ty(next.payoutSats),
            );
          }
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = scheme.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round,
      );
    }

    if (result.canonicalPoints.length >= 2) {
      final sorted = [...result.canonicalPoints]
        ..sort((a, b) => a.outcomePrice.compareTo(b.outcomePrice));
      final path = Path();
      final first = sorted.first;
      path.moveTo(tx(first.outcomePrice), ty(first.payoutSats));
      for (var i = 1; i < sorted.length; i++) {
        path.lineTo(tx(sorted[i].outcomePrice), ty(sorted[i].payoutSats));
      }
      _drawDashedPath(
        canvas,
        path,
        scheme.onSurfaceVariant.withOpacity(0.75),
        1.6,
        dashLen: 7,
        gapLen: 5,
      );
    }

    canvas.restore();

    // 10. Plot border
    canvas.drawRect(
      chart,
      Paint()
        ..color = scheme.outlineVariant.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // 11. X-axis labels
    _drawText(
      canvas,
      dlcPayoutChartCompactUsd(xMin),
      Offset(chart.left, chart.bottom + 6),
      scheme.onSurfaceVariant,
      align: TextAlign.left,
      fontSize: 10,
    );
    _drawText(
      canvas,
      dlcPayoutChartCompactUsd(xMax),
      Offset(chart.right, chart.bottom + 6),
      scheme.onSurfaceVariant,
      align: TextAlign.right,
      fontSize: 10,
    );
    _drawText(
      canvas,
      'BTC/USD (oracle)',
      Offset(chart.center.dx, chart.bottom + 6),
      scheme.onSurfaceVariant,
      align: TextAlign.center,
      fontSize: 10,
    );
  }

  void _drawVerticalGuide(
    Canvas canvas, {
    required Rect chart,
    required double x,
    required Color color,
    required String tag,
  }) {
    if (x < chart.left || x > chart.right) {
      return;
    }
    canvas.drawLine(
      Offset(x, chart.top),
      Offset(x, chart.bottom),
      Paint()
        ..color = color.withOpacity(0.65)
        ..strokeWidth = 1.5,
    );

    final tagStyle = TextStyle(
      color: color.withOpacity(0.95),
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );
    final tp = TextPainter(
      text: TextSpan(text: tag, style: tagStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    var tagX = x - tp.width / 2;
    tagX = tagX.clamp(chart.left, chart.right - tp.width);
    tp.paint(canvas, Offset(tagX, chart.top - 2 - tp.height));
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset anchor,
    Color color, {
    required TextAlign align,
    double fontSize = 12,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout();

    final dx = switch (align) {
      TextAlign.right => anchor.dx - tp.width,
      TextAlign.center => anchor.dx - tp.width / 2,
      _ => anchor.dx,
    };
    tp.paint(canvas, Offset(dx, anchor.dy - tp.height / 2));
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Color color,
    double width, {
    required double dashLen,
    required double gapLen,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashLen).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DlcPayoutChartPainter oldDelegate) =>
      oldDelegate.result != result ||
      oldDelegate.strikeUsd != strikeUsd ||
      oldDelegate.outcomeUsd != outcomeUsd ||
      oldDelegate.scheme != scheme;
}
