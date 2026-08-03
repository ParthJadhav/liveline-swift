import SwiftUI

extension LivelineRenderer {
    static func drawTooltipSelection(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        selection: LivelineTooltipSelection?,
        configuration: LivelineChartConfiguration,
        textScale: LivelineTextScale,
        alpha: Double
    ) {
        guard let selection, !selection.rows.isEmpty, alpha > 0.01 else { return }
        let rows = Array(selection.rows.prefix(7))
        let heading = selection.heading?.isEmpty == false ? selection.heading : nil
        let headingFont = textScale.font(10, weight: .medium, design: .monospaced)
        let rowFont = textScale.font(11, weight: .medium, design: .monospaced)
        let labelWidth = rows.map { measureText($0.label, context: context, font: rowFont).width }.max() ?? 0
        let valueWidth = rows.map { measureText($0.value, context: context, font: rowFont).width }.max() ?? 0
        let headingWidth = heading.map { measureText($0, context: context, font: headingFont).width } ?? 0
        let horizontalPadding: CGFloat = 9
        let swatchAndGap: CGFloat = 14
        let columnGap: CGFloat = 14
        // Rows are sized off the text they contain, so they have to grow with it.
        let rowHeight = textScale.scaled(15)
        let headingHeight: CGFloat = heading == nil ? 0 : textScale.scaled(15)
        let width = min(
            max(40, layout.chartWidth - 8),
            max(96, headingWidth + horizontalPadding * 2, labelWidth + valueWidth + swatchAndGap + columnGap + horizontalPadding * 2)
        )
        let height = CGFloat(rows.count) * rowHeight + headingHeight + 12
        let rect = tooltipRect(
            anchor: selection.anchor,
            size: CGSize(width: width, height: height),
            layout: layout,
            verticalOffset: configuration.tooltipY - 14
        )

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

        // Tooltip rows read start-to-end like any other run of text, so the
        // whole column layout — swatch, label, value — mirrors.
        let isRTL = layout.isRTL
        var cursorY = rect.minY + 7
        if let heading {
            drawText(
                heading,
                context: &layer,
                at: CGPoint(
                    x: isRTL ? rect.maxX - horizontalPadding : rect.minX + horizontalPadding,
                    y: cursorY
                ),
                anchor: isRTL ? .topTrailing : .topLeading,
                color: palette.gridLabel,
                font: headingFont
            )
            cursorY += headingHeight
        }

        for row in rows {
            let centerY = cursorY + rowHeight / 2
            let swatch = CGRect(
                x: isRTL ? rect.maxX - horizontalPadding - 7 : rect.minX + horizontalPadding,
                y: centerY - 3.5,
                width: 7,
                height: 7
            )
            layer.fill(Path(roundedRect: swatch, cornerRadius: 1.5), with: .color(row.color))
            drawText(
                row.label,
                context: &layer,
                at: CGPoint(x: isRTL ? swatch.minX - 7 : swatch.maxX + 7, y: centerY),
                anchor: isRTL ? .trailing : .leading,
                color: palette.gridLabel,
                font: rowFont
            )
            drawText(
                row.value,
                context: &layer,
                at: CGPoint(
                    x: isRTL ? rect.minX + horizontalPadding : rect.maxX - horizontalPadding,
                    y: centerY
                ),
                anchor: isRTL ? .leading : .trailing,
                color: palette.tooltipText,
                font: rowFont
            )
            cursorY += rowHeight
        }
    }

    static func tooltipRect(
        anchor: CGPoint,
        size: CGSize,
        layout: LivelineLayout,
        verticalOffset: CGFloat = 0
    ) -> CGRect {
        let minimumX = layout.plotLeftX + 4
        let maximumX = max(minimumX, layout.rightX - size.width - 4)
        let minimumY = layout.padding.top + 4
        let maximumY = max(minimumY, layout.bottomY - size.height - 4)
        let preferredAboveY = anchor.y - size.height - 12
        let origin: CGPoint

        if preferredAboveY >= minimumY {
            origin = CGPoint(
                x: LivelineMath.clamp(anchor.x - size.width / 2, minimumX, maximumX),
                y: preferredAboveY
            )
        } else {
            // Beside the anchor, the tooltip opens toward the reading
            // direction first and falls back to the other side.
            let rightX = anchor.x + 12
            let leftX = anchor.x - size.width - 12
            let preferred = layout.isRTL ? leftX : rightX
            let fallback = layout.isRTL ? rightX : leftX
            if layout.isRTL ? preferred >= minimumX : preferred <= maximumX {
                origin = CGPoint(
                    x: preferred,
                    y: LivelineMath.clamp(anchor.y - size.height / 2, minimumY, maximumY)
                )
            } else if layout.isRTL ? fallback <= maximumX : fallback >= minimumX {
                origin = CGPoint(
                    x: fallback,
                    y: LivelineMath.clamp(anchor.y - size.height / 2, minimumY, maximumY)
                )
            } else {
                origin = CGPoint(
                    x: LivelineMath.clamp(anchor.x - size.width / 2, minimumX, maximumX),
                    y: LivelineMath.clamp(anchor.y + 12, minimumY, maximumY)
                )
            }
        }

        return CGRect(
            origin: CGPoint(
                x: origin.x,
                y: LivelineMath.clamp(origin.y + verticalOffset, minimumY, maximumY)
            ),
            size: size
        )
    }
}
