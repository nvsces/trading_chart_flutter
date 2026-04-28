import '../model/candle.dart';
import '../model/line_point.dart';

/// Returns the [period]-bar simple moving average of [Candle.close], one
/// [LinePoint] per input candle. The first `period - 1` outputs carry `NaN`,
/// matching the convention used by [LineSeries] to draw a gap during the
/// indicator's warm-up.
List<LinePoint> simpleMovingAverage(List<Candle> candles, int period) {
  if (period <= 0 || candles.isEmpty) return const [];
  final out = List<LinePoint>.filled(
    candles.length,
    const LinePoint(time: 0, value: 0),
  );
  var sum = 0.0;
  for (var i = 0; i < candles.length; i++) {
    sum += candles[i].close;
    if (i >= period) sum -= candles[i - period].close;
    final value = i >= period - 1 ? sum / period : double.nan;
    out[i] = LinePoint(time: candles[i].time, value: value);
  }
  return out;
}

/// Returns the [period]-bar exponential moving average of [Candle.close].
/// Seeded with the SMA of the first [period] closes; outputs before the
/// seed are `NaN`. Smoothing factor is `2 / (period + 1)` (the standard
/// Wilder/EMA convention used by Lightweight Charts and TradingView).
List<LinePoint> exponentialMovingAverage(List<Candle> candles, int period) {
  if (period <= 0 || candles.isEmpty) return const [];
  final n = candles.length;
  final out = List<LinePoint>.filled(
    n,
    const LinePoint(time: 0, value: 0),
  );
  final k = 2.0 / (period + 1);
  var ema = double.nan;
  var seedSum = 0.0;
  for (var i = 0; i < n; i++) {
    final c = candles[i].close;
    if (i < period - 1) {
      seedSum += c;
      out[i] = LinePoint(time: candles[i].time, value: double.nan);
    } else if (i == period - 1) {
      seedSum += c;
      ema = seedSum / period;
      out[i] = LinePoint(time: candles[i].time, value: ema);
    } else {
      ema = c * k + ema * (1 - k);
      out[i] = LinePoint(time: candles[i].time, value: ema);
    }
  }
  return out;
}
