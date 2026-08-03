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
            let font = input.textScale.font(12, weight: .regular)
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
        textScale: LivelineTextScale,
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
        // Taller labels need proportionally more room before they collide.
        let coarse = pickGridInterval(
            valueRange: valueRange,
            pxPerUnit: pxPerUnit,
            minGap: Double(textScale.scaled(36)),
            previous: state.gridInterval
        )
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
                // The value axis lives in the gutter beside the live edge, so
                // it moves — and its labels flip their anchor — in RTL.
                drawText(
                    formatValue(value),
                    context: &rowLayer,
                    at: CGPoint(
                        x: layout.isRTL
                            ? layout.plotLeftX - axisLabelOffsetX
                            : layout.rightX + axisLabelOffsetX,
                        y: y
                    ),
                    anchor: layout.isRTL ? .trailing : .leading,
                    color: palette.gridLabel,
                    font: textScale.font(11, weight: .regular, design: .monospaced)
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
        textScale: LivelineTextScale,
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
        while CGFloat(interval) * pxPerSecond < textScale.scaled(60), interval < window {
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
            } else if state.timeAxisLabels[key]?.text != text {
                state.timeAxisLabels[key]?.text = text
                state.timeAxisLabels[key]?.measuredWidth = nil
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
            // A label may hang slightly past the edge data scrolls off, but not
            // past the live edge; both bounds follow the reading direction.
            let slackMin = layout.isRTL ? layout.plotLeftX : layout.plotLeftX - 20
            let slackMax = layout.isRTL ? layout.rightX + 20 : layout.rightX
            guard x >= slackMin, x <= slackMax else {
                continue
            }

            // Measuring resolves the text through the graphics context, so keep
            // the result until the label text — or the type size behind it —
            // changes. `LivelineRenderState.adoptTextScale` drops the widths on
            // a Dynamic Type change so this never returns a stale measurement.
            let width: CGFloat
            if let measured = label.measuredWidth {
                width = measured
            } else {
                let font = textScale.font(11, weight: .regular, design: .monospaced)
                width = measureText(label.text, context: layer, font: font).width
                state.timeAxisLabels[key]?.measuredWidth = width
            }
            labels.append((x, label.text, label.alpha, width))
        }

        var drawn: [(x: CGFloat, text: String, alpha: Double, width: CGFloat)] = []
        for label in labels.sorted(by: { $0.x < $1.x }) {
            if let previous = drawn.last {
                let left = label.x - label.width / 2
                let previousRight = previous.x + previous.width / 2
                if left < previousRight + textScale.scaled(8) {
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
                font: textScale.font(11, weight: .regular, design: .monospaced)
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

    /// Draws the shaded annotation bands. Called after the grid and before the
    /// marks, so a band reads as a backdrop rather than a highlight over data.
    static func drawReferenceBands(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        bands: [LivelineReferenceBand],
        textScale: LivelineTextScale,
        alpha: Double
    ) {
        guard !bands.isEmpty, alpha > 0.01 else { return }
        var layer = context
        layer.opacity *= alpha

        for band in bands {
            guard let rect = LivelineAnnotationGeometry.rect(for: band, layout: layout) else { continue }
            let color = band.color ?? palette.referenceLine
            layer.fill(Path(rect), with: .color(color.opacity(band.opacity.livelineClamped(0, 1, fallback: 0.12))))

            guard let label = band.label, !label.isEmpty else { continue }
            let font = textScale.font(11, weight: .medium)
            drawText(
                label,
                context: &layer,
                at: CGPoint(
                    x: layout.isRTL ? rect.maxX - 6 : rect.minX + 6,
                    y: rect.minY + textScale.scaled(9)
                ),
                anchor: layout.isRTL ? .trailing : .leading,
                color: palette.referenceLabel,
                font: font
            )
        }
    }

    /// Draws the additional annotation lines, matching the single reference
    /// line's layering so a chart that uses both reads consistently.
    static func drawReferenceLines(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        lines: [LivelineReferenceLine],
        textScale: LivelineTextScale,
        alpha: Double
    ) {
        guard !lines.isEmpty, alpha > 0.01 else { return }
        var layer = context
        layer.opacity *= alpha

        for line in lines {
            guard let position = LivelineAnnotationGeometry.position(for: line, layout: layout) else { continue }
            let color = line.color ?? palette.referenceLine
            let style = StrokeStyle(lineWidth: 1, dash: line.dash.pattern)
            let font = textScale.font(11, weight: .medium)
            let label = line.label ?? ""

            switch line.axis {
            case .value:
                var path = Path()
                path.move(to: CGPoint(x: layout.plotLeftX, y: position))
                path.addLine(to: CGPoint(x: layout.rightX, y: position))
                layer.stroke(path, with: .color(color), style: style)
                if !label.isEmpty {
                    drawText(
                        label,
                        context: &layer,
                        at: CGPoint(
                            x: layout.isRTL ? layout.rightX - 6 : layout.plotLeftX + 6,
                            y: position - textScale.scaled(8)
                        ),
                        anchor: layout.isRTL ? .trailing : .leading,
                        color: palette.referenceLabel,
                        font: font
                    )
                }

            case .time:
                var path = Path()
                path.move(to: CGPoint(x: position, y: layout.padding.top))
                path.addLine(to: CGPoint(x: position, y: layout.bottomY))
                layer.stroke(path, with: .color(color), style: style)
                if !label.isEmpty {
                    drawText(
                        label,
                        context: &layer,
                        at: CGPoint(
                            x: position + 4 * layout.forwardXDirection,
                            y: layout.padding.top + textScale.scaled(8)
                        ),
                        anchor: layout.isRTL ? .trailing : .leading,
                        color: palette.referenceLabel,
                        font: font
                    )
                }
            }
        }
    }

    static func drawReferenceLine(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        referenceLine: LivelineReferenceLine,
        formatValue: (Double) -> String,
        textScale: LivelineTextScale,
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

        let font = textScale.font(11, weight: .medium)
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

/// Maps annotation models onto plot coordinates.
///
/// Split out from the drawing code so the mapping — value to `y`, time to `x`,
/// and the clipping that keeps an off-screen annotation from drawing — can be
/// exercised without a graphics context.
enum LivelineAnnotationGeometry {
    /// The line's position along the axis it crosses: `y` for a `.value` line,
    /// `x` for a `.time` line. Returns `nil` when the line falls outside the
    /// plot.
    static func position(for line: LivelineReferenceLine, layout: LivelineLayout) -> CGFloat? {
        guard line.value.isFinite else { return nil }
        switch line.axis {
        case .value:
            let y = layout.y(for: line.value)
            guard y.isFinite, y >= layout.padding.top - 2, y <= layout.bottomY + 2 else { return nil }
            return y
        case .time:
            let x = layout.x(for: line.value)
            guard x.isFinite, x >= layout.plotLeftX - 2, x <= layout.rightX + 2 else { return nil }
            return x
        }
    }

    /// The band's rectangle inside the plot, clamped to the plot's bounds.
    ///
    /// Inverted bounds are normalized by ``LivelineReferenceBand/bounds`` and a
    /// degenerate band — both edges equal — becomes a hairline rather than a
    /// zero-area rectangle that would silently vanish. Returns `nil` when the
    /// band lies entirely outside the plot or carries non-finite bounds.
    static func rect(for band: LivelineReferenceBand, layout: LivelineLayout) -> CGRect? {
        guard let bounds = band.bounds else { return nil }
        let hairline: CGFloat = 0.5

        switch band.axis {
        case .value:
            let top = layout.y(for: bounds.upperBound)
            let bottom = layout.y(for: bounds.lowerBound)
            guard top.isFinite, bottom.isFinite else { return nil }
            let plotTop = layout.padding.top
            let plotBottom = layout.bottomY
            guard bottom >= plotTop, top <= plotBottom else { return nil }
            let clampedTop = min(max(top, plotTop), plotBottom)
            let clampedBottom = min(max(bottom, plotTop), plotBottom)
            return CGRect(
                x: layout.plotLeftX,
                y: clampedTop,
                width: layout.chartWidth,
                height: max(clampedBottom - clampedTop, hairline)
            )

        case .time:
            let left = layout.x(for: bounds.lowerBound)
            let right = layout.x(for: bounds.upperBound)
            guard left.isFinite, right.isFinite else { return nil }
            let plotLeft = layout.plotLeftX
            let plotRight = layout.rightX
            guard right >= plotLeft, left <= plotRight else { return nil }
            let clampedLeft = min(max(left, plotLeft), plotRight)
            let clampedRight = min(max(right, plotLeft), plotRight)
            return CGRect(
                x: clampedLeft,
                y: layout.padding.top,
                width: max(clampedRight - clampedLeft, hairline),
                height: layout.chartHeight
            )
        }
    }
}
