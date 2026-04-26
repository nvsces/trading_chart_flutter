import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../model/candle.dart';
import '../model/chart_theme.dart';
import '../scale/price_scale.dart';
import '../scale/time_scale.dart';

@immutable
class CandlestickSeries {
  final List<Candle> data;

  const CandlestickSeries({required this.data});

  /// Returns (min, max) across the [from..to] inclusive index range.
  /// Considers high/low for accurate fit.
  ({double min, double max})? priceRange(int from, int to) {
    if (data.isEmpty) return null;
    final lo = from.clamp(0, data.length - 1);
    final hi = to.clamp(0, data.length - 1);
    if (hi < lo) return null;
    var min = data[lo].low;
    var max = data[lo].high;
    for (var i = lo + 1; i <= hi; i++) {
      final c = data[i];
      if (c.low < min) min = c.low;
      if (c.high > max) max = c.high;
    }
    return (min: min, max: max);
  }

  void paint({
    required ui.Canvas canvas,
    required ui.Size size,
    required TimeScale timeScale,
    required PriceScale priceScale,
    required ChartTheme theme,
  }) {
    if (data.isEmpty) return;
    final width = size.width;
    final height = size.height;

    final upBody = ui.Paint()..color = theme.upColor;
    final downBody = ui.Paint()..color = theme.downColor;
    final upWick = ui.Paint()
      ..color = theme.upWick
      ..strokeWidth = 1
      ..style = ui.PaintingStyle.stroke;
    final downWick = ui.Paint()
      ..color = theme.downWick
      ..strokeWidth = 1
      ..style = ui.PaintingStyle.stroke;

    final range = timeScale.visibleIntegerRange(width);
    final bodyWidth = (timeScale.barSpacing * 0.7).clamp(1.0, double.infinity);

    for (var i = range.from; i <= range.to; i++) {
      final c = data[i];
      final x = timeScale.indexToX(i.toDouble(), width);

      final yOpen = priceScale.priceToY(c.open, height);
      final yClose = priceScale.priceToY(c.close, height);
      final yHigh = priceScale.priceToY(c.high, height);
      final yLow = priceScale.priceToY(c.low, height);

      final isUp = c.isUp;
      final wickPaint = isUp ? upWick : downWick;
      final bodyPaint = isUp ? upBody : downBody;

      // Wick (snap to half-pixel for crisp 1px line).
      final wickX = (x).roundToDouble() + 0.5;
      canvas.drawLine(
        ui.Offset(wickX, yHigh),
        ui.Offset(wickX, yLow),
        wickPaint,
      );

      // Body.
      var top = yClose < yOpen ? yClose : yOpen;
      var bottom = yClose < yOpen ? yOpen : yClose;
      if ((bottom - top).abs() < 1) {
        // Doji: at least 1px tall.
        top -= 0.5;
        bottom += 0.5;
      }
      final left = (x - bodyWidth / 2).roundToDouble();
      final right = (x + bodyWidth / 2).roundToDouble();
      canvas.drawRect(
        ui.Rect.fromLTRB(left, top, right, bottom),
        bodyPaint,
      );
    }
  }
}
