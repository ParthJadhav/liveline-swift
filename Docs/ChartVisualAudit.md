# Chart visual audit

This is the catalog-level record for the pixel-quality review completed against
the deterministic iPhone 17 Pro baseline. The authoritative scenario inventory
remains `storybook-scenarios.json`; this document records the human visual pass
and the renderer-level conclusions.

## Defects found and corrected

| Surface | Defect | Correction | Proof |
| --- | --- | --- | --- |
| Marimekko | Spacing was charged at the outer edges and reveal changed each segment's proportions. | Budget only internal column/segment gaps, absorb floating remainder at the final edge, and clip settled geometry during reveal. | Exact bounds, gap, ratio, and interaction-anchor tests plus `marimekko-basic`. |
| Contour | Coarse per-cell line fragments produced angular isolines and translucent checkerboard seams. | Bicubic bounded sampling, marching-squares stitching, closed-path smoothing, grouped opaque-composited fills, rounded joins, and plot clipping. | Dense/closed/in-bounds geometry tests plus `contour-basic`. |
| Horizon | Folded continuous bands used hard linear corners that were difficult to track. | Monotone band paths with rounded baseline edges and plot clipping. Flat fold plateaus remain intentional. | `horizon-basic` at 100% and 200%. |
| Range and stacked area | Continuous upper/lower boundaries exposed faceted diagonals. | Reuse bounded monotone splines for both fills and outlines. | Both range and all three stacked-area scenarios. |
| Violin and ridgeline | Density outlines exposed polygon corners. | Smooth the closed violin hull and use monotone ridge tops with round caps/joins. | `violin-basic` and `ridgeline-basic`. |
| Multi-series labels | A direct series label could share the value-axis gutter and collide with `$100.00`. | Reserve independent data-label and axis-label gutters. | Dark, light, compact, and two-series scenarios. |
| Bump and direct labels | Equal or near-equal endpoints could overlap. | Ordered constrained label distribution with a 13-point preferred gap and leader lines when moved. | `bump-basic` and direct-label geometry tests. |

## Intentional geometry preserved

The review did not smooth step transitions, bump-chart rank segments, candles,
waterfalls, market-depth curves, Renko bricks, point-and-figure symbols,
Marimekko rectangles, waffle cells, or categorical radar/parallel-coordinate
segments. Their corners carry meaning. Visual polish must not rewrite data.

## Catalog result

“Pass” means the family was reviewed in the complete contact-sheet sweep and in
its raw full-resolution screenshots. Families touched by shared renderer changes
were recaptured and reinspected separately.

| Family | Scenarios reviewed | Result |
| --- | --- | --- |
| Line | `line-basic-dark`, `line-basic-light`, `line-no-grid-no-fill`, `line-minimal-badge`, `line-no-badge`, `line-momentum-up`, `line-momentum-down`, `line-exaggerated`, `line-show-value-windows`, `line-rounded-windows`, `line-text-windows`, `line-zoom-pan`, `line-reference`, `line-orderbook`, `line-degen` | Pass |
| State | `line-loading`, `line-empty`, `line-empty-controls`, `candle-loading` | Pass |
| Candles | `candle-basic`, `candle-light`, `candle-line-mode`, `candle-mode-controls`, `candle-no-live`, `candle-wide-window` | Pass |
| Multi-series | `multi-basic`, `multi-light`, `multi-compact`, `multi-two-series` | Pass |
| Bars | `bar-basic`, `bar-signed` | Pass |
| Range bands | `range-basic`, `range-center-line` | Pass |
| Scatter | `scatter-basic`, `scatter-connected` | Pass |
| Step | `step-basic`, `step-centered` | Pass |
| Lollipop | `lollipop-basic`, `lollipop-diamond` | Pass |
| Bubble | `bubble-basic`, `bubble-diameter` | Pass |
| Box plot | `boxplot-basic`, `boxplot-minimal` | Pass |
| Waterfall | `waterfall-basic`, `waterfall-no-connectors` | Pass |
| Error bar | `errorbar-basic`, `errorbar-diamond` | Pass |
| Dumbbell | `dumbbell-basic`, `dumbbell-directional` | Pass |
| Stacked bar | `stackedbar-basic`, `stackedbar-normalized` | Pass |
| Stacked area | `stackedarea-basic`, `stackedarea-normalized`, `stacked-area-stream` | Pass |
| Timeline | `timeline-basic`, `timeline-compact` | Pass |
| Heatmap | `heatmap-basic`, `heatmap-values` | Pass |
| Radar | `radar-basic`, `radar-minimal` | Pass |
| Donut | `donut-basic`, `donut-thin` | Pass |
| Gauge | `gauge-basic`, `gauge-target` | Pass |
| Funnel | `funnel-basic`, `funnel-compact` | Pass |
| Histogram | `histogram-basic` | Pass |
| Bullet | `bullet-basic` | Pass |
| Treemap | `treemap-basic` | Pass |
| Sunburst | `sunburst-basic` | Pass |
| Sankey | `sankey-basic` | Pass |
| Violin | `violin-basic` | Pass |
| Ridgeline | `ridgeline-basic` | Pass |
| Calendar heatmap | `calendar-heatmap-basic` | Pass |
| Gantt | `gantt-basic` | Pass |
| Chord | `chord-basic` | Pass |
| Parallel coordinates | `parallel-basic` | Pass |
| Hexbin | `hexbin-basic` | Pass |
| Bump | `bump-basic` | Pass |
| Horizon | `horizon-basic` | Pass |
| Marimekko | `marimekko-basic` | Pass |
| Polar area | `polar-area-basic` | Pass |
| Network | `network-basic` | Pass |
| Contour | `contour-basic` | Pass |
| Ternary | `ternary-basic` | Pass |
| Waffle | `waffle-basic` | Pass |
| Volume profile | `volume-profile-basic` | Pass |
| Renko | `renko-basic` | Pass |
| Heikin-Ashi | `heikin-ashi-basic` | Pass |
| Market depth | `market-depth-basic` | Pass |
| OHLC + volume | `ohlc-volume-basic` | Pass |
| Point-and-figure | `point-figure-basic` | Pass |

## Release evidence

- 92 manifest scenarios, 92 uniquely owned PNG baselines, one reference size.
- Focused geometry tests cover spacing budgets, closed isolines, duplicate
  contour coordinates, direct-label separation, and gutter ownership.
- Shared interaction geometry covers Marimekko hit targets.
- Standard and Dither renderer smoke tests cover the advanced catalog.
- The contour result is cached across reveal frames and benchmarked in the
  opt-in release performance suite.
- Release acceptance still requires the commands in
  [Chart Visual Quality Standard](ChartQuality.md) and
  [Development and Verification](Development.md) to pass on the release commit.
