# ``Liveline``

Animated real-time SwiftUI charts for Apple apps.

## Overview

Liveline renders twenty-one typed line, financial, statistical, time-series, matrix, radial, and categorical chart forms with SwiftUI `Canvas`.
It is designed for live data streams such as prices, telemetry, scores, or metrics.

Use ``LivelineChart`` as the main view:

```swift
LivelineChart(data: points, value: latest)
    .frame(height: 280)
```

## Topics

### Chart View

- ``LivelineChart``
- ``SwiftUICore/View/livelineChartStyle(_:)``

### Data

- ``LivelinePoint``
- ``LivelineRangePoint``
- ``LivelineBubblePoint``
- ``LivelineBoxPlotPoint``
- ``LivelineErrorBarPoint``
- ``LivelineDumbbellPoint``
- ``LivelineStackedPoint``
- ``LivelineTimelineItem``
- ``LivelineHeatmapCell``
- ``LivelineRadarPoint``
- ``LivelineCategoryValue``
- ``LivelineCandle``
- ``LivelineSeries``

### Configuration

- ``LivelineChartConfiguration``
- ``LivelineChartStyle``
- ``LivelineDitherStyle``
- ``LivelineDitherVariant``
- ``LivelineDitherBloom``
- ``LivelineWindowOption``
- ``LivelineReferenceLine``
- ``LivelineOrderbookData``
- ``LivelineDegenOptions``
- ``LivelineBarStyle``
- ``LivelineRangeStyle``
- ``LivelineScatterStyle``
- ``LivelineStepStyle``
- ``LivelineLollipopStyle``
- ``LivelineBubbleStyle``
- ``LivelineBoxPlotStyle``
- ``LivelineWaterfallStyle``
- ``LivelineErrorBarStyle``
- ``LivelineDumbbellStyle``
- ``LivelineStackedBarStyle``
- ``LivelineStackedAreaStyle``
- ``LivelineTimelineStyle``
- ``LivelineHeatmapStyle``
- ``LivelineRadarStyle``
- ``LivelineDonutStyle``
- ``LivelineGaugeStyle``
- ``LivelineFunnelStyle``
