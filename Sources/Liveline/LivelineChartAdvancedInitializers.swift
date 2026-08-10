import SwiftUI

extension LivelineChart {
    /// Creates mirrored kernel-density shapes for one or more distributions.
    public init(
        violin series: [LivelineDistributionSeries],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineViolinStyle = LivelineViolinStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(
            content: .advanced(.violin(series, style)), accent: color, configuration: configuration)
    }

    /// Creates stacked density ridgelines for several distributions.
    public init(
        ridgeline series: [LivelineDistributionSeries],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineRidgelineStyle = LivelineRidgelineStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(
            content: .advanced(.ridgeline(series, style)), accent: color, configuration: configuration)
    }

    /// Creates a week-column calendar heatmap from civil-day values.
    public init(
        calendarHeatmap values: [LivelineCalendarValue],
        color: Color = Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255),
        style: LivelineCalendarHeatmapStyle = LivelineCalendarHeatmapStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(
            content: .advanced(.calendarHeatmap(values, style)), accent: color,
            configuration: configuration)
    }

    /// Creates a task schedule with progress and dependency links.
    public init(
        gantt tasks: [LivelineGanttTask],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineGanttStyle = LivelineGanttStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(content: .advanced(.gantt(tasks, style)), accent: color, configuration: configuration)
    }

    /// Creates a circular chord diagram from weighted relationships.
    public init(
        chord links: [LivelineChordLink],
        color: Color = Color(red: 139 / 255, green: 92 / 255, blue: 246 / 255),
        style: LivelineChordStyle = LivelineChordStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(content: .advanced(.chord(links, style)), accent: color, configuration: configuration)
    }

    /// Creates a multi-axis parallel-coordinate comparison.
    public init(
        parallelCoordinates records: [LivelineParallelRecord],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineParallelCoordinatesStyle = LivelineParallelCoordinatesStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(
            content: .advanced(.parallelCoordinates(records, style)), accent: color,
            configuration: configuration)
    }

    /// Creates a density map by aggregating two-dimensional points into hexagons.
    public init(
        hexbin points: [LivelineXYPoint],
        color: Color = Color(red: 6 / 255, green: 182 / 255, blue: 212 / 255),
        style: LivelineHexbinStyle = LivelineHexbinStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(
            content: .advanced(.hexbin(points, style)), accent: color, configuration: configuration)
    }

    /// Creates a rank-over-time bump chart.
    public init(
        bump series: [LivelineRankSeries],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineBumpStyle = LivelineBumpStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(content: .advanced(.bump(series, style)), accent: color, configuration: configuration)
    }

    /// Creates a compact multi-band horizon chart.
    public init(
        horizon points: [LivelinePoint],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineHorizonStyle = LivelineHorizonStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(
            content: .advanced(.horizon(points, style)), accent: color, configuration: configuration)
    }

    /// Creates a two-dimensional proportional Marimekko chart.
    public init(
        marimekko columns: [LivelineMarimekkoColumn],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineMarimekkoStyle = LivelineMarimekkoStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(
            content: .advanced(.marimekko(columns, style)), accent: color, configuration: configuration)
    }

    /// Creates an equal-angle polar-area, or rose, chart.
    public init(
        polarArea values: [LivelineCategoryValue],
        color: Color = Color(red: 139 / 255, green: 92 / 255, blue: 246 / 255),
        style: LivelinePolarAreaStyle = LivelinePolarAreaStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(
            content: .advanced(.polarArea(values, style)), accent: color, configuration: configuration)
    }

    /// Creates a deterministic radial or grid network graph.
    public init(
        networkNodes nodes: [LivelineNetworkNode],
        edges: [LivelineNetworkEdge],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineNetworkStyle = LivelineNetworkStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(
            content: .advanced(.network(nodes, edges, style)), accent: color, configuration: configuration
        )
    }

    /// Creates level bands and isolines from a sampled scalar field.
    public init(
        contour samples: [LivelineContourSample],
        color: Color = Color(red: 6 / 255, green: 182 / 255, blue: 212 / 255),
        style: LivelineContourStyle = LivelineContourStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(
            content: .advanced(.contour(samples, style)), accent: color, configuration: configuration)
    }

    /// Creates a three-component composition plot.
    public init(
        ternary points: [LivelineTernaryPoint],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineTernaryStyle = LivelineTernaryStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(
            content: .advanced(.ternary(points, style)), accent: color, configuration: configuration)
    }

    /// Creates a fixed-cell percentage waffle chart.
    public init(
        waffle values: [LivelineCategoryValue],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineWaffleStyle = LivelineWaffleStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(
            content: .advanced(.waffle(values, style)), accent: color, configuration: configuration)
    }

    /// Creates a horizontal volume distribution across price levels.
    public init(
        volumeProfile levels: [LivelinePriceVolume],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineVolumeProfileStyle = LivelineVolumeProfileStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(
            content: .advanced(.volumeProfile(levels, style)), accent: color, configuration: configuration
        )
    }

    /// Creates Renko bricks derived from a price series and fixed brick size.
    public init(
        renko prices: [LivelinePoint],
        color: Color = Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255),
        style: LivelineRenkoStyle,
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(
            content: .advanced(.renko(LivelineRenkoSeries(points: prices, style: style), style)),
            accent: color, configuration: configuration)
    }

    /// Creates Heikin-Ashi candles derived from standard OHLC intervals.
    public init(
        heikinAshi candles: [LivelineCandle],
        color: Color = Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255),
        style: LivelineHeikinAshiStyle = LivelineHeikinAshiStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(
            content: .advanced(.heikinAshi(LivelineHeikinAshiSeries(source: candles), style)),
            accent: color, configuration: configuration)
    }

    /// Creates cumulative bid and ask market-depth curves.
    public init(
        marketDepth levels: [LivelineOrderBookLevel],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineMarketDepthStyle = LivelineMarketDepthStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(
            content: .advanced(.marketDepth(levels, style)), accent: color, configuration: configuration)
    }

    /// Creates synchronized OHLC and traded-volume panes on one time axis.
    public init(
        ohlcVolume values: [LivelineCandleVolume],
        color: Color = Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255),
        style: LivelineOHLCVolumeStyle = LivelineOHLCVolumeStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(
            content: .advanced(.ohlcVolume(values, style)), accent: color, configuration: configuration)
    }

    /// Creates point-and-figure columns derived from prices, box size, and reversal rule.
    public init(
        pointAndFigure prices: [LivelinePoint],
        color: Color = Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255),
        style: LivelinePointAndFigureStyle,
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(
            content: .advanced(
                .pointAndFigure(LivelinePointFigureSeries(points: prices, style: style), style)),
            accent: color, configuration: configuration)
    }
}
