import 'package:aqua/features/dlc/models/dlc_models.dart';
import 'package:collection/collection.dart';

const _strikePlaceholderPattern = 'STRIKE';

String? dlcOptionRightFromInstrumentId(String instrumentId) {
  final upper = instrumentId.toUpperCase();
  if (upper.endsWith('-C') || upper.contains('-C-')) {
    return 'C';
  }
  if (upper.endsWith('-P') || upper.contains('-P-')) {
    return 'P';
  }
  return null;
}

num? dlcStrikeUsdFromInstrumentId(String instrumentId) {
  final parts = instrumentId.split('-');
  for (final part in parts.reversed) {
    final value = num.tryParse(part);
    if (value != null && value > 1000) {
      return value;
    }
  }
  return null;
}

bool dlcInstrumentHasStrikePlaceholder(String instrumentId) =>
    instrumentId.toUpperCase().contains(_strikePlaceholderPattern);

String dlcNormalizeStrikeToken(num strike) {
  if (strike == strike.roundToDouble()) {
    return strike.round().toString();
  }
  return strike.toString();
}

String dlcReplaceStrikeInInstrumentId(
  String templateInstrumentId,
  String strikeToken,
) =>
    templateInstrumentId.replaceAll(
      RegExp(_strikePlaceholderPattern, caseSensitive: false),
      strikeToken,
    );

class DlcInstrumentMetadata {
  const DlcInstrumentMetadata({
    required this.underlying,
    required this.expiryToken,
    required this.optionRight,
  });

  final String underlying;
  final String expiryToken;
  final String optionRight;
}

DlcInstrumentMetadata? dlcParseInstrumentMetadata(String instrumentId) {
  final parts = instrumentId.split('-');
  if (parts.length < 4) {
    return null;
  }
  final right = parts.last.toUpperCase();
  if (right != 'C' && right != 'P') {
    return null;
  }
  return DlcInstrumentMetadata(
    underlying: parts.first.toUpperCase(),
    expiryToken: parts[parts.length - 2],
    optionRight: right,
  );
}

bool dlcInstrumentMatchesOptionType(
  String instrumentId,
  String optionRight,
) {
  final meta = dlcParseInstrumentMetadata(instrumentId);
  if (meta == null) {
    return true;
  }
  return meta.optionRight == optionRight.toUpperCase();
}

List<DlcInstrument> dlcFilterInstrumentsByOptionRight(
  List<DlcInstrument> instruments,
  String optionRight,
) =>
    instruments
        .where((i) => dlcInstrumentMatchesOptionType(i.instrumentId, optionRight))
        .toList();

/// Resolves a template with STRIKE placeholder or returns a concrete instrument id.
String? dlcResolveInstrumentId({
  required String templateOrId,
  required String? strikeToken,
  required List<DlcInstrument> instruments,
  required bool allowUnresolvedInCatalog,
}) {
  if (!dlcInstrumentHasStrikePlaceholder(templateOrId)) {
    final exists =
        instruments.any((i) => i.instrumentId == templateOrId);
    if (exists || allowUnresolvedInCatalog) {
      return templateOrId;
    }
    return null;
  }

  if (strikeToken == null || strikeToken.isEmpty) {
    return null;
  }

  final resolved =
      dlcReplaceStrikeInInstrumentId(templateOrId, strikeToken);
  final exists = instruments.any((i) => i.instrumentId == resolved);
  if (exists || allowUnresolvedInCatalog) {
    return resolved;
  }
  return null;
}

bool dlcIsInstrumentExpired(
  DlcInstrument instrument, {
  required bool allowExpired,
}) {
  if (allowExpired) {
    return false;
  }
  final expiresAt = instrument.expiresAt;
  if (expiresAt == null) {
    return false;
  }
  return !expiresAt.isAfter(DateTime.now());
}

List<num> buildSuggestedStrikePrices(
  num spotUsd, {
  int steps = 5,
  num stepUsd = 1000,
}) {
  if (spotUsd <= 0) {
    return const [];
  }
  final center = (spotUsd / stepUsd).round() * stepUsd;
  return [
    for (var offset = -steps; offset <= steps; offset++)
      center + offset * stepUsd,
  ];
}

DlcInstrument? dlcPickDefaultTemplateInstrument(
  List<DlcInstrument> instruments, {
  String optionRight = 'C',
}) {
  final filtered = dlcFilterInstrumentsByOptionRight(instruments, optionRight);
  final pool = filtered.isNotEmpty ? filtered : instruments;
  return pool.firstWhereOrNull(
        (instrument) =>
            dlcInstrumentHasStrikePlaceholder(instrument.instrumentId),
      ) ??
      pool.firstOrNull;
}
