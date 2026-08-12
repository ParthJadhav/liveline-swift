# Advanced-chart PR demo

This file is the durable brief and production recipe for the advanced-chart pull-request video.

## Confirmed creative preferences

- Treat every demo as a public product reel, not as a progress report addressed to the requester.
- Use only enough on-screen text to identify and understand the feature at a glance. Prefer a category, chart name, and one short phrase; avoid explanatory paragraphs and implementation badges.
- Show every new chart family in the pull request; the canonical set contains 21 charts.
- Give every chart a dedicated scene. Do not combine multiple chart families into one frame.
- Use a light visual system for the video: warm-white canvas, pale blue surfaces, dark ink, and saturated Liveline accents.
- Dither scenes must use advanced chart implementations introduced by this pull request. Do not use legacy line, bar, donut, or radar examples as evidence for the feature.
- Use a bright, upbeat, kinetic technology music bed with no vocals. Avoid the previous ambient track.
- Render in 16:9 at 1920×1080, 30 fps. Preserve generous video-safe margins.
- Source chart visuals from Liveline's native SwiftUI renderer. Do not redraw chart geometry in React, SVG, or CSS.
- Animate the data and marks inside the native `LivelineChart`. Never create the impression of chart motion by translating, scaling, wiping, or clipping a static chart container.
- Keep the chart viewport fixed in Remotion. Remotion owns sequencing, labels, transitions, and audio; Liveline owns all chart motion.

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

The script builds the iOS Storybook app, captures all 21 charts with a forced light theme, records a native live-data clip for every chart, and records the four advanced Dither treatments directly from the renderer. Generated inputs live under `remotion/public/advanced-pr-light/`:

- `*.png` — settled reference stills and poster inputs.
- `live/*.mp4` — standard scenes driven by changing SwiftUI data at 30 fps.
- `dither/*.mp4` — changing native chart data with animated Dither rendering.

The app launch flag `--advanced-demo-live` selects `StorybookAdvancedLiveChart`, which updates each advanced model while preserving stable IDs. Liveline's own reveal, value-range, geometry, and Dither paths render the motion. These are the only acceptable chart-animation sources for this reel.

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

Before publishing, inspect at least one frame from every section and two time-separated frames from several standard and every Dither clip. Confirm that chart pixels change while the video card bounds remain fixed, and that all 21 chart IDs occur exactly once in the standard chart sequence.

The capture script waits for each Storybook launch to settle before recording. The verification step also rejects any native clip containing sustained black frames, so a simulator focus or launch failure cannot silently ship in the reel.
