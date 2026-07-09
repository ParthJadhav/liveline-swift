# ``Liveline``

Animated real-time SwiftUI charts for Apple apps.

## Overview

Liveline renders line, candlestick, multi-series, bar, range-band, and scatter charts with SwiftUI `Canvas`.
It is designed for live data streams such as prices, telemetry, scores, or metrics.

Use ``LivelineChart`` as the main view:

```swift
LivelineChart(data: points, value: latest)
    .frame(height: 280)
```

## Topics

### Chart View

- ``LivelineChart``

### Data

- ``LivelinePoint``
- ``LivelineRangePoint``
- ``LivelineCandle``
- ``LivelineSeries``

### Configuration

- ``LivelineChartConfiguration``
- ``LivelineWindowOption``
- ``LivelineReferenceLine``
- ``LivelineOrderbookData``
- ``LivelineDegenOptions``
- ``LivelineBarStyle``
- ``LivelineRangeStyle``
- ``LivelineScatterStyle``
