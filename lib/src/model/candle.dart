import 'package:flutter/foundation.dart';

/// A single OHLC bar with an optional traded volume.
///
/// All prices are doubles in the instrument's quote currency. [time] is a
/// Unix timestamp **in seconds** (not milliseconds) at the start of the bar.
@immutable
class Candle {
  /// Unix timestamp in **seconds** at the start of the bar.
  final int time;

  /// Opening price.
  final double open;

  /// Highest price reached during the bar.
  final double high;

  /// Lowest price reached during the bar.
  final double low;

  /// Closing price.
  final double close;

  /// Total volume traded during the bar, or `null` if unknown.
  final double? volume;

  /// Creates an immutable OHLC bar.
  const Candle({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume,
  });

  /// `true` when [close] >= [open] (a bullish, "up" candle).
  bool get isUp => close >= open;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Candle &&
          time == other.time &&
          open == other.open &&
          high == other.high &&
          low == other.low &&
          close == other.close &&
          volume == other.volume;

  @override
  int get hashCode => Object.hash(time, open, high, low, close, volume);
}
