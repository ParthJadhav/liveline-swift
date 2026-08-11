# Liveline demo videos (Remotion)

Four release compositions live here:

| Composition ID | Output | Length |
| --- | --- | --- |
| `LivelinePlatforms` | `Media/liveline-platforms.mp4` | ~22s |
| `Liveline060` | `Media/liveline-0-6-0-demo.mp4` | 50s |
| `Liveline070` | `Media/liveline-0-7-0-demo.mp4` | 26s |
| `LivelineAdvancedPR` | `Media/liveline-advanced-charts-pr.mp4` | 25s |

```sh
bun install --frozen-lockfile
bun run studio       # live-edit at http://localhost:3000
bun run render       # writes ../Media/liveline-platforms.mp4
bun run render:060   # writes ../Media/liveline-0-6-0-demo.mp4
bun run render:070   # writes ../Media/liveline-0-7-0-demo.mp4
bun run render:advanced-pr # writes ../Media/liveline-advanced-charts-pr.mp4
```

## `LivelineAdvancedPR` — the advanced-chart PR demo

The 25-second dark-mode cut introduces the 21 new chart families in PR #6,
then spotlights distribution/planning, relationship/multivariate, and financial
charts before showing the authentic animated Dither showcase and closing on the
accessibility and verification story. Native chart captures live in
`public/advanced-pr/`; the framing, reveals, typography, and scene transitions
are authored in `src/advanced-pr/`.

## `Liveline070` — the 0.7.0 improvement demo

The 26-second cut shows the adaptive Live dashboard, stronger chart-label
contrast, searchable and filterable Storybook, static gallery previews, the
SwiftUI code workbench, larger accessibility text, Spanish localization, and
the renderer file split. Its app screenshots live in `public/improvements/`;
the animated chart footage remains authentic output produced by `ShotGen`.

## `Liveline060` — the 0.6.0 release video

50s at 1920×1080, 30fps, on the library's dark theme. Scene order and frame
ranges are declared in `SCENES` in [`src/Video060.tsx`](src/Video060.tsx):
title → six new chart kinds → zoom/pan/follow-live → annotations → legend →
image-export beat → theme crossfade → RTL and localization → accessibility →
stats outro. Scenes overlap by `CROSSFADE` frames, so every transition is a
dissolve rather than a cut through the background.

Almost every chart in it is **authentic library output**. `tools/shotgen` is a
small SwiftPM executable that depends on this repository and drives Liveline's
public `LivelineChartImageExporter` once per video frame, advancing the chart's
data by one sample between frames and writing PNG sequences into
`public/clips/<name>/frame-NNN.png`:

```sh
cd tools/shotgen
SHOTGEN_MODE=frames swift run ShotGen          # 975 frames across 12 clips
SHOTGEN_MODE=frames SHOTGEN_CLIPS_ONLY=rtl,legend swift run ShotGen
swift run ShotGen                              # the stills in Docs/pr-assets
```

`public/clips/` is generated and git-ignored (~82 MB); regenerate it before
rendering on a fresh checkout. [`src/clips.tsx`](src/clips.tsx) plays the
sequences back against `useCurrentFrame()` and declares each clip's length.

The one chart in `Liveline060` that is *not* library output is the zoom/pan
scene: a per-frame PNG export cannot show a viewport being pinched, so
`ZoomPanScene` recreates the dark line chart in SVG and animates the viewport,
the touch points and the follow-live chip directly.

`bgm.m4a` is 30s, so `Liveline060` plays it twice with a crossfade at frame 855
rather than looping it hard.

## `LivelinePlatforms` — the cross-platform demo

Editable source for `Media/liveline-platforms.mp4` — a ~22s, 1920×1080 30fps
demo showing the same Liveline chart running on every supported Apple platform
(watchOS, iOS, iPadOS, macOS, tvOS, visionOS), in Apple light-mode styling with
a generated music bed.

The minimum OS versions shown in the video come from `Package.swift`; if the
platform list or minimum versions change, update `PLATFORMS` in
[`src/Video.tsx`](src/Video.tsx). Chart colors mirror the light theme of
`Sources/Liveline/LivelinePalette.swift` via [`src/theme.ts`](src/theme.ts).

Structure:

- `src/LiveChart.tsx` — SVG recreation of the Liveline light-theme line chart
  (dotted grid, momentum badge, dashed reference line, glow dot).
- `src/charts.tsx` — additional Liveline renderers recreated for variety:
  gauge (watchOS), signed bars (iOS/iPadOS), candlestick + volume (macOS),
  multi-series + donut (iPadOS), stacked area (tvOS), heatmap (visionOS).
  Each has an entrance animation and stays live via the shared stream clock.
- `src/chartData.ts` — deterministic data stream shared by all devices so the
  charts stay in sync.
- `src/devices.tsx` — device frames compositing the chart behind real Apple
  product bezels (see below).
- `src/Video.tsx` — scenes (intro → six platform spotlights → all-devices grid
  → install outro) plus the music bed and SFX cues.

## Assets

In `public/`:

- `bezels/*.png` — official Apple product bezels (iPhone 17 Pro, iPad Pro M5,
  MacBook Pro M5, Apple Watch Series 11, Apple TV 4K) from
  [Apple Design Resources](https://developer.apple.com/design/resources/)
  (`devimages-cdn.apple.com/design/resources/download/Bezel-*.dmg`), used under
  the bundled `Apple Design Resources License.rtf`. Screen cutout rects in
  `src/devices.tsx` were measured from each PNG's alpha channel.
- `bezels/visionpro.jpg` — Apple's Vision Pro product photo (Apple Store
  imagery; there is no official bezel for Vision Pro). Composited with a
  visionOS-style glass window carrying the chart.
- `audio/bgm.m4a` — music bed generated locally with MusicGen
  (facebook/musicgen-small) via the media-use audio engine; loudness-normalized.
- `audio/sfx/*.mp3` — transition sounds from the media-use bundled SFX library
  (Pixabay Content License, free for commercial use).
- `clips/*/frame-NNN.png` — generated chart footage; see `tools/shotgen` above.
  Not checked in.
