# Animation Model

Liveline Swift uses a SwiftUI `Canvas` renderer with one motion policy. Static
charts use a plain Canvas; charts with live interpolation, a reveal in flight,
or an explicitly continuous effect use `TimelineView` only while frames are
needed. The package keeps small render state between frames so input arrays can
update normally while the visual output remains smooth.

## Frame Scheduling

The motion policy combines chart capabilities, reveal state, pause, system
Reduce Motion, and deterministic test time. It produces both the effective
frame delta and whether a timeline is required, so individual renderer branches
cannot accidentally start their own animation clocks. Date formatters are
cached, visible time samples use binary search, and Canvas drawing remains free
of callbacks or other external side effects.

## Real-Time Value Interpolation

The latest value is eased toward the incoming value each frame. Small ticks settle quickly; larger jumps use a slower adaptive speed so the line moves without snapping.

## Range Easing

The Y range is computed from visible points, the current value, and any reference line. The displayed min/max values interpolate toward the target range so the grid and line do not jump when new highs or lows arrive.

## Line Path

The line uses Fritsch-Carlson monotone cubic interpolation. The curve stays within local point bounds, which avoids the overshoot that can make financial charts misleading.

## Reveal States

When `loading` is true, or when no data is present, the chart draws a breathing placeholder line. When data becomes available, the real chart morphs from that placeholder shape into the live chart while the grid, fill, badge, and dot fade in.

During the reveal, the line color also blends from the placeholder/grid-label color into the accent color. This matches the upstream choreography and avoids a sudden color flash when data replaces the loading state.

The additional chart families use the same reveal state to animate their own geometry rather than applying a mask or scale to a finished chart. Time-based paths grow through interpolated points; bars, intervals, whiskers, and stacked marks expand from their semantic baseline; point marks appear with a stable stagger; and radial charts sweep their real angles. This keeps intermediate frames meaningful and gives every renderer the same inherent motion model as the line chart.

## Scrubbing

Drag scrubbing converts the pointer location to a chart time, interpolates a value at that time, and draws a crosshair tooltip. The live dot and the part of the line to the right of the scrub point dim so the inspected history reads clearly.

## Momentum Effects

Momentum is detected from recent points, not the total visible range. The live dot and arrows use semantic green/red for up/down movement. Passing `momentum` in the configuration overrides automatic detection.

## Dither Style

`LivelineChartConfiguration.style = .dither(...)` renders chart marks into an
isolated Canvas layer, applies a shared 4×4 ordered Bayer texture, and adds
colour bloom plus deterministic winking sparkles. Because the treatment happens
at the compositor boundary, the same implementation covers every chart kind
without softening axes, labels, crosshairs, or tooltips. Static charts request a
timeline only when animated bloom or sparkles are enabled.

## Candle Line Mode

Candlestick charts animate between OHLC bars and line mode with the same staged transition as the web implementation. Candle bodies collapse toward their close values, the line fades in with accent-color blending, tick-level line density ramps in after the first part of the morph, and the candle close-price dash crossfades into the line dash.

## Degen Effects

`LivelineDegenOptions` adds particle bursts and a short chart shake on momentum changes. This is intentionally opt-in.

## Pause

Paused charts receive a zero animation delta and a frozen presentation time in
every renderer subsystem. Their current state remains visible without particles,
shake, pulses, or interpolation advancing behind the pause.

## Reduced Motion

Liveline follows the system Reduce Motion setting automatically. Renderer reveals complete immediately, dither bloom and sparkles freeze, continuous pulses stop, and opt-in particle or shake effects are suppressed while static chart state and color feedback remain available.
