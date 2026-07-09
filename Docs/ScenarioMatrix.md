# Scenario Matrix

The iOS demo includes a Storybook tab and a single-scenario launch mode for screenshot capture.

```bash
scripts/capture-storybook.sh
```

Screenshots are written to `Media/storybook`.

For chart-only comparison screenshots without the scenario heading copy:

```bash
scripts/capture-storybook.sh --chart-only
```

Chart-only screenshots are written to `Media/storybook-chart-only`. The capture script supports `STORYBOOK_SCENARIOS` for partial runs, `STORYBOOK_CAPTURE_WAIT_SECONDS` for one global snapshot elapsed time, `STORYBOOK_SCENARIO_WAIT_OVERRIDES` for entries like `line-orderbook=3.40 line-loading=2.80`, and `STORYBOOK_ORDERBOOK_RANDOM_SEED` for local orderbook stream tuning. Native captures pass the elapsed time into `snapshotElapsedTime`, advance animations with a fixed 60fps snapshot cursor, then wait an extra 0.60 seconds before taking the simulator screenshot.

To capture the matching upstream React/canvas references:

```bash
scripts/capture-web-references.sh
```

Reference screenshots are written to `Media/web-reference`. The script copies a tiny Vite/Playwright app from `scripts/web-reference` into `.build`, clones `benjitaylor/liveline` into `.build/liveline-upstream` when needed, and renders each scenario at the same iPhone-sized viewport used by the native capture.

To compare native chart-only screenshots against the upstream references:

```bash
scripts/diff-storybook.sh
```

Diff panels are written to `Media/storybook-diff` as reference/native/heatmap triptychs, with numeric metrics in `Media/storybook-diff/summary.csv`.

## Scenarios

| ID | Area | Coverage |
| --- | --- | --- |
| `line-basic-dark` | Line | Default dark line with grid, fill, and badge. |
| `line-basic-light` | Line | Default light theme. |
| `line-no-grid-no-fill` | Line | Minimal chart with no grid and no fill. |
| `line-minimal-badge` | Line | Minimal badge variant. |
| `line-no-badge` | Line | Badge disabled and compact right padding. |
| `line-momentum-up` | Line | Forced up momentum. |
| `line-momentum-down` | Line | Forced down momentum. |
| `line-exaggerated` | Line | Tight Y-axis. |
| `line-show-value-windows` | Line | Live value display and window controls. |
| `line-rounded-windows` | Line | Rounded window controls. |
| `line-text-windows` | Line | Text-only window controls. |
| `line-reference` | Line | Reference line and label. |
| `line-orderbook` | Line | Orderbook stream labels with static pulse suppressed for diff stability. |
| `line-degen` | Line | Particle/shake mode. |
| `line-loading` | State | Loading line. |
| `line-empty` | State | Empty state. |
| `candle-basic` | Candles | OHLC bars with live candle. |
| `candle-light` | Candles | Light theme candles. |
| `candle-line-mode` | Candles | Candle data rendered as line. |
| `candle-mode-controls` | Candles | Built-in line/candle icon mode controls. |
| `candle-no-live` | Candles | Committed bars only. |
| `candle-wide-window` | Candles | Wider time range and smaller candles. |
| `candle-loading` | State | Candle loading setup. |
| `multi-basic` | Multi-series | Three lines and series chips. |
| `multi-light` | Multi-series | Light theme multi-series. |
| `multi-compact` | Multi-series | Dot-only series chips. |
| `multi-two-series` | Multi-series | Two series. |
| `bar-basic` | Bars | Rounded positive time buckets. |
| `bar-signed` | Bars | Narrow square bars diverging from a custom target baseline. |
| `range-basic` | Range bands | Filled forecast interval with emphasized boundaries. |
| `range-center-line` | Range bands | Light interval with a dashed center estimate. |
| `scatter-basic` | Scatter | Independent circular observations. |
| `scatter-connected` | Scatter | Diamond observations with a curved connection. |
| `step-basic` | Step | Trailing transitions with a subtle fill. |
| `step-centered` | Step | Centered transitions with an unfilled heavy line. |
| `lollipop-basic` | Lollipop | Signed circular heads around zero. |
| `lollipop-diamond` | Lollipop | Diamond heads around a custom target. |
| `bubble-basic` | Bubble | Request volume mapped to visible area. |
| `bubble-diameter` | Bubble | Linear diameter scaling with bold outlines. |
| `boxplot-basic` | Box plot | Filled rolling five-number summaries. |
| `boxplot-minimal` | Box plot | Narrow outlined summaries with heavy medians. |
| `waterfall-basic` | Waterfall | Connected cumulative gains and losses. |
| `waterfall-no-connectors` | Waterfall | Wide square changes without connectors. |
| `errorbar-basic` | Error bar | Circular estimates with capped uncertainty intervals. |
| `errorbar-diamond` | Error bar | Diamond estimates with wider caps and translucent centers. |
| `dumbbell-basic` | Dumbbell | Paired before/after values with gradient connectors. |
| `dumbbell-directional` | Dumbbell | Square endpoints with direction chevrons. |
| `stackedbar-basic` | Stacked bar | Absolute multi-segment time buckets. |
| `stackedbar-normalized` | Stacked bar | Segment shares normalized to 100 percent. |
| `stackedarea-basic` | Stacked area | Layered absolute volumes with boundaries. |
| `stackedarea-normalized` | Stacked area | Layered composition normalized to 100 percent. |
| `timeline-basic` | Timeline | Labeled overlapping intervals across three lanes. |
| `timeline-compact` | Timeline | Slim square intervals without guides or labels. |
| `heatmap-basic` | Heatmap | Regional load intensity across four labeled rows. |
| `heatmap-values` | Heatmap | Wide rounded cells with embedded values. |
| `radar-basic` | Radar | Six labeled axes, five grid levels, fill, and markers. |
| `radar-minimal` | Radar | Unlabeled three-level outline with no markers. |
| `donut-basic` | Donut | Composition ring with outside labels and center total. |
| `donut-thin` | Donut | Thin ring with value-bearing labels. |
| `gauge-basic` | Gauge | Tick-marked 240-degree capacity gauge. |
| `gauge-target` | Gauge | Half-circle SLA gauge with target marker. |
| `funnel-basic` | Funnel | Labeled conversion stages with values. |
| `funnel-compact` | Funnel | Tight square stages with labels only. |

## Parity Notes

The gallery is the audit surface for visual work. Scenarios inherited from the upstream chart must pass the web-reference diff before marking parity complete; native-only chart types are reviewed through their deterministic captures. Static parity scenarios suppress the live pulse unless pulse behavior is the thing being inspected. The current native renderer ports the web loading waveform, empty-state center gap, curved badge path, momentum badge colors, live dot structure, icon mode controls, centered reference labels, baseline-adjusted axis text, segmented candle wicks, live candle glow, deterministic snapshot timing, time-axis intervals, grid/time-axis label state, and coarse/fine grid interval selection.
