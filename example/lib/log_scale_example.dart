import 'dart:math';

import 'package:flutter/material.dart';
import 'package:trading_chart_flutter/trading_chart_flutter.dart';

/// Demonstrates the `logarithmicPriceScale` flag on a synthetic, exponentially
/// growing series. Toggle the switch in the AppBar to compare linear and log
/// scaling on the same data — under linear scale the early bars are crushed
/// near the bottom, under log scale equal % moves take equal screen space.
class LogScaleExample extends StatefulWidget {
  const LogScaleExample({super.key});

  @override
  State<LogScaleExample> createState() => _LogScaleExampleState();
}

class _LogScaleExampleState extends State<LogScaleExample> {
  bool _logarithmic = true;
  late final List<Candle> _candles;

  @override
  void initState() {
    super.initState();
    _candles = _generate(n: 400);
  }

  /// Geometric random walk: each bar drifts up by ~+1.5% with ±2% jitter.
  /// Over 400 bars price grows roughly 100x, which makes the linear-vs-log
  /// difference very visible.
  List<Candle> _generate({required int n}) {
    final rng = Random(42);
    final out = <Candle>[];
    var price = 1.0;
    final startTime = DateTime.now().millisecondsSinceEpoch ~/ 1000 - n * 60;
    for (var i = 0; i < n; i++) {
      final pct = 0.015 + (rng.nextDouble() - 0.5) * 0.04;
      final open = price;
      final close = price * (1 + pct);
      final high = max(open, close) * (1 + rng.nextDouble() * 0.01);
      final low = min(open, close) * (1 - rng.nextDouble() * 0.01);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF131722),
        title: const Text('Log scale (long-term)'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                const Text('log'),
                Switch(
                  value: _logarithmic,
                  onChanged: (v) => setState(() => _logarithmic = v),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: InteractiveTradingChart(
          candles: _candles,
          theme: ChartTheme.dark,
          logarithmicPriceScale: _logarithmic,
        ),
      ),
    );
  }
}
