import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Maps a price <-> screen Y coordinate inside a vertical region.
class PriceScale {
  PriceScale({this.topMarginRatio = 0.05, this.bottomMarginRatio = 0.2});

  /// Padding inside the price region (fraction of region height).
  double topMarginRatio;
  double bottomMarginRatio;

  double _minPrice = 0;
  double _maxPrice = 1;

  /// When true, [fit] is a no-op — user controls the range manually.
  /// Set by user dragging the price axis.
  bool autoFit = true;

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
    final t = (price - _minPrice) / priceRange;
    return bottom - t * usable;
  }

  double yToPrice(double y, double height) {
    final top = height * topMarginRatio;
    final bottom = height * (1 - bottomMarginRatio);
    final usable = bottom - top;
    final t = (bottom - y) / usable;
    return _minPrice + t * priceRange;
  }

  /// Multiply the price range around the price at [anchorY], keeping that
  /// price fixed at the same screen Y. Used for manual price zoom.
  void zoomAtY({
    required double anchorY,
    required double factor,
    required double height,
  }) {
    final anchorPrice = yToPrice(anchorY, height);
    final newRange = priceRange / factor;
    if (newRange <= 0) return;
    // Solve for new min so that anchorPrice maps back to anchorY.
    final top = height * topMarginRatio;
    final bottom = height * (1 - bottomMarginRatio);
    final usable = bottom - top;
    if (usable <= 0) return;
    final tAnchor = (bottom - anchorY) / usable;
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

  const PriceAxisTick({required this.price, required this.y, required this.label});
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
