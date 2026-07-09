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

    var resolvedWidthRatio: CGFloat { min(max(widthRatio, 0.05), 1) }
    var resolvedCornerRadius: CGFloat { max(cornerRadius, 0) }
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

    var resolvedFillOpacity: Double { min(max(fillOpacity, 0), 1) }
    var resolvedBoundaryLineWidth: CGFloat { max(boundaryLineWidth, 0) }
    var resolvedCenterLineWidth: CGFloat { max(centerLineWidth, 0) }
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

    var resolvedPointSize: CGFloat { max(pointSize, 2) }
    var resolvedOutlineWidth: CGFloat { max(outlineWidth, 0) }
    var resolvedConnectionLineWidth: CGFloat { max(connectionLineWidth, 0) }
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

    var resolvedLineWidth: CGFloat { max(lineWidth, 0) }
    var resolvedFillOpacity: Double { min(max(fillOpacity, 0), 1) }
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

    var resolvedStemWidth: CGFloat { max(stemWidth, 0) }
    var resolvedHeadSize: CGFloat { max(headSize, 2) }
    var resolvedOutlineWidth: CGFloat { max(outlineWidth, 0) }
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

    var resolvedMinimumSize: CGFloat { max(min(minimumSize, maximumSize), 2) }
    var resolvedMaximumSize: CGFloat { max(max(minimumSize, maximumSize), resolvedMinimumSize) }
    var resolvedFillOpacity: Double { min(max(fillOpacity, 0), 1) }
    var resolvedOutlineWidth: CGFloat { max(outlineWidth, 0) }
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

    var resolvedWidthRatio: CGFloat { min(max(widthRatio, 0.05), 1) }
    var resolvedFillOpacity: Double { min(max(fillOpacity, 0), 1) }
    var resolvedOutlineWidth: CGFloat { max(outlineWidth, 0) }
    var resolvedMedianLineWidth: CGFloat { max(medianLineWidth, 0) }
    var resolvedWhiskerWidthRatio: CGFloat { min(max(whiskerWidthRatio, 0.05), 1) }
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

    var resolvedWidthRatio: CGFloat { min(max(widthRatio, 0.05), 1) }
    var resolvedCornerRadius: CGFloat { max(cornerRadius, 0) }
    var resolvedConnectorLineWidth: CGFloat { max(connectorLineWidth, 0) }
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

/// Behavioral and visual configuration for ``LivelineChart``.
public struct LivelineChartConfiguration {
    public var theme: LivelineThemeMode
    public var window: TimeInterval
    public var windows: [LivelineWindowOption]
    public var grid: Bool
    public var badge: Bool
    public var badgeVariant: LivelineBadgeVariant
    public var badgeTail: Bool
    public var fill: Bool
    public var pulse: Bool
    public var endpointDecorations: Bool
    public var fadeEffects: Bool
    public var lineWidth: CGFloat
    public var momentum: LivelineMomentum?
    public var autoDetectMomentum: Bool
    public var scrub: Bool
    public var exaggerate: Bool
    public var showValue: Bool
    public var valueMomentumColor: Bool
    public var degen: LivelineDegenOptions?
    public var loading: Bool
    public var paused: Bool
    public var emptyText: String
    public var windowStyle: LivelineWindowStyle
    public var tooltipY: CGFloat
    public var tooltipOutline: Bool
    public var orderbook: LivelineOrderbookData?
    public var referenceLine: LivelineReferenceLine?
    public var activePoint: LivelineActivePoint?
    public var formatValue: (Double) -> String
    public var formatTime: (TimeInterval) -> String
    public var lerpSpeed: Double
    public var randomSeed: UInt32?
    public var snapshotElapsedTime: TimeInterval?
    public var padding: LivelinePadding
    public var lineMode: Bool
    public var seriesToggleCompact: Bool
    public var seriesLegendSide: LivelineLegendSide
    public var onHover: ((LivelineHoverPoint?) -> Void)?
    public var onWindowChange: ((TimeInterval) -> Void)?
    public var onModeChange: ((LivelineChartMode) -> Void)?
    public var onSeriesToggle: ((String, Bool) -> Void)?

    public init(
        theme: LivelineThemeMode = .dark,
        window: TimeInterval = 30,
        windows: [LivelineWindowOption] = [],
        grid: Bool = true,
        badge: Bool = true,
        badgeVariant: LivelineBadgeVariant = .default,
        badgeTail: Bool = true,
        fill: Bool = true,
        pulse: Bool = true,
        lineWidth: CGFloat = 2,
        momentum: LivelineMomentum? = nil,
        autoDetectMomentum: Bool = true,
        scrub: Bool = true,
        exaggerate: Bool = false,
        showValue: Bool = false,
        valueMomentumColor: Bool = false,
        degen: LivelineDegenOptions? = nil,
        loading: Bool = false,
        paused: Bool = false,
        emptyText: String = "No data to display",
        windowStyle: LivelineWindowStyle = .default,
        tooltipY: CGFloat = 14,
        tooltipOutline: Bool = true,
        orderbook: LivelineOrderbookData? = nil,
        referenceLine: LivelineReferenceLine? = nil,
        formatValue: @escaping (Double) -> String = LivelineFormatters.value,
        formatTime: @escaping (TimeInterval) -> String = LivelineFormatters.time,
        lerpSpeed: Double = 0.08,
        randomSeed: UInt32? = nil,
        snapshotElapsedTime: TimeInterval? = nil,
        padding: LivelinePadding = LivelinePadding(),
        lineMode: Bool = false,
        seriesToggleCompact: Bool = false,
        onHover: ((LivelineHoverPoint?) -> Void)? = nil,
        onWindowChange: ((TimeInterval) -> Void)? = nil,
        onModeChange: ((LivelineChartMode) -> Void)? = nil,
        onSeriesToggle: ((String, Bool) -> Void)? = nil
    ) {
        self.init(
            theme: theme,
            window: window,
            windows: windows,
            grid: grid,
            badge: badge,
            badgeVariant: badgeVariant,
            badgeTail: badgeTail,
            fill: fill,
            pulse: pulse,
            endpointDecorations: true,
            fadeEffects: false,
            lineWidth: lineWidth,
            momentum: momentum,
            autoDetectMomentum: autoDetectMomentum,
            scrub: scrub,
            exaggerate: exaggerate,
            showValue: showValue,
            valueMomentumColor: valueMomentumColor,
            degen: degen,
            loading: loading,
            paused: paused,
            emptyText: emptyText,
            windowStyle: windowStyle,
            tooltipY: tooltipY,
            tooltipOutline: tooltipOutline,
            orderbook: orderbook,
            referenceLine: referenceLine,
            activePoint: nil,
            formatValue: formatValue,
            formatTime: formatTime,
            lerpSpeed: lerpSpeed,
            randomSeed: randomSeed,
            snapshotElapsedTime: snapshotElapsedTime,
            padding: padding,
            lineMode: lineMode,
            seriesToggleCompact: seriesToggleCompact,
            seriesLegendSide: .trailing,
            onHover: onHover,
            onWindowChange: onWindowChange,
            onModeChange: onModeChange,
            onSeriesToggle: onSeriesToggle
        )
    }

    public init(
        theme: LivelineThemeMode = .dark,
        window: TimeInterval = 30,
        windows: [LivelineWindowOption] = [],
        grid: Bool = true,
        badge: Bool = true,
        badgeVariant: LivelineBadgeVariant = .default,
        badgeTail: Bool = true,
        fill: Bool = true,
        pulse: Bool = true,
        endpointDecorations: Bool = true,
        fadeEffects: Bool = false,
        lineWidth: CGFloat = 2,
        momentum: LivelineMomentum? = nil,
        autoDetectMomentum: Bool = true,
        scrub: Bool = true,
        exaggerate: Bool = false,
        showValue: Bool = false,
        valueMomentumColor: Bool = false,
        degen: LivelineDegenOptions? = nil,
        loading: Bool = false,
        paused: Bool = false,
        emptyText: String = "No data to display",
        windowStyle: LivelineWindowStyle = .default,
        tooltipY: CGFloat = 14,
        tooltipOutline: Bool = true,
        orderbook: LivelineOrderbookData? = nil,
        referenceLine: LivelineReferenceLine? = nil,
        activePoint: LivelineActivePoint? = nil,
        formatValue: @escaping (Double) -> String = LivelineFormatters.value,
        formatTime: @escaping (TimeInterval) -> String = LivelineFormatters.time,
        lerpSpeed: Double = 0.08,
        randomSeed: UInt32? = nil,
        snapshotElapsedTime: TimeInterval? = nil,
        padding: LivelinePadding = LivelinePadding(),
        lineMode: Bool = false,
        seriesToggleCompact: Bool = false,
        seriesLegendSide: LivelineLegendSide = .trailing,
        onHover: ((LivelineHoverPoint?) -> Void)? = nil,
        onWindowChange: ((TimeInterval) -> Void)? = nil,
        onModeChange: ((LivelineChartMode) -> Void)? = nil,
        onSeriesToggle: ((String, Bool) -> Void)? = nil
    ) {
        self.theme = theme
        self.window = window
        self.windows = windows
        self.grid = grid
        self.badge = badge
        self.badgeVariant = badgeVariant
        self.badgeTail = badgeTail
        self.fill = fill
        self.pulse = pulse
        self.endpointDecorations = endpointDecorations
        self.fadeEffects = fadeEffects
        self.lineWidth = lineWidth
        self.momentum = momentum
        self.autoDetectMomentum = autoDetectMomentum
        self.scrub = scrub
        self.exaggerate = exaggerate
        self.showValue = showValue
        self.valueMomentumColor = valueMomentumColor
        self.degen = degen
        self.loading = loading
        self.paused = paused
        self.emptyText = emptyText
        self.windowStyle = windowStyle
        self.tooltipY = tooltipY
        self.tooltipOutline = tooltipOutline
        self.orderbook = orderbook
        self.referenceLine = referenceLine
        self.activePoint = activePoint
        self.formatValue = formatValue
        self.formatTime = formatTime
        self.lerpSpeed = lerpSpeed
        self.randomSeed = randomSeed
        self.snapshotElapsedTime = snapshotElapsedTime
        self.padding = padding
        self.lineMode = lineMode
        self.seriesToggleCompact = seriesToggleCompact
        self.seriesLegendSide = seriesLegendSide
        self.onHover = onHover
        self.onWindowChange = onWindowChange
        self.onModeChange = onModeChange
        self.onSeriesToggle = onSeriesToggle
    }
}

public enum LivelineFormatters {
    public static func value(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    public static func time(_ time: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: time)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
