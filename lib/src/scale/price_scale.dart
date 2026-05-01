import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Maps a price <-> screen Y coordinate inside a vertical region.
class PriceScale {
  PriceScale({
    this.topMarginRatio = 0.05,
    this.bottomMarginRatio = 0.2,
    this.logarithmic = false,
  });

  /// Padding inside the price region (fraction of region height).
  double topMarginRatio;
  double bottomMarginRatio;

  /// When true, [priceToY] / [yToPrice] interpolate in log-space, so equal
  /// percentage moves take equal screen distance. Falls back to linear if the
  /// current minimum is non-positive (log is undefined at and below 0).
  bool logarithmic;

  double _minPrice = 0;
  double _maxPrice = 1;

  /// When true, [fit] is a no-op — user controls the range manually.
  /// Set by user dragging the price axis.
  bool autoFit = true;

  /// Whether the current min/max is safe for logarithmic mapping.
  bool get _logActive => logarithmic && _minPrice > 0 && _maxPrice > _minPrice;

  void switchToManual() {
    autoFit = false;
  }

  void switchToAuto() {
    autoFit = true;
  }

  void fit(Iterable<double> values) {
    if (!autoFit) return;
    _fitInternal(values);
  }

  void forceFit(Iterable<double> values) {
    _fitInternal(values);
  }

  void _fitInternal(Iterable<double> values) {
    var first = true;
    var min = 0.0;
    var max = 0.0;
    for (final v in values) {
      if (v.isNaN || v.isInfinite) continue;
      if (first) {
        min = v;
        max = v;
        first = false;
      } else {
        if (v < min) min = v;
        if (v > max) max = v;
      }
    }
    if (first) {
      _minPrice = 0;
      _maxPrice = 1;
      return;
    }
    if ((max - min).abs() < 1e-9) {
      final pad = math.max(1.0, max.abs() * 0.01);
      min -= pad;
      max += pad;
    }
    _minPrice = min;
    _maxPrice = max;
  }

  double get minPrice => _minPrice;
  double get maxPrice => _maxPrice;
  double get priceRange => _maxPrice - _minPrice;

  double priceToY(double price, double height) {
    final top = height * topMarginRatio;
    final bottom = height * (1 - bottomMarginRatio);
    final usable = bottom - top;
    final double t;
    if (_logActive && price > 0) {
      final logMin = math.log(_minPrice);
      final logMax = math.log(_maxPrice);
      t = (math.log(price) - logMin) / (logMax - logMin);
    } else {
      t = (price - _minPrice) / priceRange;
    }
    return bottom - t * usable;
  }

  double yToPrice(double y, double height) {
    final top = height * topMarginRatio;
    final bottom = height * (1 - bottomMarginRatio);
    final usable = bottom - top;
    final t = (bottom - y) / usable;
    if (_logActive) {
      final logMin = math.log(_minPrice);
      final logMax = math.log(_maxPrice);
      return math.exp(logMin + t * (logMax - logMin));
    }
    return _minPrice + t * priceRange;
  }

  /// Multiply the price range around the price at [anchorY], keeping that
  /// price fixed at the same screen Y. Used for manual price zoom.
  ///
  /// In log mode, the *log-space* range is multiplied by `1/factor`, so the
  /// pinch feels the same on a log chart as it does on a linear one.
  void zoomAtY({
    required double anchorY,
    required double factor,
    required double height,
  }) {
    final anchorPrice = yToPrice(anchorY, height);
    final top = height * topMarginRatio;
    final bottom = height * (1 - bottomMarginRatio);
    final usable = bottom - top;
    if (usable <= 0) return;
    final tAnchor = (bottom - anchorY) / usable;

    if (_logActive && anchorPrice > 0) {
      final logMin = math.log(_minPrice);
      final logMax = math.log(_maxPrice);
      final logRange = logMax - logMin;
      final newLogRange = logRange / factor;
      if (newLogRange <= 0) return;
      final logAnchor = math.log(anchorPrice);
      final newLogMin = logAnchor - tAnchor * newLogRange;
      _minPrice = math.exp(newLogMin);
      _maxPrice = math.exp(newLogMin + newLogRange);
      return;
    }

    final newRange = priceRange / factor;
    if (newRange <= 0) return;
    final newMin = anchorPrice - tAnchor * newRange;
    _minPrice = newMin;
    _maxPrice = newMin + newRange;
  }
}

@immutable
class PriceAxisTick {
  final double price;
  final double y;
  final String label;

  const PriceAxisTick({
    required this.price,
    required this.y,
    required this.label,
  });
}

/// Picks "nice" round numbers for axis ticks (1, 2, 2.5, 5 × 10^n family).
class NiceTicks {
  static List<double> compute({
    required double min,
    required double max,
    required int targetCount,
  }) {
    if (targetCount < 2) targetCount = 2;
    final range = max - min;
    if (range <= 0 || range.isNaN || range.isInfinite) {
      return [min];
    }
    final rough = range / (targetCount - 1);
    final mag = math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
    final norm = rough / mag;
    final double step;
    if (norm < 1.5) {
      step = 1 * mag;
    } else if (norm < 3) {
      step = 2 * mag;
    } else if (norm < 7) {
      step = 5 * mag;
    } else {
      step = 10 * mag;
    }
    final start = (min / step).floor() * step;
    final out = <double>[];
    var v = start;
    while (v <= max + step * 0.5) {
      if (v >= min - step * 0.5) out.add(v);
      v += step;
    }
    return out;
  }

  static String formatPrice(double v, double step) {
    final absStep = step.abs();
    final int decimals;
    if (absStep >= 100) {
      decimals = 0;
    } else if (absStep >= 1) {
      decimals = 2;
    } else if (absStep >= 0.01) {
      decimals = 4;
    } else {
      decimals = 6;
    }
    return v.toStringAsFixed(decimals);
  }
}
