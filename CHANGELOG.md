# Changelog

## Unreleased

## 0.7.0 - 2026-08-09

- Improves chart legibility with higher-contrast grid, reference, and time-axis
  labels in both color schemes, plus canvas text that scales to 1.8× at the
  largest accessibility sizes.
- Bundles Spanish translations for chart names, values, controls, empty states,
  VoiceOver summaries, and Audio Graph terminology.
- Reworks the demo into an adaptive native dashboard: automatic system theming,
  an iPad multi-column layout, semantic Dynamic Type, one-time interaction
  guidance, and a quieter chart showcase.
- Turns Storybook into a practical chart workbench with search, family filters,
  responsive cards, static navigation previews, contextual gesture help, and
  selectable SwiftUI examples with copy and share actions.
- Adds a custom Liveline demo app icon and stronger UI regression coverage for
  Storybook discovery and navigation.
- Splits the largest chart and extended-renderer implementations by runtime,
  statistical, and hierarchy responsibilities while preserving the public API.
- Keeps the macOS scroll-wheel monitor clean under complete Swift concurrency
  checking with Xcode 26 while retaining deterministic monitor cleanup.
- Adds a reproducible Remotion 4.0.507 project and a 26-second 1080p release
  film built from authentic native chart frames and final app screenshots.
- Expands the README gallery to all 27 chart families, refreshes all 71 native
  visual baselines, and hardens baseline replacement against macOS provenance
  metadata while retaining strict scenario-scoped parity thresholds.

## 0.6.1 - 2026-08-09

- Restores Xcode 15.4 compatibility for histogram bin construction by avoiding
  a compiler type-check timeout without changing histogram behavior.
- Fixes the remaining DocC warnings-as-errors failures for viewport APIs.
- Stabilizes Storybook scroll-state detection and its cross-version UI
  regression coverage.
- Adds a fail-closed, read-only release readiness check that requires the exact
  remote `main` commit to have completed CI successfully before tagging.

## 0.6.0 - 2026-08-03

- Performance: sorted-input fast-path normalization, min/max-per-column line
  decimation, prepared-chart and waterfall caching, palette memoization,
  allocation-free `bucketWidth`, cached axis-label widths and legend gutter,
  hover-snapshot narrowing for all chart kinds, and accessibility-model
  memoization.
- Accessibility: VoiceOver Audio Graph support (`AXChartDescriptor`) for every
  chart kind, and Dynamic Type scaling for all canvas-drawn text.
- Internationalization: all user-facing strings localized via a stable-key
  string layer; locale-aware `localizedValue`/`localizedTime` formatters.
- Theming: new `LivelineThemeMode.automatic` follows the system color scheme.
- Six new chart kinds: histogram (auto binning), streamgraph (centered stacked
  areas), bullet, treemap (squarified with group headers), sunburst, and
  sankey — each wired through rendering, hover, accessibility, and RTL.
- New features: public image export (`LivelineChartImageExporter`), multiple
  reference lines and shaded bands, standalone `LivelineLegend`,
  `LivelineDataStream` streaming buffer, and opt-in pinch-zoom/pan with
  auto-follow-live.
- Right-to-left layout mirroring via an explicit coordinate transform.
- Fixes window changes snapping the x-axis: the drawn span now eases through
  `displayWindow` smoothing with a half-pixel convergence snap.
- Lowers the deployment floor to iOS 15 / macOS 12 / watchOS 8 (tvOS stays 16)
  with availability gates on `ImageRenderer`-backed export, the legend's
  `Layout` wrap, and continuous hover.

## 0.5.0 - 2026-07-29

- Adds accessible chart summaries and adjustable value inspection, improves
  Dynamic Type sizing and control hit targets, and strengthens labels and
  traits throughout the demo.
- Adds focus-based tvOS chart inspection with deterministic remote navigation.
- Keeps pointer hover and drag-scrub sessions independent so one input path
  cannot clear a selection still owned by the other.
- Hardens chart geometry, rendering, and export option validation, including
  full-ring donut hit testing and frame-accurate MP4 durations.
- Expands package, renderer, accessibility, runtime, and core regression
  coverage, plus iOS demo UI tests on both iOS 17.5 and the current SDK.
- Extends CI validation across all declared Apple platforms and Storybook
  scenario overrides.

## 0.4.0 - 2026-07-26

- Adds an opt-in `showsTooltipOnHover` interaction setting that shows the chart
  tooltip when a cursor rests over the chart, with no press or drag. It is off
  by default, so touch-first charts keep their existing press-to-inspect
  behavior.
- Honors the setting on macOS, on iPadOS with a trackpad, mouse, or Apple Pencil
  hover, and on visionOS; tvOS and watchOS have no cursor and are unaffected.
- Gates the marker, guide, and tooltip on either input path rather than on
  `scrub` alone, so a chart can be hover-only with `scrub` disabled.
- Preserves the pre-hover `LivelineChartInteraction` initializer signature, so
  the public API check reports no breaking changes.

## 0.3.1 - 2026-07-25

- Fixes gesture arbitration for vertically stacked LiveLine charts so vertical
  drags that begin on chart content scroll the containing view smoothly, while
  intentional horizontal drags remain locked to accurate scrubbing.
- Adds unit coverage for direction boundaries, ties, stable intent, and
  idempotent cancellation cleanup, plus five iOS Simulator UI scenarios
  covering vertical and horizontal jitter and scrubbing in both directions.

## 0.3.0 - 2026-07-12

- Adds a universal, configurable ordered-dither chart style with gradient,
  dotted, hatched, and solid variants; coloured bloom; animated sparkles; and
  automatic Reduce Motion support across all chart renderers.
- Adds a hierarchy-wide style override and a configurable 1–120 FPS animation
  limit, with a dashboard-friendly 30 FPS default.
- Adds structured, hit-tested tooltips for all twenty-one chart kinds and fixes
  candlestick and candle-line tooltip geometry.
- Reduces warm dither-frame and active-tooltip work through cached Bayer
  geometry, preselected sparkle candidates, and targeted interaction snapshots.
- Adds an opt-in release benchmark, performance methodology, an interactive
  Storybook style switch, and reproducible dither showcase media.

## 0.2.1 - 2026-07-12

- Refactors the renderer and chart runtime, strengthens input normalization and
  regression coverage, and preserves the existing public API surface.
- Refreshes release and visual-parity documentation and moves maintainer-only
  guidance out of the package README.

## 0.2.0 - 2026-07-10

- Adds customizable time-based bar, range-band, and scatter charts with six deterministic Storybook variants.
- Adds step, lollipop, bubble, box-plot, and waterfall charts with typed customization, normalization tests, and ten deterministic Storybook variants.
- Adds error-bar, dumbbell, stacked-bar, stacked-area, timeline, heatmap, radar, donut, gauge, and funnel charts with typed customization and twenty deterministic Storybook variants.
- Adds intrinsic reveal animation to all eighteen additional chart renderers: paths trace their data, marks grow from semantic baselines, and radial charts sweep their actual angles without showcase-level masks.
- Honors the system Reduce Motion setting by completing renderer reveals immediately and suppressing pulse, particle, and shake effects.
- Centers radial, categorical, loading, and empty renderers with content-aware axis gutters; controlled charts now size their Canvas to the remaining viewport, and gauges use sweep-aware geometry with refined ticks and target pins.
- Prevents candlestick value-axis labels from being clipped after the centering changes.
- Keeps strict upstream visual parity checks for structurally comparable scenarios while documenting control-layout exclusions introduced by the centering fix.
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

## 0.1.1 - 2026-07-07

- Documents the SwiftPM release tag and private repository install path.

## 0.1.0 - 2026-07-06

- Initial native SwiftUI Liveline package with line, candlestick, multi-series, Storybook, demo, and visual parity tooling.
