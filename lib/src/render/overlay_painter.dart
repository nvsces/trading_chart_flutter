import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../model/candle.dart';
import '../model/chart_theme.dart';
import '../scale/price_scale.dart';
import '../scale/time_scale.dart';

class OverlayPainter {
  /// Last close price line + axis badge.
  static void paintLastValue({
    required ui.Canvas canvas,
    required ui.Rect plotRect,
    required ui.Rect priceAxisRect,
    required ChartTheme theme,
    required Candle lastCandle,
    required PriceScale priceScale,
    required double priceStep,
  }) {
    final y = priceScale.priceToY(lastCandle.close, plotRect.height);
    if (y < plotRect.top || y > plotRect.bottom) return;

    final yLine = y.roundToDouble() + 0.5;
    final dashPaint = ui.Paint()
      ..color = theme.priceLine
      ..strokeWidth = 1
      ..style = ui.PaintingStyle.stroke;

    _drawDashedHLine(
      canvas,
      yLine,
      plotRect.left,
      plotRect.right,
      dashPaint,
      dash: 4,
      gap: 4,
    );

    _drawAxisBadge(
      canvas: canvas,
      axisRect: priceAxisRect,
      y: y,
      text: NiceTicks.formatPrice(lastCandle.close, priceStep),
      bg: theme.lastValueLabelBg,
      fg: theme.lastValueLabelText,
      fontSize: theme.axisFontSize,
    );
  }

  /// Crosshair: vertical + horizontal dashed lines, plus axis badges.
  static void paintCrosshair({
    required ui.Canvas canvas,
    required ui.Rect plotRect,
    required ui.Rect priceAxisRect,
    required ui.Rect timeAxisRect,
    required ChartTheme theme,
    required Offset position,
    required int dataIndex,
    required Candle candle,
    required TimeScale timeScale,
    required PriceScale priceScale,
    required double priceStep,
  }) {
    final dashPaint = ui.Paint()
      ..color = theme.crosshair
      ..strokeWidth = 1
      ..style = ui.PaintingStyle.stroke;

    // Snap vertical line to bar center.
    final snappedX =
        timeScale
            .indexToX(dataIndex.toDouble(), plotRect.width)
            .roundToDouble() +
        0.5;

    _drawDashedVLine(
      canvas,
      snappedX,
      plotRect.top,
      plotRect.bottom,
      dashPaint,
      dash: 4,
      gap: 4,
    );

    final cy = position.dy.clamp(plotRect.top, plotRect.bottom);
    _drawDashedHLine(
      canvas,
      cy.roundToDouble() + 0.5,
      plotRect.left,
      plotRect.right,
      dashPaint,
      dash: 4,
      gap: 4,
    );

    // Price badge on right axis.
    final price = priceScale.yToPrice(cy, plotRect.height);
    _drawAxisBadge(
      canvas: canvas,
      axisRect: priceAxisRect,
      y: cy,
      text: NiceTicks.formatPrice(price, priceStep),
      bg: theme.crosshairLabelBg,
      fg: theme.crosshairLabelText,
      fontSize: theme.axisFontSize,
    );

    // Time badge on bottom axis.
    final dt = DateTime.fromMillisecondsSinceEpoch(
      candle.time * 1000,
      isUtc: false,
    );
    _drawTimeBadge(
      canvas: canvas,
      axisRect: timeAxisRect,
      x: snappedX,
      text: _formatDateTime(dt),
      bg: theme.crosshairLabelBg,
      fg: theme.crosshairLabelText,
      fontSize: theme.axisFontSize,
    );
  }

  /// Compact OHLC legend in the top-left corner.
  static void paintOhlcLegend({
    required ui.Canvas canvas,
    required ui.Rect plotRect,
    required ChartTheme theme,
    required Candle candle,
    required double priceStep,
  }) {
    final color = candle.isUp ? theme.upColor : theme.downColor;
    final parts = <_LegendPart>[
      _LegendPart('O', theme.text),
      _LegendPart(NiceTicks.formatPrice(candle.open, priceStep), color),
      _LegendPart('H', theme.text),
      _LegendPart(NiceTicks.formatPrice(candle.high, priceStep), color),
      _LegendPart('L', theme.text),
      _LegendPart(NiceTicks.formatPrice(candle.low, priceStep), color),
      _LegendPart('C', theme.text),
      _LegendPart(NiceTicks.formatPrice(candle.close, priceStep), color),
    ];

    var x = plotRect.left + 8.0;
    final y = plotRect.top + 6.0;
    for (var i = 0; i < parts.length; i++) {
      final p = parts[i];
      final tp = TextPainter(
        text: TextSpan(
          text: p.text,
          style: TextStyle(
            color: p.color,
            fontSize: 12,
            fontWeight: i.isOdd ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x, y));
      x += tp.width + 4;
    }
  }

  // ───────── helpers ─────────

  static void _drawAxisBadge({
    required ui.Canvas canvas,
    required ui.Rect axisRect,
    required double y,
    required String text,
    required ui.Color bg,
    required ui.Color fg,
    required double fontSize,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: fg, fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    const padX = 6.0;
    const padY = 3.0;
    final w = tp.width + padX * 2;
    final h = tp.height + padY * 2;
    final left = axisRect.left + 1;
    final top = (y - h / 2).clamp(axisRect.top, axisRect.bottom - h);
    final rect = Rect.fromLTWH(left, top, w, h);
    canvas.drawRect(rect, ui.Paint()..color = bg);
    tp.paint(canvas, Offset(left + padX, top + padY));
  }

  static void _drawTimeBadge({
    required ui.Canvas canvas,
    required ui.Rect axisRect,
    required double x,
    required String text,
    required ui.Color bg,
    required ui.Color fg,
    required double fontSize,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: fg, fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    const padX = 6.0;
    const padY = 3.0;
    final w = tp.width + padX * 2;
    final h = tp.height + padY * 2;
    final left = (x - w / 2).clamp(axisRect.left, axisRect.right - w);
    final top = axisRect.top + 1;
    final rect = Rect.fromLTWH(left, top, w, h);
    canvas.drawRect(rect, ui.Paint()..color = bg);
    tp.paint(canvas, Offset(left + padX, top + padY));
  }

  static void _drawDashedHLine(
    ui.Canvas canvas,
    double y,
    double x1,
    double x2,
    ui.Paint paint, {
    required double dash,
    required double gap,
  }) {
    var x = x1;
    while (x < x2) {
      final next = (x + dash).clamp(x1, x2);
      canvas.drawLine(Offset(x, y), Offset(next, y), paint);
      x += dash + gap;
    }
  }

  static void _drawDashedVLine(
    ui.Canvas canvas,
    double x,
    double y1,
    double y2,
    ui.Paint paint, {
    required double dash,
    required double gap,
  }) {
    var y = y1;
    while (y < y2) {
      final next = (y + dash).clamp(y1, y2);
      canvas.drawLine(Offset(x, y), Offset(x, next), paint);
      y += dash + gap;
    }
  }

  static String _formatDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}

class _LegendPart {
  final String text;
  final ui.Color color;
  const _LegendPart(this.text, this.color);
}
