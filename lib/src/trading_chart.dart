import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'chart_controller.dart';
import 'model/candle.dart';
import 'model/chart_theme.dart';
import 'render/render_trading_chart.dart';

/// A static candlestick chart widget with no built-in gestures.
///
/// Renders [candles] through a single custom render object. Use
/// [InteractiveTradingChart] if you also want pan, zoom and crosshair.
class TradingChart extends LeafRenderObjectWidget {
  /// Creates a static candlestick chart.
  const TradingChart({
    super.key,
    required this.candles,
    this.theme = ChartTheme.dark,
    this.initialBarSpacing = 8,
    this.rightOffsetBars = 8,
    this.showVolume = true,
    this.controller,
    this.onVisibleRangeChanged,
  });

  /// The full ordered list of bars to render. Times must be ascending.
  final List<Candle> candles;

  /// Colors and font sizes used by the chart.
  final ChartTheme theme;

  /// Pixel width allocated per bar at startup. Adjusted later by zoom.
  final double initialBarSpacing;

  /// Number of empty bar slots reserved at the right edge of the plot.
  final double rightOffsetBars;

  /// Show the translucent volume histogram in the bottom 20 % of the plot.
  final bool showVolume;

  /// Optional imperative controller for live updates and viewport control.
  final ChartController? controller;

  /// Optional callback invoked when the visible logical range changes.
  ///
  /// Wire this to load older candles when the user scrolls past the start
  /// of the data.
  final VisibleRangeChanged? onVisibleRangeChanged;

  @override
  RenderTradingChart createRenderObject(BuildContext context) {
    final r = RenderTradingChart(
      candles: candles,
      theme: theme,
      initialBarSpacing: initialBarSpacing,
      rightOffsetBars: rightOffsetBars,
      showVolume: showVolume,
    );
    r.onVisibleRangeChanged = onVisibleRangeChanged;
    controller?.attach(r);
    return r;
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderTradingChart renderObject,
  ) {
    renderObject
      ..candles = candles
      ..theme = theme
      ..showVolume = showVolume
      ..onVisibleRangeChanged = onVisibleRangeChanged;
    if (controller != null) controller!.attach(renderObject);
  }

  @override
  void didUnmountRenderObject(RenderTradingChart renderObject) {
    controller?.detach();
  }
}

enum _GestureZone { plot, priceAxis, timeAxis }

/// TradingView-style interactive wrapper.
///
/// Behavior summary:
/// - Drag in plot: pan X. Single-finger.
/// - Pinch in plot: zoom X around focal point.
/// - Drag on time axis (bottom): zoom X around right edge.
/// - Drag on price axis (right): manual zoom Y around drag start.
/// - Mouse wheel in plot: animated zoom X around cursor.
/// - Long-press in plot: crosshair on, drag moves it. Release: off.
/// - Hover (mouse): crosshair follows immediately.
/// - Double-tap on plot: scroll to latest.
/// - Double-tap on price axis: re-enable autofit.
/// - Double-tap on time axis: reset bar spacing + follow latest.
class InteractiveTradingChart extends StatefulWidget {
  /// Creates an interactive candlestick chart.
  const InteractiveTradingChart({
    super.key,
    required this.candles,
    this.theme = ChartTheme.dark,
    this.initialBarSpacing = 8,
    this.rightOffsetBars = 8,
    this.showVolume = true,
    this.controller,
    this.onVisibleRangeChanged,
  });

  /// The full ordered list of bars to render. Times must be ascending.
  final List<Candle> candles;

  /// Colors and font sizes used by the chart.
  final ChartTheme theme;

  /// Pixel width allocated per bar at startup. Adjusted later by zoom.
  final double initialBarSpacing;

  /// Number of empty bar slots reserved at the right edge of the plot.
  final double rightOffsetBars;

  /// Show the translucent volume histogram in the bottom 20 % of the plot.
  final bool showVolume;

  /// Optional imperative controller for live updates and viewport control.
  final ChartController? controller;

  /// Optional callback invoked when the visible logical range changes.
  ///
  /// Wire this to load older candles when the user scrolls past the start
  /// of the data.
  final VisibleRangeChanged? onVisibleRangeChanged;

  @override
  State<InteractiveTradingChart> createState() =>
      _InteractiveTradingChartState();
}

class _InteractiveTradingChartState extends State<InteractiveTradingChart>
    with TickerProviderStateMixin {
  final GlobalKey _chartKey = GlobalKey();

  RenderTradingChart? get _render =>
      _chartKey.currentContext?.findRenderObject() as RenderTradingChart?;

  // ───────── gesture state ─────────

  _GestureZone _zone = _GestureZone.plot;
  Offset _scaleStartFocal = Offset.zero;
  double _scaleStartBarSpacing = 8;
  double _scaleStartAnchorIndex = 0;
  double _priceDragStartY = 0;
  double _timeAxisDragStartX = 0;
  bool _crosshairActive = false;

  // Inertia (fling) for X-pan in the plot.
  Ticker? _flingTicker;
  double _flingVelocityX = 0; // pixels/sec
  Duration _flingLastTick = Duration.zero;

  // Animated wheel zoom.
  AnimationController? _wheelAnim;
  Offset _wheelAnchor = Offset.zero;
  double _wheelStartSpacing = 8;
  double _wheelTargetSpacing = 8;

  // Velocity tracker for fling.
  VelocityTracker? _panVelocity;

  @override
  void initState() {
    super.initState();
    _wheelAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    )..addListener(_tickWheel);
  }

  @override
  void dispose() {
    _flingTicker?.dispose();
    _wheelAnim?.dispose();
    super.dispose();
  }

  // ───────── zone detection ─────────

  _GestureZone _zoneFor(Offset local) {
    final r = _render;
    if (r == null) return _GestureZone.plot;
    if (r.isOverPriceAxis(local)) return _GestureZone.priceAxis;
    if (r.isOverTimeAxis(local)) return _GestureZone.timeAxis;
    return _GestureZone.plot;
  }

  // ───────── scale (pan + pinch) ─────────

  void _onScaleStart(ScaleStartDetails d) {
    _stopFling();
    final r = _render;
    if (r == null) return;
    _zone = _zoneFor(d.localFocalPoint);
    _scaleStartFocal = d.localFocalPoint;
    _scaleStartBarSpacing = r.timeScale.barSpacing;
    _scaleStartAnchorIndex = r.captureAnchorIndex(d.localFocalPoint.dx);
    _priceDragStartY = d.localFocalPoint.dy;
    _timeAxisDragStartX = d.localFocalPoint.dx;
    _panVelocity = VelocityTracker.withKind(PointerDeviceKind.touch);
    _panVelocity!.addPosition(Duration.zero, d.localFocalPoint);
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final r = _render;
    if (r == null) return;

    // Crosshair mode disables pan/zoom (long-press took over).
    if (_crosshairActive) {
      r.setCrosshair(d.localFocalPoint);
      return;
    }

    _panVelocity?.addPosition(
      Duration(milliseconds: DateTime.now().millisecondsSinceEpoch),
      d.localFocalPoint,
    );

    switch (_zone) {
      case _GestureZone.plot:
        if (d.scale != 1.0) {
          // Pinch zoom X around the original focal point. Set spacing
          // absolutely against the captured anchor to avoid drift.
          r.setSpacingAtAnchor(
            anchorIndex: _scaleStartAnchorIndex,
            anchorX: _scaleStartFocal.dx,
            newSpacing: _scaleStartBarSpacing * d.scale,
          );
        } else if (d.focalPointDelta.dx != 0) {
          r.panByPixels(d.focalPointDelta.dx);
        }
        break;
      case _GestureZone.priceAxis:
        // Drag on price axis = manual Y zoom around the start point.
        final dy = d.localFocalPoint.dy - _priceDragStartY;
        if (dy.abs() < 0.5) return;
        // Drag down = zoom in (factor > 1), drag up = zoom out.
        final factor = math.exp(dy / 200);
        _priceDragStartY = d.localFocalPoint.dy;
        r.priceZoomAt(anchorY: _scaleStartFocal.dy, factor: factor);
        break;
      case _GestureZone.timeAxis:
        // Drag on time axis = zoom X around right edge.
        final dx = d.localFocalPoint.dx - _timeAxisDragStartX;
        if (dx.abs() < 0.5) return;
        // Drag left = zoom out, drag right = zoom in (LWC convention).
        final factor = math.exp(dx / 200);
        _timeAxisDragStartX = d.localFocalPoint.dx;
        r.zoomAt(anchorX: r.plotWidth, factor: factor);
        break;
    }
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (_crosshairActive) return;
    if (_zone != _GestureZone.plot) return;
    final v = _panVelocity?.getVelocity().pixelsPerSecond.dx ?? 0;
    if (v.abs() < 200) return;
    _startFling(v);
  }

  // ───────── fling inertia ─────────

  void _startFling(double velocityPxSec) {
    _flingVelocityX = velocityPxSec;
    _flingLastTick = Duration.zero;
    _flingTicker?.dispose();
    _flingTicker = createTicker(_onFlingTick)..start();
  }

  void _onFlingTick(Duration elapsed) {
    final r = _render;
    if (r == null) {
      _stopFling();
      return;
    }
    final dt = (elapsed - _flingLastTick).inMicroseconds / 1e6;
    _flingLastTick = elapsed;
    if (dt <= 0) return;
    final dx = _flingVelocityX * dt;
    r.panByPixels(dx);
    // Exponential decay (~3.5 = stops in ~1s).
    _flingVelocityX *= math.exp(-3.5 * dt);
    if (_flingVelocityX.abs() < 30) {
      _stopFling();
    }
  }

  void _stopFling() {
    _flingTicker?.dispose();
    _flingTicker = null;
    _flingVelocityX = 0;
  }

  // ───────── mouse wheel + trackpad scroll (animated, accumulating) ─────────

  void _onPointerSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    final r = _render;
    if (r == null) return;
    if (!r.isOverPlot(e.localPosition)) return;
    _stopFling();

    final dy = e.scrollDelta.dy;
    final dx = e.scrollDelta.dx;

    // Trackpad on Chrome reports pinch as fine-grained scroll events with
    // tiny deltas (dy ≈ -1..-4 per tick) and ALSO sends two-finger horizontal
    // scroll the same way (dx component). We handle both:
    //   - vertical delta → zoom (anchor under pointer), instant (no anim,
    //     events arrive often enough that animation just fights itself).
    //   - horizontal delta → pan.
    final isTrackpad = e.kind == PointerDeviceKind.trackpad;

    if (isTrackpad) {
      if (dx != 0) r.panByPixels(-dx);
      if (dy != 0) {
        // Sensitivity tuned for trackpad on Chrome (tiny tick deltas).
        // Negative dy = pinch out / scroll up → zoom in (factor > 1).
        final factor = math.exp(-dy * 0.005);
        final desired = (r.timeScale.barSpacing * factor).clamp(1.0, 60.0);
        final factorClamped = desired / r.timeScale.barSpacing;
        if ((factorClamped - 1).abs() > 1e-4) {
          r.zoomAt(anchorX: e.localPosition.dx, factor: factorClamped);
        }
      }
      return;
    }

    // Mouse wheel: deltas are big (~100) and rare (one per detent).
    // Animate to make discrete steps feel smooth.
    if (dy == 0) return;
    final factor = math.exp(-dy * 0.0035);
    final desired = (r.timeScale.barSpacing * factor).clamp(1.0, 60.0);
    _animateZoomTo(anchor: e.localPosition, newSpacing: desired);
  }

  /// Smoothly tween bar spacing from current value toward [newSpacing],
  /// continuing any in-flight animation rather than restarting from zero.
  /// This is what makes consecutive wheel ticks feel fluid.
  void _animateZoomTo({required Offset anchor, required double newSpacing}) {
    final r = _render;
    if (r == null) return;
    _wheelAnchor = anchor;
    _wheelStartSpacing = r.timeScale.barSpacing;
    _wheelTargetSpacing = newSpacing.clamp(1.0, 60.0);
    // Restart the animation curve from 0 but keep the *start* equal to the
    // current spacing — so even if a previous tween was mid-flight, the
    // next animation begins from where we visually are, not from a stale
    // anchor. The curve is short (140ms) so tweens overlap smoothly.
    _wheelAnim!
      ..stop()
      ..value = 0
      ..forward();
  }

  void _tickWheel() {
    final r = _render;
    if (r == null) return;
    final t = Curves.easeOut.transform(_wheelAnim!.value);
    final desired =
        _wheelStartSpacing + (_wheelTargetSpacing - _wheelStartSpacing) * t;
    final factor = desired / r.timeScale.barSpacing;
    if ((factor - 1).abs() < 1e-4) return;
    r.zoomAt(anchorX: _wheelAnchor.dx, factor: factor);
  }

  // ───────── trackpad pan/zoom (native PanZoom events) ─────────
  //
  // Some platforms (native macOS, some Linux setups) deliver trackpad pinch
  // as PointerPanZoom* events. Chrome on macOS does NOT — it folds them into
  // PointerScrollEvent with kind=trackpad, which we handle in _onPointerSignal.

  Offset _panZoomFocal = Offset.zero;
  double _panZoomStartSpacing = 8;
  double _panZoomAnchorIndex = 0;
  bool _panZoomIsTrackpad = false;

  void _onPanZoomStart(PointerPanZoomStartEvent e) {
    final r = _render;
    if (r == null) return;
    _stopFling();
    _panZoomFocal = e.localPosition;
    _panZoomStartSpacing = r.timeScale.barSpacing;
    _panZoomAnchorIndex = r.captureAnchorIndex(e.localPosition.dx);
    _panZoomIsTrackpad = true;
  }

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent e) {
    final r = _render;
    if (r == null) return;
    if (!_panZoomIsTrackpad) return;

    if (e.scale != 1.0) {
      r.setSpacingAtAnchor(
        anchorIndex: _panZoomAnchorIndex,
        anchorX: _panZoomFocal.dx,
        newSpacing: _panZoomStartSpacing * e.scale,
      );
    }
    if (e.scale == 1.0 && (e.panDelta.dx != 0 || e.panDelta.dy != 0)) {
      if (e.panDelta.dx != 0) r.panByPixels(e.panDelta.dx);
      if (e.panDelta.dy != 0) {
        final factor = math.exp(-e.panDelta.dy * 0.0035);
        r.zoomAt(anchorX: e.localPosition.dx, factor: factor);
      }
    }
  }

  void _onPanZoomEnd(PointerPanZoomEndEvent e) {
    _panZoomIsTrackpad = false;
  }

  // ───────── crosshair (long-press on touch + hover on mouse) ─────────

  void _onHover(PointerHoverEvent e) {
    final r = _render;
    if (r == null) return;
    if (r.isOverPlot(e.localPosition)) {
      r.setCrosshair(e.localPosition);
    } else {
      r.setCrosshair(null);
    }
  }

  void _onExit(PointerExitEvent e) {
    _render?.setCrosshair(null);
  }

  void _onLongPressStart(LongPressStartDetails d) {
    final r = _render;
    if (r == null) return;
    if (!r.isOverPlot(d.localPosition)) return;
    _stopFling();
    _crosshairActive = true;
    r.setCrosshair(d.localPosition);
  }

  void _onLongPressMove(LongPressMoveUpdateDetails d) {
    _render?.setCrosshair(d.localPosition);
  }

  void _onLongPressEnd(LongPressEndDetails d) {
    _crosshairActive = false;
    _render?.setCrosshair(null);
  }

  // ───────── double tap ─────────

  Offset _lastTapDown = Offset.zero;
  void _onTapDown(TapDownDetails d) {
    _lastTapDown = d.localPosition;
  }

  void _onDoubleTap() {
    final r = _render;
    if (r == null) return;
    final zone = _zoneFor(_lastTapDown);
    switch (zone) {
      case _GestureZone.plot:
        r.scrollToLatest();
        break;
      case _GestureZone.priceAxis:
        r.resetPriceAutoFit();
        break;
      case _GestureZone.timeAxis:
        r.resetTimeScale(barSpacing: widget.initialBarSpacing);
        break;
    }
  }

  // ───────── build ─────────

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      onPointerHover: _onHover,
      onPointerPanZoomStart: _onPanZoomStart,
      onPointerPanZoomUpdate: _onPanZoomUpdate,
      onPointerPanZoomEnd: _onPanZoomEnd,
      child: MouseRegion(
        onExit: _onExit,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _onTapDown,
          onDoubleTap: _onDoubleTap,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: _onScaleEnd,
          onLongPressStart: _onLongPressStart,
          onLongPressMoveUpdate: _onLongPressMove,
          onLongPressEnd: _onLongPressEnd,
          child: TradingChart(
            key: _chartKey,
            candles: widget.candles,
            theme: widget.theme,
            initialBarSpacing: widget.initialBarSpacing,
            rightOffsetBars: widget.rightOffsetBars,
            showVolume: widget.showVolume,
            controller: widget.controller,
            onVisibleRangeChanged: widget.onVisibleRangeChanged,
          ),
        ),
      ),
    );
  }
}
