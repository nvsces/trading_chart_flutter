import 'package:flutter/foundation.dart';

/// A single `(time, value)` sample used by line overlays such as moving
/// averages or any custom indicator.
///
/// [time] is a Unix timestamp **in seconds**, matching [Candle.time]. Samples
/// align to candles by time, so a moving-average value computed for a candle
/// must carry that candle's [time].
@immutable
class LinePoint {
  /// Unix timestamp in **seconds**.
  final int time;

  /// Indicator value at [time]. May be `NaN` to mark a gap (e.g. the warm-up
  /// period of a moving average); points with `NaN` are skipped during paint.
  final double value;

  /// Creates an immutable `(time, value)` sample.
  const LinePoint({required this.time, required this.value});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinePoint && time == other.time && value == other.value;

  @override
  int get hashCode => Object.hash(time, value);
}
