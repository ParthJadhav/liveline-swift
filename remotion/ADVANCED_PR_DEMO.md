# Advanced-chart PR demo

This file is the durable brief and production recipe for the advanced-chart pull-request video.

## Confirmed creative preferences

- Show every new chart family in the pull request; the canonical set contains 21 charts.
- Give every chart a dedicated scene. Do not combine multiple chart families into one frame.
- Use a light visual system for the video: warm-white canvas, pale blue surfaces, dark ink, and saturated Liveline accents.
- Dither scenes must use advanced chart implementations introduced by this pull request. Do not use legacy line, bar, donut, or radar examples as evidence for the feature.
- Use a bright, upbeat, kinetic technology music bed with no vocals. Avoid the previous ambient track.
- Render in 16:9 at 1920×1080, 30 fps. Preserve generous video-safe margins.
- Source chart visuals from Liveline's native SwiftUI renderer. Do not redraw chart geometry in React, SVG, or CSS.

## Canonical scene order

1. Brief title card.
2. Distribution and planning: violin, ridgeline, calendar heatmap, Gantt, bump, horizon.
3. Relationships and multivariate analysis: chord, parallel coordinates, hexbin, network, contour, ternary.
4. Proportional composition: Marimekko, polar area, waffle.
5. Financial market structure: volume profile, Renko, Heikin-Ashi, market depth, synchronized OHLC + volume, point-and-figure.
6. Four dedicated Dither scenes using new implementations: violin/gradient, chord/dotted, contour/hatched, market depth/solid.
7. Closing card with the 21-chart and 48-total-family summary.

## Reproduce the assets

From the repository root:

```bash
scripts/capture-advanced-pr-demo-assets.sh
```

The script builds the iOS Storybook app, captures all 21 charts with a forced light theme, and records the four advanced Dither treatments directly from the native renderer. Generated inputs live under `remotion/public/advanced-pr-light/`.

Generate a fresh upbeat music bed only when the creative brief changes:

```bash
python3 remotion/tools/generate-advanced-pr-bgm.py
```

## Validate and render

```bash
cd remotion
bun run verify:advanced-pr
bunx tsc --noEmit
bunx remotion compositions src/index.ts
bun run render:advanced-pr
bun run poster:advanced-pr
```

Or run the checked-in wrapper from the repository root:

```bash
scripts/render-advanced-pr-demo.sh
```

Set `ADVANCED_PR_CAPTURE_ASSETS=true` to regenerate the native light/Dither
inputs first. Set `ADVANCED_PR_REGENERATE_MUSIC=true` only when a new music
prompt is intentionally required.

The final files are:

- `Media/liveline-advanced-charts-pr.mp4`
- `Media/liveline-advanced-charts-pr-poster.png`

Before publishing, inspect at least one frame from every section and two time-separated frames from every Dither clip. Confirm that all 21 chart IDs occur exactly once in the standard chart sequence.
