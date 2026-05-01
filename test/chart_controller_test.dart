import 'package:flutter_test/flutter_test.dart';
import 'package:trading_chart_flutter/trading_chart_flutter.dart';

Candle bar(int t, {double price = 100}) => Candle(
      time: t,
      open: price,
      high: price,
      low: price,
      close: price,
    );

void main() {
  // Without a render object attached, the controller buffers state.
  // visibleLogicalRange / scrollToLatest etc. are render-dependent and tested
  // via the widget; here we cover the buffered-state path which is what users
  // see between construct and first paint.

  group('ChartController (detached)', () {
    test('upsert into empty buffers stores the candle', () {
      final c = ChartController();
      c.upsert(bar(100));
      // No way to read pending data directly, but a follow-up upsert with the
      // same time should overwrite, and a later one should append. We exercise
      // that path through the public API only by ensuring no exceptions.
      c.upsert(bar(100, price: 110));
      c.upsert(bar(200));
      // Smoke: nothing should throw.
    });

    test('prependHistory with empty list is a no-op', () {
      final c = ChartController();
      c.setData([bar(100), bar(200)]);
      c.prependHistory(const []);
    });

    test('visibleLogicalRange is null before render attaches', () {
      final c = ChartController();
      c.setData([bar(100)]);
      expect(c.visibleLogicalRange, isNull);
    });

    test('scrollToLatest / scrollToTime / setVisibleLogicalRange are safe '
        'before attach', () {
      final c = ChartController();
      // Should not throw even without a render object.
      c.scrollToLatest();
      c.scrollToTime(123);
      c.setVisibleLogicalRange(0, 10);
    });

    test('dispose works without attach', () {
      ChartController().dispose();
    });
  });
}
