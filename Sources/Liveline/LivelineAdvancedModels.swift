import Foundation
import SwiftUI

// MARK: - Distribution charts

/// A named collection of observations rendered by distribution charts.
public struct LivelineDistributionSeries: Identifiable, Hashable, Sendable {
    public var id: String
    public var label: String
    public var values: [Double]

    public init(id: String, label: String, values: [Double]) {
        self.id = id
        self.label = label
        self.values = values.filter(\.isFinite)
    }
}

/// Visual options shared by violin plots.
public struct LivelineViolinStyle {
    public var bandwidth: Double?
    public var widthRatio: CGFloat
    public var fillOpacity: Double
    public var lineWidth: CGFloat
    public var showsMedian: Bool
    public var showsQuartiles: Bool
    public var showsLabels: Bool
    public var colors: [Color]

    public init(
        bandwidth: Double? = nil,
        widthRatio: CGFloat = 0.78,
        fillOpacity: Double = 0.34,
        lineWidth: CGFloat = 1.5,
        showsMedian: Bool = true,
        showsQuartiles: Bool = true,
        showsLabels: Bool = true,
        colors: [Color] = []
    ) {
        self.bandwidth = bandwidth
        self.widthRatio = widthRatio
        self.fillOpacity = fillOpacity
        self.lineWidth = lineWidth
        self.showsMedian = showsMedian
        self.showsQuartiles = showsQuartiles
        self.showsLabels = showsLabels
        self.colors = colors
    }

    var resolvedWidthRatio: CGFloat { widthRatio.livelineClamped(0.2, 1, fallback: 0.78) }
    var resolvedFillOpacity: Double { fillOpacity.livelineClamped(0, 1, fallback: 0.34) }
    var resolvedLineWidth: CGFloat { lineWidth.livelineAtLeast(0.5, fallback: 1.5) }
}

/// Visual options for stacked density ridgelines.
public struct LivelineRidgelineStyle {
    public var bandwidth: Double?
    public var overlap: CGFloat
    public var fillOpacity: Double
    public var lineWidth: CGFloat
    public var showsLabels: Bool
    public var colors: [Color]

    public init(
        bandwidth: Double? = nil,
        overlap: CGFloat = 0.58,
        fillOpacity: Double = 0.28,
        lineWidth: CGFloat = 1.5,
        showsLabels: Bool = true,
        colors: [Color] = []
    ) {
        self.bandwidth = bandwidth
        self.overlap = overlap
        self.fillOpacity = fillOpacity
        self.lineWidth = lineWidth
        self.showsLabels = showsLabels
        self.colors = colors
    }

    var resolvedOverlap: CGFloat { overlap.livelineClamped(0, 0.85, fallback: 0.58) }
    var resolvedFillOpacity: Double { fillOpacity.livelineClamped(0, 1, fallback: 0.28) }
    var resolvedLineWidth: CGFloat { lineWidth.livelineAtLeast(0.5, fallback: 1.5) }
}

// MARK: - Calendar and planning charts

/// A value associated with one civil day.
public struct LivelineCalendarValue: Identifiable, Hashable, Sendable {
    public var date: Date
    public var value: Double
    public var label: String?

    public var id: Date { date }

    public init(date: Date, value: Double, label: String? = nil) {
        self.date = date
        self.value = value.isFinite ? max(value, 0) : 0
        self.label = label
    }
}

/// Visual options for a year-style calendar heatmap.
public struct LivelineCalendarHeatmapStyle {
    public var calendar: Calendar
    public var cellSpacing: CGFloat
    public var cornerRadius: CGFloat
    public var emptyOpacity: Double
    public var showsMonthLabels: Bool
    public var showsWeekdayLabels: Bool
    public var colorScale: [Color]

    public init(
        calendar: Calendar = .current,
        cellSpacing: CGFloat = 3,
        cornerRadius: CGFloat = 2,
        emptyOpacity: Double = 0.08,
        showsMonthLabels: Bool = true,
        showsWeekdayLabels: Bool = true,
        colorScale: [Color] = []
    ) {
        self.calendar = calendar
        self.cellSpacing = cellSpacing
        self.cornerRadius = cornerRadius
        self.emptyOpacity = emptyOpacity
        self.showsMonthLabels = showsMonthLabels
        self.showsWeekdayLabels = showsWeekdayLabels
        self.colorScale = colorScale
    }

    var resolvedCellSpacing: CGFloat { cellSpacing.livelineClamped(0, 8, fallback: 3) }
    var resolvedCornerRadius: CGFloat { cornerRadius.livelineAtLeast(0, fallback: 2) }
    var resolvedEmptyOpacity: Double { emptyOpacity.livelineClamped(0, 1, fallback: 0.08) }
}

/// A scheduled task with optional completion and dependency information.
public struct LivelineGanttTask: Identifiable, Hashable, Sendable {
    public var id: String
    public var label: String
    public var start: TimeInterval
    public var end: TimeInterval
    public var lane: Int
    public var progress: Double
    public var dependencyIDs: [String]

    public init(
        id: String,
        label: String,
        start: TimeInterval,
        end: TimeInterval,
        lane: Int,
        progress: Double = 0,
        dependencyIDs: [String] = []
    ) {
        let start = start.isFinite ? start : 0
        let end = end.isFinite ? end : start
        self.id = id
        self.label = label
        self.start = min(start, end)
        self.end = max(start, end)
        self.lane = min(max(lane, 0), 10_000)
        self.progress = progress.livelineClamped(0, 1, fallback: 0)
        self.dependencyIDs = dependencyIDs
    }
}

/// Visual options for Gantt charts.
public struct LivelineGanttStyle {
    public var rowSpacing: CGFloat
    public var cornerRadius: CGFloat
    public var showsLabels: Bool
    public var showsProgress: Bool
    public var showsDependencies: Bool
    public var colors: [Color]

    public init(
        rowSpacing: CGFloat = 6,
        cornerRadius: CGFloat = 4,
        showsLabels: Bool = true,
        showsProgress: Bool = true,
        showsDependencies: Bool = true,
        colors: [Color] = []
    ) {
        self.rowSpacing = rowSpacing
        self.cornerRadius = cornerRadius
        self.showsLabels = showsLabels
        self.showsProgress = showsProgress
        self.showsDependencies = showsDependencies
        self.colors = colors
    }

    var resolvedRowSpacing: CGFloat { rowSpacing.livelineClamped(0, 20, fallback: 6) }
    var resolvedCornerRadius: CGFloat { cornerRadius.livelineAtLeast(0, fallback: 4) }
}

/// One rank observation for a bump chart.
public struct LivelineRankPoint: Identifiable, Hashable, Sendable {
    public var time: TimeInterval
    public var rank: Double

    public var id: TimeInterval { time }

    public init(time: TimeInterval, rank: Double) {
        self.time = time.isFinite ? time : 0
        self.rank = rank.isFinite ? rank : 0
    }
}

/// A named rank series.
public struct LivelineRankSeries: Identifiable, Hashable, Sendable {
    public var id: String
    public var label: String
    public var points: [LivelineRankPoint]

    public init(id: String, label: String, points: [LivelineRankPoint]) {
        self.id = id
        self.label = label
        self.points = points.sorted { $0.time < $1.time }
    }
}

/// Visual options for rank-over-time bump charts.
public struct LivelineBumpStyle {
    public var lowerRankIsBetter: Bool
    public var lineWidth: CGFloat
    public var pointSize: CGFloat
    public var showsPoints: Bool
    public var showsEndLabels: Bool
    public var colors: [Color]

    public init(
        lowerRankIsBetter: Bool = true,
        lineWidth: CGFloat = 2.5,
        pointSize: CGFloat = 6,
        showsPoints: Bool = true,
        showsEndLabels: Bool = true,
        colors: [Color] = []
    ) {
        self.lowerRankIsBetter = lowerRankIsBetter
        self.lineWidth = lineWidth
        self.pointSize = pointSize
        self.showsPoints = showsPoints
        self.showsEndLabels = showsEndLabels
        self.colors = colors
    }

    var resolvedLineWidth: CGFloat { lineWidth.livelineAtLeast(0.5, fallback: 2.5) }
    var resolvedPointSize: CGFloat { pointSize.livelineAtLeast(2, fallback: 6) }
}

/// Visual options for compact horizon charts.
public struct LivelineHorizonStyle {
    public var bandCount: Int
    public var positiveColor: Color?
    public var negativeColor: Color
    public var lineWidth: CGFloat
    public var showsBaseline: Bool

    public init(
        bandCount: Int = 3,
        positiveColor: Color? = nil,
        negativeColor: Color = Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255),
        lineWidth: CGFloat = 1,
        showsBaseline: Bool = true
    ) {
        self.bandCount = bandCount
        self.positiveColor = positiveColor
        self.negativeColor = negativeColor
        self.lineWidth = lineWidth
        self.showsBaseline = showsBaseline
    }

    var resolvedBandCount: Int { min(max(bandCount, 1), 6) }
    var resolvedLineWidth: CGFloat { lineWidth.livelineAtLeast(0, fallback: 1) }
}

// MARK: - Relationship and multivariate charts

/// A weighted directional relationship between two categories.
public struct LivelineChordLink: Identifiable, Hashable, Sendable {
    public var source: String
    public var target: String
    public var value: Double

    public var id: String { "\(source)→\(target)" }

    public init(source: String, target: String, value: Double) {
        self.source = source
        self.target = target
        self.value = value.isFinite ? max(value, 0) : 0
    }
}

/// Visual options for chord diagrams.
public struct LivelineChordStyle {
    public var innerRadiusRatio: CGFloat
    public var gapDegrees: Double
    public var ribbonOpacity: Double
    public var showsLabels: Bool
    public var colors: [Color]

    public init(
        innerRadiusRatio: CGFloat = 0.72,
        gapDegrees: Double = 2,
        ribbonOpacity: Double = 0.34,
        showsLabels: Bool = true,
        colors: [Color] = []
    ) {
        self.innerRadiusRatio = innerRadiusRatio
        self.gapDegrees = gapDegrees
        self.ribbonOpacity = ribbonOpacity
        self.showsLabels = showsLabels
        self.colors = colors
    }

    var resolvedInnerRadiusRatio: CGFloat {
        innerRadiusRatio.livelineClamped(0.42, 0.9, fallback: 0.72)
    }
    var resolvedGapDegrees: Double { gapDegrees.livelineClamped(0, 12, fallback: 2) }
    var resolvedRibbonOpacity: Double { ribbonOpacity.livelineClamped(0, 1, fallback: 0.34) }
}

/// One observation across several quantitative axes.
public struct LivelineParallelRecord: Identifiable, Hashable, Sendable {
    public var id: String
    public var label: String
    public var values: [Double]

    public init(id: String, label: String, values: [Double]) {
        self.id = id
        self.label = label
        self.values = values.map { $0.isFinite ? $0 : 0 }
    }
}

/// Visual options for parallel-coordinate charts.
public struct LivelineParallelCoordinatesStyle {
    public var axisLabels: [String]
    public var lineWidth: CGFloat
    public var lineOpacity: Double
    public var showsPoints: Bool
    public var colors: [Color]

    public init(
        axisLabels: [String] = [],
        lineWidth: CGFloat = 1.5,
        lineOpacity: Double = 0.62,
        showsPoints: Bool = true,
        colors: [Color] = []
    ) {
        self.axisLabels = axisLabels
        self.lineWidth = lineWidth
        self.lineOpacity = lineOpacity
        self.showsPoints = showsPoints
        self.colors = colors
    }

    var resolvedLineWidth: CGFloat { lineWidth.livelineAtLeast(0.5, fallback: 1.5) }
    var resolvedLineOpacity: Double { lineOpacity.livelineClamped(0, 1, fallback: 0.62) }
}

/// A point in a two-dimensional numeric domain.
public struct LivelineXYPoint: Identifiable, Hashable, Sendable {
    public var id: String
    public var x: Double
    public var y: Double
    public var weight: Double
    public var label: String?

    public init(id: String, x: Double, y: Double, weight: Double = 1, label: String? = nil) {
        self.id = id
        self.x = x.isFinite ? x : 0
        self.y = y.isFinite ? y : 0
        self.weight = weight.isFinite ? max(weight, 0) : 0
        self.label = label
    }
}

/// Visual options for density-preserving hexagonal bins.
public struct LivelineHexbinStyle {
    public var binsAcross: Int
    public var minimumOpacity: Double
    public var maximumOpacity: Double
    public var showsCounts: Bool

    public init(
        binsAcross: Int = 18,
        minimumOpacity: Double = 0.12,
        maximumOpacity: Double = 0.9,
        showsCounts: Bool = false
    ) {
        self.binsAcross = binsAcross
        self.minimumOpacity = minimumOpacity
        self.maximumOpacity = maximumOpacity
        self.showsCounts = showsCounts
    }

    var resolvedBinsAcross: Int { min(max(binsAcross, 4), 80) }
    var resolvedMinimumOpacity: Double { minimumOpacity.livelineClamped(0, 1, fallback: 0.12) }
    var resolvedMaximumOpacity: Double {
        maximumOpacity.livelineClamped(resolvedMinimumOpacity, 1, fallback: 0.9)
    }
}

/// A proportional Marimekko column containing categorical segments.
public struct LivelineMarimekkoColumn: Identifiable, Hashable, Sendable {
    public var id: String
    public var label: String
    public var width: Double
    public var segments: [LivelineCategoryValue]

    public init(id: String, label: String, width: Double, segments: [LivelineCategoryValue]) {
        self.id = id
        self.label = label
        self.width = width.isFinite ? max(width, 0) : 0
        self.segments = segments
    }
}

/// Visual options for Marimekko charts.
public struct LivelineMarimekkoStyle {
    public var columnSpacing: CGFloat
    public var segmentSpacing: CGFloat
    public var showsLabels: Bool
    public var showsValues: Bool
    public var colors: [Color]

    public init(
        columnSpacing: CGFloat = 1,
        segmentSpacing: CGFloat = 1,
        showsLabels: Bool = true,
        showsValues: Bool = false,
        colors: [Color] = []
    ) {
        self.columnSpacing = columnSpacing
        self.segmentSpacing = segmentSpacing
        self.showsLabels = showsLabels
        self.showsValues = showsValues
        self.colors = colors
    }

    var resolvedColumnSpacing: CGFloat { columnSpacing.livelineClamped(0, 16, fallback: 1) }
    var resolvedSegmentSpacing: CGFloat { segmentSpacing.livelineClamped(0, 8, fallback: 1) }
}

/// Visual options for polar-area (rose) charts.
public struct LivelinePolarAreaStyle {
    public var innerRadiusRatio: CGFloat
    public var gapDegrees: Double
    public var fillOpacity: Double
    public var showsLabels: Bool
    public var colors: [Color]

    public init(
        innerRadiusRatio: CGFloat = 0,
        gapDegrees: Double = 2,
        fillOpacity: Double = 0.78,
        showsLabels: Bool = true,
        colors: [Color] = []
    ) {
        self.innerRadiusRatio = innerRadiusRatio
        self.gapDegrees = gapDegrees
        self.fillOpacity = fillOpacity
        self.showsLabels = showsLabels
        self.colors = colors
    }

    var resolvedInnerRadiusRatio: CGFloat { innerRadiusRatio.livelineClamped(0, 0.75, fallback: 0) }
    var resolvedGapDegrees: Double { gapDegrees.livelineClamped(0, 15, fallback: 2) }
    var resolvedFillOpacity: Double { fillOpacity.livelineClamped(0, 1, fallback: 0.78) }
}

/// A node in a relationship graph.
public struct LivelineNetworkNode: Identifiable, Hashable, Sendable {
    public var id: String
    public var label: String
    public var weight: Double
    public var group: String?

    public init(id: String, label: String, weight: Double = 1, group: String? = nil) {
        self.id = id
        self.label = label
        self.weight = weight.isFinite ? max(weight, 0) : 0
        self.group = group
    }
}

/// A weighted edge between graph nodes.
public struct LivelineNetworkEdge: Identifiable, Hashable, Sendable {
    public var source: String
    public var target: String
    public var value: Double

    public var id: String { "\(source)→\(target)" }

    public init(source: String, target: String, value: Double = 1) {
        self.source = source
        self.target = target
        self.value = value.isFinite ? max(value, 0) : 0
    }
}

/// Deterministic placement strategies for network graphs.
public enum LivelineNetworkLayout: String, CaseIterable, Sendable {
    case radial
    case grid
}

/// Visual options for network graphs.
public struct LivelineNetworkStyle {
    public var layout: LivelineNetworkLayout
    public var minimumNodeSize: CGFloat
    public var maximumNodeSize: CGFloat
    public var edgeOpacity: Double
    public var showsLabels: Bool
    public var colors: [Color]

    public init(
        layout: LivelineNetworkLayout = .radial,
        minimumNodeSize: CGFloat = 8,
        maximumNodeSize: CGFloat = 22,
        edgeOpacity: Double = 0.28,
        showsLabels: Bool = true,
        colors: [Color] = []
    ) {
        self.layout = layout
        self.minimumNodeSize = minimumNodeSize
        self.maximumNodeSize = maximumNodeSize
        self.edgeOpacity = edgeOpacity
        self.showsLabels = showsLabels
        self.colors = colors
    }

    var resolvedMinimumNodeSize: CGFloat { minimumNodeSize.livelineAtLeast(4, fallback: 8) }
    var resolvedMaximumNodeSize: CGFloat {
        max(maximumNodeSize.livelineAtLeast(4, fallback: 22), resolvedMinimumNodeSize)
    }
    var resolvedEdgeOpacity: Double { edgeOpacity.livelineClamped(0, 1, fallback: 0.28) }
}

/// A sample in a scalar field used to derive contour bands.
public struct LivelineContourSample: Identifiable, Hashable, Sendable {
    public var id: String
    public var x: Double
    public var y: Double
    public var value: Double

    public init(id: String, x: Double, y: Double, value: Double) {
        self.id = id
        self.x = x.isFinite ? x : 0
        self.y = y.isFinite ? y : 0
        self.value = value.isFinite ? value : 0
    }
}

/// Visual options for contour plots.
public struct LivelineContourStyle {
    public var levelCount: Int
    public var lineWidth: CGFloat
    public var fillOpacity: Double
    public var showsFill: Bool
    public var showsLevelLabels: Bool
    public var colors: [Color]

    public init(
        levelCount: Int = 7,
        lineWidth: CGFloat = 1,
        fillOpacity: Double = 0.18,
        showsFill: Bool = true,
        showsLevelLabels: Bool = false,
        colors: [Color] = []
    ) {
        self.levelCount = levelCount
        self.lineWidth = lineWidth
        self.fillOpacity = fillOpacity
        self.showsFill = showsFill
        self.showsLevelLabels = showsLevelLabels
        self.colors = colors
    }

    var resolvedLevelCount: Int { min(max(levelCount, 2), 16) }
    var resolvedLineWidth: CGFloat { lineWidth.livelineAtLeast(0.5, fallback: 1) }
    var resolvedFillOpacity: Double { fillOpacity.livelineClamped(0, 1, fallback: 0.18) }
}

/// A composition of three non-negative components.
public struct LivelineTernaryPoint: Identifiable, Hashable, Sendable {
    public var id: String
    public var label: String
    public var a: Double
    public var b: Double
    public var c: Double
    public var magnitude: Double

    public init(id: String, label: String, a: Double, b: Double, c: Double, magnitude: Double = 1) {
        self.id = id
        self.label = label
        self.a = a.isFinite ? max(a, 0) : 0
        self.b = b.isFinite ? max(b, 0) : 0
        self.c = c.isFinite ? max(c, 0) : 0
        self.magnitude = magnitude.isFinite ? max(magnitude, 0) : 0
    }

    var total: Double {
        let safeA = a.isFinite ? max(a, 0) : 0
        let safeB = b.isFinite ? max(b, 0) : 0
        let safeC = c.isFinite ? max(c, 0) : 0
        let sum = safeA + safeB + safeC
        return sum.isFinite ? sum : Double.greatestFiniteMagnitude
    }

    var proportions: (a: Double, b: Double, c: Double) {
        let safeA = a.isFinite ? max(a, 0) : 0
        let safeB = b.isFinite ? max(b, 0) : 0
        let safeC = c.isFinite ? max(c, 0) : 0
        let scale = max(safeA, safeB, safeC)
        guard scale > 0 else { return (0, 0, 0) }
        let scaledA = safeA / scale
        let scaledB = safeB / scale
        let scaledC = safeC / scale
        let scaledTotal = scaledA + scaledB + scaledC
        return (scaledA / scaledTotal, scaledB / scaledTotal, scaledC / scaledTotal)
    }
}

/// Visual options for ternary plots.
public struct LivelineTernaryStyle {
    public var axisLabels: [String]
    public var pointSizeRange: ClosedRange<CGFloat>
    public var showsGrid: Bool
    public var showsLabels: Bool
    public var colors: [Color]

    public init(
        axisLabels: [String] = ["A", "B", "C"],
        pointSizeRange: ClosedRange<CGFloat> = 6...14,
        showsGrid: Bool = true,
        showsLabels: Bool = true,
        colors: [Color] = []
    ) {
        self.axisLabels = axisLabels
        self.pointSizeRange = pointSizeRange
        self.showsGrid = showsGrid
        self.showsLabels = showsLabels
        self.colors = colors
    }

    var resolvedPointSizeRange: ClosedRange<CGFloat> {
        let lower = pointSizeRange.lowerBound.livelineAtLeast(2, fallback: 6)
        return lower...max(pointSizeRange.upperBound.livelineAtLeast(2, fallback: 14), lower)
    }
}

/// Visual options for percentage waffle charts.
public struct LivelineWaffleStyle {
    public var columns: Int
    public var rows: Int
    public var spacing: CGFloat
    public var cornerRadius: CGFloat
    public var showsLegend: Bool
    public var colors: [Color]

    public init(
        columns: Int = 10,
        rows: Int = 10,
        spacing: CGFloat = 3,
        cornerRadius: CGFloat = 2,
        showsLegend: Bool = true,
        colors: [Color] = []
    ) {
        self.columns = columns
        self.rows = rows
        self.spacing = spacing
        self.cornerRadius = cornerRadius
        self.showsLegend = showsLegend
        self.colors = colors
    }

    var resolvedColumns: Int { min(max(columns, 1), 40) }
    var resolvedRows: Int { min(max(rows, 1), 40) }
    var resolvedSpacing: CGFloat { spacing.livelineClamped(0, 10, fallback: 3) }
    var resolvedCornerRadius: CGFloat { cornerRadius.livelineAtLeast(0, fallback: 2) }
}
