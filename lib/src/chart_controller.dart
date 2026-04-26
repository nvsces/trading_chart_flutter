import 'package:flutter/foundation.dart';

import 'model/candle.dart';
import 'render/render_trading_chart.dart';

/// The portion of the time scale currently visible on screen, expressed in
/// **logical bar indices** (the position of a bar in the data list, possibly
/// fractional at the edges).
@immutable
class VisibleLogicalRange {
  /// Leftmost visible logical index (may be negative if the user scrolled
  /// past the start of the data).
  final double from;

  /// Rightmost visible logical index (may be greater than `data.length - 1`
  /// because of the right offset).
  final double to;

  /// Creates a logical range descriptor.
  const VisibleLogicalRange({required this.from, required this.to});

  @override
  bool operator ==(Object other) =>
      other is VisibleLogicalRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'VisibleLogicalRange($from..$to)';
}

/// Callback fired whenever the visible logical range changes.
///
/// Wire this to your data source to load older candles when [VisibleLogicalRange.from]
/// drops below a small threshold (history pagination).
typedef VisibleRangeChanged = void Function(VisibleLogicalRange range);

/// Imperative API for the chart, in the spirit of Lightweight Charts.
///
/// Attach via [InteractiveTradingChart.controller]. The controller is
/// bound to the underlying [RenderTradingChart] when the widget mounts;
/// before that, calls are buffered into the initial state and applied on attach.
class ChartController extends ChangeNotifier {
  RenderTradingChart? _render;

  // Buffered state used before attach.
  List<Candle>? _pendingData;

  // ───────── attach lifecycle ─────────

  /// Bind the controller to the underlying render object. Called by
  /// [TradingChart] when the widget is mounted; you should not call this
  /// directly.
  void attach(RenderTradingChart render) {
    _render = render;
    if (_pendingData != null) {
      render.candles = _pendingData!;
      _pendingData = null;
    }
  }

  /// Release the binding to the render object. Called by [TradingChart]
  /// when the widget is unmounted; you should not call this directly.
  void detach() {
    _render = null;
  }

  // ───────── data ─────────

  /// Replace the candle list. If the chart was following the latest candle,
  /// it will continue to do so on the new data.
  void setData(List<Candle> candles) {
    final r = _render;
    if (r == null) {
      _pendingData = candles;
      return;
    }
    r.candles = candles;
  }

  /// Append or update a single candle by [Candle.time].
  /// If [candle.time] matches the last candle's time, the last candle is
  /// updated in place. If it's strictly newer, the candle is appended.
  /// Older times are ignored (use [prependHistory] for those).
  void upsert(Candle candle) {
    final r = _render;
    final current = r?.candles ?? _pendingData ?? const <Candle>[];
    if (current.isEmpty) {
      setData([candle]);
      return;
    }
    final last = current.last;
    if (candle.time == last.time) {
      final next = List<Candle>.of(current);
      next[next.length - 1] = candle;
      setData(next);
    } else if (candle.time > last.time) {
      setData([...current, candle]);
    } else {
      // Older bars are ignored here.
    }
  }

  /// Prepend older candles to the front of the data array (e.g. after
  /// loading a history page). Duplicates by [Candle.time] are dropped.
  void prependHistory(List<Candle> older) {
    if (older.isEmpty) return;
    final r = _render;
    final current = r?.candles ?? _pendingData ?? const <Candle>[];

    final knownTimes = <int>{for (final c in current) c.time};
    final filtered = older.where((c) => !knownTimes.contains(c.time)).toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    if (filtered.isEmpty) return;

    final addedCount = filtered.length;
    final next = [...filtered, ...current];

    if (r == null) {
      _pendingData = next;
      return;
    }

    // Keep the visually anchored bars in place: shift rightLogicalIndex
    // by the number of bars we just inserted on the left.
    final ts = r.timeScale;
    final wasFollowing =
        (ts.rightLogicalIndex - ((current.length - 1) + ts.rightOffsetBars))
            .abs() <
        0.5;
    r.candles = next;
    if (!wasFollowing) {
      ts.rightLogicalIndex += addedCount;
      r.markNeedsPaintExternal();
    }
  }

  // ───────── viewport ─────────

  /// Pin the right edge of the chart back to the latest bar (with the
  /// configured right offset). Equivalent to a double-tap in the plot area.
  void scrollToLatest() {
    _render?.scrollToLatest();
  }

  /// Scroll so [unixSeconds] sits near the right edge.
  /// No-op if the time is not present in the current data.
  void scrollToTime(int unixSeconds) {
    final r = _render;
    if (r == null) return;
    final idx = _findIndexByTime(r.candles, unixSeconds);
    if (idx == null) return;
    r.setRightLogicalIndex(idx + r.timeScale.rightOffsetBars);
  }

  /// Force the visible logical range to [from..to] (fractional indices ok).
  void setVisibleLogicalRange(double from, double to) {
    final r = _render;
    if (r == null) return;
    r.setVisibleLogicalRange(from, to);
  }

  /// Currently visible logical range, or null if not laid out yet.
  VisibleLogicalRange? get visibleLogicalRange {
    final r = _render;
    if (r == null) return null;
    return r.computeVisibleLogicalRange();
  }

  static int? _findIndexByTime(List<Candle> data, int t) {
    if (data.isEmpty) return null;
    // Linear scan is fine for typical sizes; data is time-ordered so we
    // could binary-search if it ever matters.
    for (var i = 0; i < data.length; i++) {
      if (data[i].time == t) return i;
      if (data[i].time > t) return i == 0 ? 0 : i - 1;
    }
    return data.length - 1;
  }
}
