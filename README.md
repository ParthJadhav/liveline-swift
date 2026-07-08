# Liveline Swift

Native SwiftUI real-time charts for iOS apps. Liveline renders animated line, candlestick, and multi-series charts with smooth value interpolation, scrubbing, live badges, time windows, loading/empty states, and optional market-style effects.

<p align="center">
  <img src="Media/readme/cover.png" alt="Liveline Swift cover showing line, candlestick, and multi-series charts" />
</p>

This repository is a Swift Package. Any iOS app can add it with Swift Package Manager and import `Liveline`.

## Gallery

These screenshots are captured from the included deterministic iOS Storybook scenarios.

<p align="center">
  <img src="Media/readme/examples.png" alt="Liveline Swift Storybook screenshots showing line, momentum, orderbook, candlestick, mode control, and multi-series charts" />
</p>

## Requirements

- iOS 16+
- Swift 5.9+
- Xcode 15+

The package also declares macOS 13, tvOS 16, watchOS 9, and visionOS 1 support. The included demo app targets iOS.

## Installation

In Xcode:

1. Open your app project.
2. Select **File > Add Package Dependencies...**
3. Add the repository URL.
4. Choose the `Liveline` product.

In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ParthJadhav/liveline-swift.git", from: "0.1.2")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["Liveline"]
    )
]
```

If the repository remains private, use a GitHub account or deploy key that can read it.

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
swift build -c release
xcodebuild -scheme Liveline -destination 'generic/platform=macOS' build
xcodebuild -project Examples/LivelineDemo/LivelineDemo.xcodeproj -scheme LivelineDemo -destination 'generic/platform=iOS Simulator' build
scripts/capture-storybook.sh
scripts/capture-storybook.sh --chart-only
python3 scripts/build-readme-media.py
scripts/capture-web-references.sh
scripts/diff-storybook.sh --fail-changed-pct 5 --fail-rms 12
```

Use the chart-only capture plus web-reference diff when comparing the native renderer against the upstream React/canvas implementation. Native Storybook captures use deterministic snapshot timing, README media is built from `Media/storybook-chart-only`, and diff panels are written to `Media/storybook-diff`.

The normal CI workflow runs package tests and the iOS demo build. The manual `Visual Parity` workflow captures upstream/native Storybook screenshots, runs the diff gate, and uploads the visual artifacts.

## Release

For release verification and tagging:

```bash
swift test
swift build -c release
xcodebuild -scheme Liveline -destination 'generic/platform=macOS' build
xcodebuild -project Examples/LivelineDemo/LivelineDemo.xcodeproj -scheme LivelineDemo -destination 'generic/platform=iOS Simulator' build
scripts/capture-storybook.sh --chart-only
scripts/diff-storybook.sh --fail-changed-pct 5 --fail-rms 12
```

See [Docs/Publishing.md](Docs/Publishing.md) for the release checklist. Repository visibility is intentionally left unchanged by the release process.

## Documentation

- [API overview](Docs/API.md)
- [Animation model](Docs/Animations.md)
- [Example recipes](Docs/Examples.md)
- [Scenario matrix](Docs/ScenarioMatrix.md)
- [Visual parity status](Docs/ParityStatus.md)
- [Publishing checklist](Docs/Publishing.md)
- [Changelog](CHANGELOG.md)

## Attribution

Liveline Swift is a native Swift implementation inspired by [benjitaylor/liveline](https://github.com/benjitaylor/liveline). It does not embed the original React/canvas implementation.
