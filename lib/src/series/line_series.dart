import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../model/line_point.dart';
import '../scale/price_scale.dart';
import '../scale/time_scale.dart';

/// A polyline overlay drawn on top of the candlesticks, sharing the main
/// price scale. Use it to render moving averages, VWAP, or any custom
/// `(time, value)` series.
///
/// Points are aligned to candle indices via the `indexFor` lookup passed to
/// [paint]; samples whose [LinePoint.time] does not match a candle, or whose
/// value is `NaN`, are skipped. Adjacent skipped samples produce visual gaps,
/// matching how Lightweight Charts handles missing data.
@immutable
class LineSeries {
  /// Indicator samples in time-ascending order.
  final List<LinePoint> data;

  /// Stroke color.
  final ui.Color color;

  /// Stroke width in logical pixels.
  final double lineWidth;

  /// Whether the line should contribute to the auto-fit price range.
  /// Disable for off-scale overlays you don't want to affect candle framing.
  final bool fitToPriceScale;

  /// Creates a line overlay.
  const LineSeries({
    required this.data,
    required this.color,
    this.lineWidth = 1.5,
    this.fitToPriceScale = true,
  });

  /// Returns (min, max) value across all samples whose [LinePoint.time] is
  /// within the inclusive `[fromTime..toTime]` window. `null` if no finite
  /// sample falls in the window.
  ({double min, double max})? valueRangeForTimeWindow(
    int fromTime,
    int toTime,
  ) {
    if (data.isEmpty || toTime < fromTime) return null;
    double? min;
    double? max;
    for (final p in data) {
      if (p.time < fromTime) continue;
      if (p.time > toTime) break;
      final v = p.value;
      if (v.isNaN || v.isInfinite) continue;
      if (min == null || v < min) min = v;
      if (max == null || v > max) max = v;
    }
    if (min == null || max == null) return null;
    return (min: min, max: max);
  }

  void paint({
    required ui.Canvas canvas,
    required ui.Size size,
    required TimeScale timeScale,
    required PriceScale priceScale,
    required double Function(int time) xForTime,
  }) {
    if (data.isEmpty) return;
    final width = size.width;
    final height = size.height;

    final paint = ui.Paint()
      ..color = color
      ..strokeWidth = lineWidth
      ..style = ui.PaintingStyle.stroke
      ..strokeJoin = ui.StrokeJoin.round
      ..strokeCap = ui.StrokeCap.round
      ..isAntiAlias = true;

    final path = ui.Path();
    var penDown = false;

    for (final p in data) {
      final v = p.value;
      if (v.isNaN || v.isInfinite) {
        penDown = false;
        continue;
      }
      final x = xForTime(p.time);
      // Cull points clearly outside the viewport horizontally, but keep the
      // segments that cross the edge — moveTo/lineTo handle clipping with the
      // canvas clip rect set up by the caller.
      if (x < -width || x > width * 2) {
        penDown = false;
        continue;
      }
      final y = priceScale.priceToY(v, height);
      if (!penDown) {
        path.moveTo(x, y);
        penDown = true;
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }
}
