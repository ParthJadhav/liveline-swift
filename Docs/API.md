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

The Swift API keeps the upstream React feature surface but maps union-style props into typed fields. Web `momentum={false}` is `autoDetectMomentum: false`; web `momentum="up"` is `momentum: .up`. Web `degen={true}` is `degen: LivelineDegenOptions()`, and web `degen={false}` is `degen: nil`.

Important options:

| Option | Default | Notes |
| --- | --- | --- |
| `theme` | `.dark` | Controls grid, label, tooltip, and badge colors. |
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
| `scrub` | `true` | Enables drag scrubbing and tooltips. |
| `tooltipY` | `14` | Adjusts structured tooltip placement vertically; values above or below the default shift the adaptive placement within the plot bounds. |
| `exaggerate` | `false` | Uses a tighter Y range for small moves. |
| `showValue` | `false` | Shows a live value label above the chart. |
| `degen` | `nil` | Enables particle bursts and chart shake. |
| `loading` | `false` | Shows the breathing loading line. |
| `paused` | `false` | Freezes animation progress visually. |
| `orderbook` | `nil` | Draws streaming bid/ask size labels behind the line. |
| `referenceLine` | `nil` | Keeps a horizontal reference value visible. |
| `activePoint` | `nil` | Draws a pulsing dot at an arbitrary active time/value. If `value` is nil, Liveline interpolates the value from the visible data. |
| `seriesLegendSide` | `.trailing` | Places multi-series endpoint labels to the trailing or leading side of their points. |
| `lineMode` | `false` | Renders candle input as a line. |
| `showsModeControls` | `false` | Explicitly shows line/candle mode controls when the content supports them. |
| `showsSeriesControls` | `true` | Explicitly shows series visibility controls when the content supports them. |

### Universal dither style

`LivelineDitherStyle` exposes `variant` (`gradient`, `dotted`, `hatched`, or
`solid`), `bloom` (`off`, `low`, `high`, or `aura`), `cellSize`, `intensity`,
`sparkleDensity`, `animationSpeed`, and `animated`. Values are normalized at the
rendering boundary. Bloom and sparkles opt static charts into frame scheduling
only while animation is enabled; pausing or Reduce Motion keeps the pattern
stable.

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
