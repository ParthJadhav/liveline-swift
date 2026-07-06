import Foundation
import SwiftUI

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
    private static let loadingAmplitudeRatio: CGFloat = 0.14
    private static let loadingScrollSpeed: Double = 0.003
    private static let fadeEdgeWidth: CGFloat = 40

    static func draw(context: inout GraphicsContext, state: LivelineRenderState, input: LivelineRenderInput) {
        guard input.size.width > 8, input.size.height > 8 else { return }

        let dt = state.deltaTime(for: input.timestamp)
        let config = input.configuration
        let palette = LivelinePalette.resolve(accent: input.accent, mode: config.theme, lineWidth: config.lineWidth)
        let isMultiSeries = input.content.isMultiSeries
        let showBadge = !isMultiSeries && config.badge
        let resolvedPadding = resolvePadding(config.padding, showBadge: showBadge, showGrid: config.grid)
        let anchor = anchorTime(for: input.content, timelineTimestamp: input.timestamp, window: input.activeWindow)
        let rightEdge = anchor + input.activeWindow * (showBadge ? windowBuffer : windowBufferNoBadge)
        let leftEdge = rightEdge - input.activeWindow

        let renderData = renderData(for: input.content, hiddenSeries: input.hiddenSeries, leftEdge: leftEdge, rightEdge: rightEdge)
        let hasRenderableData = renderData.hasData
        let targetReveal = hasRenderableData && !config.loading ? 1.0 : 0.0
        let revealSpeed = targetReveal > state.chartReveal ? 0.09 : 0.14
        state.chartReveal = LivelineMath.lerp(state.chartReveal, targetReveal, speed: revealSpeed, deltaTime: dt)
        state.pauseProgress = LivelineMath.lerp(state.pauseProgress, config.paused ? 1 : 0, speed: 0.12, deltaTime: dt)
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
            state.displayMin = LivelineMath.lerp(state.displayMin ?? range.lowerBound, range.lowerBound, speed: 0.15, deltaTime: dt)
            state.displayMax = LivelineMath.lerp(state.displayMax ?? range.upperBound, range.upperBound, speed: 0.15, deltaTime: dt)
        }

        state.displayWindow = LivelineMath.lerp(state.displayWindow ?? input.activeWindow, input.activeWindow, speed: 0.08, deltaTime: dt)

        let layout = LivelineLayout(
            size: input.size,
            padding: resolvedPadding,
            minValue: state.displayMin ?? range.lowerBound,
            maxValue: state.displayMax ?? range.upperBound,
            leftEdge: leftEdge,
            rightEdge: rightEdge
        )

        if config.loading || !hasRenderableData {
            drawLoadingOrEmpty(context: &context, layout: layout, palette: palette, input: input, showText: !config.loading)
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

        if config.grid {
            drawGrid(context: &layer, layout: layout, palette: palette, formatValue: config.formatValue, alpha: revealRamp(state.chartReveal, 0.15, 0.70))
        }

        if let orderbook = config.orderbook, !isMultiSeries {
            drawOrderbook(context: &layer, layout: layout, palette: palette, state: state, orderbook: orderbook, deltaTime: dt, swingMagnitude: renderData.swingMagnitude, alpha: state.chartReveal)
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
                timestamp: input.timestamp
            )
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
                timestamp: input.timestamp,
                deltaTime: dt
            )

        case let .candle(_, _, candles, candleWidth, liveCandle, lineData, lineValue):
            if config.lineMode {
                let points = drawLine(
                    context: &layer,
                    layout: layout,
                    palette: palette,
                    points: renderData.primaryVisible.isEmpty ? lineData.visible(in: leftEdge...rightEdge) : renderData.primaryVisible,
                    smoothValue: lineValue ?? smoothValue,
                    now: anchor,
                    showFill: config.fill,
                    hoverX: hover?.x,
                    scrubAmount: scrubAmount,
                    reveal: state.chartReveal,
                    timestamp: input.timestamp
                )
                drawLineDecorations(
                    context: &layer,
                    state: state,
                    layout: layout,
                    palette: palette,
                    points: points,
                    momentum: resolvedMomentum(config: config, points: renderData.primaryVisible),
                    config: config,
                    hover: hover,
                    scrubAmount: scrubAmount,
                    timestamp: input.timestamp,
                    deltaTime: dt
                )
            } else {
                drawCandles(
                    context: &layer,
                    layout: layout,
                    palette: palette,
                    candles: candles.visibleCandles(in: leftEdge...rightEdge, candleWidth: candleWidth),
                    candleWidth: candleWidth,
                    liveCandle: liveCandle,
                    timestamp: input.timestamp,
                    scrubX: hover?.x,
                    scrubAmount: scrubAmount,
                    reveal: state.chartReveal
                )
                if let liveCandle {
                    drawCurrentPriceLine(context: &layer, layout: layout, palette: palette, value: liveCandle.close, isUp: liveCandle.close >= liveCandle.open, alpha: state.chartReveal * (1 - scrubAmount * 0.3))
                }
                drawCandleCrosshair(context: &layer, layout: layout, palette: palette, hover: hover, candles: candles, candleWidth: candleWidth, config: config, alpha: scrubAmount)
            }

        case let .series(series):
            drawSeries(
                context: &layer,
                state: state,
                layout: layout,
                series: series,
                hiddenSeries: input.hiddenSeries,
                config: config,
                timestamp: input.timestamp,
                hover: hover,
                alpha: state.chartReveal
            )
            drawMultiCrosshair(context: &layer, layout: layout, palette: palette, series: series, hiddenSeries: input.hiddenSeries, hover: hover, config: config, alpha: scrubAmount)
        }

        drawTimeAxis(context: &layer, layout: layout, palette: palette, window: input.activeWindow, formatTime: config.formatTime, alpha: revealRamp(state.chartReveal, 0.15, 0.70))
        drawLeftFade(context: &context, layout: layout)

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
    static func resolvePadding(_ padding: LivelinePadding, showBadge: Bool, showGrid: Bool) -> LivelineResolvedPadding {
        LivelineResolvedPadding(
            top: padding.top ?? 12,
            right: padding.right ?? (showBadge ? 80 : showGrid ? 54 : 12),
            bottom: padding.bottom ?? 28,
            left: padding.left ?? 12
        )
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
        switch content {
        case .candle(_, _, let candles, _, let liveCandle, _, _) where !config.lineMode:
            return LivelineMath.computeCandleRange(
                candles: candles,
                liveCandle: liveCandle,
                referenceValue: config.referenceLine?.value,
                exaggerate: config.exaggerate
            )
        default:
            return LivelineMath.computeRange(
                points: renderData.rangePoints,
                currentValue: smoothValue,
                referenceValue: config.referenceLine?.value,
                exaggerate: config.exaggerate
            )
        }
    }

    static func hoverState(input: LivelineRenderInput, layout: LivelineLayout, points: [LivelinePoint]) -> LivelineHoverPoint? {
        guard input.configuration.scrub,
              let hoverLocation = input.hoverLocation,
              hoverLocation.x >= layout.padding.left,
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
    var primaryValue: Double
    var swingMagnitude: Double

    var hasData: Bool {
        !rangePoints.isEmpty
    }
}

private extension LivelineRenderer {
    static func renderData(for content: LivelineChartContent, hiddenSeries: Set<String>, leftEdge: TimeInterval, rightEdge: TimeInterval) -> RenderData {
        switch content {
        case let .line(data, value):
            let visible = data.visible(in: (leftEdge - 2)...rightEdge)
            return RenderData(
                primaryVisible: visible,
                rangePoints: visible.isEmpty ? data.suffixArray(8) : visible,
                primaryValue: value,
                swingMagnitude: swingMagnitude(points: visible)
            )

        case let .candle(data, value, candles, _, liveCandle, lineData, lineValue):
            let visible = (lineData.isEmpty ? data : lineData).visible(in: (leftEdge - 2)...rightEdge)
            var range = visible
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
                primaryValue: lineValue ?? liveCandle?.close ?? value,
                swingMagnitude: swingMagnitude(points: visible)
            )

        case let .series(series):
            let visibleSeries = series.filter { !hiddenSeries.contains($0.id) }
            let visiblePoints = visibleSeries.flatMap { $0.data.visible(in: (leftEdge - 2)...rightEdge) }
            let fallback = visibleSeries.flatMap { $0.data.suffixArray(8) }
            let firstSeries = visibleSeries.first ?? series.first
            let primaryVisible = firstSeries?.data.visible(in: (leftEdge - 2)...rightEdge) ?? []
            return RenderData(
                primaryVisible: primaryVisible,
                rangePoints: visiblePoints.isEmpty ? fallback : visiblePoints,
                primaryValue: firstSeries?.value ?? 0,
                swingMagnitude: swingMagnitude(points: primaryVisible)
            )
        }
    }

    static func swingMagnitude(points: [LivelinePoint]) -> Double {
        guard points.count >= 6 else { return 0 }
        let tail = points.suffix(6)
        guard let first = tail.first?.value, let last = tail.last?.value else { return 0 }
        let values = tail.map(\.value)
        let range = max(0.001, (values.max() ?? last) - (values.min() ?? first))
        return min(abs(last - first) / range, 1)
    }
}

private extension LivelineRenderer {
    static func drawLoadingOrEmpty(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        input: LivelineRenderInput,
        showText: Bool
    ) {
        let centerY = layout.padding.top + layout.chartHeight / 2
        let amplitude = layout.chartHeight * loadingAmplitudeRatio
        let phase = input.timestamp * loadingScrollSpeed
        let count = max(12, Int(layout.chartWidth / 18))
        var points: [CGPoint] = []
        for index in 0..<count {
            let progress = CGFloat(index) / CGFloat(count - 1)
            let x = layout.padding.left + progress * layout.chartWidth
            let y = LivelineMath.loadingY(progress: progress, centerY: centerY, amplitude: amplitude, phase: phase)
            points.append(CGPoint(x: x, y: y))
        }

        var lineContext = context
        lineContext.opacity *= LivelineMath.loadingBreath(input.timestamp)
        lineContext.stroke(
            LivelineMath.monotoneSplinePath(points: points),
            with: .color(palette.gridLabel),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        )

        if showText {
            drawText(
                input.configuration.emptyText,
                context: &context,
                at: CGPoint(x: layout.size.width / 2, y: centerY + 34),
                anchor: .center,
                color: palette.gridLabel,
                font: .system(size: 13, weight: .medium, design: .monospaced)
            )
        }
    }

    static func drawGrid(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        formatValue: (Double) -> String,
        alpha: Double
    ) {
        guard alpha > 0.01 else { return }
        var layer = context
        layer.opacity *= alpha

        let ticks = 5
        for index in 0..<ticks {
            let progress = Double(index) / Double(ticks - 1)
            let value = layout.maxValue - (layout.maxValue - layout.minValue) * progress
            let y = layout.y(for: value)

            var path = Path()
            path.move(to: CGPoint(x: layout.padding.left, y: y))
            path.addLine(to: CGPoint(x: layout.rightX, y: y))
            layer.stroke(path, with: .color(palette.gridLine), lineWidth: 1)

            drawText(
                formatValue(value),
                context: &layer,
                at: CGPoint(x: layout.size.width - 4, y: y),
                anchor: .trailing,
                color: palette.gridLabel,
                font: .system(size: 11, weight: .regular, design: .monospaced)
            )
        }
    }

    static func drawTimeAxis(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        window: TimeInterval,
        formatTime: (TimeInterval) -> String,
        alpha: Double
    ) {
        guard alpha > 0.01, layout.size.width > 180 else { return }
        var layer = context
        layer.opacity *= alpha

        let count = layout.size.width > 420 ? 4 : 3
        for index in 0..<count {
            let progress = Double(index) / Double(count - 1)
            let time = layout.leftEdge + (layout.rightEdge - layout.leftEdge) * progress
            let x = layout.padding.left + CGFloat(progress) * layout.chartWidth
            let anchor: UnitPoint = index == 0 ? .leading : index == count - 1 ? .trailing : .center
            drawText(
                formatTime(time),
                context: &layer,
                at: CGPoint(x: x, y: layout.size.height - 8),
                anchor: anchor,
                color: palette.timeLabel,
                font: .system(size: 10, weight: .regular, design: .monospaced)
            )
        }

        _ = window
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

        var path = Path()
        path.move(to: CGPoint(x: layout.padding.left, y: y))
        path.addLine(to: CGPoint(x: layout.rightX, y: y))
        layer.stroke(path, with: .color(palette.referenceLine), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))

        let label = referenceLine.label ?? formatValue(referenceLine.value)
        drawText(
            label,
            context: &layer,
            at: CGPoint(x: layout.padding.left + 4, y: y - 8),
            anchor: .leading,
            color: palette.referenceLabel,
            font: .system(size: 10, weight: .medium, design: .monospaced)
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
        timestamp: TimeInterval
    ) -> [CGPoint] {
        guard !points.isEmpty else { return [] }

        let centerY = layout.padding.top + layout.chartHeight / 2
        let amplitude = layout.chartHeight * loadingAmplitudeRatio
        let phase = timestamp * loadingScrollSpeed

        func morphY(_ rawY: CGFloat, x: CGFloat) -> CGFloat {
            guard reveal < 1 else { return LivelineMath.clamp(rawY, layout.padding.top, layout.bottomY) }
            let progress = LivelineMath.clamp((x - layout.padding.left) / layout.chartWidth, 0, 1)
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
        let fullRight = layout.padding.left + layout.chartWidth
        let displayedTipX = reveal < 1 ? tipX + (fullRight - tipX) * CGFloat(1 - reveal) : tipX
        screenPoints.append(CGPoint(x: displayedTipX, y: morphY(layout.y(for: smoothValue), x: displayedTipX)))

        guard screenPoints.count >= 2 else { return screenPoints }

        let linePath = LivelineMath.monotoneSplinePath(points: screenPoints)
        let clipRect = CGRect(x: layout.padding.left - 1, y: layout.padding.top, width: layout.chartWidth + 2, height: layout.chartHeight)

        var clipped = context
        clipped.clip(to: Path(clipRect))

        let fillAlpha = reveal < 1 ? reveal : 1
        let lineAlpha = reveal < 1 ? LivelineMath.loadingBreath(timestamp) + (1 - LivelineMath.loadingBreath(timestamp)) * reveal : 1

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
            layer.stroke(
                linePath,
                with: .color(palette.line),
                style: StrokeStyle(lineWidth: palette.lineWidth, lineCap: .round, lineJoin: .round)
            )
        }

        if let hoverX, scrubAmount > 0 {
            var left = clipped
            left.clip(to: Path(CGRect(x: 0, y: 0, width: hoverX, height: layout.size.height)))
            stroke(&left, opacity: lineAlpha)

            var right = clipped
            right.clip(to: Path(CGRect(x: hoverX, y: 0, width: layout.size.width - hoverX, height: layout.size.height)))
            stroke(&right, opacity: lineAlpha * (1 - scrubAmount * 0.6))
        } else {
            stroke(&clipped, opacity: lineAlpha)
        }

        let currentY = reveal < 1
            ? centerY + (LivelineMath.clamp(layout.y(for: smoothValue), layout.padding.top, layout.bottomY) - centerY) * CGFloat(reveal)
            : LivelineMath.clamp(layout.y(for: smoothValue), layout.padding.top, layout.bottomY)
        var dash = Path()
        dash.move(to: CGPoint(x: layout.padding.left, y: currentY))
        dash.addLine(to: CGPoint(x: layout.rightX, y: currentY))
        var dashLayer = context
        dashLayer.opacity *= reveal * (1 - scrubAmount * 0.2)
        dashLayer.stroke(dash, with: .color(palette.dashLine), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

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
        timestamp: TimeInterval,
        deltaTime: TimeInterval
    ) {
        guard let lastPoint = points.last else { return }

        let dotAlpha = state.chartReveal < 0.3 ? 0 : (state.chartReveal - 0.3) / 0.7
        if dotAlpha > 0.01 {
            drawDot(context: &context, at: lastPoint, palette: palette, momentum: momentum, showPulse: config.pulse && state.pauseProgress < 0.5, scrubAmount: scrubAmount, alpha: dotAlpha, timestamp: timestamp)
        }

        if config.autoDetectMomentum || config.momentum != nil {
            drawMomentumArrows(context: &context, state: state, at: lastPoint, palette: palette, momentum: momentum, alpha: revealRamp(state.chartReveal, 0.60, 1) * (1 - state.pauseProgress), deltaTime: deltaTime, timestamp: timestamp)
        }

        if let degen = config.degen, state.chartReveal > 0.9 {
            updateParticles(state: state, origin: lastPoint, palette: palette, momentum: momentum, swingMagnitude: 0.7, options: degen, deltaTime: deltaTime)
            drawParticles(context: &context, state: state, deltaTime: deltaTime)
        }

        if config.badge {
            drawBadge(context: &context, layout: layout, palette: palette, value: layout.minValue + (layout.maxValue - layout.minValue) * Double((layout.bottomY - lastPoint.y) / layout.chartHeight), y: lastPoint.y, config: config, alpha: state.chartReveal)
        }

        if let hover {
            drawLineCrosshair(context: &context, layout: layout, palette: palette, hover: hover, livePoint: lastPoint, config: config, alpha: scrubAmount)
        }
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
        let glow: Color
        switch momentum {
        case .up:
            color = palette.dotUp
            glow = palette.glowUp
        case .down:
            color = palette.dotDown
            glow = palette.glowDown
        case .flat:
            color = palette.dotFlat
            glow = palette.glowFlat
        }

        var layer = context
        layer.opacity *= alpha * (1 - scrubAmount * 0.5)

        if showPulse {
            let pulse = 1 + CGFloat((sin(timestamp * 0.006) + 1) * 0.5)
            let rect = CGRect(x: point.x - 10 - pulse * 2, y: point.y - 10 - pulse * 2, width: 20 + pulse * 4, height: 20 + pulse * 4)
            layer.fill(Path(ellipseIn: rect), with: .color(glow.opacity(0.5)))
        }

        layer.fill(Path(ellipseIn: CGRect(x: point.x - 5.5, y: point.y - 5.5, width: 11, height: 11)), with: .color(color.opacity(0.22)))
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
        state.arrowUp = LivelineMath.lerp(state.arrowUp, momentum == .up ? 1 : 0, speed: 0.12, deltaTime: deltaTime)
        state.arrowDown = LivelineMath.lerp(state.arrowDown, momentum == .down ? 1 : 0, speed: 0.12, deltaTime: deltaTime)

        let amount = momentum == .up ? state.arrowUp : state.arrowDown
        guard amount > 0.02 else { return }

        let direction: CGFloat = momentum == .up ? -1 : 1
        let color = momentum == .up ? palette.dotUp : palette.dotDown
        let baseY = point.y + direction * 18
        let bob = CGFloat(sin(timestamp * 0.006)) * 2
        var layer = context
        layer.opacity *= alpha * amount

        for index in 0..<2 {
            let offset = CGFloat(index) * direction * 8 + bob
            var path = Path()
            let y = baseY + offset
            path.move(to: CGPoint(x: point.x - 5, y: y - direction * 2))
            path.addLine(to: CGPoint(x: point.x, y: y + direction * -7))
            path.addLine(to: CGPoint(x: point.x + 5, y: y - direction * 2))
            layer.stroke(path, with: .color(color.opacity(index == 0 ? 0.75 : 0.40)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}

private extension LivelineRenderer {
    static func drawBadge(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        value: Double,
        y: CGFloat,
        config: LivelineChartConfiguration,
        alpha: Double
    ) {
        guard alpha > 0.01 else { return }
        let text = config.formatValue(value)
        let font = Font.system(size: 11, weight: .semibold, design: .monospaced)
        let size = measureText(text, context: context, font: font)
        let width = max(44, size.width + 18)
        let height: CGFloat = 24
        let x = layout.size.width - width - 8
        let badgeY = LivelineMath.clamp(y - height / 2, layout.padding.top, layout.bottomY - height)
        let rect = CGRect(x: x, y: badgeY, width: width, height: height)
        var layer = context
        layer.opacity *= alpha

        let background = config.badgeVariant == .minimal ? palette.badgeOuterBackground : palette.badgeBackground
        let textColor = config.badgeVariant == .minimal ? palette.gridLabel : palette.badgeText
        layer.fill(Path(roundedRect: rect, cornerRadius: 7), with: .color(background))

        if config.badgeTail {
            var tail = Path()
            let midY = rect.midY
            tail.move(to: CGPoint(x: rect.minX, y: midY - 5))
            tail.addLine(to: CGPoint(x: rect.minX - 7, y: midY))
            tail.addLine(to: CGPoint(x: rect.minX, y: midY + 5))
            tail.closeSubpath()
            layer.fill(tail, with: .color(background))
        }

        drawText(text, context: &layer, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center, color: textColor, font: font)
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
        if distanceToLive < 5 {
            opacity = 0
        } else if distanceToLive >= fadeStart {
            opacity = alpha
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
        x = LivelineMath.clamp(x, layout.padding.left + 4, layout.rightX - measured.width - 4)
        let rect = CGRect(x: x - 7, y: layout.padding.top + config.tooltipY, width: measured.width + 14, height: measured.height + 8)

        layer.fill(Path(roundedRect: rect, cornerRadius: 6), with: .color(palette.tooltipBackground))
        layer.stroke(Path(roundedRect: rect, cornerRadius: 6), with: .color(palette.tooltipBorder), lineWidth: 1)
        drawText(label, context: &layer, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center, color: palette.tooltipText, font: font)
    }
}

private extension LivelineRenderer {
    static func drawCandles(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        candles: [LivelineCandle],
        candleWidth: TimeInterval,
        liveCandle: LivelineCandle?,
        timestamp: TimeInterval,
        scrubX: CGFloat?,
        scrubAmount: Double,
        reveal: Double
    ) {
        guard !candles.isEmpty || liveCandle != nil else { return }
        let allCandles = candles + [liveCandle].compactMap { $0 }
        let pxPerSecond = layout.chartWidth / CGFloat(max(0.001, layout.rightEdge - layout.leftEdge))
        let bodyWidth = max(1, candleWidth * pxPerSecond * 0.70)
        let wickWidth = max(0.8, min(2, bodyWidth * 0.15))
        let radius: CGFloat = bodyWidth > 6 ? 1.5 : 0

        var layer = context
        layer.opacity *= reveal
        layer.clip(to: Path(CGRect(x: layout.padding.left - 2, y: layout.padding.top, width: layout.chartWidth + 4, height: layout.chartHeight)))

        for candle in allCandles {
            let centerX = layout.x(for: candle.time + candleWidth / 2)
            let isLive = candle.time == liveCandle?.time
            let isUp = candle.close >= candle.open
            let color = isUp ? Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255) : Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255)

            var candleAlpha = isLive ? 0.9 + sin(timestamp * 0.004) * 0.1 : 1
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

            var wick = Path()
            wick.move(to: CGPoint(x: centerX, y: highY))
            wick.addLine(to: CGPoint(x: centerX, y: lowY))
            candleLayer.stroke(wick, with: .color(color), style: StrokeStyle(lineWidth: wickWidth, lineCap: .round))

            let rect = CGRect(x: centerX - bodyWidth / 2, y: top, width: bodyWidth, height: height)
            candleLayer.fill(Path(roundedRect: rect, cornerRadius: radius), with: .color(color))

            if isLive {
                candleLayer.fill(Path(roundedRect: rect.insetBy(dx: -2, dy: -2), cornerRadius: radius + 2), with: .color(color.opacity(0.10)))
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
        alpha: Double
    ) {
        let y = layout.y(for: value)
        guard y >= layout.padding.top, y <= layout.bottomY else { return }
        var path = Path()
        path.move(to: CGPoint(x: layout.padding.left, y: y))
        path.addLine(to: CGPoint(x: layout.rightX, y: y))
        var layer = context
        layer.opacity *= alpha * 0.45
        layer.stroke(path, with: .color(isUp ? Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255) : Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        _ = palette
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
        x = LivelineMath.clamp(x, layout.padding.left + 4, layout.rightX - measured.width - 4)
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
        hover: LivelineHoverPoint?,
        alpha: Double
    ) {
        for entry in series {
            let target = hiddenSeries.contains(entry.id) ? 0.0 : 1.0
            let current = state.seriesAlpha[entry.id] ?? target
            state.seriesAlpha[entry.id] = LivelineMath.lerp(current, target, speed: 0.10, deltaTime: 16.667)
            let entryAlpha = state.seriesAlpha[entry.id] ?? target
            guard entryAlpha > 0.01 else { continue }

            let palette = LivelinePalette.resolve(accent: entry.color, mode: config.theme, lineWidth: config.lineWidth)
            var layer = context
            layer.opacity *= entryAlpha * alpha
            let visible = entry.data.visible(in: (layout.leftEdge - 2)...layout.rightEdge)
            let points = visible.map { CGPoint(x: layout.x(for: $0.time), y: LivelineMath.clamp(layout.y(for: $0.value), layout.padding.top, layout.bottomY)) }
            guard points.count >= 2 else { continue }
            let path = LivelineMath.monotoneSplinePath(points: points)
            layer.stroke(path, with: .color(palette.line), style: StrokeStyle(lineWidth: palette.lineWidth, lineCap: .round, lineJoin: .round))

            if let last = points.last {
                drawDot(context: &layer, at: last, palette: palette, momentum: .flat, showPulse: config.pulse, scrubAmount: hover == nil ? 0 : 0.5, alpha: 1, timestamp: timestamp)
            }
        }
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
            x: LivelineMath.clamp(hover.x - measured.width / 2 - 8, layout.padding.left + 4, layout.rightX - measured.width - 18),
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
        deltaTime: TimeInterval,
        swingMagnitude: Double,
        alpha: Double
    ) {
        guard alpha > 0.01, !orderbook.bids.isEmpty || !orderbook.asks.isEmpty else { return }

        let bidTotal = orderbook.bids.reduce(0) { $0 + $1.size }
        let askTotal = orderbook.asks.reduce(0) { $0 + $1.size }
        let total = bidTotal + askTotal
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
        state.orderbookSpeed = LivelineMath.lerpCGFloat(state.orderbookSpeed, targetSpeed, speed: 0.12, deltaTime: deltaTime)

        let dtSeconds = deltaTime / 1000
        state.orderbookSpawnTimer += deltaTime
        let bottomY = layout.bottomY - 6
        let topY = layout.padding.top
        let allLevels = orderbook.bids.map { ($0.size, true) } + orderbook.asks.map { ($0.size, false) }
        let maxSize = max(0.001, allLevels.map(\.0).max() ?? 1)

        while state.orderbookSpawnTimer >= 40, state.orderbookLabels.count < 50, let picked = allLevels.randomElement() {
            state.orderbookSpawnTimer -= 40
            if state.orderbookLabels.contains(where: { abs($0.y - bottomY) < 22 }) { break }
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
            let color = label.isBid
                ? Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255).opacity(strength)
                : Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255).opacity(strength)
            drawText(label.text, context: &layer, at: CGPoint(x: layout.padding.left + 8, y: label.y), anchor: .leading, color: color, font: .system(size: 13, weight: .semibold, design: .monospaced))
        }

        _ = palette
        _ = total
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
                let angle = Double.random(in: 0...(Double.pi * 2))
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

    static func drawLeftFade(context: inout GraphicsContext, layout: LivelineLayout) {
        var rect = Path()
        rect.addRect(CGRect(x: 0, y: 0, width: layout.padding.left + fadeEdgeWidth, height: layout.size.height))
        context.blendMode = .destinationOut
        context.fill(
            rect,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black.opacity(0), location: 1),
                ]),
                startPoint: CGPoint(x: layout.padding.left, y: 0),
                endPoint: CGPoint(x: layout.padding.left + fadeEdgeWidth, y: 0)
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

    var latestTime: TimeInterval? {
        switch self {
        case let .line(data, _):
            return data.last?.time
        case let .candle(data, _, candles, candleWidth, liveCandle, lineData, _):
            return [
                data.last?.time,
                lineData.last?.time,
                candles.last.map { $0.time + candleWidth },
                liveCandle.map { $0.time + candleWidth },
            ].compactMap { $0 }.max()
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
