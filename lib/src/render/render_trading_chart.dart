import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../model/candle.dart';
import '../model/chart_theme.dart';
import '../scale/price_scale.dart';
import '../scale/time_scale.dart';
import '../chart_controller.dart';
import '../model/bar_marker.dart';
import '../model/chart_pane.dart';
import '../series/candlestick_series.dart';
import '../series/histogram_series.dart';
import '../series/line_series.dart';
import 'axes_painter.dart';
import 'markers_painter.dart';
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
    List<LineSeries> overlays = const [],
    List<ChartPane> panes = const [],
    List<BarMarker> markers = const [],
    bool logarithmicPriceScale = false,
  })  : _candles = candles,
        _theme = theme,
        _showVolume = showVolume,
        _overlays = overlays,
        _panes = panes,
        _markers = markers,
        _paneScales = List.generate(panes.length, (_) => PriceScale()),
        _timeScale = TimeScale(
          dataLength: candles.length,
          barSpacing: initialBarSpacing,
          rightOffsetBars: rightOffsetBars,
        ) {
    _priceScale.logarithmic = logarithmicPriceScale;
  }

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

  List<LineSeries> _overlays;
  List<LineSeries> get overlays => _overlays;
  set overlays(List<LineSeries> v) {
    if (identical(_overlays, v)) return;
    _overlays = v;
    markNeedsPaint();
  }

  List<ChartPane> _panes;
  // One auto-fit price scale per extra pane, kept in lockstep with _panes.
  List<PriceScale> _paneScales;
  List<ChartPane> get panes => _panes;
  set panes(List<ChartPane> v) {
    if (identical(_panes, v)) return;
    if (_panes.length != v.length) {
      _paneScales = List.generate(v.length, (_) => PriceScale());
    }
    _panes = v;
    markNeedsPaint();
  }

  List<BarMarker> _markers;
  List<BarMarker> get markers => _markers;
  set markers(List<BarMarker> v) {
    if (identical(_markers, v)) return;
    _markers = v;
    markNeedsPaint();
  }

  // ───────── scales ─────────

  final TimeScale _timeScale;
  final PriceScale _priceScale = PriceScale();
  // Volume occupies the bottom 20% of the plot (top margin = 0.8).
  final PriceScale _volumeScale = PriceScale(
    topMarginRatio: 0.8,
    bottomMarginRatio: 0.0,
  );
  TimeScale get timeScale => _timeScale;

  bool get logarithmicPriceScale => _priceScale.logarithmic;
  set logarithmicPriceScale(bool v) {
    if (_priceScale.logarithmic == v) return;
    _priceScale.logarithmic = v;
    markNeedsPaint();
  }

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

  /// Height available to the main candlestick plot (excludes any extra panes
  /// and the time axis). Drawings live in this region.
  double get mainPlotHeight => _computeLayout().mainRect.height;

  /// Convert a local screen X to the Unix-seconds time of the bar at that X.
  /// Uses linear interpolation between candles, so the result is meaningful
  /// even between bars and slightly past the last one.
  int timeForX(double x) {
    final n = _candles.length;
    if (n == 0) return 0;
    final idx = _timeScale.xToIndex(x, _plotWidth);
    if (n == 1) return _candles[0].time;
    final first = _candles[0].time;
    final last = _candles[n - 1].time;
    final avgStep = (last - first) / (n - 1);
    if (idx <= 0) return (first + idx * avgStep).round();
    if (idx >= n - 1) {
      return (last + (idx - (n - 1)) * avgStep).round();
    }
    final lo = idx.floor();
    final hi = lo + 1;
    final frac = idx - lo;
    return (_candles[lo].time +
            frac * (_candles[hi].time - _candles[lo].time))
        .round();
  }

  /// Convert a local screen Y (within the main plot) to a price.
  double priceForY(double y) {
    return _priceScale.yToPrice(y, mainPlotHeight);
  }

  /// Convert a `(time, price)` pair back to a local screen offset within the
  /// main plot. Used by gesture code to position drag handles.
  ui.Offset offsetForTimePrice(int time, double price) {
    final x = _xForTime(time);
    final y = _priceScale.priceToY(price, mainPlotHeight);
    return ui.Offset(x, y);
  }

  double xForTimeExternal(int time) => _xForTime(time);
  double yForPriceExternal(double price) =>
      _priceScale.priceToY(price, mainPlotHeight);

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

  double get _plotWidth =>
      (size.width - AxesPainter.priceAxisWidth).clamp(0.0, double.infinity);
  double get _plotHeight =>
      (size.height - AxesPainter.timeAxisHeight).clamp(0.0, double.infinity);

  /// 1px gap between adjacent panes for a visual separator line.
  static const double _paneSeparatorPx = 1;

  /// Compute the vertical layout of the main plot and any extra panes.
  ///
  /// Returns rectangles in render-box-local coordinates for each region:
  /// - [_PaneLayout.mainRect] — main candlestick plot.
  /// - [_PaneLayout.extraRects] — one rect per extra pane, top-to-bottom.
  /// - [_PaneLayout.separators] — Y coordinates of separator lines.
  ///
  /// The total of all extra panes is clamped so the main plot keeps at
  /// least 30 % of [_plotHeight].
  _PaneLayout _computeLayout() {
    final width = _plotWidth;
    final totalH = _plotHeight;
    if (_panes.isEmpty) {
      return _PaneLayout(
        mainRect: ui.Rect.fromLTWH(0, 0, width, totalH),
        extraRects: const [],
        separators: const [],
      );
    }

    // Per-pane requested heights, each clamped to a sane band.
    final requested = [
      for (final p in _panes)
        (p.heightRatio.clamp(0.05, 0.6)) * totalH,
    ];
    var requestedSum = requested.fold<double>(0, (a, b) => a + b);
    final maxExtras = totalH * 0.7;
    if (requestedSum > maxExtras && requestedSum > 0) {
      final scale = maxExtras / requestedSum;
      for (var i = 0; i < requested.length; i++) {
        requested[i] *= scale;
      }
      requestedSum = maxExtras;
    }
    final separatorTotal = _paneSeparatorPx * _panes.length;
    final mainHeight =
        (totalH - requestedSum - separatorTotal).clamp(0.0, totalH);

    final extraRects = <ui.Rect>[];
    final separators = <double>[];
    var y = mainHeight;
    separators.add(y);
    y += _paneSeparatorPx;
    for (var i = 0; i < _panes.length; i++) {
      extraRects.add(ui.Rect.fromLTWH(0, y, width, requested[i]));
      y += requested[i];
      if (i < _panes.length - 1) {
        separators.add(y);
        y += _paneSeparatorPx;
      }
    }

    return _PaneLayout(
      mainRect: ui.Rect.fromLTWH(0, 0, width, mainHeight),
      extraRects: extraRects,
      separators: separators,
    );
  }

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

    final layout = _computeLayout();
    final plotRect = layout.mainRect;
    final priceAxisRect = ui.Rect.fromLTWH(
      _plotWidth,
      0,
      AxesPainter.priceAxisWidth,
      plotRect.height,
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

    if (_candles.isNotEmpty && _plotWidth > 0 && plotRect.height > 0) {
      // Fit price scale to currently visible range.
      final visible = _timeScale.visibleIntegerRange(_plotWidth);
      final series = CandlestickSeries(data: _candles);
      final pr = series.priceRange(visible.from, visible.to);
      final visFromTime = _candles[visible.from].time;
      final visToTime = _candles[visible.to].time;
      if (pr != null) {
        var fitMin = pr.min;
        var fitMax = pr.max;
        // Expand the auto-fit range so visible overlay values stay on screen.
        for (final ov in _overlays) {
          if (!ov.fitToPriceScale) continue;
          final r = ov.valueRangeForTimeWindow(visFromTime, visToTime);
          if (r == null) continue;
          if (r.min < fitMin) fitMin = r.min;
          if (r.max > fitMax) fitMax = r.max;
        }
        _priceScale.fit(_expand(fitMin, fitMax));
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
            y: _priceScale.priceToY(p, plotRect.height),
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
            size: ui.Size(_plotWidth, plotRect.height),
            timeScale: _timeScale,
            priceScale: _volumeScale,
            theme: _theme,
          );
        }
      }
      // Candles on top.
      series.paint(
        canvas: canvas,
        size: ui.Size(_plotWidth, plotRect.height),
        timeScale: _timeScale,
        priceScale: _priceScale,
        theme: _theme,
      );
      // Overlay line series (e.g. moving averages) on top of candles.
      if (_overlays.isNotEmpty) {
        for (final ov in _overlays) {
          ov.paint(
            canvas: canvas,
            size: ui.Size(_plotWidth, plotRect.height),
            timeScale: _timeScale,
            priceScale: _priceScale,
            xForTime: _xForTime,
          );
        }
      }
      // Bar markers (after overlays so they sit visually on top of MA lines).
      if (_markers.isNotEmpty) {
        MarkersPainter.paint(
          canvas: canvas,
          size: ui.Size(_plotWidth, plotRect.height),
          theme: _theme,
          markers: _markers,
          candles: _candles,
          priceScale: _priceScale,
          xForTime: _xForTime,
        );
      }
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
      // Crosshair (also clipped). Bar index is shared by all panes; only the
      // panel that contains the cursor gets the horizontal line + Y badge.
      Candle? hoverCandle;
      int? hoverIndex;
      final crosshairInMain =
          _crosshair != null && plotRect.contains(_crosshair!);
      if (_crosshair != null) {
        final cx = _crosshair!.dx;
        if (cx >= 0 && cx <= _plotWidth) {
          final idxF = _timeScale.xToIndex(cx, _plotWidth);
          final idx = idxF.round().clamp(0, _candles.length - 1);
          hoverIndex = idx;
          hoverCandle = _candles[idx];
        }
      }
      if (hoverCandle != null && crosshairInMain) {
        OverlayPainter.paintCrosshair(
          canvas: canvas,
          plotRect: plotRect,
          priceAxisRect: priceAxisRect,
          timeAxisRect: timeAxisRect,
          theme: _theme,
          position: _crosshair!,
          dataIndex: hoverIndex!,
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

      // Crosshair badges over axes (main pane only).
      if (hoverCandle != null && crosshairInMain) {
        OverlayPainter.paintCrosshair(
          canvas: canvas,
          plotRect: plotRect,
          priceAxisRect: priceAxisRect,
          timeAxisRect: timeAxisRect,
          theme: _theme,
          position: _crosshair!,
          dataIndex: hoverIndex!,
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

      // ───── extra panes ─────
      for (var i = 0; i < _panes.length; i++) {
        _paintPane(
          canvas: canvas,
          pane: _panes[i],
          paneRect: layout.extraRects[i],
          paneScale: _paneScales[i],
          visFromTime: visFromTime,
          visToTime: visToTime,
          hoverIndex: hoverIndex,
          hoverCandle: hoverCandle,
          timeAxisRect: timeAxisRect,
        );
      }

      // Pane separators.
      if (layout.separators.isNotEmpty) {
        final sepPaint = ui.Paint()
          ..color = _theme.axisLine
          ..strokeWidth = 1;
        for (final sy in layout.separators) {
          final y = sy.roundToDouble() + 0.5;
          canvas.drawLine(
            ui.Offset(0, y),
            ui.Offset(_plotWidth, y),
            sepPaint,
          );
        }
      }

      // Time-axis crosshair vertical line spans all panes (drawn after panes
      // so it sits on top of pane content but under the bottom time axis).
      if (hoverCandle != null && hoverIndex != null) {
        canvas.save();
        canvas.clipRect(ui.Rect.fromLTWH(0, 0, _plotWidth, _plotHeight));
        OverlayPainter.paintCrosshairVertical(
          canvas: canvas,
          fromY: 0,
          toY: _plotHeight,
          x: _timeScale.indexToX(hoverIndex.toDouble(), _plotWidth),
          theme: _theme,
        );
        canvas.restore();
        // Time badge if cursor is anywhere over plot column.
        if (!crosshairInMain) {
          OverlayPainter.paintTimeOnlyBadge(
            canvas: canvas,
            timeAxisRect: timeAxisRect,
            x: _timeScale.indexToX(hoverIndex.toDouble(), _plotWidth),
            unixSeconds: hoverCandle.time,
            theme: _theme,
          );
        }
      }
    }

    canvas.restore();
  }

  Iterable<double> _expand(double min, double max) sync* {
    yield min;
    yield max;
  }

  /// Paint one extra pane: auto-fit its [paneScale], draw grid + lines +
  /// fixed levels + the price axis on the right strip. Also draws the
  /// per-pane crosshair Y line if the cursor is inside [paneRect].
  void _paintPane({
    required ui.Canvas canvas,
    required ChartPane pane,
    required ui.Rect paneRect,
    required PriceScale paneScale,
    required int visFromTime,
    required int visToTime,
    required int? hoverIndex,
    required Candle? hoverCandle,
    required ui.Rect timeAxisRect,
  }) {
    if (paneRect.height <= 0) return;

    // Collect value range across visible window from all lines + levels.
    double? minV;
    double? maxV;
    for (final ln in pane.lines) {
      if (!ln.fitToPriceScale) continue;
      final r = ln.valueRangeForTimeWindow(visFromTime, visToTime);
      if (r == null) continue;
      minV = minV == null ? r.min : (r.min < minV ? r.min : minV);
      maxV = maxV == null ? r.max : (r.max > maxV ? r.max : maxV);
    }
    for (final lvl in pane.levels) {
      minV = minV == null ? lvl.value : (lvl.value < minV ? lvl.value : minV);
      maxV = maxV == null ? lvl.value : (lvl.value > maxV ? lvl.value : maxV);
    }
    if (minV == null || maxV == null) return;
    paneScale.fit(_expand(minV, maxV));

    final paneAxisRect = ui.Rect.fromLTWH(
      _plotWidth,
      paneRect.top,
      AxesPainter.priceAxisWidth,
      paneRect.height,
    );

    // Per-pane price ticks.
    final ticksRaw = NiceTicks.compute(
      min: paneScale.minPrice,
      max: paneScale.maxPrice,
      targetCount: 4,
    );
    final step = ticksRaw.length > 1 ? (ticksRaw[1] - ticksRaw[0]) : 1.0;
    final ticks = [
      for (final v in ticksRaw)
        PriceAxisTick(
          price: v,
          // priceToY returns Y in [0..paneRect.height]; offset to absolute.
          y: paneRect.top + paneScale.priceToY(v, paneRect.height),
          label: NiceTicks.formatPrice(v, step),
        ),
    ];

    // Clip + grid + lines + levels.
    canvas.save();
    canvas.clipRect(paneRect);

    final gridPaint = ui.Paint()
      ..color = _theme.gridLine
      ..strokeWidth = 1;
    for (final t in ticks) {
      final y = t.y.roundToDouble() + 0.5;
      canvas.drawLine(
        ui.Offset(paneRect.left, y),
        ui.Offset(paneRect.right, y),
        gridPaint,
      );
    }

    canvas.translate(0, paneRect.top);
    for (final ln in pane.lines) {
      ln.paint(
        canvas: canvas,
        size: ui.Size(_plotWidth, paneRect.height),
        timeScale: _timeScale,
        priceScale: paneScale,
        xForTime: _xForTime,
      );
    }
    for (final lvl in pane.levels) {
      final y = paneScale.priceToY(lvl.value, paneRect.height);
      final paint = ui.Paint()
        ..color = ui.Color(lvl.colorArgb)
        ..strokeWidth = lvl.lineWidth
        ..style = ui.PaintingStyle.stroke;
      canvas.drawLine(
        ui.Offset(0, y.roundToDouble() + 0.5),
        ui.Offset(_plotWidth, y.roundToDouble() + 0.5),
        paint,
      );
    }
    canvas.restore();

    // Pane title.
    final title = pane.title;
    if (title != null && title.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: title,
          style: TextStyle(color: _theme.text, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, ui.Offset(paneRect.left + 8, paneRect.top + 4));
    }

    // Pane price axis (ticks rendered in absolute Y).
    AxesPainter.paintPriceAxis(
      canvas: canvas,
      axisRect: paneAxisRect,
      theme: _theme,
      ticks: ticks,
    );

    // Crosshair Y-line + price badge if cursor sits inside this pane.
    if (_crosshair != null && paneRect.contains(_crosshair!)) {
      final yInPane = _crosshair!.dy - paneRect.top;
      final value = paneScale.yToPrice(yInPane, paneRect.height);
      OverlayPainter.paintPaneCrosshair(
        canvas: canvas,
        paneRect: paneRect,
        priceAxisRect: paneAxisRect,
        theme: _theme,
        y: _crosshair!.dy,
        value: value,
        valueStep: step,
      );
    }
  }

  /// Map a Unix-seconds [time] to a screen X using the current time scale.
  /// Times outside the data range are linearly extrapolated using the
  /// average bar duration, so an overlay sample slightly past the last
  /// candle still lands at a sensible X.
  double _xForTime(int time) {
    final n = _candles.length;
    if (n == 0) return 0;
    if (n == 1) return _timeScale.indexToX(0, _plotWidth);
    final first = _candles[0].time;
    final last = _candles[n - 1].time;
    final avgStep = (last - first) / (n - 1);
    if (time <= first) {
      final idx = avgStep > 0 ? (time - first) / avgStep : 0.0;
      return _timeScale.indexToX(idx, _plotWidth);
    }
    if (time >= last) {
      final idx = avgStep > 0
          ? (n - 1) + (time - last) / avgStep
          : (n - 1).toDouble();
      return _timeScale.indexToX(idx, _plotWidth);
    }
    // Binary search: find lo such that candles[lo].time <= time < candles[lo+1].time.
    var lo = 0;
    var hi = n - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (_candles[mid].time <= time) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final tLo = _candles[lo].time;
    final tHi = _candles[hi].time;
    final span = tHi - tLo;
    final frac = span > 0 ? (time - tLo) / span : 0.0;
    return _timeScale.indexToX(lo + frac, _plotWidth);
  }

  // ───────── hit test ─────────

  @override
  bool hitTestSelf(Offset position) => true;
}

/// Pixel layout of the main plot and any extra panes, in render-box-local
/// coordinates. The price axis lives to the right of every rect; the time
/// axis runs along the bottom of the last rect.
class _PaneLayout {
  final ui.Rect mainRect;
  final List<ui.Rect> extraRects;
  final List<double> separators;
  const _PaneLayout({
    required this.mainRect,
    required this.extraRects,
    required this.separators,
  });
}
