import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:trading_chart_flutter/trading_chart_flutter.dart';

Candle _bar(int t, double close) => Candle(
      time: t,
      open: close,
      high: close,
      low: close,
      close: close,
    );

void main() {
  group('bollingerBands', () {
    test('first period-1 outputs are NaN on all three bands', () {
      final closes = <double>[1, 2, 3, 4, 5, 6, 7, 8];
      final input = [for (var i = 0; i < closes.length; i++) _bar(i, closes[i])];
      final b = bollingerBands(input, period: 4, stdDevMultiplier: 2);
      for (var i = 0; i < 3; i++) {
        expect(b.middle[i].value.isNaN, isTrue);
        expect(b.upper[i].value.isNaN, isTrue);
        expect(b.lower[i].value.isNaN, isTrue);
      }
      expect(b.middle[3].value.isNaN, isFalse);
    });

    test('middle line equals SMA of the same period', () {
      final input = [for (var i = 0; i < 30; i++) _bar(i, 100.0 + i.toDouble())];
      final b = bollingerBands(input, period: 14, stdDevMultiplier: 2);
      final sma = simpleMovingAverage(input, 14);
      for (var i = 0; i < 30; i++) {
        if (sma[i].value.isNaN) {
          expect(b.middle[i].value.isNaN, isTrue);
        } else {
          expect(b.middle[i].value, closeTo(sma[i].value, 1e-9));
        }
      }
    });

    test('upper and lower are symmetric around middle', () {
      final rng = math.Random(7);
      final input = [
        for (var i = 0; i < 60; i++)
          _bar(i, 100 + rng.nextDouble() * 5),
      ];
      final b = bollingerBands(input, period: 20, stdDevMultiplier: 2);
      for (var i = 19; i < 60; i++) {
        final m = b.middle[i].value;
        final u = b.upper[i].value;
        final l = b.lower[i].value;
        expect(u - m, closeTo(m - l, 1e-9));
      }
    });

    test('on a constant series the bands collapse onto the middle', () {
      final input = [for (var i = 0; i < 20; i++) _bar(i, 42.0)];
      final b = bollingerBands(input, period: 10, stdDevMultiplier: 2);
      for (var i = 9; i < 20; i++) {
        expect(b.middle[i].value, closeTo(42, 1e-9));
        expect(b.upper[i].value, closeTo(42, 1e-9));
        expect(b.lower[i].value, closeTo(42, 1e-9));
      }
    });

    test('matches a textbook computation on a small window', () {
      // Closes: [2, 4, 4, 4, 5, 5, 7, 9]; period=8.
      // Mean = 5; population variance = 4; sd = 2.
      // With multiplier=2 → upper=9, lower=1.
      final closes = <double>[2, 4, 4, 4, 5, 5, 7, 9];
      final input = [for (var i = 0; i < closes.length; i++) _bar(i, closes[i])];
      final b = bollingerBands(input, period: 8, stdDevMultiplier: 2);
      expect(b.middle.last.value, closeTo(5, 1e-9));
      expect(b.upper.last.value, closeTo(9, 1e-9));
      expect(b.lower.last.value, closeTo(1, 1e-9));
    });

    test('preserves the time axis on all three series', () {
      final input = [for (var i = 0; i < 10; i++) _bar(i * 60, 100.0 + i)];
      final b = bollingerBands(input, period: 4);
      for (var i = 0; i < input.length; i++) {
        expect(b.middle[i].time, input[i].time);
        expect(b.upper[i].time, input[i].time);
        expect(b.lower[i].time, input[i].time);
      }
    });

    test('non-positive period or empty input returns empty bands', () {
      expect(bollingerBands(const []).middle, isEmpty);
      expect(bollingerBands([_bar(0, 1)], period: 0).middle, isEmpty);
    });
  });
}
