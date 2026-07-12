import Liveline
import SwiftUI

extension StorybookCatalog {
    static let barBasic = chart(
        id: .barBasic,
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
        id: .barSigned,
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
        id: .rangeBasic,
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
        id: .rangeCenterLine,
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
        id: .scatterBasic,
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
        id: .scatterConnected,
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
        id: .stepBasic,
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
        id: .stepCentered,
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
        id: .lollipopBasic,
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
        id: .lollipopDiamond,
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
        id: .bubbleBasic,
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
        id: .bubbleDiameter,
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
        id: .boxplotBasic,
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
        id: .boxplotMinimal,
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
        id: .waterfallBasic,
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
        id: .waterfallNoConnectors,
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
        id: .errorbarBasic,
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
        id: .errorbarDiamond,
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
        id: .dumbbellBasic,
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
        id: .dumbbellDirectional,
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

}
