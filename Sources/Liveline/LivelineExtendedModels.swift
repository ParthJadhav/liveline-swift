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

/// Where a stack is anchored on the value axis.
///
/// `.zero` stacks upwards from the value axis' zero line. `.centered` offsets
/// every stack by half its own height so the layers ripple around a shared
/// middle — the streamgraph presentation. Absolute values stop being readable
/// in that mode, so a centered chart draws no value axis.
public enum LivelineStackBaseline: String, CaseIterable, Sendable {
    case zero
    case centered
}

/// Visual options for a stacked-area chart.
public struct LivelineStackedAreaStyle {
    public var mode: LivelineStackMode
    /// Anchoring of the stack on the value axis. Defaults to `.zero`; use
    /// `.centered` for a streamgraph.
    public var baseline: LivelineStackBaseline
    public var colors: [Color]
    public var fillOpacity: Double
    public var boundaryLineWidth: CGFloat
    public var showsBaseline: Bool

    public init(
        mode: LivelineStackMode = .standard,
        baseline: LivelineStackBaseline = .zero,
        colors: [Color] = [],
        fillOpacity: Double = 0.62,
        boundaryLineWidth: CGFloat = 1,
        showsBaseline: Bool = true
    ) {
        self.mode = mode
        self.baseline = baseline
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

/// How a histogram decides how many bins to split its samples into.
public enum LivelineHistogramBinning: Hashable, Sendable {
    /// Freedman–Diaconis, which adapts the bin width to the interquartile
    /// range, falling back to Sturges when the samples have no spread in
    /// their middle half.
    case automatic
    /// `ceil(log2(n)) + 1` bins, the classic Sturges rule.
    case sturges
    /// `2 · IQR · n^(-1/3)` bin width, robust against outliers.
    case freedmanDiaconis
    /// An explicit bin count, clamped to `1...512`.
    case count(Int)

    /// Stable identifier used by the render caches.
    var cacheIdentifier: String {
        switch self {
        case .automatic: return "automatic"
        case .sturges: return "sturges"
        case .freedmanDiaconis: return "freedmanDiaconis"
        case let .count(count): return "count-\(count)"
        }
    }
}

/// One bin of a histogram: a half-open `lowerBound..<upperBound` value interval
/// and the number of samples that fell inside it. The final bin of a histogram
/// is closed so the largest sample is counted.
public struct LivelineHistogramBin: Identifiable, Hashable, Sendable {
    public var lowerBound: Double
    public var upperBound: Double
    public var count: Int

    public var id: Double { lowerBound }

    /// The centre of the bin, used to place labels and hover anchors.
    public var midpoint: Double { (lowerBound + upperBound) / 2 }

    public init(lowerBound: Double, upperBound: Double, count: Int) {
        self.lowerBound = min(lowerBound, upperBound)
        self.upperBound = max(lowerBound, upperBound)
        self.count = max(count, 0)
    }
}

/// Visual options for a histogram.
public struct LivelineHistogramStyle {
    public var binning: LivelineHistogramBinning
    /// Bar fill. Defaults to the chart accent.
    public var color: Color?
    /// Gap between neighbouring bars in points. Histogram bars are contiguous
    /// by convention, so this defaults to a hairline separator.
    public var barSpacing: CGFloat
    public var cornerRadius: CGFloat
    public var fillOpacity: Double
    public var showsBaseline: Bool
    /// Draws the value-range labels beneath the first, middle, and last edge.
    public var showsEdgeLabels: Bool
    /// Draws each bin's count inside its bar when the bar is wide enough.
    public var showsCounts: Bool

    public init(
        binning: LivelineHistogramBinning = .automatic,
        color: Color? = nil,
        barSpacing: CGFloat = 1,
        cornerRadius: CGFloat = 2,
        fillOpacity: Double = 0.9,
        showsBaseline: Bool = true,
        showsEdgeLabels: Bool = true,
        showsCounts: Bool = false
    ) {
        self.binning = binning
        self.color = color
        self.barSpacing = barSpacing
        self.cornerRadius = cornerRadius
        self.fillOpacity = fillOpacity
        self.showsBaseline = showsBaseline
        self.showsEdgeLabels = showsEdgeLabels
        self.showsCounts = showsCounts
    }

    var resolvedBarSpacing: CGFloat { barSpacing.livelineClamped(0, 12, fallback: 1) }
    var resolvedCornerRadius: CGFloat { cornerRadius.livelineAtLeast(0, fallback: 2) }
    var resolvedFillOpacity: Double { fillOpacity.livelineClamped(0, 1, fallback: 0.9) }
}

/// One qualitative band of a bullet chart, running from the previous band's
/// upper bound — or the axis minimum for the first band — up to `value`.
public struct LivelineBulletRange: Identifiable, Equatable {
    /// The band's upper bound on the measure axis.
    public var value: Double
    public var label: String?
    public var color: Color?

    public var id: Double { value }

    public init(value: Double, label: String? = nil, color: Color? = nil) {
        self.value = value.isFinite ? value : 0
        self.label = label
        self.color = color
    }
}

/// Visual options and data for a bullet chart: a compact horizontal KPI with
/// qualitative bands behind a measure bar and a target tick.
public struct LivelineBulletStyle {
    /// The value being reported.
    public var measure: Double
    /// The value being aimed at, drawn as a tick across the bands.
    public var target: Double?
    /// Qualitative bands, ordered from worst to best. Unordered input is sorted
    /// by `value` before it is drawn.
    public var ranges: [LivelineBulletRange]
    /// The measure axis. When `nil` it spans zero (or the smallest supplied
    /// value) through the largest of measure, target, and band bounds.
    public var axisRange: ClosedRange<Double>?
    public var label: String?
    public var barHeightRatio: CGFloat
    public var measureHeightRatio: CGFloat
    public var measureColor: Color?
    public var targetColor: Color?
    public var bandOpacity: Double
    public var cornerRadius: CGFloat
    public var showsValue: Bool

    public init(
        measure: Double,
        target: Double? = nil,
        ranges: [LivelineBulletRange] = [],
        axisRange: ClosedRange<Double>? = nil,
        label: String? = nil,
        barHeightRatio: CGFloat = 0.42,
        measureHeightRatio: CGFloat = 0.38,
        measureColor: Color? = nil,
        targetColor: Color? = nil,
        bandOpacity: Double = 0.28,
        cornerRadius: CGFloat = 3,
        showsValue: Bool = true
    ) {
        self.measure = measure.isFinite ? measure : 0
        self.target = target.flatMap { $0.isFinite ? $0 : nil }
        self.ranges = ranges
        self.axisRange = axisRange
        self.label = label
        self.barHeightRatio = barHeightRatio
        self.measureHeightRatio = measureHeightRatio
        self.measureColor = measureColor
        self.targetColor = targetColor
        self.bandOpacity = bandOpacity
        self.cornerRadius = cornerRadius
        self.showsValue = showsValue
    }

    var resolvedMeasure: Double { LivelineScalar.value(measure) }
    var resolvedTarget: Double? { target.flatMap { $0.isFinite ? LivelineScalar.value($0) : nil } }
    var resolvedBarHeightRatio: CGFloat { barHeightRatio.livelineClamped(0.05, 1, fallback: 0.42) }
    var resolvedMeasureHeightRatio: CGFloat {
        measureHeightRatio.livelineClamped(0.05, resolvedBarHeightRatio, fallback: min(0.38, resolvedBarHeightRatio))
    }
    var resolvedBandOpacity: Double { bandOpacity.livelineClamped(0, 1, fallback: 0.28) }
    var resolvedCornerRadius: CGFloat { cornerRadius.livelineAtLeast(0, fallback: 3) }

    /// Bands ordered worst to best, with non-finite and non-positive-width
    /// entries dropped.
    var resolvedRanges: [LivelineBulletRange] {
        ranges
            .filter { $0.value.isFinite }
            .map { LivelineBulletRange(value: LivelineScalar.value($0.value), label: $0.label, color: $0.color) }
            .sorted { $0.value < $1.value }
    }

    /// The measure axis actually drawn, always non-degenerate.
    var resolvedAxisRange: ClosedRange<Double> {
        if let axisRange {
            return LivelineScalar.nondegenerateRange(
                lower: axisRange.lowerBound,
                upper: axisRange.upperBound,
                fallback: 0...1
            )
        }
        let candidates = [resolvedMeasure] + (resolvedTarget.map { [$0] } ?? []) + resolvedRanges.map(\.value)
        let upper = candidates.max() ?? 1
        let lower = min(candidates.min() ?? 0, 0)
        return LivelineScalar.nondegenerateRange(lower: lower, upper: upper, fallback: 0...1)
    }

    /// The band the measure currently falls in, if any.
    var containingRange: LivelineBulletRange? {
        resolvedRanges.first { resolvedMeasure <= $0.value } ?? resolvedRanges.last
    }
}
