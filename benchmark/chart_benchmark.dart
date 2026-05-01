// Run with: flutter test benchmark/chart_benchmark.dart
//
// Uses the flutter_test harness only because it gives us a binding (so
// `Canvas` and `PictureRecorder` work). All measurements are wall-clock
// timings via Stopwatch — there are no `expect` calls, just `print`.
//
// Each scenario runs `iterations` times after a short warm-up, and reports
// the median time per iteration. Median is more stable than mean when GC or
// background work pauses one iteration.

// ignore_for_file: avoid_print

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:trading_chart_flutter/src/scale/price_scale.dart';
import 'package:trading_chart_flutter/src/scale/time_scale.dart';
import 'package:trading_chart_flutter/src/series/candlestick_series.dart';
import 'package:trading_chart_flutter/trading_chart_flutter.dart';

const _width = 1200.0;
const _height = 600.0;
const _plotSize = ui.Size(_width, _height);

List<Candle> _series(int n, {int seed = 1}) {
  final rng = math.Random(seed);
  final out = <Candle>[];
  var price = 100.0;
  const startTime = 1700000000;
  for (var i = 0; i < n; i++) {
    final drift = (rng.nextDouble() - 0.48) * 2.0;
    final open = price;
    final close = price + drift;
    out.add(Candle(
      time: startTime + i * 60,
      open: open,
      high: math.max(open, close) + rng.nextDouble() * 0.8,
      low: math.min(open, close) - rng.nextDouble() * 0.8,
      close: close,
      volume: 50 + rng.nextDouble() * 100,
    ));
    price = close;
  }
  return out;
}

({double medianUs, double minUs, double maxUs}) _measure(
  void Function() body, {
  int warmup = 3,
  int iterations = 11,
}) {
  for (var i = 0; i < warmup; i++) {
    body();
  }
  final samples = <int>[];
  for (var i = 0; i < iterations; i++) {
    final sw = Stopwatch()..start();
    body();
    sw.stop();
    samples.add(sw.elapsedMicroseconds);
  }
  samples.sort();
  return (
    medianUs: samples[samples.length ~/ 2].toDouble(),
    minUs: samples.first.toDouble(),
    maxUs: samples.last.toDouble(),
  );
}

String _fmtUs(double us) {
  if (us >= 1000) return '${(us / 1000).toStringAsFixed(2)} ms';
  return '${us.toStringAsFixed(1)} µs';
}

void _printRow(String name, ({double medianUs, double minUs, double maxUs}) r) {
  // Pad name so columns line up in terminal.
  final padded = name.padRight(46);
  print(
    '$padded median=${_fmtUs(r.medianUs).padLeft(10)}  '
    'min=${_fmtUs(r.minUs).padLeft(10)}  '
    'max=${_fmtUs(r.maxUs).padLeft(10)}',
  );
}

({ui.Canvas canvas, ui.PictureRecorder recorder}) _newCanvas() {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(
    recorder,
    const ui.Rect.fromLTWH(0, 0, _width, _height),
  );
  return (canvas: canvas, recorder: recorder);
}

void _benchCandlestickPaint({
  required String label,
  required int dataLength,
  required double barSpacing,
}) {
  final candles = _series(dataLength);
  final series = CandlestickSeries(data: candles);
  final ts = TimeScale(
    dataLength: dataLength,
    barSpacing: barSpacing,
    rightOffsetBars: 0,
  )..resetToLatest();
  final ps = PriceScale()..fit(candles.expand((c) => [c.high, c.low]));
  final visible = ts.visibleIntegerRange(_width);
  final visCount = visible.to - visible.from + 1;

  final result = _measure(() {
    final c = _newCanvas();
    series.paint(
      canvas: c.canvas,
      size: _plotSize,
      timeScale: ts,
      priceScale: ps,
      theme: ChartTheme.dark,
    );
    // Finalize the picture so we measure the full cost (drawRect/drawLine
    // submit work to a display list — the cost lives in series.paint, but we
    // call endRecording so the recorder's internal buffer is released).
    c.recorder.endRecording().dispose();
  });
  _printRow(
    '$label  N=$dataLength  visible≈$visCount',
    result,
  );
}

void _benchLineOverlayPaint({
  required String label,
  required int dataLength,
}) {
  final candles = _series(dataLength);
  final ts = TimeScale(
    dataLength: dataLength,
    barSpacing: 8,
    rightOffsetBars: 0,
  )..resetToLatest();
  final ps = PriceScale()..fit(candles.expand((c) => [c.high, c.low]));

  final overlay = LineSeries(
    data: simpleMovingAverage(candles, 20),
    color: const ui.Color(0xFFFFD24A),
    lineWidth: 2,
  );

  // Mirror RenderTradingChart's xForTime: binary-search candles by time.
  double xForTime(int time) {
    final n = candles.length;
    if (n < 2) return ts.indexToX(0, _width);
    final first = candles[0].time;
    final last = candles[n - 1].time;
    final avgStep = (last - first) / (n - 1);
    if (time <= first) {
      final idx = avgStep > 0 ? (time - first) / avgStep : 0.0;
      return ts.indexToX(idx, _width);
    }
    if (time >= last) {
      final idx = avgStep > 0
          ? (n - 1) + (time - last) / avgStep
          : (n - 1).toDouble();
      return ts.indexToX(idx, _width);
    }
    var lo = 0;
    var hi = n - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (candles[mid].time <= time) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final tLo = candles[lo].time;
    final tHi = candles[lo + 1].time;
    final frac = (time - tLo) / (tHi - tLo);
    return ts.indexToX(lo + frac, _width);
  }

  final result = _measure(() {
    final c = _newCanvas();
    overlay.paint(
      canvas: c.canvas,
      size: _plotSize,
      timeScale: ts,
      priceScale: ps,
      xForTime: xForTime,
    );
    c.recorder.endRecording().dispose();
  });
  _printRow('$label  N=$dataLength', result);
}

void _benchAlgo(String name, int n, void Function() body) {
  final result = _measure(body);
  _printRow('$name  N=$n', result);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('benchmark', () async {
    print('');
    print('=== trading_chart_flutter benchmark ===');
    print('canvas size: ${_width.toInt()}x${_height.toInt()}');
    print('');

    print('--- CandlestickSeries.paint, fixed visible window ---');
    // visible ≈ width / barSpacing = 1200/8 = 150
    _benchCandlestickPaint(
      label: 'paint candles (window=150)',
      dataLength: 1000,
      barSpacing: 8,
    );
    _benchCandlestickPaint(
      label: 'paint candles (window=150)',
      dataLength: 10000,
      barSpacing: 8,
    );
    _benchCandlestickPaint(
      label: 'paint candles (window=150)',
      dataLength: 100000,
      barSpacing: 8,
    );

    print('');
    print('--- CandlestickSeries.paint, all bars visible (worst case) ---');
    _benchCandlestickPaint(
      label: 'paint candles (all visible)',
      dataLength: 1000,
      barSpacing: _width / 1000,
    );
    _benchCandlestickPaint(
      label: 'paint candles (all visible)',
      dataLength: 10000,
      barSpacing: math.max(1, _width / 10000),
    );
    _benchCandlestickPaint(
      label: 'paint candles (all visible)',
      dataLength: 100000,
      barSpacing: math.max(1, _width / 100000),
    );

    print('');
    print('--- LineSeries.paint (overlay) ---');
    _benchLineOverlayPaint(label: 'overlay paint', dataLength: 1000);
    _benchLineOverlayPaint(label: 'overlay paint', dataLength: 10000);
    _benchLineOverlayPaint(label: 'overlay paint', dataLength: 100000);

    print('');
    print('--- Indicators (algo) ---');
    final c10k = _series(10000);
    final c100k = _series(100000);
    _benchAlgo('SMA(20)', 10000, () => simpleMovingAverage(c10k, 20));
    _benchAlgo('SMA(20)', 100000, () => simpleMovingAverage(c100k, 20));
    _benchAlgo('EMA(20)', 10000, () => exponentialMovingAverage(c10k, 20));
    _benchAlgo('EMA(20)', 100000, () => exponentialMovingAverage(c100k, 20));
    _benchAlgo('RSI(14)', 10000, () => relativeStrengthIndex(c10k, 14));
    _benchAlgo('RSI(14)', 100000, () => relativeStrengthIndex(c100k, 14));

    print('');
    print('--- TimeScale ops (10k iterations each) ---');
    final ts = TimeScale(
      dataLength: 100000,
      barSpacing: 8,
      rightOffsetBars: 0,
    )..resetToLatest();
    _benchAlgo('TimeScale.panByPixels x10k', 100000, () {
      for (var i = 0; i < 10000; i++) {
        ts.panByPixels(i.isEven ? 1.0 : -1.0);
      }
    });
    _benchAlgo('TimeScale.zoomAt x10k', 100000, () {
      for (var i = 0; i < 10000; i++) {
        ts.zoomAt(
          anchorX: 600,
          factor: i.isEven ? 1.001 : 0.999,
          width: _width,
        );
      }
    });
    _benchAlgo('TimeScale.indexToX x100k', 100000, () {
      for (var i = 0; i < 100000; i++) {
        ts.indexToX(i.toDouble(), _width);
      }
    });

    print('');
    print('=== done ===');
    print('');
  });
}
