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
        lineEmptyControls,
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
        barBasic,
        barSigned,
        rangeBasic,
        rangeCenterLine,
        scatterBasic,
        scatterConnected,
        stepBasic,
        stepCentered,
        lollipopBasic,
        lollipopDiamond,
        bubbleBasic,
        bubbleDiameter,
        boxPlotBasic,
        boxPlotMinimal,
        waterfallBasic,
        waterfallNoConnectors,
        errorBarBasic,
        errorBarDiamond,
        dumbbellBasic,
        dumbbellDirectional,
        stackedBarBasic,
        stackedBarNormalized,
        stackedAreaBasic,
        stackedAreaNormalized,
        timelineBasic,
        timelineCompact,
        heatmapBasic,
        heatmapValues,
        radarBasic,
        radarMinimal,
        donutBasic,
        donutThin,
        gaugeBasic,
        gaugeTarget,
        funnelBasic,
        funnelCompact,
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

    static let lineEmptyControls = chart(
        id: "line-empty-controls",
        group: "States",
        title: "Empty With Controls",
        detail: "Empty state centered in the remaining plot viewport.",
        background: StorybookData.darkBackground,
        height: 310
    ) {
        LivelineChart(
            data: [],
            value: 0,
            color: StorybookData.blue,
            configuration: StorybookData.lineConfig(
                theme: .dark,
                window: 60,
                windows: StorybookData.windows,
                showValue: true,
                emptyText: "No data to display"
            )
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

    static let barBasic = chart(
        id: "bar-basic",
        group: "Bars",
        title: "Bucketed Volume",
        detail: "Rounded bars for regular time buckets.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            bars: StorybookData.bars(signed: false),
            color: StorybookData.teal,
            style: LivelineBarStyle(widthRatio: 0.72, cornerRadius: 3),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: " req")
        )
    }

    static let barSigned = chart(
        id: "bar-signed",
        group: "Bars",
        title: "Target Variance",
        detail: "Square bars diverging from a custom 4% target baseline.",
        background: .white
    ) {
        LivelineChart(
            bars: StorybookData.bars(signed: true),
            color: StorybookData.green,
            style: LivelineBarStyle(
                widthRatio: 0.46,
                cornerRadius: 0,
                baseline: 4,
                negativeColor: StorybookData.red
            ),
            configuration: StorybookData.staticSnapshotConfig(theme: .light, window: 180, suffix: "%")
        )
    }

    static let rangeBasic = chart(
        id: "range-basic",
        group: "Range bands",
        title: "Forecast Band",
        detail: "Filled lower/upper interval with emphasized boundaries.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            range: StorybookData.ranges,
            color: StorybookData.indigo,
            style: LivelineRangeStyle(fillOpacity: 0.22, boundaryLineWidth: 1.5),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: "%")
        )
    }

    static let rangeCenterLine = chart(
        id: "range-center-line",
        group: "Range bands",
        title: "Expected Range",
        detail: "Light band with a dashed center estimate.",
        background: .white
    ) {
        LivelineChart(
            range: StorybookData.ranges,
            color: StorybookData.orange,
            style: LivelineRangeStyle(
                fillOpacity: 0.1,
                boundaryLineWidth: 0.75,
                showsCenterLine: true,
                centerLineWidth: 1.5
            ),
            configuration: StorybookData.staticSnapshotConfig(theme: .light, window: 180, suffix: "%")
        )
    }

    static let scatterBasic = chart(
        id: "scatter-basic",
        group: "Scatter",
        title: "Sparse Observations",
        detail: "Independent circular points with background outlines.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            scatter: StorybookData.scatter,
            color: StorybookData.violet,
            style: LivelineScatterStyle(pointSize: 8, outlineWidth: 1.5),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: " ms")
        )
    }

    static let scatterConnected = chart(
        id: "scatter-connected",
        group: "Scatter",
        title: "Connected Samples",
        detail: "Diamond symbols joined by a curved trend line.",
        background: .white
    ) {
        LivelineChart(
            scatter: StorybookData.scatter,
            color: StorybookData.cyan,
            style: LivelineScatterStyle(
                symbol: .diamond,
                pointSize: 9,
                outlineWidth: 1,
                connection: .curved,
                connectionLineWidth: 1.5
            ),
            configuration: StorybookData.staticSnapshotConfig(theme: .light, window: 180, suffix: " ms")
        )
    }

    static let stepBasic = chart(
        id: "step-basic",
        group: "Step",
        title: "Deployment Levels",
        detail: "Trailing transitions with a subtle area fill.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            steps: StorybookData.steps,
            color: StorybookData.cyan,
            style: LivelineStepStyle(position: .trailing, lineWidth: 2, fillOpacity: 0.12),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: "%")
        )
    }

    static let stepCentered = chart(
        id: "step-centered",
        group: "Step",
        title: "Centered State Changes",
        detail: "Centered transitions with a heavier unfilled line.",
        background: .white
    ) {
        LivelineChart(
            steps: StorybookData.steps,
            color: StorybookData.blue,
            style: LivelineStepStyle(position: .center, lineWidth: 3, fillOpacity: 0),
            configuration: StorybookData.staticSnapshotConfig(theme: .light, window: 180, suffix: "%")
        )
    }

    static let lollipopBasic = chart(
        id: "lollipop-basic",
        group: "Lollipop",
        title: "Signed Events",
        detail: "Circular heads and stems diverging from zero.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            lollipops: StorybookData.lollipops,
            color: StorybookData.green,
            style: LivelineLollipopStyle(baseline: 0, stemWidth: 1.5, headSize: 9),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: "%")
        )
    }

    static let lollipopDiamond = chart(
        id: "lollipop-diamond",
        group: "Lollipop",
        title: "Target Deviations",
        detail: "Diamond heads around a custom target baseline.",
        background: .white
    ) {
        LivelineChart(
            lollipops: StorybookData.lollipops.map { LivelinePoint(time: $0.time, value: $0.value + 4) },
            color: StorybookData.orange,
            style: LivelineLollipopStyle(
                baseline: 4,
                stemWidth: 2,
                headSize: 11,
                headSymbol: .diamond,
                outlineWidth: 0,
                showsBaseline: false
            ),
            configuration: StorybookData.staticSnapshotConfig(theme: .light, window: 180, suffix: "%")
        )
    }

    static let bubbleBasic = chart(
        id: "bubble-basic",
        group: "Bubble",
        title: "Request Cost",
        detail: "Bubble area represents request volume.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            bubbles: StorybookData.bubbles,
            color: StorybookData.violet,
            style: LivelineBubbleStyle(minimumSize: 5, maximumSize: 24, fillOpacity: 0.28, scale: .area),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: " ms")
        )
    }

    static let bubbleDiameter = chart(
        id: "bubble-diameter",
        group: "Bubble",
        title: "Linear Bubble Scale",
        detail: "Diameter scaling with bold outlines and translucent fills.",
        background: .white
    ) {
        LivelineChart(
            bubbles: StorybookData.bubbles,
            color: StorybookData.cyan,
            style: LivelineBubbleStyle(
                minimumSize: 8,
                maximumSize: 30,
                fillOpacity: 0.14,
                outlineWidth: 2,
                scale: .diameter
            ),
            configuration: StorybookData.staticSnapshotConfig(theme: .light, window: 180, suffix: " ms")
        )
    }

    static let boxPlotBasic = chart(
        id: "boxplot-basic",
        group: "Box plot",
        title: "Latency Distribution",
        detail: "Five-number summaries for rolling latency windows.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            boxPlots: StorybookData.boxPlots,
            color: StorybookData.indigo,
            style: LivelineBoxPlotStyle(widthRatio: 0.58, fillOpacity: 0.2),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: " ms")
        )
    }

    static let boxPlotMinimal = chart(
        id: "boxplot-minimal",
        group: "Box plot",
        title: "Outlined Distribution",
        detail: "Unfilled narrow boxes with emphasized medians.",
        background: .white
    ) {
        LivelineChart(
            boxPlots: StorybookData.boxPlots,
            color: StorybookData.orange,
            style: LivelineBoxPlotStyle(
                widthRatio: 0.38,
                fillOpacity: 0,
                outlineWidth: 2,
                medianLineWidth: 3,
                whiskerWidthRatio: 0.8
            ),
            configuration: StorybookData.staticSnapshotConfig(theme: .light, window: 180, suffix: " ms")
        )
    }

    static let waterfallBasic = chart(
        id: "waterfall-basic",
        group: "Waterfall",
        title: "Balance Contributions",
        detail: "Cumulative gains and losses connected across time.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            waterfall: StorybookData.waterfall,
            color: StorybookData.green,
            style: LivelineWaterfallStyle(initialValue: 100, widthRatio: 0.62, cornerRadius: 3),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: " k")
        )
    }

    static let waterfallNoConnectors = chart(
        id: "waterfall-no-connectors",
        group: "Waterfall",
        title: "Compact Changes",
        detail: "Wide square steps without connectors or a baseline.",
        background: .white
    ) {
        LivelineChart(
            waterfall: StorybookData.waterfall,
            color: StorybookData.blue,
            style: LivelineWaterfallStyle(
                initialValue: 50,
                widthRatio: 0.86,
                cornerRadius: 0,
                showsConnectors: false,
                showsBaseline: false
            ),
            configuration: StorybookData.staticSnapshotConfig(theme: .light, window: 180, suffix: " k")
        )
    }

    static let errorBarBasic = chart(
        id: "errorbar-basic",
        group: "Error bar",
        title: "Confidence Intervals",
        detail: "Central estimates with capped uncertainty bounds.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            errorBars: StorybookData.errorBars,
            color: StorybookData.cyan,
            style: LivelineErrorBarStyle(capWidth: 11, lineWidth: 1.5, pointSize: 7),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: " ms")
        )
    }

    static let errorBarDiamond = chart(
        id: "errorbar-diamond",
        group: "Error bar",
        title: "Forecast Bounds",
        detail: "Diamond estimates with wide, lightly filled caps.",
        background: .white
    ) {
        LivelineChart(
            errorBars: StorybookData.errorBars,
            color: StorybookData.orange,
            style: LivelineErrorBarStyle(capWidth: 16, lineWidth: 2, pointSize: 9, pointSymbol: .diamond, fillOpacity: 0.18),
            configuration: StorybookData.staticSnapshotConfig(theme: .light, window: 180, suffix: " ms")
        )
    }

    static let dumbbellBasic = chart(
        id: "dumbbell-basic",
        group: "Dumbbell",
        title: "Before and After",
        detail: "Paired values connected across each time bucket.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            dumbbells: StorybookData.dumbbells,
            color: StorybookData.green,
            style: LivelineDumbbellStyle(lineWidth: 2, pointSize: 9, startColor: StorybookData.violet),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: "%")
        )
    }

    static let dumbbellDirectional = chart(
        id: "dumbbell-directional",
        group: "Dumbbell",
        title: "Directional Change",
        detail: "Square endpoints and direction chevrons emphasize movement.",
        background: .white
    ) {
        LivelineChart(
            dumbbells: StorybookData.dumbbells,
            color: StorybookData.blue,
            style: LivelineDumbbellStyle(
                lineWidth: 3,
                pointSize: 10,
                pointSymbol: .square,
                startColor: StorybookData.orange,
                endColor: StorybookData.blue,
                showsDirection: true
            ),
            configuration: StorybookData.staticSnapshotConfig(theme: .light, window: 180, suffix: "%")
        )
    }

    static let stackedBarBasic = chart(
        id: "stackedbar-basic",
        group: "Stacked bar",
        title: "Traffic Mix",
        detail: "Absolute segment totals with rounded, separated stacks.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            stackedBars: StorybookData.stacked,
            color: StorybookData.blue,
            style: LivelineStackedBarStyle(
                widthRatio: 0.74,
                cornerRadius: 2,
                segmentSpacing: 1,
                colors: StorybookData.segmentColors
            ),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: " k")
        )
    }

    static let stackedBarNormalized = chart(
        id: "stackedbar-normalized",
        group: "Stacked bar",
        title: "Traffic Share",
        detail: "Each stack is normalized to 100 percent.",
        background: .white
    ) {
        LivelineChart(
            stackedBars: StorybookData.stacked,
            color: StorybookData.blue,
            style: LivelineStackedBarStyle(
                mode: .normalized,
                widthRatio: 0.88,
                cornerRadius: 0,
                segmentSpacing: 0,
                colors: StorybookData.segmentColors,
                showsBaseline: false
            ),
            configuration: StorybookData.normalizedSnapshotConfig(theme: .light, window: 180)
        )
    }

    static let stackedAreaBasic = chart(
        id: "stackedarea-basic",
        group: "Stacked area",
        title: "Service Volume",
        detail: "Layered absolute volumes with visible boundaries.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            stackedAreas: StorybookData.stackedArea,
            color: StorybookData.blue,
            style: LivelineStackedAreaStyle(colors: StorybookData.segmentColors, fillOpacity: 0.55, boundaryLineWidth: 1.25),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: " k")
        )
    }

    static let stackedAreaNormalized = chart(
        id: "stackedarea-normalized",
        group: "Stacked area",
        title: "Service Share",
        detail: "Normalized layers show composition rather than magnitude.",
        background: .white
    ) {
        LivelineChart(
            stackedAreas: StorybookData.stackedArea,
            color: StorybookData.blue,
            style: LivelineStackedAreaStyle(
                mode: .normalized,
                colors: StorybookData.segmentColors,
                fillOpacity: 0.72,
                boundaryLineWidth: 0,
                showsBaseline: false
            ),
            configuration: StorybookData.normalizedSnapshotConfig(theme: .light, window: 180)
        )
    }

    static let timelineBasic = chart(
        id: "timeline-basic",
        group: "Timeline",
        title: "Release Pipeline",
        detail: "Overlapping work intervals arranged across lanes.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            timeline: StorybookData.timeline,
            color: StorybookData.cyan,
            style: LivelineTimelineStyle(colors: StorybookData.segmentColors, showsLabels: true),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: "")
        )
    }

    static let timelineCompact = chart(
        id: "timeline-compact",
        group: "Timeline",
        title: "Compact Schedule",
        detail: "Slim square intervals without lane guides.",
        background: .white
    ) {
        LivelineChart(
            timeline: StorybookData.timeline,
            color: StorybookData.orange,
            style: LivelineTimelineStyle(barHeightRatio: 0.36, cornerRadius: 0, colors: [StorybookData.orange], showsLabels: false, showsLaneGuides: false),
            configuration: StorybookData.staticSnapshotConfig(theme: .light, window: 180, suffix: "")
        )
    }

    static let heatmapBasic = chart(
        id: "heatmap-basic",
        group: "Heatmap",
        title: "Regional Load",
        detail: "Color intensity tracks load across time and regions.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            heatmap: StorybookData.heatmap,
            color: StorybookData.violet,
            style: LivelineHeatmapStyle(rowLabels: ["US", "EU", "APAC", "LATAM"], color: StorybookData.violet),
            configuration: StorybookData.staticSnapshotConfig(
                theme: .dark,
                window: 180,
                suffix: "%",
                padding: LivelinePadding(left: 50)
            )
        )
    }

    static let heatmapValues = chart(
        id: "heatmap-values",
        group: "Heatmap",
        title: "Annotated Matrix",
        detail: "Wide cells display their rounded intensity values.",
        background: .white
    ) {
        LivelineChart(
            heatmap: StorybookData.heatmapSparse,
            color: StorybookData.teal,
            style: LivelineHeatmapStyle(
                rowLabels: ["API", "Jobs", "DB"],
                color: StorybookData.teal,
                minimumOpacity: 0.08,
                cellWidthRatio: 0.94,
                cellHeightRatio: 0.74,
                cornerRadius: 5,
                showsValues: true
            ),
            configuration: StorybookData.staticSnapshotConfig(
                theme: .light,
                window: 180,
                suffix: "%",
                padding: LivelinePadding(left: 50)
            )
        )
    }

    static let radarBasic = chart(
        id: "radar-basic",
        group: "Radar",
        title: "System Profile",
        detail: "Six labeled axes with filled performance coverage.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            radar: StorybookData.radar,
            color: StorybookData.cyan,
            style: LivelineRadarStyle(range: 0...100, gridLevels: 5, fillOpacity: 0.22, lineWidth: 2, pointSize: 5),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: "%")
        )
    }

    static let radarMinimal = chart(
        id: "radar-minimal",
        group: "Radar",
        title: "Minimal Profile",
        detail: "Three grid levels without labels or point markers.",
        background: .white
    ) {
        LivelineChart(
            radar: StorybookData.radar,
            color: StorybookData.orange,
            style: LivelineRadarStyle(range: 0...100, gridLevels: 3, fillOpacity: 0.10, lineWidth: 3, pointSize: 0, showsLabels: false),
            configuration: StorybookData.staticSnapshotConfig(theme: .light, window: 180, suffix: "%")
        )
    }

    static let donutBasic = chart(
        id: "donut-basic",
        group: "Donut",
        title: "Revenue Mix",
        detail: "Categorical composition with an aggregate center value.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            donut: StorybookData.categories,
            color: StorybookData.blue,
            style: LivelineDonutStyle(innerRadiusRatio: 0.58, gapDegrees: 3, colors: StorybookData.segmentColors),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: " k")
        )
    }

    static let donutThin = chart(
        id: "donut-thin",
        group: "Donut",
        title: "Thin Ring Breakdown",
        detail: "A thin ring with value-bearing outside labels.",
        background: .white
    ) {
        LivelineChart(
            donut: StorybookData.categories,
            color: StorybookData.violet,
            style: LivelineDonutStyle(innerRadiusRatio: 0.78, gapDegrees: 1, colors: StorybookData.segmentColors, showsLabels: true, showsValues: true),
            configuration: StorybookData.staticSnapshotConfig(theme: .light, window: 180, suffix: " k")
        )
    }

    static let gaugeBasic = chart(
        id: "gauge-basic",
        group: "Gauge",
        title: "Capacity",
        detail: "A 240-degree radial progress gauge with ticks.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            gauge: 72,
            range: 0...100,
            color: StorybookData.green,
            style: LivelineGaugeStyle(lineWidth: 20, trackOpacity: 0.18),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: "%")
        )
    }

    static let gaugeTarget = chart(
        id: "gauge-target",
        group: "Gauge",
        title: "SLA Target",
        detail: "A wide sweep with an explicit target marker.",
        background: .white
    ) {
        LivelineChart(
            gauge: 91.4,
            range: 0...100,
            color: StorybookData.blue,
            style: LivelineGaugeStyle(startAngleDegrees: 180, sweepDegrees: 180, lineWidth: 14, trackOpacity: 0.10, target: 95, showsTicks: false),
            configuration: StorybookData.staticSnapshotConfig(theme: .light, window: 180, suffix: "%")
        )
    }

    static let funnelBasic = chart(
        id: "funnel-basic",
        group: "Funnel",
        title: "Conversion Funnel",
        detail: "Stage widths preserve absolute conversion volume.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            funnel: StorybookData.funnel,
            color: StorybookData.blue,
            style: LivelineFunnelStyle(colors: StorybookData.segmentColors),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: "")
        )
    }

    static let funnelCompact = chart(
        id: "funnel-compact",
        group: "Funnel",
        title: "Compact Stages",
        detail: "Tightly spaced square stages with labels only.",
        background: .white
    ) {
        LivelineChart(
            funnel: StorybookData.funnel,
            color: StorybookData.orange,
            style: LivelineFunnelStyle(
                maximumWidthRatio: 0.76,
                minimumWidthRatio: 0.24,
                spacing: 1,
                cornerRadius: 0,
                colors: [StorybookData.orange, StorybookData.red],
                showsLabels: true,
                showsValues: false
            ),
            configuration: StorybookData.staticSnapshotConfig(theme: .light, window: 180, suffix: "")
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
            formatValue: { value in
                value.formatted(.number.precision(.fractionLength(0))) + suffix
            },
            snapshotElapsedTime: StorybookLaunch.snapshotElapsedTimeFromArguments(),
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
            formatValue: { value in
                (value * 100).formatted(.number.precision(.fractionLength(0))) + "%"
            },
            snapshotElapsedTime: StorybookLaunch.snapshotElapsedTimeFromArguments()
        )
    }

    static func money(_ value: Double) -> String {
        "$" + value.formatted(.number.precision(.fractionLength(2)))
    }
}
