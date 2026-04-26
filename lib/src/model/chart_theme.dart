import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

@immutable
class ChartTheme {
  final Color background;
  final Color text;
  final Color axisLine;
  final Color gridLine;
  final Color upColor;
  final Color downColor;
  final Color upWick;
  final Color downWick;
  final Color crosshair;
  final Color crosshairLabelBg;
  final Color crosshairLabelText;
  final Color lastValueLabelBg;
  final Color lastValueLabelText;
  final Color priceLine;
  final double axisFontSize;

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
