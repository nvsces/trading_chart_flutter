import 'package:flutter_test/flutter_test.dart';
import 'package:trading_chart_flutter/src/scale/time_scale.dart';

void main() {
  TimeScale make({
    int dataLength = 100,
    double barSpacing = 8,
    double rightOffsetBars = 5,
  }) {
    return TimeScale(
      dataLength: dataLength,
      barSpacing: barSpacing,
      rightOffsetBars: rightOffsetBars,
    );
  }

  group('resetToLatest', () {
    test('pins right edge at last index + right offset', () {
      final ts = make(dataLength: 100, rightOffsetBars: 5);
      ts.resetToLatest();
      expect(ts.rightLogicalIndex, 99 + 5);
    });
  });

  group('xToIndex / indexToX round-trip', () {
    test('mapping is inverse for points across the visible area', () {
      final ts = make(dataLength: 200, barSpacing: 10, rightOffsetBars: 0);
      ts.resetToLatest();
      const width = 800.0;
      for (final x in const [0.0, 100.0, 400.0, 750.0, 800.0]) {
        final idx = ts.xToIndex(x, width);
        final back = ts.indexToX(idx, width);
        expect(back, closeTo(x, 1e-9));
      }
    });

    test('right-edge x maps to rightLogicalIndex + 1 (one bar past right)', () {
      // The mapping is continuous: x = width corresponds to leftIndex + visible
      // = rightLogicalIndex + 1.
      final ts = make(dataLength: 100, barSpacing: 8, rightOffsetBars: 0);
      ts.resetToLatest();
      const width = 400.0;
      final idx = ts.xToIndex(width, width);
      expect(idx, closeTo(ts.rightLogicalIndex + 1, 1e-9));
    });
  });

  group('panByPixels', () {
    test('positive pixels scrolls back in time (right index decreases)', () {
      final ts = make(dataLength: 200, barSpacing: 10, rightOffsetBars: 0);
      ts.resetToLatest();
      final before = ts.rightLogicalIndex;
      ts.panByPixels(100); // 10 bars worth
      expect(ts.rightLogicalIndex, closeTo(before - 10, 1e-9));
    });

    test('clamps so at least the minimum bars stay visible on the left', () {
      final ts = make(dataLength: 200, barSpacing: 10, rightOffsetBars: 0);
      ts.resetToLatest();
      ts.panByPixels(1e9); // try to scroll far past the start
      // Implementation keeps right index >= minVisibleBars - 1 = 4.
      expect(ts.rightLogicalIndex, greaterThanOrEqualTo(4));
    });

    test('clamps so user cannot pan past the right offset', () {
      final ts = make(dataLength: 200, barSpacing: 10, rightOffsetBars: 5);
      ts.resetToLatest();
      ts.panByPixels(-1e9); // scroll forward into the future
      expect(ts.rightLogicalIndex, (200 - 1) + 5);
    });
  });

  group('zoomAt', () {
    test('keeps the bar under the anchor stable within rounding', () {
      final ts = make(dataLength: 500, barSpacing: 10, rightOffsetBars: 0);
      ts.resetToLatest();
      const width = 600.0;
      const anchorX = 420.0;
      final anchorIndexBefore = ts.xToIndex(anchorX, width);
      ts.zoomAt(anchorX: anchorX, factor: 1.5, width: width);
      final anchorIndexAfter = ts.xToIndex(anchorX, width);
      expect(anchorIndexAfter, closeTo(anchorIndexBefore, 1e-6));
    });

    test('clamps spacing to maxBarSpacing', () {
      final ts = make(dataLength: 500, barSpacing: 30, rightOffsetBars: 0);
      ts.resetToLatest();
      ts.zoomAt(anchorX: 100, factor: 100, width: 600);
      expect(ts.barSpacing, TimeScale.maxBarSpacing);
    });

    test('clamps spacing to minBarSpacing', () {
      final ts = make(dataLength: 500, barSpacing: 2, rightOffsetBars: 0);
      ts.resetToLatest();
      ts.zoomAt(anchorX: 100, factor: 0.0001, width: 600);
      expect(ts.barSpacing, TimeScale.minBarSpacing);
    });
  });

  group('setSpacingAtAnchorIndex', () {
    test('keeps anchorIndex pinned to anchorX exactly (drift-free pinch)', () {
      // Use a long history with right-offset headroom so clamping never kicks
      // in for the spacings under test.
      final ts = make(dataLength: 5000, barSpacing: 10, rightOffsetBars: 50);
      ts.resetToLatest();
      ts.panByPixels(2000); // move well away from both edges
      const width = 600.0;
      const anchorX = 300.0;
      final anchorIndex = ts.xToIndex(anchorX, width);
      for (final s in const [12.0, 18.0, 7.0, 25.0, 4.0]) {
        ts.setSpacingAtAnchorIndex(
          anchorIndex: anchorIndex,
          anchorX: anchorX,
          newSpacing: s,
          width: width,
        );
        final back = ts.indexToX(anchorIndex, width);
        expect(back, closeTo(anchorX, 1e-6));
      }
    });

    test('cannot push rightLogicalIndex past the right offset', () {
      // When the new spacing would push the right edge into empty space past
      // the latest bar, _clamp keeps it at maxRight. The anchor pin is the
      // best-effort target, the right-edge clamp wins.
      final ts = make(dataLength: 500, barSpacing: 10, rightOffsetBars: 0);
      ts.resetToLatest();
      const width = 600.0;
      const anchorX = 300.0;
      final anchorIndex = ts.xToIndex(anchorX, width);
      ts.setSpacingAtAnchorIndex(
        anchorIndex: anchorIndex,
        anchorX: anchorX,
        newSpacing: 50,
        width: width,
      );
      expect(ts.rightLogicalIndex, lessThanOrEqualTo(499));
    });

    test('ignores invalid width or spacing', () {
      final ts = make();
      ts.resetToLatest();
      final before = ts.rightLogicalIndex;
      final spacingBefore = ts.barSpacing;
      ts.setSpacingAtAnchorIndex(
        anchorIndex: 10,
        anchorX: 100,
        newSpacing: 12,
        width: 0,
      );
      expect(ts.rightLogicalIndex, before);
      expect(ts.barSpacing, spacingBefore);
    });
  });

  group('visibleIntegerRange', () {
    test('returns clamped integer bounds of currently visible bars', () {
      final ts = make(dataLength: 100, barSpacing: 10, rightOffsetBars: 0);
      ts.resetToLatest();
      // width=300, spacing=10 => 30 bars visible, right index = 99
      final r = ts.visibleIntegerRange(300);
      expect(r.to, 99);
      expect(r.from, lessThan(r.to));
      expect(r.from, greaterThanOrEqualTo(0));
    });

    test('clamps from to 0 when scrolled to the start', () {
      final ts = make(dataLength: 50, barSpacing: 10, rightOffsetBars: 0);
      ts.resetToLatest();
      ts.panByPixels(1e9);
      final r = ts.visibleIntegerRange(300);
      expect(r.from, 0);
    });
  });

  group('equality', () {
    test('two scales with identical state compare equal', () {
      final a = make()..resetToLatest();
      final b = make()..resetToLatest();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different rightLogicalIndex breaks equality', () {
      final a = make()..resetToLatest();
      final b = make()..resetToLatest();
      b.panByPixels(10);
      expect(a, isNot(b));
    });
  });
}
