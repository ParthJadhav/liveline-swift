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
    showValue: true,
    valueMomentumColor: true,
    referenceLine: LivelineReferenceLine(value: 42, label: "Open"),
    formatValue: { $0.formatted(.number.precision(.fractionLength(2))) }
)
```

Important options:

| Option | Default | Notes |
| --- | --- | --- |
| `theme` | `.dark` | Controls grid, label, tooltip, and badge colors. |
| `window` | `30` | Visible time span in seconds. |
| `windows` | `[]` | Adds built-in time horizon buttons. |
| `grid` | `true` | Draws horizontal grid lines and value labels. |
| `badge` | `true` | Draws the live value pill for line charts. |
| `fill` | `true` | Draws a gradient under line charts. |
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
