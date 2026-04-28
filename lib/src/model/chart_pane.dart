import 'package:flutter/foundation.dart';

import '../series/line_series.dart';

/// An additional plot panel rendered below the main candlestick area.
///
/// Each pane has its own auto-fit price scale, derived from the [lines] it
/// contains. Use it to render bounded indicators (RSI, stochastic) or any
/// `(time, value)` series that should not share the candle price scale.
///
/// Panes are stacked under the main plot in the order given, splitting the
/// available height proportionally to [heightRatio]. The main plot keeps
/// whatever vertical space is left.
@immutable
class ChartPane {
  /// Line series rendered inside this pane.
  final List<LineSeries> lines;

  /// Fraction of the **total plot height** allocated to this pane (0..1).
  /// E.g. 0.2 = 20 % of the plot height. Sum of all extra panes is clamped
  /// so the main plot keeps at least 30 % of the height.
  final double heightRatio;

  /// Optional caption rendered in the top-left of the pane.
  final String? title;

  /// Optional fixed reference levels drawn as horizontal lines (e.g. 30 / 70
  /// for RSI). Pairs of (value, color-as-ARGB) — kept primitive to avoid a
  /// Color import here.
  final List<PaneLevel> levels;

  /// Creates an extra pane configuration.
  const ChartPane({
    required this.lines,
    this.heightRatio = 0.2,
    this.title,
    this.levels = const [],
  });
}

/// A horizontal reference line at a fixed [value] inside a [ChartPane].
@immutable
class PaneLevel {
  final double value;
  final int colorArgb;
  final double lineWidth;

  /// Creates a horizontal reference level at [value].
  const PaneLevel({
    required this.value,
    required this.colorArgb,
    this.lineWidth = 1,
  });
}
