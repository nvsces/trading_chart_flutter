import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../model/chart_theme.dart';
import '../scale/price_scale.dart';
import '../scale/time_scale.dart';

class AxesPainter {
  /// Width reserved for the right-side price axis.
  static const double priceAxisWidth = 64;

  /// Height reserved for the bottom time axis.
  static const double timeAxisHeight = 24;

  static void paintGrid({
    required ui.Canvas canvas,
    required ui.Rect plotRect,
    required ChartTheme theme,
    required List<PriceAxisTick> priceTicks,
    required List<TimeAxisTick> timeTicks,
  }) {
    final paint = ui.Paint()
      ..color = theme.gridLine
      ..strokeWidth = 1;
    for (final t in priceTicks) {
      canvas.drawLine(
        ui.Offset(plotRect.left, t.y.roundToDouble() + 0.5),
        ui.Offset(plotRect.right, t.y.roundToDouble() + 0.5),
        paint,
      );
    }
    for (final t in timeTicks) {
      if (!t.isMajor) continue;
      canvas.drawLine(
        ui.Offset(t.x.roundToDouble() + 0.5, plotRect.top),
        ui.Offset(t.x.roundToDouble() + 0.5, plotRect.bottom),
        paint,
      );
    }
  }

  static void paintPriceAxis({
    required ui.Canvas canvas,
    required ui.Rect axisRect,
    required ChartTheme theme,
    required List<PriceAxisTick> ticks,
  }) {
    final linePaint = ui.Paint()
      ..color = theme.axisLine
      ..strokeWidth = 1;
    canvas.drawLine(
      ui.Offset(axisRect.left + 0.5, axisRect.top),
      ui.Offset(axisRect.left + 0.5, axisRect.bottom),
      linePaint,
    );
    for (final t in ticks) {
      _drawText(
        canvas: canvas,
        text: t.label,
        x: axisRect.left + 6,
        y: t.y - 6,
        color: theme.text,
        size: theme.axisFontSize,
      );
    }
  }

  static void paintTimeAxis({
    required ui.Canvas canvas,
    required ui.Rect axisRect,
    required ChartTheme theme,
    required List<TimeAxisTick> ticks,
  }) {
    final linePaint = ui.Paint()
      ..color = theme.axisLine
      ..strokeWidth = 1;
    canvas.drawLine(
      ui.Offset(axisRect.left, axisRect.top + 0.5),
      ui.Offset(axisRect.right, axisRect.top + 0.5),
      linePaint,
    );
    for (final t in ticks) {
      if (!t.isMajor) continue;
      _drawText(
        canvas: canvas,
        text: t.label,
        x: t.x + 4,
        y: axisRect.top + 4,
        color: theme.text,
        size: theme.axisFontSize,
      );
    }
  }

  static void _drawText({
    required ui.Canvas canvas,
    required String text,
    required double x,
    required double y,
    required ui.Color color,
    required double size,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, ui.Offset(x, y));
  }
}
