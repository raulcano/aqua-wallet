import 'dart:math' as math;

import 'package:aqua/features/dlc/models/dlc_trade_models.dart';

/// Focused x-axis window around strike and outcome (see simulate tab spec §6.6.1).
({double min, double max}) dlcPayoutChartStrikeOutcomeXAxis({
  required int strikeUsd,
  required int outcomeUsd,
}) {
  final min = math.min(strikeUsd * 0.65, outcomeUsd * 0.65).toDouble();
  var max = math.max(strikeUsd * 1.35, outcomeUsd * 1.35).toDouble();
  final clampedMin = math.max(0.0, min);
  if (max <= clampedMin) {
    max = clampedMin + 1;
  }
  return (min: clampedMin, max: max);
}

/// Y extents from intervals and canonical points visible inside [xMin, xMax].
({double min, double max}) dlcPayoutChartYExtentsForX({
  required double xMin,
  required double xMax,
  required List<DlcPayoutChartInterval> intervals,
  required List<DlcPayoutChartPoint> canonicalPoints,
}) {
  var yMin = double.infinity;
  var yMax = -double.infinity;

  void consider(double x, double y) {
    if (x < xMin || x > xMax) {
      return;
    }
    yMin = math.min(yMin, y);
    yMax = math.max(yMax, y);
  }

  for (final interval in intervals) {
    final lo = interval.outcomeLo.toDouble();
    final hi = interval.outcomeHi.toDouble();
    final payout = interval.payoutSats.toDouble();
    consider(lo, payout);
    consider(hi, payout);
  }

  for (final point in canonicalPoints) {
    consider(point.outcomePrice.toDouble(), point.payoutSats.toDouble());
  }

  if (yMin == double.infinity) {
    return (min: 0, max: 1);
  }

  if (yMin == yMax) {
    yMax = yMin + 1;
  }

  final range = yMax - yMin;
  final pad = range * 0.08;
  return (min: yMin - pad, max: yMax + pad);
}

String dlcPayoutChartCompactUsd(double v) {
  if (v.abs() >= 1e6) {
    return '${(v / 1e6).toStringAsFixed(2)}M';
  }
  if (v.abs() >= 1e3) {
    return '${(v / 1e3).toStringAsFixed(1)}k';
  }
  return v.round().toString();
}

String dlcPayoutChartCompactSats(double v) {
  final r = v.round();
  final abs = r.abs();
  final sign = r < 0 ? '-' : '';
  if (abs >= 1000000000) {
    return '$sign${(abs / 1e9).toStringAsFixed(2)}B';
  }
  if (abs >= 1000000) {
    return '$sign${(abs / 1e6).toStringAsFixed(2)}M';
  }
  if (abs >= 1000) {
    return '$sign${(abs / 1e3).toStringAsFixed(1)}k';
  }
  return '$sign$abs';
}
