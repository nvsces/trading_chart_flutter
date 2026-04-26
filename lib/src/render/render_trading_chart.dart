import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../model/candle.dart';
import '../model/chart_theme.dart';
import '../scale/price_scale.dart';
import '../scale/time_scale.dart';
import '../chart_controller.dart';
import '../series/candlestick_series.dart';
import '../series/histogram_series.dart';
import 'axes_painter.dart';
import 'overlay_painter.dart';
import 'time_axis_ticks.dart';

/// The single RenderBox that paints the whole chart scene.
class RenderTradingChart extends RenderBox {
  RenderTradingChart({
    required List<Candle> candles,
    required ChartTheme theme,
    required double initialBarSpacing,
    required double rightOffsetBars,
    required bool showVolume,
  })  : _candles = candles,
        _theme = theme,
        _showVolume = showVolume,
        _timeScale = TimeScale(
          dataLength: candles.length,
          barSpacing: initialBarSpacing,
          rightOffsetBars: rightOffsetBars,
        );

  // ───────── data ─────────

  List<Candle> _candles;
  List<Candle> get candles => _candles;
  set candles(List<Candle> v) {
    if (identical(_candles, v)) return;
    final lengthChanged = _candles.length != v.length;
    final wasFollowing = _isFollowingLatest();
    _candles = v;
    _timeScale.dataLength = v.length;
    if (lengthChanged && wasFollowing) {
      _timeScale.resetToLatest();
    }
    markNeedsPaint();
  }

  ChartTheme _theme;
  ChartTheme get theme => _theme;
  set theme(ChartTheme v) {
    if (_theme == v) return;
    _theme = v;
    markNeedsPaint();
  }

  bool _showVolume;
  bool get showVolume => _showVolume;
  set showVolume(bool v) {
    if (_showVolume == v) return;
    _showVolume = v;
    markNeedsPaint();
  }

  // ───────── scales ─────────

  final TimeScale _timeScale;
  final PriceScale _priceScale = PriceScale();
  // Volume occupies the bottom 20% of the plot (top margin = 0.8).
  final PriceScale _volumeScale =
      PriceScale(topMarginRatio: 0.8, bottomMarginRatio: 0.0);
  TimeScale get timeScale => _timeScale;

  bool _isFollowingLatest() {
    if (_candles.isEmpty) return true;
    final latestIndex = (_candles.length - 1) + _timeScale.rightOffsetBars;
    return (_timeScale.rightLogicalIndex - latestIndex).abs() < 0.5;
  }

  // ───────── interaction ─────────

  void panByPixels(double dx) {
    _timeScale.panByPixels(dx);
    _notifyVisibleRange();
    markNeedsPaint();
  }

  void zoomAt({required double anchorX, required double factor}) {
    final plotWidth = _plotWidth;
    if (plotWidth <= 0) return;
    _timeScale.zoomAt(anchorX: anchorX, factor: factor, width: plotWidth);
    _notifyVisibleRange();
    markNeedsPaint();
  }

  /// Capture the logical index at [anchorX] right now. Use the result as
  /// the stable anchor across many [setSpacingAtAnchorIndex] calls during
  /// a single pinch gesture.
  double captureAnchorIndex(double anchorX) {
    final w = _plotWidth;
    if (w <= 0) return _timeScale.rightLogicalIndex;
    return _timeScale.xToIndex(anchorX, w);
  }

  /// Set bar spacing to [newSpacing] while keeping [anchorIndex] pinned
  /// to [anchorX]. This avoids drift when called rapidly (e.g. trackpad pinch).
  void setSpacingAtAnchor({
    required double anchorIndex,
    required double anchorX,
    required double newSpacing,
  }) {
    final w = _plotWidth;
    if (w <= 0) return;
    _timeScale.setSpacingAtAnchorIndex(
      anchorIndex: anchorIndex,
      anchorX: anchorX,
      newSpacing: newSpacing,
      width: w,
    );
    _notifyVisibleRange();
    markNeedsPaint();
  }

  /// Manually zoom price scale around [anchorY]. Switches to manual mode.
  void priceZoomAt({required double anchorY, required double factor}) {
    final h = _plotHeight;
    if (h <= 0) return;
    _priceScale.switchToManual();
    _priceScale.zoomAtY(anchorY: anchorY, factor: factor, height: h);
    markNeedsPaint();
  }

  /// Re-enable autofit on the price scale.
  void resetPriceAutoFit() {
    _priceScale.switchToAuto();
    markNeedsPaint();
  }

  bool get isPriceAutoFit => _priceScale.autoFit;

  /// Reset bar spacing and follow the latest bar (double-tap on time axis).
  void resetTimeScale({double barSpacing = 8}) {
    _timeScale.barSpacing = barSpacing.clamp(
      TimeScale.minBarSpacing,
      TimeScale.maxBarSpacing,
    );
    _timeScale.resetToLatest();
    _notifyVisibleRange();
    markNeedsPaint();
  }

  /// True if [local] sits within the right-side price axis strip.
  bool isOverPriceAxis(Offset local) {
    return local.dx >= _plotWidth && local.dy <= _plotHeight;
  }

  /// True if [local] sits within the bottom time axis strip.
  bool isOverTimeAxis(Offset local) {
    return local.dy >= _plotHeight && local.dx <= _plotWidth;
  }

  /// True if [local] is inside the plot area (not on either axis).
  bool isOverPlot(Offset local) {
    return local.dx <= _plotWidth && local.dy <= _plotHeight;
  }

  double get plotWidth => _plotWidth;
  double get plotHeight => _plotHeight;

  void scrollToLatest() {
    _timeScale.resetToLatest();
    _notifyVisibleRange();
    markNeedsPaint();
  }

  /// Externally pin the right logical index of the time scale.
  void setRightLogicalIndex(double index) {
    _timeScale.rightLogicalIndex = index;
    _timeScale.ensureInitialized();
    _notifyVisibleRange();
    markNeedsPaint();
  }

  /// Adjust both barSpacing and rightLogicalIndex so the visible range
  /// becomes exactly [from..to] (in logical bar indices).
  void setVisibleLogicalRange(double from, double to) {
    final width = _plotWidth;
    if (width <= 0 || to <= from) return;
    _timeScale.barSpacing = (width / (to - from)).clamp(
      TimeScale.minBarSpacing,
      TimeScale.maxBarSpacing,
    );
    _timeScale.rightLogicalIndex = to;
    _notifyVisibleRange();
    markNeedsPaint();
  }

  VisibleLogicalRange? computeVisibleLogicalRange() {
    if (!hasSize) return null;
    final width = _plotWidth;
    if (width <= 0) return null;
    final visible = _timeScale.visibleBarCount(width);
    final left = _timeScale.rightLogicalIndex - visible + 1;
    return VisibleLogicalRange(from: left, to: _timeScale.rightLogicalIndex);
  }

  /// Allow external code (e.g. controller) to request a repaint.
  void markNeedsPaintExternal() {
    markNeedsPaint();
  }

  /// Listener invoked whenever the visible logical range changes.
  /// Used for history pagination.
  VisibleRangeChanged? onVisibleRangeChanged;

  VisibleLogicalRange? _lastNotifiedRange;
  void _notifyVisibleRange() {
    final cb = onVisibleRangeChanged;
    if (cb == null) return;
    final r = computeVisibleLogicalRange();
    if (r == null) return;
    if (_lastNotifiedRange == r) return;
    _lastNotifiedRange = r;
    cb(r);
  }

  // ───────── crosshair ─────────

  Offset? _crosshair;

  /// Set crosshair position in local coordinates (relative to render box origin).
  /// Pass null to hide.
  void setCrosshair(Offset? local) {
    if (_crosshair == local) return;
    _crosshair = local;
    markNeedsPaint();
  }

  // ───────── layout ─────────

  double get _plotWidth => (size.width - AxesPainter.priceAxisWidth).clamp(0.0, double.infinity);
  double get _plotHeight => (size.height - AxesPainter.timeAxisHeight).clamp(0.0, double.infinity);

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.biggest.isFinite
          ? constraints.biggest
          : constraints.constrain(const Size(400, 300));

  // ───────── paint ─────────

  @override
  void paint(PaintingContext context, Offset offset) {
    _timeScale.ensureInitialized();

    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    final plotRect = ui.Rect.fromLTWH(0, 0, _plotWidth, _plotHeight);
    final priceAxisRect = ui.Rect.fromLTWH(
      _plotWidth,
      0,
      AxesPainter.priceAxisWidth,
      _plotHeight,
    );
    final timeAxisRect = ui.Rect.fromLTWH(
      0,
      _plotHeight,
      _plotWidth,
      AxesPainter.timeAxisHeight,
    );

    // Background
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, size.width, size.height),
      ui.Paint()..color = _theme.background,
    );

    if (_candles.isNotEmpty && _plotWidth > 0 && _plotHeight > 0) {
      // Fit price scale to currently visible range.
      final visible = _timeScale.visibleIntegerRange(_plotWidth);
      final series = CandlestickSeries(data: _candles);
      final pr = series.priceRange(visible.from, visible.to);
      if (pr != null) {
        _priceScale.fit(_expand(pr.min, pr.max));
      }

      // Compute axis ticks.
      final priceTicksRaw = NiceTicks.compute(
        min: _priceScale.minPrice,
        max: _priceScale.maxPrice,
        targetCount: 6,
      );
      final priceStep = priceTicksRaw.length > 1
          ? (priceTicksRaw[1] - priceTicksRaw[0])
          : 1.0;
      final priceTicks = [
        for (final p in priceTicksRaw)
          PriceAxisTick(
            price: p,
            y: _priceScale.priceToY(p, _plotHeight),
            label: NiceTicks.formatPrice(p, priceStep),
          ),
      ];
      final timeTicks = TimeAxisTicks.compute(
        data: _candles,
        timeScale: _timeScale,
        width: _plotWidth,
      );

      // Grid behind series.
      canvas.save();
      canvas.clipRect(plotRect);
      AxesPainter.paintGrid(
        canvas: canvas,
        plotRect: plotRect,
        theme: _theme,
        priceTicks: priceTicks,
        timeTicks: timeTicks,
      );
      // Volume bars under candles (so candles win the visual stack
      // for overlap, but the bars stay readable thanks to opacity).
      if (_showVolume) {
        final vSeries = VolumeHistogramSeries(data: _candles);
        final vr = vSeries.volumeRange(visible.from, visible.to);
        if (vr != null) {
          _volumeScale.fit([vr.min, vr.max]);
          vSeries.paint(
            canvas: canvas,
            size: ui.Size(_plotWidth, _plotHeight),
            timeScale: _timeScale,
            priceScale: _volumeScale,
            theme: _theme,
          );
        }
      }
      // Candles on top.
      series.paint(
        canvas: canvas,
        size: ui.Size(_plotWidth, _plotHeight),
        timeScale: _timeScale,
        priceScale: _priceScale,
        theme: _theme,
      );
      // Last value price line (clipped).
      OverlayPainter.paintLastValue(
        canvas: canvas,
        plotRect: plotRect,
        priceAxisRect: priceAxisRect,
        theme: _theme,
        lastCandle: _candles.last,
        priceScale: _priceScale,
        priceStep: priceStep,
      );
      // Crosshair (also clipped).
      Candle? hoverCandle;
      int? hoverIndex;
      if (_crosshair != null && plotRect.contains(_crosshair!)) {
        final idxF = _timeScale.xToIndex(_crosshair!.dx, _plotWidth);
        final idx = idxF.round().clamp(0, _candles.length - 1);
        hoverIndex = idx;
        hoverCandle = _candles[idx];
        OverlayPainter.paintCrosshair(
          canvas: canvas,
          plotRect: plotRect,
          priceAxisRect: priceAxisRect,
          timeAxisRect: timeAxisRect,
          theme: _theme,
          position: _crosshair!,
          dataIndex: idx,
          candle: hoverCandle,
          timeScale: _timeScale,
          priceScale: _priceScale,
          priceStep: priceStep,
        );
      }
      canvas.restore();

      // Axes (outside clip).
      AxesPainter.paintPriceAxis(
        canvas: canvas,
        axisRect: priceAxisRect,
        theme: _theme,
        ticks: priceTicks,
      );
      AxesPainter.paintTimeAxis(
        canvas: canvas,
        axisRect: timeAxisRect,
        theme: _theme,
        ticks: timeTicks,
      );

      // Last value badge on price axis (above axis ticks).
      OverlayPainter.paintLastValue(
        canvas: canvas,
        plotRect: plotRect,
        priceAxisRect: priceAxisRect,
        theme: _theme,
        lastCandle: _candles.last,
        priceScale: _priceScale,
        priceStep: priceStep,
      );

      // Crosshair badges over axes.
      if (hoverCandle != null && hoverIndex != null) {
        OverlayPainter.paintCrosshair(
          canvas: canvas,
          plotRect: plotRect,
          priceAxisRect: priceAxisRect,
          timeAxisRect: timeAxisRect,
          theme: _theme,
          position: _crosshair!,
          dataIndex: hoverIndex,
          candle: hoverCandle,
          timeScale: _timeScale,
          priceScale: _priceScale,
          priceStep: priceStep,
        );
      }

      // OHLC legend (top-left). Show hovered candle, otherwise last.
      OverlayPainter.paintOhlcLegend(
        canvas: canvas,
        plotRect: plotRect,
        theme: _theme,
        candle: hoverCandle ?? _candles.last,
        priceStep: priceStep,
      );
    }

    canvas.restore();
  }

  Iterable<double> _expand(double min, double max) sync* {
    yield min;
    yield max;
  }

  // ───────── hit test ─────────

  @override
  bool hitTestSelf(Offset position) => true;
}
