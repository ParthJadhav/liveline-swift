import Foundation
import SwiftUI

/// A time/value pair rendered by a live line chart.
public struct LivelinePoint: Identifiable, Hashable, Sendable {
    public var time: TimeInterval
    public var value: Double

    public var id: TimeInterval { time }

    public init(time: TimeInterval, value: Double) {
        self.time = time
        self.value = value
    }
}

/// A lower and upper value observed at one point in time.
public struct LivelineRangePoint: Identifiable, Hashable, Sendable {
    public var time: TimeInterval
    public var lower: Double
    public var upper: Double

    public var id: TimeInterval { time }
    public var midpoint: Double { (lower + upper) / 2 }

    public init(time: TimeInterval, lower: Double, upper: Double) {
        self.time = time
        self.lower = min(lower, upper)
        self.upper = max(lower, upper)
    }
}

/// Visual options for a time-based bar chart.
public struct LivelineBarStyle {
    /// The fraction of the available time bucket occupied by each bar.
    public var widthRatio: CGFloat
    public var cornerRadius: CGFloat
    public var baseline: Double
    public var positiveColor: Color?
    public var negativeColor: Color
    public var showsBaseline: Bool

    public init(
        widthRatio: CGFloat = 0.72,
        cornerRadius: CGFloat = 2,
        baseline: Double = 0,
        positiveColor: Color? = nil,
        negativeColor: Color = Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255),
        showsBaseline: Bool = true
    ) {
        self.widthRatio = widthRatio
        self.cornerRadius = cornerRadius
        self.baseline = baseline
        self.positiveColor = positiveColor
        self.negativeColor = negativeColor
        self.showsBaseline = showsBaseline
    }

    var resolvedWidthRatio: CGFloat { widthRatio.livelineClamped(0.05, 1, fallback: 0.7) }
    var resolvedCornerRadius: CGFloat { cornerRadius.livelineAtLeast(0, fallback: 2) }
    var resolvedBaseline: Double { LivelineScalar.value(baseline) }
}

/// Visual options for a range-band chart.
public struct LivelineRangeStyle {
    public var fillOpacity: Double
    public var boundaryLineWidth: CGFloat
    public var showsCenterLine: Bool
    public var centerLineWidth: CGFloat

    public init(
        fillOpacity: Double = 0.18,
        boundaryLineWidth: CGFloat = 1.5,
        showsCenterLine: Bool = false,
        centerLineWidth: CGFloat = 1
    ) {
        self.fillOpacity = fillOpacity
        self.boundaryLineWidth = boundaryLineWidth
        self.showsCenterLine = showsCenterLine
        self.centerLineWidth = centerLineWidth
    }

    var resolvedFillOpacity: Double { fillOpacity.livelineClamped(0, 1, fallback: 0.16) }
    var resolvedBoundaryLineWidth: CGFloat { boundaryLineWidth.livelineAtLeast(0, fallback: 1.25) }
    var resolvedCenterLineWidth: CGFloat { centerLineWidth.livelineAtLeast(0, fallback: 1) }
}

public enum LivelineScatterSymbol: String, CaseIterable, Sendable {
    case circle
    case square
    case diamond
}

public enum LivelineScatterConnection: String, CaseIterable, Sendable {
    case none
    case straight
    case curved
}

/// Visual options for a scatter chart.
public struct LivelineScatterStyle {
    public var symbol: LivelineScatterSymbol
    public var pointSize: CGFloat
    public var outlineWidth: CGFloat
    public var connection: LivelineScatterConnection
    public var connectionLineWidth: CGFloat

    public init(
        symbol: LivelineScatterSymbol = .circle,
        pointSize: CGFloat = 7,
        outlineWidth: CGFloat = 1.5,
        connection: LivelineScatterConnection = .none,
        connectionLineWidth: CGFloat = 1.25
    ) {
        self.symbol = symbol
        self.pointSize = pointSize
        self.outlineWidth = outlineWidth
        self.connection = connection
        self.connectionLineWidth = connectionLineWidth
    }

    var resolvedPointSize: CGFloat { pointSize.livelineAtLeast(2, fallback: 7) }
    var resolvedOutlineWidth: CGFloat { outlineWidth.livelineAtLeast(0, fallback: 1.5) }
    var resolvedConnectionLineWidth: CGFloat { connectionLineWidth.livelineAtLeast(0, fallback: 1.5) }
}

/// Where a step transition occurs between two adjacent samples.
public enum LivelineStepPosition: String, CaseIterable, Sendable {
    case leading
    case center
    case trailing
}

/// Visual options for a step chart.
public struct LivelineStepStyle {
    public var position: LivelineStepPosition
    public var lineWidth: CGFloat
    public var fillOpacity: Double

    public init(
        position: LivelineStepPosition = .trailing,
        lineWidth: CGFloat = 2,
        fillOpacity: Double = 0.10
    ) {
        self.position = position
        self.lineWidth = lineWidth
        self.fillOpacity = fillOpacity
    }

    var resolvedLineWidth: CGFloat { lineWidth.livelineAtLeast(0, fallback: 2) }
    var resolvedFillOpacity: Double { fillOpacity.livelineClamped(0, 1, fallback: 0.10) }
}

/// Visual options for a lollipop chart.
public struct LivelineLollipopStyle {
    public var baseline: Double
    public var stemWidth: CGFloat
    public var headSize: CGFloat
    public var headSymbol: LivelineScatterSymbol
    public var outlineWidth: CGFloat
    public var positiveColor: Color?
    public var negativeColor: Color
    public var showsBaseline: Bool

    public init(
        baseline: Double = 0,
        stemWidth: CGFloat = 1.5,
        headSize: CGFloat = 8,
        headSymbol: LivelineScatterSymbol = .circle,
        outlineWidth: CGFloat = 1,
        positiveColor: Color? = nil,
        negativeColor: Color = Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255),
        showsBaseline: Bool = true
    ) {
        self.baseline = baseline
        self.stemWidth = stemWidth
        self.headSize = headSize
        self.headSymbol = headSymbol
        self.outlineWidth = outlineWidth
        self.positiveColor = positiveColor
        self.negativeColor = negativeColor
        self.showsBaseline = showsBaseline
    }

    var resolvedStemWidth: CGFloat { stemWidth.livelineAtLeast(0, fallback: 1.5) }
    var resolvedHeadSize: CGFloat { headSize.livelineAtLeast(2, fallback: 8) }
    var resolvedOutlineWidth: CGFloat { outlineWidth.livelineAtLeast(0, fallback: 1) }
    var resolvedBaseline: Double { LivelineScalar.value(baseline) }
}

/// A time/value observation with a third magnitude dimension.
public struct LivelineBubblePoint: Identifiable, Hashable, Sendable {
    public var time: TimeInterval
    public var value: Double
    public var magnitude: Double

    public var id: TimeInterval { time }

    public init(time: TimeInterval, value: Double, magnitude: Double) {
        self.time = time
        self.value = value
        self.magnitude = max(magnitude, 0)
    }
}

/// Controls whether bubble magnitude maps to visible area or diameter.
public enum LivelineBubbleScale: String, CaseIterable, Sendable {
    case area
    case diameter
}

/// Visual options for a bubble chart.
public struct LivelineBubbleStyle {
    public var minimumSize: CGFloat
    public var maximumSize: CGFloat
    public var fillOpacity: Double
    public var outlineWidth: CGFloat
    public var scale: LivelineBubbleScale

    public init(
        minimumSize: CGFloat = 5,
        maximumSize: CGFloat = 24,
        fillOpacity: Double = 0.30,
        outlineWidth: CGFloat = 1.5,
        scale: LivelineBubbleScale = .area
    ) {
        self.minimumSize = minimumSize
        self.maximumSize = maximumSize
        self.fillOpacity = fillOpacity
        self.outlineWidth = outlineWidth
        self.scale = scale
    }

    var resolvedMinimumSize: CGFloat {
        min(minimumSize.livelineFinite(or: 5), maximumSize.livelineFinite(or: 24))
            .livelineAtLeast(2, fallback: 5)
    }
    var resolvedMaximumSize: CGFloat {
        max(minimumSize.livelineFinite(or: 5), maximumSize.livelineFinite(or: 24))
            .livelineAtLeast(resolvedMinimumSize, fallback: 24)
    }
    var resolvedFillOpacity: Double { fillOpacity.livelineClamped(0, 1, fallback: 0.30) }
    var resolvedOutlineWidth: CGFloat { outlineWidth.livelineAtLeast(0, fallback: 1.5) }
}

/// A five-number statistical summary observed at one point in time.
public struct LivelineBoxPlotPoint: Identifiable, Hashable, Sendable {
    public var time: TimeInterval
    public var minimum: Double
    public var lowerQuartile: Double
    public var median: Double
    public var upperQuartile: Double
    public var maximum: Double

    public var id: TimeInterval { time }

    public init(
        time: TimeInterval,
        minimum: Double,
        lowerQuartile: Double,
        median: Double,
        upperQuartile: Double,
        maximum: Double
    ) {
        let values = [minimum, lowerQuartile, median, upperQuartile, maximum].sorted()
        self.time = time
        self.minimum = values[0]
        self.lowerQuartile = values[1]
        self.median = values[2]
        self.upperQuartile = values[3]
        self.maximum = values[4]
    }
}

/// Visual options for a time-based box plot.
public struct LivelineBoxPlotStyle {
    public var widthRatio: CGFloat
    public var fillOpacity: Double
    public var outlineWidth: CGFloat
    public var medianLineWidth: CGFloat
    public var whiskerWidthRatio: CGFloat

    public init(
        widthRatio: CGFloat = 0.55,
        fillOpacity: Double = 0.16,
        outlineWidth: CGFloat = 1.25,
        medianLineWidth: CGFloat = 2,
        whiskerWidthRatio: CGFloat = 0.55
    ) {
        self.widthRatio = widthRatio
        self.fillOpacity = fillOpacity
        self.outlineWidth = outlineWidth
        self.medianLineWidth = medianLineWidth
        self.whiskerWidthRatio = whiskerWidthRatio
    }

    var resolvedWidthRatio: CGFloat { widthRatio.livelineClamped(0.05, 1, fallback: 0.55) }
    var resolvedFillOpacity: Double { fillOpacity.livelineClamped(0, 1, fallback: 0.16) }
    var resolvedOutlineWidth: CGFloat { outlineWidth.livelineAtLeast(0, fallback: 1.25) }
    var resolvedMedianLineWidth: CGFloat { medianLineWidth.livelineAtLeast(0, fallback: 2) }
    var resolvedWhiskerWidthRatio: CGFloat { whiskerWidthRatio.livelineClamped(0.05, 1, fallback: 0.55) }
}

/// Visual options for a cumulative waterfall chart.
public struct LivelineWaterfallStyle {
    public var initialValue: Double
    public var widthRatio: CGFloat
    public var cornerRadius: CGFloat
    public var connectorLineWidth: CGFloat
    public var positiveColor: Color?
    public var negativeColor: Color
    public var showsConnectors: Bool
    public var showsBaseline: Bool

    public init(
        initialValue: Double = 0,
        widthRatio: CGFloat = 0.62,
        cornerRadius: CGFloat = 2,
        connectorLineWidth: CGFloat = 1,
        positiveColor: Color? = nil,
        negativeColor: Color = Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255),
        showsConnectors: Bool = true,
        showsBaseline: Bool = true
    ) {
        self.initialValue = initialValue
        self.widthRatio = widthRatio
        self.cornerRadius = cornerRadius
        self.connectorLineWidth = connectorLineWidth
        self.positiveColor = positiveColor
        self.negativeColor = negativeColor
        self.showsConnectors = showsConnectors
        self.showsBaseline = showsBaseline
    }

    var resolvedWidthRatio: CGFloat { widthRatio.livelineClamped(0.05, 1, fallback: 0.62) }
    var resolvedCornerRadius: CGFloat { cornerRadius.livelineAtLeast(0, fallback: 2) }
    var resolvedConnectorLineWidth: CGFloat { connectorLineWidth.livelineAtLeast(0, fallback: 1) }
    var resolvedInitialValue: Double { LivelineScalar.value(initialValue) }
}

/// One OHLC candle. `time` is the candle open time in Unix seconds.
public struct LivelineCandle: Identifiable, Hashable, Sendable {
    public var time: TimeInterval
    public var open: Double
    public var high: Double
    public var low: Double
    public var close: Double

    public var id: TimeInterval { time }

    public init(time: TimeInterval, open: Double, high: Double, low: Double, close: Double) {
        self.time = time
        self.open = open
        self.high = high
        self.low = low
        self.close = close
    }
}

/// A line in a multi-series chart.
public struct LivelineSeries: Identifiable {
    public var id: String
    public var data: [LivelinePoint]
    public var value: Double
    public var color: Color
    public var label: String?

    public init(
        id: String,
        data: [LivelinePoint],
        value: Double,
        color: Color,
        label: String? = nil
    ) {
        self.id = id
        self.data = data
        self.value = value
        self.color = color
        self.label = label
    }
}

public enum LivelineThemeMode: String, CaseIterable, Sendable {
    case light
    case dark
}

public enum LivelineMomentum: String, CaseIterable, Sendable {
    case up
    case down
    case flat
}

public enum LivelineChartMode: String, CaseIterable, Sendable {
    case line
    case candle
}

public enum LivelineBadgeVariant: String, CaseIterable, Sendable {
    case `default`
    case minimal
}

public enum LivelineWindowStyle: String, CaseIterable, Sendable {
    case `default`
    case rounded
    case text
}

public enum LivelineLegendSide: String, CaseIterable, Sendable {
    case leading
    case trailing
}

/// A time horizon option shown above the chart.
public struct LivelineWindowOption: Identifiable, Hashable, Sendable {
    public var label: String
    public var seconds: TimeInterval

    public var id: TimeInterval { seconds }

    public init(label: String, seconds: TimeInterval) {
        self.label = label
        self.seconds = seconds
    }
}

public struct LivelineReferenceLine: Hashable, Sendable {
    public var value: Double
    public var label: String?

    public init(value: Double, label: String? = nil) {
        self.value = value
        self.label = label
    }
}

public struct LivelineHoverPoint: Hashable, Sendable {
    public var time: TimeInterval
    public var value: Double
    public var x: CGFloat
    public var y: CGFloat

    public init(time: TimeInterval, value: Double, x: CGFloat, y: CGFloat) {
        self.time = time
        self.value = value
        self.x = x
        self.y = y
    }
}

public struct LivelineActivePoint: Hashable, Sendable {
    public var time: TimeInterval
    public var value: Double?
    public var pulse: Bool

    public init(time: TimeInterval, value: Double? = nil, pulse: Bool = true) {
        self.time = time
        self.value = value
        self.pulse = pulse
    }
}

public struct LivelinePadding: Hashable, Sendable {
    public var top: CGFloat?
    public var right: CGFloat?
    public var bottom: CGFloat?
    public var left: CGFloat?

    public init(top: CGFloat? = nil, right: CGFloat? = nil, bottom: CGFloat? = nil, left: CGFloat? = nil) {
        self.top = top
        self.right = right
        self.bottom = bottom
        self.left = left
    }
}

public struct LivelineResolvedPadding: Hashable, Sendable {
    public var top: CGFloat
    public var right: CGFloat
    public var bottom: CGFloat
    public var left: CGFloat

    public init(top: CGFloat, right: CGFloat, bottom: CGFloat, left: CGFloat) {
        self.top = top
        self.right = right
        self.bottom = bottom
        self.left = left
    }
}

public struct LivelineOrderbookLevel: Hashable, Sendable {
    public var price: Double
    public var size: Double

    public init(price: Double, size: Double) {
        self.price = price
        self.size = size
    }
}

public struct LivelineOrderbookData: Hashable, Sendable {
    public var bids: [LivelineOrderbookLevel]
    public var asks: [LivelineOrderbookLevel]

    public init(bids: [LivelineOrderbookLevel], asks: [LivelineOrderbookLevel]) {
        self.bids = bids
        self.asks = asks
    }
}

public struct LivelineDegenOptions: Hashable, Sendable {
    public var scale: Double
    public var downMomentum: Bool

    public init(scale: Double = 1, downMomentum: Bool = false) {
        self.scale = scale
        self.downMomentum = downMomentum
    }
}


public enum LivelineFormatters {
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    public static func value(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    public static func time(_ time: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: time)
        return timeFormatter.string(from: date)
    }
}
