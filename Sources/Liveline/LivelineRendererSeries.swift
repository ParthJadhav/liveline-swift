import Foundation
import SwiftUI

extension LivelineRenderer {
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
            let visible = entry.data.livelineVisible(in: (layout.leftEdge - 2)...layout.rightEdge)
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
        legendSide: LivelineLegendSide,
        drawsDot: Bool = true,
        drawsLabel: Bool = true
    ) {
        let dotAlpha = alpha < 0.3 ? 0 : (alpha - 0.3) / 0.7
        guard dotAlpha > 0.01 else { return }

        for endpoint in endpoints {
            var layer = context
            layer.opacity *= dotAlpha * endpoint.alpha
            if drawsDot {
                drawMultiEndpointDot(
                    context: &layer,
                    at: endpoint.point,
                    color: endpoint.palette.line,
                    showPulse: showPulse && endpoint.alpha > 0.5,
                    timestamp: timestamp
                )
            }

            if drawsLabel, let label = endpoint.label {
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
            if let value = LivelineMath.interpolateOrdered(points: entry.data, at: hover.time) {
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
        if config.tooltipOutline {
            layer.stroke(Path(roundedRect: rect, cornerRadius: 6), with: .color(palette.tooltipBorder), lineWidth: 1)
        }
        drawText(text, context: &layer, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center, color: palette.tooltipText, font: font)
    }
}
