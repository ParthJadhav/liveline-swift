import SwiftUI

extension LivelineRenderer {
    static func drawTooltipSelection(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        selection: LivelineTooltipSelection?,
        configuration: LivelineChartConfiguration,
        alpha: Double
    ) {
        guard let selection, !selection.rows.isEmpty, alpha > 0.01 else { return }
        let rows = Array(selection.rows.prefix(7))
        let heading = selection.heading?.isEmpty == false ? selection.heading : nil
        let headingFont = Font.system(size: 10, weight: .medium, design: .monospaced)
        let rowFont = Font.system(size: 11, weight: .medium, design: .monospaced)
        let labelWidth = rows.map { measureText($0.label, context: context, font: rowFont).width }.max() ?? 0
        let valueWidth = rows.map { measureText($0.value, context: context, font: rowFont).width }.max() ?? 0
        let headingWidth = heading.map { measureText($0, context: context, font: headingFont).width } ?? 0
        let horizontalPadding: CGFloat = 9
        let swatchAndGap: CGFloat = 14
        let columnGap: CGFloat = 14
        let rowHeight: CGFloat = 15
        let headingHeight: CGFloat = heading == nil ? 0 : 15
        let width = min(
            max(40, layout.chartWidth - 8),
            max(96, headingWidth + horizontalPadding * 2, labelWidth + valueWidth + swatchAndGap + columnGap + horizontalPadding * 2)
        )
        let height = CGFloat(rows.count) * rowHeight + headingHeight + 12
        let minimumX = layout.plotLeftX + 4
        let maximumX = max(minimumX, layout.rightX - width - 4)
        let x = LivelineMath.clamp(selection.anchor.x - width / 2, minimumX, maximumX)
        var y = selection.anchor.y - height - 12
        if y < layout.padding.top + 4 {
            y = selection.anchor.y + 12
        }
        y = LivelineMath.clamp(y, layout.padding.top + 4, layout.bottomY - height - 4)
        let rect = CGRect(x: x, y: y, width: width, height: height)

        var layer = context
        layer.opacity *= alpha
        layer.fill(Path(roundedRect: rect, cornerRadius: 7), with: .color(palette.tooltipBackground))
        if configuration.tooltipOutline {
            layer.stroke(Path(roundedRect: rect, cornerRadius: 7), with: .color(palette.tooltipBorder), lineWidth: 1)
        }

        let markerRadius: CGFloat = 4
        layer.fill(
            Path(ellipseIn: CGRect(
                x: selection.anchor.x - markerRadius,
                y: selection.anchor.y - markerRadius,
                width: markerRadius * 2,
                height: markerRadius * 2
            )),
            with: .color(rows[0].color)
        )
        layer.stroke(
            Path(ellipseIn: CGRect(
                x: selection.anchor.x - markerRadius,
                y: selection.anchor.y - markerRadius,
                width: markerRadius * 2,
                height: markerRadius * 2
            )),
            with: .color(palette.backgroundRGB.color),
            lineWidth: 1.5
        )

        var cursorY = rect.minY + 7
        if let heading {
            drawText(
                heading,
                context: &layer,
                at: CGPoint(x: rect.minX + horizontalPadding, y: cursorY),
                anchor: .topLeading,
                color: palette.gridLabel,
                font: headingFont
            )
            cursorY += headingHeight
        }

        for row in rows {
            let centerY = cursorY + rowHeight / 2
            let swatch = CGRect(x: rect.minX + horizontalPadding, y: centerY - 3.5, width: 7, height: 7)
            layer.fill(Path(roundedRect: swatch, cornerRadius: 1.5), with: .color(row.color))
            drawText(
                row.label,
                context: &layer,
                at: CGPoint(x: swatch.maxX + 7, y: centerY),
                anchor: .leading,
                color: palette.gridLabel,
                font: rowFont
            )
            drawText(
                row.value,
                context: &layer,
                at: CGPoint(x: rect.maxX - horizontalPadding, y: centerY),
                anchor: .trailing,
                color: palette.tooltipText,
                font: rowFont
            )
            cursorY += rowHeight
        }
    }
}
