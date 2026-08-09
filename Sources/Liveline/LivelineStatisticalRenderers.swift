import SwiftUI

extension LivelineRenderer {
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
