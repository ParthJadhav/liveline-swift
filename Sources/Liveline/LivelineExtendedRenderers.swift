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
        items: [LivelineTimelineItem],
        style: LivelineTimelineStyle,
        reveal: Double
    ) {
        let progress = LivelineMath.easedReveal(reveal)
        guard !items.isEmpty, progress > 0.001 else { return }
        let laneCount = max((items.map(\.lane).max() ?? 0) + 1, 1)
        let laneHeight = layout.chartHeight / CGFloat(laneCount)
        let barHeight = max(laneHeight * style.resolvedBarHeightRatio, 3)
        let layer = context

        if style.showsLaneGuides {
            var guideLayer = layer
            guideLayer.opacity *= min(progress * 2, 1)
            for lane in 0..<laneCount {
                let y = layout.padding.top + CGFloat(lane + 1) * laneHeight
                var guide = Path()
                guide.move(to: CGPoint(x: layout.plotLeftX, y: y))
                guide.addLine(to: CGPoint(x: layout.rightX, y: y))
                guideLayer.stroke(guide, with: .color(palette.gridLine), lineWidth: 1)
            }
        }

        var bars = layer
        bars.clip(to: plotClip(layout))
        for (index, item) in items.enumerated() {
            let localReveal = LivelineMath.staggeredReveal(index: index, count: items.count, reveal: reveal)
            guard localReveal > 0.001 else { continue }
            let x1 = layout.x(for: item.start)
            let x2 = layout.x(for: item.end)
            let displayedX2 = x1 + (x2 - x1) * CGFloat(localReveal)
            let y = layout.padding.top + (CGFloat(item.lane) + 0.5) * laneHeight
            let rect = CGRect(
                x: min(x1, displayedX2),
                y: y - barHeight / 2,
                width: max(abs(displayedX2 - x1), 2),
                height: barHeight
            )
            let color = extendedSeriesColor(index: index, colors: style.colors, palette: palette)
            bars.fill(
                Path(roundedRect: rect, cornerRadius: min(style.resolvedCornerRadius, barHeight / 2)),
                with: .color(color.opacity(0.86))
            )

            if style.showsLabels, localReveal > 0.72, rect.width > 30 {
                var labelLayer = bars
                labelLayer.opacity *= LivelineMath.easedReveal((localReveal - 0.72) / 0.28)
                drawText(
                    item.label,
                    context: &labelLayer,
                    at: CGPoint(x: rect.midX, y: rect.midY),
                    anchor: .center,
                    color: .white.opacity(0.92),
                    font: .system(size: 9, weight: .semibold)
                )
            }
        }
    }

    static func drawHeatmap(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        cells: [LivelineHeatmapCell],
        style: LivelineHeatmapStyle,
        formatValue: (Double) -> String,
        reveal: Double
    ) {
        let progress = LivelineMath.easedReveal(reveal)
        guard !cells.isEmpty, progress > 0.001 else { return }
        let rowCount = max((cells.map(\.row).max() ?? 0) + 1, style.rowLabels.count, 1)
        let rowHeight = layout.chartHeight / CGFloat(rowCount)
        let times = Array(Set(cells.map(\.time))).sorted()
        let width = bucketWidth(times: times, layout: layout, ratio: style.resolvedCellWidthRatio, maximum: .greatestFiniteMagnitude)
        let height = max(rowHeight * style.resolvedCellHeightRatio, 1)
        let minimum = cells.map(\.value).min() ?? 0
        let maximum = cells.map(\.value).max() ?? minimum
        let baseColor = style.color ?? palette.line
        let baseRGB = baseColor.livelineRGBA()
        let orderedCells = cells.sorted {
            $0.time == $1.time ? $0.row < $1.row : $0.time < $1.time
        }

        let layer = context
        var clipped = layer
        clipped.clip(to: plotClip(layout))

        for (index, cell) in orderedCells.enumerated() {
            let localReveal = LivelineMath.staggeredReveal(index: index, count: orderedCells.count, reveal: reveal)
            guard localReveal > 0.001 else { continue }
            let opacity = LivelineMath.heatmapOpacity(
                value: cell.value,
                minimum: minimum,
                maximum: maximum,
                minimumOpacity: style.resolvedMinimumOpacity,
                maximumOpacity: style.resolvedMaximumOpacity
            )
            let color = baseRGB.map { palette.backgroundRGB.blended(to: $0, t: opacity).color }
                ?? baseColor.opacity(opacity)
            let centerY = layout.padding.top + (CGFloat(cell.row) + 0.5) * rowHeight
            let displayedWidth = width * CGFloat(localReveal)
            let displayedHeight = height * CGFloat(localReveal)
            let rect = CGRect(
                x: layout.x(for: cell.time) - displayedWidth / 2,
                y: centerY - displayedHeight / 2,
                width: displayedWidth,
                height: displayedHeight
            )
            clipped.fill(
                Path(roundedRect: rect, cornerRadius: min(style.resolvedCornerRadius, displayedWidth / 2, displayedHeight / 2)),
                with: .color(color)
            )

            if style.showsValues, localReveal > 0.8, width > 25, height > 14 {
                var valueLayer = clipped
                valueLayer.opacity *= LivelineMath.easedReveal((localReveal - 0.8) / 0.2)
                drawText(
                    formatValue(cell.value),
                    context: &valueLayer,
                    at: CGPoint(x: rect.midX, y: rect.midY),
                    anchor: .center,
                    color: opacity > 0.55 ? .white.opacity(0.9) : palette.gridLabel,
                    font: .system(size: 8, weight: .medium, design: .monospaced)
                )
            }
        }

        var labelLayer = layer
        labelLayer.opacity *= min(progress * 2, 1)
        for row in 0..<min(rowCount, style.rowLabels.count) {
            let y = layout.padding.top + (CGFloat(row) + 0.5) * rowHeight
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
        layout: LivelineLayout,
        palette: LivelinePalette,
        points: [LivelineRadarPoint],
        style: LivelineRadarStyle,
        reveal: Double
    ) {
        let progress = LivelineMath.easedReveal(reveal)
        guard points.count >= 3, progress > 0.001 else { return }
        let layer = context
        let center = CGPoint(x: (layout.plotLeftX + layout.rightX) / 2, y: layout.padding.top + layout.chartHeight / 2)
        let labelInset: CGFloat = style.showsLabels ? 30 : 8
        let radius = max(8, min(layout.chartWidth, layout.chartHeight) / 2 - labelInset)
        let angleStep = 2 * Double.pi / Double(points.count)
        let startAngle = -Double.pi / 2

        var gridLayer = layer
        gridLayer.opacity *= min(progress * 1.8, 1)
        for level in 1...style.resolvedGridLevels {
            let levelRadius = radius * CGFloat(level) / CGFloat(style.resolvedGridLevels)
            var polygon = Path()
            for index in points.indices {
                let point = LivelineMath.polarPoint(center: center, radius: levelRadius, angle: startAngle + Double(index) * angleStep)
                index == points.startIndex ? polygon.move(to: point) : polygon.addLine(to: point)
            }
            polygon.closeSubpath()
            gridLayer.stroke(polygon, with: .color(palette.gridLine), lineWidth: 1)
        }

        for index in points.indices {
            let angle = startAngle + Double(index) * angleStep
            let endpoint = LivelineMath.polarPoint(center: center, radius: radius, angle: angle)
            var spoke = Path()
            spoke.move(to: center)
            spoke.addLine(to: endpoint)
            gridLayer.stroke(spoke, with: .color(palette.gridLine), lineWidth: 1)
        }

        let valuePoints = points.enumerated().map { index, point -> CGPoint in
            let progress = LivelineMath.clamp(
                (point.value - style.resolvedRange.lowerBound) / (style.resolvedRange.upperBound - style.resolvedRange.lowerBound),
                0,
                1
            )
            return LivelineMath.polarPoint(
                center: center,
                radius: radius * CGFloat(progress * LivelineMath.easedReveal(reveal)),
                angle: startAngle + Double(index) * angleStep
            )
        }

        var valuePath = Path()
        for (index, point) in valuePoints.enumerated() {
            index == 0 ? valuePath.move(to: point) : valuePath.addLine(to: point)
        }
        valuePath.closeSubpath()
        layer.fill(valuePath, with: .color(palette.line.opacity(style.resolvedFillOpacity)))
        if style.resolvedLineWidth > 0 {
            layer.stroke(valuePath, with: .color(palette.line), style: StrokeStyle(lineWidth: style.resolvedLineWidth, lineJoin: .round))
        }

        if style.resolvedPointSize > 0 {
            for point in valuePoints {
                let marker = Path(ellipseIn: CGRect(
                    x: point.x - style.resolvedPointSize * CGFloat(progress) / 2,
                    y: point.y - style.resolvedPointSize * CGFloat(progress) / 2,
                    width: style.resolvedPointSize * CGFloat(progress),
                    height: style.resolvedPointSize * CGFloat(progress)
                ))
                layer.fill(marker, with: .color(palette.line))
            }
        }

        if style.showsLabels {
            var labelLayer = layer
            labelLayer.opacity *= LivelineMath.easedReveal((progress - 0.45) / 0.55)
            for (index, point) in points.enumerated() {
                let angle = startAngle + Double(index) * angleStep
                let labelPoint = LivelineMath.polarPoint(center: center, radius: radius + 14, angle: angle)
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
    }

    static func drawDonut(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        data: [LivelineCategoryValue],
        style: LivelineDonutStyle,
        formatValue: (Double) -> String,
        reveal: Double
    ) {
        let positive = data.filter { $0.value > 0 }
        let total = positive.map(\.value).reduce(0, +)
        let progress = LivelineMath.easedReveal(reveal)
        guard !positive.isEmpty, total > 0, progress > 0.001 else { return }
        var layer = context
        let center = CGPoint(x: (layout.plotLeftX + layout.rightX) / 2, y: layout.padding.top + layout.chartHeight / 2)
        let outerRadius = max(12, min(layout.chartWidth, layout.chartHeight) * (style.showsLabels ? 0.34 : 0.43))
        let innerRadius = outerRadius * style.resolvedInnerRadiusRatio
        let ringWidth = max(2, outerRadius - innerRadius)
        let pathRadius = innerRadius + ringWidth / 2
        var cursor = -90.0
        var consumedSweep = 0.0
        let visibleSweep = 360 * progress

        for (index, entry) in positive.enumerated() {
            let sweep = entry.value / total * 360
            let gap = min(style.resolvedGapDegrees, sweep * 0.7)
            let revealedSweep = LivelineMath.clamp(visibleSweep - consumedSweep, 0, sweep)
            let start = cursor + gap / 2
            let end = cursor + revealedSweep - gap / 2
            if end > start {
                var arc = Path()
                arc.addArc(
                    center: center,
                    radius: pathRadius,
                    startAngle: .degrees(start),
                    endAngle: .degrees(end),
                    clockwise: false
                )
                let color = extendedSeriesColor(index: index, colors: style.colors, palette: palette)
                layer.stroke(arc, with: .color(color), style: StrokeStyle(lineWidth: ringWidth, lineCap: .butt))
            }

            if style.showsLabels, revealedSweep >= sweep * 0.98 {
                let finalEnd = cursor + sweep - gap / 2
                let mid = (start + finalEnd) / 2 * Double.pi / 180
                let labelPoint = LivelineMath.polarPoint(center: center, radius: outerRadius + 13, angle: mid)
                let label = style.showsValues ? "\(entry.label) \(formatValue(entry.value))" : entry.label
                drawText(
                    label,
                    context: &layer,
                    at: labelPoint,
                    anchor: extendedRadialAnchor(angle: mid),
                    color: palette.gridLabel,
                    font: .system(size: 9, weight: .medium)
                )
            }
            cursor += sweep
            consumedSweep += sweep
        }

        var valueLayer = layer
        valueLayer.opacity *= LivelineMath.easedReveal((progress - 0.55) / 0.45)
        drawText(
            formatValue(total),
            context: &valueLayer,
            at: center,
            anchor: .center,
            color: palette.tooltipText,
            font: .system(size: 15, weight: .semibold, design: .rounded)
        )
    }

    static func drawGauge(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        value: Double,
        range: ClosedRange<Double>,
        style: LivelineGaugeStyle,
        formatValue: (Double) -> String,
        reveal: Double
    ) {
        let revealProgress = LivelineMath.easedReveal(reveal)
        guard revealProgress > 0.001 else { return }
        let layer = context
        let plotRect = CGRect(
            x: layout.plotLeftX,
            y: layout.padding.top,
            width: layout.chartWidth,
            height: layout.chartHeight
        )
        let geometry = LivelineMath.gaugeGeometry(
            in: plotRect,
            startAngleDegrees: style.resolvedStartAngleDegrees,
            sweepDegrees: style.resolvedSweepDegrees,
            lineWidth: style.resolvedLineWidth,
            hasOuterMarks: style.showsTicks || style.resolvedTarget != nil,
            showsValue: style.showsValue
        )
        let center = geometry.center
        let radius = geometry.radius
        let start = style.resolvedStartAngleDegrees
        let end = start + style.resolvedSweepDegrees
        let progress = LivelineMath.gaugeProgress(value: value, range: range)

        var trackLayer = layer
        trackLayer.opacity *= min(revealProgress * 2, 1)
        var track = Path()
        track.addArc(center: center, radius: radius, startAngle: .degrees(start), endAngle: .degrees(end), clockwise: false)
        trackLayer.stroke(
            track,
            with: .color(palette.tooltipText.opacity(style.resolvedTrackOpacity)),
            style: StrokeStyle(lineWidth: style.resolvedLineWidth, lineCap: .round)
        )

        if progress > 0 {
            var progressPath = Path()
            progressPath.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(start),
                endAngle: .degrees(start + style.resolvedSweepDegrees * progress * revealProgress),
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
                let tickReveal = LivelineMath.staggeredReveal(index: index, count: style.resolvedTickCount, reveal: reveal)
                guard tickReveal > 0.001 else { continue }
                let angle = (start + style.resolvedSweepDegrees * Double(index) / Double(lastIndex)) * Double.pi / 180
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

        if let target = style.resolvedTarget {
            let targetReveal = LivelineMath.easedReveal((revealProgress - 0.72) / 0.28)
            let targetProgress = LivelineMath.gaugeProgress(value: target, range: range)
            let angle = (start + style.resolvedSweepDegrees * targetProgress) * Double.pi / 180
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

        if style.showsValue {
            var valueLayer = layer
            valueLayer.opacity *= LivelineMath.easedReveal((revealProgress - 0.35) / 0.65)
            let displayedValue = range.lowerBound + (value - range.lowerBound) * revealProgress
            drawText(
                formatValue(displayedValue),
                context: &valueLayer,
                at: CGPoint(x: center.x, y: center.y + min(10, radius * 0.08)),
                anchor: .center,
                color: palette.tooltipText,
                font: .system(size: 24, weight: .semibold, design: .rounded)
            )
        }
    }

    static func drawFunnel(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        data: [LivelineCategoryValue],
        style: LivelineFunnelStyle,
        formatValue: (Double) -> String,
        reveal: Double
    ) {
        let positive = data.filter { $0.value > 0 }
        let progress = LivelineMath.easedReveal(reveal)
        guard !positive.isEmpty, progress > 0.001 else { return }
        let layer = context
        let maximum = positive.map(\.value).max() ?? 1
        let stageHeight = max(8, (layout.chartHeight - style.resolvedSpacing * CGFloat(max(positive.count - 1, 0))) / CGFloat(positive.count))
        let maxWidth = layout.chartWidth * style.resolvedMaximumWidthRatio
        let minWidth = layout.chartWidth * style.resolvedMinimumWidthRatio
        let centerX = (layout.plotLeftX + layout.rightX) / 2

        for (index, entry) in positive.enumerated() {
            let localReveal = LivelineMath.staggeredReveal(index: index, count: positive.count, reveal: reveal, staggerFraction: 0.5)
            guard localReveal > 0.001 else { continue }
            let ratio = maximum > 0 ? entry.value / maximum : 0
            let targetWidth = minWidth + CGFloat(ratio) * (maxWidth - minWidth)
            let width = targetWidth * CGFloat(localReveal)
            let y = layout.padding.top + CGFloat(index) * (stageHeight + style.resolvedSpacing)
            let rect = CGRect(x: centerX - width / 2, y: y, width: width, height: stageHeight)
            let color = extendedSeriesColor(index: index, colors: style.colors, palette: palette)
            layer.fill(
                Path(roundedRect: rect, cornerRadius: min(style.resolvedCornerRadius, stageHeight / 2)),
                with: .color(color.opacity(0.88))
            )

            if localReveal > 0.65, style.showsLabels || style.showsValues {
                var labelLayer = layer
                labelLayer.opacity *= LivelineMath.easedReveal((localReveal - 0.65) / 0.35)
                let label: String
                if style.showsLabels, style.showsValues {
                    label = "\(entry.label) · \(formatValue(entry.value))"
                } else if style.showsLabels {
                    label = entry.label
                } else {
                    label = formatValue(entry.value)
                }
                drawText(
                    label,
                    context: &labelLayer,
                    at: CGPoint(x: rect.midX, y: rect.midY),
                    anchor: .center,
                    color: .white.opacity(0.94),
                    font: .system(size: 10, weight: .semibold)
                )
            }
        }
    }
}

private extension LivelineRenderer {
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
