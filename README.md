# Liveline Swift

Native SwiftUI real-time charts for iOS apps. Liveline renders animated line, candlestick, and multi-series charts with smooth value interpolation, scrubbing, live badges, time windows, loading/empty states, and optional market-style effects.

This repository is a Swift Package. Any iOS app can add it with Swift Package Manager and import `Liveline`.

## Requirements

- iOS 16+
- Swift 5.9+
- Xcode 15+

The package also declares macOS 13, tvOS 16, watchOS 9, and visionOS 1 support. The included demo app targets iOS.

## Installation

In Xcode:

1. Open your app project.
2. Select **File > Add Package Dependencies...**
3. Add the private repository URL.
4. Choose the `Liveline` product.

In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ParthJadhav/liveline-swift.git", from: "0.1.1")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["Liveline"]
    )
]
```

For private GitHub access, use an account or deploy key that can read the repository.

## Quick Start

```swift
import Liveline
import SwiftUI

struct PriceChart: View {
    let points: [LivelinePoint]
    let latest: Double

    var body: some View {
        LivelineChart(
            data: points,
            value: latest,
            color: .blue,
            configuration: LivelineChartConfiguration(
                theme: .dark,
                window: 60,
                showValue: true,
                valueMomentumColor: true,
                formatValue: { "$" + $0.formatted(.number.precision(.fractionLength(2))) }
            )
        )
        .frame(height: 280)
        .background(Color(red: 10 / 255, green: 10 / 255, blue: 10 / 255))
    }
}
```

Each point uses Unix seconds:

```swift
LivelinePoint(time: Date().timeIntervalSince1970, value: 42125.44)
```

## Chart Modes

Line:

```swift
LivelineChart(data: ticks, value: latest)
    .frame(height: 260)
```

Candlestick:

```swift
LivelineChart(
    data: ticks,
    value: latest,
    candles: candles,
    candleWidth: 60,
    liveCandle: liveCandle,
    lineData: ticks,
    lineValue: latest,
    configuration: LivelineChartConfiguration(lineMode: false)
)
.frame(height: 280)
```

Multi-series:

```swift
LivelineChart(series: [
    LivelineSeries(id: "alpha", data: alpha, value: alphaLatest, color: .blue, label: "Alpha"),
    LivelineSeries(id: "beta", data: beta, value: betaLatest, color: .red, label: "Beta")
])
.frame(height: 260)
```

## Features

- SwiftUI `Canvas` rendering, no WebView and no JavaScript bridge
- Smooth live value interpolation and range easing
- Monotone cubic line paths to avoid overshoot
- Time-window controls
- Drag scrubbing with tooltips
- Live value badge and pulse dot
- Momentum coloring and arrows
- Optional particle burst and shake effects
- Loading/empty morph states
- Candlestick drawing with live candle glow
- Multi-series toggles
- Reference line and orderbook stream labels

## Example App

The iOS demo lives in `Examples/LivelineDemo`.

```bash
cd Examples/LivelineDemo
xcodegen generate
open LivelineDemo.xcodeproj
```

The generated project uses the local package path (`../..`). CI builds this demo target as an iOS simulator app.

## Demo Recording

A current simulator recording is available at [Media/liveline-demo.mp4](Media/liveline-demo.mp4).

To regenerate it:

```bash
scripts/record-demo.sh
```

## Verification

```bash
swift test
xcodebuild -project Examples/LivelineDemo/LivelineDemo.xcodeproj -scheme LivelineDemo -destination 'generic/platform=iOS Simulator' build
scripts/capture-storybook.sh
scripts/capture-storybook.sh --chart-only
scripts/capture-web-references.sh
scripts/diff-storybook.sh --fail-changed-pct 5 --fail-rms 12
```

Use the chart-only capture plus web-reference diff when comparing the native renderer against the upstream React/canvas implementation. Native Storybook captures use deterministic snapshot timing, and diff panels are written to `Media/storybook-diff`.

The normal CI workflow runs package tests and the iOS demo build. The manual `Visual Parity` workflow captures upstream/native Storybook screenshots, runs the diff gate, and uploads the visual artifacts.

## Publishing

For private GitHub publishing:

```bash
scripts/publish-private.sh ParthJadhav liveline-swift
```

See [Docs/Publishing.md](Docs/Publishing.md) for release tags and private SwiftPM access notes.

## Documentation

- [API overview](Docs/API.md)
- [Animation model](Docs/Animations.md)
- [Example recipes](Docs/Examples.md)
- [Scenario matrix](Docs/ScenarioMatrix.md)
- [Visual parity status](Docs/ParityStatus.md)
- [Publishing checklist](Docs/Publishing.md)

## Attribution

Liveline Swift is a native Swift implementation inspired by [benjitaylor/liveline](https://github.com/benjitaylor/liveline). It does not embed the original React/canvas implementation.
