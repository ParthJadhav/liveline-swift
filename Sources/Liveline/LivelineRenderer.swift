import Foundation
import SwiftUI

struct LivelineRenderInput {
    var content: LivelineChartContent
    var semantics: LivelineChartSemantics
    var accent: Color
    var configuration: LivelineChartConfiguration
    var motion: LivelineMotionPolicy
    var activeWindow: TimeInterval
    /// The right edge a frozen zoom-and-pan viewport has pinned, or `nil` to
    /// follow the live edge as usual. `activeWindow` still carries the visible
    /// span, so the two together are the viewport.
    var frozenRightEdge: TimeInterval? = nil
    var hiddenSeries: Set<String>
    var hoverLocation: CGPoint?
    var timestamp: TimeInterval
    var size: CGSize
    /// Canvas text does not inherit Dynamic Type on its own; the chart reads the
    /// environment and hands the resolved multiplier to every text site.
    var textScale: LivelineTextScale = .standard
    /// Canvas drawing does not inherit `layoutDirection` either. The chart reads
    /// it once per body evaluation so the render pipeline can mirror the time
    /// axis, the gutters, and every hover coordinate.
    var isRTL: Bool = false
}

enum LivelineRenderer {
    static let windowBuffer = 0.05
    static let windowBufferNoBadge = 0.015
    static let loadingAmplitudeRatio: CGFloat = 0.07
    static let loadingScrollSpeed: Double = 1.0
    static let fadeEdgeWidth: CGFloat = 40
    static let badgePaddingX: CGFloat = 10
    static let badgePaddingY: CGFloat = 3
    static let badgeTailLength: CGFloat = 5
    static let badgeTailSpread: CGFloat = 2.5
    static let badgeLineHeight: CGFloat = 16
    static let axisLabelOffsetX: CGFloat = 7.33
    static let orderbookTextOffsetX: CGFloat = -4
    static let orderbookTextOffsetY: CGFloat = 0
    static let candleLineMorphDuration: TimeInterval = 0.50
    static let candleLineDensityDuration: TimeInterval = 0.35
    static let candleLiveLerpSpeed = 0.25
    static let candleCloseLineLerpSpeed = 0.25
    static let candleLineLerpBase = 0.08
    static let candleLineAdaptiveBoost = 0.20

    static func draw(context: inout GraphicsContext, state: LivelineRenderState, input: LivelineRenderInput) {
        guard input.size.width > 8, input.size.height > 8 else {
            state.interactionSnapshot = nil
            return
        }

        state.settlesTransitionsImmediately = input.motion.settlesImmediately
        state.adoptTextScale(input.textScale)
        let textScale = input.textScale
        let config = input.configuration
        let palette = state.palette(accent: input.accent, mode: config.theme, lineWidth: config.lineWidth)
        let capabilities = input.semantics.capabilities
        let kind = input.semantics.identity.kind
        let isLine = kind == .line
        let isCandle = kind == .candle
        let isMultiSeries = kind == .series
        let showBadge = capabilities.supportsLiveBadge && config.badge
        let reservesBadgePadding = capabilities.reservesBadgePadding && config.badge
        let isRTL = input.isRTL
        let ltrPadding = LivelineMath.resolvedPadding(
            config.padding,
            badgeEnabled: reservesBadgePadding,
            showValueAxis: config.grid && capabilities.usesValueAxis,
            showTimeAxis: capabilities.usesTimeAxis || capabilities.reservesBottomAxisPadding
        )
        // The value-axis gutter and the badge's room are resolved on the right;
        // in an RTL layout the live edge — and everything hanging off it — moves
        // to the left, so the horizontal insets swap with it.
        let resolvedPadding = isRTL ? ltrPadding.mirroredHorizontally() : ltrPadding
        let presentationTimestamp = state.presentationTimestamp(for: input.timestamp, isPaused: input.motion.isPaused)
        let baseBuffer = isCandle ? windowBufferNoBadge : (showBadge ? windowBuffer : windowBufferNoBadge)
        let labelReveal = config.fadeEffects ? state.chartReveal : 1
        // The legend gutter is requested on a logical side, so it follows the
        // reading direction onto the physical edge that side maps to.
        let leadingReserve = dataReserve(for: input.content, side: .leading, config: config, context: context, state: state, textScale: textScale, reveal: labelReveal)
        let trailingReserve = dataReserve(for: input.content, side: .trailing, config: config, context: context, state: state, textScale: textScale, reveal: labelReveal)
        let dataLeftReserve = isRTL ? trailingReserve : leadingReserve
        let dataRightReserve = isRTL ? leadingReserve : trailingReserve
        let chartWidth = max(1, input.size.width - resolvedPadding.left - resolvedPadding.right - dataLeftReserve - dataRightReserve)
        // Everything below is derived from the *drawn* window rather than the
        // requested one, so a window change eases across frames instead of
        // remapping every visible time in a single one.
        let effectiveWindow = resolvedWindow(state: state, input: input, plotWidth: chartWidth)
        let anchor = anchorTime(latestTime: input.semantics.latestTime, timelineTimestamp: presentationTimestamp, window: effectiveWindow)
        let needsArrowRoom = isLine && showBadge && (config.autoDetectMomentum || config.momentum != nil)
        let buffer = needsArrowRoom ? max(baseBuffer, Double(37 / chartWidth)) : baseBuffer
        let liveRightEdge = anchor + effectiveWindow * buffer
        state.liveRightEdge = liveRightEdge
        // A frozen viewport substitutes its own right edge and nothing else
        // changes: decimation, hover narrowing, the time axis, and the prepared
        // chart cache all key off these two edges already.
        let rightEdge = resolvedRightEdge(
            target: input.frozenRightEdge ?? liveRightEdge,
            window: effectiveWindow,
            state: state,
            input: input
        )
        let leftEdge = rightEdge - effectiveWindow

        let renderData = LivelineChartPreparer.prepare(
            for: input.content,
            hiddenSeries: input.hiddenSeries,
            leftEdge: leftEdge,
            rightEdge: rightEdge,
            config: config,
            state: state
        )
        state.reconcile(
            identity: input.semantics.identity,
            anchorValue: renderData.primaryValue,
            window: input.activeWindow
        )
        let frame = state.frame(for: input.timestamp, isPaused: input.motion.isPaused)
        let dt = frame.deltaMilliseconds
        let animationTimestamp = frame.elapsed
        let hasRenderableData = renderData.hasData
        let targetReveal = hasRenderableData && !config.loading ? 1.0 : 0.0
        if config.fadeEffects && !input.motion.settlesImmediately && !input.motion.isPaused {
            let revealSpeed = targetReveal > state.chartReveal ? 0.09 : 0.14
            state.chartReveal = LivelineMath.lerp(state.chartReveal, targetReveal, speed: revealSpeed, deltaTime: dt)
        } else {
            state.chartReveal = targetReveal
        }
        state.pauseProgress = input.motion.isPaused ? 1 : 0
        if abs(state.chartReveal - targetReveal) < 0.005 {
            state.chartReveal = targetReveal
        }
        if state.pauseProgress < 0.005 {
            state.pauseProgress = 0
        } else if state.pauseProgress > 0.995 {
            state.pauseProgress = 1
        }
        let currentValue = renderData.primaryValue
        let previousSmooth = state.smoothValue ?? currentValue
        let rangeForSpeed = max(0.001, (state.displayMax ?? currentValue + 0.2) - (state.displayMin ?? currentValue - 0.2))
        let valueGap = abs(currentValue - previousSmooth)
        let adaptiveSpeed = config.lerpSpeed + (1 - min(valueGap / rangeForSpeed, 1)) * 0.20
        if input.motion.isPaused {
            state.smoothValue = previousSmooth
        } else if input.motion.settlesImmediately {
            state.smoothValue = currentValue
        } else {
            state.smoothValue = LivelineMath.lerp(previousSmooth, currentValue, speed: adaptiveSpeed, deltaTime: dt)
        }
        let smoothValue = state.smoothValue ?? currentValue

        let range = valueRange(
            renderData: renderData,
            smoothValue: smoothValue,
            visibleTimeRange: leftEdge...rightEdge,
            config: config
        )
        if state.displayMin == nil || state.displayMax == nil || input.motion.settlesImmediately {
            state.displayMin = range.lowerBound
            state.displayMax = range.upperBound
        } else {
            let currentMin = state.displayMin ?? range.lowerBound
            let currentMax = state.displayMax ?? range.upperBound
            let currentRange = max(0.001, currentMax - currentMin)
            let chartHeight = max(1, input.size.height - resolvedPadding.top - resolvedPadding.bottom)
            let rangeSpeed: Double
            if isMultiSeries {
                rangeSpeed = config.lerpSpeed + 0.10
            } else if isCandle {
                let gapMin = abs(currentMin - range.lowerBound)
                let gapMax = abs(currentMax - range.upperBound)
                let gapRatio = min((gapMin + gapMax) / currentRange, 1)
                rangeSpeed = 0.15 + (1 - gapRatio) * 0.20
            } else {
                rangeSpeed = adaptiveSpeed
            }

            var nextMin = LivelineMath.lerp(currentMin, range.lowerBound, speed: rangeSpeed, deltaTime: dt)
            var nextMax = LivelineMath.lerp(currentMax, range.upperBound, speed: rangeSpeed, deltaTime: dt)
            let pixelThreshold = max(0.001, 0.5 * currentRange / Double(chartHeight))
            if abs(nextMin - range.lowerBound) < pixelThreshold { nextMin = range.lowerBound }
            if abs(nextMax - range.upperBound) < pixelThreshold { nextMax = range.upperBound }
            state.displayMin = nextMin
            state.displayMax = nextMax
        }

        let layout = LivelineLayout(
            size: input.size,
            padding: resolvedPadding,
            minValue: state.displayMin ?? range.lowerBound,
            maxValue: state.displayMax ?? range.upperBound,
            leftEdge: leftEdge,
            rightEdge: rightEdge,
            dataLeftReserve: dataLeftReserve,
            dataRightReserve: dataRightReserve,
            isRTL: isRTL
        )
        let swingMagnitude = renderData.swingMagnitude(valueRange: layout.maxValue - layout.minValue)

        if config.loading || !hasRenderableData {
            drawLoadingOrEmpty(
                context: &context,
                layout: centeredPlaceholderLayout(from: layout, input: input),
                palette: palette,
                input: input,
                animationTimestamp: animationTimestamp,
                showText: !config.loading
            )
        }

        guard hasRenderableData else {
            state.interactionSnapshot = nil
            return
        }

        var layer = context
        if state.shakeAmplitude > 0.2 {
            let x = randomCGFloat(
                in: -state.shakeAmplitude...state.shakeAmplitude,
                state: state,
                seed: config.randomSeed
            )
            let y = randomCGFloat(
                in: -state.shakeAmplitude...state.shakeAmplitude,
                state: state,
                seed: config.randomSeed
            )
            layer.translateBy(x: x, y: y)
            state.shakeAmplitude *= CGFloat(pow(0.002, dt / 1000))
            if state.shakeAmplitude < 0.2 { state.shakeAmplitude = 0 }
        }

        if let referenceLine = config.referenceLine, state.chartReveal > 0.01 {
            drawReferenceLine(context: &layer, layout: layout, palette: palette, referenceLine: referenceLine, formatValue: config.formatValue, textScale: textScale, alpha: state.chartReveal)
        }

        if !config.referenceLines.isEmpty, capabilities.usesCartesianGrid, state.chartReveal > 0.01 {
            drawReferenceLines(context: &layer, layout: layout, palette: palette, lines: config.referenceLines, textScale: textScale, alpha: state.chartReveal)
        }

        if config.grid, capabilities.usesCartesianGrid {
            drawGrid(context: &layer, layout: layout, palette: palette, state: state, formatValue: config.formatValue, textScale: textScale, alpha: revealAmount(state.chartReveal, 0.15, 0.70, fadeEffects: config.fadeEffects), fadeEffects: config.fadeEffects, deltaTime: dt)
        }

        // Bands sit between the grid and the marks: a backdrop for the data
        // rather than a highlight painted over it.
        if !config.referenceBands.isEmpty, capabilities.usesCartesianGrid, state.chartReveal > 0.01 {
            drawReferenceBands(context: &layer, layout: layout, palette: palette, bands: config.referenceBands, textScale: textScale, alpha: state.chartReveal)
        }

        if let orderbook = config.orderbook, isLine {
            drawOrderbook(context: &layer, layout: layout, palette: palette, state: state, orderbook: orderbook, randomSeed: config.randomSeed, textScale: textScale, deltaTime: dt, swingMagnitude: swingMagnitude, alpha: state.chartReveal)
        }

        let interactionSnapshot = LivelineInteractionBuilder.snapshot(
            content: input.content,
            prepared: renderData,
            layout: layout,
            palette: palette,
            configuration: config,
            hiddenSeries: input.hiddenSeries,
            behavior: capabilities.hoverBehavior,
            // Structured targets format labels and values for every visible
            // datum. Keep the idle snapshot lightweight and only pay that cost
            // while a pointer or touch is actively inspecting the chart.
            includeTargets: input.hoverLocation != nil,
            targetLocation: input.hoverLocation
        )
        state.interactionSnapshot = interactionSnapshot
        let tooltipSelection = LivelineHoverResolver.resolveSelection(
            location: input.hoverLocation,
            snapshot: interactionSnapshot
        )
        let hover = tooltipSelection?.hover
        let scrubAmount = config.resolvesTooltipSelection && hover != nil ? 1.0 : 0.0

        let compositorInput = LivelineCompositorInput(
            content: input.content,
            configuration: config,
            layout: layout,
            palette: palette,
            prepared: renderData,
            hiddenSeries: input.hiddenSeries,
            hover: hover,
            scrubAmount: scrubAmount,
            smoothValue: smoothValue,
            swingMagnitude: swingMagnitude,
            anchor: anchor,
            leftEdge: leftEdge,
            rightEdge: rightEdge,
            reveal: state.chartReveal,
            animationTimestamp: animationTimestamp,
            deltaTime: dt,
            textScale: textScale
        )
        var contentOverlay = LivelineContentOverlay.standard
        switch config.style {
        case .standard:
            contentOverlay = drawContent(context: &layer, state: state, input: compositorInput)
        case let .dither(style):
            layer.drawLayer { styledLayer in
                if let bloom = ditherBloom(style: style, timestamp: animationTimestamp) {
                    styledLayer.addFilter(
                        .shadow(
                            color: input.accent.opacity(bloom.opacity),
                            radius: bloom.radius,
                            x: 0,
                            y: 0,
                            blendMode: .plusLighter
                        )
                    )
                }
                contentOverlay = drawContent(
                    context: &styledLayer,
                    state: state,
                    input: compositorInput,
                    drawText: false
                )
                drawDitherTexture(
                    context: &styledLayer,
                    state: state,
                    layout: layout,
                    color: input.accent,
                    style: style,
                    timestamp: animationTimestamp
                )
            }
            drawContentText(context: &layer, input: compositorInput, overlay: contentOverlay)
        }

        if capabilities.usesTimeAxis {
            let axisRevealStart = isCandle ? 0.25 : 0.15
            let axisRevealEnd = isCandle ? 0.60 : 0.70
            drawTimeAxis(
                context: &layer,
                layout: layout,
                palette: palette,
                state: state,
                window: effectiveWindow,
                formatTime: config.formatTime,
                textScale: textScale,
                alpha: revealAmount(
                    state.chartReveal,
                    axisRevealStart,
                    axisRevealEnd,
                    fadeEffects: config.fadeEffects
                ),
                fadeEffects: config.fadeEffects,
                deltaTime: dt
            )
        }

        drawContentOverlays(
            context: &layer,
            overlay: contentOverlay,
            layout: layout,
            palette: palette,
            prepared: renderData,
            hover: hover,
            scrubAmount: scrubAmount,
            configuration: config,
            tooltipSelection: tooltipSelection,
            textScale: textScale,
            reveal: state.chartReveal,
            animationTimestamp: animationTimestamp
        )

        if config.fadeEffects {
            drawLeftFade(context: &context, layout: layout)
        }

    }
}

extension LivelineRenderer {
    static func centeredPlaceholderLayout(
        from layout: LivelineLayout,
        input: LivelineRenderInput
    ) -> LivelineLayout {
        let padding = LivelineMath.resolvedPadding(
            input.configuration.padding,
            badgeEnabled: false,
            showValueAxis: false,
            showTimeAxis: false
        )
        return LivelineLayout(
            size: input.size,
            padding: input.isRTL ? padding.mirroredHorizontally() : padding,
            minValue: layout.minValue,
            maxValue: layout.maxValue,
            leftEdge: layout.leftEdge,
            rightEdge: layout.rightEdge,
            isRTL: input.isRTL
        )
    }

    static func dataReserve(
        for content: LivelineChartContent,
        side: LivelineLegendSide,
        config: LivelineChartConfiguration,
        context: GraphicsContext,
        state: LivelineRenderState,
        textScale: LivelineTextScale,
        reveal: Double
    ) -> CGFloat {
        guard config.seriesLegendSide == side else { return 0 }
        guard case let .series(series) = content else { return 0 }
        let font = textScale.font(10, weight: .semibold)
        let labels = series.compactMap(\.label)
        guard !labels.isEmpty else { return 0 }
        // Text measurement goes through the graphics context. The gutter only
        // moves when the labels do, so measure once per label set.
        let maxLabelWidth = state.legendGutterWidth(labels: labels, side: side) {
            labels.reduce(CGFloat.zero) { current, label in
                max(current, measureText(label, context: context, font: font).width)
            }
        }
        return max(0, maxLabelWidth - 2) * CGFloat(reveal)
    }

    /// The window the x-axis is actually drawn at this frame.
    ///
    /// The visible span is part of the time-to-x mapping, so adopting a new one
    /// in a single frame slides every visible point sideways at once — the
    /// trace jumps, then scrolls back. Growing the window as data arrives, and
    /// the built-in `30s`/`1m` picker, both do exactly that. Easing the drawn
    /// span toward the requested one turns the jump into a glide, and every
    /// other piece of this frame's geometry — the anchor, the live edge, the
    /// prepared chart's edges, the layout, the time axis' tick spacing — is
    /// derived from the value returned here so nothing mixes the two spans.
    ///
    /// Composes with the viewport's return-to-live glide rather than fighting
    /// it: this eases *how wide* the plot is, ``resolvedRightEdge(target:window:state:input:)``
    /// eases *where its right edge sits*, and the latter is handed the eased
    /// span so its "a window change is a cut" escape hatch no longer trips on a
    /// change that is already being animated.
    static func resolvedWindow(
        state: LivelineRenderState,
        input: LivelineRenderInput,
        plotWidth: CGFloat
    ) -> TimeInterval {
        let target = input.activeWindow
        // Reduce Motion, a settled single-frame export, and a chart that just
        // changed identity all cut to the new span rather than animate to it.
        guard !input.motion.settlesImmediately,
              state.chartIdentity == input.semantics.identity,
              let current = state.displayWindow,
              current.isFinite, current > 0,
              target.isFinite, target > 0
        else {
            state.displayWindow = target
            return target
        }

        // The animation frame is taken once per draw, later, after the identity
        // reconcile that may reset it — so read the delta without consuming it.
        // While paused the delta is zero and the eased span simply holds.
        let dt = state.peekDeltaMilliseconds(for: input.timestamp, isPaused: input.motion.isPaused)
        var next = LivelineMath.lerp(current, target, speed: 0.08, deltaTime: dt)
        // Settle once the remainder is worth less than half a pixel of plot,
        // the same convergence rule the value range uses, so the span does not
        // asymptote toward its target forever.
        let secondsPerPixel = target / Double(max(plotWidth, 1))
        if abs(next - target) < secondsPerPixel * 0.5 { next = target }
        state.displayWindow = next
        return next
    }

    /// Eases the drawn right edge toward wherever the viewport wants it.
    ///
    /// This is what makes "jump back to live" glide rather than cut. It only
    /// runs for charts that opted into zoom and pan, and only while frames are
    /// already arriving — a settled export or a chart with no timeline snaps to
    /// the target, so nothing that renders one frame is left mid-glide.
    ///
    /// - Parameter window: The span actually being drawn this frame — the eased
    ///   one from ``resolvedWindow(state:input:plotWidth:)``, never the raw
    ///   request, so a single frame's geometry is derived from one span only.
    static func resolvedRightEdge(
        target: TimeInterval,
        window: TimeInterval,
        state: LivelineRenderState,
        input: LivelineRenderInput
    ) -> TimeInterval {
        guard input.configuration.zoomAndPan,
              !input.motion.settlesImmediately,
              !input.motion.isPaused,
              let previous = state.displayRightEdge,
              previous.isFinite,
              // A fresh chart, or a jump too far to be worth easing, is a cut.
              abs(previous - target) < window * 8
        else {
            state.displayRightEdge = target
            return target
        }

        // Read the frame delta without consuming it: the animation frame is
        // taken later in `draw`, after the identity reconcile that may reset it.
        let delta = state.peekDeltaMilliseconds(for: input.timestamp, isPaused: input.motion.isPaused)
        var next = LivelineMath.lerp(previous, target, speed: 0.22, deltaTime: delta)
        if abs(next - target) < window * 0.0005 { next = target }
        state.displayRightEdge = next
        return next
    }

    static func anchorTime(latestTime: TimeInterval?, timelineTimestamp: TimeInterval, window: TimeInterval) -> TimeInterval {
        guard let latest = latestTime else { return timelineTimestamp }
        if timelineTimestamp - latest > window * 2 {
            return latest
        }
        return max(timelineTimestamp, latest)
    }

    static func revealRamp(_ reveal: Double, _ start: Double, _ end: Double) -> Double {
        let t = LivelineMath.clamp((reveal - start) / (end - start), 0, 1)
        return t * t * (3 - 2 * t)
    }

    static func revealAmount(_ reveal: Double, _ start: Double, _ end: Double, fadeEffects: Bool) -> Double {
        fadeEffects ? revealRamp(reveal, start, end) : reveal
    }

    static func resolvedMomentum(config: LivelineChartConfiguration, points: [LivelinePoint]) -> LivelineMomentum {
        if let momentum = config.momentum { return momentum }
        guard config.autoDetectMomentum else { return .flat }
        return LivelineMath.detectMomentum(points: points)
    }

    static func valueRange(
        renderData: LivelinePreparedChart,
        smoothValue: Double,
        visibleTimeRange: ClosedRange<TimeInterval>,
        config: LivelineChartConfiguration
    ) -> ClosedRange<Double> {
        if let rangeOverride = renderData.rangeOverride {
            return rangeIncludingActivePoint(
                rangeOverride,
                renderData: renderData,
                visibleTimeRange: visibleTimeRange,
                config: config
            )
        }

        let range = LivelineMath.computeRange(
            points: renderData.rangePoints,
            currentValue: smoothValue,
            referenceValue: config.referenceLine?.value,
            exaggerate: config.exaggerate
        )
        return rangeIncludingActivePoint(
            range,
            renderData: renderData,
            visibleTimeRange: visibleTimeRange,
            config: config
        )
    }

    static func rangeIncludingActivePoint(
        _ range: ClosedRange<Double>,
        renderData: LivelinePreparedChart,
        visibleTimeRange: ClosedRange<TimeInterval>,
        config: LivelineChartConfiguration
    ) -> ClosedRange<Double> {
        guard let activePoint = config.activePoint,
              visibleTimeRange.contains(activePoint.time),
              let value = activePoint.value ?? LivelineMath.interpolateOrdered(points: renderData.primaryVisible, at: activePoint.time)
        else {
            return range
        }

        return min(range.lowerBound, value)...max(range.upperBound, value)
    }

    static func randomCGFloat(
        in range: ClosedRange<CGFloat>,
        state: LivelineRenderState,
        seed: UInt32?
    ) -> CGFloat {
        guard let seed else { return CGFloat.random(in: range) }
        let progress = CGFloat(state.nextRandom(seed: seed))
        return range.lowerBound + (range.upperBound - range.lowerBound) * progress
    }

}
