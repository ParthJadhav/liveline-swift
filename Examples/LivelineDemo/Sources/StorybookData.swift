import Liveline
import SwiftUI

enum StorybookData {
    enum Shape {
        case calm
        case normal
        case spiky
        case rising
        case falling
    }

    static let darkBackground = Color(red: 10 / 255, green: 10 / 255, blue: 10 / 255)
    static let blue = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255)
    static let red = Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255)
    static let green = Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255)
    static let cyan = Color(red: 6 / 255, green: 182 / 255, blue: 212 / 255)
    static let orange = Color(red: 249 / 255, green: 115 / 255, blue: 22 / 255)
    static let bitcoinOrange = Color(red: 247 / 255, green: 147 / 255, blue: 26 / 255)
    static let violet = Color(red: 139 / 255, green: 92 / 255, blue: 246 / 255)
    static let indigo = Color(red: 99 / 255, green: 102 / 255, blue: 241 / 255)
    static let teal = Color(red: 20 / 255, green: 184 / 255, blue: 166 / 255)
    static let segmentColors = [blue, violet, cyan, green, orange, red]
    static let baseTime: TimeInterval = 1_788_888_000
    static var orderbookReferenceRandomState: UInt32 {
        StorybookLaunch.orderbookSeedFromArguments() ?? 12_345
    }
    static let windows = [
        LivelineWindowOption(label: "15s", seconds: 15),
        LivelineWindowOption(label: "30s", seconds: 30),
        LivelineWindowOption(label: "2m", seconds: 120),
        LivelineWindowOption(label: "5m", seconds: 300),
    ]

    static let orderbook = LivelineOrderbookData(
        bids: (1...12).map { LivelineOrderbookLevel(price: 100 - Double($0) * 0.2, size: Double($0) * 0.8 + 1.4) },
        asks: (1...12).map { LivelineOrderbookLevel(price: 100 + Double($0) * 0.2, size: Double(13 - $0) * 0.7 + 1.1) }
    )

    static func points(_ shape: Shape, count: Int = 260, step: TimeInterval = 1) -> [LivelinePoint] {
        var output: [LivelinePoint] = []
        output.reserveCapacity(count)

        for index in 0..<count {
            let t = Double(index)
            let value: Double
            switch shape {
            case .calm:
                value = 100 + sin(t * 0.13) * 0.42 + cos(t * 0.037) * 0.18
            case .normal:
                value = 100 + sin(t * 0.10) * 2.5 + cos(t * 0.031) * 4.2 + sin(t * 0.015) * 1.6
            case .spiky:
                let spike = index % 37 == 0 ? (index % 74 == 0 ? 7.5 : -5.8) : 0
                value = 100 + sin(t * 0.12) * 3.8 + cos(t * 0.055) * 2.7 + spike
            case .rising:
                value = 96 + t * 0.035 + sin(t * 0.11) * 1.7 + cos(t * 0.04) * 0.8
            case .falling:
                value = 108 - t * 0.033 + sin(t * 0.11) * 1.7 + cos(t * 0.04) * 0.8
            }
            output.append(LivelinePoint(time: baseTime - Double(count - index - 1) * step, value: value))
        }

        return output
    }

    static var series: [LivelineSeries] {
        let first = points(.normal, count: 240)
        let second = first.enumerated().map { index, point in
            LivelinePoint(time: point.time, value: point.value - 3.2 + cos(Double(index) * 0.07) * 2.4)
        }
        let third = first.enumerated().map { index, point in
            LivelinePoint(time: point.time, value: point.value + 4.4 + sin(Double(index) * 0.06 + 1.4) * 3.2)
        }
        return [
            LivelineSeries(id: "alpha", data: first, value: first.last?.value ?? 0, color: blue, label: "Alpha"),
            LivelineSeries(id: "beta", data: second, value: second.last?.value ?? 0, color: red, label: "Beta"),
            LivelineSeries(id: "gamma", data: third, value: third.last?.value ?? 0, color: green, label: "Gamma"),
        ]
    }

    static func bars(signed: Bool) -> [LivelinePoint] {
        (0..<18).map { index in
            let t = Double(index)
            let base = 46 + sin(t * 0.82) * 18 + cos(t * 0.31) * 9
            let value = signed ? sin(t * 0.74) * 13 + cos(t * 0.27) * 5 : max(4, base)
            return LivelinePoint(time: baseTime - Double(17 - index) * 10, value: value)
        }
    }

    static var ranges: [LivelineRangePoint] {
        (0..<37).map { index in
            let t = Double(index)
            let center = 68 + sin(t * 0.28) * 7 + cos(t * 0.11) * 3
            let spread = 5 + (sin(t * 0.19 + 0.8) + 1) * 2.5
            return LivelineRangePoint(
                time: baseTime - Double(36 - index) * 5,
                lower: center - spread,
                upper: center + spread
            )
        }
    }

    static var scatter: [LivelinePoint] {
        (0..<23).map { index in
            let t = Double(index)
            let value = 82 + sin(t * 0.91) * 20 + cos(t * 0.27) * 11 + (index % 7 == 0 ? 16 : 0)
            return LivelinePoint(time: baseTime - Double(22 - index) * 8, value: value)
        }
    }

    static var steps: [LivelinePoint] {
        let values = [42.0, 48, 48, 56, 51, 63, 63, 70, 66, 74, 79, 73]
        return values.enumerated().map { index, value in
            LivelinePoint(time: baseTime - Double(values.count - index - 1) * 15, value: value)
        }
    }

    static var lollipops: [LivelinePoint] {
        let values = [8.0, -5, 11, 4, -8, 6, 13, -3, 9, -6, 5, 12]
        return values.enumerated().map { index, value in
            LivelinePoint(time: baseTime - Double(values.count - index - 1) * 15, value: value)
        }
    }

    static var bubbles: [LivelineBubblePoint] {
        (0..<16).map { index in
            let t = Double(index)
            return LivelineBubblePoint(
                time: baseTime - Double(15 - index) * 11,
                value: 76 + sin(t * 0.72) * 18 + cos(t * 0.21) * 8,
                magnitude: 12 + Double((index * 17) % 43)
            )
        }
    }

    static var boxPlots: [LivelineBoxPlotPoint] {
        (0..<12).map { index in
            let t = Double(index)
            let center = 72 + sin(t * 0.61) * 9
            let innerSpread = 4 + Double(index % 3)
            let outerSpread = innerSpread + 5 + cos(t * 0.32) * 2
            return LivelineBoxPlotPoint(
                time: baseTime - Double(11 - index) * 15,
                minimum: center - outerSpread,
                lowerQuartile: center - innerSpread,
                median: center + sin(t * 0.47),
                upperQuartile: center + innerSpread,
                maximum: center + outerSpread
            )
        }
    }

    static var waterfall: [LivelinePoint] {
        let deltas = [8.0, -3, 6, -7, 11, 4, -5, 9, -2, 7, -6, 10]
        return deltas.enumerated().map { index, delta in
            LivelinePoint(time: baseTime - Double(deltas.count - index - 1) * 15, value: delta)
        }
    }

    static var errorBars: [LivelineErrorBarPoint] {
        (0..<12).map { index in
            let t = Double(index)
            let value = 72 + sin(t * 0.64) * 9 + cos(t * 0.23) * 4
            let spread = 4 + Double(index % 4) * 1.3
            return LivelineErrorBarPoint(
                time: baseTime - Double(11 - index) * 15,
                value: value,
                lower: value - spread,
                upper: value + spread * 0.8
            )
        }
    }

    static var dumbbells: [LivelineDumbbellPoint] {
        (0..<12).map { index in
            let t = Double(index)
            let start = 58 + sin(t * 0.52) * 8
            let change = 7 + cos(t * 0.81) * 6 - (index % 4 == 0 ? 10 : 0)
            return LivelineDumbbellPoint(
                time: baseTime - Double(11 - index) * 15,
                start: start,
                end: start + change
            )
        }
    }

    static var stacked: [LivelineStackedPoint] {
        (0..<12).map { index in
            let t = Double(index)
            return LivelineStackedPoint(
                time: baseTime - Double(11 - index) * 15,
                values: [
                    20 + sin(t * 0.43) * 7,
                    13 + cos(t * 0.61) * 5,
                    8 + sin(t * 0.77 + 1) * 4,
                ]
            )
        }
    }

    static var stackedArea: [LivelineStackedPoint] {
        (0..<25).map { index in
            let t = Double(index)
            return LivelineStackedPoint(
                time: baseTime - Double(24 - index) * 7,
                values: [
                    18 + sin(t * 0.28) * 6,
                    12 + cos(t * 0.34 + 0.8) * 4,
                    7 + sin(t * 0.47 + 1.7) * 3,
                ]
            )
        }
    }

    static var timeline: [LivelineTimelineItem] {
        [
            LivelineTimelineItem(id: "design", label: "Design", start: baseTime - 170, end: baseTime - 118, lane: 0),
            LivelineTimelineItem(id: "api", label: "API", start: baseTime - 148, end: baseTime - 82, lane: 1),
            LivelineTimelineItem(id: "ios", label: "iOS", start: baseTime - 126, end: baseTime - 54, lane: 2),
            LivelineTimelineItem(id: "qa", label: "QA", start: baseTime - 78, end: baseTime - 30, lane: 0),
            LivelineTimelineItem(id: "docs", label: "Docs", start: baseTime - 65, end: baseTime - 18, lane: 1),
            LivelineTimelineItem(id: "ship", label: "Ship", start: baseTime - 38, end: baseTime - 8, lane: 2),
        ]
    }

    static var heatmap: [LivelineHeatmapCell] {
        (0..<12).flatMap { column in
            (0..<4).map { row in
                let value = 20 + Double((column * 17 + row * 23) % 68) + sin(Double(column + row) * 0.7) * 8
                return LivelineHeatmapCell(
                    time: baseTime - Double(11 - column) * 15,
                    row: row,
                    value: value
                )
            }
        }
    }

    static var heatmapSparse: [LivelineHeatmapCell] {
        var cells: [LivelineHeatmapCell] = []
        for column in 0..<6 {
            for row in 0..<3 {
                let time = baseTime - Double(5 - column) * 30
                let value = 18 + Double((column * 19 + row * 27) % 76)
                cells.append(LivelineHeatmapCell(time: time, row: row, value: value))
            }
        }
        return cells
    }

    static let radar = [
        LivelineRadarPoint(label: "Speed", value: 84),
        LivelineRadarPoint(label: "Uptime", value: 96),
        LivelineRadarPoint(label: "Cost", value: 61),
        LivelineRadarPoint(label: "Scale", value: 78),
        LivelineRadarPoint(label: "DX", value: 88),
        LivelineRadarPoint(label: "Safety", value: 73),
    ]

    static let categories = [
        LivelineCategoryValue(id: "pro", label: "Pro", value: 42),
        LivelineCategoryValue(id: "team", label: "Team", value: 31),
        LivelineCategoryValue(id: "starter", label: "Starter", value: 18),
        LivelineCategoryValue(id: "other", label: "Other", value: 9),
    ]

    static let funnel = [
        LivelineCategoryValue(id: "visit", label: "Visits", value: 1_000),
        LivelineCategoryValue(id: "signup", label: "Signups", value: 680),
        LivelineCategoryValue(id: "trial", label: "Trials", value: 420),
        LivelineCategoryValue(id: "paid", label: "Paid", value: 240),
        LivelineCategoryValue(id: "renew", label: "Renewed", value: 172),
    ]

    static func candles(width: TimeInterval) -> (committed: [LivelineCandle], live: LivelineCandle?) {
        let source = points(.normal, count: 360)
        var candles: [LivelineCandle] = []
        var current: LivelineCandle?

        for point in source {
            let bucket = floor(point.time / width) * width
            if current == nil {
                current = LivelineCandle(time: bucket, open: point.value, high: point.value, low: point.value, close: point.value)
            } else if current?.time == bucket {
                var updated = current!
                updated.high = max(updated.high, point.value)
                updated.low = min(updated.low, point.value)
                updated.close = point.value
                current = updated
            } else {
                if let current {
                    candles.append(current)
                }
                current = LivelineCandle(time: bucket, open: point.value, high: point.value, low: point.value, close: point.value)
            }
        }

        return (candles, current)
    }

    static func lineConfig(
        theme: LivelineThemeMode,
        window: TimeInterval = 60,
        windows: [LivelineWindowOption] = [],
        windowStyle: LivelineWindowStyle = .default,
        grid: Bool = true,
        badge: Bool = true,
        badgeVariant: LivelineBadgeVariant = .default,
        fill: Bool = true,
        pulse: Bool = false,
        momentum: LivelineMomentum? = nil,
        exaggerate: Bool = false,
        showValue: Bool = false,
        valueMomentumColor: Bool = false,
        loading: Bool = false,
        emptyText: String = "No data to display",
        referenceLine: LivelineReferenceLine? = nil,
        orderbook: LivelineOrderbookData? = nil,
        degen: LivelineDegenOptions? = nil,
        lineMode: Bool = false,
        seriesToggleCompact: Bool = false,
        randomSeed: UInt32? = nil,
        onModeChange: ((LivelineChartMode) -> Void)? = nil
    ) -> LivelineChartConfiguration {
        LivelineChartConfiguration(
            theme: theme,
            window: window,
            windows: windows,
            grid: grid,
            badge: badge,
            badgeVariant: badgeVariant,
            fill: fill,
            pulse: pulse,
            fadeEffects: true,
            momentum: momentum,
            exaggerate: exaggerate,
            showValue: showValue,
            valueMomentumColor: valueMomentumColor,
            degen: degen,
            loading: loading,
            emptyText: emptyText,
            windowStyle: windowStyle,
            orderbook: orderbook,
            referenceLine: referenceLine,
            formatValue: money,
            randomSeed: randomSeed ?? (orderbook == nil ? nil : 12_345),
            lineMode: lineMode,
            seriesToggleCompact: seriesToggleCompact,
            onModeChange: onModeChange
        )
    }

    static func staticSnapshotConfig(
        theme: LivelineThemeMode,
        window: TimeInterval,
        suffix: String,
        padding: LivelinePadding = LivelinePadding()
    ) -> LivelineChartConfiguration {
        LivelineChartConfiguration(
            theme: theme,
            window: window,
            badge: false,
            fill: false,
            pulse: false,
            endpointDecorations: false,
            fadeEffects: StorybookLaunch.chartShowcaseFromArguments(),
            formatValue: { value in
                value.formatted(.number.precision(.fractionLength(0))) + suffix
            },
            padding: padding
        )
    }

    static func normalizedSnapshotConfig(
        theme: LivelineThemeMode,
        window: TimeInterval
    ) -> LivelineChartConfiguration {
        LivelineChartConfiguration(
            theme: theme,
            window: window,
            badge: false,
            fill: false,
            pulse: false,
            endpointDecorations: false,
            fadeEffects: StorybookLaunch.chartShowcaseFromArguments(),
            formatValue: { value in
                (value * 100).formatted(.number.precision(.fractionLength(0))) + "%"
            }
        )
    }

    static func money(_ value: Double) -> String {
        "$" + value.formatted(.number.precision(.fractionLength(2)))
    }
}
