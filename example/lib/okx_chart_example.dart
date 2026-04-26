import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:trading_chart_flutter/trading_chart_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class OkxChartExample extends StatefulWidget {
  const OkxChartExample({super.key});

  @override
  State<OkxChartExample> createState() => _OkxChartExampleState();
}

class _OkxIntervalOption {
  final String label;
  final String okxBar;
  final int seconds;
  const _OkxIntervalOption(this.label, this.okxBar, this.seconds);
}

class _OkxChartExampleState extends State<OkxChartExample> {
  static const _instId = 'BTC-USDT';
  static const _historyTriggerBars = 20;
  static const _historyPageSize = 200;

  static const _intervals = [
    _OkxIntervalOption('1m', '1m', 60),
    _OkxIntervalOption('5m', '5m', 300),
    _OkxIntervalOption('15m', '15m', 900),
    _OkxIntervalOption('1h', '1H', 3600),
    _OkxIntervalOption('4h', '4H', 14400),
  ];

  final _controller = ChartController();
  _OkxIntervalOption _interval = _intervals.first;

  List<Candle> _candles = const [];
  bool _loadingInitial = true;
  bool _loadingHistory = false;
  String _wsStatus = 'connecting...';
  double? _lastPrice;

  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _wsSub?.cancel();
    _ws?.sink.close();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadInitial();
    _connectWs();
  }

  // ───────── REST ─────────

  Future<void> _loadInitial() async {
    setState(() => _loadingInitial = true);
    final bars = await _fetchCandles();
    if (!mounted) return;
    _candles = bars;
    _controller.setData(_candles);
    setState(() => _loadingInitial = false);
  }

  Future<List<Candle>> _fetchCandles({int? beforeMs}) async {
    final params = <String, String>{
      'instId': _instId,
      'bar': _interval.okxBar,
      'limit': _historyPageSize.toString(),
    };
    if (beforeMs != null) {
      params['after'] = beforeMs.toString();
    }
    final uri = Uri.https('www.okx.com', '/api/v5/market/candles', params);
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      debugPrint('OKX REST error ${res.statusCode}: ${res.body}');
      return const [];
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'];
    if (data is! List) return const [];

    final bars = <Candle>[];
    for (final row in data) {
      if (row is! List || row.length < 6) continue;
      final ts = int.tryParse(row[0].toString());
      final o = double.tryParse(row[1].toString());
      final h = double.tryParse(row[2].toString());
      final l = double.tryParse(row[3].toString());
      final c = double.tryParse(row[4].toString());
      final v = double.tryParse(row[5].toString());
      if (ts == null || o == null || h == null || l == null || c == null) {
        continue;
      }
      bars.add(
        Candle(time: ts ~/ 1000, open: o, high: h, low: l, close: c, volume: v),
      );
    }
    bars.sort((a, b) => a.time.compareTo(b.time));
    return bars;
  }

  // ───────── WebSocket ─────────

  void _connectWs() {
    _wsSub?.cancel();
    _ws?.sink.close();
    setState(() => _wsStatus = 'connecting...');

    final ws = WebSocketChannel.connect(
      Uri.parse('wss://ws.okx.com:8443/ws/v5/public'),
    );
    _ws = ws;

    _wsSub = ws.stream.listen(
      _onWsData,
      onError: (e) {
        debugPrint('OKX WS error: $e');
        _scheduleReconnect();
      },
      onDone: () => _scheduleReconnect(),
      cancelOnError: true,
    );

    _subscribeTrades();
    _startPing();
  }

  void _subscribeTrades() {
    _ws?.sink.add(
      jsonEncode({
        'op': 'subscribe',
        'args': [
          {'channel': 'trades', 'instId': _instId},
        ],
      }),
    );
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      try {
        _ws?.sink.add('ping');
      } catch (_) {}
    });
  }

  void _scheduleReconnect() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    if (!mounted) return;
    setState(() => _wsStatus = 'reconnecting in 3s...');
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _connectWs();
    });
  }

  void _onWsData(dynamic raw) {
    if (raw is! String) return;
    if (raw == 'pong') return;

    Map<String, dynamic> msg;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      msg = decoded;
    } catch (_) {
      return;
    }

    if (msg['event'] == 'subscribe') {
      if (mounted) setState(() => _wsStatus = 'live');
      return;
    }
    if (msg['event'] == 'error') {
      debugPrint('OKX WS event error: $raw');
      if (mounted) setState(() => _wsStatus = 'error');
      return;
    }

    final data = msg['data'];
    if (data is! List) return;

    for (final row in data) {
      if (row is! Map) continue;
      final px = double.tryParse(row['px']?.toString() ?? '');
      final ts = int.tryParse(row['ts']?.toString() ?? '');
      final sz = double.tryParse(row['sz']?.toString() ?? '0') ?? 0;
      if (px == null || ts == null) continue;
      _lastPrice = px;
      _ingestTick(price: px, timeMs: ts, size: sz);
    }
    if (mounted) setState(() {});
  }

  /// Aggregate raw trades into the current candle bucket.
  void _ingestTick({
    required double price,
    required int timeMs,
    required double size,
  }) {
    if (_candles.isEmpty) return;
    final tSec = timeMs ~/ 1000;
    final bucket = tSec - (tSec % _interval.seconds);
    final last = _candles.last;
    if (bucket == last.time) {
      final updated = Candle(
        time: last.time,
        open: last.open,
        high: math.max(last.high, price),
        low: math.min(last.low, price),
        close: price,
        volume: (last.volume ?? 0) + size,
      );
      _candles = [..._candles.sublist(0, _candles.length - 1), updated];
      _controller.upsert(updated);
    } else if (bucket > last.time) {
      final next = Candle(
        time: bucket,
        open: last.close,
        high: math.max(last.close, price),
        low: math.min(last.close, price),
        close: price,
        volume: size,
      );
      _candles = [..._candles, next];
      _controller.upsert(next);
    }
  }

  // ───────── history pagination ─────────

  void _onVisibleRangeChanged(VisibleLogicalRange range) {
    if (_loadingHistory || _loadingInitial) return;
    if (range.from < _historyTriggerBars) {
      _loadHistoryPage();
    }
  }

  Future<void> _loadHistoryPage() async {
    if (_candles.isEmpty) return;
    _loadingHistory = true;
    if (mounted) setState(() {});
    final oldestMs = _candles.first.time * 1000;
    final older = await _fetchCandles(beforeMs: oldestMs);
    if (!mounted) {
      _loadingHistory = false;
      return;
    }
    if (older.isNotEmpty) {
      final knownTimes = <int>{for (final c in _candles) c.time};
      final filtered = older
          .where((c) => !knownTimes.contains(c.time))
          .toList();
      _candles = [...filtered, ..._candles];
      _controller.prependHistory(filtered);
    }
    _loadingHistory = false;
    if (mounted) setState(() {});
  }

  // ───────── interval switch ─────────

  Future<void> _onIntervalChanged(_OkxIntervalOption v) async {
    if (v == _interval) return;
    setState(() {
      _interval = v;
      _candles = const [];
    });
    _wsSub?.cancel();
    _ws?.sink.close();
    await _loadInitial();
    _connectWs();
  }

  // ───────── build ─────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF131722),
        title: Text('OKX live · $_instId'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Row(
                children: [
                  _StatusDot(status: _wsStatus),
                  const SizedBox(width: 6),
                  Text(
                    _wsStatus,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                  if (_lastPrice != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      _lastPrice!.toStringAsFixed(2),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _IntervalBar(
              intervals: _intervals,
              current: _interval,
              onChanged: _onIntervalChanged,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _loadingInitial
                    ? const Center(child: CircularProgressIndicator())
                    : InteractiveTradingChart(
                        candles: _candles,
                        controller: _controller,
                        onVisibleRangeChanged: _onVisibleRangeChanged,
                        theme: ChartTheme.dark,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntervalBar extends StatelessWidget {
  const _IntervalBar({
    required this.intervals,
    required this.current,
    required this.onChanged,
  });

  final List<_OkxIntervalOption> intervals;
  final _OkxIntervalOption current;
  final ValueChanged<_OkxIntervalOption> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: const Color(0xFF131722),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          for (final i in intervals)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              child: Material(
                color: i == current
                    ? const Color(0xFF2A2E39)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: i == current ? null : () => onChanged(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(
                      i.label,
                      style: TextStyle(
                        color: i == current ? Colors.white : Colors.white70,
                        fontSize: 14,
                        fontWeight: i == current
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final String status;

  Color get _color {
    if (status == 'live') return const Color(0xFF26A69A);
    if (status.startsWith('reconnecting') || status == 'connecting...') {
      return const Color(0xFFFFB300);
    }
    return const Color(0xFFEF5350);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
    );
  }
}
