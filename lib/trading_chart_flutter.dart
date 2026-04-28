/// Pure-Dart candlestick trading chart for Flutter.
///
/// See [TradingChart] for a static chart that renders a list of [Candle]s,
/// or [InteractiveTradingChart] for the same chart with TradingView-style
/// pan, zoom, crosshair and axis-drag gestures.
///
/// Use a [ChartController] to drive updates imperatively (live ticks,
/// history pagination, programmatic scroll).
library;

export 'src/chart_controller.dart'
    show ChartController, VisibleLogicalRange, VisibleRangeChanged;
export 'src/indicators/moving_average.dart'
    show simpleMovingAverage, exponentialMovingAverage;
export 'src/model/candle.dart';
export 'src/model/chart_theme.dart';
export 'src/model/line_point.dart';
export 'src/series/line_series.dart' show LineSeries;
export 'src/trading_chart.dart' show TradingChart, InteractiveTradingChart;
