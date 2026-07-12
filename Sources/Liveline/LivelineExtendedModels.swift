import Foundation
import SwiftUI

/// A central estimate with lower and upper uncertainty bounds at one point in time.
public struct LivelineErrorBarPoint: Identifiable, Hashable, Sendable {
    public var time: TimeInterval
    public var value: Double
    public var lower: Double
    public var upper: Double

    public var id: TimeInterval { time }

    public init(time: TimeInterval, value: Double, lower: Double, upper: Double) {
        let resolvedLower = min(lower, upper)
        let resolvedUpper = max(lower, upper)
        self.time = time
        self.value = min(max(value, resolvedLower), resolvedUpper)
        self.lower = resolvedLower
        self.upper = resolvedUpper
    }
}

/// Visual options for an error-bar chart.
public struct LivelineErrorBarStyle {
    public var capWidth: CGFloat
    public var lineWidth: CGFloat
    public var pointSize: CGFloat
    public var pointSymbol: LivelineScatterSymbol
    public var fillOpacity: Double

    public init(
        capWidth: CGFloat = 10,
        lineWidth: CGFloat = 1.5,
        pointSize: CGFloat = 7,
        pointSymbol: LivelineScatterSymbol = .circle,
        fillOpacity: Double = 1
    ) {
        self.capWidth = capWidth
        self.lineWidth = lineWidth
        self.pointSize = pointSize
        self.pointSymbol = pointSymbol
        self.fillOpacity = fillOpacity
    }

    var resolvedCapWidth: CGFloat { capWidth.livelineAtLeast(1, fallback: 10) }
    var resolvedLineWidth: CGFloat { lineWidth.livelineAtLeast(0, fallback: 1.5) }
    var resolvedPointSize: CGFloat { pointSize.livelineAtLeast(2, fallback: 7) }
    var resolvedFillOpacity: Double { fillOpacity.livelineClamped(0, 1, fallback: 1) }
}

/// A paired comparison observed at one point in time.
public struct LivelineDumbbellPoint: Identifiable, Hashable, Sendable {
    public var time: TimeInterval
    public var start: Double
    public var end: Double

    public var id: TimeInterval { time }

    public init(time: TimeInterval, start: Double, end: Double) {
        self.time = time
        self.start = start
        self.end = end
    }
}

/// Visual options for a dumbbell chart.
public struct LivelineDumbbellStyle {
    public var lineWidth: CGFloat
    public var pointSize: CGFloat
    public var pointSymbol: LivelineScatterSymbol
    public var startColor: Color?
    public var endColor: Color?
    public var showsDirection: Bool

    public init(
        lineWidth: CGFloat = 2,
        pointSize: CGFloat = 9,
        pointSymbol: LivelineScatterSymbol = .circle,
        startColor: Color? = nil,
        endColor: Color? = nil,
        showsDirection: Bool = false
    ) {
        self.lineWidth = lineWidth
        self.pointSize = pointSize
        self.pointSymbol = pointSymbol
        self.startColor = startColor
        self.endColor = endColor
        self.showsDirection = showsDirection
    }

    var resolvedLineWidth: CGFloat { lineWidth.livelineAtLeast(0, fallback: 2) }
    var resolvedPointSize: CGFloat { pointSize.livelineAtLeast(2, fallback: 9) }
}

/// Multiple segment values observed at one point in time.
public struct LivelineStackedPoint: Identifiable, Hashable, Sendable {
    public var time: TimeInterval
    public var values: [Double]

    public var id: TimeInterval { time }
    public var total: Double { values.reduce(0, +) }

    public init(time: TimeInterval, values: [Double]) {
        self.time = time
        self.values = values.map { $0.isFinite ? $0 : 0 }
    }
}

/// Controls whether stacked values retain their magnitude or normalize to a percentage.
public enum LivelineStackMode: String, CaseIterable, Sendable {
    case standard
    case normalized
}

/// Visual options for a stacked-bar chart.
public struct LivelineStackedBarStyle {
    public var mode: LivelineStackMode
    public var widthRatio: CGFloat
    public var cornerRadius: CGFloat
    public var segmentSpacing: CGFloat
    public var colors: [Color]
    public var showsBaseline: Bool

    public init(
        mode: LivelineStackMode = .standard,
        widthRatio: CGFloat = 0.72,
        cornerRadius: CGFloat = 2,
        segmentSpacing: CGFloat = 1,
        colors: [Color] = [],
        showsBaseline: Bool = true
    ) {
        self.mode = mode
        self.widthRatio = widthRatio
        self.cornerRadius = cornerRadius
        self.segmentSpacing = segmentSpacing
        self.colors = colors
        self.showsBaseline = showsBaseline
    }

    var resolvedWidthRatio: CGFloat { widthRatio.livelineClamped(0.05, 1, fallback: 0.72) }
    var resolvedCornerRadius: CGFloat { cornerRadius.livelineAtLeast(0, fallback: 2) }
    var resolvedSegmentSpacing: CGFloat { segmentSpacing.livelineAtLeast(0, fallback: 1) }
}

/// Visual options for a stacked-area chart.
public struct LivelineStackedAreaStyle {
    public var mode: LivelineStackMode
    public var colors: [Color]
    public var fillOpacity: Double
    public var boundaryLineWidth: CGFloat
    public var showsBaseline: Bool

    public init(
        mode: LivelineStackMode = .standard,
        colors: [Color] = [],
        fillOpacity: Double = 0.62,
        boundaryLineWidth: CGFloat = 1,
        showsBaseline: Bool = true
    ) {
        self.mode = mode
        self.colors = colors
        self.fillOpacity = fillOpacity
        self.boundaryLineWidth = boundaryLineWidth
        self.showsBaseline = showsBaseline
    }

    var resolvedFillOpacity: Double { fillOpacity.livelineClamped(0, 1, fallback: 0.62) }
    var resolvedBoundaryLineWidth: CGFloat { boundaryLineWidth.livelineAtLeast(0, fallback: 1) }
}

/// A labeled time interval assigned to a zero-based lane.
public struct LivelineTimelineItem: Identifiable, Hashable, Sendable {
    public var id: String
    public var label: String
    public var start: TimeInterval
    public var end: TimeInterval
    public var lane: Int

    public init(id: String, label: String, start: TimeInterval, end: TimeInterval, lane: Int) {
        self.id = id
        self.label = label
        self.start = min(start, end)
        self.end = max(start, end)
        self.lane = max(lane, 0)
    }
}

/// Visual options for a timeline chart.
public struct LivelineTimelineStyle {
    public var barHeightRatio: CGFloat
    public var cornerRadius: CGFloat
    public var colors: [Color]
    public var showsLabels: Bool
    public var showsLaneGuides: Bool

    public init(
        barHeightRatio: CGFloat = 0.62,
        cornerRadius: CGFloat = 5,
        colors: [Color] = [],
        showsLabels: Bool = true,
        showsLaneGuides: Bool = true
    ) {
        self.barHeightRatio = barHeightRatio
        self.cornerRadius = cornerRadius
        self.colors = colors
        self.showsLabels = showsLabels
        self.showsLaneGuides = showsLaneGuides
    }

    var resolvedBarHeightRatio: CGFloat { barHeightRatio.livelineClamped(0.08, 1, fallback: 0.62) }
    var resolvedCornerRadius: CGFloat { cornerRadius.livelineAtLeast(0, fallback: 5) }
}

/// A heatmap cell observed at a point in time and a zero-based row.
public struct LivelineHeatmapCell: Identifiable, Hashable, Sendable {
    public var time: TimeInterval
    public var row: Int
    public var value: Double

    public var id: String { "\(time)-\(row)" }

    public init(time: TimeInterval, row: Int, value: Double) {
        self.time = time
        self.row = max(row, 0)
        self.value = value.isFinite ? value : 0
    }
}

/// Visual options for a time-row heatmap.
public struct LivelineHeatmapStyle {
    public var rowLabels: [String]
    public var color: Color?
    public var minimumOpacity: Double
    public var maximumOpacity: Double
    public var cellWidthRatio: CGFloat
    public var cellHeightRatio: CGFloat
    public var cornerRadius: CGFloat
    public var showsValues: Bool

    public init(
        rowLabels: [String] = [],
        color: Color? = nil,
        minimumOpacity: Double = 0.10,
        maximumOpacity: Double = 0.95,
        cellWidthRatio: CGFloat = 0.90,
        cellHeightRatio: CGFloat = 0.82,
        cornerRadius: CGFloat = 2,
        showsValues: Bool = false
    ) {
        self.rowLabels = rowLabels
        self.color = color
        self.minimumOpacity = minimumOpacity
        self.maximumOpacity = maximumOpacity
        self.cellWidthRatio = cellWidthRatio
        self.cellHeightRatio = cellHeightRatio
        self.cornerRadius = cornerRadius
        self.showsValues = showsValues
    }

    var resolvedMinimumOpacity: Double { minimumOpacity.livelineClamped(0, 1, fallback: 0.10) }
    var resolvedMaximumOpacity: Double { maximumOpacity.livelineClamped(resolvedMinimumOpacity, 1, fallback: 0.95) }
    var resolvedCellWidthRatio: CGFloat { cellWidthRatio.livelineClamped(0.05, 1, fallback: 0.90) }
    var resolvedCellHeightRatio: CGFloat { cellHeightRatio.livelineClamped(0.05, 1, fallback: 0.82) }
    var resolvedCornerRadius: CGFloat { cornerRadius.livelineAtLeast(0, fallback: 2) }
}

/// One labeled axis in a radar chart.
public struct LivelineRadarPoint: Identifiable, Hashable, Sendable {
    public var label: String
    public var value: Double

    public var id: String { label }

    public init(label: String, value: Double) {
        self.label = label
        self.value = value.isFinite ? value : 0
    }
}

/// Visual options for a radar chart.
public struct LivelineRadarStyle {
    public var range: ClosedRange<Double>
    public var gridLevels: Int
    public var fillOpacity: Double
    public var lineWidth: CGFloat
    public var pointSize: CGFloat
    public var showsLabels: Bool

    public init(
        range: ClosedRange<Double> = 0...1,
        gridLevels: Int = 4,
        fillOpacity: Double = 0.18,
        lineWidth: CGFloat = 2,
        pointSize: CGFloat = 5,
        showsLabels: Bool = true
    ) {
        self.range = range.lowerBound == range.upperBound
            ? (range.lowerBound - 0.5)...(range.upperBound + 0.5)
            : min(range.lowerBound, range.upperBound)...max(range.lowerBound, range.upperBound)
        self.gridLevels = gridLevels
        self.fillOpacity = fillOpacity
        self.lineWidth = lineWidth
        self.pointSize = pointSize
        self.showsLabels = showsLabels
    }

    var resolvedGridLevels: Int { min(max(gridLevels, 1), 10) }
    var resolvedFillOpacity: Double { fillOpacity.livelineClamped(0, 1, fallback: 0.18) }
    var resolvedLineWidth: CGFloat { lineWidth.livelineAtLeast(0, fallback: 2) }
    var resolvedPointSize: CGFloat { pointSize.livelineAtLeast(0, fallback: 5) }
    var resolvedRange: ClosedRange<Double> {
        LivelineScalar.nondegenerateRange(
            lower: range.lowerBound,
            upper: range.upperBound,
            fallback: 0...1
        )
    }
}

/// A labeled non-negative value used by composition and stage charts.
public struct LivelineCategoryValue: Identifiable, Hashable, Sendable {
    public var id: String
    public var label: String
    public var value: Double

    public init(id: String, label: String, value: Double) {
        self.id = id
        self.label = label
        self.value = value.isFinite ? max(value, 0) : 0
    }
}

/// Visual options for a donut chart.
public struct LivelineDonutStyle {
    public var innerRadiusRatio: CGFloat
    public var gapDegrees: Double
    public var colors: [Color]
    public var showsLabels: Bool
    public var showsValues: Bool

    public init(
        innerRadiusRatio: CGFloat = 0.58,
        gapDegrees: Double = 2,
        colors: [Color] = [],
        showsLabels: Bool = true,
        showsValues: Bool = false
    ) {
        self.innerRadiusRatio = innerRadiusRatio
        self.gapDegrees = gapDegrees
        self.colors = colors
        self.showsLabels = showsLabels
        self.showsValues = showsValues
    }

    var resolvedInnerRadiusRatio: CGFloat { innerRadiusRatio.livelineClamped(0, 0.92, fallback: 0.58) }
    var resolvedGapDegrees: Double { gapDegrees.livelineClamped(0, 20, fallback: 2) }
}

/// Visual options for a radial gauge.
public struct LivelineGaugeStyle {
    public var startAngleDegrees: Double
    public var sweepDegrees: Double
    public var lineWidth: CGFloat
    public var trackOpacity: Double
    public var progressColor: Color?
    public var target: Double?
    public var targetColor: Color?
    public var showsTicks: Bool
    public var tickCount: Int
    public var showsValue: Bool

    public init(
        startAngleDegrees: Double = 150,
        sweepDegrees: Double = 240,
        lineWidth: CGFloat = 18,
        trackOpacity: Double = 0.12,
        progressColor: Color? = nil,
        target: Double? = nil,
        targetColor: Color? = nil,
        showsTicks: Bool = true,
        tickCount: Int = 9,
        showsValue: Bool = true
    ) {
        self.startAngleDegrees = startAngleDegrees.isFinite ? startAngleDegrees : 150
        self.sweepDegrees = sweepDegrees.isFinite ? sweepDegrees : 240
        self.lineWidth = lineWidth.isFinite ? lineWidth : 18
        self.trackOpacity = trackOpacity.isFinite ? trackOpacity : 0.12
        self.progressColor = progressColor
        self.target = target.flatMap { $0.isFinite ? $0 : nil }
        self.targetColor = targetColor
        self.showsTicks = showsTicks
        self.tickCount = tickCount
        self.showsValue = showsValue
    }

    var resolvedStartAngleDegrees: Double {
        (startAngleDegrees.isFinite ? startAngleDegrees : 150)
            .truncatingRemainder(dividingBy: 360)
    }
    var resolvedSweepDegrees: Double { abs(sweepDegrees.livelineFinite(or: 240)).livelineClamped(1, 359.5, fallback: 240) }
    var resolvedLineWidth: CGFloat { lineWidth.livelineAtLeast(1, fallback: 18) }
    var resolvedTrackOpacity: Double { trackOpacity.livelineClamped(0, 1, fallback: 0.12) }
    var resolvedTickCount: Int { min(max(tickCount, 2), 25) }
    var resolvedTarget: Double? { target.flatMap { $0.isFinite ? LivelineScalar.value($0) : nil } }
}

/// Visual options for a funnel chart.
public struct LivelineFunnelStyle {
    public var maximumWidthRatio: CGFloat
    public var minimumWidthRatio: CGFloat
    public var spacing: CGFloat
    public var cornerRadius: CGFloat
    public var colors: [Color]
    public var showsLabels: Bool
    public var showsValues: Bool

    public init(
        maximumWidthRatio: CGFloat = 0.88,
        minimumWidthRatio: CGFloat = 0.18,
        spacing: CGFloat = 4,
        cornerRadius: CGFloat = 4,
        colors: [Color] = [],
        showsLabels: Bool = true,
        showsValues: Bool = true
    ) {
        self.maximumWidthRatio = maximumWidthRatio
        self.minimumWidthRatio = minimumWidthRatio
        self.spacing = spacing
        self.cornerRadius = cornerRadius
        self.colors = colors
        self.showsLabels = showsLabels
        self.showsValues = showsValues
    }

    var resolvedMaximumWidthRatio: CGFloat { maximumWidthRatio.livelineClamped(0.1, 1, fallback: 0.88) }
    var resolvedMinimumWidthRatio: CGFloat { minimumWidthRatio.livelineClamped(0.02, resolvedMaximumWidthRatio, fallback: 0.18) }
    var resolvedSpacing: CGFloat { spacing.livelineAtLeast(0, fallback: 4) }
    var resolvedCornerRadius: CGFloat { cornerRadius.livelineAtLeast(0, fallback: 4) }
}
