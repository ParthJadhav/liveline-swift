# Example Recipes

## Dashboard Line Chart

```swift
LivelineChart(
    data: ticks,
    value: latest,
    color: .blue,
    configuration: LivelineChartConfiguration(
        theme: .dark,
        window: 60,
        windows: [
            LivelineWindowOption(label: "30s", seconds: 30),
            LivelineWindowOption(label: "1m", seconds: 60),
            LivelineWindowOption(label: "3m", seconds: 180)
        ],
        showValue: true,
        valueMomentumColor: true,
        formatValue: { "$" + $0.formatted(.number.precision(.fractionLength(2))) }
    )
)
.frame(height: 260)
```

## Candlestick With Built-In Mode Toggle

```swift
@State private var lineMode = false

LivelineChart(
    data: ticks,
    value: latest,
    candles: candles,
    candleWidth: 60,
    liveCandle: liveCandle,
    lineData: ticks,
    lineValue: latest,
    configuration: LivelineChartConfiguration(
        window: 300,
        lineMode: lineMode,
        onModeChange: { lineMode = $0 == .line }
    )
)
.frame(height: 280)
```

## Multi-Series

```swift
LivelineChart(
    series: [
        LivelineSeries(id: "alpha", data: alpha, value: alpha.last?.value ?? 0, color: .blue),
        LivelineSeries(id: "beta", data: beta, value: beta.last?.value ?? 0, color: .red),
        LivelineSeries(id: "gamma", data: gamma, value: gamma.last?.value ?? 0, color: .green)
    ],
    configuration: LivelineChartConfiguration(
        theme: .light,
        window: 180,
        seriesToggleCompact: false
    )
)
.frame(height: 260)
```

## Loading And Empty States

```swift
LivelineChart(
    data: points,
    value: latest,
    configuration: LivelineChartConfiguration(
        loading: isLoading,
        emptyText: "No trades yet"
    )
)
.frame(height: 240)
```

## Orderbook Stream

```swift
let orderbook = LivelineOrderbookData(
    bids: [LivelineOrderbookLevel(price: 99, size: 3.2)],
    asks: [LivelineOrderbookLevel(price: 101, size: 2.8)]
)

LivelineChart(
    data: ticks,
    value: latest,
    configuration: LivelineChartConfiguration(orderbook: orderbook)
)
```

## Signed Bar Chart

```swift
LivelineChart(
    bars: changes,
    color: .green,
    style: LivelineBarStyle(
        widthRatio: 0.5,
        cornerRadius: 0,
        baseline: 4,
        negativeColor: .red
    ),
    configuration: LivelineChartConfiguration(
        theme: .light,
        window: 180,
        formatValue: { $0.formatted() + "%" }
    )
)
.frame(height: 260)
```

## Forecast Range

```swift
let forecast = samples.map {
    LivelineRangePoint(time: $0.time, lower: $0.p10, upper: $0.p90)
}

LivelineChart(
    range: forecast,
    color: .indigo,
    style: LivelineRangeStyle(
        fillOpacity: 0.2,
        boundaryLineWidth: 1.5,
        showsCenterLine: true
    ),
    configuration: LivelineChartConfiguration(window: 300)
)
.frame(height: 260)
```

## Connected Scatter Plot

```swift
LivelineChart(
    scatter: latencySamples,
    color: .cyan,
    style: LivelineScatterStyle(
        symbol: .diamond,
        pointSize: 9,
        outlineWidth: 1,
        connection: .curved
    ),
    configuration: LivelineChartConfiguration(
        theme: .light,
        window: 180,
        formatValue: { $0.formatted() + " ms" }
    )
)
.frame(height: 260)
```

## Centered Step Chart

```swift
LivelineChart(
    steps: deploymentLevels,
    color: .cyan,
    style: LivelineStepStyle(position: .center, lineWidth: 2.5, fillOpacity: 0.12),
    configuration: LivelineChartConfiguration(window: 180)
)
.frame(height: 260)
```

## Signed Lollipop Chart

```swift
LivelineChart(
    lollipops: changes,
    color: .green,
    style: LivelineLollipopStyle(
        baseline: 0,
        headSize: 10,
        headSymbol: .diamond,
        negativeColor: .red
    )
)
.frame(height: 260)
```

## Bubble Magnitudes

```swift
let bubbles = samples.map {
    LivelineBubblePoint(time: $0.time, value: $0.latency, magnitude: $0.requests)
}

LivelineChart(
    bubbles: bubbles,
    color: .purple,
    style: LivelineBubbleStyle(minimumSize: 5, maximumSize: 26, scale: .area)
)
.frame(height: 260)
```

## Rolling Box Plot

```swift
LivelineChart(
    boxPlots: latencySummaries,
    color: .indigo,
    style: LivelineBoxPlotStyle(fillOpacity: 0.2, medianLineWidth: 2.5),
    configuration: LivelineChartConfiguration(window: 300)
)
.frame(height: 260)
```

## Cumulative Waterfall

Waterfall point values are deltas. Liveline accumulates them from `initialValue`.

```swift
LivelineChart(
    waterfall: balanceChanges,
    color: .green,
    style: LivelineWaterfallStyle(
        initialValue: 100,
        widthRatio: 0.65,
        showsConnectors: true
    )
)
.frame(height: 260)
```
