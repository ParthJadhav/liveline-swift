# Changelog

## Unreleased

- Adds customizable time-based bar, range-band, and scatter charts with six deterministic Storybook variants.
- Adds step, lollipop, bubble, box-plot, and waterfall charts with typed customization, normalization tests, and ten deterministic Storybook variants.
- Adds error-bar, dumbbell, stacked-bar, stacked-area, timeline, heatmap, radar, donut, gauge, and funnel charts with typed customization and twenty deterministic Storybook variants.
- Centers radial, categorical, loading, and empty renderers with content-aware axis gutters; controlled charts now size their Canvas to the remaining viewport, and gauges use sweep-aware geometry with refined ticks and target pins.
- Improves single-range rendering, formatter-aware grid labels, and empty-state contrast following visual edge-case review.
- Adds Swift Package Index metadata for public DocC hosting.
- Bundles an empty privacy manifest with the Swift package target.
- Preserves the previous public `LivelineChartConfiguration` initializer for source compatibility.
- Adds CI checks for public API compatibility and declared Apple platform builds.
- Fixes platform-specific compile issues across the declared Apple targets.

## 0.1.2 - 2026-07-07

- Adds candle line-mode morphing with staged OHLC collapse, line density ramping, close-price dash crossfade, and smoother live-candle transitions.
- Refreshes deterministic Storybook captures and visual parity artifacts; the accepted diff gate remains `--fail-changed-pct 5 --fail-rms 12`.
- Adds release, optimized package, and macOS package build checks to CI and the release checklist.
- Updates release documentation so tagging and GitHub releases do not imply a repository visibility change.

## 0.1.1 - 2026-07-06

- Documents the SwiftPM release tag and private repository install path.

## 0.1.0 - 2026-07-06

- Initial native SwiftUI Liveline package with line, candlestick, multi-series, Storybook, demo, and visual parity tooling.
