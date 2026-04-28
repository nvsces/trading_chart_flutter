import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:trading_chart_flutter/trading_chart_flutter.dart';

class SyntheticChartExample extends StatefulWidget {
  const SyntheticChartExample({super.key});

  @override
  State<SyntheticChartExample> createState() => _SyntheticChartExampleState();
}

class _SyntheticChartExampleState extends State<SyntheticChartExample> {
  static const _intervalSec = 60;
  static const _historyTriggerBars = 20;

  final _controller = ChartController();
  late List<Candle> _candles;

  bool _loadingHistory = false;
  Timer? _tickTimer;
  int _historyPagesLoaded = 0;
  late double _lastClose;

  @override
  void initState() {
    super.initState();
    _candles = _generatePage(
      endTimeSec: _alignedNow(),
      count: 200,
      seedPrice: 70000,
    );
    _lastClose = _candles.last.close;
    _controller.setData(_candles);

    _tickTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      _pushTick();
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  int _alignedNow() {
    final t = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return t - (t % _intervalSec);
  }

  List<Candle> _generatePage({
    required int endTimeSec,
    required int count,
    required double seedPrice,
  }) {
    final rng = Random(endTimeSec ^ count);
    var price = seedPrice + (rng.nextDouble() - 0.5) * 1500;
    final out = <Candle>[];
    for (var i = count; i > 0; i--) {
      final t = endTimeSec - i * _intervalSec;
      final open = price;
      final close = open + (rng.nextDouble() - 0.5) * 120;
      final high = max(open, close) + rng.nextDouble() * 60;
      final low = min(open, close) - rng.nextDouble() * 60;
      final vol = 500 + rng.nextDouble() * 4000;
      out.add(
        Candle(
          time: t,
          open: open,
          high: high,
          low: low,
          close: close,
          volume: vol,
        ),
      );
      price = close;
    }
    return out;
  }

  void _pushTick() {
    final rng = Random();
    _lastClose += (rng.nextDouble() - 0.5) * 50;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final bucket = nowSec - (nowSec % _intervalSec);
    final last = _candles.last;
    final Candle next;
    if (bucket == last.time) {
      next = Candle(
        time: last.time,
        open: last.open,
        high: max(last.high, _lastClose),
        low: min(last.low, _lastClose),
        close: _lastClose,
        volume: (last.volume ?? 0) + rng.nextDouble() * 50,
      );
      _candles = [..._candles.sublist(0, _candles.length - 1), next];
    } else if (bucket > last.time) {
      next = Candle(
        time: bucket,
        open: last.close,
        high: max(last.close, _lastClose),
        low: min(last.close, _lastClose),
        close: _lastClose,
        volume: 100 + rng.nextDouble() * 400,
      );
      _candles = [..._candles, next];
    } else {
      return;
    }
    _controller.upsert(next);
    if (mounted) setState(() {});
  }

  void _onVisibleRangeChanged(VisibleLogicalRange range) {
    if (_loadingHistory) return;
    if (range.from < _historyTriggerBars) {
      _loadHistoryPage();
    }
  }

  Future<void> _loadHistoryPage() async {
    _loadingHistory = true;
    setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final oldestTime = _candles.first.time;
    final older = _generatePage(
      endTimeSec: oldestTime,
      count: 200,
      seedPrice: _candles.first.open,
    );
    _candles = [...older, ..._candles];
    _controller.prependHistory(older);
    _historyPagesLoaded += 1;
    _loadingHistory = false;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF131722),
        title: const Text('Synthetic feed'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                'bars: ${_candles.length} · pages: $_historyPagesLoaded'
                '${_loadingHistory ? ' · loading...' : ''}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Scroll to latest',
            onPressed: () => _controller.scrollToLatest(),
            icon: const Icon(Icons.last_page),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: InteractiveTradingChart(
            candles: _candles,
            controller: _controller,
            onVisibleRangeChanged: _onVisibleRangeChanged,
            theme: ChartTheme.dark,
            overlays: [
              LineSeries(
                data: simpleMovingAverage(_candles, 20),
                color: const Color(0xFFFFB300),
              ),
              LineSeries(
                data: exponentialMovingAverage(_candles, 50),
                color: const Color(0xFF42A5F5),
                lineWidth: 1.5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
