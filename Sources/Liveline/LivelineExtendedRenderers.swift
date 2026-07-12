import Foundation
import SwiftUI

extension LivelineRenderer {
    static func drawErrorBars(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        points: [LivelineErrorBarPoint],
        style: LivelineErrorBarStyle,
        reveal: Double
    ) {
        let progress = LivelineMath.easedReveal(reveal)
        guard !points.isEmpty, progress > 0.001 else { return }
        var layer = context
        layer.clip(to: plotClip(layout))

        for (index, point) in points.enumerated() {
            let localReveal = LivelineMath.staggeredReveal(index: index, count: points.count, reveal: reveal)
            guard localReveal > 0.001 else { continue }
            let x = layout.x(for: point.time)
            let center = CGPoint(x: x, y: layout.y(for: point.value))
            let local = CGFloat(localReveal)
            let lowerY = center.y + (layout.y(for: point.lower) - center.y) * local
            let upperY = center.y + (layout.y(for: point.upper) - center.y) * local
            let capWidth = style.resolvedCapWidth * local

            if style.resolvedLineWidth > 0 {
                var whisker = Path()
                whisker.move(to: CGPoint(x: x, y: lowerY))
                whisker.addLine(to: CGPoint(x: x, y: upperY))
                whisker.move(to: CGPoint(x: x - capWidth / 2, y: lowerY))
                whisker.addLine(to: CGPoint(x: x + capWidth / 2, y: lowerY))
                whisker.move(to: CGPoint(x: x - capWidth / 2, y: upperY))
                whisker.addLine(to: CGPoint(x: x + capWidth / 2, y: upperY))
                layer.stroke(
                    whisker,
                    with: .color(palette.line.opacity(0.72)),
                    style: StrokeStyle(lineWidth: style.resolvedLineWidth, lineCap: .round)
                )
            }

            let marker = scatterSymbolPath(symbol: style.pointSymbol, center: center, size: style.resolvedPointSize * local)
            layer.fill(marker, with: .color(palette.line.opacity(style.resolvedFillOpacity)))
            layer.stroke(marker, with: .color(palette.line), lineWidth: max(1, style.resolvedLineWidth * 0.7))
        }
    }

    static func drawDumbbells(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        points: [LivelineDumbbellPoint],
        style: LivelineDumbbellStyle,
        reveal: Double
    ) {
        let progress = LivelineMath.easedReveal(reveal)
        guard !points.isEmpty, progress > 0.001 else { return }
        var layer = context
        layer.clip(to: plotClip(layout))
        let startColor = style.startColor ?? palette.gridLabel
        let endColor = style.endColor ?? palette.line

        for (index, point) in points.enumerated() {
            let localReveal = LivelineMath.staggeredReveal(index: index, count: points.count, reveal: reveal)
            guard localReveal > 0.001 else { continue }
            let x = layout.x(for: point.time)
            let start = CGPoint(x: x, y: layout.y(for: point.start))
            let targetEnd = CGPoint(x: x, y: layout.y(for: point.end))
            let end = CGPoint(
                x: x,
                y: start.y + (targetEnd.y - start.y) * CGFloat(localReveal)
            )

            if style.resolvedLineWidth > 0 {
                var connector = Path()
                connector.move(to: start)
                connector.addLine(to: end)
                layer.stroke(
                    connector,
                    with: .linearGradient(
                        Gradient(colors: [startColor, endColor]),
                        startPoint: start,
                        endPoint: end
                    ),
                    style: StrokeStyle(lineWidth: style.resolvedLineWidth, lineCap: .round)
                )
            }

            let startMarker = scatterSymbolPath(
                symbol: style.pointSymbol,
                center: start,
                size: style.resolvedPointSize * CGFloat(min(localReveal * 2, 1))
            )
            let endMarker = scatterSymbolPath(
                symbol: style.pointSymbol,
                center: end,
                size: style.resolvedPointSize * CGFloat(localReveal)
            )
            layer.fill(startMarker, with: .color(startColor))
            layer.fill(endMarker, with: .color(endColor))
            layer.stroke(startMarker, with: .color(palette.backgroundRGB.color), lineWidth: 1)
            layer.stroke(endMarker, with: .color(palette.backgroundRGB.color), lineWidth: 1)

            if style.showsDirection, abs(end.y - start.y) > style.resolvedPointSize * 2.5 {
                let direction: CGFloat = end.y < start.y ? -1 : 1
                let midpoint = CGPoint(x: x, y: (start.y + end.y) / 2)
                var arrow = Path()
                arrow.move(to: CGPoint(x: midpoint.x - 3, y: midpoint.y - direction * 3))
                arrow.addLine(to: midpoint)
                arrow.addLine(to: CGPoint(x: midpoint.x + 3, y: midpoint.y - direction * 3))
                layer.stroke(arrow, with: .color(endColor), lineWidth: max(1, style.resolvedLineWidth))
            }
        }
    }

    static func drawStackedBars(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        points: [LivelineStackedPoint],
        style: LivelineStackedBarStyle,
        reveal: Double
    ) {
        let progress = LivelineMath.easedReveal(reveal)
        guard !points.isEmpty, progress > 0.001 else { return }
        let width = bucketWidth(times: points.map(\.time), layout: layout, ratio: style.resolvedWidthRatio, maximum: 48)
        var layer = context
        layer.clip(to: plotClip(layout))

        if style.showsBaseline {
            var baselineLayer = layer
            baselineLayer.opacity *= min(progress * 2, 1)
            drawBaseline(context: &baselineLayer, layout: layout, palette: palette, value: 0)
        }

        for (pointIndex, point) in points.enumerated() {
            let localReveal = LivelineMath.staggeredReveal(index: pointIndex, count: points.count, reveal: reveal)
            guard localReveal > 0.001 else { continue }
            let x = layout.x(for: point.time)
            for (index, segment) in LivelineMath.stackedSegments(values: point.values, mode: style.mode).enumerated() {
                let lowerY = layout.y(for: segment.lower * localReveal)
                let upperY = layout.y(for: segment.upper * localReveal)
                let top = min(lowerY, upperY) + style.resolvedSegmentSpacing / 2
                let height = max(abs(lowerY - upperY) - style.resolvedSegmentSpacing, 1)
                let rect = CGRect(x: x - width / 2, y: top, width: width, height: height)
                let radius = min(style.resolvedCornerRadius, width / 2, height / 2)
                layer.fill(
                    Path(roundedRect: rect, cornerRadius: radius),
                    with: .color(extendedSeriesColor(index: index, colors: style.colors, palette: palette))
                )
            }
        }
    }

    static func drawStackedAreas(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        points: [LivelineStackedPoint],
        style: LivelineStackedAreaStyle,
        reveal: Double
    ) {
        let progress = LivelineMath.easedReveal(reveal)
        guard !points.isEmpty, progress > 0.001 else { return }
        let sorted = points.sorted { $0.time < $1.time }
        if sorted.count == 1 {
            drawStackedBars(
                context: &context,
                layout: layout,
                palette: palette,
                points: sorted,
                style: LivelineStackedBarStyle(
                    mode: style.mode,
                    widthRatio: 0.4,
                    cornerRadius: 2,
                    segmentSpacing: 0,
                    colors: style.colors,
                    showsBaseline: style.showsBaseline
                ),
                reveal: reveal
            )
            return
        }
        let maximumSegments = sorted.map { $0.values.count }.max() ?? 0
        var layer = context
        layer.clip(to: plotClip(layout))

        if style.showsBaseline {
            var baselineLayer = layer
            baselineLayer.opacity *= min(progress * 2, 1)
            drawBaseline(context: &baselineLayer, layout: layout, palette: palette, value: 0)
        }

        for index in 0..<maximumSegments {
            let bounds = sorted.map { point -> (time: TimeInterval, segment: LivelineStackSegment) in
                let segments = LivelineMath.stackedSegments(values: point.values, mode: style.mode)
                return (point.time, index < segments.count ? segments[index] : LivelineStackSegment(lower: 0, upper: 0))
            }
            let upperPoints = bounds.map { CGPoint(x: layout.x(for: $0.time), y: layout.y(for: $0.segment.upper)) }
            let lowerPoints = bounds.map { CGPoint(x: layout.x(for: $0.time), y: layout.y(for: $0.segment.lower)) }
            let visibleUpper = LivelineMath.revealedPoints(upperPoints, reveal: progress)
            let visibleLower = LivelineMath.revealedPoints(lowerPoints, reveal: progress)
            guard let first = visibleUpper.first else { continue }

            var area = Path()
            area.move(to: first)
            for point in visibleUpper.dropFirst() { area.addLine(to: point) }
            for point in visibleLower.reversed() { area.addLine(to: point) }
            area.closeSubpath()

            let color = extendedSeriesColor(index: index, colors: style.colors, palette: palette)
            layer.fill(area, with: .color(color.opacity(style.resolvedFillOpacity)))

            if style.resolvedBoundaryLineWidth > 0 {
                layer.stroke(
                    linePath(points: visibleUpper),
                    with: .color(color),
                    style: StrokeStyle(lineWidth: style.resolvedBoundaryLineWidth, lineJoin: .round)
                )
            }
        }
    }

    static func drawTimeline(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        geometry: LivelineTimelineGeometry,
        style: LivelineTimelineStyle,
        drawLabels: Bool = true
    ) {
        guard !geometry.marks.isEmpty, geometry.progress > 0.001 else { return }
        let layer = context

        if style.showsLaneGuides {
            var guideLayer = layer
            guideLayer.opacity *= min(geometry.progress * 2, 1)
            for lane in 0..<geometry.laneCount {
                let y = layout.padding.top + CGFloat(lane + 1) * geometry.laneHeight
                var guide = Path()
                guide.move(to: CGPoint(x: layout.plotLeftX, y: y))
                guide.addLine(to: CGPoint(x: layout.rightX, y: y))
                guideLayer.stroke(guide, with: .color(palette.gridLine), lineWidth: 1)
            }
        }

        var bars = layer
        bars.clip(to: plotClip(layout))
        for mark in geometry.marks {
            bars.fill(
                Path(roundedRect: mark.rect, cornerRadius: min(style.resolvedCornerRadius, geometry.barHeight / 2)),
                with: .color(mark.color.opacity(0.86))
            )
        }
        if drawLabels {
            drawTimelineLabels(context: &bars, geometry: geometry, style: style)
        }
    }

    static func drawTimelineLabels(
        context: inout GraphicsContext,
        geometry: LivelineTimelineGeometry,
        style: LivelineTimelineStyle
    ) {
        guard style.showsLabels else { return }
        for mark in geometry.marks where mark.reveal > 0.72 && mark.rect.width > 30 {
            var labelLayer = context
            labelLayer.opacity *= LivelineMath.easedReveal((mark.reveal - 0.72) / 0.28)
            drawText(
                mark.item.label,
                context: &labelLayer,
                at: CGPoint(x: mark.rect.midX, y: mark.rect.midY),
                anchor: .center,
                color: .white.opacity(0.92),
                font: .system(size: 9, weight: .semibold)
            )
        }
    }

    static func drawHeatmap(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        geometry: LivelineHeatmapGeometry,
        style: LivelineHeatmapStyle,
        formatValue: (Double) -> String,
        drawLabels: Bool = true
    ) {
        guard !geometry.marks.isEmpty, geometry.progress > 0.001 else { return }

        var layer = context
        var clipped = layer
        clipped.clip(to: plotClip(layout))

        for mark in geometry.marks {
            clipped.fill(
                Path(
                    roundedRect: mark.rect,
                    cornerRadius: min(style.resolvedCornerRadius, mark.rect.width / 2, mark.rect.height / 2)
                ),
                with: .color(mark.color)
            )
        }

        if drawLabels {
            drawHeatmapLabels(
                context: &layer,
                layout: layout,
                palette: palette,
                geometry: geometry,
                style: style,
                formatValue: formatValue
            )
        }
    }

    static func drawHeatmapLabels(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        geometry: LivelineHeatmapGeometry,
        style: LivelineHeatmapStyle,
        formatValue: (Double) -> String
    ) {
        if style.showsValues, geometry.cellWidth > 25, geometry.cellHeight > 14 {
            var clipped = context
            clipped.clip(to: plotClip(layout))
            for mark in geometry.marks where mark.reveal > 0.8 {
                var valueLayer = clipped
                valueLayer.opacity *= LivelineMath.easedReveal((mark.reveal - 0.8) / 0.2)
                drawText(
                    formatValue(mark.cell.value),
                    context: &valueLayer,
                    at: CGPoint(x: mark.rect.midX, y: mark.rect.midY),
                    anchor: .center,
                    color: mark.opacity > 0.55 ? .white.opacity(0.9) : palette.gridLabel,
                    font: .system(size: 8, weight: .medium, design: .monospaced)
                )
            }
        }

        var labelLayer = context
        labelLayer.opacity *= min(geometry.progress * 2, 1)
        for row in 0..<min(geometry.rowCount, style.rowLabels.count) {
            let y = layout.padding.top + (CGFloat(row) + 0.5) * geometry.rowHeight
            drawText(
                style.rowLabels[row],
                context: &labelLayer,
                at: CGPoint(x: layout.plotLeftX - 5, y: y),
                anchor: .trailing,
                color: palette.gridLabel,
                font: .system(size: 9, weight: .medium)
            )
        }
    }

    static func drawRadar(
        context: inout GraphicsContext,
        palette: LivelinePalette,
        geometry: LivelineRadarGeometry,
        points: [LivelineRadarPoint],
        style: LivelineRadarStyle,
        drawLabels: Bool = true
    ) {
        guard points.count >= 3, geometry.progress > 0.001 else { return }
        let layer = context

        var gridLayer = layer
        gridLayer.opacity *= min(geometry.progress * 1.8, 1)
        for level in 1...style.resolvedGridLevels {
            let levelRadius = geometry.radius * CGFloat(level) / CGFloat(style.resolvedGridLevels)
            var polygon = Path()
            for index in points.indices {
                let point = LivelineMath.polarPoint(
                    center: geometry.center,
                    radius: levelRadius,
                    angle: geometry.startAngle + Double(index) * geometry.angleStep
                )
                index == points.startIndex ? polygon.move(to: point) : polygon.addLine(to: point)
            }
            polygon.closeSubpath()
            gridLayer.stroke(polygon, with: .color(palette.gridLine), lineWidth: 1)
        }

        for index in points.indices {
            let angle = geometry.startAngle + Double(index) * geometry.angleStep
            let endpoint = LivelineMath.polarPoint(center: geometry.center, radius: geometry.radius, angle: angle)
            var spoke = Path()
            spoke.move(to: geometry.center)
            spoke.addLine(to: endpoint)
            gridLayer.stroke(spoke, with: .color(palette.gridLine), lineWidth: 1)
        }

        var valuePath = Path()
        for (index, point) in geometry.valuePoints.enumerated() {
            index == 0 ? valuePath.move(to: point) : valuePath.addLine(to: point)
        }
        valuePath.closeSubpath()
        layer.fill(valuePath, with: .color(palette.line.opacity(style.resolvedFillOpacity)))
        if style.resolvedLineWidth > 0 {
            layer.stroke(valuePath, with: .color(palette.line), style: StrokeStyle(lineWidth: style.resolvedLineWidth, lineJoin: .round))
        }

        if style.resolvedPointSize > 0 {
            for point in geometry.valuePoints {
                let marker = Path(ellipseIn: CGRect(
                    x: point.x - style.resolvedPointSize * CGFloat(geometry.progress) / 2,
                    y: point.y - style.resolvedPointSize * CGFloat(geometry.progress) / 2,
                    width: style.resolvedPointSize * CGFloat(geometry.progress),
                    height: style.resolvedPointSize * CGFloat(geometry.progress)
                ))
                layer.fill(marker, with: .color(palette.line))
            }
        }

        if drawLabels {
            drawRadarLabels(context: &context, palette: palette, geometry: geometry, points: points, style: style)
        }
    }

    static func drawRadarLabels(
        context: inout GraphicsContext,
        palette: LivelinePalette,
        geometry: LivelineRadarGeometry,
        points: [LivelineRadarPoint],
        style: LivelineRadarStyle
    ) {
        guard style.showsLabels else { return }
        var labelLayer = context
        labelLayer.opacity *= LivelineMath.easedReveal((geometry.progress - 0.45) / 0.55)
        for (index, point) in points.enumerated() {
            let angle = geometry.startAngle + Double(index) * geometry.angleStep
            let labelPoint = LivelineMath.polarPoint(center: geometry.center, radius: geometry.radius + 14, angle: angle)
            drawText(
                point.label,
                context: &labelLayer,
                at: labelPoint,
                anchor: extendedRadialAnchor(angle: angle),
                color: palette.gridLabel,
                font: .system(size: 9, weight: .medium)
            )
        }
    }

    static func drawDonut(
        context: inout GraphicsContext,
        palette: LivelinePalette,
        geometry: LivelineDonutGeometry,
        style: LivelineDonutStyle,
        formatValue: (Double) -> String,
        drawLabels: Bool = true
    ) {
        guard !geometry.segments.isEmpty, geometry.total > 0, geometry.progress > 0.001 else { return }
        var layer = context

        for segment in geometry.segments where segment.endDegrees > segment.startDegrees {
                var arc = Path()
                arc.addArc(
                    center: geometry.center,
                    radius: geometry.pathRadius,
                    startAngle: .degrees(segment.startDegrees),
                    endAngle: .degrees(segment.endDegrees),
                    clockwise: false
                )
                layer.stroke(
                    arc,
                    with: .color(segment.color),
                    style: StrokeStyle(lineWidth: geometry.ringWidth, lineCap: .butt)
                )
        }

        if drawLabels {
            drawDonutLabels(
                context: &layer,
                palette: palette,
                geometry: geometry,
                style: style,
                formatValue: formatValue
            )
        }
    }

    static func drawDonutLabels(
        context: inout GraphicsContext,
        palette: LivelinePalette,
        geometry: LivelineDonutGeometry,
        style: LivelineDonutStyle,
        formatValue: (Double) -> String
    ) {
        if style.showsLabels {
            for segment in geometry.segments where segment.isFullyRevealed {
                let labelPoint = LivelineMath.polarPoint(
                    center: geometry.center,
                    radius: geometry.outerRadius + 13,
                    angle: segment.middleAngle
                )
                let label = style.showsValues
                    ? "\(segment.entry.label) \(formatValue(segment.entry.value))"
                    : segment.entry.label
                drawText(
                    label,
                    context: &context,
                    at: labelPoint,
                    anchor: extendedRadialAnchor(angle: segment.middleAngle),
                    color: palette.gridLabel,
                    font: .system(size: 9, weight: .medium)
                )
            }
        }

        var valueLayer = context
        valueLayer.opacity *= LivelineMath.easedReveal((geometry.progress - 0.55) / 0.45)
        drawText(
            formatValue(geometry.total),
            context: &valueLayer,
            at: geometry.center,
            anchor: .center,
            color: palette.tooltipText,
            font: .system(size: 15, weight: .semibold, design: .rounded)
        )
    }

    static func drawGauge(
        context: inout GraphicsContext,
        palette: LivelinePalette,
        geometry: LivelineGaugeRenderGeometry,
        style: LivelineGaugeStyle,
        formatValue: (Double) -> String,
        drawLabels: Bool = true
    ) {
        guard geometry.revealProgress > 0.001 else { return }
        let layer = context
        let center = geometry.gauge.center
        let radius = geometry.gauge.radius

        var trackLayer = layer
        trackLayer.opacity *= min(geometry.revealProgress * 2, 1)
        var track = Path()
        track.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(geometry.startDegrees),
            endAngle: .degrees(geometry.endDegrees),
            clockwise: false
        )
        trackLayer.stroke(
            track,
            with: .color(palette.tooltipText.opacity(style.resolvedTrackOpacity)),
            style: StrokeStyle(lineWidth: style.resolvedLineWidth, lineCap: .round)
        )

        if geometry.valueProgress > 0 {
            var progressPath = Path()
            progressPath.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(geometry.startDegrees),
                endAngle: .degrees(
                    geometry.startDegrees
                        + style.resolvedSweepDegrees * geometry.valueProgress * geometry.revealProgress
                ),
                clockwise: false
            )
            layer.stroke(
                progressPath,
                with: .color(style.progressColor ?? palette.line),
                style: StrokeStyle(lineWidth: style.resolvedLineWidth, lineCap: .round)
            )
        }

        if style.showsTicks {
            let lastIndex = style.resolvedTickCount - 1
            for index in 0...lastIndex {
                let tickReveal = LivelineMath.staggeredReveal(
                    index: index,
                    count: style.resolvedTickCount,
                    reveal: geometry.reveal
                )
                guard tickReveal > 0.001 else { continue }
                let angle = (
                    geometry.startDegrees + style.resolvedSweepDegrees * Double(index) / Double(lastIndex)
                ) * Double.pi / 180
                let isMajor = index == 0 || index == lastIndex || index * 2 == lastIndex
                let innerRadius = radius + style.resolvedLineWidth / 2 + 5
                let outerRadius = innerRadius + (isMajor ? 7 : 4)
                let inside = LivelineMath.polarPoint(center: center, radius: innerRadius, angle: angle)
                let outside = LivelineMath.polarPoint(center: center, radius: outerRadius, angle: angle)
                var tick = Path()
                tick.move(to: inside)
                tick.addLine(to: outside)
                var tickLayer = layer
                tickLayer.opacity *= tickReveal
                tickLayer.stroke(
                    tick,
                    with: .color(palette.tooltipText.opacity(isMajor ? 0.42 : 0.26)),
                    style: StrokeStyle(lineWidth: isMajor ? 1.5 : 1, lineCap: .round)
                )
            }
        }

        if let targetProgress = geometry.targetProgress {
            let targetReveal = LivelineMath.easedReveal((geometry.revealProgress - 0.72) / 0.28)
            let angle = (geometry.startDegrees + style.resolvedSweepDegrees * targetProgress) * Double.pi / 180
            let markerColor = style.targetColor ?? palette.tooltipText
            let markerCenter = LivelineMath.polarPoint(
                center: center,
                radius: radius + style.resolvedLineWidth / 2 + 6,
                angle: angle
            )
            let targetPin = scatterSymbolPath(symbol: .diamond, center: markerCenter, size: 8)
            var targetLayer = layer
            targetLayer.opacity *= targetReveal
            targetLayer.fill(targetPin, with: .color(markerColor))
            targetLayer.stroke(targetPin, with: .color(palette.backgroundRGB.color), lineWidth: 1)
        }

        if drawLabels {
            drawGaugeLabel(
                context: &context,
                palette: palette,
                geometry: geometry,
                style: style,
                formatValue: formatValue
            )
        }
    }

    static func drawGaugeLabel(
        context: inout GraphicsContext,
        palette: LivelinePalette,
        geometry: LivelineGaugeRenderGeometry,
        style: LivelineGaugeStyle,
        formatValue: (Double) -> String
    ) {
        guard style.showsValue else { return }
        var valueLayer = context
        valueLayer.opacity *= LivelineMath.easedReveal((geometry.revealProgress - 0.35) / 0.65)
        drawText(
            formatValue(geometry.displayedValue),
            context: &valueLayer,
            at: CGPoint(
                x: geometry.gauge.center.x,
                y: geometry.gauge.center.y + min(10, geometry.gauge.radius * 0.08)
            ),
            anchor: .center,
            color: palette.tooltipText,
            font: .system(size: 24, weight: .semibold, design: .rounded)
        )
    }

    static func drawFunnel(
        context: inout GraphicsContext,
        geometry: LivelineFunnelGeometry,
        style: LivelineFunnelStyle,
        formatValue: (Double) -> String,
        drawLabels: Bool = true
    ) {
        guard !geometry.stages.isEmpty, geometry.progress > 0.001 else { return }
        let layer = context

        for stage in geometry.stages {
            layer.fill(
                Path(
                    roundedRect: stage.rect,
                    cornerRadius: min(style.resolvedCornerRadius, geometry.stageHeight / 2)
                ),
                with: .color(stage.color.opacity(0.88))
            )
        }

        if drawLabels {
            drawFunnelLabels(
                context: &context,
                geometry: geometry,
                style: style,
                formatValue: formatValue
            )
        }
    }

    static func drawFunnelLabels(
        context: inout GraphicsContext,
        geometry: LivelineFunnelGeometry,
        style: LivelineFunnelStyle,
        formatValue: (Double) -> String
    ) {
        guard style.showsLabels || style.showsValues else { return }
        for stage in geometry.stages where stage.reveal > 0.65 {
            var labelLayer = context
            labelLayer.opacity *= LivelineMath.easedReveal((stage.reveal - 0.65) / 0.35)
            let label: String
            if style.showsLabels, style.showsValues {
                label = "\(stage.entry.label) · \(formatValue(stage.entry.value))"
            } else if style.showsLabels {
                label = stage.entry.label
            } else {
                label = formatValue(stage.entry.value)
            }
            drawText(
                label,
                context: &labelLayer,
                at: CGPoint(x: stage.rect.midX, y: stage.rect.midY),
                anchor: .center,
                color: .white.opacity(0.94),
                font: .system(size: 10, weight: .semibold)
            )
        }
    }
}

extension LivelineRenderer {
    static var extendedDefaultColors: [Color] {
        [
            Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
            Color(red: 139 / 255, green: 92 / 255, blue: 246 / 255),
            Color(red: 6 / 255, green: 182 / 255, blue: 212 / 255),
            Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255),
            Color(red: 249 / 255, green: 115 / 255, blue: 22 / 255),
            Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255),
        ]
    }

    static func extendedSeriesColor(index: Int, colors: [Color], palette: LivelinePalette) -> Color {
        if !colors.isEmpty { return colors[index % colors.count] }
        if index == 0 { return palette.line }
        return extendedDefaultColors[index % extendedDefaultColors.count]
    }

    static func extendedRadialAnchor(angle: Double) -> UnitPoint {
        let x = cos(angle)
        let y = sin(angle)
        return UnitPoint(x: 0.5 - x * 0.5, y: 0.5 - y * 0.5)
    }

}
