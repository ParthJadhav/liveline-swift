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
