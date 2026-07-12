import Foundation
import SwiftUI

extension LivelineRenderer {
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
        let lineColor: Color = input.configuration.loading && input.semantics.identity.kind == .line
            ? palette.line
            : palette.gridLabel
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
                color: palette.emptyText,
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

        var targets: [Double: Double] = [:]
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
            let key = LivelineScalar.quantized(value, scale: 1_000)
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

        let visibleRows = state.gridLabelAlphas.compactMap { key, labelAlpha -> (key: Double, value: Double, y: CGFloat, alpha: Double)? in
            guard labelAlpha > 0.02 else { return nil }
            let value = key
            let y = layout.y(for: value)
            guard y >= layout.padding.top - 10, y <= layout.bottomY + 10 else { return nil }
            return (key, value, y, labelAlpha)
        }
        let centerY = layout.padding.top + layout.chartHeight / 2
        let labelKeys = LivelineMath.uniqueFormattedGridLabelKeys(
            candidates: visibleRows.map { row in
                let centerPreference = 1 - min(abs(row.y - centerY) / max(layout.chartHeight, 1), 1)
                return (row.key, row.value, row.alpha + Double(centerPreference) * 0.001)
            },
            formatValue: formatValue
        )

        for row in visibleRows {
            let key = row.key
            let value = row.value
            let y = row.y

            var rowLayer = layer
            rowLayer.opacity *= row.alpha

            var path = Path()
            path.move(to: CGPoint(x: layout.plotLeftX, y: y))
            path.addLine(to: CGPoint(x: layout.rightX, y: y))
            rowLayer.stroke(path, with: .color(palette.gridLine), style: StrokeStyle(lineWidth: 1, dash: [1, 3]))

            if labelKeys.contains(key) {
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
        var targets: Set<TimeInterval> = []
        while time <= layout.rightEdge + interval, time.isFinite, targets.count < 30 {
            let key = LivelineScalar.quantized(time, scale: 100)
            targets.insert(key)
            let text = formatTime(key)
            if state.timeAxisLabels[key] == nil {
                state.timeAxisLabels[key] = TimeAxisLabelState(alpha: fadeEffects ? 0 : 1, text: text)
            } else {
                state.timeAxisLabels[key]?.text = text
            }
            time += interval
        }

        for key in Array(state.timeAxisLabels.keys) {
            guard var label = state.timeAxisLabels[key] else { continue }
            let labelTime = key
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
            let time = key
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
