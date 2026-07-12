import Foundation
import SwiftUI

extension LivelineRenderer {
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
        reveal: Double,
        timestamp: TimeInterval,
        deltaTime: TimeInterval,
        smoothValue: Double
    ) -> LivelineCandleOverlay {
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

        var visibleCandles = candles.livelineVisible(in: leftEdge...rightEdge, candleWidth: candleWidth)
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

        return LivelineCandleOverlay(
            lineModeProgress: lineModeProgress,
            linePoints: linePoints,
            smoothValue: lineResult.smoothValue,
            candles: candlesToDraw,
            candleWidth: candleWidth,
            reveal: reveal
        )
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
            let visibleTicks = lineData.livelineVisible(in: leftEdge...rightEdge)
            let points = visibleTicks.map { point -> LivelinePoint in
                let close = LivelineMath.interpolateOrdered(points: refs, at: point.time) ?? point.value
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
            let candleRGB = candleColor(isUp: isUp, bullBlend: isLive ? liveBullBlend : nil)
            let color = palette.lineRGB.map { candleRGB.blended(to: $0, t: accentBlend).color }
                ?? (accentBlend >= 0.5 ? palette.line : candleRGB.color)

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
