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
        baseline: LivelineStackBaseline = .zero,
        reveal: Double
    ) {
        let progress = LivelineMath.easedReveal(reveal)
        guard !points.isEmpty, progress > 0.001 else { return }
        let width = bucketWidth(sortedTimes: points.lazy.map(\.time), layout: layout, ratio: style.resolvedWidthRatio, maximum: 48)
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
            for (index, segment) in LivelineMath.stackedSegments(
                values: point.values,
                mode: style.mode,
                baseline: baseline
            ).enumerated() {
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
                    showsBaseline: style.showsBaseline && style.baseline == .zero
                ),
                baseline: style.baseline,
                reveal: reveal
            )
            return
        }
        let maximumSegments = sorted.map { $0.values.count }.max() ?? 0
        var layer = context
        layer.clip(to: plotClip(layout))

        // A centered stack has no meaningful zero line to draw against.
        if style.showsBaseline, style.baseline == .zero {
            var baselineLayer = layer
            baselineLayer.opacity *= min(progress * 2, 1)
            drawBaseline(context: &baselineLayer, layout: layout, palette: palette, value: 0)
        }

        for index in 0..<maximumSegments {
            let bounds = sorted.map { point -> (time: TimeInterval, segment: LivelineStackSegment) in
                let segments = LivelineMath.stackedSegments(
                    values: point.values,
                    mode: style.mode,
                    baseline: style.baseline
                )
                // A point with fewer slots than the widest one contributes a
                // zero-height sliver. Under `.zero` that is the axis' zero
                // line, exactly as before; a centered stack has no zero line,
                // so the sliver rides on top of that point's own stack.
                let collapsed = style.baseline == .centered ? (segments.last?.upper ?? 0) : 0
                let empty = LivelineStackSegment(lower: collapsed, upper: collapsed)
                return (point.time, index < segments.count ? segments[index] : empty)
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
        textScale: LivelineTextScale,
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
            drawTimelineLabels(context: &bars, geometry: geometry, style: style, textScale: textScale)
        }
    }

    static func drawTimelineLabels(
        context: inout GraphicsContext,
        geometry: LivelineTimelineGeometry,
        style: LivelineTimelineStyle,
        textScale: LivelineTextScale
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
                font: textScale.font(9, weight: .semibold)
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
        textScale: LivelineTextScale,
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
                formatValue: formatValue,
                textScale: textScale
            )
        }
    }

    static func drawHeatmapLabels(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        geometry: LivelineHeatmapGeometry,
        style: LivelineHeatmapStyle,
        formatValue: (Double) -> String,
        textScale: LivelineTextScale
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
                    font: textScale.font(8, weight: .medium, design: .monospaced)
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
                at: CGPoint(x: layout.pastEdgeX - 5 * layout.forwardXDirection, y: y),
                anchor: layout.isRTL ? .leading : .trailing,
                color: palette.gridLabel,
                font: textScale.font(9, weight: .medium)
            )
        }
    }

    static func drawRadar(
        context: inout GraphicsContext,
        palette: LivelinePalette,
        geometry: LivelineRadarGeometry,
        points: [LivelineRadarPoint],
        style: LivelineRadarStyle,
        textScale: LivelineTextScale,
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
            drawRadarLabels(context: &context, palette: palette, geometry: geometry, points: points, style: style, textScale: textScale)
        }
    }

    static func drawRadarLabels(
        context: inout GraphicsContext,
        palette: LivelinePalette,
        geometry: LivelineRadarGeometry,
        points: [LivelineRadarPoint],
        style: LivelineRadarStyle,
        textScale: LivelineTextScale
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
                font: textScale.font(9, weight: .medium)
            )
        }
    }

    static func drawDonut(
        context: inout GraphicsContext,
        palette: LivelinePalette,
        geometry: LivelineDonutGeometry,
        style: LivelineDonutStyle,
        formatValue: (Double) -> String,
        textScale: LivelineTextScale,
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
                formatValue: formatValue,
                textScale: textScale
            )
        }
    }

    static func drawDonutLabels(
        context: inout GraphicsContext,
        palette: LivelinePalette,
        geometry: LivelineDonutGeometry,
        style: LivelineDonutStyle,
        formatValue: (Double) -> String,
        textScale: LivelineTextScale
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
                    font: textScale.font(9, weight: .medium)
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
            font: textScale.font(15, weight: .semibold, design: .rounded)
        )
    }

    static func drawGauge(
        context: inout GraphicsContext,
        palette: LivelinePalette,
        geometry: LivelineGaugeRenderGeometry,
        style: LivelineGaugeStyle,
        formatValue: (Double) -> String,
        textScale: LivelineTextScale,
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
                formatValue: formatValue,
                textScale: textScale
            )
        }
    }

    static func drawGaugeLabel(
        context: inout GraphicsContext,
        palette: LivelinePalette,
        geometry: LivelineGaugeRenderGeometry,
        style: LivelineGaugeStyle,
        formatValue: (Double) -> String,
        textScale: LivelineTextScale
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
            font: textScale.font(24, weight: .semibold, design: .rounded)
        )
    }

    static func drawFunnel(
        context: inout GraphicsContext,
        geometry: LivelineFunnelGeometry,
        style: LivelineFunnelStyle,
        formatValue: (Double) -> String,
        textScale: LivelineTextScale,
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
                formatValue: formatValue,
                textScale: textScale
            )
        }
    }

    static func drawFunnelLabels(
        context: inout GraphicsContext,
        geometry: LivelineFunnelGeometry,
        style: LivelineFunnelStyle,
        formatValue: (Double) -> String,
        textScale: LivelineTextScale
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
                font: textScale.font(10, weight: .semibold)
            )
        }
    }

    static func drawHistogram(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        geometry: LivelineHistogramGeometry,
        style: LivelineHistogramStyle,
        formatValue: (Double) -> String,
        textScale: LivelineTextScale,
        drawLabels: Bool = true
    ) {
        guard !geometry.bars.isEmpty, geometry.progress > 0.001 else { return }
        var layer = context
        layer.clip(to: plotClip(layout))

        if style.showsBaseline {
            var baselineLayer = layer
            baselineLayer.opacity *= min(geometry.progress * 2, 1)
            drawBaseline(context: &baselineLayer, layout: layout, palette: palette, value: 0)
        }

        for bar in geometry.bars {
            let radius = min(style.resolvedCornerRadius, bar.rect.width / 2, max(bar.rect.height / 2, 0))
            layer.fill(
                Path(roundedRect: bar.rect, cornerRadius: radius),
                with: .color(geometry.color.opacity(style.resolvedFillOpacity))
            )
        }

        if drawLabels {
            drawHistogramLabels(
                context: &context,
                layout: layout,
                palette: palette,
                geometry: geometry,
                style: style,
                formatValue: formatValue,
                textScale: textScale
            )
        }
    }

    static func drawHistogramLabels(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        geometry: LivelineHistogramGeometry,
        style: LivelineHistogramStyle,
        formatValue: (Double) -> String,
        textScale: LivelineTextScale
    ) {
        guard !geometry.bars.isEmpty else { return }

        if style.showsCounts, geometry.barWidth > textScale.scaled(22) {
            var clipped = context
            clipped.clip(to: plotClip(layout))
            for bar in geometry.bars where bar.reveal > 0.8 && bar.rect.height > textScale.scaled(12) {
                var countLayer = clipped
                countLayer.opacity *= LivelineMath.easedReveal((bar.reveal - 0.8) / 0.2)
                drawText(
                    "\(bar.bin.count)",
                    context: &countLayer,
                    at: CGPoint(x: bar.rect.midX, y: bar.rect.minY + textScale.scaled(8)),
                    anchor: .center,
                    color: .white.opacity(0.92),
                    font: textScale.font(9, weight: .semibold, design: .monospaced)
                )
            }
        }

        guard style.showsEdgeLabels else { return }
        var labelLayer = context
        labelLayer.opacity *= min(geometry.progress * 2, 1)
        let font = textScale.font(10, weight: .regular, design: .monospaced)
        let y = layout.bottomY + textScale.scaled(11)
        // The low end of the range sits at the reading start, the high end at
        // the reading end, with both captions anchored outward.
        let lowX = layout.isRTL ? layout.rightX : layout.plotLeftX
        let highX = layout.isRTL ? layout.plotLeftX : layout.rightX
        let lowAnchor: UnitPoint = layout.isRTL ? .trailing : .leading
        let highAnchor: UnitPoint = layout.isRTL ? .leading : .trailing
        let edges: [(value: Double, x: CGFloat, anchor: UnitPoint)] = [
            (geometry.valueRange.lowerBound, lowX, lowAnchor),
            (
                (geometry.valueRange.lowerBound + geometry.valueRange.upperBound) / 2,
                layout.plotLeftX + layout.chartWidth / 2,
                .center
            ),
            (geometry.valueRange.upperBound, highX, highAnchor),
        ]
        // The middle label is the first to collide on a narrow chart.
        let visible = layout.chartWidth > textScale.scaled(180) ? edges : [edges[0], edges[2]]
        for edge in visible {
            drawText(
                formatValue(edge.value),
                context: &labelLayer,
                at: CGPoint(x: edge.x, y: y),
                anchor: edge.anchor,
                color: palette.timeLabel,
                font: font
            )
        }
    }

    static func drawBullet(
        context: inout GraphicsContext,
        palette: LivelinePalette,
        geometry: LivelineBulletGeometry,
        style: LivelineBulletStyle,
        formatValue: (Double) -> String,
        textScale: LivelineTextScale,
        drawLabels: Bool = true
    ) {
        guard geometry.progress > 0.001 else { return }
        let layer = context

        var trackLayer = layer
        trackLayer.opacity *= min(geometry.progress * 2, 1)
        let trackRadius = min(style.resolvedCornerRadius, geometry.trackRect.height / 2)
        trackLayer.fill(
            Path(roundedRect: geometry.trackRect, cornerRadius: trackRadius),
            with: .color(palette.tooltipText.opacity(0.08))
        )
        for band in geometry.bands where band.rect.width > 0 {
            trackLayer.fill(
                Path(roundedRect: band.rect, cornerRadius: min(trackRadius, band.rect.width / 2)),
                with: .color(bulletBandFill(band.color, palette: palette, style: style))
            )
        }

        if geometry.measureRect.width > 0 {
            layer.fill(
                Path(
                    roundedRect: geometry.measureRect,
                    cornerRadius: min(
                        style.resolvedCornerRadius,
                        geometry.measureRect.height / 2,
                        geometry.measureRect.width / 2
                    )
                ),
                with: .color(style.measureColor ?? palette.line)
            )
        }

        if let targetX = geometry.targetX {
            var targetLayer = layer
            targetLayer.opacity *= LivelineMath.easedReveal((geometry.progress - 0.6) / 0.4)
            let overhang = bulletTargetOverhang(trackHeight: geometry.trackRect.height)
            var tick = Path()
            tick.move(to: CGPoint(x: targetX, y: geometry.trackRect.minY - overhang))
            tick.addLine(to: CGPoint(x: targetX, y: geometry.trackRect.maxY + overhang))
            targetLayer.stroke(
                tick,
                with: .color(style.targetColor ?? palette.tooltipText),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
        }

        if drawLabels {
            drawBulletLabels(
                context: &context,
                palette: palette,
                geometry: geometry,
                style: style,
                formatValue: formatValue,
                textScale: textScale
            )
        }
    }

    /// Bands are composited straight onto the theme background instead of being
    /// alpha-blended over whatever is beneath them: a translucent red over a
    /// near-black plot with a light track under it lands on brown, which is the
    /// one colour a "danger" band must not be.
    static func bulletBandFill(
        _ color: Color,
        palette: LivelinePalette,
        style: LivelineBulletStyle
    ) -> Color {
        let weight = style.resolvedBandOpacity
        guard let rgba = color.livelineRGBA() else { return color.opacity(weight) }
        let solid = LivelineRGBA(red: rgba.red, green: rgba.green, blue: rgba.blue, alpha: 1)
        guard palette.backgroundRGB.luminance < 0.5 else {
            // On a light surface a plain composite already lands on a clean
            // pastel tint of the band's own hue.
            return palette.backgroundRGB.blended(to: solid, t: weight).color
        }
        // On a dark surface the same composite drags a pastel red or amber
        // through brown, because the near-black background eats the band's
        // lightness before its chroma. Compositing over a neutral mid-dark grey
        // instead lands the band where a muted UI palette puts it: light enough
        // that red reads red and amber reads gold, dark enough that the measure
        // bar still sits in front of it.
        let neutral = LivelineRGBA(red: 0.32, green: 0.32, blue: 0.34, alpha: 1)
        let tinted = neutral.blended(to: solid, t: min(weight * 1.5, 1))
        let (hue, saturation, brightness) = tinted.hsb
        // The composite dilutes chroma along with lightness; a small boost puts
        // the hue back, and the ceiling keeps the band behind the measure bar
        // rather than beside it.
        let saturated = min(saturation * 1.3, 0.75)
        // The floor tracks the requested weight, so a band asked to be faint
        // still is, while the default weight lands in muted-UI territory
        // instead of the near-black end of the hue.
        let base = min(max(brightness, 0.34 + 0.7 * weight), 0.9)
        let candidate = LivelineRGBA.fromHSB(hue: hue, saturation: saturated, brightness: base)
        // Yellow and green carry far more luminance than red at the same
        // brightness, so an untouched ramp reads as one loud band beside two
        // quiet ones. A light correction toward equal luminance evens the
        // weights; a heavy one is what turns amber into olive.
        let ratio = candidate.luminance > 0 ? 0.38 / candidate.luminance : 1
        let factor = min(max(1 + (ratio - 1) * 0.2, 0.94), 1.12)
        return LivelineRGBA.fromHSB(
            hue: hue,
            saturation: saturated,
            brightness: min(base * factor, 0.9)
        ).color
    }

    /// A few points of overhang is enough to read the target tick against the
    /// bands; scaled with the track it turns into a tower.
    static func bulletTargetOverhang(trackHeight: CGFloat) -> CGFloat {
        min(max(trackHeight * 0.14, 3), 6)
    }

    static func drawBulletLabels(
        context: inout GraphicsContext,
        palette: LivelinePalette,
        geometry: LivelineBulletGeometry,
        style: LivelineBulletStyle,
        formatValue: (Double) -> String,
        textScale: LivelineTextScale
    ) {
        var labelLayer = context
        labelLayer.opacity *= LivelineMath.easedReveal((geometry.progress - 0.35) / 0.65)
        let captionY = geometry.trackRect.minY - textScale.scaled(18)

        if let label = style.label, !label.isEmpty {
            drawText(
                label,
                context: &labelLayer,
                at: CGPoint(
                    x: geometry.isRTL ? geometry.plotRect.maxX : geometry.plotRect.minX,
                    y: captionY
                ),
                anchor: geometry.isRTL ? .trailing : .leading,
                color: palette.gridLabel,
                font: textScale.font(11, weight: .medium)
            )
        }

        if style.showsBandLabels {
            drawBulletBandLabels(
                context: &labelLayer,
                palette: palette,
                geometry: geometry,
                textScale: textScale
            )
        }

        guard style.showsValue else { return }
        let text = formatValue(geometry.displayedMeasure)
        let font = textScale.font(16, weight: .semibold, design: .rounded)
        let size = measureText(text, context: labelLayer, font: font)
        // The value sits at the reading end of the track. The target tick's
        // overhang normally stops short of the caption line; when a tall track
        // pushes it up into the text, the value steps aside rather than being
        // struck through.
        var edge = geometry.isRTL ? geometry.plotRect.minX : geometry.plotRect.maxX
        let tickTop = geometry.trackRect.minY - bulletTargetOverhang(trackHeight: geometry.trackRect.height)
        if let targetX = geometry.targetX, tickTop < captionY + size.height / 2 + 2 {
            let clearance = textScale.scaled(10)
            if geometry.isRTL {
                if targetX < edge + size.width + clearance {
                    edge = min(targetX + clearance, geometry.plotRect.maxX - size.width)
                }
            } else if targetX > edge - size.width - clearance {
                edge = max(targetX - clearance, geometry.plotRect.minX + size.width)
            }
        }
        drawText(
            text,
            context: &labelLayer,
            at: CGPoint(x: edge, y: captionY),
            anchor: geometry.isRTL ? .leading : .trailing,
            color: palette.tooltipText,
            font: font
        )
    }

    /// One label per band, centred under the band it names and drawn only where
    /// the band is wide enough to hold the whole string.
    static func drawBulletBandLabels(
        context: inout GraphicsContext,
        palette: LivelinePalette,
        geometry: LivelineBulletGeometry,
        textScale: LivelineTextScale
    ) {
        let font = textScale.font(10, weight: .medium)
        let baseline = geometry.trackRect.maxY + textScale.scaled(13)
        for band in geometry.bands {
            guard let label = band.range.label, !label.isEmpty, band.rect.width > 0 else { continue }
            let width = measureText(label, context: context, font: font).width
            guard band.rect.width >= width + textScale.scaled(10) else { continue }
            drawText(
                label,
                context: &context,
                at: CGPoint(x: band.rect.midX, y: baseline),
                anchor: .center,
                color: palette.gridLabel,
                font: font
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

extension LivelineRenderer {
    static func drawTreemap(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        geometry: LivelineTreemapGeometry,
        style: LivelineTreemapStyle,
        formatValue: (Double) -> String,
        textScale: LivelineTextScale,
        drawLabels: Bool = true
    ) {
        guard !geometry.cells.isEmpty, geometry.progress > 0.001 else { return }
        var layer = context
        layer.clip(to: plotClip(layout))

        // Groups are drawn first: a tinted backing plate with a hairline edge
        // that reads as "these cells belong together" before any label does.
        for group in geometry.groups {
            var groupLayer = layer
            groupLayer.opacity *= group.reveal
            let radius = min(
                style.resolvedCornerRadius + 2,
                group.rect.width / 2,
                group.rect.height / 2
            )
            let path = Path(roundedRect: group.rect, cornerRadius: max(radius, 0))
            groupLayer.fill(path, with: .color(group.color.opacity(0.18 * style.resolvedFillOpacity)))
            // The header carries a heavier tint than the plate, so the strip
            // holding the parent's name reads as a title bar for the cells
            // below rather than as spare room inside the group.
            if let header = group.headerRect {
                var headerLayer = groupLayer
                headerLayer.clip(to: path)
                headerLayer.fill(
                    Path(header),
                    with: .color(group.color.opacity(0.34 * style.resolvedFillOpacity))
                )
            }
            groupLayer.stroke(path, with: .color(group.color.opacity(0.55)), lineWidth: 1)
        }

        for cell in geometry.cells {
            var cellLayer = layer
            cellLayer.opacity *= cell.reveal
            let radius = min(style.resolvedCornerRadius, cell.rect.width / 2, cell.rect.height / 2)
            cellLayer.fill(
                Path(roundedRect: cell.rect, cornerRadius: max(radius, 0)),
                with: .color(cell.color.opacity(style.resolvedFillOpacity * cell.opacity))
            )
        }

        if drawLabels {
            drawTreemapLabels(
                context: &context,
                layout: layout,
                geometry: geometry,
                style: style,
                formatValue: formatValue,
                textScale: textScale
            )
        }
    }

    static func drawTreemapLabels(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        geometry: LivelineTreemapGeometry,
        style: LivelineTreemapStyle,
        formatValue: (Double) -> String,
        textScale: LivelineTextScale
    ) {
        guard style.showsLabels || style.showsValues else { return }
        var clipped = context
        clipped.clip(to: plotClip(layout))
        // Dynamic Type grows the glyphs but not the cell, so the threshold a
        // cell has to clear grows with it.
        let inset = textScale.scaled(style.labelInset)
        let minimumWidth = textScale.scaled(style.resolvedMinimumLabelWidth)
        let minimumHeight = textScale.scaled(style.resolvedMinimumLabelHeight)
        let lineHeight = textScale.scaled(13)

        // Group headers first, so a child cell's own label always wins the
        // pixels where the two could meet.
        for group in geometry.groups where group.reveal > 0.65 {
            guard style.showsLabels, let header = group.headerRect else { continue }
            var headerLayer = clipped
            headerLayer.opacity *= LivelineMath.easedReveal((group.reveal - 0.65) / 0.35)
            let text = header.insetBy(dx: inset, dy: 0)
            guard text.width > 0 else { continue }
            headerLayer.clip(to: Path(text))
            drawText(
                group.node.label,
                context: &headerLayer,
                at: CGPoint(x: text.minX, y: header.midY),
                anchor: .leading,
                color: .white.opacity(0.95),
                font: textScale.font(11, weight: .semibold)
            )
            guard style.showsValues, text.width >= minimumWidth else { continue }
            drawText(
                formatValue(group.value),
                context: &headerLayer,
                at: CGPoint(x: text.maxX, y: header.midY),
                anchor: .trailing,
                color: .white.opacity(0.7),
                font: textScale.font(10, weight: .regular, design: .monospaced)
            )
        }

        for cell in geometry.cells where cell.reveal > 0.65 {
            guard cell.rect.width >= minimumWidth, cell.rect.height >= minimumHeight else { continue }
            var labelLayer = clipped
            labelLayer.opacity *= LivelineMath.easedReveal((cell.reveal - 0.65) / 0.35)
            // Text is clipped to the cell's own padding box: a long label runs
            // out of room rather than crossing the border into its neighbour.
            let box = cell.rect.insetBy(dx: inset, dy: textScale.scaled(3))
            guard box.width > 0, box.height > 0 else { continue }
            labelLayer.clip(to: Path(box))
            let origin = CGPoint(x: box.minX, y: cell.rect.minY + inset + textScale.scaled(1))
            if style.showsLabels {
                drawText(
                    cell.node.label,
                    context: &labelLayer,
                    at: origin,
                    anchor: .leading,
                    color: .white.opacity(0.94),
                    font: textScale.font(10, weight: .semibold)
                )
            }
            // The value needs a second line, which only the taller cells have.
            guard style.showsValues else { continue }
            guard !style.showsLabels || cell.rect.height >= minimumHeight + lineHeight else { continue }
            drawText(
                formatValue(cell.value),
                context: &labelLayer,
                at: CGPoint(x: origin.x, y: style.showsLabels ? origin.y + lineHeight : origin.y),
                anchor: .leading,
                color: .white.opacity(0.74),
                font: textScale.font(9, weight: .regular, design: .monospaced)
            )
        }
    }

    static func drawSunburst(
        context: inout GraphicsContext,
        palette: LivelinePalette,
        geometry: LivelineSunburstGeometry,
        style: LivelineSunburstStyle,
        formatValue: (Double) -> String,
        textScale: LivelineTextScale,
        drawLabels: Bool = true
    ) {
        guard !geometry.segments.isEmpty, geometry.total > 0, geometry.progress > 0.001 else { return }
        let layer = context

        for segment in geometry.segments where segment.revealedEnd > segment.span.start {
            var arc = Path()
            arc.addArc(
                center: geometry.center,
                radius: segment.pathRadius,
                startAngle: .degrees(segment.span.start),
                endAngle: .degrees(segment.revealedEnd),
                clockwise: false
            )
            layer.stroke(
                arc,
                with: .color(segment.color),
                style: StrokeStyle(lineWidth: segment.ringWidth, lineCap: .butt)
            )
        }

        if drawLabels {
            drawSunburstLabels(
                context: &context,
                palette: palette,
                geometry: geometry,
                style: style,
                formatValue: formatValue,
                textScale: textScale
            )
        }
    }

    static func drawSunburstLabels(
        context: inout GraphicsContext,
        palette: LivelinePalette,
        geometry: LivelineSunburstGeometry,
        style: LivelineSunburstStyle,
        formatValue: (Double) -> String,
        textScale: LivelineTextScale
    ) {
        guard style.showsLabels, geometry.total > 0 else { return }
        var labelLayer = context
        labelLayer.opacity *= LivelineMath.easedReveal((geometry.progress - 0.5) / 0.5)
        for segment in geometry.segments where segment.isFullyRevealed {
            // A narrow wedge cannot hold a horizontal label without spilling
            // over its neighbours.
            guard segment.span.fullSweep >= style.resolvedMinimumLabelDegrees else { continue }
            let angle = segment.span.middle * Double.pi / 180
            let label = style.showsValues
                ? "\(segment.label) \(formatValue(segment.value))"
                : segment.label
            let isOuter = segment.span.depth > 0
            let radius = isOuter ? geometry.outerRadius + textScale.scaled(13) : segment.pathRadius
            // An inner label sits *inside* its wedge, so the wedge also has to
            // be long enough along the arc to hold the glyphs; an outer label
            // hangs off the rim and only needs the sweep check above.
            if !isOuter {
                let arcLength = segment.span.fullSweep * Double.pi / 180 * Double(segment.pathRadius)
                guard arcLength >= Double(textScale.scaled(CGFloat(label.count) * 5.4)) else { continue }
            }
            drawText(
                label,
                context: &labelLayer,
                at: LivelineMath.polarPoint(center: geometry.center, radius: radius, angle: angle),
                anchor: isOuter ? extendedRadialAnchor(angle: angle) : .center,
                color: isOuter ? palette.gridLabel : .white.opacity(0.94),
                font: textScale.font(9, weight: .medium)
            )
        }
    }

    static func drawSankey(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        geometry: LivelineSankeyGeometry,
        style: LivelineSankeyStyle,
        formatValue: (Double) -> String,
        textScale: LivelineTextScale,
        drawLabels: Bool = true
    ) {
        guard !geometry.nodes.isEmpty, geometry.progress > 0.001 else { return }
        var layer = context
        layer.clip(to: plotClip(layout))

        for link in geometry.links {
            layer.fill(link.path, with: .color(link.color.opacity(style.resolvedLinkOpacity)))
        }

        var nodeLayer = layer
        nodeLayer.opacity *= min(geometry.progress * 2, 1)
        for node in geometry.nodes {
            nodeLayer.fill(
                Path(
                    roundedRect: node.rect,
                    cornerRadius: min(style.resolvedCornerRadius, node.rect.width / 2)
                ),
                with: .color(node.color)
            )
        }

        if drawLabels {
            drawSankeyLabels(
                context: &context,
                layout: layout,
                palette: palette,
                geometry: geometry,
                style: style,
                formatValue: formatValue,
                textScale: textScale
            )
        }
    }

    static func drawSankeyLabels(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        geometry: LivelineSankeyGeometry,
        style: LivelineSankeyStyle,
        formatValue: (Double) -> String,
        textScale: LivelineTextScale
    ) {
        guard style.showsLabels else { return }
        var labelLayer = context
        labelLayer.opacity *= LivelineMath.easedReveal((geometry.progress - 0.45) / 0.55)
        let minimumHeight = textScale.scaled(style.resolvedMinimumLabelHeight)
        let inset = textScale.scaled(5)

        for node in geometry.nodes where node.rect.height >= minimumHeight {
            // A node hugging the right edge has no room outside it, so its
            // label flips to the inboard side. Stated in physical coordinates,
            // this holds for a mirrored right-to-left layout unchanged.
            let leading = node.rect.maxX > geometry.plotRect.maxX - textScale.scaled(40)
            let label = style.showsValues
                ? "\(node.node.label) \(formatValue(node.node.throughput))"
                : node.node.label
            drawText(
                label,
                context: &labelLayer,
                at: CGPoint(
                    x: leading ? node.rect.minX - inset : node.rect.maxX + inset,
                    y: node.rect.midY
                ),
                anchor: leading ? .trailing : .leading,
                color: palette.gridLabel,
                font: textScale.font(9, weight: .medium)
            )
        }
    }
}
