import 'package:flutter_test/flutter_test.dart';
import 'package:trading_chart_flutter/trading_chart_flutter.dart';

Candle bar(int t, double close) => Candle(
      time: t,
      open: close,
      high: close,
      low: close,
      close: close,
    );

void main() {
  group('simpleMovingAverage', () {
    test('first period-1 outputs are NaN, then matches the running mean', () {
      final closes = [1.0, 2.0, 3.0, 4.0, 5.0];
      final input = [for (var i = 0; i < closes.length; i++) bar(i, closes[i])];
      final out = simpleMovingAverage(input, 3);
      expect(out.length, closes.length);
      expect(out[0].value.isNaN, isTrue);
      expect(out[1].value.isNaN, isTrue);
      expect(out[2].value, closeTo(2, 1e-12)); // (1+2+3)/3
      expect(out[3].value, closeTo(3, 1e-12)); // (2+3+4)/3
      expect(out[4].value, closeTo(4, 1e-12)); // (3+4+5)/3
    });

    test('preserves the time axis', () {
      final input = [bar(100, 1), bar(200, 2), bar(300, 3)];
      final out = simpleMovingAverage(input, 2);
      expect(out.map((p) => p.time).toList(), [100, 200, 300]);
    });

    test('non-positive period or empty input returns empty', () {
      expect(simpleMovingAverage([bar(0, 1)], 0), isEmpty);
      expect(simpleMovingAverage([bar(0, 1)], -1), isEmpty);
      expect(simpleMovingAverage(const [], 5), isEmpty);
    });

    test('period of 1 is the identity (each output = its close)', () {
      final input = [bar(0, 10), bar(1, 20), bar(2, 30)];
      final out = simpleMovingAverage(input, 1);
      expect(out.map((p) => p.value), [10, 20, 30]);
    });
  });

  group('exponentialMovingAverage', () {
    test('seeded with SMA at index period - 1', () {
      final closes = [1.0, 2.0, 3.0, 4.0, 5.0];
      final input = [for (var i = 0; i < closes.length; i++) bar(i, closes[i])];
      final out = exponentialMovingAverage(input, 3);
      expect(out[0].value.isNaN, isTrue);
      expect(out[1].value.isNaN, isTrue);
      expect(out[2].value, closeTo(2, 1e-12)); // SMA(1,2,3)
    });

    test('subsequent values follow the standard EMA recurrence', () {
      // k = 2 / (period + 1) = 2/4 = 0.5 for period=3.
      const k = 2.0 / 4.0;
      final closes = [1.0, 2.0, 3.0, 4.0, 5.0];
      final input = [for (var i = 0; i < closes.length; i++) bar(i, closes[i])];
      final out = exponentialMovingAverage(input, 3);
      final ema3 = out[2].value;
      final ema4 = out[3].value;
      final ema5 = out[4].value;
      expect(ema4, closeTo(4 * k + ema3 * (1 - k), 1e-12));
      expect(ema5, closeTo(5 * k + ema4 * (1 - k), 1e-12));
    });

    test('on a constant series equals the constant after warm-up', () {
      final input = [for (var i = 0; i < 10; i++) bar(i, 42.0)];
      final out = exponentialMovingAverage(input, 4);
      for (var i = 3; i < 10; i++) {
        expect(out[i].value, closeTo(42, 1e-12));
      }
    });

    test('non-positive period or empty input returns empty', () {
      expect(exponentialMovingAverage([bar(0, 1)], 0), isEmpty);
      expect(exponentialMovingAverage(const [], 5), isEmpty);
    });
  });
}
