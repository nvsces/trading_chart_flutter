import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Maps a logical bar index <-> screen X coordinate.
///
/// Bars are addressed by their integer index in the data array.
/// Fractional indices are valid: index 5.5 means "halfway between bar 5 and 6".
class TimeScale {
  TimeScale({
    required this.dataLength,
    required this.barSpacing,
    required this.rightOffsetBars,
  });

  /// Number of candles in the underlying series.
  int dataLength;

  /// Pixel width allocated per bar (incl. gap).
  double barSpacing;

  /// How many empty bars to leave to the right of the last candle.
  double rightOffsetBars;

  /// Logical index pinned to the right edge of the visible area.
  /// `dataLength - 1 + rightOffsetBars` means "follow the latest bar".
  double rightLogicalIndex = 0;

  bool _initialized = false;

  static const double minBarSpacing = 1.0;
  static const double maxBarSpacing = 60.0;

  /// Reset the scale to follow the latest bar.
  void resetToLatest() {
    rightLogicalIndex = (dataLength - 1) + rightOffsetBars;
    _initialized = true;
  }

  void ensureInitialized() {
    if (!_initialized) resetToLatest();
  }

  void setBarSpacing(double v) {
    barSpacing = v.clamp(minBarSpacing, maxBarSpacing);
  }

  /// Adjust spacing while keeping the bar at [anchorX] under the cursor stable.
  void zoomAt({
    required double anchorX,
    required double factor,
    required double width,
  }) {
    final anchorIndex = xToIndex(anchorX, width);
    final next = (barSpacing * factor).clamp(minBarSpacing, maxBarSpacing);
    if (next == barSpacing) return;
    barSpacing = next;
    // Keep anchorIndex at the same anchorX after zoom.
    final newAnchorX = indexToX(anchorIndex, width);
    final dxBars = (newAnchorX - anchorX) / barSpacing;
    rightLogicalIndex += dxBars;
    _clamp();
  }

  /// Set [barSpacing] to an absolute value while keeping the bar at
  /// [anchorIndex] (a logical index captured at the start of a gesture)
  /// pinned to [anchorX] (a screen X also captured at gesture start).
  ///
  /// This avoids the drift that accumulates when [zoomAt] is called many
  /// times in a row with `factor = newSpacing / currentSpacing` — every
  /// call would re-derive `anchorIndex` from the current scale, which has
  /// already shifted from the user's reference frame.
  void setSpacingAtAnchorIndex({
    required double anchorIndex,
    required double anchorX,
    required double newSpacing,
    required double width,
  }) {
    final clamped = newSpacing.clamp(minBarSpacing, maxBarSpacing);
    if (clamped <= 0 || width <= 0) return;
    barSpacing = clamped.toDouble();
    // Solve: indexToX(anchorIndex) == anchorX
    //   anchorX = ((anchorIndex - leftIndex) / visible) * width
    //   leftIndex = rightLogicalIndex - visible + 1
    // => rightLogicalIndex = anchorIndex + (1 - anchorX/width) * visible - 1
    final visible = width / barSpacing;
    rightLogicalIndex = anchorIndex + (1 - anchorX / width) * visible - 1;
    _clamp();
  }

  /// Pan by [pixels] (positive = drag content to the right = scroll back in time).
  void panByPixels(double pixels) {
    rightLogicalIndex -= pixels / barSpacing;
    _clamp();
  }

  static const int _minVisibleBars = 5;

  /// Keep at least [_minVisibleBars] bars on screen and don't pan past
  /// the right offset.
  void _clamp() {
    final maxRight = (dataLength - 1) + rightOffsetBars;
    if (rightLogicalIndex > maxRight) rightLogicalIndex = maxRight;
    // Allow scrolling back into history but keep a few bars visible.
    final minRight = _minVisibleBars - 1.0;
    if (rightLogicalIndex < minRight) rightLogicalIndex = minRight;
  }

  /// Number of bars visible across [width].
  double visibleBarCount(double width) => width / barSpacing;

  /// Logical index at screen x.
  double xToIndex(double x, double width) {
    final visible = visibleBarCount(width);
    final leftIndex = rightLogicalIndex - visible + 1;
    final ratio = x / width;
    return leftIndex + ratio * visible;
  }

  /// Screen x for a (possibly fractional) logical index.
  double indexToX(double index, double width) {
    final visible = visibleBarCount(width);
    final leftIndex = rightLogicalIndex - visible + 1;
    return ((index - leftIndex) / visible) * width;
  }

  /// Inclusive range of integer indices currently in view, clamped to data.
  ({int from, int to}) visibleIntegerRange(double width) {
    final visible = visibleBarCount(width);
    final left = rightLogicalIndex - visible + 1;
    final from = math.max(0, left.floor());
    final to = math.min(dataLength - 1, rightLogicalIndex.ceil());
    return (from: from, to: to);
  }

  @override
  bool operator ==(Object other) =>
      other is TimeScale &&
      other.dataLength == dataLength &&
      other.barSpacing == barSpacing &&
      other.rightOffsetBars == rightOffsetBars &&
      other.rightLogicalIndex == rightLogicalIndex;

  @override
  int get hashCode =>
      Object.hash(dataLength, barSpacing, rightOffsetBars, rightLogicalIndex);
}

@immutable
class TimeAxisTick {
  final int dataIndex;
  final double x;
  final String label;
  final bool isMajor;

  const TimeAxisTick({
    required this.dataIndex,
    required this.x,
    required this.label,
    required this.isMajor,
  });
}
