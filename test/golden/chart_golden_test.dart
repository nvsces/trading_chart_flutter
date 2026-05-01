import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_chart_flutter/trading_chart_flutter.dart';

/// Deterministic synthetic candle series. The same seed always yields the
/// same data, so goldens are stable across machines.
List<Candle> _series({int n = 120, int seed = 1}) {
  final rng = math.Random(seed);
  final out = <Candle>[];
  var price = 100.0;
  const startTime = 1700000000;
  for (var i = 0; i < n; i++) {
    final drift = (rng.nextDouble() - 0.48) * 2.0;
    final open = price;
    final close = price + drift;
    final high = math.max(open, close) + rng.nextDouble() * 0.8;
    final low = math.min(open, close) - rng.nextDouble() * 0.8;
    final vol = 50 + rng.nextDouble() * 100;
    out.add(Candle(
      time: startTime + i * 60,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: vol,
    ));
    price = close;
  }
  return out;
}

Widget _frame(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(),
      child: ColoredBox(
        color: const Color(0xFF000000),
        child: SizedBox(
          width: 800,
          height: 400,
          child: child,
        ),
      ),
    ),
  );
}

Future<void> _pumpAndMatch(
  WidgetTester tester,
  Widget chart,
  String fileName,
) async {
  await tester.pumpWidget(_frame(chart));
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(TradingChart),
    matchesGoldenFile('goldens/$fileName'),
  );
}

void main() {
  testWidgets('dark theme, full data with volume', (tester) async {
    await _pumpAndMatch(
      tester,
      TradingChart(
        candles: _series(),
        theme: ChartTheme.dark,
      ),
      'chart_dark.png',
    );
  });

  testWidgets('light theme, no volume', (tester) async {
    await _pumpAndMatch(
      tester,
      TradingChart(
        candles: _series(seed: 2),
        theme: ChartTheme.light,
        showVolume: false,
      ),
      'chart_light_no_volume.png',
    );
  });

  testWidgets('dark theme with SMA overlay', (tester) async {
    final candles = _series(seed: 3);
    await _pumpAndMatch(
      tester,
      TradingChart(
        candles: candles,
        theme: ChartTheme.dark,
        overlays: [
          LineSeries(
            data: simpleMovingAverage(candles, 14),
            color: const Color(0xFFFFD24A),
            lineWidth: 2,
          ),
        ],
      ),
      'chart_with_sma.png',
    );
  });

  testWidgets('dark theme with bar markers', (tester) async {
    final candles = _series(seed: 4);
    await _pumpAndMatch(
      tester,
      TradingChart(
        candles: candles,
        theme: ChartTheme.dark,
        markers: [
          BarMarker(
            time: candles[20].time,
            position: MarkerPosition.belowBar,
            shape: MarkerShape.arrowUp,
            color: const Color(0xFF26A69A),
            text: 'B',
          ),
          BarMarker(
            time: candles[80].time,
            position: MarkerPosition.aboveBar,
            shape: MarkerShape.arrowDown,
            color: const Color(0xFFEF5350),
            text: 'S',
          ),
        ],
      ),
      'chart_with_markers.png',
    );
  });

  testWidgets('dark theme with RSI pane', (tester) async {
    final candles = _series(seed: 5);
    await _pumpAndMatch(
      tester,
      TradingChart(
        candles: candles,
        theme: ChartTheme.dark,
        panes: [
          ChartPane(
            heightRatio: 0.25,
            title: 'RSI 14',
            levels: const [
              PaneLevel(value: 70, colorArgb: 0x55EF5350),
              PaneLevel(value: 30, colorArgb: 0x5526A69A),
            ],
            lines: [
              LineSeries(
                data: relativeStrengthIndex(candles, 14),
                color: const Color(0xFF7E57C2),
                lineWidth: 1.5,
              ),
            ],
          ),
        ],
      ),
      'chart_with_rsi.png',
    );
  });
}
