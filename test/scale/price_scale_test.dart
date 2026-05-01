import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:trading_chart_flutter/src/scale/price_scale.dart';

void main() {
  group('fit / autoFit', () {
    test('fit captures min and max of the series', () {
      final ps = PriceScale();
      ps.fit([100.0, 105.0, 99.0, 110.0]);
      expect(ps.minPrice, 99);
      expect(ps.maxPrice, 110);
    });

    test('fit ignores NaN and infinity', () {
      final ps = PriceScale();
      ps.fit([100.0, double.nan, 90.0, double.infinity, 110.0]);
      expect(ps.minPrice, 90);
      expect(ps.maxPrice, 110);
    });

    test('fit on a flat series pads the range', () {
      final ps = PriceScale();
      ps.fit([42.0, 42.0, 42.0]);
      expect(ps.priceRange, greaterThan(0));
      expect(ps.minPrice, lessThan(42));
      expect(ps.maxPrice, greaterThan(42));
    });

    test('fit on an empty iterable falls back to [0,1]', () {
      final ps = PriceScale();
      ps.fit(const Iterable<double>.empty());
      expect(ps.minPrice, 0);
      expect(ps.maxPrice, 1);
    });

    test('fit is a no-op while autoFit is off', () {
      final ps = PriceScale();
      ps.fit([100.0, 200.0]);
      ps.switchToManual();
      ps.fit([1.0, 2.0]);
      expect(ps.minPrice, 100);
      expect(ps.maxPrice, 200);
    });

    test('forceFit applies even in manual mode', () {
      final ps = PriceScale();
      ps.fit([100.0, 200.0]);
      ps.switchToManual();
      ps.forceFit([5.0, 50.0]);
      expect(ps.minPrice, 5);
      expect(ps.maxPrice, 50);
    });
  });

  group('priceToY / yToPrice round-trip', () {
    test('mapping is inverse across the price range', () {
      final ps = PriceScale();
      ps.fit([0.0, 100.0]);
      const height = 400.0;
      for (final p in const [0.0, 25.0, 50.0, 75.0, 100.0]) {
        final y = ps.priceToY(p, height);
        expect(ps.yToPrice(y, height), closeTo(p, 1e-9));
      }
    });

    test('higher prices map to smaller Y (top of the screen)', () {
      final ps = PriceScale();
      ps.fit([0.0, 100.0]);
      final yLow = ps.priceToY(10, 400);
      final yHigh = ps.priceToY(90, 400);
      expect(yHigh, lessThan(yLow));
    });

    test('top and bottom margins eat into the usable region', () {
      final ps = PriceScale(topMarginRatio: 0.1, bottomMarginRatio: 0.2);
      ps.fit([0.0, 100.0]);
      const height = 1000.0;
      // maxPrice should land at top margin (y = 100), not y = 0.
      expect(ps.priceToY(100, height), closeTo(100, 1e-9));
      // minPrice should land at bottom margin boundary (y = 800), not y = 1000.
      expect(ps.priceToY(0, height), closeTo(800, 1e-9));
    });
  });

  group('logarithmic mode', () {
    test('priceToY / yToPrice round-trip in log space', () {
      final ps = PriceScale(logarithmic: true);
      ps.fit([1.0, 1000.0]);
      const height = 400.0;
      for (final p in const [1.0, 3.0, 10.0, 100.0, 316.0, 1000.0]) {
        final y = ps.priceToY(p, height);
        expect(ps.yToPrice(y, height), closeTo(p, 1e-6));
      }
    });

    test('equal log-ratios map to equal screen distances', () {
      // Going from 1 to 10 and from 10 to 100 are both x10. In log mode the
      // two screen distances must be equal; in linear mode they would not.
      final ps = PriceScale(logarithmic: true);
      ps.fit([1.0, 1000.0]);
      const height = 400.0;
      final y1 = ps.priceToY(1, height);
      final y10 = ps.priceToY(10, height);
      final y100 = ps.priceToY(100, height);
      final dA = (y1 - y10).abs();
      final dB = (y10 - y100).abs();
      expect(dA, closeTo(dB, 1e-6));
    });

    test('falls back to linear when minPrice <= 0', () {
      final psLog = PriceScale(logarithmic: true);
      psLog.fit([0.0, 100.0]);
      final psLin = PriceScale();
      psLin.fit([0.0, 100.0]);
      const height = 400.0;
      // Both modes should produce identical Y for the same prices when log
      // is forced off by the non-positive minimum.
      for (final p in const [10.0, 50.0, 90.0]) {
        expect(
          psLog.priceToY(p, height),
          closeTo(psLin.priceToY(p, height), 1e-9),
        );
      }
    });

    test('zoomAtY in log mode keeps anchor price stable', () {
      final ps = PriceScale(logarithmic: true);
      ps.fit([1.0, 1000.0]);
      const height = 400.0;
      const anchorY = 150.0;
      final priceBefore = ps.yToPrice(anchorY, height);
      ps.zoomAtY(anchorY: anchorY, factor: 1.5, height: height);
      final priceAfter = ps.yToPrice(anchorY, height);
      expect(priceAfter, closeTo(priceBefore, 1e-9));
    });

    test('zoomAtY factor>1 shrinks the visible log range', () {
      final ps = PriceScale(logarithmic: true);
      ps.fit([1.0, 1000.0]);
      // Use a custom log of 10 here so the test is human-readable.
      double log10(double v) => math.log(v) / math.ln10;
      final logRangeBefore = log10(ps.maxPrice) - log10(ps.minPrice);
      ps.zoomAtY(anchorY: 200, factor: 2, height: 400);
      final logRangeAfter = log10(ps.maxPrice) - log10(ps.minPrice);
      expect(logRangeAfter, closeTo(logRangeBefore / 2, 1e-9));
    });
  });

  group('zoomAtY (manual price zoom)', () {
    test('keeps the price under anchorY stable', () {
      final ps = PriceScale();
      ps.fit([0.0, 100.0]);
      const height = 400.0;
      const anchorY = 150.0;
      final priceBefore = ps.yToPrice(anchorY, height);
      ps.zoomAtY(anchorY: anchorY, factor: 1.5, height: height);
      final priceAfter = ps.yToPrice(anchorY, height);
      expect(priceAfter, closeTo(priceBefore, 1e-9));
    });

    test('factor > 1 shrinks the visible price range', () {
      final ps = PriceScale();
      ps.fit([0.0, 100.0]);
      final rangeBefore = ps.priceRange;
      ps.zoomAtY(anchorY: 200, factor: 2, height: 400);
      expect(ps.priceRange, closeTo(rangeBefore / 2, 1e-9));
    });

    test('non-positive factor is ignored', () {
      final ps = PriceScale();
      ps.fit([0.0, 100.0]);
      final rangeBefore = ps.priceRange;
      ps.zoomAtY(anchorY: 200, factor: -1, height: 400);
      expect(ps.priceRange, rangeBefore);
    });
  });
}
