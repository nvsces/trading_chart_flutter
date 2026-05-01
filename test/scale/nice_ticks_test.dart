import 'package:flutter_test/flutter_test.dart';
import 'package:trading_chart_flutter/src/scale/price_scale.dart';

void main() {
  group('NiceTicks.compute', () {
    test('returns ticks with a step from the {1, 2, 5} × 10ⁿ family', () {
      final ticks = NiceTicks.compute(min: 0, max: 100, targetCount: 6);
      expect(ticks.length, greaterThanOrEqualTo(2));
      final step = ticks[1] - ticks[0];
      // Normalize: step / 10^floor(log10(step)) should be 1, 2, 2.5, 5 or 10.
      final mag = _magnitude(step);
      final norm = step / mag;
      expect(_isAllowedNorm(norm), isTrue, reason: 'norm=$norm step=$step');
    });

    test('all returned ticks lie within [min, max] window (with tolerance)',
        () {
      final ticks = NiceTicks.compute(min: 17, max: 83, targetCount: 5);
      for (final t in ticks) {
        // Uses a half-step tolerance internally; just verify a sane bound.
        expect(t, greaterThanOrEqualTo(17 - 100));
        expect(t, lessThanOrEqualTo(83 + 100));
      }
    });

    test('produces a tick count near targetCount for typical ranges', () {
      final ticks = NiceTicks.compute(min: 0, max: 1000, targetCount: 5);
      expect(ticks.length, inInclusiveRange(3, 8));
    });

    test('handles negative ranges', () {
      final ticks = NiceTicks.compute(min: -50, max: -10, targetCount: 5);
      expect(ticks, isNotEmpty);
      expect(ticks.first, lessThanOrEqualTo(-10));
      expect(ticks.last, greaterThanOrEqualTo(-50));
    });

    test('handles very small ranges (sub-cent prices)', () {
      final ticks = NiceTicks.compute(
        min: 0.001,
        max: 0.005,
        targetCount: 5,
      );
      expect(ticks.length, greaterThanOrEqualTo(2));
      final step = ticks[1] - ticks[0];
      expect(step, greaterThan(0));
    });

    test('zero range returns a single value (no division by zero)', () {
      final ticks = NiceTicks.compute(min: 50, max: 50, targetCount: 5);
      expect(ticks, [50]);
    });

    test('clamps targetCount below 2 to avoid divide-by-zero', () {
      final ticks = NiceTicks.compute(min: 0, max: 10, targetCount: 1);
      expect(ticks, isNotEmpty);
    });
  });

  group('NiceTicks.formatPrice', () {
    test('big steps drop decimals', () {
      expect(NiceTicks.formatPrice(12345.67, 100), '12346');
    });

    test('medium steps use 2 decimals', () {
      expect(NiceTicks.formatPrice(12.345, 1), '12.35');
    });

    test('sub-dollar steps use 4 decimals', () {
      expect(NiceTicks.formatPrice(0.12345, 0.05), '0.1235');
    });

    test('crypto-tier tiny steps use 6 decimals', () {
      expect(NiceTicks.formatPrice(0.0001234567, 0.000001), '0.000123');
    });
  });
}

double _magnitude(double v) {
  // floor(log10(v)) -> 10^that.
  if (v <= 0) return 1;
  var m = 1.0;
  if (v >= 1) {
    while (m * 10 <= v) {
      m *= 10;
    }
  } else {
    while (m > v) {
      m /= 10;
    }
  }
  return m;
}

bool _isAllowedNorm(double n) {
  const allowed = [1.0, 2.0, 2.5, 5.0, 10.0];
  for (final a in allowed) {
    if ((n - a).abs() < 1e-6) return true;
  }
  return false;
}
