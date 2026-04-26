import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Color palette and font sizing for [TradingChart] / [InteractiveTradingChart].
///
/// Use the built-in [ChartTheme.dark] / [ChartTheme.light] presets, or
/// build a custom palette to match your app.
@immutable
class ChartTheme {
  /// Plot background color, painted edge-to-edge before any series.
  final Color background;

  /// Color used for axis tick labels.
  final Color text;

  /// Color of the thin axis baseline that separates plot from axis.
  final Color axisLine;

  /// Color of the in-plot grid lines.
  final Color gridLine;

  /// Body color for bullish (close >= open) candles.
  final Color upColor;

  /// Body color for bearish (close < open) candles.
  final Color downColor;

  /// Wick color for bullish candles.
  final Color upWick;

  /// Wick color for bearish candles.
  final Color downWick;

  /// Crosshair line color (usually translucent).
  final Color crosshair;

  /// Background of the crosshair badges drawn on the price/time axes.
  final Color crosshairLabelBg;

  /// Text color inside crosshair badges.
  final Color crosshairLabelText;

  /// Background of the last-value badge on the price axis.
  final Color lastValueLabelBg;

  /// Text color inside the last-value badge.
  final Color lastValueLabelText;

  /// Color of the dashed last-value horizontal price line.
  final Color priceLine;

  /// Font size used for axis tick labels and badges.
  final double axisFontSize;

  /// Builds a custom theme. Prefer [ChartTheme.dark] or [ChartTheme.light]
  /// unless you really need to override colors.
  const ChartTheme({
    required this.background,
    required this.text,
    required this.axisLine,
    required this.gridLine,
    required this.upColor,
    required this.downColor,
    required this.upWick,
    required this.downWick,
    required this.crosshair,
    required this.crosshairLabelBg,
    required this.crosshairLabelText,
    required this.lastValueLabelBg,
    required this.lastValueLabelText,
    required this.priceLine,
    this.axisFontSize = 11,
  });

  /// Default dark palette: black background, TradingView-like green/red accents.
  static const dark = ChartTheme(
    background: Color(0xFF000000),
    text: Color(0xFFD1D4DC),
    axisLine: Color(0xFF2A2E39),
    gridLine: Color(0xFF1E222D),
    upColor: Color(0xFF26A69A),
    downColor: Color(0xFFEF5350),
    upWick: Color(0xFF26A69A),
    downWick: Color(0xFFEF5350),
    crosshair: Color(0x88B7BDC6),
    crosshairLabelBg: Color(0xFF2A2E39),
    crosshairLabelText: Color(0xFFFFFFFF),
    lastValueLabelBg: Color(0xFF2962FF),
    lastValueLabelText: Color(0xFFFFFFFF),
    priceLine: Color(0x882962FF),
  );

  /// Default light palette: white background, TradingView-like green/red accents.
  static const light = ChartTheme(
    background: Color(0xFFFFFFFF),
    text: Color(0xFF131722),
    axisLine: Color(0xFFE1E3EB),
    gridLine: Color(0xFFE1E3EB),
    upColor: Color(0xFF26A69A),
    downColor: Color(0xFFEF5350),
    upWick: Color(0xFF26A69A),
    downWick: Color(0xFFEF5350),
    crosshair: Color(0x88758696),
    crosshairLabelBg: Color(0xFF131722),
    crosshairLabelText: Color(0xFFFFFFFF),
    lastValueLabelBg: Color(0xFF2962FF),
    lastValueLabelText: Color(0xFFFFFFFF),
    priceLine: Color(0x882962FF),
  );
}
