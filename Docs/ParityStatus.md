# Visual Parity Status

This document tracks the native renderer against the upstream React/canvas Liveline implementation.

## Current Coverage

- `Docs/ScenarioMatrix.md` defines 27 deterministic Storybook scenarios across line, candlestick, loading/empty, orderbook, degen, mode controls, and multi-series modes.
- `scripts/capture-storybook.sh` captures full Storybook screenshots into `Media/storybook`.
- `scripts/capture-storybook.sh --chart-only` captures the same scenario IDs into `Media/storybook-chart-only`.
- `scripts/capture-web-references.sh` renders the equivalent scenarios with the upstream React/canvas package into `Media/web-reference`.
- `scripts/diff-storybook.sh` crops the native chart-only screenshots and writes side-by-side reference/native/heatmap diffs into `Media/storybook-diff`.
- The renderer now ports upstream primitives for loading waveform shape, loading breath alpha, elapsed animation timing, reveal/pause snap thresholds, reveal-time line color blending, empty-state center gap, curved badge tail geometry, badge sizing constants, badge text weight/baseline, semantic momentum badge colors, live dot outer/core structure, icon mode controls, multi-series endpoint pulse behavior, multi-series label reserve/right-padding split, labeled series-chip baseline nudging, live value letter spacing, canvas-style orderbook text rasterization, orderbook phase calibration, centered reference-line labels, baseline-adjusted and x-aligned axis text, window control baseline nudging, segmented candle wicks, live candle glow, candle close-price opacity, candle line-mode morph/density transitions, OHLC collapse/expand reveal behavior, adaptive range settling, deterministic snapshot timing, time-axis interval thresholds, overlap suppression, grid/time-axis label state, and coarse/fine grid interval selection.

## Last Verified

```bash
swift test
xcodebuild -project Examples/LivelineDemo/LivelineDemo.xcodeproj -scheme LivelineDemo -destination 'generic/platform=iOS Simulator' build
scripts/capture-storybook.sh --chart-only
scripts/diff-storybook.sh --fail-changed-pct 5 --fail-rms 12
```

`scripts/capture-storybook.sh` passes the scenario wait into `snapshotElapsedTime`, advances native animations with a fixed 60fps snapshot cursor, and waits an extra 0.60 seconds before screenshotting so captures are repeatable. It uses the upstream orderbook seed `12345`. `line-orderbook` defaults to a `3.40` second snapshot elapsed time because the browser reference's RAF stream has already advanced while Playwright navigates, lays out, and waits for the capture node before the nominal 2.2 second screenshot wait begins. The loading/empty-state scenarios default to `2.80` seconds to align the deterministic native waveform with the checked-in browser references. Other scenarios use the default 2.2 second snapshot elapsed time unless overridden. `STORYBOOK_ORDERBOOK_RANDOM_SEED` can override the Storybook orderbook seed for local tuning.

The latest chart-only comparison against the checked-in web references is:

| Scenario | Changed pixels | Mean abs | RMS |
| --- | ---: | ---: | ---: |
| `line-orderbook` | 4.877% | 1.599 | 10.607 |
| `multi-basic` | 2.093% | 0.674 | 6.583 |
| `multi-light` | 2.082% | 0.652 | 6.269 |
| `multi-compact` | 1.876% | 0.589 | 6.054 |
| `line-momentum-down` | 1.795% | 0.691 | 6.751 |
| `multi-two-series` | 1.778% | 0.518 | 5.718 |
| `line-no-badge` | 1.756% | 0.610 | 5.680 |
| `line-exaggerated` | 1.736% | 0.670 | 6.882 |
| `line-reference` | 1.706% | 0.625 | 6.570 |
| `candle-line-mode` | 1.703% | 0.643 | 6.563 |
| `candle-wide-window` | 1.670% | 0.443 | 4.976 |
| `line-show-value-windows` | 1.677% | 0.757 | 7.964 |
| `candle-basic` | 1.644% | 0.480 | 5.280 |
| `line-degen` | 1.666% | 0.690 | 6.925 |
| `line-momentum-up` | 1.664% | 0.694 | 6.927 |
| `line-basic-light` | 1.649% | 0.577 | 6.287 |
| `candle-light` | 1.614% | 0.439 | 4.788 |
| `candle-no-live` | 1.585% | 0.478 | 5.271 |
| `line-minimal-badge` | 1.568% | 0.602 | 6.621 |
| `line-basic-dark` | 1.513% | 0.588 | 6.431 |
| `line-rounded-windows` | 1.490% | 0.615 | 6.422 |
| `line-text-windows` | 1.436% | 0.612 | 6.426 |
| `candle-mode-controls` | 1.082% | 0.283 | 3.999 |
| `line-no-grid-no-fill` | 1.024% | 0.341 | 5.436 |
| `line-empty` | 0.422% | 0.091 | 1.255 |
| `line-loading` | 0.356% | 0.068 | 1.494 |
| `candle-loading` | 0.329% | 0.053 | 0.983 |

## Accepted Parity Gate

- The release gate is `scripts/diff-storybook.sh --fail-changed-pct 5 --fail-rms 12`.
- `line-orderbook` is the largest remaining outlier, but it is below the accepted 5% changed-pixel threshold. Weighted label picks, seed, stream phase, and two-pass bitmap text outline rendering now match the upstream reference more honestly; the remaining delta is mostly cross-platform text antialiasing and tiny motion-phase differences.
- Remaining visual deltas are text/grid halo differences, mostly from SwiftUI text rasterization versus canvas text drawing, plus the known orderbook phase sensitivity.
