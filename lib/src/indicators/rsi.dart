import '../model/candle.dart';
import '../model/line_point.dart';

/// Returns the [period]-bar Relative Strength Index of [Candle.close],
/// one [LinePoint] per input candle. Outputs before the first full period
/// carry `NaN`.
///
/// Uses Wilder's smoothing (the standard convention in TradingView and
/// Lightweight Charts): seed = simple average of the first [period] gains
/// and losses, then `avg = (prev * (period - 1) + current) / period`.
List<LinePoint> relativeStrengthIndex(List<Candle> candles, int period) {
  if (period <= 0 || candles.length < period + 1) {
    return [
      for (final c in candles) LinePoint(time: c.time, value: double.nan),
    ];
  }
  final n = candles.length;
  final out = List<LinePoint>.filled(
    n,
    const LinePoint(time: 0, value: 0),
  );

  var gainSum = 0.0;
  var lossSum = 0.0;
  out[0] = LinePoint(time: candles[0].time, value: double.nan);
  for (var i = 1; i <= period; i++) {
    final diff = candles[i].close - candles[i - 1].close;
    if (diff >= 0) {
      gainSum += diff;
    } else {
      lossSum -= diff;
    }
    out[i] = LinePoint(time: candles[i].time, value: double.nan);
  }
  var avgGain = gainSum / period;
  var avgLoss = lossSum / period;
  out[period] = LinePoint(
    time: candles[period].time,
    value: _rsiFromAverages(avgGain, avgLoss),
  );

  for (var i = period + 1; i < n; i++) {
    final diff = candles[i].close - candles[i - 1].close;
    final gain = diff > 0 ? diff : 0.0;
    final loss = diff < 0 ? -diff : 0.0;
    avgGain = (avgGain * (period - 1) + gain) / period;
    avgLoss = (avgLoss * (period - 1) + loss) / period;
    out[i] = LinePoint(
      time: candles[i].time,
      value: _rsiFromAverages(avgGain, avgLoss),
    );
  }
  return out;
}

double _rsiFromAverages(double avgGain, double avgLoss) {
  if (avgLoss == 0) return 100;
  final rs = avgGain / avgLoss;
  return 100 - 100 / (1 + rs);
}
