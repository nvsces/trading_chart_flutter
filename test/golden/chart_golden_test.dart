import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_chart_flutter/trading_chart_flutter.dart';

/// Deterministic synthetic series with a large dynamic range (price grows
/// roughly 100x across the window, with noise). Useful for visualising a
/// log-scale chart, where equal % moves take equal screen distance.
List<Candle> _exponentialSeries({int n = 200, int seed = 11}) {
  final rng = math.Random(seed);
  final out = <Candle>[];
  var price = 1.0;
  const startTime = 1700000000;
  // ~+2.3% drift per bar with ±2% jitter → price grows ~100x across 200 bars.
  for (var i = 0; i < n; i++) {
    final pct = 0.023 + (rng.nextDouble() - 0.5) * 0.04;
    final open = price;
    final close = price * (1 + pct);
    final high = math.max(open, close) * (1 + rng.nextDouble() * 0.01);
    final low = math.min(open, close) * (1 - rng.nextDouble() * 0.01);
    out.add(Candle(
      time: startTime + i * 60,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: 50 + rng.nextDouble() * 100,
    ));
    price = close;
  }
  return out;
}

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

  testWidgets('dark theme with Bollinger Bands overlay', (tester) async {
    final candles = _series(seed: 6, n: 200);
    final bb = bollingerBands(candles, period: 20, stdDevMultiplier: 2);
    await _pumpAndMatch(
      tester,
      TradingChart(
        candles: candles,
        theme: ChartTheme.dark,
        overlays: [
          LineSeries(
            data: bb.middle,
            color: const Color(0xFFFFD24A),
            lineWidth: 1.5,
          ),
          LineSeries(
            data: bb.upper,
            color: const Color(0xFF80CBC4),
            lineWidth: 1.2,
            fitToPriceScale: false,
          ),
          LineSeries(
            data: bb.lower,
            color: const Color(0xFF80CBC4),
            lineWidth: 1.2,
            fitToPriceScale: false,
          ),
        ],
      ),
      'chart_with_bollinger.png',
    );
  });

  testWidgets('linear vs logarithmic price scale on the same data',
      (tester) async {
    final candles = _exponentialSeries();
    // Linear baseline.
    await _pumpAndMatch(
      tester,
      TradingChart(
        candles: candles,
        theme: ChartTheme.dark,
        showVolume: false,
      ),
      'chart_exponential_linear.png',
    );
    // Same data, log scale.
    await _pumpAndMatch(
      tester,
      TradingChart(
        candles: candles,
        theme: ChartTheme.dark,
        showVolume: false,
        logarithmicPriceScale: true,
      ),
      'chart_exponential_log.png',
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
