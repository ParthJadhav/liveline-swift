import CoreGraphics
import Foundation

public struct LivelineChartAppearance {
    public var theme: LivelineThemeMode
    public var style: LivelineChartStyle
    public var grid: Bool
    public var fill: Bool
    public var lineWidth: CGFloat
    public var showValue: Bool
    public var valueMomentumColor: Bool
    public var emptyText: String
    public var padding: LivelinePadding

    public init(
        theme: LivelineThemeMode = .dark,
        style: LivelineChartStyle = .standard,
        grid: Bool = true,
        fill: Bool = true,
        lineWidth: CGFloat = 2,
        showValue: Bool = false,
        valueMomentumColor: Bool = false,
        emptyText: String = "No data to display",
        padding: LivelinePadding = LivelinePadding()
    ) {
        self.theme = theme
        self.style = style
        self.grid = grid
        self.fill = fill
        self.lineWidth = lineWidth
        self.showValue = showValue
        self.valueMomentumColor = valueMomentumColor
        self.emptyText = emptyText
        self.padding = padding
    }
}

public struct LivelineChartEffects {
    public var badge: Bool
    public var badgeVariant: LivelineBadgeVariant
    public var badgeTail: Bool
    public var pulse: Bool
    public var endpointDecorations: Bool
    public var fadeEffects: Bool
    public var tooltipY: CGFloat
    public var tooltipOutline: Bool
    public var degen: LivelineDegenOptions?
    public var randomSeed: UInt32?

    public init(
        badge: Bool = true,
        badgeVariant: LivelineBadgeVariant = .default,
        badgeTail: Bool = true,
        pulse: Bool = true,
        endpointDecorations: Bool = true,
        fadeEffects: Bool = false,
        tooltipY: CGFloat = 14,
        tooltipOutline: Bool = true,
        degen: LivelineDegenOptions? = nil,
        randomSeed: UInt32? = nil
    ) {
        self.badge = badge
        self.badgeVariant = badgeVariant
        self.badgeTail = badgeTail
        self.pulse = pulse
        self.endpointDecorations = endpointDecorations
        self.fadeEffects = fadeEffects
        self.tooltipY = tooltipY
        self.tooltipOutline = tooltipOutline
        self.degen = degen
        self.randomSeed = randomSeed
    }
}

public struct LivelineChartViewport {
    public var window: TimeInterval
    public var windows: [LivelineWindowOption]
    public var exaggerate: Bool

    public init(
        window: TimeInterval = 30,
        windows: [LivelineWindowOption] = [],
        exaggerate: Bool = false
    ) {
        self.window = window
        self.windows = windows
        self.exaggerate = exaggerate
    }
}

public struct LivelineChartInteraction {
    public var scrub: Bool
    public var windowStyle: LivelineWindowStyle
    public var lineMode: Bool
    public var seriesToggleCompact: Bool
    public var seriesLegendSide: LivelineLegendSide
    public var showsModeControls: Bool
    public var showsSeriesControls: Bool

    public init(
        scrub: Bool = true,
        windowStyle: LivelineWindowStyle = .default,
        lineMode: Bool = false,
        seriesToggleCompact: Bool = false,
        seriesLegendSide: LivelineLegendSide = .trailing,
        showsModeControls: Bool = false,
        showsSeriesControls: Bool = true
    ) {
        self.scrub = scrub
        self.windowStyle = windowStyle
        self.lineMode = lineMode
        self.seriesToggleCompact = seriesToggleCompact
        self.seriesLegendSide = seriesLegendSide
        self.showsModeControls = showsModeControls
        self.showsSeriesControls = showsSeriesControls
    }
}

public struct LivelineChartMotion {
    public var loading: Bool
    public var paused: Bool
    public var lerpSpeed: Double

    public init(loading: Bool = false, paused: Bool = false, lerpSpeed: Double = 0.08) {
        self.loading = loading
        self.paused = paused
        self.lerpSpeed = lerpSpeed
    }
}

public struct LivelineChartAnnotations {
    public var momentum: LivelineMomentum?
    public var autoDetectMomentum: Bool
    public var orderbook: LivelineOrderbookData?
    public var referenceLine: LivelineReferenceLine?
    public var activePoint: LivelineActivePoint?

    public init(
        momentum: LivelineMomentum? = nil,
        autoDetectMomentum: Bool = true,
        orderbook: LivelineOrderbookData? = nil,
        referenceLine: LivelineReferenceLine? = nil,
        activePoint: LivelineActivePoint? = nil
    ) {
        self.momentum = momentum
        self.autoDetectMomentum = autoDetectMomentum
        self.orderbook = orderbook
        self.referenceLine = referenceLine
        self.activePoint = activePoint
    }
}

public struct LivelineChartFormatting {
    public var value: (Double) -> String
    public var time: (TimeInterval) -> String

    public init(
        value: @escaping (Double) -> String = LivelineFormatters.value,
        time: @escaping (TimeInterval) -> String = LivelineFormatters.time
    ) {
        self.value = value
        self.time = time
    }
}

public struct LivelineChartCallbacks {
    public var onHover: ((LivelineHoverPoint?) -> Void)?
    public var onWindowChange: ((TimeInterval) -> Void)?
    public var onModeChange: ((LivelineChartMode) -> Void)?
    public var onSeriesToggle: ((String, Bool) -> Void)?

    public init(
        onHover: ((LivelineHoverPoint?) -> Void)? = nil,
        onWindowChange: ((TimeInterval) -> Void)? = nil,
        onModeChange: ((LivelineChartMode) -> Void)? = nil,
        onSeriesToggle: ((String, Bool) -> Void)? = nil
    ) {
        self.onHover = onHover
        self.onWindowChange = onWindowChange
        self.onModeChange = onModeChange
        self.onSeriesToggle = onSeriesToggle
    }
}

/// Behavioral and visual configuration for ``LivelineChart``.
///
/// New code can compose the typed policy groups. The original flat properties
/// and initializers remain as source-compatible projections over those groups.
public struct LivelineChartConfiguration {
    public var appearance: LivelineChartAppearance
    public var effects: LivelineChartEffects
    public var viewport: LivelineChartViewport
    public var interaction: LivelineChartInteraction
    public var motion: LivelineChartMotion
    public var annotations: LivelineChartAnnotations
    public var formatting: LivelineChartFormatting
    public var callbacks: LivelineChartCallbacks

    var snapshotElapsedTimeOverride: TimeInterval?

    public init(
        appearance: LivelineChartAppearance,
        effects: LivelineChartEffects = LivelineChartEffects(),
        viewport: LivelineChartViewport = LivelineChartViewport(),
        interaction: LivelineChartInteraction = LivelineChartInteraction(),
        motion: LivelineChartMotion = LivelineChartMotion(),
        annotations: LivelineChartAnnotations = LivelineChartAnnotations(),
        formatting: LivelineChartFormatting = LivelineChartFormatting(),
        callbacks: LivelineChartCallbacks = LivelineChartCallbacks()
    ) {
        self.appearance = appearance
        self.effects = effects
        self.viewport = viewport
        self.interaction = interaction
        self.motion = motion
        self.annotations = annotations
        self.formatting = formatting
        self.callbacks = callbacks
        self.snapshotElapsedTimeOverride = nil
    }

    public init(
        theme: LivelineThemeMode = .dark,
        style: LivelineChartStyle = .standard,
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
            style: style,
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
        style: LivelineChartStyle = .standard,
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
        self.appearance = LivelineChartAppearance(
            theme: theme,
            style: style,
            grid: grid,
            fill: fill,
            lineWidth: lineWidth,
            showValue: showValue,
            valueMomentumColor: valueMomentumColor,
            emptyText: emptyText,
            padding: padding
        )
        self.effects = LivelineChartEffects(
            badge: badge,
            badgeVariant: badgeVariant,
            badgeTail: badgeTail,
            pulse: pulse,
            endpointDecorations: endpointDecorations,
            fadeEffects: fadeEffects,
            tooltipY: tooltipY,
            tooltipOutline: tooltipOutline,
            degen: degen,
            randomSeed: randomSeed
        )
        self.viewport = LivelineChartViewport(window: window, windows: windows, exaggerate: exaggerate)
        self.interaction = LivelineChartInteraction(
            scrub: scrub,
            windowStyle: windowStyle,
            lineMode: lineMode,
            seriesToggleCompact: seriesToggleCompact,
            seriesLegendSide: seriesLegendSide,
            showsModeControls: onModeChange != nil,
            showsSeriesControls: true
        )
        self.motion = LivelineChartMotion(loading: loading, paused: paused, lerpSpeed: lerpSpeed)
        self.annotations = LivelineChartAnnotations(
            momentum: momentum,
            autoDetectMomentum: autoDetectMomentum,
            orderbook: orderbook,
            referenceLine: referenceLine,
            activePoint: activePoint
        )
        self.formatting = LivelineChartFormatting(value: formatValue, time: formatTime)
        self.callbacks = LivelineChartCallbacks(
            onHover: onHover,
            onWindowChange: onWindowChange,
            onModeChange: onModeChange,
            onSeriesToggle: onSeriesToggle
        )
        self.snapshotElapsedTimeOverride = snapshotElapsedTime
    }
}

// MARK: - Source-compatible flat projections

extension LivelineChartConfiguration {
    public var theme: LivelineThemeMode { get { appearance.theme } set { appearance.theme = newValue } }
    public var style: LivelineChartStyle { get { appearance.style } set { appearance.style = newValue } }
    public var window: TimeInterval { get { viewport.window } set { viewport.window = newValue } }
    public var windows: [LivelineWindowOption] { get { viewport.windows } set { viewport.windows = newValue } }
    public var grid: Bool { get { appearance.grid } set { appearance.grid = newValue } }
    public var badge: Bool { get { effects.badge } set { effects.badge = newValue } }
    public var badgeVariant: LivelineBadgeVariant { get { effects.badgeVariant } set { effects.badgeVariant = newValue } }
    public var badgeTail: Bool { get { effects.badgeTail } set { effects.badgeTail = newValue } }
    public var fill: Bool { get { appearance.fill } set { appearance.fill = newValue } }
    public var pulse: Bool { get { effects.pulse } set { effects.pulse = newValue } }
    public var endpointDecorations: Bool { get { effects.endpointDecorations } set { effects.endpointDecorations = newValue } }
    public var fadeEffects: Bool { get { effects.fadeEffects } set { effects.fadeEffects = newValue } }
    public var lineWidth: CGFloat { get { appearance.lineWidth } set { appearance.lineWidth = newValue } }
    public var momentum: LivelineMomentum? { get { annotations.momentum } set { annotations.momentum = newValue } }
    public var autoDetectMomentum: Bool { get { annotations.autoDetectMomentum } set { annotations.autoDetectMomentum = newValue } }
    public var scrub: Bool { get { interaction.scrub } set { interaction.scrub = newValue } }
    public var exaggerate: Bool { get { viewport.exaggerate } set { viewport.exaggerate = newValue } }
    public var showValue: Bool { get { appearance.showValue } set { appearance.showValue = newValue } }
    public var valueMomentumColor: Bool { get { appearance.valueMomentumColor } set { appearance.valueMomentumColor = newValue } }
    public var degen: LivelineDegenOptions? { get { effects.degen } set { effects.degen = newValue } }
    public var loading: Bool { get { motion.loading } set { motion.loading = newValue } }
    public var paused: Bool { get { motion.paused } set { motion.paused = newValue } }
    public var emptyText: String { get { appearance.emptyText } set { appearance.emptyText = newValue } }
    public var windowStyle: LivelineWindowStyle { get { interaction.windowStyle } set { interaction.windowStyle = newValue } }
    public var tooltipY: CGFloat { get { effects.tooltipY } set { effects.tooltipY = newValue } }
    public var tooltipOutline: Bool { get { effects.tooltipOutline } set { effects.tooltipOutline = newValue } }
    public var orderbook: LivelineOrderbookData? { get { annotations.orderbook } set { annotations.orderbook = newValue } }
    public var referenceLine: LivelineReferenceLine? { get { annotations.referenceLine } set { annotations.referenceLine = newValue } }
    public var activePoint: LivelineActivePoint? { get { annotations.activePoint } set { annotations.activePoint = newValue } }
    public var formatValue: (Double) -> String { get { formatting.value } set { formatting.value = newValue } }
    public var formatTime: (TimeInterval) -> String { get { formatting.time } set { formatting.time = newValue } }
    public var lerpSpeed: Double { get { motion.lerpSpeed } set { motion.lerpSpeed = newValue } }
    public var randomSeed: UInt32? { get { effects.randomSeed } set { effects.randomSeed = newValue } }
    public var padding: LivelinePadding { get { appearance.padding } set { appearance.padding = newValue } }
    public var lineMode: Bool { get { interaction.lineMode } set { interaction.lineMode = newValue } }
    public var seriesToggleCompact: Bool { get { interaction.seriesToggleCompact } set { interaction.seriesToggleCompact = newValue } }
    public var seriesLegendSide: LivelineLegendSide { get { interaction.seriesLegendSide } set { interaction.seriesLegendSide = newValue } }
    public var showsModeControls: Bool { get { interaction.showsModeControls } set { interaction.showsModeControls = newValue } }
    public var showsSeriesControls: Bool { get { interaction.showsSeriesControls } set { interaction.showsSeriesControls = newValue } }
    public var onHover: ((LivelineHoverPoint?) -> Void)? { get { callbacks.onHover } set { callbacks.onHover = newValue } }
    public var onWindowChange: ((TimeInterval) -> Void)? { get { callbacks.onWindowChange } set { callbacks.onWindowChange = newValue } }
    public var onModeChange: ((LivelineChartMode) -> Void)? { get { callbacks.onModeChange } set { callbacks.onModeChange = newValue } }
    public var onSeriesToggle: ((String, Bool) -> Void)? { get { callbacks.onSeriesToggle } set { callbacks.onSeriesToggle = newValue } }

    @available(*, deprecated, message: "Snapshot timing is testing-only and is not part of the canonical configuration API.")
    public var snapshotElapsedTime: TimeInterval? {
        get { snapshotElapsedTimeOverride }
        set { snapshotElapsedTimeOverride = newValue }
    }

    var resolvedSnapshotElapsedTime: TimeInterval? { snapshotElapsedTimeOverride }
    var initialWindow: TimeInterval {
        guard !windows.isEmpty else { return window }
        return windows.contains(where: { $0.seconds == window }) ? window : (windows.first?.seconds ?? window)
    }

    func normalizedForRendering() -> LivelineChartConfiguration {
        var configuration = self
        configuration.window = LivelineScalar.positiveDuration(configuration.window, fallback: 30)

        var seenWindows = Set<TimeInterval>()
        configuration.windows = configuration.windows.compactMap { option in
            guard option.seconds.isFinite, option.seconds > 0 else { return nil }
            let seconds = LivelineScalar.positiveDuration(option.seconds, fallback: configuration.window)
            guard seenWindows.insert(seconds).inserted else { return nil }
            return LivelineWindowOption(label: option.label, seconds: seconds)
        }
        configuration.lineWidth = configuration.lineWidth.livelineClamped(
            0,
            LivelineScalar.maximumDrawingMagnitude,
            fallback: 2
        )
        configuration.style = configuration.style.normalizedForRendering()
        configuration.tooltipY = configuration.tooltipY.livelineClamped(
            -LivelineScalar.maximumDrawingMagnitude,
            LivelineScalar.maximumDrawingMagnitude,
            fallback: 14
        )
        configuration.lerpSpeed = configuration.lerpSpeed.isFinite ? min(max(configuration.lerpSpeed, 0), 1) : 0.08
        configuration.snapshotElapsedTimeOverride = configuration.snapshotElapsedTimeOverride.flatMap {
            $0.isFinite && $0 >= 0 ? $0 : nil
        }
        configuration.padding = configuration.padding.normalizedForRendering()
        configuration.referenceLine = configuration.referenceLine.flatMap { referenceLine in
            guard referenceLine.value.isFinite else { return nil }
            return LivelineReferenceLine(
                value: LivelineScalar.value(referenceLine.value),
                label: referenceLine.label
            )
        }
        configuration.activePoint = configuration.activePoint.flatMap { point in
            guard let time = LivelineScalar.time(point.time) else { return nil }
            return LivelineActivePoint(
                time: time,
                value: point.value.flatMap { $0.isFinite ? LivelineScalar.value($0) : nil },
                pulse: point.pulse
            )
        }
        configuration.degen = configuration.degen.map { options in
            LivelineDegenOptions(
                scale: options.scale.isFinite ? min(max(options.scale, 0), 8) : 1,
                downMomentum: options.downMomentum
            )
        }
        configuration.orderbook = configuration.orderbook.map { orderbook in
            LivelineOrderbookData(
                bids: normalizedOrderbookLevels(orderbook.bids),
                asks: normalizedOrderbookLevels(orderbook.asks)
            )
        }
        return configuration
    }

    func respectingReducedMotion(_ enabled: Bool) -> LivelineChartConfiguration {
        guard enabled else { return self }
        var configuration = self
        configuration.style = configuration.style.respectingReducedMotion(true)
        configuration.fadeEffects = false
        configuration.pulse = false
        configuration.degen = nil
        if let activePoint = configuration.activePoint {
            configuration.activePoint = LivelineActivePoint(
                time: activePoint.time,
                value: activePoint.value,
                pulse: false
            )
        }
        return configuration
    }
}

private extension LivelinePadding {
    func normalizedForRendering() -> LivelinePadding {
        LivelinePadding(
            top: top.flatMap { $0.isFinite ? min(max($0, 0), LivelineScalar.maximumDrawingMagnitude) : nil },
            right: right.flatMap { $0.isFinite ? min(max($0, 0), LivelineScalar.maximumDrawingMagnitude) : nil },
            bottom: bottom.flatMap { $0.isFinite ? min(max($0, 0), LivelineScalar.maximumDrawingMagnitude) : nil },
            left: left.flatMap { $0.isFinite ? min(max($0, 0), LivelineScalar.maximumDrawingMagnitude) : nil }
        )
    }
}

private func normalizedOrderbookLevels(_ levels: [LivelineOrderbookLevel]) -> [LivelineOrderbookLevel] {
    levels.compactMap { level in
        guard level.price.isFinite, level.size.isFinite, level.size > 0 else { return nil }
        return LivelineOrderbookLevel(
            price: LivelineScalar.value(level.price),
            size: LivelineScalar.value(level.size)
        )
    }
}
