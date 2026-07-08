import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct LivelineRenderInput {
    var content: LivelineChartContent
    var accent: Color
    var configuration: LivelineChartConfiguration
    var activeWindow: TimeInterval
    var hiddenSeries: Set<String>
    var hoverLocation: CGPoint?
    var timestamp: TimeInterval
    var size: CGSize
}

enum LivelineChartContent {
    case line(data: [LivelinePoint], value: Double)
    case candle(
        data: [LivelinePoint],
        value: Double,
        candles: [LivelineCandle],
        candleWidth: TimeInterval,
        liveCandle: LivelineCandle?,
        lineData: [LivelinePoint],
        lineValue: Double?
    )
    case series([LivelineSeries])
}

enum LivelineRenderer {
    private static let windowBuffer = 0.05
    private static let windowBufferNoBadge = 0.015
    private static let loadingAmplitudeRatio: CGFloat = 0.07
    private static let loadingScrollSpeed: Double = 1.0
    private static let fadeEdgeWidth: CGFloat = 40
    private static let badgePaddingX: CGFloat = 10
    private static let badgePaddingY: CGFloat = 3
    private static let badgeTailLength: CGFloat = 5
    private static let badgeTailSpread: CGFloat = 2.5
    private static let badgeLineHeight: CGFloat = 16
    private static let axisLabelOffsetX: CGFloat = 7.33
    private static let orderbookTextStrokePercent: CGFloat = -31
    private static let orderbookTextOffsetX: CGFloat = -4
    private static let orderbookTextOffsetY: CGFloat = 0
    private static let candleLineMorphDuration: TimeInterval = 0.50
    private static let candleLineDensityDuration: TimeInterval = 0.35
    private static let candleLiveLerpSpeed = 0.25
    private static let candleCloseLineLerpSpeed = 0.25
    private static let candleLineLerpBase = 0.08
    private static let candleLineAdaptiveBoost = 0.20

    static func draw(context: inout GraphicsContext, state: LivelineRenderState, input: LivelineRenderInput) {
        guard input.size.width > 8, input.size.height > 8 else { return }

        let dt = state.deltaTime(for: input.timestamp)
        let animationTimestamp = state.animationTime(for: input.timestamp)
        let config = input.configuration
        let palette = LivelinePalette.resolve(accent: input.accent, mode: config.theme, lineWidth: config.lineWidth)
        let isMultiSeries = input.content.isMultiSeries
        let showBadge = !isMultiSeries && config.badge
        let resolvedPadding = resolvePadding(config.padding, badgeEnabled: config.badge, showGrid: config.grid)
        let anchor = anchorTime(for: input.content, timelineTimestamp: input.timestamp, window: input.activeWindow)
        let baseBuffer = input.content.isCandle ? windowBufferNoBadge : (showBadge ? windowBuffer : windowBufferNoBadge)
        let labelReveal = config.fadeEffects ? state.chartReveal : 1
        let dataLeftReserve = dataReserve(for: input.content, side: .leading, config: config, context: context, reveal: labelReveal)
        let dataRightReserve = dataReserve(for: input.content, side: .trailing, config: config, context: context, reveal: labelReveal)
        let chartWidth = max(1, input.size.width - resolvedPadding.left - resolvedPadding.right - dataLeftReserve - dataRightReserve)
        let needsArrowRoom = input.content.isSingleLine && showBadge && (config.autoDetectMomentum || config.momentum != nil)
        let buffer = needsArrowRoom ? max(baseBuffer, Double(37 / chartWidth)) : baseBuffer
        let rightEdge = anchor + input.activeWindow * buffer
        let leftEdge = rightEdge - input.activeWindow

        let renderData = renderData(for: input.content, hiddenSeries: input.hiddenSeries, leftEdge: leftEdge, rightEdge: rightEdge, config: config)
        let hasRenderableData = renderData.hasData
        let targetReveal = hasRenderableData && !config.loading ? 1.0 : 0.0
        if config.fadeEffects {
            let revealSpeed = targetReveal > state.chartReveal ? 0.09 : 0.14
            state.chartReveal = LivelineMath.lerp(state.chartReveal, targetReveal, speed: revealSpeed, deltaTime: dt)
        } else {
            state.chartReveal = targetReveal
        }
        state.pauseProgress = LivelineMath.lerp(state.pauseProgress, config.paused ? 1 : 0, speed: 0.12, deltaTime: dt)
        if abs(state.chartReveal - targetReveal) < 0.005 {
            state.chartReveal = targetReveal
        }
        if state.pauseProgress < 0.005 {
            state.pauseProgress = 0
        } else if state.pauseProgress > 0.995 {
            state.pauseProgress = 1
        }
        state.resetIfNeeded(anchorValue: renderData.primaryValue, window: input.activeWindow)

        let noMotion = input.configuration.paused
        let currentValue = renderData.primaryValue
        let previousSmooth = state.smoothValue ?? currentValue
        let rangeForSpeed = max(0.001, (state.displayMax ?? currentValue + 0.2) - (state.displayMin ?? currentValue - 0.2))
        let valueGap = abs(currentValue - previousSmooth)
        let adaptiveSpeed = config.lerpSpeed + (1 - min(valueGap / rangeForSpeed, 1)) * 0.20
        state.smoothValue = noMotion ? previousSmooth : LivelineMath.lerp(previousSmooth, currentValue, speed: adaptiveSpeed, deltaTime: dt)
        let smoothValue = state.smoothValue ?? currentValue

        let range = valueRange(for: input.content, renderData: renderData, smoothValue: smoothValue, config: config)
        if state.displayMin == nil || state.displayMax == nil {
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
            } else if input.content.isCandle {
                let gapMin = abs(currentMin - range.lowerBound)
                let gapMax = abs(currentMax - range.upperBound)
                let gapRatio = min((gapMin + gapMax) / currentRange, 1)
                rangeSpeed = 0.15 + (1 - gapRatio) * 0.20
            } else {
                rangeSpeed = noMotion ? 1 : adaptiveSpeed
            }

            var nextMin = LivelineMath.lerp(currentMin, range.lowerBound, speed: rangeSpeed, deltaTime: dt)
            var nextMax = LivelineMath.lerp(currentMax, range.upperBound, speed: rangeSpeed, deltaTime: dt)
            let pixelThreshold = max(0.001, 0.5 * currentRange / Double(chartHeight))
            if abs(nextMin - range.lowerBound) < pixelThreshold { nextMin = range.lowerBound }
            if abs(nextMax - range.upperBound) < pixelThreshold { nextMax = range.upperBound }
            state.displayMin = nextMin
            state.displayMax = nextMax
        }

        state.displayWindow = LivelineMath.lerp(state.displayWindow ?? input.activeWindow, input.activeWindow, speed: 0.08, deltaTime: dt)

        let layout = LivelineLayout(
            size: input.size,
            padding: resolvedPadding,
            minValue: state.displayMin ?? range.lowerBound,
            maxValue: state.displayMax ?? range.upperBound,
            leftEdge: leftEdge,
            rightEdge: rightEdge,
            dataLeftReserve: dataLeftReserve,
            dataRightReserve: dataRightReserve
        )
        let swingMagnitude = swingMagnitude(points: renderData.primaryVisible, valueRange: layout.maxValue - layout.minValue)

        if config.loading || !hasRenderableData {
            drawLoadingOrEmpty(context: &context, layout: layout, palette: palette, input: input, animationTimestamp: animationTimestamp, showText: !config.loading)
        }

        guard hasRenderableData else {
            config.onHover?(nil)
            return
        }

        var layer = context
        if state.shakeAmplitude > 0.2 {
            let x = CGFloat.random(in: -state.shakeAmplitude...state.shakeAmplitude)
            let y = CGFloat.random(in: -state.shakeAmplitude...state.shakeAmplitude)
            layer.translateBy(x: x, y: y)
            state.shakeAmplitude *= CGFloat(pow(0.002, dt / 1000))
            if state.shakeAmplitude < 0.2 { state.shakeAmplitude = 0 }
        }

        if config.referenceLine != nil, state.chartReveal > 0.01 {
            drawReferenceLine(context: &layer, layout: layout, palette: palette, referenceLine: config.referenceLine!, formatValue: config.formatValue, alpha: state.chartReveal)
        }

        if config.grid, !input.content.isCandle {
            drawGrid(context: &layer, layout: layout, palette: palette, state: state, formatValue: config.formatValue, alpha: revealAmount(state.chartReveal, 0.15, 0.70, fadeEffects: config.fadeEffects), fadeEffects: config.fadeEffects, deltaTime: dt)
        }

        if let orderbook = config.orderbook, !isMultiSeries, !input.content.isCandle {
            drawOrderbook(context: &layer, layout: layout, palette: palette, state: state, orderbook: orderbook, randomSeed: config.randomSeed, deltaTime: dt, swingMagnitude: swingMagnitude, alpha: state.chartReveal)
        }

        let hover = hoverState(input: input, layout: layout, points: renderData.primaryVisible)
        let scrubAmount = config.scrub && hover != nil ? 1.0 : 0.0

        switch input.content {
        case .line:
            let momentum = resolvedMomentum(config: config, points: renderData.primaryVisible)
            let points = drawLine(
                context: &layer,
                layout: layout,
                palette: palette,
                points: renderData.primaryVisible,
                smoothValue: smoothValue,
                now: anchor,
                showFill: config.fill,
                hoverX: hover?.x,
                scrubAmount: scrubAmount,
                reveal: state.chartReveal,
                timestamp: animationTimestamp,
                fadeEffects: config.fadeEffects
            )
            drawTimeAxis(context: &layer, layout: layout, palette: palette, state: state, window: input.activeWindow, formatTime: config.formatTime, alpha: revealAmount(state.chartReveal, 0.15, 0.70, fadeEffects: config.fadeEffects), fadeEffects: config.fadeEffects, deltaTime: dt)
            drawLineDecorations(
                context: &layer,
                state: state,
                layout: layout,
                palette: palette,
                points: points,
                momentum: momentum,
                config: config,
                hover: hover,
                scrubAmount: scrubAmount,
                smoothValue: smoothValue,
                swingMagnitude: swingMagnitude,
                timestamp: animationTimestamp,
                deltaTime: dt
            )
            drawActivePoint(
                context: &layer,
                layout: layout,
                palette: palette,
                points: renderData.primaryVisible,
                activePoint: config.activePoint,
                alpha: state.chartReveal,
                timestamp: animationTimestamp
            )

        case let .candle(_, _, candles, candleWidth, liveCandle, lineData, lineValue):
            drawCandleMode(
                context: &layer,
                state: state,
                layout: layout,
                palette: palette,
                candles: candles,
                candleWidth: candleWidth,
                liveCandle: liveCandle,
                lineData: lineData,
                lineValue: lineValue,
                config: config,
                hover: hover,
                scrubAmount: scrubAmount,
                now: anchor,
                leftEdge: leftEdge,
                rightEdge: rightEdge,
                activeWindow: input.activeWindow,
                reveal: state.chartReveal,
                timestamp: animationTimestamp,
                deltaTime: dt,
                smoothValue: smoothValue
            )
            drawActivePoint(
                context: &layer,
                layout: layout,
                palette: palette,
                points: renderData.primaryVisible,
                activePoint: config.activePoint,
                alpha: state.chartReveal,
                timestamp: animationTimestamp
            )

        case let .series(series):
            let endpoints = drawSeries(
                context: &layer,
                state: state,
                layout: layout,
                series: series,
                hiddenSeries: input.hiddenSeries,
                config: config,
                timestamp: animationTimestamp,
                now: anchor,
                hover: hover,
                deltaTime: dt,
                alpha: state.chartReveal
            )
            drawTimeAxis(context: &layer, layout: layout, palette: palette, state: state, window: input.activeWindow, formatTime: config.formatTime, alpha: revealAmount(state.chartReveal, 0.15, 0.70, fadeEffects: config.fadeEffects), fadeEffects: config.fadeEffects, deltaTime: dt)
            drawSeriesEndpoints(
                context: &layer,
                endpoints: endpoints,
                alpha: state.chartReveal,
                showPulse: config.pulse && state.chartReveal > 0.6 && state.pauseProgress < 0.5,
                timestamp: animationTimestamp,
                legendSide: config.seriesLegendSide
            )
            drawActivePoint(
                context: &layer,
                layout: layout,
                palette: palette,
                points: renderData.primaryVisible,
                activePoint: config.activePoint,
                alpha: state.chartReveal,
                timestamp: animationTimestamp
            )
            drawMultiCrosshair(context: &layer, layout: layout, palette: palette, series: series, hiddenSeries: input.hiddenSeries, hover: hover, config: config, alpha: scrubAmount)
        }

        if config.fadeEffects {
            drawLeftFade(context: &context, layout: layout)
        }

        if let hover {
            config.onHover?(hover)
            state.lastHover = hover
        } else if state.lastHover != nil {
            config.onHover?(nil)
            state.lastHover = nil
        }
    }
}

private extension LivelineRenderer {
    static func resolvePadding(_ padding: LivelinePadding, badgeEnabled: Bool, showGrid: Bool) -> LivelineResolvedPadding {
        LivelineResolvedPadding(
            top: padding.top ?? 12,
            right: padding.right ?? (badgeEnabled ? 80 : showGrid ? 54 : 12),
            bottom: padding.bottom ?? 28,
            left: padding.left ?? 12
        )
    }

    static func dataReserve(for content: LivelineChartContent, side: LivelineLegendSide, config: LivelineChartConfiguration, context: GraphicsContext, reveal: Double) -> CGFloat {
        guard config.seriesLegendSide == side else { return 0 }
        guard case let .series(series) = content else { return 0 }
        let font = Font.system(size: 10, weight: .semibold)
        let labels = series.compactMap(\.label)
        guard !labels.isEmpty else { return 0 }
        let maxLabelWidth = labels.reduce(CGFloat.zero) { current, label in
            max(current, measureText(label, context: context, font: font).width)
        }
        return max(0, maxLabelWidth - 2) * CGFloat(reveal)
    }

    static func anchorTime(for content: LivelineChartContent, timelineTimestamp: TimeInterval, window: TimeInterval) -> TimeInterval {
        guard let latest = content.latestTime else { return timelineTimestamp }
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
        for content: LivelineChartContent,
        renderData: RenderData,
        smoothValue: Double,
        config: LivelineChartConfiguration
    ) -> ClosedRange<Double> {
        if let rangeOverride = renderData.rangeOverride {
            return rangeIncludingActivePoint(rangeOverride, renderData: renderData, config: config)
        }

        let range: ClosedRange<Double>
        switch content {
        default:
            range = LivelineMath.computeRange(
                points: renderData.rangePoints,
                currentValue: smoothValue,
                referenceValue: config.referenceLine?.value,
                exaggerate: config.exaggerate
            )
        }
        return rangeIncludingActivePoint(range, renderData: renderData, config: config)
    }

    static func rangeIncludingActivePoint(
        _ range: ClosedRange<Double>,
        renderData: RenderData,
        config: LivelineChartConfiguration
    ) -> ClosedRange<Double> {
        guard let activePoint = config.activePoint,
              let value = activePoint.value ?? LivelineMath.interpolate(points: renderData.rangePoints, at: activePoint.time)
        else {
            return range
        }

        return min(range.lowerBound, value)...max(range.upperBound, value)
    }

    static func hoverState(input: LivelineRenderInput, layout: LivelineLayout, points: [LivelinePoint]) -> LivelineHoverPoint? {
        guard input.configuration.scrub,
              let hoverLocation = input.hoverLocation,
              hoverLocation.x >= layout.plotLeftX,
              hoverLocation.x <= layout.rightX,
              let value = LivelineMath.interpolate(points: points, at: layout.time(for: hoverLocation.x))
        else {
            return nil
        }

        let time = layout.time(for: hoverLocation.x)
        return LivelineHoverPoint(time: time, value: value, x: hoverLocation.x, y: layout.y(for: value))
    }
}

private struct RenderData {
    var primaryVisible: [LivelinePoint]
    var rangePoints: [LivelinePoint]
    var rangeOverride: ClosedRange<Double>?
    var primaryValue: Double

    var hasData: Bool {
        !rangePoints.isEmpty
    }
}

private extension LivelineRenderer {
    static func renderData(
        for content: LivelineChartContent,
        hiddenSeries: Set<String>,
        leftEdge: TimeInterval,
        rightEdge: TimeInterval,
        config: LivelineChartConfiguration
    ) -> RenderData {
        switch content {
        case let .line(data, value):
            let visible = data.visible(in: (leftEdge - 2)...rightEdge)
            return RenderData(
                primaryVisible: visible,
                rangePoints: visible.isEmpty ? data.suffixArray(8) : visible,
                rangeOverride: nil,
                primaryValue: value
            )

        case let .candle(data, value, candles, candleWidth, liveCandle, lineData, lineValue):
            let visible = (lineData.isEmpty ? data : lineData).visible(in: (leftEdge - 2)...rightEdge)
            var range = visible
            for candle in candles.visibleCandles(in: (leftEdge - 2)...rightEdge, candleWidth: candleWidth) {
                range.append(LivelinePoint(time: candle.time, value: candle.high))
                range.append(LivelinePoint(time: candle.time, value: candle.low))
            }
            if range.isEmpty {
                range = (lineData.isEmpty ? data : lineData).suffixArray(8)
            }
            if let liveCandle {
                range.append(LivelinePoint(time: liveCandle.time, value: liveCandle.high))
                range.append(LivelinePoint(time: liveCandle.time, value: liveCandle.low))
            } else if let last = candles.last {
                range.append(LivelinePoint(time: last.time, value: last.high))
                range.append(LivelinePoint(time: last.time, value: last.low))
            }
            return RenderData(
                primaryVisible: visible,
                rangePoints: range,
                rangeOverride: nil,
                primaryValue: lineValue ?? liveCandle?.close ?? value
            )

        case let .series(series):
            let visibleSeries = series.filter { !hiddenSeries.contains($0.id) }
            let visiblePoints = visibleSeries.flatMap { $0.data.visible(in: (leftEdge - 2)...rightEdge) }
            let fallback = visibleSeries.flatMap { $0.data.suffixArray(8) }
            let firstSeries = visibleSeries.first ?? series.first
            let primaryVisible = firstSeries?.data.visible(in: (leftEdge - 2)...rightEdge) ?? []
            var lower = Double.infinity
            var upper = -Double.infinity
            for entry in visibleSeries {
                let visible = entry.data.visible(in: (leftEdge - 2)...rightEdge)
                guard visible.count >= 2 else { continue }
                let range = LivelineMath.computeRange(
                    points: visible,
                    currentValue: entry.value,
                    referenceValue: config.referenceLine?.value,
                    exaggerate: config.exaggerate
                )
                lower = min(lower, range.lowerBound)
                upper = max(upper, range.upperBound)
            }
            return RenderData(
                primaryVisible: primaryVisible,
                rangePoints: visiblePoints.isEmpty ? fallback : visiblePoints,
                rangeOverride: lower.isFinite && upper.isFinite ? lower...upper : nil,
                primaryValue: firstSeries?.value ?? 0
            )
        }
    }

    static func swingMagnitude(points: [LivelinePoint], valueRange: Double) -> Double {
        guard points.count >= 2, valueRange > 0 else { return 0 }
        let lookback = min(5, points.count - 1)
        let recentDelta = abs(points[points.count - 1].value - points[points.count - 1 - lookback].value)
        return min(recentDelta / valueRange, 1)
    }
}

private extension LivelineRenderer {
    static func drawLoadingOrEmpty(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        input: LivelineRenderInput,
        animationTimestamp: TimeInterval,
        showText: Bool
    ) {
        let centerY = layout.padding.top + layout.chartHeight / 2
        let amplitude = layout.chartHeight * loadingAmplitudeRatio
        let phase = animationTimestamp * loadingScrollSpeed
        let count = 32
        var points: [CGPoint] = []
        for index in 0...count {
            let progress = CGFloat(index) / CGFloat(count)
            let x = layout.plotLeftX + progress * layout.chartWidth
            let y = LivelineMath.loadingY(progress: progress, centerY: centerY, amplitude: amplitude, phase: phase)
            points.append(CGPoint(x: x, y: y))
        }

        var lineContext = context
        lineContext.opacity *= LivelineMath.loadingBreath(animationTimestamp)
        let lineColor: Color = input.configuration.loading && input.content.isSingleLine ? palette.line : palette.gridLabel
        lineContext.stroke(
            LivelineMath.monotoneSplinePath(points: points),
            with: .color(lineColor),
            style: StrokeStyle(lineWidth: palette.lineWidth, lineCap: .round, lineJoin: .round)
        )

        if showText {
            let font = Font.system(size: 12, weight: .regular)
            let size = measureText(input.configuration.emptyText, context: context, font: font)
            let gapHalf = size.width / 2 + 20
            let fadeWidth: CGFloat = 30
            let gapLeft = layout.plotLeftX + layout.chartWidth / 2 - gapHalf - fadeWidth
            let gapRight = layout.plotLeftX + layout.chartWidth / 2 + gapHalf + fadeWidth
            let eraseHeight = amplitude * 2 + palette.lineWidth + 6
            context.fill(
                Path(CGRect(x: gapLeft, y: centerY - eraseHeight / 2, width: gapRight - gapLeft, height: eraseHeight)),
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: palette.backgroundRGB.withAlpha(0), location: 0),
                        .init(color: palette.backgroundRGB.color, location: fadeWidth / max(gapRight - gapLeft, 1)),
                        .init(color: palette.backgroundRGB.color, location: 1 - fadeWidth / max(gapRight - gapLeft, 1)),
                        .init(color: palette.backgroundRGB.withAlpha(0), location: 1),
                    ]),
                    startPoint: CGPoint(x: gapLeft, y: centerY),
                    endPoint: CGPoint(x: gapRight, y: centerY)
                )
            )
            drawText(
                input.configuration.emptyText,
                context: &context,
                at: CGPoint(x: layout.plotLeftX + layout.chartWidth / 2, y: centerY),
                anchor: .center,
                color: palette.gridLabel.opacity(0.35),
                font: font
            )
        }
    }

    static func drawGrid(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        state: LivelineRenderState,
        formatValue: (Double) -> String,
        alpha: Double,
        fadeEffects: Bool,
        deltaTime: TimeInterval
    ) {
        guard alpha > 0.01 else { return }
        var layer = context
        layer.opacity *= alpha

        let valueRange = layout.maxValue - layout.minValue
        guard valueRange > 0, layout.chartHeight > 0 else { return }
        let pxPerUnit = Double(layout.chartHeight) / valueRange
        let coarse = pickGridInterval(valueRange: valueRange, pxPerUnit: pxPerUnit, minGap: 36, previous: state.gridInterval)
        state.gridInterval = coarse
        let fine = coarse / 2
        let finePx = fine * pxPerUnit
        let fineTarget = finePx < 40 ? 0 : finePx >= 60 ? 1 : (finePx - 40) / 20

        var targets: [Int: Double] = [:]
        let first = ceil(layout.minValue / fine) * fine
        var value = first
        var count = 0
        while value <= layout.maxValue + fine * 0.5, count < 32 {
            let y = layout.y(for: value)
            defer {
                value += fine
                count += 1
            }
            guard y >= layout.padding.top - 2, y <= layout.bottomY + 2 else { continue }

            let edgeDistance = min(y - layout.padding.top, layout.bottomY - y)
            let edgeAlpha = max(0, min(1, edgeDistance / 32))
            let labelAlpha = (isDivisible(value, by: coarse) ? 1 : fineTarget) * Double(edgeAlpha)
            let key = Int((value * 1000).rounded())
            targets[key] = labelAlpha
        }

        for key in Array(state.gridLabelAlphas.keys) {
            let current = state.gridLabelAlphas[key] ?? 0
            let target = targets[key] ?? 0
            let speed = target >= current ? 0.18 : 0.12
            var next = fadeEffects ? LivelineMath.lerp(current, target, speed: speed, deltaTime: deltaTime) : target
            if abs(next - target) < 0.02 { next = target }
            if next < 0.01, target == 0 {
                state.gridLabelAlphas.removeValue(forKey: key)
            } else {
                state.gridLabelAlphas[key] = next
            }
        }

        for (key, target) in targets where state.gridLabelAlphas[key] == nil {
            state.gridLabelAlphas[key] = fadeEffects ? target * 0.18 : target
        }

        for (key, labelAlpha) in state.gridLabelAlphas {
            guard labelAlpha > 0.02 else { continue }
            let value = Double(key) / 1000
            let y = layout.y(for: value)
            guard y >= layout.padding.top - 10, y <= layout.bottomY + 10 else { continue }

            var rowLayer = layer
            rowLayer.opacity *= labelAlpha

            var path = Path()
            path.move(to: CGPoint(x: layout.plotLeftX, y: y))
            path.addLine(to: CGPoint(x: layout.rightX, y: y))
            rowLayer.stroke(path, with: .color(palette.gridLine), style: StrokeStyle(lineWidth: 1, dash: [1, 3]))

            drawText(
                formatValue(value),
                context: &rowLayer,
                at: CGPoint(x: layout.rightX + axisLabelOffsetX, y: y),
                anchor: .leading,
                color: palette.gridLabel,
                font: .system(size: 11, weight: .regular, design: .monospaced)
            )
        }
    }

    static func drawTimeAxis(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        state: LivelineRenderState,
        window: TimeInterval,
        formatTime: (TimeInterval) -> String,
        alpha: Double,
        fadeEffects: Bool,
        deltaTime: TimeInterval
    ) {
        guard alpha > 0.01, layout.size.width > 180 else { return }
        var layer = context
        layer.opacity *= alpha

        var axis = Path()
        axis.move(to: CGPoint(x: layout.plotLeftX, y: layout.bottomY))
        axis.addLine(to: CGPoint(x: layout.rightX, y: layout.bottomY))
        layer.stroke(axis, with: .color(palette.gridLine), lineWidth: 1)

        var interval = niceTimeInterval(window)
        let pxPerSecond = layout.chartWidth / CGFloat(max(window, 0.001))
        while CGFloat(interval) * pxPerSecond < 60, interval < window {
            interval *= 2
        }

        let first = ceil((layout.leftEdge - interval) / interval) * interval
        var time = first
        var targets: Set<Int> = []
        while time <= layout.rightEdge + interval, time.isFinite, targets.count < 30 {
            let key = Int((time * 100).rounded())
            targets.insert(key)
            let text = formatTime(Double(key) / 100)
            if state.timeAxisLabels[key] == nil {
                state.timeAxisLabels[key] = TimeAxisLabelState(alpha: fadeEffects ? 0 : 1, text: text)
            } else {
                state.timeAxisLabels[key]?.text = text
            }
            time += interval
        }

        for key in Array(state.timeAxisLabels.keys) {
            guard var label = state.timeAxisLabels[key] else { continue }
            let labelTime = Double(key) / 100
            let x = layout.x(for: labelTime)
            let isTarget = targets.contains(key)
            let edgeDistance = min(x - layout.plotLeftX, layout.rightX - x)
            let target = isTarget ? max(0, min(1, edgeDistance / 50)) : 0
            var next = fadeEffects ? LivelineMath.lerp(label.alpha, target, speed: 0.08, deltaTime: deltaTime) : target
            if abs(next - target) < 0.02 { next = target }
            if next < 0.01, target == 0 {
                state.timeAxisLabels.removeValue(forKey: key)
            } else {
                label.alpha = next
                state.timeAxisLabels[key] = label
            }
        }

        var labels: [(x: CGFloat, text: String, alpha: Double, width: CGFloat)] = []
        for (key, label) in state.timeAxisLabels {
            guard label.alpha > 0.02 else { continue }
            let time = Double(key) / 100
            let x = layout.x(for: time)
            guard x >= layout.plotLeftX - 20, x <= layout.rightX else {
                continue
            }

            let font = Font.system(size: 11, weight: .regular, design: .monospaced)
            let width = measureText(label.text, context: layer, font: font).width
            labels.append((x, label.text, label.alpha, width))
        }

        var drawn: [(x: CGFloat, text: String, alpha: Double, width: CGFloat)] = []
        for label in labels.sorted(by: { $0.x < $1.x }) {
            if let previous = drawn.last {
                let left = label.x - label.width / 2
                let previousRight = previous.x + previous.width / 2
                if left < previousRight + 8 {
                    if label.alpha > previous.alpha {
                        drawn[drawn.count - 1] = label
                    }
                    continue
                }
            }
            drawn.append(label)
        }

        for label in drawn where label.alpha > 0.02 {
            var tickLayer = layer
            tickLayer.opacity *= label.alpha

            var tick = Path()
            tick.move(to: CGPoint(x: label.x, y: layout.bottomY))
            tick.addLine(to: CGPoint(x: label.x, y: layout.bottomY + 5))
            tickLayer.stroke(tick, with: .color(palette.gridLine), lineWidth: 1)

            drawText(
                label.text,
                context: &tickLayer,
                at: CGPoint(x: label.x, y: layout.bottomY + 15),
                anchor: .center,
                color: palette.timeLabel,
                font: .system(size: 11, weight: .regular, design: .monospaced)
            )
        }
    }

    static func pickGridInterval(valueRange: Double, pxPerUnit: Double, minGap: Double, previous: Double = 0) -> Double {
        guard valueRange > 0, pxPerUnit > 0 else { return 1 }
        if previous > 0 {
            let previousPx = previous * pxPerUnit
            if previousPx >= minGap * 0.5, previousPx <= minGap * 4 {
                return previous
            }
        }

        let divisorSets: [[Double]] = [[2, 2.5, 2], [2, 2, 2.5], [2.5, 2, 2]]
        var best = Double.infinity
        for divisors in divisorSets {
            var span = pow(10, ceil(log10(valueRange)))
            var index = 0
            while span / divisors[index % divisors.count] * pxPerUnit >= minGap {
                span /= divisors[index % divisors.count]
                index += 1
            }
            best = min(best, span)
        }
        return best.isFinite ? best : max(valueRange / 5, 1)
    }

    static func isDivisible(_ value: Double, by interval: Double) -> Bool {
        guard interval > 0 else { return false }
        let ratio = value / interval
        return abs(ratio - ratio.rounded()) < 0.01
    }

    static func niceTimeInterval(_ window: TimeInterval) -> TimeInterval {
        if window <= 15 { return 2 }
        if window <= 30 { return 5 }
        if window <= 60 { return 10 }
        if window <= 120 { return 15 }
        if window <= 300 { return 30 }
        if window <= 600 { return 60 }
        if window <= 1_800 { return 300 }
        if window <= 3_600 { return 600 }
        if window <= 14_400 { return 1_800 }
        if window <= 43_200 { return 3_600 }
        if window <= 86_400 { return 7_200 }
        if window <= 604_800 { return 86_400 }
        return 604_800
    }

    static func drawReferenceLine(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        referenceLine: LivelineReferenceLine,
        formatValue: (Double) -> String,
        alpha: Double
    ) {
        let y = layout.y(for: referenceLine.value)
        guard y >= layout.padding.top - 2, y <= layout.bottomY + 2 else { return }
        var layer = context
        layer.opacity *= alpha

        let label = referenceLine.label ?? ""
        guard !label.isEmpty else {
            var path = Path()
            path.move(to: CGPoint(x: layout.plotLeftX, y: y))
            path.addLine(to: CGPoint(x: layout.rightX, y: y))
            layer.stroke(path, with: .color(palette.referenceLine), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            return
        }

        let font = Font.system(size: 11, weight: .medium)
        let labelWidth = measureText(label, context: layer, font: font).width
        let centerX = layout.plotLeftX + layout.chartWidth / 2
        let gapPad: CGFloat = 8

        var left = Path()
        left.move(to: CGPoint(x: layout.plotLeftX, y: y))
        left.addLine(to: CGPoint(x: centerX - labelWidth / 2 - gapPad, y: y))
        layer.stroke(left, with: .color(palette.referenceLine), lineWidth: 1)

        var right = Path()
        right.move(to: CGPoint(x: centerX + labelWidth / 2 + gapPad, y: y))
        right.addLine(to: CGPoint(x: layout.rightX, y: y))
        layer.stroke(right, with: .color(palette.referenceLine), lineWidth: 1)

        drawText(
            label,
            context: &layer,
            at: CGPoint(x: centerX, y: y),
            anchor: .center,
            color: palette.referenceLabel,
            font: font
        )
    }
}

private extension LivelineRenderer {
    @discardableResult
    static func drawLine(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        points: [LivelinePoint],
        smoothValue: Double,
        now: TimeInterval,
        showFill: Bool,
        hoverX: CGFloat?,
        scrubAmount: Double,
        reveal: Double,
        timestamp: TimeInterval,
        fadeEffects: Bool,
        colorBlend: Double = 1,
        skipDashLine: Bool = false,
        fillScale: Double = 1
    ) -> [CGPoint] {
        guard !points.isEmpty else { return [] }

        let centerY = layout.padding.top + layout.chartHeight / 2
        let amplitude = layout.chartHeight * loadingAmplitudeRatio
        let phase = timestamp * loadingScrollSpeed

        func morphY(_ rawY: CGFloat, x: CGFloat) -> CGFloat {
            guard reveal < 1 else { return LivelineMath.clamp(rawY, layout.padding.top, layout.bottomY) }
            let progress = LivelineMath.clamp((x - layout.plotLeftX) / layout.chartWidth, 0, 1)
            let centerDistance = abs(progress - 0.5) * 2
            let localReveal = LivelineMath.clamp((CGFloat(reveal) - centerDistance * 0.4) / 0.6, 0, 1)
            let loading = LivelineMath.loadingY(progress: progress, centerY: centerY, amplitude: amplitude, phase: phase)
            return loading + (LivelineMath.clamp(rawY, layout.padding.top, layout.bottomY) - loading) * localReveal
        }

        var screenPoints = points.enumerated().map { index, point in
            let x = layout.x(for: point.time)
            let value = index == points.count - 1 ? smoothValue : point.value
            return CGPoint(x: x, y: morphY(layout.y(for: value), x: x))
        }

        let tipX = layout.x(for: now)
        let fullRight = layout.plotLeftX + layout.chartWidth
        let displayedTipX = reveal < 1 ? tipX + (fullRight - tipX) * CGFloat(1 - reveal) : tipX
        screenPoints.append(CGPoint(x: displayedTipX, y: morphY(layout.y(for: smoothValue), x: displayedTipX)))

        guard screenPoints.count >= 2 else { return screenPoints }

        let linePath = LivelineMath.monotoneSplinePath(points: screenPoints)
        let clipRect = CGRect(x: layout.plotLeftX - 1, y: layout.padding.top, width: layout.chartWidth + 2, height: layout.chartHeight)

        var clipped = context
        clipped.clip(to: Path(clipRect))

        let fillAlpha = reveal < 1 ? reveal * fillScale : fillScale
        let lineAlpha = reveal < 1 ? LivelineMath.loadingBreath(timestamp) + (1 - LivelineMath.loadingBreath(timestamp)) * reveal : 1
        let scrubFadeAmount = fadeEffects ? scrubAmount : 0

        if showFill, fillAlpha > 0.01 {
            var fillPath = linePath
            fillPath.addLine(to: CGPoint(x: screenPoints.last!.x, y: layout.bottomY))
            fillPath.addLine(to: CGPoint(x: screenPoints.first!.x, y: layout.bottomY))
            fillPath.closeSubpath()

            var fillLayer = clipped
            fillLayer.opacity *= fillAlpha
            fillLayer.fill(
                fillPath,
                with: .linearGradient(
                    Gradient(colors: [palette.fillTop, palette.fillBottom]),
                    startPoint: CGPoint(x: 0, y: layout.padding.top),
                    endPoint: CGPoint(x: 0, y: layout.bottomY)
                )
            )
        }

        func stroke(_ target: inout GraphicsContext, opacity: Double) {
            var layer = target
            layer.opacity *= opacity
            let strokeColor: Color
            if reveal < 1 || colorBlend < 1 {
                let colorProgress = min(1, reveal * 3) * LivelineMath.clamp(colorBlend, 0, 1)
                strokeColor = palette.gridLabelRGB.blended(to: palette.lineRGB, t: colorProgress).color
            } else {
                strokeColor = palette.line
            }
            layer.stroke(
                linePath,
                with: .color(strokeColor),
                style: StrokeStyle(lineWidth: palette.lineWidth, lineCap: .round, lineJoin: .round)
            )
        }

        if let hoverX, scrubAmount > 0 {
            var left = clipped
            left.clip(to: Path(CGRect(x: 0, y: 0, width: hoverX, height: layout.size.height)))
            stroke(&left, opacity: lineAlpha)

            var right = clipped
            right.clip(to: Path(CGRect(x: hoverX, y: 0, width: layout.size.width - hoverX, height: layout.size.height)))
            stroke(&right, opacity: lineAlpha * (1 - scrubFadeAmount * 0.6))
        } else {
            stroke(&clipped, opacity: lineAlpha)
        }

        if !skipDashLine {
            let currentY = reveal < 1
                ? centerY + (LivelineMath.clamp(layout.y(for: smoothValue), layout.padding.top, layout.bottomY) - centerY) * CGFloat(reveal)
                : LivelineMath.clamp(layout.y(for: smoothValue), layout.padding.top, layout.bottomY)
            var dash = Path()
            dash.move(to: CGPoint(x: layout.plotLeftX, y: currentY))
            dash.addLine(to: CGPoint(x: layout.rightX, y: currentY))
            var dashLayer = context
            dashLayer.opacity *= reveal * (1 - scrubFadeAmount * 0.2)
            dashLayer.stroke(dash, with: .color(palette.dashLine), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }

        if let index = screenPoints.indices.last {
            screenPoints[index].y = LivelineMath.clamp(screenPoints[index].y, 10, layout.size.height - 10)
        }
        return screenPoints
    }

    static func drawLineDecorations(
        context: inout GraphicsContext,
        state: LivelineRenderState,
        layout: LivelineLayout,
        palette: LivelinePalette,
        points: [CGPoint],
        momentum: LivelineMomentum,
        config: LivelineChartConfiguration,
        hover: LivelineHoverPoint?,
        scrubAmount: Double,
        smoothValue: Double,
        swingMagnitude: Double,
        timestamp: TimeInterval,
        deltaTime: TimeInterval
    ) {
        guard let lastPoint = points.last else { return }

        let dotAlpha = state.chartReveal < 0.3 ? 0 : (state.chartReveal - 0.3) / 0.7
        if config.endpointDecorations, dotAlpha > 0.01 {
            drawDot(context: &context, at: lastPoint, palette: palette, momentum: momentum, showPulse: config.pulse && state.pauseProgress < 0.5, scrubAmount: config.fadeEffects ? scrubAmount : 0, alpha: dotAlpha, timestamp: timestamp)
        }

        if config.endpointDecorations && (config.autoDetectMomentum || config.momentum != nil) {
            drawMomentumArrows(context: &context, state: state, at: lastPoint, palette: palette, momentum: momentum, alpha: revealRamp(state.chartReveal, 0.60, 1) * (1 - state.pauseProgress), deltaTime: deltaTime, timestamp: timestamp)
        }

        if let degen = config.degen, state.chartReveal > 0.9 {
            updateParticles(state: state, origin: lastPoint, palette: palette, momentum: momentum, swingMagnitude: swingMagnitude, options: degen, deltaTime: deltaTime)
            drawParticles(context: &context, state: state, deltaTime: deltaTime)
        }

        if config.badge {
            drawBadge(context: &context, layout: layout, palette: palette, value: smoothValue, momentum: momentum, y: lastPoint.y, config: config, alpha: state.chartReveal)
        }

        if let hover {
            drawLineCrosshair(context: &context, layout: layout, palette: palette, hover: hover, livePoint: lastPoint, config: config, alpha: scrubAmount)
        }
    }

    static func drawActivePoint(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        points: [LivelinePoint],
        activePoint: LivelineActivePoint?,
        alpha: Double,
        timestamp: TimeInterval
    ) {
        guard let activePoint,
              alpha > 0.01,
              activePoint.time >= layout.leftEdge,
              activePoint.time <= layout.rightEdge,
              let value = activePoint.value ?? LivelineMath.interpolate(points: points, at: activePoint.time)
        else {
            return
        }

        let point = CGPoint(x: layout.x(for: activePoint.time), y: layout.y(for: value))
        guard point.x >= layout.plotLeftX - 1,
              point.x <= layout.rightX + 1,
              point.y >= layout.padding.top - 12,
              point.y <= layout.bottomY + 12
        else {
            return
        }

        drawDot(
            context: &context,
            at: point,
            palette: palette,
            momentum: .flat,
            showPulse: activePoint.pulse,
            scrubAmount: 0,
            alpha: alpha,
            timestamp: timestamp
        )
    }

    static func drawDot(
        context: inout GraphicsContext,
        at point: CGPoint,
        palette: LivelinePalette,
        momentum: LivelineMomentum,
        showPulse: Bool,
        scrubAmount: Double,
        alpha: Double,
        timestamp: TimeInterval
    ) {
        let color: Color
        switch momentum {
        case .up:
            color = palette.line
        case .down:
            color = palette.line
        case .flat:
            color = palette.dotFlat
        }

        var layer = context
        layer.opacity *= alpha * (1 - scrubAmount * 0.5)
        let dim = scrubAmount * 0.7

        if showPulse, dim < 0.3 {
            let t = (timestamp.truncatingRemainder(dividingBy: 1.5)) / 0.9
            if t < 1 {
                let radius = 9 + CGFloat(t) * 12
                let pulseAlpha = 0.35 * (1 - t) * (1 - dim * 3)
                layer.stroke(
                    Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(color.opacity(pulseAlpha)),
                    style: StrokeStyle(lineWidth: 1.5)
                )
            }
        }

        var outer = layer
        outer.addFilter(.shadow(color: palette.badgeOuterShadow, radius: 2.5 * (1 - dim), x: 0, y: 1))
        outer.fill(Path(ellipseIn: CGRect(x: point.x - 6.5, y: point.y - 6.5, width: 13, height: 13)), with: .color(palette.badgeOuterBackground))
        layer.fill(Path(ellipseIn: CGRect(x: point.x - 3.5, y: point.y - 3.5, width: 7, height: 7)), with: .color(color))
    }

    static func drawMomentumArrows(
        context: inout GraphicsContext,
        state: LivelineRenderState,
        at point: CGPoint,
        palette: LivelinePalette,
        momentum: LivelineMomentum,
        alpha: Double,
        deltaTime: TimeInterval,
        timestamp: TimeInterval
    ) {
        guard alpha > 0.01, momentum != .flat else { return }
        let upTarget = momentum == .up ? 1.0 : 0.0
        let downTarget = momentum == .down ? 1.0 : 0.0
        state.arrowUp = LivelineMath.lerp(state.arrowUp, (state.arrowDown < 0.02 ? upTarget : 0), speed: upTarget > state.arrowUp ? 0.08 : 0.04, deltaTime: deltaTime)
        state.arrowDown = LivelineMath.lerp(state.arrowDown, (state.arrowUp < 0.02 ? downTarget : 0), speed: downTarget > state.arrowDown ? 0.08 : 0.04, deltaTime: deltaTime)

        let amount = momentum == .up ? state.arrowUp : state.arrowDown
        guard amount > 0.02 else { return }

        let direction: CGFloat = momentum == .up ? -1 : 1
        let cycle = timestamp.truncatingRemainder(dividingBy: 1.4) / 1.4
        var layer = context
        layer.opacity *= alpha * amount

        for index in 0..<2 {
            let start = Double(index) * 0.2
            let duration = 0.35
            let local = cycle - start
            let wave = local >= 0 && local < duration ? sin((local / duration) * .pi) : 0
            let pulse = 0.3 + 0.7 * wave
            var arrowLayer = layer
            arrowLayer.opacity *= pulse
            var path = Path()
            let centerX = point.x + 19
            let nudge = momentum == .up ? CGFloat(-3) : CGFloat(3)
            let centerY = point.y + direction * (CGFloat(index) * 8 - 4) + nudge
            path.move(to: CGPoint(x: centerX - 5, y: centerY - direction * 3.5))
            path.addLine(to: CGPoint(x: centerX, y: centerY))
            path.addLine(to: CGPoint(x: centerX + 5, y: centerY - direction * 3.5))
            arrowLayer.stroke(path, with: .color(palette.gridLabel), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
    }
}

private extension LivelineRenderer {
    static func drawBadge(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        value: Double,
        momentum: LivelineMomentum,
        y: CGFloat,
        config: LivelineChartConfiguration,
        alpha: Double
    ) {
        guard alpha > 0.25 else { return }
        let text = config.formatValue(value)
        let template = text.map { $0.isNumber ? "8" : String($0) }.joined()
        let font = Font.system(size: 11, weight: .regular, design: .monospaced)
        let size = measureText(template, context: context, font: font)
        let tailLength = config.badgeTail ? badgeTailLength : 0
        let pillWidth = size.width + badgePaddingX * 2
        let pillHeight = badgeLineHeight + badgePaddingY * 2
        let totalWidth = tailLength + pillWidth
        let x = layout.rightX + 8 - badgePaddingX - tailLength
        let badgeY = LivelineMath.clamp(y - pillHeight / 2, layout.padding.top, layout.bottomY - pillHeight)
        var layer = context
        layer.opacity *= alpha < 0.5 ? (alpha - 0.25) / 0.25 : 1

        let background: Color
        if config.badgeVariant == .minimal {
            background = palette.badgeOuterBackground
            layer.addFilter(.shadow(color: palette.badgeOuterShadow, radius: 4, x: 0, y: 1))
        } else if config.autoDetectMomentum || config.momentum != nil {
            switch momentum {
            case .up:
                background = palette.dotUp
            case .down:
                background = palette.dotDown
            case .flat:
                background = palette.line
            }
        } else {
            background = palette.line
        }
        let textColor = config.badgeVariant == .minimal ? palette.tooltipText : palette.badgeText
        let path = config.badgeTail
            ? badgePath(origin: CGPoint(x: x, y: badgeY), pillWidth: pillWidth, pillHeight: pillHeight, tailLength: badgeTailLength, tailSpread: badgeTailSpread)
            : badgePillPath(origin: CGPoint(x: x, y: badgeY), pillWidth: pillWidth, pillHeight: pillHeight)
        layer.fill(path, with: .color(background))

        let textX = x + tailLength + pillWidth / 2
        drawText(text, context: &layer, at: CGPoint(x: textX, y: badgeY + pillHeight / 2 - 1), anchor: .center, color: textColor, font: font)
        _ = totalWidth
    }

    static func badgePath(origin: CGPoint, pillWidth: CGFloat, pillHeight: CGFloat, tailLength: CGFloat, tailSpread: CGFloat) -> Path {
        let r = pillHeight / 2
        let cx = origin.x + tailLength + pillWidth - r
        let tl = origin.x + tailLength + r
        let midY = origin.y + r
        var path = Path()
        path.move(to: CGPoint(x: tl, y: origin.y))
        path.addLine(to: CGPoint(x: cx, y: origin.y))
        path.addArc(center: CGPoint(x: cx, y: midY), radius: r, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: tl, y: origin.y + pillHeight))
        path.addCurve(
            to: CGPoint(x: origin.x, y: midY),
            control1: CGPoint(x: origin.x + tailLength + 2, y: origin.y + pillHeight),
            control2: CGPoint(x: origin.x + 3, y: midY + tailSpread)
        )
        path.addCurve(
            to: CGPoint(x: tl, y: origin.y),
            control1: CGPoint(x: origin.x + 3, y: midY - tailSpread),
            control2: CGPoint(x: origin.x + tailLength + 2, y: origin.y)
        )
        path.closeSubpath()
        return path
    }

    static func badgePillPath(origin: CGPoint, pillWidth: CGFloat, pillHeight: CGFloat) -> Path {
        Path(roundedRect: CGRect(x: origin.x, y: origin.y, width: pillWidth, height: pillHeight), cornerRadius: pillHeight / 2)
    }

    static func drawLineCrosshair(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        hover: LivelineHoverPoint,
        livePoint: CGPoint,
        config: LivelineChartConfiguration,
        alpha: Double
    ) {
        guard alpha > 0.01 else { return }
        let distanceToLive = livePoint.x - hover.x
        let fadeStart = min(80, layout.chartWidth * 0.3)
        let opacity: Double
        if !config.fadeEffects || distanceToLive >= fadeStart {
            opacity = alpha
        } else if distanceToLive < 5 {
            opacity = 0
        } else {
            opacity = Double((distanceToLive - 5) / (fadeStart - 5)) * alpha
        }
        guard opacity > 0.01 else { return }

        var layer = context
        layer.opacity *= opacity

        var vertical = Path()
        vertical.move(to: CGPoint(x: hover.x, y: layout.padding.top))
        vertical.addLine(to: CGPoint(x: hover.x, y: layout.bottomY))
        layer.stroke(vertical, with: .color(palette.crosshairLine), lineWidth: 1)

        layer.fill(Path(ellipseIn: CGRect(x: hover.x - 3, y: hover.y - 3, width: 6, height: 6)), with: .color(palette.line))

        let valueText = config.formatValue(hover.value)
        let timeText = config.formatTime(hover.time)
        let label = "\(valueText)  ·  \(timeText)"
        let font = Font.system(size: 11, weight: .medium, design: .monospaced)
        let measured = measureText(label, context: layer, font: font)
        var x = hover.x - measured.width / 2
        x = LivelineMath.clamp(x, layout.plotLeftX + 4, layout.rightX - measured.width - 4)
        let rect = CGRect(x: x - 7, y: layout.padding.top + config.tooltipY, width: measured.width + 14, height: measured.height + 8)

        layer.fill(Path(roundedRect: rect, cornerRadius: 6), with: .color(palette.tooltipBackground))
        layer.stroke(Path(roundedRect: rect, cornerRadius: 6), with: .color(palette.tooltipBorder), lineWidth: 1)
        drawText(label, context: &layer, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center, color: palette.tooltipText, font: font)
    }
}

private extension LivelineRenderer {
    static func drawCandleMode(
        context: inout GraphicsContext,
        state: LivelineRenderState,
        layout: LivelineLayout,
        palette: LivelinePalette,
        candles: [LivelineCandle],
        candleWidth: TimeInterval,
        liveCandle: LivelineCandle?,
        lineData: [LivelinePoint],
        lineValue: Double?,
        config: LivelineChartConfiguration,
        hover: LivelineHoverPoint?,
        scrubAmount: Double,
        now: TimeInterval,
        leftEdge: TimeInterval,
        rightEdge: TimeInterval,
        activeWindow: TimeInterval,
        reveal: Double,
        timestamp: TimeInterval,
        deltaTime: TimeInterval,
        smoothValue: Double
    ) {
        let pausedDeltaTime = deltaTime * (1 - state.pauseProgress)
        let lineModeTarget = config.lineMode ? 1.0 : 0.0
        state.candleLineModeProgress = state.timedProgress(
            current: state.candleLineModeProgress,
            target: lineModeTarget,
            duration: candleLineMorphDuration,
            timestamp: timestamp,
            transition: \.candleLineModeTransition
        )
        let lineModeProgress = state.candleLineModeProgress

        let smoothLive = smoothLiveCandle(state: state, liveCandle: liveCandle, deltaTime: pausedDeltaTime)
        updateCandleLineSmoothing(
            state: state,
            liveCandle: liveCandle,
            lineValue: lineValue,
            hasTickData: !lineData.isEmpty,
            displayMin: layout.minValue,
            displayMax: layout.maxValue,
            deltaTime: pausedDeltaTime
        )

        let hasTickData = !lineData.isEmpty
        let densityTarget = config.lineMode && lineModeProgress >= 0.30 && hasTickData ? 1.0 : 0.0
        state.candleLineDensityProgress = state.timedProgress(
            current: state.candleLineDensityProgress,
            target: densityTarget,
            duration: candleLineDensityDuration,
            timestamp: timestamp,
            transition: \.candleLineDensityTransition
        )
        let lineDensityProgress = state.candleLineDensityProgress

        var visibleCandles = candles.visibleCandles(in: leftEdge...rightEdge, candleWidth: candleWidth)
        if let smoothLive, smoothLive.time + candleWidth >= leftEdge, smoothLive.time <= rightEdge {
            visibleCandles.append(smoothLive)
        }

        var candlesToDraw = visibleCandles
        if lineModeProgress > 0.01,
           let live = smoothLive,
           let lineSmoothClose = state.candleLineSmoothClose {
            let blendedClose = live.close + (lineSmoothClose - live.close) * lineModeProgress
            let blendedLive = LivelineCandle(
                time: live.time,
                open: live.open,
                high: live.high,
                low: live.low,
                close: blendedClose
            )
            if let liveIndex = candlesToDraw.lastIndex(where: { $0.time == live.time }) {
                candlesToDraw[liveIndex] = blendedLive
            }
        }

        if lineModeProgress > 0.01, lineModeProgress < 0.99 {
            candlesToDraw = candlesToDraw.map { collapse(candle: $0, scale: 1 - lineModeProgress) }
        }

        let lineResult = candleLineData(
            candles: candlesToDraw,
            lineData: lineData,
            lineValue: lineValue,
            lineDensityProgress: lineDensityProgress,
            lineModeProgress: lineModeProgress,
            lineSmoothClose: state.candleLineSmoothClose,
            lineTickSmooth: state.candleLineTickSmooth,
            fallbackSmoothValue: smoothValue,
            candleWidth: candleWidth,
            leftEdge: leftEdge,
            rightEdge: rightEdge
        )

        let fullLineMode = lineModeProgress >= 0.99
        let revealLine = fullLineMode ? (1 - reveal) : pow(1 - reveal, 3)
        let linePresence = max(lineModeProgress, revealLine)
        let colorBlend = linePresence > 0.001 ? lineModeProgress / linePresence : 1
        let scrubFadeAmount = config.fadeEffects ? scrubAmount : 0

        if config.grid {
            drawGrid(
                context: &context,
                layout: layout,
                palette: palette,
                state: state,
                formatValue: config.formatValue,
                alpha: revealAmount(reveal, 0.25, 0.60, fadeEffects: config.fadeEffects),
                fadeEffects: config.fadeEffects,
                deltaTime: deltaTime
            )
        }

        var linePoints: [CGPoint] = []
        if linePresence > 0.01, lineResult.points.count >= 2 {
            var lineLayer = context
            lineLayer.opacity *= linePresence
            linePoints = drawLine(
                context: &lineLayer,
                layout: layout,
                palette: palette,
                points: paddedLinePointsForReveal(lineResult.points, leftEdge: leftEdge, rightEdge: rightEdge, reveal: reveal),
                smoothValue: lineResult.smoothValue,
                now: now,
                showFill: config.fill && lineModeProgress > 0.01,
                hoverX: hover?.x,
                scrubAmount: scrubAmount,
                reveal: reveal,
                timestamp: timestamp,
                fadeEffects: config.fadeEffects,
                colorBlend: colorBlend,
                skipDashLine: !fullLineMode,
                fillScale: lineModeProgress
            )
        }

        let closeAlpha = revealRamp(reveal, 0.40, 0.80)
        let closeSource = closePriceCandle(state: state, liveCandle: liveCandle)
        if let closeSource, closeAlpha > 0.01 {
            if linePresence < 0.99 {
                drawCurrentPriceLine(
                    context: &context,
                    layout: layout,
                    palette: palette,
                    value: closeSource.close,
                    isUp: closeSource.close >= closeSource.open,
                    alpha: closeAlpha * (1 - linePresence) * (1 - scrubFadeAmount * 0.3),
                    colorOverride: candleColor(isUp: closeSource.close >= closeSource.open, bullBlend: state.candleLiveBullBlend).color
                )
            }

            if linePresence > 0.01, !fullLineMode {
                drawCurrentPriceLine(
                    context: &context,
                    layout: layout,
                    palette: palette,
                    value: closeSource.close,
                    isUp: closeSource.close >= closeSource.open,
                    alpha: closeAlpha * linePresence * (1 - scrubFadeAmount * 0.2),
                    colorOverride: palette.dashLine,
                    opacityScale: 1
                )
            }
        }

        let candleAlpha = reveal * (1 - linePresence)
        if candleAlpha > 0.01, !candlesToDraw.isEmpty {
            let ohlcScale = smoothstep(reveal)
            let revealCandles = ohlcScale < 0.99
                ? candlesToDraw.map { collapse(candle: $0, scale: ohlcScale) }
                : candlesToDraw
            drawCandles(
                context: &context,
                layout: layout,
                palette: palette,
                candles: revealCandles,
                candleWidth: candleWidth,
                liveTime: smoothLive?.time,
                timestamp: timestamp,
                scrubX: hover?.x,
                scrubAmount: scrubFadeAmount,
                alpha: candleAlpha,
                liveBirthAlpha: state.candleLiveBirthAlpha,
                liveBullBlend: state.candleLiveBullBlend,
                accentBlend: linePresence
            )
        }

        if lineModeProgress > 0.5,
           let lastPoint = linePoints.last,
           reveal > 0.3 {
            let lineFade = (lineModeProgress - 0.5) * 2
            let dotAlpha = config.fadeEffects ? lineFade * ((reveal - 0.3) / 0.7) : lineFade
            if config.endpointDecorations, dotAlpha > 0.01 {
                drawDot(
                    context: &context,
                    at: lastPoint,
                    palette: palette,
                    momentum: resolvedMomentum(config: config, points: lineResult.points),
                    showPulse: config.pulse && lineModeProgress > 0.8 && reveal > 0.6 && state.pauseProgress < 0.5,
                    scrubAmount: scrubFadeAmount,
                    alpha: dotAlpha,
                    timestamp: timestamp
                )
            }

            if config.badge {
                drawBadge(
                    context: &context,
                    layout: layout,
                    palette: palette,
                    value: lineResult.smoothValue,
                    momentum: resolvedMomentum(config: config, points: lineResult.points),
                    y: lastPoint.y,
                    config: config,
                    alpha: reveal * lineFade
                )
            }
        }

        drawTimeAxis(
            context: &context,
            layout: layout,
            palette: palette,
            state: state,
            window: activeWindow,
            formatTime: config.formatTime,
            alpha: revealAmount(reveal, 0.25, 0.60, fadeEffects: config.fadeEffects),
            fadeEffects: config.fadeEffects,
            deltaTime: deltaTime
        )

        if reveal > 0.7 {
            if lineModeProgress > 0.5 {
                if let hover {
                    drawLineCrosshair(
                        context: &context,
                        layout: layout,
                        palette: palette,
                        hover: hover,
                        livePoint: linePoints.last ?? CGPoint(x: layout.rightX, y: layout.y(for: lineResult.smoothValue)),
                        config: config,
                        alpha: scrubAmount
                    )
                }
            } else {
                drawCandleCrosshair(
                    context: &context,
                    layout: layout,
                    palette: palette,
                    hover: hover,
                    candles: candlesToDraw,
                    candleWidth: candleWidth,
                    config: config,
                    alpha: scrubAmount
                )
            }
        }

    }

    static func smoothLiveCandle(
        state: LivelineRenderState,
        liveCandle: LivelineCandle?,
        deltaTime: TimeInterval
    ) -> LivelineCandle? {
        guard let liveCandle else {
            state.candleDisplayLive = nil
            state.candleLiveBirthAlpha = 1
            state.candleLiveBullBlend = 0.5
            return nil
        }

        if state.candleDisplayLive?.time != liveCandle.time {
            state.candleDisplayLive = LivelineCandle(
                time: liveCandle.time,
                open: liveCandle.open,
                high: liveCandle.open,
                low: liveCandle.open,
                close: liveCandle.open
            )
            state.candleLiveBirthAlpha = 0
        } else if var display = state.candleDisplayLive {
            display.open = LivelineMath.lerp(display.open, liveCandle.open, speed: candleLiveLerpSpeed, deltaTime: deltaTime)
            display.high = LivelineMath.lerp(display.high, liveCandle.high, speed: candleLiveLerpSpeed, deltaTime: deltaTime)
            display.low = LivelineMath.lerp(display.low, liveCandle.low, speed: candleLiveLerpSpeed, deltaTime: deltaTime)
            display.close = LivelineMath.lerp(display.close, liveCandle.close, speed: candleLiveLerpSpeed, deltaTime: deltaTime)
            state.candleDisplayLive = display
        }

        state.candleLiveBirthAlpha = LivelineMath.lerp(state.candleLiveBirthAlpha, 1, speed: 0.20, deltaTime: deltaTime)
        if state.candleLiveBirthAlpha > 0.99 { state.candleLiveBirthAlpha = 1 }

        if let display = state.candleDisplayLive {
            let bullTarget = display.close >= display.open ? 1.0 : 0.0
            state.candleLiveBullBlend = LivelineMath.lerp(state.candleLiveBullBlend, bullTarget, speed: 0.12, deltaTime: deltaTime)
            if state.candleLiveBullBlend > 0.99 { state.candleLiveBullBlend = 1 }
            if state.candleLiveBullBlend < 0.01 { state.candleLiveBullBlend = 0 }
        }

        return state.candleDisplayLive
    }

    static func updateCandleLineSmoothing(
        state: LivelineRenderState,
        liveCandle: LivelineCandle?,
        lineValue: Double?,
        hasTickData: Bool,
        displayMin: Double,
        displayMax: Double,
        deltaTime: TimeInterval
    ) {
        let range = max(0.001, displayMax - displayMin)

        if let liveCandle {
            if let current = state.candleCloseLineSmooth {
                var next = LivelineMath.lerp(current, liveCandle.close, speed: candleCloseLineLerpSpeed, deltaTime: deltaTime)
                if abs(next - liveCandle.close) < range * 0.0005 { next = liveCandle.close }
                state.candleCloseLineSmooth = next
            } else {
                state.candleCloseLineSmooth = liveCandle.close
            }

            if let current = state.candleLineSmoothClose {
                let gapRatio = min(abs(liveCandle.close - current) / range, 1)
                let speed = candleLineLerpBase + (1 - gapRatio) * candleLineAdaptiveBoost
                var next = LivelineMath.lerp(current, liveCandle.close, speed: speed, deltaTime: deltaTime)
                if abs(next - liveCandle.close) < range * 0.001 { next = liveCandle.close }
                state.candleLineSmoothClose = next
            } else {
                state.candleLineSmoothClose = liveCandle.close
            }
        } else {
            state.candleCloseLineSmooth = nil
            state.candleLineSmoothClose = nil
        }

        if let lineValue, hasTickData {
            if let current = state.candleLineTickSmooth {
                let gapRatio = min(abs(lineValue - current) / range, 1)
                let speed = candleLineLerpBase + (1 - gapRatio) * candleLineAdaptiveBoost
                var next = LivelineMath.lerp(current, lineValue, speed: speed, deltaTime: deltaTime)
                if abs(next - lineValue) < range * 0.001 { next = lineValue }
                state.candleLineTickSmooth = next
            } else {
                state.candleLineTickSmooth = lineValue
            }
        } else {
            state.candleLineTickSmooth = nil
        }
    }

    static func closePriceCandle(state: LivelineRenderState, liveCandle: LivelineCandle?) -> LivelineCandle? {
        guard var liveCandle else { return nil }
        if let close = state.candleCloseLineSmooth {
            liveCandle.close = close
        }
        return liveCandle
    }

    static func candleLineData(
        candles: [LivelineCandle],
        lineData: [LivelinePoint],
        lineValue: Double?,
        lineDensityProgress: Double,
        lineModeProgress: Double,
        lineSmoothClose: Double?,
        lineTickSmooth: Double?,
        fallbackSmoothValue: Double,
        candleWidth: TimeInterval,
        leftEdge: TimeInterval,
        rightEdge: TimeInterval
    ) -> (points: [LivelinePoint], smoothValue: Double) {
        let shouldUseTickData = !lineData.isEmpty && (lineDensityProgress > 0.01 || lineModeProgress > 0.05)
        if shouldUseTickData {
            let refs = candles.map {
                LivelinePoint(time: $0.time + candleWidth / 2, value: $0.close)
            }
            let visibleTicks = lineData.visible(in: leftEdge...rightEdge)
            let points = visibleTicks.map { point -> LivelinePoint in
                let close = LivelineMath.interpolate(points: refs, at: point.time) ?? point.value
                return LivelinePoint(
                    time: point.time,
                    value: close + (point.value - close) * lineDensityProgress
                )
            }
            let smoothTick = lineTickSmooth ?? lineValue ?? visibleTicks.last?.value ?? fallbackSmoothValue
            let smoothClose = lineSmoothClose ?? refs.last?.value ?? fallbackSmoothValue
            return (points, smoothClose + (smoothTick - smoothClose) * lineDensityProgress)
        }

        let points = candles.map {
            LivelinePoint(time: $0.time + candleWidth / 2, value: $0.close)
        }
        return (points, lineSmoothClose ?? points.last?.value ?? fallbackSmoothValue)
    }

    static func paddedLinePointsForReveal(
        _ points: [LivelinePoint],
        leftEdge: TimeInterval,
        rightEdge: TimeInterval,
        reveal: Double
    ) -> [LivelinePoint] {
        guard reveal < 1, points.count >= 2, let first = points.first else { return points }
        let span = rightEdge - leftEdge
        guard span > 0, first.time - leftEdge > span * 0.05 else { return points }
        let step = span / 32
        var padded: [LivelinePoint] = []
        var time = leftEdge
        while time < first.time - step * 0.5 {
            padded.append(LivelinePoint(time: time, value: first.value))
            time += step
        }
        padded.append(contentsOf: points)
        return padded
    }

    static func collapse(candle: LivelineCandle, scale: Double) -> LivelineCandle {
        LivelineCandle(
            time: candle.time,
            open: candle.close + (candle.open - candle.close) * scale,
            high: candle.close + (candle.high - candle.close) * scale,
            low: candle.close + (candle.low - candle.close) * scale,
            close: candle.close
        )
    }

    static func smoothstep(_ value: Double) -> Double {
        let t = LivelineMath.clamp(value, 0, 1)
        return t * t * (3 - 2 * t)
    }

    static func drawCandles(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        candles: [LivelineCandle],
        candleWidth: TimeInterval,
        liveTime: TimeInterval?,
        timestamp: TimeInterval,
        scrubX: CGFloat?,
        scrubAmount: Double,
        alpha: Double,
        liveBirthAlpha: Double = 1,
        liveBullBlend: Double = 0.5,
        accentBlend: Double = 0
    ) {
        guard !candles.isEmpty else { return }
        let pxPerSecond = layout.chartWidth / CGFloat(max(0.001, layout.rightEdge - layout.leftEdge))
        let bodyWidth = max(1, candleWidth * pxPerSecond * 0.70)
        let wickWidth = max(0.8, min(2, bodyWidth * 0.15))
        let radius: CGFloat = bodyWidth > 6 ? 1.5 : 0

        var layer = context
        layer.opacity *= alpha
        layer.clip(to: Path(CGRect(x: layout.plotLeftX - 2, y: layout.padding.top, width: layout.chartWidth + 4, height: layout.chartHeight)))

        for candle in candles {
            let centerX = layout.x(for: candle.time + candleWidth / 2)
            let isLive = candle.time == liveTime
            let isUp = candle.close >= candle.open
            let color = candleColor(isUp: isUp, bullBlend: isLive ? liveBullBlend : nil)
                .blended(to: palette.lineRGB, t: accentBlend)
                .color

            var candleAlpha = 1.0
            if isLive {
                candleAlpha *= liveBirthAlpha
            }
            if let scrubX, centerX > scrubX {
                let distance = min((centerX - scrubX) / max(bodyWidth * 1.5, 1), 1)
                candleAlpha *= 1 - scrubAmount * 0.5 * Double(distance)
            }

            var candleLayer = layer
            candleLayer.opacity *= candleAlpha

            let highY = LivelineMath.clamp(layout.y(for: candle.high), layout.padding.top, layout.bottomY)
            let lowY = LivelineMath.clamp(layout.y(for: candle.low), layout.padding.top, layout.bottomY)
            let openY = LivelineMath.clamp(layout.y(for: candle.open), layout.padding.top, layout.bottomY)
            let closeY = LivelineMath.clamp(layout.y(for: candle.close), layout.padding.top, layout.bottomY)
            let top = min(openY, closeY)
            let height = max(1, abs(closeY - openY))

            if top - highY > 0.5 {
                var upperWick = Path()
                upperWick.move(to: CGPoint(x: centerX, y: top))
                upperWick.addLine(to: CGPoint(x: centerX, y: highY))
                candleLayer.stroke(upperWick, with: .color(color), style: StrokeStyle(lineWidth: wickWidth, lineCap: .round))
            }
            if lowY - (top + height) > 0.5 {
                var lowerWick = Path()
                lowerWick.move(to: CGPoint(x: centerX, y: top + height))
                lowerWick.addLine(to: CGPoint(x: centerX, y: lowY))
                candleLayer.stroke(lowerWick, with: .color(color), style: StrokeStyle(lineWidth: wickWidth, lineCap: .round))
            }

            let rect = CGRect(x: centerX - bodyWidth / 2, y: top, width: bodyWidth, height: height)
            candleLayer.fill(Path(roundedRect: rect, cornerRadius: radius), with: .color(color))

            if isLive {
                let livePulse = 0.12 + sin(timestamp * 4) * 0.08
                var glowLayer = layer
                glowLayer.opacity *= candleAlpha * livePulse
                glowLayer.addFilter(.shadow(color: color, radius: 8, x: 0, y: 0))
                glowLayer.fill(Path(roundedRect: rect, cornerRadius: radius), with: .color(color))
            }
        }

        _ = palette
    }

    static func drawCurrentPriceLine(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        value: Double,
        isUp: Bool,
        alpha: Double,
        colorOverride: Color? = nil,
        opacityScale: Double = 0.4
    ) {
        let y = layout.y(for: value)
        guard y >= layout.padding.top, y <= layout.bottomY else { return }
        var path = Path()
        path.move(to: CGPoint(x: layout.plotLeftX, y: y))
        path.addLine(to: CGPoint(x: layout.rightX, y: y))
        var layer = context
        layer.opacity *= alpha * opacityScale
        layer.stroke(path, with: .color(colorOverride ?? candleColor(isUp: isUp).color), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        _ = palette
    }

    static func candleColor(isUp: Bool, bullBlend: Double? = nil) -> LivelineRGBA {
        let bear = LivelineRGBA(red: 239 / 255, green: 68 / 255, blue: 68 / 255, alpha: 1)
        let bull = LivelineRGBA(red: 34 / 255, green: 197 / 255, blue: 94 / 255, alpha: 1)
        if let bullBlend {
            return bear.blended(to: bull, t: bullBlend)
        }
        return isUp ? bull : bear
    }

    static func drawCandleCrosshair(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        hover: LivelineHoverPoint?,
        candles: [LivelineCandle],
        candleWidth: TimeInterval,
        config: LivelineChartConfiguration,
        alpha: Double
    ) {
        guard let hover, alpha > 0.01 else { return }
        let candleTime = floor(hover.time / candleWidth) * candleWidth
        guard let candle = candles.min(by: { abs($0.time - candleTime) < abs($1.time - candleTime) }) else { return }

        var layer = context
        layer.opacity *= alpha
        var vertical = Path()
        vertical.move(to: CGPoint(x: hover.x, y: layout.padding.top))
        vertical.addLine(to: CGPoint(x: hover.x, y: layout.bottomY))
        layer.stroke(vertical, with: .color(palette.crosshairLine), lineWidth: 1)

        let valueColor = candle.close >= candle.open ? Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255) : Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255)
        let text = layout.size.width >= 400
            ? "O \(config.formatValue(candle.open))   H \(config.formatValue(candle.high))   L \(config.formatValue(candle.low))   C \(config.formatValue(candle.close))  ·  \(config.formatTime(candle.time))"
            : "C \(config.formatValue(candle.close))  ·  \(config.formatTime(candle.time))"
        let font = Font.system(size: 11, weight: .medium, design: .monospaced)
        let measured = measureText(text, context: layer, font: font)
        var x = hover.x - measured.width / 2
        x = LivelineMath.clamp(x, layout.plotLeftX + 4, layout.rightX - measured.width - 4)
        let point = CGPoint(x: x + measured.width / 2, y: layout.padding.top + 24)
        drawText(text, context: &layer, at: point, anchor: .center, color: valueColor, font: font)
    }
}

private extension LivelineRenderer {
    static func drawSeries(
        context: inout GraphicsContext,
        state: LivelineRenderState,
        layout: LivelineLayout,
        series: [LivelineSeries],
        hiddenSeries: Set<String>,
        config: LivelineChartConfiguration,
        timestamp: TimeInterval,
        now: TimeInterval,
        hover: LivelineHoverPoint?,
        deltaTime: TimeInterval,
        alpha: Double
    ) -> [(point: CGPoint, palette: LivelinePalette, label: String?, alpha: Double)] {
        var endpointPoints: [(point: CGPoint, palette: LivelinePalette, label: String?, alpha: Double)] = []

        for entry in series {
            let target = hiddenSeries.contains(entry.id) ? 0.0 : 1.0
            let current = state.seriesAlpha[entry.id] ?? target
            state.seriesAlpha[entry.id] = config.fadeEffects ? LivelineMath.lerp(current, target, speed: 0.10, deltaTime: deltaTime) : target
            let entryAlpha = state.seriesAlpha[entry.id] ?? target
            guard entryAlpha > 0.01 else { continue }

            let palette = LivelinePalette.resolve(accent: entry.color, mode: config.theme, lineWidth: config.lineWidth)
            var layer = context
            layer.opacity *= entryAlpha * alpha
            let visible = entry.data.visible(in: (layout.leftEdge - 2)...layout.rightEdge)
            guard visible.count >= 2 else { continue }

            let points = drawLine(
                context: &layer,
                layout: layout,
                palette: palette,
                points: visible,
                smoothValue: entry.value,
                now: now,
                showFill: false,
                hoverX: hover?.x,
                scrubAmount: hover == nil ? 0 : 1,
                reveal: alpha,
                timestamp: timestamp,
                fadeEffects: config.fadeEffects
            )

            if let last = points.last {
                endpointPoints.append((last, palette, entry.label, entryAlpha))
            }
        }

        return endpointPoints
    }

    static func drawSeriesEndpoints(
        context: inout GraphicsContext,
        endpoints: [(point: CGPoint, palette: LivelinePalette, label: String?, alpha: Double)],
        alpha: Double,
        showPulse: Bool,
        timestamp: TimeInterval,
        legendSide: LivelineLegendSide
    ) {
        let dotAlpha = alpha < 0.3 ? 0 : (alpha - 0.3) / 0.7
        guard dotAlpha > 0.01 else { return }

        for endpoint in endpoints {
            var layer = context
            layer.opacity *= dotAlpha * endpoint.alpha
            drawMultiEndpointDot(
                context: &layer,
                at: endpoint.point,
                color: endpoint.palette.line,
                showPulse: showPulse && endpoint.alpha > 0.5,
                timestamp: timestamp
            )

            if let label = endpoint.label {
                let labelOffset: CGFloat = legendSide == .trailing ? 6 : -6
                let anchor: UnitPoint = legendSide == .trailing ? .leading : .trailing
                drawText(
                    label,
                    context: &layer,
                    at: CGPoint(x: endpoint.point.x + labelOffset, y: endpoint.point.y - 0.5),
                    anchor: anchor,
                    color: endpoint.palette.line,
                    font: .system(size: 10, weight: .semibold)
                )
            }
        }
    }

    static func drawMultiEndpointDot(
        context: inout GraphicsContext,
        at point: CGPoint,
        color: Color,
        showPulse: Bool,
        timestamp: TimeInterval
    ) {
        if showPulse {
            let t = timestamp.truncatingRemainder(dividingBy: 1.5) / 0.9
            if t < 1 {
                let radius = 9 + CGFloat(t) * 10
                let pulseAlpha = 0.3 * (1 - t)
                context.stroke(
                    Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(color.opacity(pulseAlpha)),
                    style: StrokeStyle(lineWidth: 1.5)
                )
            }
        }

        context.fill(Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)), with: .color(color))
    }

    static func drawMultiCrosshair(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        series: [LivelineSeries],
        hiddenSeries: Set<String>,
        hover: LivelineHoverPoint?,
        config: LivelineChartConfiguration,
        alpha: Double
    ) {
        guard let hover, alpha > 0.01 else { return }
        var layer = context
        layer.opacity *= alpha
        var vertical = Path()
        vertical.move(to: CGPoint(x: hover.x, y: layout.padding.top))
        vertical.addLine(to: CGPoint(x: hover.x, y: layout.bottomY))
        layer.stroke(vertical, with: .color(palette.crosshairLine), lineWidth: 1)

        var rows: [String] = []
        for entry in series where !hiddenSeries.contains(entry.id) {
            if let value = LivelineMath.interpolate(points: entry.data, at: hover.time) {
                rows.append("\(entry.label ?? entry.id) \(config.formatValue(value))")
            }
        }
        guard !rows.isEmpty else { return }
        let text = rows.prefix(4).joined(separator: "  ·  ")
        let font = Font.system(size: 11, weight: .medium, design: .monospaced)
        let measured = measureText(text, context: layer, font: font)
        let rect = CGRect(
            x: LivelineMath.clamp(hover.x - measured.width / 2 - 8, layout.plotLeftX + 4, layout.rightX - measured.width - 18),
            y: layout.padding.top + config.tooltipY,
            width: measured.width + 16,
            height: measured.height + 8
        )
        layer.fill(Path(roundedRect: rect, cornerRadius: 6), with: .color(palette.tooltipBackground))
        layer.stroke(Path(roundedRect: rect, cornerRadius: 6), with: .color(palette.tooltipBorder), lineWidth: 1)
        drawText(text, context: &layer, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center, color: palette.tooltipText, font: font)
    }
}

private extension LivelineRenderer {
    static func drawOrderbook(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        state: LivelineRenderState,
        orderbook: LivelineOrderbookData,
        randomSeed: UInt32?,
        deltaTime: TimeInterval,
        swingMagnitude: Double,
        alpha: Double
    ) {
        guard alpha > 0.01, !orderbook.bids.isEmpty || !orderbook.asks.isEmpty else { return }

        let bidTotal = orderbook.bids.reduce(0) { $0 + $1.size }
        let askTotal = orderbook.asks.reduce(0) { $0 + $1.size }
        let previousTotal = state.previousBidTotal + state.previousAskTotal
        var churn = 0.0
        if previousTotal > 0 {
            churn = min((abs(bidTotal - state.previousBidTotal) + abs(askTotal - state.previousAskTotal)) / previousTotal, 1)
        }
        state.previousBidTotal = bidTotal
        state.previousAskTotal = askTotal
        state.churnRate += (churn - state.churnRate) * (churn > state.churnRate ? 0.3 : 0.05)

        let activity = max(min(swingMagnitude * 5, 1), state.churnRate)
        let targetSpeed = CGFloat(60 + activity * 100)
        state.orderbookSpeed = LivelineMath.lerpCGFloat(state.orderbookSpeed, targetSpeed, speed: 0.05, deltaTime: deltaTime)

        let dtSeconds = deltaTime / 1000
        state.orderbookSpawnTimer += deltaTime
        let bottomY = layout.bottomY - 6
        let topY = layout.padding.top
        let allLevels = orderbook.bids.map { ($0.size, true) } + orderbook.asks.map { ($0.size, false) }
        let maxSize = max(0.001, allLevels.map(\.0).max() ?? 1)
        let totalWeight = allLevels.reduce(0) { $0 + max(0, $1.0) }

        while state.orderbookSpawnTimer >= 40, state.orderbookLabels.count < 50, totalWeight > 0 {
            state.orderbookSpawnTimer -= 40
            if state.orderbookLabels.contains(where: { abs($0.y - bottomY) < 22 }) { break }
            let randomUnit = randomSeed.map { state.nextOrderbookRandom(seed: $0) } ?? Double.random(in: 0..<1)
            var remaining = randomUnit * totalWeight
            var picked = allLevels[0]
            for level in allLevels {
                remaining -= max(0, level.0)
                if remaining <= 0 {
                    picked = level
                    break
                }
            }
            state.orderbookLabels.append(
                OrderbookLabel(
                    y: bottomY,
                    text: "+ \(formatOrderSize(picked.0))",
                    isBid: picked.1,
                    life: 6,
                    maxLife: 6,
                    intensity: 0.5 + min(picked.0 / maxSize, 1) * 0.5
                )
            )
        }

        for index in state.orderbookLabels.indices {
            let progress = (state.orderbookLabels[index].y - topY) / max(1, bottomY - topY)
            state.orderbookLabels[index].life -= dtSeconds
            state.orderbookLabels[index].y -= state.orderbookSpeed * (0.7 + 0.3 * progress) * CGFloat(dtSeconds)
        }
        state.orderbookLabels.removeAll { $0.life <= 0 || $0.y < topY - 14 }

        var layer = context
        layer.opacity *= alpha
        for label in state.orderbookLabels {
            let lifeRatio = label.life / label.maxLife
            let fadeIn = min((1 - lifeRatio) * 10, 1)
            let yRatio = Double((label.y - topY) / layout.chartHeight)
            let fadeOut = yRatio < 0.45 ? yRatio / 0.45 : 1
            let strength = label.intensity * fadeIn * fadeOut
            let baseColor = label.isBid
                ? LivelineRGBA(red: 34 / 255, green: 197 / 255, blue: 94 / 255, alpha: 1)
                : LivelineRGBA(red: 239 / 255, green: 68 / 255, blue: 68 / 255, alpha: 1)
            let fill = baseColor.blended(to: palette.backgroundRGB, t: 1 - strength)
            drawOrderbookText(
                label.text,
                context: &layer,
                at: CGPoint(x: layout.plotLeftX + 8, y: label.y),
                fill: fill,
                outline: palette.backgroundRGB
            )
        }
    }

    static func updateParticles(
        state: LivelineRenderState,
        origin: CGPoint,
        palette: LivelinePalette,
        momentum: LivelineMomentum,
        swingMagnitude: Double,
        options: LivelineDegenOptions,
        deltaTime: TimeInterval
    ) {
        let shouldSpawn = momentum == .up || (momentum == .down && options.downMomentum)
        if shouldSpawn, state.previousMomentum != momentum {
            let count = Int((8 + swingMagnitude * 14) * options.scale)
            for _ in 0..<count {
                let angle = CGFloat.random(in: 0...(CGFloat.pi * 2))
                let speed = CGFloat.random(in: 35...120) * CGFloat(options.scale)
                let velocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
                let color = momentum == .up ? palette.dotUp : palette.dotDown
                state.particles.append(Particle(position: origin, velocity: velocity, color: color, radius: CGFloat.random(in: 1.5...3.5), life: 0.55, maxLife: 0.55))
            }
            state.shakeAmplitude = CGFloat(3 + swingMagnitude * 4)
        }
        state.previousMomentum = momentum
        _ = deltaTime
    }

    static func drawParticles(context: inout GraphicsContext, state: LivelineRenderState, deltaTime: TimeInterval) {
        let dt = deltaTime / 1000
        for index in state.particles.indices {
            state.particles[index].life -= dt
            state.particles[index].position.x += state.particles[index].velocity.dx * CGFloat(dt)
            state.particles[index].position.y += state.particles[index].velocity.dy * CGFloat(dt)
            state.particles[index].velocity.dy += 30 * CGFloat(dt)
        }
        state.particles.removeAll { $0.life <= 0 }

        for particle in state.particles {
            var layer = context
            layer.opacity *= particle.life / particle.maxLife
            layer.fill(Path(ellipseIn: CGRect(x: particle.position.x - particle.radius, y: particle.position.y - particle.radius, width: particle.radius * 2, height: particle.radius * 2)), with: .color(particle.color))
        }
    }

    static func formatOrderSize(_ size: Double) -> String {
        if size >= 10 { return "$\(Int(size.rounded()))" }
        if size >= 1 { return String(format: "$%.1f", size) }
        return String(format: "$%.2f", size)
    }

    static func drawOrderbookText(
        _ text: String,
        context: inout GraphicsContext,
        at point: CGPoint,
        fill: LivelineRGBA,
        outline: LivelineRGBA
    ) {
        #if canImport(UIKit) && !os(watchOS) && !os(visionOS)
        let font = UIFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
        let fillColor = UIColor(red: fill.red, green: fill.green, blue: fill.blue, alpha: fill.alpha)
        let outlineColor = UIColor(red: outline.red, green: outline.green, blue: outline.blue, alpha: outline.alpha)
        let image = orderbookTextImage(text: text, font: font, fill: fillColor, outline: outlineColor, scale: UIScreen.main.scale)
        let swiftUIImage = Image(uiImage: image)
        let size = image.size
        context.draw(swiftUIImage, in: CGRect(x: point.x + orderbookTextOffsetX, y: point.y - size.height / 2 + orderbookTextOffsetY, width: size.width, height: size.height))
        #elseif canImport(AppKit)
        let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
        let fillColor = NSColor(srgbRed: fill.red, green: fill.green, blue: fill.blue, alpha: fill.alpha)
        let outlineColor = NSColor(srgbRed: outline.red, green: outline.green, blue: outline.blue, alpha: outline.alpha)
        let image = orderbookTextImage(text: text, font: font, fill: fillColor, outline: outlineColor, scale: NSScreen.main?.backingScaleFactor ?? 2)
        let swiftUIImage = Image(nsImage: image)
        let size = image.size
        context.draw(swiftUIImage, in: CGRect(x: point.x + orderbookTextOffsetX, y: point.y - size.height / 2 + orderbookTextOffsetY, width: size.width, height: size.height))
        #else
        drawOutlinedText(
            text,
            context: &context,
            at: point,
            anchor: .leading,
            fill: fill.color,
            outline: outline.color,
            font: .system(size: 13, weight: .semibold, design: .monospaced)
        )
        #endif
    }

    #if canImport(UIKit) && !os(watchOS) && !os(visionOS)
    static func orderbookTextImage(text: String, font: UIFont, fill: UIColor, outline: UIColor, scale: CGFloat) -> UIImage {
        let padding: CGFloat = 4
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let measured = (text as NSString).size(withAttributes: attributes)
        let size = CGSize(width: ceil(measured.width + padding * 2), height: ceil(measured.height + padding * 2))
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            (text as NSString).draw(
                at: CGPoint(x: padding, y: padding),
                withAttributes: [
                    .font: font,
                    .foregroundColor: outline,
                    .strokeColor: outline,
                    .strokeWidth: abs(orderbookTextStrokePercent),
                ]
            )
            (text as NSString).draw(
                at: CGPoint(x: padding, y: padding),
                withAttributes: [
                    .font: font,
                    .foregroundColor: fill,
                ]
            )
        }
    }
    #elseif canImport(AppKit)
    static func orderbookTextImage(text: String, font: NSFont, fill: NSColor, outline: NSColor, scale: CGFloat) -> NSImage {
        let padding: CGFloat = 4
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let measured = (text as NSString).size(withAttributes: attributes)
        let size = CGSize(width: ceil(measured.width + padding * 2), height: ceil(measured.height + padding * 2))
        let image = NSImage(size: size)
        image.lockFocus()
        (text as NSString).draw(
            at: CGPoint(x: padding, y: padding),
            withAttributes: [
                .font: font,
                .foregroundColor: outline,
                .strokeColor: outline,
                .strokeWidth: abs(orderbookTextStrokePercent),
            ]
        )
        (text as NSString).draw(
            at: CGPoint(x: padding, y: padding),
            withAttributes: [
                .font: font,
                .foregroundColor: fill,
            ]
        )
        image.unlockFocus()
        return image
    }
    #endif

    static func drawLeftFade(context: inout GraphicsContext, layout: LivelineLayout) {
        var rect = Path()
        rect.addRect(CGRect(x: 0, y: 0, width: layout.plotLeftX + fadeEdgeWidth, height: layout.size.height))
        context.blendMode = .destinationOut
        context.fill(
            rect,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black.opacity(0), location: 1),
                ]),
                startPoint: CGPoint(x: layout.plotLeftX, y: 0),
                endPoint: CGPoint(x: layout.plotLeftX + fadeEdgeWidth, y: 0)
            )
        )
        context.blendMode = .normal
    }
}

private extension LivelineRenderer {
    static func drawText(
        _ text: String,
        context: inout GraphicsContext,
        at point: CGPoint,
        anchor: UnitPoint,
        color: Color,
        font: Font
    ) {
        context.draw(Text(text).font(font).foregroundColor(color), at: point, anchor: anchor)
    }

    static func drawOutlinedText(
        _ text: String,
        context: inout GraphicsContext,
        at point: CGPoint,
        anchor: UnitPoint,
        fill: Color,
        outline: Color,
        font: Font
    ) {
        let radius: CGFloat = 2
        for offset in [
            CGPoint(x: -radius, y: 0),
            CGPoint(x: radius, y: 0),
            CGPoint(x: 0, y: -radius),
            CGPoint(x: 0, y: radius),
            CGPoint(x: -radius * 0.7, y: -radius * 0.7),
            CGPoint(x: radius * 0.7, y: -radius * 0.7),
            CGPoint(x: -radius * 0.7, y: radius * 0.7),
            CGPoint(x: radius * 0.7, y: radius * 0.7),
        ] {
            context.draw(
                Text(text).font(font).foregroundColor(outline),
                at: CGPoint(x: point.x + offset.x, y: point.y + offset.y),
                anchor: anchor
            )
        }
        context.draw(Text(text).font(font).foregroundColor(fill), at: point, anchor: anchor)
    }

    static func measureText(_ text: String, context: GraphicsContext, font: Font) -> CGSize {
        let resolved = context.resolve(Text(text).font(font))
        return resolved.measure(in: CGSize(width: 10_000, height: 10_000))
    }

}

private extension LivelineChartContent {
    var isMultiSeries: Bool {
        if case .series = self { return true }
        return false
    }

    var isSingleLine: Bool {
        if case .line = self { return true }
        return false
    }

    var isCandle: Bool {
        if case .candle = self { return true }
        return false
    }

    var latestTime: TimeInterval? {
        switch self {
        case let .line(data, _):
            return data.last?.time
        case let .candle(data, _, candles, candleWidth, liveCandle, lineData, _):
            let liveTickTime = [
                data.last?.time,
                lineData.last?.time,
                liveCandle?.time,
            ].compactMap { $0 }.max()
            return liveTickTime ?? candles.last.map { $0.time + candleWidth }
        case let .series(series):
            return series.compactMap { $0.data.last?.time }.max()
        }
    }
}

private extension Array where Element == LivelinePoint {
    func visible(in range: ClosedRange<TimeInterval>) -> [LivelinePoint] {
        filter { range.contains($0.time) }
    }

    func suffixArray(_ maxLength: Int) -> [LivelinePoint] {
        Array(suffix(maxLength))
    }
}

private extension Array where Element == LivelineCandle {
    func visibleCandles(in range: ClosedRange<TimeInterval>, candleWidth: TimeInterval) -> [LivelineCandle] {
        filter { candle in
            range.overlaps(candle.time...(candle.time + candleWidth))
        }
    }
}
