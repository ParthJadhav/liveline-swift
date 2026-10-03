# Visual Parity Status

This document tracks the native renderer against the upstream React/canvas Liveline implementation.

## Current Coverage

- `Docs/ScenarioMatrix.md` defines <!-- catalog:scenarios -->92<!-- /catalog --> deterministic Storybook scenarios covering all <!-- catalog:families -->47<!-- /catalog --> chart kinds, the streamgraph style variant, and loading, empty, control, and customization variants.
- `scripts/capture-storybook.sh` captures full Storybook screenshots into `Media/storybook`.
- `scripts/capture-storybook.sh --chart-only` captures the same <!-- catalog:scenarios -->92<!-- /catalog --> scenario IDs into `Media/storybook-chart-only`.
- `scripts/capture-web-references.sh` renders the 27 scenarios supported by the upstream React/canvas package into `Media/web-reference`.
- `scripts/diff-storybook.sh` strictly compares 19 structurally equivalent upstream/native scenarios and reports eight intentional control-layout exclusions. The native-only scenarios are reviewed through their deterministic captures.
- The accepted parity wrapper writes disposable reference/native/heatmap triptychs and `summary.csv` to `.build/storybook-diff`. Set `VISUAL_DIFF_OUT_DIR` to intentionally refresh the historical `Media/storybook-diff` artifacts.
- The renderer now ports upstream primitives for loading waveform shape, loading breath alpha, elapsed animation timing, reveal/pause snap thresholds, reveal-time line color blending, empty-state center gap, curved badge tail geometry, badge sizing constants, badge text weight/baseline, semantic momentum badge colors, live dot outer/core structure, icon mode controls, multi-series endpoint pulse behavior, multi-series label reserve/right-padding split, labeled series-chip baseline nudging, live value letter spacing, outlined orderbook labels without per-frame platform bitmaps, orderbook phase calibration, centered reference-line labels, baseline-adjusted and x-aligned axis text, window control baseline nudging, segmented candle wicks, live candle glow, candle close-price opacity, candle line-mode morph/density transitions, OHLC collapse/expand reveal behavior, adaptive range settling, deterministic snapshot timing, time-axis interval thresholds, overlap suppression, grid/time-axis label state, and coarse/fine grid interval selection.

## Recorded Comparison (2026-08-09)

The commands below reproduce the recorded procedure with the current wrapper. The measurements are historical evidence, not acceptance of a newer revision.

```bash
swift test
xcodebuild -project Examples/LivelineDemo/LivelineDemo.xcodeproj -scheme LivelineDemo -destination 'generic/platform=iOS Simulator' build
scripts/capture-storybook.sh --chart-only
scripts/verify-visual-parity.sh
```

`scripts/capture-storybook.sh` injects the scenario wait through the testing SPI environment, advances native animations with a fixed 60fps snapshot cursor, and waits an extra 0.60 seconds before screenshotting so captures are repeatable. It uses the upstream orderbook seed `12345`. `line-orderbook` defaults to a `3.10` second snapshot elapsed time to align the seeded label stream with the browser reference after Playwright navigation and layout. The loading/empty-state scenarios default to `2.80` seconds to align the deterministic native waveform with the checked-in browser references. Other scenarios use the default 2.2 second snapshot elapsed time unless overridden. `STORYBOOK_ORDERBOOK_RANDOM_SEED` can override the Storybook orderbook seed for local tuning.

The latest chart-only comparison, verified on 2026-08-09 against upstream commit `069899598a11e00094ea1eb6b838404825f828be`, is:

| Scenario | Changed pixels | Mean abs | RMS |
| --- | ---: | ---: | ---: |
| `line-orderbook` | 5.055% | 1.895 | 12.695 |
| `line-momentum-down` | 2.253% | 1.032 | 9.804 |
| `line-no-badge` | 2.237% | 0.950 | 9.118 |
| `line-exaggerated` | 2.164% | 1.000 | 9.856 |
| `line-reference` | 2.162% | 0.951 | 9.613 |
| `candle-line-mode` | 2.111% | 0.962 | 9.609 |
| `line-degen` | 2.098% | 1.021 | 9.889 |
| `line-momentum-up` | 2.096% | 1.025 | 9.890 |
| `candle-basic` | 2.092% | 0.820 | 8.866 |
| `candle-wide-window` | 2.079% | 0.754 | 8.548 |
| `candle-no-live` | 2.032% | 0.818 | 8.861 |
| `candle-light` | 1.995% | 0.883 | 8.474 |
| `line-basic-light` | 1.988% | 0.964 | 9.012 |
| `line-minimal-badge` | 1.976% | 0.921 | 9.629 |
| `line-basic-dark` | 1.930% | 0.907 | 9.501 |
| `line-loading` | 1.440% | 0.619 | 7.715 |
| `candle-loading` | 1.413% | 0.548 | 7.044 |
| `line-empty` | 1.382% | 0.740 | 9.075 |
| `line-no-grid-no-fill` | 1.298% | 0.600 | 8.581 |

The intentionally excluded upstream scenarios are `line-show-value-windows`, `line-rounded-windows`, `line-text-windows`, `candle-mode-controls`, `multi-basic`, `multi-light`, `multi-compact`, and `multi-two-series`. Upstream places their controls inside the plot layout; Liveline Swift gives those controls dedicated space so the remaining chart and placeholder canvas stays centered.

## Accepted Parity Gate

- The release gate is `scripts/verify-visual-parity.sh`. It owns the eight exclusions and accepted thresholds for local checks and CI. Directory overrides are `WEB_REFERENCE_OUT_DIR`, `STORYBOOK_OUT_DIR`, and `VISUAL_DIFF_OUT_DIR`; `WEB_REFERENCE_SCENARIOS` selects a space-separated smoke subset. Only the orderbook scenario receives the narrow 5.1% / 13 RMS allowance needed for the intentionally stronger native secondary labels; the other 18 strict comparisons retain the 5% / 12 RMS gate.
- `line-orderbook` is the largest remaining outlier and passes its explicit 5.1% / 13 RMS allowance. Weighted label picks, seed, and stream phase align with the upstream reference without allocating platform bitmaps in the render loop; the remaining delta is stronger native secondary-label contrast plus cross-platform text antialiasing.
- The excluded control-layout scenarios and all native-only chart forms remain covered by deterministic screenshot review even though they are not thresholded against structurally different upstream output.
- Remaining strict-comparison deltas are text/grid halo differences, mostly from SwiftUI text rasterization versus canvas text drawing, plus the intentional native contrast increase.
