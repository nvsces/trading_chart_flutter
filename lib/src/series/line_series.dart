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

    // xForTime is monotonic non-decreasing in time, so we can binary-search
    // the inclusive index window [lo..hi] whose x lands inside the cull rect
    // [-width .. 2*width]. We then extend by one on each side so the polyline
    // segments that cross the edge are still drawn (canvas clip handles the
    // off-screen tail).
    final cullMin = -width;
    final cullMax = 2 * width;
    final n = data.length;
    var lo = _firstIndexWithXAtLeast(cullMin, xForTime);
    var hi = _lastIndexWithXAtMost(cullMax, xForTime);
    if (lo > hi) {
      // Whole series is off-screen on one side.
      return;
    }
    if (lo > 0) lo -= 1;
    if (hi < n - 1) hi += 1;

    for (var i = lo; i <= hi; i++) {
      final p = data[i];
      final v = p.value;
      if (v.isNaN || v.isInfinite) {
        penDown = false;
        continue;
      }
      final x = xForTime(p.time);
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

  /// Smallest `i` in `[0..n]` such that `xForTime(data[i].time) >= target`.
  /// Returns `n` if no such index exists.
  int _firstIndexWithXAtLeast(double target, double Function(int time) xForTime) {
    var lo = 0;
    var hi = data.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (xForTime(data[mid].time) < target) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// Largest `i` in `[-1..n-1]` such that `xForTime(data[i].time) <= target`.
  /// Returns `-1` if no such index exists.
  int _lastIndexWithXAtMost(double target, double Function(int time) xForTime) {
    var lo = 0;
    var hi = data.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (xForTime(data[mid].time) <= target) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo - 1;
  }
}
