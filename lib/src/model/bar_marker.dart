import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Where a [BarMarker] is anchored vertically relative to its candle.
enum MarkerPosition {
  /// Above the candle's high.
  aboveBar,

  /// Below the candle's low.
  belowBar,

  /// At the candle's close price (inside the wick range).
  inBar,
}

/// Visual shape of a [BarMarker].
enum MarkerShape {
  /// Filled triangle pointing up — typical for "buy" markers below the bar.
  arrowUp,

  /// Filled triangle pointing down — typical for "sell" markers above the bar.
  arrowDown,

  /// Filled circle.
  circle,

  /// Filled square.
  square,
}

/// A small graphical annotation pinned to a candle by [time].
///
/// Markers are time-aligned via [Candle.time] (Unix seconds). Their X follows
/// the time scale, so they pan and zoom with the chart. The Y depends on
/// [position] — and on the candle's high / low / close — so a marker
/// automatically tracks live updates of its candle.
@immutable
class BarMarker {
  /// Unix timestamp **in seconds** of the candle this marker is attached to.
  final int time;

  /// Where to anchor the marker vertically. See [MarkerPosition].
  final MarkerPosition position;

  /// Glyph shape. See [MarkerShape].
  final MarkerShape shape;

  /// Fill color of the glyph (and of the optional [text]).
  final ui.Color color;

  /// Glyph diameter in logical pixels.
  final double size;

  /// Optional short label drawn next to the glyph (e.g. "BUY", "+1.0").
  final String? text;

  /// Creates a marker.
  const BarMarker({
    required this.time,
    required this.position,
    required this.shape,
    required this.color,
    this.size = 12,
    this.text,
  });
}
