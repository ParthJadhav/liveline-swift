import Liveline
import SwiftUI

extension StorybookCatalog {
    static let violinBasic = chart(
        id: .violinBasic,
        group: "Violin",
        title: "Latency Shape",
        detail: "Mirrored density, quartiles, and medians across three clients.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            violin: StorybookData.distributions,
            color: StorybookData.blue,
            style: LivelineViolinStyle(colors: StorybookData.segmentColors),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: " ms")
        )
    }

    static let ridgelineBasic = chart(
        id: .ridgelineBasic,
        group: "Ridgeline",
        title: "Latency Layers",
        detail: "Overlapping density profiles make distribution shifts easy to compare.",
        background: .white
    ) {
        LivelineChart(
            ridgeline: StorybookData.distributions,
            color: StorybookData.violet,
            style: LivelineRidgelineStyle(colors: StorybookData.segmentColors),
            configuration: StorybookData.staticSnapshotConfig(theme: .light, window: 180, suffix: " ms")
        )
    }

    static let calendarHeatmapBasic = chart(
        id: .calendarHeatmapBasic,
        group: "Calendar heatmap",
        title: "Daily Activity",
        detail: "Fourteen weeks of activity arranged by civil day.",
        background: StorybookData.darkBackground,
        height: 240
    ) {
        LivelineChart(
            calendarHeatmap: StorybookData.calendarActivity,
            color: StorybookData.green,
            style: LivelineCalendarHeatmapStyle(colorScale: [StorybookData.teal, StorybookData.green]),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: "")
        )
    }

    static let ganttBasic = chart(
        id: .ganttBasic,
        group: "Gantt",
        title: "Release Plan",
        detail: "Task progress and dependencies share a time-aligned schedule.",
        background: .white
    ) {
        LivelineChart(
            gantt: StorybookData.ganttTasks,
            color: StorybookData.blue,
            style: LivelineGanttStyle(colors: StorybookData.segmentColors),
            configuration: StorybookData.staticSnapshotConfig(
                theme: .light,
                window: 220,
                suffix: "",
                padding: LivelinePadding(left: 68)
            )
        )
    }

    static let chordBasic = chart(
        id: .chordBasic,
        group: "Chord",
        title: "Team Collaboration",
        detail: "Weighted relationships curve between proportional team arcs.",
        background: StorybookData.darkBackground,
        height: 320
    ) {
        LivelineChart(
            chord: StorybookData.chordLinks,
            color: StorybookData.violet,
            style: LivelineChordStyle(colors: StorybookData.segmentColors),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: "")
        )
    }

    static let parallelBasic = chart(
        id: .parallelBasic,
        group: "Parallel coordinates",
        title: "Release Candidates",
        detail: "Four candidates compared across five independently scaled dimensions.",
        background: .white
    ) {
        LivelineChart(
            parallelCoordinates: StorybookData.parallelRecords,
            color: StorybookData.blue,
            style: LivelineParallelCoordinatesStyle(
                axisLabels: ["Speed", "Cost", "Safety", "Scale", "DX"],
                colors: StorybookData.segmentColors
            ),
            configuration: StorybookData.staticSnapshotConfig(theme: .light, window: 180, suffix: "")
        )
    }

    static let hexbinBasic = chart(
        id: .hexbinBasic,
        group: "Hexbin",
        title: "Request Density",
        detail: "Two-dimensional observations aggregate into density-preserving hexagons.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            hexbin: StorybookData.hexbinPoints,
            color: StorybookData.cyan,
            style: LivelineHexbinStyle(binsAcross: 20),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: "")
        )
    }

    static let bumpBasic = chart(
        id: .bumpBasic,
        group: "Bump",
        title: "Weekly Rank",
        detail: "Rank crossings remain traceable with direct end labels.",
        background: .white
    ) {
        LivelineChart(
            bump: StorybookData.bumpSeries,
            color: StorybookData.blue,
            style: LivelineBumpStyle(colors: StorybookData.segmentColors),
            configuration: StorybookData.staticSnapshotConfig(theme: .light, window: 180, suffix: "")
        )
    }

    static let horizonBasic = chart(
        id: .horizonBasic,
        group: "Horizon",
        title: "Traffic Deviation",
        detail: "Positive and negative deviations fold into three compact bands.",
        background: StorybookData.darkBackground,
        height: 220
    ) {
        LivelineChart(
            horizon: StorybookData.horizonPoints,
            color: StorybookData.blue,
            style: LivelineHorizonStyle(bandCount: 3),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 190, suffix: "%")
        )
    }

    static let marimekkoBasic = chart(
        id: .marimekkoBasic,
        group: "Marimekko",
        title: "Revenue Mix by Region",
        detail: "Column width and stacked height encode two proportional dimensions.",
        background: .white
    ) {
        LivelineChart(
            marimekko: StorybookData.marimekkoColumns,
            color: StorybookData.blue,
            style: LivelineMarimekkoStyle(showsValues: true, colors: StorybookData.segmentColors),
            configuration: StorybookData.staticSnapshotConfig(theme: .light, window: 180, suffix: "%")
        )
    }

    static let polarAreaBasic = chart(
        id: .polarAreaBasic,
        group: "Polar area",
        title: "Plan Distribution",
        detail: "Equal-angle sectors compare category magnitude by area.",
        background: StorybookData.darkBackground,
        height: 320
    ) {
        LivelineChart(
            polarArea: StorybookData.categories,
            color: StorybookData.violet,
            style: LivelinePolarAreaStyle(colors: StorybookData.segmentColors),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: "%")
        )
    }

    static let networkBasic = chart(
        id: .networkBasic,
        group: "Network",
        title: "Service Topology",
        detail: "Weighted nodes and edges reveal a compact service dependency graph.",
        background: .white,
        height: 320
    ) {
        LivelineChart(
            networkNodes: StorybookData.networkNodes,
            edges: StorybookData.networkEdges,
            color: StorybookData.blue,
            style: LivelineNetworkStyle(colors: StorybookData.segmentColors),
            configuration: StorybookData.staticSnapshotConfig(theme: .light, window: 180, suffix: "")
        )
    }

    static let contourBasic = chart(
        id: .contourBasic,
        group: "Contour",
        title: "Response Surface",
        detail: "Filled scalar-field bands retain clear level boundaries.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            contour: StorybookData.contourSamples,
            color: StorybookData.cyan,
            style: LivelineContourStyle(
                levelCount: 7, colors: [StorybookData.blue, StorybookData.cyan, StorybookData.green]),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: "")
        )
    }

    static let ternaryBasic = chart(
        id: .ternaryBasic,
        group: "Ternary",
        title: "Workload Composition",
        detail: "Three-part compositions plot inside a normalized triangular domain.",
        background: .white,
        height: 320
    ) {
        LivelineChart(
            ternary: StorybookData.ternaryPoints,
            color: StorybookData.blue,
            style: LivelineTernaryStyle(
                axisLabels: ["Compute", "Storage", "Network"],
                colors: StorybookData.segmentColors
            ),
            configuration: StorybookData.staticSnapshotConfig(theme: .light, window: 180, suffix: "%")
        )
    }

    static let waffleBasic = chart(
        id: .waffleBasic,
        group: "Waffle",
        title: "Subscriber Mix",
        detail: "One hundred cells turn category share into an exact, countable composition.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            waffle: StorybookData.categories,
            color: StorybookData.blue,
            style: LivelineWaffleStyle(colors: StorybookData.segmentColors),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: "%")
        )
    }

    static let volumeProfileBasic = chart(
        id: .volumeProfileBasic,
        group: "Volume profile",
        title: "Volume by Price",
        detail: "Horizontal volume bars highlight the dominant price level.",
        background: .white
    ) {
        LivelineChart(
            volumeProfile: StorybookData.volumeProfile,
            color: StorybookData.blue,
            style: LivelineVolumeProfileStyle(
                showsValues: true, pointOfControlColor: StorybookData.orange),
            configuration: StorybookData.staticSnapshotConfig(theme: .light, window: 180, suffix: "")
        )
    }

    static let renkoBasic = chart(
        id: .renkoBasic,
        group: "Renko",
        title: "Price Bricks",
        detail: "Fixed-size bricks suppress time noise and emphasize directional moves.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            renko: StorybookData.points(.normal, count: 180),
            color: StorybookData.green,
            style: LivelineRenkoStyle(brickSize: 0.8),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: "")
        )
    }

    static let heikinAshiBasic = chart(
        id: .heikinAshiBasic,
        group: "Heikin-Ashi",
        title: "Smoothed Candles",
        detail: "Derived OHLC candles reduce short-term noise while preserving trend direction.",
        background: .white
    ) {
        LivelineChart(
            heikinAshi: StorybookData.candles(width: 15).committed,
            color: StorybookData.green,
            configuration: StorybookData.staticSnapshotConfig(theme: .light, window: 180, suffix: "")
        )
    }

    static let marketDepthBasic = chart(
        id: .marketDepthBasic,
        group: "Market depth",
        title: "Order Book Depth",
        detail: "Cumulative bid and ask liquidity frame the live spread.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            marketDepth: StorybookData.marketDepth,
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: "")
        )
    }

    static let ohlcVolumeBasic = chart(
        id: .ohlcVolumeBasic,
        group: "OHLC + volume",
        title: "Price and Volume",
        detail: "Synchronized panes align candle movement with traded volume.",
        background: .white,
        height: 320
    ) {
        LivelineChart(
            ohlcVolume: StorybookData.candleVolumes,
            color: StorybookData.green,
            configuration: StorybookData.staticSnapshotConfig(theme: .light, window: 180, suffix: "")
        )
    }

    static let pointFigureBasic = chart(
        id: .pointFigureBasic,
        group: "Point-and-figure",
        title: "Reversal Columns",
        detail: "X and O columns expose price reversals without a continuous time axis.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            pointAndFigure: StorybookData.points(.normal, count: 220),
            color: StorybookData.green,
            style: LivelinePointAndFigureStyle(boxSize: 0.65, reversalBoxes: 3),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 220, suffix: "")
        )
    }
}
