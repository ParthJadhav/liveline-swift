import Foundation
import SwiftUI

extension LivelineRenderer {
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

        if showFill,
           fillAlpha > 0.01,
           let firstPoint = screenPoints.first,
           let lastPoint = screenPoints.last {
            var fillPath = linePath
            fillPath.addLine(to: CGPoint(x: lastPoint.x, y: layout.bottomY))
            fillPath.addLine(to: CGPoint(x: firstPoint.x, y: layout.bottomY))
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
            if (reveal < 1 || colorBlend < 1), let lineRGB = palette.lineRGB {
                let colorProgress = min(1, reveal * 3) * LivelineMath.clamp(colorBlend, 0, 1)
                strokeColor = palette.gridLabelRGB.blended(to: lineRGB, t: colorProgress).color
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
            updateParticles(
                state: state,
                origin: lastPoint,
                palette: palette,
                momentum: momentum,
                swingMagnitude: swingMagnitude,
                options: degen,
                randomSeed: config.randomSeed,
                deltaTime: deltaTime
            )
            drawParticles(context: &context, state: state, deltaTime: deltaTime)
        }

        if config.badge {
            drawBadge(context: &context, layout: layout, palette: palette, value: smoothValue, momentum: momentum, y: lastPoint.y, config: config, alpha: state.chartReveal)
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

extension LivelineRenderer {
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
        if config.tooltipOutline {
            layer.stroke(Path(roundedRect: rect, cornerRadius: 6), with: .color(palette.tooltipBorder), lineWidth: 1)
        }
        drawText(label, context: &layer, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center, color: palette.tooltipText, font: font)
    }
}
