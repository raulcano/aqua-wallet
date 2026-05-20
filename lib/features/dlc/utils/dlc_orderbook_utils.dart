import 'package:aqua/features/dlc/models/dlc_trade_models.dart';

List<DlcStrikeOrderbookSnapshot> optimisticTrimOrderbookForMatch({
  required List<DlcStrikeOrderbookSnapshot> snapshots,
  required num strike,
  required String side,
  required num quantity,
}) {
  final normalizedSide = side.toLowerCase();
  return snapshots.map((snapshot) {
    if (snapshot.strike != strike || snapshot.orderbook == null) {
      return snapshot;
    }
    final book = snapshot.orderbook!;
    if (normalizedSide == 'buy') {
      return DlcStrikeOrderbookSnapshot(
        strike: snapshot.strike,
        instrumentId: snapshot.instrumentId,
        orderbook: DlcOrderbookSnapshot(
          instrumentId: book.instrumentId,
          bids: book.bids,
          asks: _trimLevels(book.asks, quantity),
        ),
      );
    }
    return DlcStrikeOrderbookSnapshot(
      strike: snapshot.strike,
      instrumentId: snapshot.instrumentId,
      orderbook: DlcOrderbookSnapshot(
        instrumentId: book.instrumentId,
        bids: _trimLevels(book.bids, quantity),
        asks: book.asks,
      ),
    );
  }).toList();
}

List<DlcOrderbookLevel> _trimLevels(
  List<DlcOrderbookLevel> levels,
  num quantity,
) {
  if (levels.isEmpty) {
    return levels;
  }
  final top = levels.first;
  final remaining = top.quantity - quantity;
  if (remaining <= 0) {
    return levels.skip(1).toList();
  }
  return [
    DlcOrderbookLevel(
      price: top.price,
      quantity: remaining,
      instrumentId: top.instrumentId,
      strike: top.strike,
    ),
    ...levels.skip(1),
  ];
}
