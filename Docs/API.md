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
```

Scatter symbols are `.circle`, `.square`, and `.diamond`. Connections are `.none`, `.straight`, and `.curved`.

## Configuration

`LivelineChartConfiguration` controls appearance and behavior.

```swift
LivelineChartConfiguration(
    theme: .dark,
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
| `window` | `30` | Visible time span in seconds. |
| `windows` | `[]` | Adds built-in time horizon buttons. |
| `grid` | `true` | Draws horizontal grid lines and value labels. |
| `badge` | `true` | Draws the live value pill for line charts. |
| `fill` | `true` | Draws a gradient under line charts. |
| `endpointDecorations` | `true` | Draws the endpoint dot and momentum arrows. Disable this for forecast or historical charts where the final point is not a live value. |
| `fadeEffects` | `false` | Enables chart reveal, edge masks, scrub dimming, axis label, series, and tooltip fade transitions. Disabled by default so charts render at full opacity immediately. |
| `momentum` | `nil` | Use `.up`, `.down`, or `.flat` to override auto detection. |
| `autoDetectMomentum` | `true` | Uses recent velocity to color momentum affordances. |
| `scrub` | `true` | Enables drag scrubbing and tooltips. |
| `exaggerate` | `false` | Uses a tighter Y range for small moves. |
| `showValue` | `false` | Shows a live value label above the chart. |
| `degen` | `nil` | Enables particle bursts and chart shake. |
| `loading` | `false` | Shows the breathing loading line. |
| `paused` | `false` | Freezes animation progress visually. |
| `orderbook` | `nil` | Draws streaming bid/ask size labels behind the line. |
| `referenceLine` | `nil` | Keeps a horizontal reference value visible. |
| `activePoint` | `nil` | Draws a pulsing dot at an arbitrary active time/value. If `value` is nil, Liveline interpolates the value from the visible data. |
| `seriesLegendSide` | `.trailing` | Places multi-series endpoint labels to the trailing or leading side of their points. |
| `snapshotElapsedTime` | `nil` | Runs animations on a fixed 60fps cursor until this elapsed time, then freezes for deterministic screenshots and tests. |
| `lineMode` | `false` | Renders candle input as a line. |

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

Callbacks are optional. The built-in UI only appears when relevant data or callbacks are present.
