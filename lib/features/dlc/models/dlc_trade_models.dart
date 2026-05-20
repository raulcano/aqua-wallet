class DlcOrderbookLevel {
  const DlcOrderbookLevel({
    required this.price,
    required this.quantity,
    this.instrumentId,
    this.strike,
  });

  final num price;
  final num quantity;
  final String? instrumentId;
  final String? strike;

  factory DlcOrderbookLevel.fromJson(Map<String, dynamic> json) =>
      DlcOrderbookLevel(
        price: json['price'] as num? ?? 0,
        quantity: json['quantity'] as num? ?? 0,
        instrumentId: json['instrument_id'] as String?,
        strike: json['strike']?.toString(),
      );
}

class DlcOrderbookSnapshot {
  const DlcOrderbookSnapshot({
    required this.instrumentId,
    required this.bids,
    required this.asks,
  });

  final String instrumentId;
  final List<DlcOrderbookLevel> bids;
  final List<DlcOrderbookLevel> asks;

  factory DlcOrderbookSnapshot.fromJson(Map<String, dynamic> json) =>
      DlcOrderbookSnapshot(
        instrumentId: json['instrument_id'] as String? ?? '',
        bids: (json['bids'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(DlcOrderbookLevel.fromJson)
            .toList(),
        asks: (json['asks'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(DlcOrderbookLevel.fromJson)
            .toList(),
      );
}

class DlcStrikeOrderbookSnapshot {
  const DlcStrikeOrderbookSnapshot({
    required this.strike,
    required this.instrumentId,
    required this.orderbook,
    this.errorMessage,
  });

  final num strike;
  final String instrumentId;
  final DlcOrderbookSnapshot? orderbook;
  final String? errorMessage;

  bool get hasError => errorMessage != null;
}

class DlcOptionPayoutSimulationRequest {
  const DlcOptionPayoutSimulationRequest({
    required this.side,
    required this.role,
    required this.optionRight,
    required this.numContracts,
    required this.strike,
    required this.premiumPerContractSats,
    required this.outcomePrice,
    this.premiumPaidUpfront = false,
    this.networkFeeSats = 0,
  });

  final String side;
  final String role;
  final String optionRight;
  final num numContracts;
  final num strike;
  final num premiumPerContractSats;
  final num outcomePrice;
  final bool premiumPaidUpfront;
  final num networkFeeSats;

  Map<String, dynamic> toJson() => {
        'side': side,
        'role': role,
        'option_right': optionRight,
        'num_contracts': numContracts,
        'strike': strike,
        'premium_per_contract_sats': premiumPerContractSats,
        'outcome_price': outcomePrice,
        'premium_paid_upfront': premiumPaidUpfront,
        'network_fee_sats': networkFeeSats,
      };
}

class DlcPayoutChartPoint {
  const DlcPayoutChartPoint({
    required this.outcomePrice,
    required this.payoutSats,
  });

  final num outcomePrice;
  final num payoutSats;
}

class DlcPayoutChartInterval {
  const DlcPayoutChartInterval({
    required this.outcomeLo,
    required this.outcomeHi,
    required this.payoutSats,
  });

  final num outcomeLo;
  final num outcomeHi;
  final num payoutSats;
}

class DlcOptionPayoutSimulationResult {
  const DlcOptionPayoutSimulationResult({
    required this.raw,
    this.walletPnlSats,
    this.walletCollateralSats,
    this.premiumPaidSats,
    this.premiumReceivedSats,
    this.partnerFeeSats,
    this.roundedSettlementPayoutSats,
    this.roundingDeltaSats,
    this.canonicalPayoutSats,
    this.intervals = const [],
    this.canonicalPoints = const [],
    this.outcomePrice,
    this.strikePrice,
  });

  final Map<String, dynamic> raw;
  final num? walletPnlSats;
  final num? walletCollateralSats;
  final num? premiumPaidSats;
  final num? premiumReceivedSats;
  final num? partnerFeeSats;
  final num? roundedSettlementPayoutSats;
  final num? roundingDeltaSats;
  final num? canonicalPayoutSats;
  final List<DlcPayoutChartInterval> intervals;
  final List<DlcPayoutChartPoint> canonicalPoints;
  final num? outcomePrice;
  final num? strikePrice;

  bool get hasChartData =>
      intervals.isNotEmpty || canonicalPoints.isNotEmpty;

  factory DlcOptionPayoutSimulationResult.fromJson(Map<String, dynamic> json) {
    num? readNum(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is num) {
          return value;
        }
      }
      return null;
    }

    return DlcOptionPayoutSimulationResult(
      raw: json,
      walletPnlSats: readNum([
        'wallet_pnl_sats',
        'rounded_pnl_sats',
        'estimated_wallet_pnl_sats',
        'wallet_pnl',
      ]),
      walletCollateralSats: readNum([
        'wallet_collateral_sats',
        'wallet_posted_collateral_sats',
        'wallet_collateral',
      ]),
      premiumPaidSats: readNum([
        'premium_paid_sats',
        'premium_paid_upfront_sats',
        'premium_paid',
      ]),
      premiumReceivedSats: readNum([
        'premium_received_sats',
        'premium_received_upfront_sats',
        'premium_received',
      ]),
      partnerFeeSats: readNum([
        'partner_fee_sats',
        'partner_wallet_fee_sats',
      ]),
      roundedSettlementPayoutSats: readNum([
        'rounded_settlement_payout_sats',
        'wallet_rounded_settlement_payout_sats',
        'settlement_payout_sats',
      ]),
      roundingDeltaSats: readNum(['rounding_delta_sats']),
      canonicalPayoutSats: readNum([
        'wallet_canonical_payout_sats',
        'canonical_payout_sats',
      ]),
      intervals: _parseIntervals(json),
      canonicalPoints: _parseCanonicalPoints(json),
      outcomePrice: readNum([
        'outcome_price',
        'btc_usd_outcome',
        'outcome_btc_usd',
      ]),
      strikePrice: readNum(['strike', 'strike_price']),
    );
  }

  static List<DlcPayoutChartInterval> _parseIntervals(
    Map<String, dynamic> json,
  ) {
    final raw = json['intervals'] ??
        json['payout_intervals'] ??
        json['wallet_payout_intervals'];
    if (raw is! List) {
      return const [];
    }
    return raw.whereType<Map<String, dynamic>>().map((item) {
      final lo = item['outcome_lo'] ??
          item['outcome_price_lo'] ??
          item['lo'] ??
          item['min_outcome'];
      final hi = item['outcome_hi'] ??
          item['outcome_price_hi'] ??
          item['hi'] ??
          item['max_outcome'];
      final payout = item['payout_sats'] ??
          item['wallet_payout_sats'] ??
          item['rounded_payout_sats'] ??
          item['payout'];
      return DlcPayoutChartInterval(
        outcomeLo: lo as num? ?? 0,
        outcomeHi: (hi as num?) ?? (lo as num?) ?? 0,
        payoutSats: payout as num? ?? 0,
      );
    }).toList();
  }

  static List<DlcPayoutChartPoint> _parseCanonicalPoints(
    Map<String, dynamic> json,
  ) {
    final raw = json['canonical_points'] ??
        json['canonical_payout_points'] ??
        json['theoretical_points'];
    if (raw is! List) {
      return const [];
    }
    return raw.whereType<Map<String, dynamic>>().map((item) {
      final outcome = item['outcome'] ??
          item['outcome_price'] ??
          item['btc_usd_outcome'];
      final payout = item['payout'] ??
          item['payout_sats'] ??
          item['wallet_payout_sats'] ??
          item['canonical_payout_sats'];
      return DlcPayoutChartPoint(
        outcomePrice: outcome as num? ?? 0,
        payoutSats: payout as num? ?? 0,
      );
    }).toList();
  }
}
