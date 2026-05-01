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
  group('relativeStrengthIndex', () {
    test('returns NaN-only series when input is too short', () {
      final input = [bar(0, 1), bar(1, 2)];
      final out = relativeStrengthIndex(input, 14);
      expect(out.length, 2);
      expect(out.every((p) => p.value.isNaN), isTrue);
    });

    test('first period values are NaN, value at index = period is finite', () {
      final closes = <double>[10, 11, 12, 13, 14, 15, 16];
      final input = [for (var i = 0; i < closes.length; i++) bar(i, closes[i])];
      final out = relativeStrengthIndex(input, 5);
      for (var i = 0; i < 5; i++) {
        expect(out[i].value.isNaN, isTrue, reason: 'index $i should be NaN');
      }
      expect(out[5].value.isNaN, isFalse);
    });

    test('strictly rising series produces RSI = 100 (no losses)', () {
      final input = [for (var i = 0; i < 20; i++) bar(i, 1.0 + i.toDouble())];
      final out = relativeStrengthIndex(input, 5);
      for (var i = 5; i < 20; i++) {
        expect(out[i].value, 100);
      }
    });

    test('strictly falling series produces RSI = 0 (no gains)', () {
      final input = [for (var i = 0; i < 20; i++) bar(i, 100.0 - i)];
      final out = relativeStrengthIndex(input, 5);
      for (var i = 5; i < 20; i++) {
        expect(out[i].value, 0);
      }
    });

    test('output is always within [0, 100] for mixed data', () {
      // A simple zig-zag series.
      final closes = [
        for (var i = 0; i < 50; i++) 100.0 + (i.isEven ? 1.0 : -1.5),
      ];
      final input = [for (var i = 0; i < closes.length; i++) bar(i, closes[i])];
      final out = relativeStrengthIndex(input, 14);
      for (final p in out) {
        if (p.value.isNaN) continue;
        expect(p.value, inInclusiveRange(0, 100));
      }
    });

    test('preserves time axis', () {
      final input = [for (var i = 0; i < 20; i++) bar(i * 60, 100.0 + i)];
      final out = relativeStrengthIndex(input, 5);
      for (var i = 0; i < input.length; i++) {
        expect(out[i].time, input[i].time);
      }
    });
  });
}
