# Animation Model

Liveline Swift uses a `TimelineView` plus SwiftUI `Canvas` renderer. The package keeps small render state between frames so the input arrays can update normally while the visual output remains smooth.

## Real-Time Value Interpolation

The latest value is eased toward the incoming value each frame. Small ticks settle quickly; larger jumps use a slower adaptive speed so the line moves without snapping.

## Range Easing

The Y range is computed from visible points, the current value, and any reference line. The displayed min/max values interpolate toward the target range so the grid and line do not jump when new highs or lows arrive.

## Line Path

The line uses Fritsch-Carlson monotone cubic interpolation. The curve stays within local point bounds, which avoids the overshoot that can make financial charts misleading.

## Reveal States

When `loading` is true, or when no data is present, the chart draws a breathing placeholder line. When data becomes available, the real chart morphs from that placeholder shape into the live chart while the grid, fill, badge, and dot fade in.

During the reveal, the line color also blends from the placeholder/grid-label color into the accent color. This matches the upstream choreography and avoids a sudden color flash when data replaces the loading state.

## Scrubbing

Drag scrubbing converts the pointer location to a chart time, interpolates a value at that time, and draws a crosshair tooltip. The live dot and the part of the line to the right of the scrub point dim so the inspected history reads clearly.

## Momentum Effects

Momentum is detected from recent points, not the total visible range. The live dot and arrows use semantic green/red for up/down movement. Passing `momentum` in the configuration overrides automatic detection.

## Degen Effects

`LivelineDegenOptions` adds particle bursts and a short chart shake on momentum changes. This is intentionally opt-in.
