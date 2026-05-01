import 'dart:math' as math;

import '../model/candle.dart';
import '../model/line_point.dart';

/// The three lines that make up a Bollinger Band overlay.
///
/// All three series have the same length as the input candles. Samples before
/// the indicator's warm-up period carry `NaN`, so a `LineSeries` will draw a
/// gap there.
class BollingerBands {
  final List<LinePoint> middle;
  final List<LinePoint> upper;
  final List<LinePoint> lower;

  const BollingerBands({
    required this.middle,
    required this.upper,
    required this.lower,
  });
}

/// Returns Bollinger Bands of [Candle.close] using a [period]-bar simple
/// moving average for the middle line and `middle ± stdDevMultiplier * σ`
/// for the upper / lower bands.
///
/// Standard parameters are `period: 20, stdDevMultiplier: 2`. Outputs before
/// the first full window carry `NaN`, matching the convention used by
/// [simpleMovingAverage] and [relativeStrengthIndex].
///
/// `σ` is the **population** standard deviation (divide by `period`, not
/// `period - 1`), matching TradingView and Lightweight Charts.
BollingerBands bollingerBands(
  List<Candle> candles, {
  int period = 20,
  double stdDevMultiplier = 2,
}) {
  if (period <= 0 || candles.isEmpty) {
    return const BollingerBands(middle: [], upper: [], lower: []);
  }
  final n = candles.length;
  final mid = List<LinePoint>.filled(n, const LinePoint(time: 0, value: 0));
  final up = List<LinePoint>.filled(n, const LinePoint(time: 0, value: 0));
  final lo = List<LinePoint>.filled(n, const LinePoint(time: 0, value: 0));

  // Rolling sum and sum-of-squares so each step is O(1).
  var sum = 0.0;
  var sumSq = 0.0;
  for (var i = 0; i < n; i++) {
    final c = candles[i].close;
    sum += c;
    sumSq += c * c;
    if (i >= period) {
      final old = candles[i - period].close;
      sum -= old;
      sumSq -= old * old;
    }
    final time = candles[i].time;
    if (i < period - 1) {
      mid[i] = LinePoint(time: time, value: double.nan);
      up[i] = LinePoint(time: time, value: double.nan);
      lo[i] = LinePoint(time: time, value: double.nan);
      continue;
    }
    final mean = sum / period;
    // Population variance, clamped to 0 to absorb tiny negative results from
    // floating-point cancellation when the window is nearly constant.
    final variance = math.max(0.0, sumSq / period - mean * mean);
    final sd = math.sqrt(variance);
    mid[i] = LinePoint(time: time, value: mean);
    up[i] = LinePoint(time: time, value: mean + stdDevMultiplier * sd);
    lo[i] = LinePoint(time: time, value: mean - stdDevMultiplier * sd);
  }
  return BollingerBands(middle: mid, upper: up, lower: lo);
}
