import Liveline
import SwiftUI

extension StorybookCatalog {
    static let lineBasicDark = chart(
        id: .lineBasicDark,
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
        id: .lineBasicLight,
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
        id: .lineNoGridNoFill,
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
        id: .lineMinimalBadge,
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
        id: .lineNoBadge,
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
        id: .lineMomentumUp,
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
        id: .lineMomentumDown,
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
        id: .lineExaggerated,
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
        id: .lineShowValueWindows,
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
        id: .lineRoundedWindows,
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
        id: .lineTextWindows,
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
        id: .lineReference,
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
        id: .lineOrderbook,
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
        id: .lineDegen,
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
        id: .lineLoading,
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
        id: .lineEmpty,
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
        id: .lineEmptyControls,
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
        id: .candleBasic,
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
        id: .candleLight,
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
        id: .candleLineMode,
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
        id: .candleModeControls,
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
        id: .candleNoLive,
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
        id: .candleWideWindow,
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
        id: .candleLoading,
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
        id: .multiBasic,
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
        id: .multiLight,
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
        id: .multiCompact,
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
        id: .multiTwoSeries,
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

}
