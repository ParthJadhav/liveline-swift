import SwiftUI

private struct LivelineChordNodeGeometry {
    var label: String
    var start: Double
    var end: Double
    var value: Double
    var color: Color
}

extension LivelineRenderer {
    static func drawChord(
        context: inout GraphicsContext,
        links: [LivelineChordLink],
        style: LivelineChordStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        reveal: Double,
        textScale: LivelineTextScale,
        drawMarks: Bool,
        drawLabels: Bool
    ) {
        let positive = links.filter { $0.value > 0 }
        guard !positive.isEmpty else { return }
        let geometry = LivelineAdvancedLayout.chord(
            links: links, style: style, layout: layout, textScale: textScale)
        let center = geometry.center
        let outerRadius = geometry.outerRadius
        let innerRadius = geometry.innerRadius
        let nodes = geometry.arcs.map { arc in
            LivelineChordNodeGeometry(
                label: arc.label,
                start: arc.start,
                end: arc.start + arc.sweep * reveal,
                value: arc.value,
                color: advancedColor(index: arc.index, colors: style.colors, palette: palette)
            )
        }
        let byLabel = Dictionary(nodes.map { ($0.label, $0) }, uniquingKeysWith: { first, _ in first })
        if drawMarks {
            for node in nodes {
                var arc = Path()
                arc.addArc(
                    center: center, radius: (outerRadius + innerRadius) / 2, startAngle: .radians(node.start),
                    endAngle: .radians(node.end), clockwise: false)
                context.stroke(
                    arc, with: .color(node.color),
                    style: StrokeStyle(lineWidth: max(outerRadius - innerRadius, 2), lineCap: .butt))
            }
            for link in positive {
                guard let source = byLabel[link.source], let target = byLabel[link.target] else { continue }
                let sourceAngle = (source.start + source.end) / 2
                let targetAngle = (target.start + target.end) / 2
                let sourceHalf =
                    (source.end - source.start) * min(link.value / max(source.value, 0.000_001), 1) * 0.42
                let targetHalf =
                    (target.end - target.start) * min(link.value / max(target.value, 0.000_001), 1) * 0.42
                let sourceStart = sourceAngle - sourceHalf
                let sourceEnd = sourceAngle + sourceHalf
                let targetStart = targetAngle - targetHalf
                let targetEnd = targetAngle + targetHalf
                let start = LivelineMath.polarPoint(
                    center: center, radius: innerRadius - 1, angle: sourceStart)
                let end = LivelineMath.polarPoint(center: center, radius: innerRadius - 1, angle: targetEnd)
                var ribbon = Path()
                ribbon.move(to: start)
                ribbon.addCurve(to: end, control1: center, control2: center)
                ribbon.addArc(
                    center: center, radius: innerRadius - 1, startAngle: .radians(targetEnd),
                    endAngle: .radians(targetStart), clockwise: true)
                let sourceReturn = LivelineMath.polarPoint(
                    center: center, radius: innerRadius - 1, angle: sourceEnd)
                ribbon.addCurve(to: sourceReturn, control1: center, control2: center)
                ribbon.addArc(
                    center: center, radius: innerRadius - 1, startAngle: .radians(sourceEnd),
                    endAngle: .radians(sourceStart), clockwise: true)
                ribbon.closeSubpath()
                context.fill(
                    ribbon, with: .color(source.color.opacity(style.resolvedRibbonOpacity * reveal)))
            }
        }

        if drawLabels, style.showsLabels {
            for node in nodes where node.end - node.start > 0.08 {
                let middle = (node.start + node.end) / 2
                let point = LivelineMath.polarPoint(
                    center: center, radius: outerRadius + textScale.scaled(9), angle: middle)
                let anchor: UnitPoint = cos(middle) >= 0 ? .leading : .trailing
                drawText(
                    node.label, context: &context, at: point, anchor: anchor, color: palette.gridLabel,
                    font: textScale.font(9, weight: .medium))
            }
        }
    }

    static func drawParallelCoordinates(
        context: inout GraphicsContext,
        records: [LivelineParallelRecord],
        style: LivelineParallelCoordinatesStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        reveal: Double,
        textScale: LivelineTextScale,
        drawMarks: Bool,
        drawLabels: Bool
    ) {
        guard
            let geometry = LivelineAdvancedLayout.parallelCoordinates(
                records: records, layout: layout, textScale: textScale)
        else { return }
        let axisCount = geometry.axisCount
        let plot = geometry.plot
        let body = geometry.body

        if drawMarks {
            for axis in 0..<axisCount {
                var line = Path()
                line.move(to: CGPoint(x: geometry.x(axis: axis), y: body.minY))
                line.addLine(to: CGPoint(x: geometry.x(axis: axis), y: body.maxY))
                context.stroke(line, with: .color(palette.referenceLine), lineWidth: 1)
            }
            for (index, record) in records.enumerated() {
                let color = advancedColor(index: index, colors: style.colors, palette: palette)
                var path = Path()
                for axis in 0..<min(axisCount, record.values.count) {
                    let point = CGPoint(
                        x: geometry.x(axis: axis), y: geometry.y(record.values[axis], axis: axis))
                    axis == 0 ? path.move(to: point) : path.addLine(to: point)
                    if style.showsPoints {
                        context.fill(
                            Path(ellipseIn: CGRect(x: point.x - 2.5, y: point.y - 2.5, width: 5, height: 5)),
                            with: .color(color.opacity(reveal)))
                    }
                }
                context.stroke(
                    path, with: .color(color.opacity(style.resolvedLineOpacity * reveal)),
                    style: StrokeStyle(lineWidth: style.resolvedLineWidth, lineCap: .round, lineJoin: .round))
            }
        }
        if drawLabels {
            for axis in 0..<axisCount {
                drawText(
                    LivelineAdvancedLayout.axisLabel(style.axisLabels, at: axis), context: &context,
                    at: CGPoint(x: geometry.x(axis: axis), y: plot.minY), anchor: .top,
                    color: palette.gridLabel, font: textScale.font(9, weight: .medium))
            }
            if geometry.recordLabelWidth > 0 {
                for (index, record) in records.enumerated() {
                    guard let value = record.values.last else { continue }
                    let color = advancedColor(index: index, colors: style.colors, palette: palette)
                    let y = geometry.y(value, axis: record.values.count - 1)
                    drawText(
                        record.label, context: &context, at: CGPoint(x: body.maxX + textScale.scaled(5), y: y),
                        anchor: .leading, color: color, font: textScale.font(8, weight: .semibold))
                }
            }
        }
    }

    static func drawHexbin(
        context: inout GraphicsContext,
        points: [LivelineXYPoint],
        style: LivelineHexbinStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        reveal: Double,
        textScale: LivelineTextScale,
        drawMarks: Bool,
        drawLabels: Bool
    ) {
        guard
            let geometry = LivelineAdvancedLayout.hexbin(
                points: points, style: style, layout: layout, textScale: textScale)
        else { return }
        let plot = geometry.plot
        let radius = geometry.radius
        if drawMarks {
            let bleed = plot.insetBy(dx: -radius, dy: -radius)
            for cell in geometry.cells where bleed.contains(cell.center) {
                let ratio = cell.weight / geometry.maximumWeight
                let opacity =
                    style.resolvedMinimumOpacity
                    + (style.resolvedMaximumOpacity - style.resolvedMinimumOpacity) * ratio
                context.fill(
                    hexagon(center: cell.center, radius: radius * 0.94),
                    with: .color(palette.line.opacity(opacity * reveal)))
            }
        }
        if drawLabels, style.showsCounts {
            for cell in geometry.cells where cell.count > 1 && plot.contains(cell.center) {
                drawText(
                    "\(cell.count)", context: &context, at: cell.center, anchor: .center,
                    color: palette.tooltipText,
                    font: textScale.font(8, weight: .semibold, design: .monospaced))
            }
        }
    }

    static func hexagon(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        for index in 0..<6 {
            let angle = Double(index) * Double.pi / 3
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    static func drawMarimekko(
        context: inout GraphicsContext,
        columns: [LivelineMarimekkoColumn],
        style: LivelineMarimekkoStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        configuration: LivelineChartConfiguration,
        reveal: Double,
        textScale: LivelineTextScale,
        drawMarks: Bool,
        drawLabels: Bool
    ) {
        let geometry = LivelineAdvancedLayout.marimekko(
            columns: columns, style: style, layout: layout, textScale: textScale,
            displayScale: context.environment.displayScale)
        guard !geometry.geometry.isEmpty else { return }
        let plot = geometry.plot
        let body = geometry.body
        let revealClip = CGRect(
            x: body.minX,
            y: body.maxY - body.height * CGFloat(reveal),
            width: body.width,
            height: body.height * CGFloat(reveal)
        )
        var markLayer = context
        markLayer.clip(to: Path(revealClip))
        for columnGeometry in geometry.geometry {
            let column = geometry.columns[columnGeometry.columnIndex]
            for segmentGeometry in columnGeometry.segments {
                let segment = column.segments[segmentGeometry.segmentIndex]
                let rect = segmentGeometry.rect
                let color = advancedColor(
                    index: geometry.colorIndexBySegmentID[segment.id] ?? 0, colors: style.colors,
                    palette: palette)
                if drawMarks { markLayer.fill(Path(rect), with: .color(color.opacity(0.78))) }
                if drawLabels, style.showsValues, rect.width > textScale.scaled(36),
                    rect.height > textScale.scaled(16)
                {
                    drawText(
                        configuration.formatValue(segment.value), context: &context,
                        at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center, color: .white.opacity(0.94),
                        font: textScale.font(8, weight: .semibold, design: .monospaced))
                }
            }
            if drawLabels, style.showsLabels {
                drawText(
                    column.label, context: &context,
                    at: CGPoint(x: columnGeometry.rect.midX, y: plot.maxY - textScale.scaled(4)), anchor: .bottom,
                    color: palette.gridLabel, font: textScale.font(9, weight: .medium))
            }
        }
    }

    static func drawPolarArea(
        context: inout GraphicsContext,
        values: [LivelineCategoryValue],
        style: LivelinePolarAreaStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        reveal: Double,
        textScale: LivelineTextScale,
        drawMarks: Bool,
        drawLabels: Bool
    ) {
        let geometry = LivelineAdvancedLayout.polarArea(
            values: values, style: style, layout: layout, textScale: textScale)
        guard !geometry.wedges.isEmpty else { return }
        let center = geometry.center
        let inner = geometry.innerRadius
        let outer = geometry.outerRadius
        for wedge in geometry.wedges {
            let start = wedge.start
            let end = start + wedge.sweep * reveal
            let radius = wedge.radius
            let color = advancedColor(index: wedge.index, colors: style.colors, palette: palette)
            if drawMarks {
                var wedge = Path()
                wedge.addArc(
                    center: center, radius: radius, startAngle: .radians(start), endAngle: .radians(end),
                    clockwise: false)
                if inner > 0 {
                    wedge.addArc(
                        center: center, radius: inner, startAngle: .radians(end), endAngle: .radians(start),
                        clockwise: true)
                } else {
                    wedge.addLine(to: center)
                }
                wedge.closeSubpath()
                context.fill(wedge, with: .color(color.opacity(style.resolvedFillOpacity)))
            }
            if drawLabels, style.showsLabels {
                let middle = (start + end) / 2
                let point = LivelineMath.polarPoint(
                    center: center, radius: outer + textScale.scaled(8), angle: middle)
                drawText(
                    wedge.value.label, context: &context, at: point,
                    anchor: cos(middle) >= 0 ? .leading : .trailing, color: palette.gridLabel,
                    font: textScale.font(9, weight: .medium))
            }
        }
    }
}

// MARK: - Networks, fields, and compositions

extension LivelineRenderer {
    static func drawNetwork(
        context: inout GraphicsContext,
        nodes: [LivelineNetworkNode],
        edges: [LivelineNetworkEdge],
        style: LivelineNetworkStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        reveal: Double,
        textScale: LivelineTextScale,
        drawMarks: Bool,
        drawLabels: Bool
    ) {
        guard
            let geometry = LivelineAdvancedLayout.network(
                nodes: nodes, edges: edges, style: style, layout: layout, textScale: textScale)
        else { return }

        if drawMarks {
            let maxEdge = max(edges.map(\.value).max() ?? 0, 0.000_001)
            for edge in edges {
                guard let start = geometry.positionsByID[edge.source],
                    let end = geometry.positionsByID[edge.target]
                else { continue }
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                context.stroke(
                    path, with: .color(palette.gridLabel.opacity(style.resolvedEdgeOpacity * reveal)),
                    lineWidth: max(CGFloat(edge.value / maxEdge) * 3, 0.75))
            }
        }

        for placement in geometry.placements {
            let center = placement.center
            let size = placement.size
            let color = advancedColor(
                index: placement.colorIndex, colors: style.colors, palette: palette)
            if drawMarks {
                let bounds = CGRect(
                    x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
                context.fill(Path(ellipseIn: bounds), with: .color(color.opacity(0.82 * reveal)))
                context.stroke(Path(ellipseIn: bounds), with: .color(color), lineWidth: 1)
            }
            if drawLabels, style.showsLabels {
                drawText(
                    placement.node.label, context: &context,
                    at: CGPoint(x: center.x, y: center.y + size / 2 + textScale.scaled(4)), anchor: .top,
                    color: palette.gridLabel, font: textScale.font(8, weight: .medium))
            }
        }
    }

    static func drawContour(
        context: inout GraphicsContext,
        state: LivelineRenderState,
        samples: [LivelineContourSample],
        style: LivelineContourStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        configuration: LivelineChartConfiguration,
        reveal: Double,
        textScale: LivelineTextScale,
        drawMarks: Bool,
        drawLabels: Bool
    ) {
        guard
            let layoutGeometry = LivelineAdvancedLayout.contour(
                samples: samples, layout: layout, textScale: textScale)
        else { return }
        let plot = layoutGeometry.plot
        let minimum = layoutGeometry.valueRange.lowerBound
        let span = max(layoutGeometry.valueRange.upperBound - minimum, 0.000_001)
        if drawMarks {
            let geometry = state.contourGeometry(
                samples: samples,
                levelCount: style.resolvedLevelCount,
                plot: plot,
                subdivisions: layoutGeometry.subdivisions
            )
            var layer = context
            layer.clip(to: Path(plot))
            if style.showsFill {
                for level in 0..<style.resolvedLevelCount {
                    var levelPath = Path()
                    for cell in geometry.fillCells where cell.level == level {
                        levelPath.addRect(cell.rect)
                    }
                    let color = contourColor(level: level, style: style, palette: palette)
                    let resolvedColor = color.livelineRGBA().map {
                        palette.backgroundRGB.blended(to: $0, t: style.resolvedFillOpacity).color
                    } ?? color.opacity(style.resolvedFillOpacity)
                    var fillLayer = layer
                    fillLayer.opacity *= reveal
                    fillLayer.fill(levelPath, with: .color(resolvedColor))
                }
            }
            for line in geometry.lines {
                layer.stroke(
                    LivelineVisualGeometry.smoothPath(points: line.points, closed: line.isClosed),
                    with: .color(
                        contourColor(level: line.level, style: style, palette: palette).opacity(reveal)),
                    style: StrokeStyle(lineWidth: style.resolvedLineWidth, lineCap: .round, lineJoin: .round))
            }
        }
        if drawLabels, style.showsLevelLabels {
            for level in 0..<style.resolvedLevelCount {
                let value = minimum + span * (Double(level) + 0.5) / Double(style.resolvedLevelCount)
                drawText(
                    configuration.formatValue(value), context: &context,
                    at: CGPoint(
                        x: plot.maxX,
                        y: plot.minY + CGFloat(level + 1) / CGFloat(style.resolvedLevelCount + 1) * plot.height),
                    anchor: .trailing, color: contourColor(level: level, style: style, palette: palette),
                    font: textScale.font(8, weight: .medium, design: .monospaced))
            }
        }
    }

    static func contourColor(level: Int, style: LivelineContourStyle, palette: LivelinePalette)
        -> Color
    {
        guard !style.colors.isEmpty else { return palette.line }
        let ratio =
            Double(min(max(level, 0), style.resolvedLevelCount - 1))
            / Double(max(style.resolvedLevelCount - 1, 1))
        let index = min(Int((ratio * Double(style.colors.count - 1)).rounded()), style.colors.count - 1)
        return style.colors[index]
    }

    static func drawTernary(
        context: inout GraphicsContext,
        points: [LivelineTernaryPoint],
        style: LivelineTernaryStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        reveal: Double,
        textScale: LivelineTextScale,
        drawMarks: Bool,
        drawLabels: Bool
    ) {
        let values = points.filter { $0.total > 0 }
        guard !values.isEmpty else { return }
        let labelFont = textScale.font(9, weight: .semibold)
        let geometry = LivelineAdvancedLayout.ternary(
            style: style, layout: layout, textScale: textScale)
        let labels = geometry.labels
        let a = geometry.a
        let b = geometry.b
        let c = geometry.c
        if drawMarks {
            var triangle = Path()
            triangle.move(to: a)
            triangle.addLine(to: b)
            triangle.addLine(to: c)
            triangle.closeSubpath()
            context.stroke(triangle, with: .color(palette.gridLabel.opacity(reveal)), lineWidth: 1.25)
            if style.showsGrid {
                for step in 1..<4 {
                    let t = CGFloat(step) / 4
                    for pair in [
                        (interpolate(a, b, t), interpolate(a, c, t)),
                        (interpolate(b, a, t), interpolate(b, c, t)),
                        (interpolate(c, a, t), interpolate(c, b, t)),
                    ] {
                        var line = Path()
                        line.move(to: pair.0)
                        line.addLine(to: pair.1)
                        context.stroke(
                            line, with: .color(palette.referenceLine.opacity(reveal)), lineWidth: 0.75)
                    }
                }
            }
        }
        let maxMagnitude = max(values.map(\.magnitude).max() ?? 0, 0.000_001)
        for (index, point) in values.enumerated() {
            let center = geometry.point(point)
            let range = style.resolvedPointSizeRange
            let size =
                range.lowerBound + (range.upperBound - range.lowerBound)
                * CGFloat(sqrt(point.magnitude / maxMagnitude))
            let color = advancedColor(index: index, colors: style.colors, palette: palette)
            if drawMarks {
                context.fill(
                    Path(
                        ellipseIn: CGRect(
                            x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)),
                    with: .color(color.opacity(0.84 * reveal)))
            }
            if drawLabels, style.showsLabels, values.count <= 12 {
                drawText(
                    point.label, context: &context,
                    at: CGPoint(x: center.x, y: center.y - size / 2 - textScale.scaled(3)), anchor: .bottom,
                    color: color, font: textScale.font(8, weight: .medium))
            }
        }
        if drawLabels {
            drawText(
                labels[0], context: &context, at: CGPoint(x: a.x, y: a.y - textScale.scaled(6)),
                anchor: .bottom, color: palette.gridLabel, font: labelFont)
            drawText(
                labels[1], context: &context, at: CGPoint(x: b.x - textScale.scaled(5), y: b.y),
                anchor: .trailing, color: palette.gridLabel, font: labelFont)
            drawText(
                labels[2], context: &context, at: CGPoint(x: c.x + textScale.scaled(5), y: c.y),
                anchor: .leading, color: palette.gridLabel, font: labelFont)
        }
    }

    static func drawWaffle(
        context: inout GraphicsContext,
        values: [LivelineCategoryValue],
        style: LivelineWaffleStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        configuration: LivelineChartConfiguration,
        reveal: Double,
        textScale: LivelineTextScale,
        drawMarks: Bool,
        drawLabels: Bool
    ) {
        let geometry = LivelineAdvancedLayout.waffle(
            values: values, style: style, layout: layout, textScale: textScale)
        let values = geometry.values
        guard !values.isEmpty else { return }
        let allocations = geometry.allocations
        let plot = geometry.plot
        let cell = geometry.cell
        let count = geometry.cellCount
        var category = 0
        var boundary = allocations.first ?? 0
        if drawMarks {
            for index in 0..<count {
                while index >= boundary, category < allocations.count - 1 {
                    category += 1
                    boundary += allocations[category]
                }
                let rect = geometry.rect(cellIndex: index)
                let color = advancedColor(index: category, colors: style.colors, palette: palette)
                let visible = Double(index + 1) / Double(count) <= reveal
                context.fill(
                    Path(roundedRect: rect, cornerRadius: min(style.resolvedCornerRadius, cell / 3)),
                    with: .color(color.opacity(visible ? 0.82 : 0.08)))
            }
        }
        if drawLabels, style.showsLegend {
            let total = values.reduce(0) { $0 + $1.value }
            var x = plot.minX
            for (index, value) in values.enumerated() {
                let color = advancedColor(index: index, colors: style.colors, palette: palette)
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: plot.maxY - textScale.scaled(13), width: 7, height: 7)),
                    with: .color(color))
                let formattedShare = configuration.formatValue(value.value / total * 100)
                let label =
                    "\(value.label) \(formattedShare.hasSuffix("%") ? formattedShare : formattedShare + "%")"
                drawText(
                    label, context: &context, at: CGPoint(x: x + 10, y: plot.maxY - textScale.scaled(9)),
                    anchor: .leading, color: palette.gridLabel, font: textScale.font(8, weight: .medium))
                // `label.count` is a grapheme count, which under-measures wide
                // scripts and overlaps the next entry. Advance by the same
                // character-class estimate the layout pass uses.
                x +=
                    LivelineAdvancedLayout.estimatedLabelWidth(label, textScale: textScale)
                    + textScale.scaled(20)
                if x > plot.maxX - textScale.scaled(50) { break }
            }
        }
    }

    static func waffleAllocations(values: [LivelineCategoryValue], cellCount: Int) -> [Int] {
        let total = max(values.reduce(0) { $0 + $1.value }, 0.000_001)
        let raw = values.map { $0.value / total * Double(cellCount) }
        var result = raw.map { Int($0.rounded(.down)) }
        var remaining = cellCount - result.reduce(0, +)
        let order = raw.enumerated().sorted { lhs, rhs in
            let left = lhs.element - floor(lhs.element)
            let right = rhs.element - floor(rhs.element)
            return left == right ? lhs.offset < rhs.offset : left > right
        }.map(\.offset)
        var index = 0
        while remaining > 0, !order.isEmpty {
            result[order[index % order.count]] += 1
            remaining -= 1
            index += 1
        }
        return result
    }

    static func interpolate(_ start: CGPoint, _ end: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t)
    }
}
