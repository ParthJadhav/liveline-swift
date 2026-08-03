# API Overview

## `LivelineChart`

`LivelineChart` is the only view most apps need. It fills its parent, so give it a height.

```swift
LivelineChart(data: points, value: latest)
    .frame(height: 280)
```

Initializers:

```swift
LivelineChart(data:value:color:configuration:)
LivelineChart(series:configuration:)
LivelineChart(data:value:candles:candleWidth:liveCandle:lineData:lineValue:color:configuration:)
LivelineChart(bars:color:style:configuration:)
LivelineChart(range:color:style:configuration:)
LivelineChart(scatter:value:color:style:configuration:)
LivelineChart(steps:value:color:style:configuration:)
LivelineChart(lollipops:color:style:configuration:)
LivelineChart(bubbles:color:style:configuration:)
LivelineChart(boxPlots:color:style:configuration:)
LivelineChart(waterfall:color:style:configuration:)
LivelineChart(errorBars:color:style:configuration:)
LivelineChart(dumbbells:color:style:configuration:)
LivelineChart(stackedBars:color:style:configuration:)
LivelineChart(stackedAreas:color:style:configuration:)
LivelineChart(timeline:color:style:configuration:)
LivelineChart(heatmap:color:style:configuration:)
LivelineChart(radar:color:style:configuration:)
LivelineChart(donut:color:style:configuration:)
LivelineChart(gauge:range:color:style:configuration:)
LivelineChart(funnel:color:style:configuration:)
LivelineChart(histogram:color:style:configuration:)
LivelineChart(bullet:color:configuration:)
```

## Data Types

`LivelinePoint`

```swift
LivelinePoint(time: unixSeconds, value: 42.0)
```

`LivelineCandle`

```swift
LivelineCandle(time: openTime, open: 40, high: 44, low: 39, close: 43)
```

`LivelineSeries`

```swift
LivelineSeries(id: "alpha", data: points, value: latest, color: .blue, label: "Alpha")
```

`LivelineRangePoint`

```swift
LivelineRangePoint(time: unixSeconds, lower: 38, upper: 46)
```

Range points normalize reversed bounds during initialization and expose their midpoint.

`LivelineBubblePoint`

```swift
LivelineBubblePoint(time: unixSeconds, value: 82, magnitude: 240)
```

Negative magnitudes normalize to zero. `LivelineBubbleStyle.scale` controls whether magnitude maps to visible area or diameter.

`LivelineBoxPlotPoint`

```swift
LivelineBoxPlotPoint(
    time: unixSeconds,
    minimum: 32,
    lowerQuartile: 38,
    median: 41,
    upperQuartile: 46,
    maximum: 55
)
```

Five-number summaries normalize into ascending order during initialization.

Extended data types:

```swift
LivelineErrorBarPoint(time: unixSeconds, value: 42, lower: 38, upper: 47)
LivelineDumbbellPoint(time: unixSeconds, start: 38, end: 47)
LivelineStackedPoint(time: unixSeconds, values: [18, 12, 7])
LivelineTimelineItem(id: "build", label: "Build", start: start, end: end, lane: 0)
LivelineHeatmapCell(time: unixSeconds, row: 2, value: 0.84)
LivelineRadarPoint(label: "Speed", value: 84)
LivelineCategoryValue(id: "pro", label: "Pro", value: 42)
```

Error bounds, reversed timeline intervals, negative lanes, non-finite stacked values, heatmap rows, and negative categorical values are normalized at initialization.

## Chart Styles

The additional chart types keep their geometry-specific options in dedicated style values:

```swift
LivelineBarStyle(
    widthRatio: 0.7,
    cornerRadius: 3,
    baseline: 0,
    positiveColor: .green,
    negativeColor: .red,
    showsBaseline: true
)

LivelineRangeStyle(
    fillOpacity: 0.2,
    boundaryLineWidth: 1.5,
    showsCenterLine: true,
    centerLineWidth: 1
)

LivelineScatterStyle(
    symbol: .diamond,
    pointSize: 9,
    outlineWidth: 1,
    connection: .curved,
    connectionLineWidth: 1.5
)

LivelineStepStyle(position: .center, lineWidth: 2, fillOpacity: 0.1)

LivelineLollipopStyle(
    baseline: 0,
    stemWidth: 1.5,
    headSize: 9,
    headSymbol: .diamond
)

LivelineBubbleStyle(
    minimumSize: 5,
    maximumSize: 24,
    fillOpacity: 0.3,
    outlineWidth: 1.5,
    scale: .area
)

LivelineBoxPlotStyle(
    widthRatio: 0.55,
    fillOpacity: 0.16,
    outlineWidth: 1.25,
    medianLineWidth: 2
)

LivelineWaterfallStyle(
    initialValue: 100,
    widthRatio: 0.62,
    connectorLineWidth: 1,
    showsConnectors: true
)

LivelineErrorBarStyle(capWidth: 12, lineWidth: 1.5, pointSize: 8, pointSymbol: .diamond)

LivelineDumbbellStyle(
    lineWidth: 2,
    pointSize: 9,
    startColor: .orange,
    endColor: .blue,
    showsDirection: true
)

LivelineStackedBarStyle(
    mode: .normalized,
    widthRatio: 0.8,
    cornerRadius: 2,
    segmentSpacing: 1,
    colors: [.blue, .purple, .cyan]
)

LivelineStackedAreaStyle(
    mode: .standard,
    colors: [.blue, .purple, .cyan],
    fillOpacity: 0.62,
    boundaryLineWidth: 1
)

LivelineTimelineStyle(barHeightRatio: 0.62, cornerRadius: 5, showsLabels: true)

LivelineHeatmapStyle(
    rowLabels: ["US", "EU", "APAC"],
    minimumOpacity: 0.1,
    maximumOpacity: 0.95,
    showsValues: false
)

LivelineRadarStyle(range: 0...100, gridLevels: 5, fillOpacity: 0.2, showsLabels: true)

LivelineDonutStyle(innerRadiusRatio: 0.6, gapDegrees: 2, showsLabels: true)

LivelineGaugeStyle(
    startAngleDegrees: 150,
    sweepDegrees: 240,
    lineWidth: 18,
    target: 80,
    targetColor: .orange,
    showsTicks: true,
    tickCount: 9
)

LivelineFunnelStyle(
    maximumWidthRatio: 0.88,
    minimumWidthRatio: 0.18,
    spacing: 4,
    showsLabels: true,
    showsValues: true
)
```

Scatter symbols are `.circle`, `.square`, and `.diamond`. Connections are `.none`, `.straight`, and `.curved`.
Step positions are `.leading`, `.center`, and `.trailing`. Bubble scales are `.area` and `.diameter`. Stack modes are `.standard` and `.normalized`. Invalid sizes, widths, opacities, magnitudes, and reversed statistical summaries are normalized before drawing.

Default padding is content-aware: value-axis space is reserved only when value labels are rendered, time-axis space only when a time axis is rendered, and radial/categorical charts use symmetric insets. Explicit `LivelinePadding` values always take precedence. Loading and empty states use a symmetric placeholder viewport even when the populated chart reserves axis or badge space.

## Configuration

`LivelineChartConfiguration` controls appearance and behavior. New code can use
the typed policy groups so unrelated settings do not accumulate in one flat
initializer:

```swift
let configuration = LivelineChartConfiguration(
    appearance: LivelineChartAppearance(
        theme: .dark,
        style: .dither(),
        grid: true,
        fill: true,
        showValue: true
    ),
    effects: LivelineChartEffects(
        badge: true,
        pulse: true,
        fadeEffects: false
    ),
    viewport: LivelineChartViewport(
        window: 60,
        windows: [
            LivelineWindowOption(label: "30s", seconds: 30),
            LivelineWindowOption(label: "1m", seconds: 60)
        ]
    ),
    interaction: LivelineChartInteraction(
        scrub: true,
        showsTooltipOnHover: false,
        showsModeControls: false,
        showsSeriesControls: true
    ),
    motion: LivelineChartMotion(paused: false),
    annotations: LivelineChartAnnotations(
        referenceLine: LivelineReferenceLine(value: 42, label: "Open")
    ),
    formatting: LivelineChartFormatting(
        value: { $0.formatted(.number.precision(.fractionLength(2))) }
    )
)
```

The flat initializer and properties remain source-compatible projections over
these groups:

```swift
LivelineChartConfiguration(
    theme: .dark,
    style: .dither(
        LivelineDitherStyle(
            variant: .gradient,
            bloom: .low,
            maximumFramesPerSecond: 30
        )
    ),
    window: 60,
    windows: [
        LivelineWindowOption(label: "30s", seconds: 30),
        LivelineWindowOption(label: "1m", seconds: 60)
    ],
    grid: true,
    badge: true,
    fill: true,
    pulse: true,
    fadeEffects: false,
    showValue: true,
    valueMomentumColor: true,
    referenceLine: LivelineReferenceLine(value: 42, label: "Open"),
    activePoint: LivelineActivePoint(time: Date().timeIntervalSince1970),
    seriesLegendSide: .trailing,
    formatValue: { $0.formatted(.number.precision(.fractionLength(2))) }
)
```

Options added after the flat initializer was frozen — `showsTooltipOnHover`
among them — are set through the typed group or by assigning the flat property,
which keeps the original initializer signature intact:

```swift
var configuration = LivelineChartConfiguration(theme: .dark, window: 60)
configuration.showsTooltipOnHover = true
```

The Swift API keeps the upstream React feature surface but maps union-style props into typed fields. Web `momentum={false}` is `autoDetectMomentum: false`; web `momentum="up"` is `momentum: .up`. Web `degen={true}` is `degen: LivelineDegenOptions()`, and web `degen={false}` is `degen: nil`.

Important options:

| Option | Default | Notes |
| --- | --- | --- |
| `theme` | `.dark` | Controls grid, label, tooltip, and badge colors. Use `.automatic` to follow the system `colorScheme`. |
| `style` | `.standard` | Applies `.dither(LivelineDitherStyle)` universally to line, cartesian, radial, categorical, and financial chart marks. |
| `window` | `30` | Visible time span in seconds. |
| `windows` | `[]` | Adds built-in time horizon buttons. |
| `grid` | `true` | Draws horizontal grid lines and value labels. |
| `badge` | `true` | Draws the live value pill for line charts. |
| `fill` | `true` | Draws a gradient under line charts. |
| `endpointDecorations` | `true` | Draws the endpoint dot and momentum arrows. Disable this for forecast or historical charts where the final point is not a live value. |
| `fadeEffects` | `false` | Enables renderer-driven chart reveals, line edge masks, scrub dimming, axis label, series, and tooltip fade transitions. Disabled by default so charts render at full opacity immediately. |
| `momentum` | `nil` | Use `.up`, `.down`, or `.flat` to override auto detection. |
| `autoDetectMomentum` | `true` | Uses recent velocity to color momentum affordances. |
| `scrub` | `true` | Enables direct data inspection. Touch and pointer platforms use drag scrubbing. On tvOS, focus the chart, press Select, and move left or right; press Select, Up, Down, or Menu to return to normal focus navigation. |
| `showsTooltipOnHover` | `false` | Shows the tooltip when a cursor rests over the chart, with no press or drag. Honored on macOS, on iPadOS with a trackpad, mouse, or Apple Pencil hover, and on visionOS; ignored on tvOS and watchOS, which have no cursor. Works independently of `scrub`, so a chart can be hover-only. |
| `tooltipY` | `14` | Adjusts structured tooltip placement vertically; values above or below the default shift the adaptive placement within the plot bounds. |
| `exaggerate` | `false` | Uses a tighter Y range for small moves. |
| `showValue` | `false` | Shows a live value label above the chart. |
| `degen` | `nil` | Enables particle bursts and chart shake. |
| `loading` | `false` | Shows the breathing loading line. |
| `paused` | `false` | Freezes animation progress visually. |
| `orderbook` | `nil` | Draws streaming bid/ask size labels behind the line. |
| `referenceLine` | `nil` | Keeps a horizontal reference value visible, and widens the automatic value range to include it. |
| `referenceLines` | `[]` | Additional annotation lines on either axis. Draw-time only: they never widen the value range. |
| `referenceBands` | `[]` | Shaded value or time ranges drawn behind the marks. Draw-time only. |
| `activePoint` | `nil` | Draws a pulsing dot at an arbitrary active time/value. If `value` is nil, Liveline interpolates the value from the visible data. |
| `seriesLegendSide` | `.trailing` | Places multi-series endpoint labels to the trailing or leading side of their points. |
| `lineMode` | `false` | Renders candle input as a line. |
| `showsModeControls` | `false` | Explicitly shows line/candle mode controls when the content supports them. |
| `showsSeriesControls` | `true` | Explicitly shows series visibility controls when the content supports them. |

### Universal dither style

`LivelineDitherStyle` exposes `variant` (`gradient`, `dotted`, `hatched`, or
`solid`), `bloom` (`off`, `low`, `high`, or `aura`), `cellSize`, `intensity`,
`sparkleDensity`, `animationSpeed`, `maximumFramesPerSecond`, and `animated`.
The frame-rate limit accepts values from 1 through 120 and defaults to 30.
Values are normalized at the rendering boundary. Bloom and sparkles opt static
charts into frame scheduling only while animation is enabled; pausing or Reduce
Motion keeps the pattern stable.

`snapshotElapsedTime` remains only as a deprecated source-compatibility
property. Screenshot infrastructure uses the testing SPI environment modifier
instead of putting deterministic time into ordinary application configuration.

## Callbacks

```swift
LivelineChartConfiguration(
    onHover: { hover in
        print(hover?.value as Any)
    },
    onWindowChange: { seconds in
        print("window", seconds)
    },
    onModeChange: { mode in
        print(mode)
    },
    onSeriesToggle: { id, visible in
        print(id, visible)
    }
)
```

Callbacks are optional event sinks and never act as feature flags. Built-in
controls are governed explicitly by `showsModeControls`,
`showsSeriesControls`, and the available chart data.

## Annotations

`referenceLines` and `referenceBands` sit in `LivelineChartAnnotations`, beside
the original single `referenceLine`. Both accept the value axis (horizontal) and
the time axis (vertical):

```swift
var configuration = LivelineChartConfiguration(theme: .dark, window: 60)
configuration.referenceLines = [
    LivelineReferenceLine(value: 42, label: "Open"),
    LivelineReferenceLine(
        value: marketOpen.timeIntervalSince1970,
        axis: .time,
        label: "Bell",
        color: .orange,
        dash: .dotted
    )
]
configuration.referenceBands = [
    LivelineReferenceBand(start: 40, end: 44, label: "Target", opacity: 0.10),
    LivelineReferenceBand(axis: .time, start: lunchStart, end: lunchEnd)
]
```

Bands are drawn after the grid and before the marks, so they read as a backdrop;
lines are drawn with the same layering as the single `referenceLine`. Inverted
band bounds are normalized and a band whose bounds are equal collapses to a
hairline. Unlike `referenceLine`, neither array widens a chart's automatic value
range — an annotation outside the visible range is simply not drawn.

## Standalone legend

`LivelineLegend` is an ordinary SwiftUI view, so it scales with Dynamic Type and
exposes one accessibility element per row. Build it from the same content a
chart takes, or from explicit items:

```swift
VStack(alignment: .leading) {
    LivelineChart(series: series).frame(height: 240)
    LivelineLegend(series: series, axis: .horizontal, swatch: .line)
}

LivelineLegend(items: [
    LivelineLegendItem(label: "Cash", color: .mint),
    LivelineLegendItem(label: "Credit", color: .pink)
], axis: .vertical)
```

`LivelineLegendItem.items(donut:style:accent:)`,
`items(funnel:style:accent:)`, and `items(stacked:colors:accent:)` derive rows
that match the colors those renderers resolve.

## Right-to-left layouts

The chart reads `\.layoutDirection` from the environment and mirrors the plot
itself, so it matches the chrome around it in Arabic, Hebrew, and any other RTL
locale — no per-call configuration:

```swift
LivelineChart(data: points, value: points.last?.value ?? 0)
    .environment(\.layoutDirection, .rightToLeft) // usually inherited
```

What mirrors:

- **Time runs right to left.** The newest sample hugs the left edge — the
  reading start — and history trails off to the right, where the fade sits.
- **Everything anchored to the live edge follows it**: the value-axis gutter and
  its labels, the live badge and its tail, momentum arrows, the series legend
  gutter (`seriesLegendSide` is a *logical* side), the orderbook ticker, and the
  tooltip, which opens toward the reading direction first.
- **Canvas text stays upright.** Mirroring is an explicit coordinate reflection,
  not a flipped graphics context, so glyphs are never reversed; labels simply
  switch to the mirrored anchor.
- **Hit testing mirrors with it.** Pointer, scrub, and tvOS remote coordinates
  convert through the same transform, so hovering still selects the sample under
  the finger, and a leftward remote swipe steps toward newer data.
- **Value-ordered kinds mirror too** — the histogram's value axis and the bullet
  chart's measure both grow toward the reading direction.
- **Radial kinds are unchanged**: donut, gauge, radar, and the funnel read the
  same in either direction, as does the vertical value axis everywhere.

A left-to-right chart renders exactly as it did before, pixel for pixel.

## Zoom and pan

Off by default. Turning it on layers a *viewport* — a visible span and where it
sits in absolute time — over the window selection:

```swift
LivelineChart(
    data: points,
    value: latest,
    configuration: LivelineChartConfiguration(
        appearance: LivelineChartAppearance(theme: .dark),
        viewport: LivelineChartViewport(
            window: 60,
            windows: [
                LivelineWindowOption(label: "1m", seconds: 60),
                LivelineWindowOption(label: "5m", seconds: 300)
            ],
            minimumSpan: nil,   // nil derives it from the sample rate
            maximumZoomOut: 8   // at most eight windows, and never past the data
        ),
        interaction: LivelineChartInteraction(
            scrub: true,
            showsTooltipOnHover: true,
            zoomAndPan: true
        )
    )
)
```

`configuration.zoomAndPan` is also available as a flat property.

### Gestures

With `zoomAndPan` on, the chart adopts the standard system division of labour:

| Input | Action |
| --- | --- |
| Pinch | Zoom, pivoting on the moment under the gesture centroid |
| One-finger drag | Pan along the time axis |
| Long press, then drag | Scrub |
| Trackpad or wheel scroll (macOS) | Pan; Shift redirects a wheel's vertical axis |
| Cursor hover | Unchanged — the tooltip still follows the pointer |

The scrub and the pan are exclusive: the long press has to survive its delay
without moving, and any earlier movement hands the drag to the pan. With
`zoomAndPan` off — the default — a plain drag scrubs exactly as it always did,
and none of this code runs.

Pinch needs iOS 17, macOS 14, or visionOS 1: it is the only version of the
gesture that reports where it started, and an anchorless zoom that jumps the
plot out from under the fingers is worse than no zoom. Panning, scrolling, and
the "Live" control work on every supported version. tvOS and watchOS keep their
existing interaction models.

### Following live

A chart follows live until it is panned away from the newest data. Panning back
to within two percent of the visible span re-engages following, and while it is
disengaged a small **Live** chip appears in the control row — the same chrome as
the window picker — that returns to the newest data and eases the plot back.

Zooming never disengages on its own: while following, a pinch pivots on the live
edge whatever the centroid says. Picking a window from the picker clears the
zoom and returns to live.

The pan direction respects the reading direction: dragging toward the live edge
always shows newer data, whichever side that edge is on.

### Limits

- **Zooming in** stops at `minimumSpan`, or at three sample intervals when that
  is `nil`, so there is always a visible segment either side of what was zoomed
  into.
- **Zooming out** stops at `maximumZoomOut` times the selected window, capped
  again by how much data actually exists.
- **Panning** is clamped to the data domain: the oldest sample on one end, the
  live edge on the other. A viewport wider than the data has nowhere to pan and
  stays pinned to the live edge.

The viewport feeds the renderer the same visible edges it has always drawn from,
so decimation, hover narrowing, the time-axis labels, and the prepared-chart
cache all adapt to the zoom with no extra work.

`LivelineViewport` and `LivelineViewportLimits` are public, so the same clamping
and follow-live rules can be exercised directly.

## Streaming data

`LivelineDataStream` is a `@MainActor` `ObservableObject` holding a bounded,
time-ordered buffer for live feeds:

```swift
@StateObject private var stream = LivelineDataStream(capacity: 600, retention: 300)

var body: some View {
    LivelineChart(data: stream.points, value: stream.points.last?.value ?? 0)
        .task { try? await stream.consume(ticks) }
}
```

`append(_:)`, `append(contentsOf:)`, `replace(_:)`, and `removeAll()` keep the
buffer sorted; appending a sample newer than the last is a plain array append,
and only an out-of-order sample pays for an insert. Because every published
array holds finite, strictly increasing times, it satisfies the renderer's
sorted-input fast path, so preparation reuses the buffer instead of sorting a
copy each frame.

## Image export

`LivelineChartImageExporter` renders a chart to a platform image or PNG data on
the main actor:

```swift
let exporter = LivelineChartImageExporter(
    size: CGSize(width: 640, height: 320),
    scale: 2,
    elapsedTime: 3,
    backgroundColor: .black
)
let image = exporter.image(chart)
let data = exporter.pngData(chart)

// Or, straight from the chart:
let png = chart.exportedPNGData(size: CGSize(width: 640, height: 320))
```

The export pins the renderer clock instead of reading the wall clock, so nothing
about the frame depends on when the call happened. Because a still is a single
frame, transitions that ramp — the appearance reveal, range easing, line
interpolation — are captured settled; `elapsedTime` drives the effects that stay
a function of time, such as the dither shimmer. Both entry points return `nil`
when the platform cannot rasterize, or when the requested size rounds to zero
pixels. For video, use the `liveline-render` executable.
