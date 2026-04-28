import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../model/bar_marker.dart';
import '../model/candle.dart';
import '../model/chart_theme.dart';
import '../scale/price_scale.dart';

/// Renders [BarMarker]s anchored to candles.
class MarkersPainter {
  /// Vertical gap between a candle wick tip and the marker glyph.
  static const double _wickGap = 4;

  /// Horizontal gap between the glyph and its label text.
  static const double _textGap = 3;

  /// Paint every marker in [markers]. Markers whose [BarMarker.time] doesn't
  /// match any candle are silently skipped.
  static void paint({
    required ui.Canvas canvas,
    required ui.Size size,
    required ChartTheme theme,
    required List<BarMarker> markers,
    required List<Candle> candles,
    required PriceScale priceScale,
    required double Function(int time) xForTime,
  }) {
    if (markers.isEmpty || candles.isEmpty) return;
    final height = size.height;

    for (final m in markers) {
      final candle = _findCandle(candles, m.time);
      if (candle == null) continue;
      final x = xForTime(m.time);
      // Cull markers clearly outside the viewport.
      if (x < -m.size * 2 || x > size.width + m.size * 2) continue;

      final double y;
      switch (m.position) {
        case MarkerPosition.aboveBar:
          y = priceScale.priceToY(candle.high, height) - _wickGap - m.size / 2;
          break;
        case MarkerPosition.belowBar:
          y = priceScale.priceToY(candle.low, height) + _wickGap + m.size / 2;
          break;
        case MarkerPosition.inBar:
          y = priceScale.priceToY(candle.close, height);
          break;
      }

      _drawGlyph(canvas, m, ui.Offset(x, y));
      final text = m.text;
      if (text != null && text.isNotEmpty) {
        _drawLabel(canvas, m, text, ui.Offset(x, y), theme);
      }
    }
  }

  // ───────── glyphs ─────────

  static void _drawGlyph(ui.Canvas canvas, BarMarker m, ui.Offset center) {
    final paint = ui.Paint()
      ..color = m.color
      ..style = ui.PaintingStyle.fill
      ..isAntiAlias = true;
    final r = m.size / 2;

    switch (m.shape) {
      case MarkerShape.arrowUp:
        final path = ui.Path()
          ..moveTo(center.dx, center.dy - r)
          ..lineTo(center.dx + r, center.dy + r)
          ..lineTo(center.dx - r, center.dy + r)
          ..close();
        canvas.drawPath(path, paint);
        break;
      case MarkerShape.arrowDown:
        final path = ui.Path()
          ..moveTo(center.dx, center.dy + r)
          ..lineTo(center.dx + r, center.dy - r)
          ..lineTo(center.dx - r, center.dy - r)
          ..close();
        canvas.drawPath(path, paint);
        break;
      case MarkerShape.circle:
        canvas.drawCircle(center, r, paint);
        break;
      case MarkerShape.square:
        canvas.drawRect(
          ui.Rect.fromCenter(center: center, width: m.size, height: m.size),
          paint,
        );
        break;
    }
  }

  static void _drawLabel(
    ui.Canvas canvas,
    BarMarker m,
    String text,
    ui.Offset glyphCenter,
    ChartTheme theme,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: m.color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final r = m.size / 2;
    final double tx;
    final double ty;
    switch (m.position) {
      case MarkerPosition.aboveBar:
        tx = glyphCenter.dx - tp.width / 2;
        ty = glyphCenter.dy - r - _textGap - tp.height;
        break;
      case MarkerPosition.belowBar:
        tx = glyphCenter.dx - tp.width / 2;
        ty = glyphCenter.dy + r + _textGap;
        break;
      case MarkerPosition.inBar:
        tx = glyphCenter.dx + r + _textGap;
        ty = glyphCenter.dy - tp.height / 2;
        break;
    }
    tp.paint(canvas, ui.Offset(tx, ty));
  }

  // ───────── candle lookup ─────────

  /// Binary search for an exact `candle.time == time` match. Returns null if
  /// the marker doesn't align to any candle (we don't snap intentionally —
  /// markers belong to a specific bar, not "the nearest" one).
  static Candle? _findCandle(List<Candle> data, int time) {
    var lo = 0;
    var hi = data.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final t = data[mid].time;
      if (t == time) return data[mid];
      if (t < time) {
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return null;
  }
}
