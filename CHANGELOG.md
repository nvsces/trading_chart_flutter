## 0.0.1

* Initial release.
* Pure-Dart candlestick chart rendered through a custom `RenderObject`.
* Volume histogram series with its own price scale.
* Time and price axes with auto-tick generation (nice numbers, time-bucket boundaries).
* Crosshair (mouse hover and touch long-press), last-value price line, OHLC legend.
* Pan, pinch zoom, mouse wheel zoom, trackpad pan/zoom, fling inertia.
* Time-axis drag zoom, price-axis drag manual zoom, double-tap reset zones.
* `ChartController` with `setData`, `upsert`, `prependHistory`, `scrollToLatest`,
  `scrollToTime`, `setVisibleLogicalRange`.
* `onVisibleRangeChanged` callback for history pagination.
* Two example apps: synthetic random walk and live OKX BTC-USDT feed.
