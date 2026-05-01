import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_chart_flutter/trading_chart_flutter.dart';

List<Candle> _series({int n = 100, int startTime = 1700000000}) {
  return [
    for (var i = 0; i < n; i++)
      Candle(
        time: startTime + i * 60,
        open: 100 + i.toDouble(),
        high: 101 + i.toDouble(),
        low: 99 + i.toDouble(),
        close: 100.5 + i.toDouble(),
        volume: 10,
      ),
  ];
}

Widget _wrap(Widget child, {Size size = const Size(800, 400)}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: Center(
        child: SizedBox.fromSize(size: size, child: child),
      ),
    ),
  );
}

void main() {
  group('TradingChart (static)', () {
    testWidgets('renders without throwing for a normal series',
        (tester) async {
      await tester.pumpWidget(_wrap(TradingChart(candles: _series())));
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders empty data without throwing', (tester) async {
      await tester.pumpWidget(_wrap(const TradingChart(candles: [])));
      expect(tester.takeException(), isNull);
    });

    testWidgets('rebuild with new data does not throw', (tester) async {
      await tester.pumpWidget(_wrap(TradingChart(candles: _series(n: 50))));
      await tester.pumpWidget(_wrap(TradingChart(candles: _series(n: 200))));
      expect(tester.takeException(), isNull);
    });
  });

  group('InteractiveTradingChart', () {
    testWidgets('mounts and exposes a visible logical range via controller',
        (tester) async {
      final controller = ChartController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          InteractiveTradingChart(
            candles: _series(),
            controller: controller,
          ),
        ),
      );
      // After first frame the controller is attached and a range is available.
      expect(controller.visibleLogicalRange, isNotNull);
      final r = controller.visibleLogicalRange!;
      expect(r.from, lessThan(r.to));
    });

    testWidgets('controller.setData before mount is applied on attach',
        (tester) async {
      final controller = ChartController();
      addTearDown(controller.dispose);
      // Buffered before any render object exists.
      controller.setData(_series(n: 30));

      await tester.pumpWidget(
        _wrap(
          InteractiveTradingChart(
            candles: const [],
            controller: controller,
          ),
        ),
      );
      // Range should reflect the buffered 30-candle series, not empty data.
      final r = controller.visibleLogicalRange!;
      expect(r.to, greaterThan(0));
    });

    testWidgets('onVisibleRangeChanged fires after pan changes the range',
        (tester) async {
      final ranges = <VisibleLogicalRange>[];
      await tester.pumpWidget(
        _wrap(
          InteractiveTradingChart(
            candles: _series(n: 500),
            onVisibleRangeChanged: ranges.add,
          ),
        ),
      );
      final center = tester.getCenter(find.byType(InteractiveTradingChart));
      await tester.dragFrom(center, const Offset(150, 0));
      await tester.pumpAndSettle();
      expect(ranges, isNotEmpty);
    });

    testWidgets('scrollToTime moves the right edge', (tester) async {
      final controller = ChartController();
      addTearDown(controller.dispose);
      final candles = _series(n: 200);

      await tester.pumpWidget(
        _wrap(
          InteractiveTradingChart(
            candles: candles,
            controller: controller,
          ),
        ),
      );
      final before = controller.visibleLogicalRange!;
      // Target a candle well inside the history.
      controller.scrollToTime(candles[50].time);
      await tester.pump();
      final after = controller.visibleLogicalRange!;
      expect(after.to, lessThan(before.to));
    });

    testWidgets('horizontal drag in the plot pans the visible range left',
        (tester) async {
      final controller = ChartController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          InteractiveTradingChart(
            candles: _series(n: 500),
            controller: controller,
          ),
        ),
      );
      final before = controller.visibleLogicalRange!;
      // Drag content to the right == scroll back in time. We aim for the
      // plot area, not the price axis (right side) or time axis (bottom).
      final center = tester.getCenter(find.byType(InteractiveTradingChart));
      await tester.dragFrom(center, const Offset(200, 0));
      await tester.pumpAndSettle();
      final after = controller.visibleLogicalRange!;
      expect(after.to, lessThan(before.to));
    });

    testWidgets('double-tap in the plot scrolls back to the latest',
        (tester) async {
      final controller = ChartController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          InteractiveTradingChart(
            candles: _series(n: 500),
            controller: controller,
          ),
        ),
      );
      // Move away from latest first.
      controller.scrollToTime(_series(n: 500)[100].time);
      await tester.pump();
      final scrolledAway = controller.visibleLogicalRange!;

      final center = tester.getCenter(find.byType(InteractiveTradingChart));
      // Two quick taps close enough in time for double-tap recognition.
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(center);
      await tester.pumpAndSettle();

      final after = controller.visibleLogicalRange!;
      expect(after.to, greaterThan(scrolledAway.to));
    });

    testWidgets('upsert updates the last candle in place', (tester) async {
      final controller = ChartController();
      addTearDown(controller.dispose);
      final candles = _series(n: 30);

      await tester.pumpWidget(
        _wrap(
          InteractiveTradingChart(
            candles: candles,
            controller: controller,
          ),
        ),
      );
      final lastT = candles.last.time;
      // Same time: should overwrite, not append → range.to stays the same.
      final before = controller.visibleLogicalRange!;
      controller.upsert(
        Candle(time: lastT, open: 1, high: 2, low: 0.5, close: 1.5),
      );
      await tester.pump();
      final after = controller.visibleLogicalRange!;
      expect(after.to, before.to);
    });

    testWidgets('controller detaches cleanly on widget unmount',
        (tester) async {
      final controller = ChartController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          InteractiveTradingChart(
            candles: _series(),
            controller: controller,
          ),
        ),
      );
      expect(controller.visibleLogicalRange, isNotNull);

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      // After unmount the render object is gone — range becomes null.
      expect(controller.visibleLogicalRange, isNull);
    });
  });
}
