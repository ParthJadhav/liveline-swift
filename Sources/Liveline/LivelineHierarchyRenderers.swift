import SwiftUI

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
