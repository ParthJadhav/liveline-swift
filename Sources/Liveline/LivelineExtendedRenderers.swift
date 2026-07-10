import Foundation
import SwiftUI

extension LivelineRenderer {
    static func drawErrorBars(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        points: [LivelineErrorBarPoint],
        style: LivelineErrorBarStyle,
        alpha: Double
    ) {
        guard !points.isEmpty, alpha > 0.01 else { return }
        var layer = context
        layer.opacity *= alpha
        layer.clip(to: extendedPlotClip(layout))

        for point in points {
            let x = layout.x(for: point.time)
            let lowerY = layout.y(for: point.lower)
            let upperY = layout.y(for: point.upper)
            let center = CGPoint(x: x, y: layout.y(for: point.value))

            if style.resolvedLineWidth > 0 {
                var whisker = Path()
                whisker.move(to: CGPoint(x: x, y: lowerY))
                whisker.addLine(to: CGPoint(x: x, y: upperY))
                whisker.move(to: CGPoint(x: x - style.resolvedCapWidth / 2, y: lowerY))
                whisker.addLine(to: CGPoint(x: x + style.resolvedCapWidth / 2, y: lowerY))
                whisker.move(to: CGPoint(x: x - style.resolvedCapWidth / 2, y: upperY))
                whisker.addLine(to: CGPoint(x: x + style.resolvedCapWidth / 2, y: upperY))
                layer.stroke(
                    whisker,
                    with: .color(palette.line.opacity(0.72)),
                    style: StrokeStyle(lineWidth: style.resolvedLineWidth, lineCap: .round)
                )
            }

            let marker = extendedSymbolPath(style.pointSymbol, center: center, size: style.resolvedPointSize)
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
        alpha: Double
    ) {
        guard !points.isEmpty, alpha > 0.01 else { return }
        var layer = context
        layer.opacity *= alpha
        layer.clip(to: extendedPlotClip(layout))
        let startColor = style.startColor ?? palette.gridLabel
        let endColor = style.endColor ?? palette.line

        for point in points {
            let x = layout.x(for: point.time)
            let start = CGPoint(x: x, y: layout.y(for: point.start))
            let end = CGPoint(x: x, y: layout.y(for: point.end))

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

            let startMarker = extendedSymbolPath(style.pointSymbol, center: start, size: style.resolvedPointSize)
            let endMarker = extendedSymbolPath(style.pointSymbol, center: end, size: style.resolvedPointSize)
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
        alpha: Double
    ) {
        guard !points.isEmpty, alpha > 0.01 else { return }
        let width = extendedBucketWidth(times: points.map(\.time), layout: layout, ratio: style.resolvedWidthRatio, maximum: 48)
        var layer = context
        layer.opacity *= alpha
        layer.clip(to: extendedPlotClip(layout))

        if style.showsBaseline {
            extendedBaseline(context: &layer, layout: layout, palette: palette, value: 0)
        }

        for point in points {
            let x = layout.x(for: point.time)
            for (index, segment) in LivelineMath.stackedSegments(values: point.values, mode: style.mode).enumerated() {
                let lowerY = layout.y(for: segment.lower)
                let upperY = layout.y(for: segment.upper)
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
        alpha: Double
    ) {
        guard !points.isEmpty, alpha > 0.01 else { return }
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
                alpha: alpha
            )
            return
        }
        let maximumSegments = sorted.map { $0.values.count }.max() ?? 0
        var layer = context
        layer.opacity *= alpha
        layer.clip(to: extendedPlotClip(layout))

        if style.showsBaseline {
            extendedBaseline(context: &layer, layout: layout, palette: palette, value: 0)
        }

        for index in 0..<maximumSegments {
            let bounds = sorted.map { point -> (time: TimeInterval, segment: LivelineStackSegment) in
                let segments = LivelineMath.stackedSegments(values: point.values, mode: style.mode)
                return (point.time, index < segments.count ? segments[index] : LivelineStackSegment(lower: 0, upper: 0))
            }
            guard let first = bounds.first else { continue }

            var area = Path()
            area.move(to: CGPoint(x: layout.x(for: first.time), y: layout.y(for: first.segment.upper)))
            for entry in bounds.dropFirst() {
                area.addLine(to: CGPoint(x: layout.x(for: entry.time), y: layout.y(for: entry.segment.upper)))
            }
            for entry in bounds.reversed() {
                area.addLine(to: CGPoint(x: layout.x(for: entry.time), y: layout.y(for: entry.segment.lower)))
            }
            area.closeSubpath()

            let color = extendedSeriesColor(index: index, colors: style.colors, palette: palette)
            layer.fill(area, with: .color(color.opacity(style.resolvedFillOpacity)))

            if style.resolvedBoundaryLineWidth > 0 {
                var boundary = Path()
                boundary.move(to: CGPoint(x: layout.x(for: first.time), y: layout.y(for: first.segment.upper)))
                for entry in bounds.dropFirst() {
                    boundary.addLine(to: CGPoint(x: layout.x(for: entry.time), y: layout.y(for: entry.segment.upper)))
                }
                layer.stroke(
                    boundary,
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
        alpha: Double
    ) {
        guard !items.isEmpty, alpha > 0.01 else { return }
        let laneCount = max((items.map(\.lane).max() ?? 0) + 1, 1)
        let laneHeight = layout.chartHeight / CGFloat(laneCount)
        let barHeight = max(laneHeight * style.resolvedBarHeightRatio, 3)
        var layer = context
        layer.opacity *= alpha

        if style.showsLaneGuides {
            for lane in 0..<laneCount {
                let y = layout.padding.top + CGFloat(lane + 1) * laneHeight
                var guide = Path()
                guide.move(to: CGPoint(x: layout.plotLeftX, y: y))
                guide.addLine(to: CGPoint(x: layout.rightX, y: y))
                layer.stroke(guide, with: .color(palette.gridLine), lineWidth: 1)
            }
        }

        var bars = layer
        bars.clip(to: extendedPlotClip(layout))
        for (index, item) in items.enumerated() {
            let x1 = layout.x(for: item.start)
            let x2 = layout.x(for: item.end)
            let y = layout.padding.top + (CGFloat(item.lane) + 0.5) * laneHeight
            let rect = CGRect(x: min(x1, x2), y: y - barHeight / 2, width: max(abs(x2 - x1), 2), height: barHeight)
            let color = extendedSeriesColor(index: index, colors: style.colors, palette: palette)
            bars.fill(
                Path(roundedRect: rect, cornerRadius: min(style.resolvedCornerRadius, barHeight / 2)),
                with: .color(color.opacity(0.86))
            )

            if style.showsLabels, rect.width > 30 {
                extendedDrawText(
                    item.label,
                    context: &bars,
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
        alpha: Double
    ) {
        guard !cells.isEmpty, alpha > 0.01 else { return }
        let rowCount = max((cells.map(\.row).max() ?? 0) + 1, style.rowLabels.count, 1)
        let rowHeight = layout.chartHeight / CGFloat(rowCount)
        let times = Array(Set(cells.map(\.time))).sorted()
        let width = extendedBucketWidth(times: times, layout: layout, ratio: style.resolvedCellWidthRatio, maximum: .greatestFiniteMagnitude)
        let height = max(rowHeight * style.resolvedCellHeightRatio, 1)
        let minimum = cells.map(\.value).min() ?? 0
        let maximum = cells.map(\.value).max() ?? minimum
        let baseRGB = (style.color ?? palette.line).livelineRGBA()

        var layer = context
        layer.opacity *= alpha
        var clipped = layer
        clipped.clip(to: extendedPlotClip(layout))

        for cell in cells {
            let opacity = LivelineMath.heatmapOpacity(
                value: cell.value,
                minimum: minimum,
                maximum: maximum,
                minimumOpacity: style.resolvedMinimumOpacity,
                maximumOpacity: style.resolvedMaximumOpacity
            )
            let color = palette.backgroundRGB.blended(to: baseRGB, t: opacity).color
            let centerY = layout.padding.top + (CGFloat(cell.row) + 0.5) * rowHeight
            let rect = CGRect(
                x: layout.x(for: cell.time) - width / 2,
                y: centerY - height / 2,
                width: width,
                height: height
            )
            clipped.fill(
                Path(roundedRect: rect, cornerRadius: min(style.resolvedCornerRadius, width / 2, height / 2)),
                with: .color(color)
            )

            if style.showsValues, width > 25, height > 14 {
                extendedDrawText(
                    formatValue(cell.value),
                    context: &clipped,
                    at: CGPoint(x: rect.midX, y: rect.midY),
                    anchor: .center,
                    color: opacity > 0.55 ? .white.opacity(0.9) : palette.gridLabel,
                    font: .system(size: 8, weight: .medium, design: .monospaced)
                )
            }
        }

        for row in 0..<min(rowCount, style.rowLabels.count) {
            let y = layout.padding.top + (CGFloat(row) + 0.5) * rowHeight
            extendedDrawText(
                style.rowLabels[row],
                context: &layer,
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
        alpha: Double
    ) {
        guard points.count >= 3, alpha > 0.01 else { return }
        var layer = context
        layer.opacity *= alpha
        let center = CGPoint(x: (layout.plotLeftX + layout.rightX) / 2, y: layout.padding.top + layout.chartHeight / 2)
        let labelInset: CGFloat = style.showsLabels ? 30 : 8
        let radius = max(8, min(layout.chartWidth, layout.chartHeight) / 2 - labelInset)
        let angleStep = 2 * Double.pi / Double(points.count)
        let startAngle = -Double.pi / 2

        for level in 1...style.resolvedGridLevels {
            let levelRadius = radius * CGFloat(level) / CGFloat(style.resolvedGridLevels)
            var polygon = Path()
            for index in points.indices {
                let point = LivelineMath.polarPoint(center: center, radius: levelRadius, angle: startAngle + Double(index) * angleStep)
                index == points.startIndex ? polygon.move(to: point) : polygon.addLine(to: point)
            }
            polygon.closeSubpath()
            layer.stroke(polygon, with: .color(palette.gridLine), lineWidth: 1)
        }

        for index in points.indices {
            let angle = startAngle + Double(index) * angleStep
            let endpoint = LivelineMath.polarPoint(center: center, radius: radius, angle: angle)
            var spoke = Path()
            spoke.move(to: center)
            spoke.addLine(to: endpoint)
            layer.stroke(spoke, with: .color(palette.gridLine), lineWidth: 1)
        }

        let valuePoints = points.enumerated().map { index, point -> CGPoint in
            let progress = LivelineMath.clamp(
                (point.value - style.range.lowerBound) / (style.range.upperBound - style.range.lowerBound),
                0,
                1
            )
            return LivelineMath.polarPoint(
                center: center,
                radius: radius * CGFloat(progress),
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
                    x: point.x - style.resolvedPointSize / 2,
                    y: point.y - style.resolvedPointSize / 2,
                    width: style.resolvedPointSize,
                    height: style.resolvedPointSize
                ))
                layer.fill(marker, with: .color(palette.line))
            }
        }

        if style.showsLabels {
            for (index, point) in points.enumerated() {
                let angle = startAngle + Double(index) * angleStep
                let labelPoint = LivelineMath.polarPoint(center: center, radius: radius + 14, angle: angle)
                extendedDrawText(
                    point.label,
                    context: &layer,
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
        alpha: Double
    ) {
        let positive = data.filter { $0.value > 0 }
        let total = positive.map(\.value).reduce(0, +)
        guard !positive.isEmpty, total > 0, alpha > 0.01 else { return }
        var layer = context
        layer.opacity *= alpha
        let center = CGPoint(x: (layout.plotLeftX + layout.rightX) / 2, y: layout.padding.top + layout.chartHeight / 2)
        let outerRadius = max(12, min(layout.chartWidth, layout.chartHeight) * (style.showsLabels ? 0.34 : 0.43))
        let innerRadius = outerRadius * style.resolvedInnerRadiusRatio
        let ringWidth = max(2, outerRadius - innerRadius)
        let pathRadius = innerRadius + ringWidth / 2
        var cursor = -90.0

        for (index, entry) in positive.enumerated() {
            let sweep = entry.value / total * 360
            let gap = min(style.resolvedGapDegrees, sweep * 0.7)
            let start = cursor + gap / 2
            let end = cursor + sweep - gap / 2
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

            if style.showsLabels {
                let mid = (start + end) / 2 * Double.pi / 180
                let labelPoint = LivelineMath.polarPoint(center: center, radius: outerRadius + 13, angle: mid)
                let label = style.showsValues ? "\(entry.label) \(formatValue(entry.value))" : entry.label
                extendedDrawText(
                    label,
                    context: &layer,
                    at: labelPoint,
                    anchor: extendedRadialAnchor(angle: mid),
                    color: palette.gridLabel,
                    font: .system(size: 9, weight: .medium)
                )
            }
            cursor += sweep
        }

        extendedDrawText(
            formatValue(total),
            context: &layer,
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
        alpha: Double
    ) {
        guard alpha > 0.01 else { return }
        var layer = context
        layer.opacity *= alpha
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
            hasOuterMarks: style.showsTicks || style.target != nil,
            showsValue: style.showsValue
        )
        let center = geometry.center
        let radius = geometry.radius
        let start = style.resolvedStartAngleDegrees
        let end = start + style.resolvedSweepDegrees
        let progress = LivelineMath.gaugeProgress(value: value, range: range)

        var track = Path()
        track.addArc(center: center, radius: radius, startAngle: .degrees(start), endAngle: .degrees(end), clockwise: false)
        layer.stroke(
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
                endAngle: .degrees(start + style.resolvedSweepDegrees * progress),
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
                let angle = (start + style.resolvedSweepDegrees * Double(index) / Double(lastIndex)) * Double.pi / 180
                let isMajor = index == 0 || index == lastIndex || index * 2 == lastIndex
                let innerRadius = radius + style.resolvedLineWidth / 2 + 5
                let outerRadius = innerRadius + (isMajor ? 7 : 4)
                let inside = LivelineMath.polarPoint(center: center, radius: innerRadius, angle: angle)
                let outside = LivelineMath.polarPoint(center: center, radius: outerRadius, angle: angle)
                var tick = Path()
                tick.move(to: inside)
                tick.addLine(to: outside)
                layer.stroke(
                    tick,
                    with: .color(palette.tooltipText.opacity(isMajor ? 0.42 : 0.26)),
                    style: StrokeStyle(lineWidth: isMajor ? 1.5 : 1, lineCap: .round)
                )
            }
        }

        if let target = style.target {
            let targetProgress = LivelineMath.gaugeProgress(value: target, range: range)
            let angle = (start + style.resolvedSweepDegrees * targetProgress) * Double.pi / 180
            let markerColor = style.targetColor ?? palette.tooltipText
            let markerCenter = LivelineMath.polarPoint(
                center: center,
                radius: radius + style.resolvedLineWidth / 2 + 6,
                angle: angle
            )
            let targetPin = extendedSymbolPath(.diamond, center: markerCenter, size: 8)
            layer.fill(targetPin, with: .color(markerColor))
            layer.stroke(targetPin, with: .color(palette.backgroundRGB.color), lineWidth: 1)
        }

        if style.showsValue {
            extendedDrawText(
                formatValue(value),
                context: &layer,
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
        alpha: Double
    ) {
        let positive = data.filter { $0.value > 0 }
        guard !positive.isEmpty, alpha > 0.01 else { return }
        var layer = context
        layer.opacity *= alpha
        let maximum = positive.map(\.value).max() ?? 1
        let stageHeight = max(8, (layout.chartHeight - style.resolvedSpacing * CGFloat(max(positive.count - 1, 0))) / CGFloat(positive.count))
        let maxWidth = layout.chartWidth * style.resolvedMaximumWidthRatio
        let minWidth = layout.chartWidth * style.resolvedMinimumWidthRatio
        let centerX = (layout.plotLeftX + layout.rightX) / 2

        for (index, entry) in positive.enumerated() {
            let ratio = maximum > 0 ? entry.value / maximum : 0
            let width = minWidth + CGFloat(ratio) * (maxWidth - minWidth)
            let y = layout.padding.top + CGFloat(index) * (stageHeight + style.resolvedSpacing)
            let rect = CGRect(x: centerX - width / 2, y: y, width: width, height: stageHeight)
            let color = extendedSeriesColor(index: index, colors: style.colors, palette: palette)
            layer.fill(
                Path(roundedRect: rect, cornerRadius: min(style.resolvedCornerRadius, stageHeight / 2)),
                with: .color(color.opacity(0.88))
            )

            if style.showsLabels || style.showsValues {
                let label: String
                if style.showsLabels, style.showsValues {
                    label = "\(entry.label) · \(formatValue(entry.value))"
                } else if style.showsLabels {
                    label = entry.label
                } else {
                    label = formatValue(entry.value)
                }
                extendedDrawText(
                    label,
                    context: &layer,
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

    static func extendedPlotClip(_ layout: LivelineLayout) -> Path {
        Path(CGRect(x: layout.plotLeftX, y: layout.padding.top, width: layout.chartWidth, height: layout.chartHeight))
    }

    static func extendedBucketWidth(
        times: [TimeInterval],
        layout: LivelineLayout,
        ratio: CGFloat,
        maximum: CGFloat
    ) -> CGFloat {
        let sorted = Array(Set(times)).sorted()
        let deltas = zip(sorted, sorted.dropFirst()).map { $1 - $0 }.filter { $0 > 0 }
        let bucket = deltas.min() ?? (layout.rightEdge - layout.leftEdge) / Double(max(sorted.count, 8))
        let bucketWidth = CGFloat(bucket / max(layout.rightEdge - layout.leftEdge, 0.001)) * layout.chartWidth
        return min(max(bucketWidth * ratio, 2), maximum)
    }

    static func extendedBaseline(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        value: Double
    ) {
        let y = LivelineMath.clamp(layout.y(for: value), layout.padding.top, layout.bottomY)
        var path = Path()
        path.move(to: CGPoint(x: layout.plotLeftX, y: y))
        path.addLine(to: CGPoint(x: layout.rightX, y: y))
        context.stroke(path, with: .color(palette.referenceLine), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
    }

    static func extendedSymbolPath(_ symbol: LivelineScatterSymbol, center: CGPoint, size: CGFloat) -> Path {
        let half = size / 2
        switch symbol {
        case .circle:
            return Path(ellipseIn: CGRect(x: center.x - half, y: center.y - half, width: size, height: size))
        case .square:
            return Path(roundedRect: CGRect(x: center.x - half, y: center.y - half, width: size, height: size), cornerRadius: min(1.5, half))
        case .diamond:
            var path = Path()
            path.move(to: CGPoint(x: center.x, y: center.y - half))
            path.addLine(to: CGPoint(x: center.x + half, y: center.y))
            path.addLine(to: CGPoint(x: center.x, y: center.y + half))
            path.addLine(to: CGPoint(x: center.x - half, y: center.y))
            path.closeSubpath()
            return path
        }
    }

    static func extendedRadialAnchor(angle: Double) -> UnitPoint {
        let x = cos(angle)
        let y = sin(angle)
        return UnitPoint(x: 0.5 - x * 0.5, y: 0.5 - y * 0.5)
    }

    static func extendedDrawText(
        _ text: String,
        context: inout GraphicsContext,
        at point: CGPoint,
        anchor: UnitPoint,
        color: Color,
        font: Font
    ) {
        context.draw(Text(text).font(font).foregroundColor(color), at: point, anchor: anchor)
    }
}
