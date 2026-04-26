import 'package:flutter/foundation.dart';

@immutable
class Candle {
  final int time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double? volume;

  const Candle({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume,
  });

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
