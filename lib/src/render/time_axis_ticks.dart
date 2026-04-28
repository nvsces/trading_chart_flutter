import '../model/candle.dart';
import '../scale/time_scale.dart';

class TimeAxisTicks {
  static List<TimeAxisTick> compute({
    required List<Candle> data,
    required TimeScale timeScale,
    required double width,
    double minLabelSpacingPx = 70,
  }) {
    if (data.isEmpty) return const [];
    final range = timeScale.visibleIntegerRange(width);
    if (range.to < range.from) return const [];

    final ticks = <TimeAxisTick>[];
    var lastLabelX = double.negativeInfinity;
    DateTime? prevDt;

    for (var i = range.from; i <= range.to; i++) {
      final c = data[i];
      final x = timeScale.indexToX(i.toDouble(), width);
      final dt = DateTime.fromMillisecondsSinceEpoch(
        c.time * 1000,
        isUtc: false,
      );

      final boundary = _boundaryFor(prevDt, dt);
      prevDt = dt;
      if (boundary == null) continue;

      if (x - lastLabelX < minLabelSpacingPx) continue;
      lastLabelX = x;

      ticks.add(
        TimeAxisTick(
          dataIndex: i,
          x: x,
          label: _formatLabel(dt, boundary),
          isMajor: true,
        ),
      );
    }
    return ticks;
  }

  static _Boundary? _boundaryFor(DateTime? prev, DateTime curr) {
    if (prev == null) return _Boundary.day;
    if (prev.year != curr.year) return _Boundary.year;
    if (prev.month != curr.month) return _Boundary.month;
    if (prev.day != curr.day) return _Boundary.day;
    if (prev.hour != curr.hour) return _Boundary.hour;
    return null;
  }

  static String _formatLabel(DateTime dt, _Boundary b) {
    switch (b) {
      case _Boundary.year:
        return '${dt.year}';
      case _Boundary.month:
        return _monthAbbr(dt.month);
      case _Boundary.day:
        return '${dt.day} ${_monthAbbr(dt.month)}';
      case _Boundary.hour:
        return '${dt.hour.toString().padLeft(2, '0')}:'
            '${dt.minute.toString().padLeft(2, '0')}';
    }
  }

  static String _monthAbbr(int m) => const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ][m - 1];
}

enum _Boundary { year, month, day, hour }
