import 'package:flutter/material.dart';

/// Trading semantics aligned with BullBitcoin DLC UI.
abstract final class DlcTradingColors {
  static const Color buy = Color(0xFF1B5E20);
  static const Color sell = Color(0xFFB71C1C);
  static const Color positivePnlDark = Color(0xFF81C784);

  static Color sideColor(String side, {required bool isDark}) {
    final normalized = side.toLowerCase();
    if (normalized == 'buy' || normalized == 'bid') {
      return buy;
    }
    return sell;
  }

  static Color pnlColor(num value, {required bool isDark}) {
    if (value > 0) {
      return isDark ? positivePnlDark : buy;
    }
    if (value < 0) {
      return sell;
    }
    return isDark ? Colors.white70 : Colors.black54;
  }
}
