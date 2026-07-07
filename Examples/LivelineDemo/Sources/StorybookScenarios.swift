import Liveline
import SwiftUI

struct StorybookLaunch {
    static func scenarioFromArguments() -> StorybookScenario? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--storybook-scenario"),
              arguments.indices.contains(index + 1)
        else {
            return nil
        }
        return StorybookCatalog.scenario(id: arguments[index + 1])
    }

    static func chartOnlyFromArguments() -> Bool {
        ProcessInfo.processInfo.arguments.contains("--storybook-chart-only")
    }

    static func orderbookSeedFromArguments() -> UInt32? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--storybook-orderbook-seed"),
              arguments.indices.contains(index + 1)
        else {
            return nil
        }

        let rawValue = arguments[index + 1]
        if rawValue.hasPrefix("0x") || rawValue.hasPrefix("0X") {
            return UInt32(rawValue.dropFirst(2), radix: 16)
        }
        return UInt32(rawValue)
    }

    static func snapshotElapsedTimeFromArguments() -> TimeInterval? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--storybook-snapshot-elapsed"),
              arguments.indices.contains(index + 1)
        else {
            return nil
        }

        return TimeInterval(arguments[index + 1])
    }
}

struct StorybookScenario: Identifiable {
    let id: String
    let group: String
    let title: String
    let detail: String
    let background: Color
    let height: CGFloat
    let makeView: () -> AnyView
}

enum StorybookCatalog {
    static let all: [StorybookScenario] = [
        lineBasicDark,
        lineBasicLight,
        lineNoGridNoFill,
        lineMinimalBadge,
        lineNoBadge,
        lineMomentumUp,
        lineMomentumDown,
        lineExaggerated,
        lineShowValueWindows,
        lineRoundedWindows,
        lineTextWindows,
        lineReference,
        lineOrderbook,
        lineDegen,
        lineLoading,
        lineEmpty,
        candleBasic,
        candleLight,
        candleLineMode,
        candleModeControls,
        candleNoLive,
        candleWideWindow,
        candleLoading,
        multiBasic,
        multiLight,
        multiCompact,
        multiTwoSeries,
    ]

    static func scenario(id: String) -> StorybookScenario? {
        all.first { $0.id == id }
    }

    static var groups: [(name: String, scenarios: [StorybookScenario])] {
        let names = Array(Set(all.map(\.group))).sorted()
        return names.map { name in
            (name, all.filter { $0.group == name })
        }
    }
}

private extension StorybookCatalog {
    static let lineBasicDark = chart(
        id: "line-basic-dark",
        group: "Line",
        title: "Basic Dark",
        detail: "Default line, fill, grid, and badge.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            data: StorybookData.points(.normal),
            value: StorybookData.points(.normal).last?.value ?? 0,
            color: StorybookData.blue,
            configuration: StorybookData.lineConfig(theme: .dark)
        )
    }

    static let lineBasicLight = chart(
        id: "line-basic-light",
        group: "Line",
        title: "Basic Light",
        detail: "Default line in light theme.",
        background: .white
    ) {
        LivelineChart(
            data: StorybookData.points(.normal),
            value: StorybookData.points(.normal).last?.value ?? 0,
            color: StorybookData.blue,
            configuration: StorybookData.lineConfig(theme: .light)
        )
    }

    static let lineNoGridNoFill = chart(
        id: "line-no-grid-no-fill",
        group: "Line",
        title: "No Grid / No Fill",
        detail: "Minimal canvas with line and live badge.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            data: StorybookData.points(.calm),
            value: StorybookData.points(.calm).last?.value ?? 0,
            color: StorybookData.cyan,
            configuration: StorybookData.lineConfig(theme: .dark, grid: false, fill: false)
        )
    }

    static let lineMinimalBadge = chart(
        id: "line-minimal-badge",
        group: "Line",
        title: "Minimal Badge",
        detail: "White badge variant with tail.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            data: StorybookData.points(.normal),
            value: StorybookData.points(.normal).last?.value ?? 0,
            color: StorybookData.orange,
            configuration: StorybookData.lineConfig(theme: .dark, badgeVariant: .minimal)
        )
    }

    static let lineNoBadge = chart(
        id: "line-no-badge",
        group: "Line",
        title: "No Badge",
        detail: "Right padding collapses to grid label width.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            data: StorybookData.points(.spiky),
            value: StorybookData.points(.spiky).last?.value ?? 0,
            color: StorybookData.violet,
            configuration: StorybookData.lineConfig(theme: .dark, badge: false)
        )
    }

    static let lineMomentumUp = chart(
        id: "line-momentum-up",
        group: "Line",
        title: "Momentum Up",
        detail: "Forced up momentum, green dot and arrows.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            data: StorybookData.points(.rising),
            value: StorybookData.points(.rising).last?.value ?? 0,
            color: StorybookData.blue,
            configuration: StorybookData.lineConfig(theme: .dark, momentum: .up)
        )
    }

    static let lineMomentumDown = chart(
        id: "line-momentum-down",
        group: "Line",
        title: "Momentum Down",
        detail: "Forced down momentum, red dot and arrows.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            data: StorybookData.points(.falling),
            value: StorybookData.points(.falling).last?.value ?? 0,
            color: StorybookData.blue,
            configuration: StorybookData.lineConfig(theme: .dark, momentum: .down)
        )
    }

    static let lineExaggerated = chart(
        id: "line-exaggerated",
        group: "Line",
        title: "Exaggerated Range",
        detail: "Small changes fill the vertical space.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            data: StorybookData.points(.calm),
            value: StorybookData.points(.calm).last?.value ?? 0,
            color: StorybookData.teal,
            configuration: StorybookData.lineConfig(theme: .dark, exaggerate: true)
        )
    }

    static let lineShowValueWindows = chart(
        id: "line-show-value-windows",
        group: "Line",
        title: "Value + Windows",
        detail: "Live value display and default window control.",
        background: StorybookData.darkBackground,
        height: 310
    ) {
        LivelineChart(
            data: StorybookData.points(.normal),
            value: StorybookData.points(.normal).last?.value ?? 0,
            color: StorybookData.blue,
            configuration: StorybookData.lineConfig(theme: .dark, windows: StorybookData.windows, showValue: true, valueMomentumColor: true)
        )
    }

    static let lineRoundedWindows = chart(
        id: "line-rounded-windows",
        group: "Line",
        title: "Rounded Windows",
        detail: "Rounded control style.",
        background: StorybookData.darkBackground,
        height: 300
    ) {
        LivelineChart(
            data: StorybookData.points(.normal),
            value: StorybookData.points(.normal).last?.value ?? 0,
            color: StorybookData.blue,
            configuration: StorybookData.lineConfig(theme: .dark, windows: StorybookData.windows, windowStyle: .rounded)
        )
    }

    static let lineTextWindows = chart(
        id: "line-text-windows",
        group: "Line",
        title: "Text Windows",
        detail: "Text-only window style.",
        background: StorybookData.darkBackground,
        height: 300
    ) {
        LivelineChart(
            data: StorybookData.points(.normal),
            value: StorybookData.points(.normal).last?.value ?? 0,
            color: StorybookData.blue,
            configuration: StorybookData.lineConfig(theme: .dark, windows: StorybookData.windows, windowStyle: .text)
        )
    }

    static let lineReference = chart(
        id: "line-reference",
        group: "Line",
        title: "Reference Line",
        detail: "Reference label and always-visible range.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            data: StorybookData.points(.normal),
            value: StorybookData.points(.normal).last?.value ?? 0,
            color: StorybookData.indigo,
            configuration: StorybookData.lineConfig(theme: .dark, referenceLine: LivelineReferenceLine(value: 100.8, label: "Open"))
        )
    }

    static let lineOrderbook = chart(
        id: "line-orderbook",
        group: "Line",
        title: "Orderbook",
        detail: "Streaming bid/ask labels behind the chart.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            data: StorybookData.points(.spiky),
            value: StorybookData.points(.spiky).last?.value ?? 0,
            color: StorybookData.orange,
            configuration: StorybookData.lineConfig(theme: .dark, orderbook: StorybookData.orderbook, randomSeed: StorybookData.orderbookReferenceRandomState)
        )
    }

    static let lineDegen = chart(
        id: "line-degen",
        group: "Line",
        title: "Degen",
        detail: "Particles and shake on momentum changes.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            data: StorybookData.points(.rising),
            value: StorybookData.points(.rising).last?.value ?? 0,
            color: StorybookData.orange,
            configuration: StorybookData.lineConfig(theme: .dark, momentum: .up, degen: LivelineDegenOptions(scale: 1, downMomentum: true))
        )
    }

    static let lineLoading = chart(
        id: "line-loading",
        group: "States",
        title: "Loading",
        detail: "Breathing loading shape.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            data: [],
            value: 0,
            color: StorybookData.blue,
            configuration: StorybookData.lineConfig(theme: .dark, loading: true)
        )
    }

    static let lineEmpty = chart(
        id: "line-empty",
        group: "States",
        title: "Empty",
        detail: "Empty state label.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            data: [],
            value: 0,
            color: StorybookData.blue,
            configuration: StorybookData.lineConfig(theme: .dark, emptyText: "No data to display")
        )
    }

    static let candleBasic = chart(
        id: "candle-basic",
        group: "Candles",
        title: "Basic Candles",
        detail: "OHLC bodies, wicks, live candle.",
        background: StorybookData.darkBackground
    ) {
        let candleSet = StorybookData.candles(width: 30)
        LivelineChart(
            data: StorybookData.points(.normal),
            value: StorybookData.points(.normal).last?.value ?? 0,
            candles: candleSet.committed,
            candleWidth: 30,
            liveCandle: candleSet.live,
            lineData: StorybookData.points(.normal),
            lineValue: StorybookData.points(.normal).last?.value,
            color: StorybookData.bitcoinOrange,
            configuration: StorybookData.lineConfig(theme: .dark, window: 240, badge: false)
        )
    }

    static let candleLight = chart(
        id: "candle-light",
        group: "Candles",
        title: "Light Candles",
        detail: "Candle mode in light theme.",
        background: .white
    ) {
        let candleSet = StorybookData.candles(width: 30)
        LivelineChart(
            data: StorybookData.points(.normal),
            value: StorybookData.points(.normal).last?.value ?? 0,
            candles: candleSet.committed,
            candleWidth: 30,
            liveCandle: candleSet.live,
            lineData: StorybookData.points(.normal),
            lineValue: StorybookData.points(.normal).last?.value,
            color: StorybookData.bitcoinOrange,
            configuration: StorybookData.lineConfig(theme: .light, window: 240, badge: false)
        )
    }

    static let candleLineMode = chart(
        id: "candle-line-mode",
        group: "Candles",
        title: "Candle Line Mode",
        detail: "Candle data rendered as dense line.",
        background: StorybookData.darkBackground
    ) {
        let candleSet = StorybookData.candles(width: 30)
        LivelineChart(
            data: StorybookData.points(.normal),
            value: StorybookData.points(.normal).last?.value ?? 0,
            candles: candleSet.committed,
            candleWidth: 30,
            liveCandle: candleSet.live,
            lineData: StorybookData.points(.normal),
            lineValue: StorybookData.points(.normal).last?.value,
            color: StorybookData.bitcoinOrange,
            configuration: StorybookData.lineConfig(theme: .dark, window: 240, lineMode: true)
        )
    }

    static let candleModeControls = chart(
        id: "candle-mode-controls",
        group: "Candles",
        title: "Mode Controls",
        detail: "Built-in candle and line mode toggle.",
        background: StorybookData.darkBackground,
        height: 300
    ) {
        let candleSet = StorybookData.candles(width: 30)
        LivelineChart(
            data: StorybookData.points(.normal),
            value: StorybookData.points(.normal).last?.value ?? 0,
            candles: candleSet.committed,
            candleWidth: 30,
            liveCandle: candleSet.live,
            lineData: StorybookData.points(.normal),
            lineValue: StorybookData.points(.normal).last?.value,
            color: StorybookData.bitcoinOrange,
            configuration: StorybookData.lineConfig(theme: .dark, window: 240, onModeChange: { _ in })
        )
    }

    static let candleNoLive = chart(
        id: "candle-no-live",
        group: "Candles",
        title: "No Live Candle",
        detail: "Committed OHLC bars only.",
        background: StorybookData.darkBackground
    ) {
        let candleSet = StorybookData.candles(width: 30)
        LivelineChart(
            data: StorybookData.points(.normal),
            value: candleSet.committed.last?.close ?? 0,
            candles: candleSet.committed,
            candleWidth: 30,
            color: StorybookData.bitcoinOrange,
            configuration: StorybookData.lineConfig(theme: .dark, window: 240, badge: false)
        )
    }

    static let candleWideWindow = chart(
        id: "candle-wide-window",
        group: "Candles",
        title: "Wide Window",
        detail: "Small candle bodies across wider time range.",
        background: StorybookData.darkBackground
    ) {
        let candleSet = StorybookData.candles(width: 15)
        LivelineChart(
            data: StorybookData.points(.normal),
            value: StorybookData.points(.normal).last?.value ?? 0,
            candles: candleSet.committed,
            candleWidth: 15,
            liveCandle: candleSet.live,
            lineData: StorybookData.points(.normal),
            lineValue: StorybookData.points(.normal).last?.value,
            color: StorybookData.bitcoinOrange,
            configuration: StorybookData.lineConfig(theme: .dark, window: 360, badge: false)
        )
    }

    static let candleLoading = chart(
        id: "candle-loading",
        group: "States",
        title: "Candle Loading",
        detail: "Loading state in candle setup.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            data: [],
            value: 0,
            candles: [],
            candleWidth: 30,
            color: StorybookData.bitcoinOrange,
            configuration: StorybookData.lineConfig(theme: .dark, loading: true)
        )
    }

    static let multiBasic = chart(
        id: "multi-basic",
        group: "Multi-series",
        title: "Basic Multi",
        detail: "Three overlapping lines, shared grid.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            series: StorybookData.series,
            configuration: StorybookData.lineConfig(theme: .dark, window: 180)
        )
    }

    static let multiLight = chart(
        id: "multi-light",
        group: "Multi-series",
        title: "Light Multi",
        detail: "Multi-series in light theme.",
        background: .white
    ) {
        LivelineChart(
            series: StorybookData.series,
            configuration: StorybookData.lineConfig(theme: .light, window: 180)
        )
    }

    static let multiCompact = chart(
        id: "multi-compact",
        group: "Multi-series",
        title: "Compact Toggles",
        detail: "Dot-only series controls.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            series: StorybookData.series,
            configuration: StorybookData.lineConfig(theme: .dark, window: 180, seriesToggleCompact: true)
        )
    }

    static let multiTwoSeries = chart(
        id: "multi-two-series",
        group: "Multi-series",
        title: "Two Series",
        detail: "Two-line comparison.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            series: Array(StorybookData.series.prefix(2)),
            configuration: StorybookData.lineConfig(theme: .dark, window: 180)
        )
    }

    static func chart<V: View>(
        id: String,
        group: String,
        title: String,
        detail: String,
        background: Color,
        height: CGFloat = 280,
        @ViewBuilder makeView: @escaping () -> V
    ) -> StorybookScenario {
        StorybookScenario(
            id: id,
            group: group,
            title: title,
            detail: detail,
            background: background,
            height: height,
            makeView: { AnyView(makeView()) }
        )
    }
}

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
        snapshotElapsedTime: TimeInterval? = StorybookLaunch.snapshotElapsedTimeFromArguments(),
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
            snapshotElapsedTime: snapshotElapsedTime,
            lineMode: lineMode,
            seriesToggleCompact: seriesToggleCompact,
            onModeChange: onModeChange
        )
    }

    static func money(_ value: Double) -> String {
        "$" + value.formatted(.number.precision(.fractionLength(2)))
    }
}
