import SwiftUI

extension LivelineRenderer {
    static func drawAdvancedFinance(
        context: inout GraphicsContext,
        content: LivelineAdvancedChartContent,
        layout: LivelineLayout,
        palette: LivelinePalette,
        configuration: LivelineChartConfiguration,
        reveal: Double,
        textScale: LivelineTextScale,
        drawMarks: Bool,
        drawLabels: Bool
    ) {
        switch content {
        case .volumeProfile(let data, let style):
            drawVolumeProfile(
                context: &context, levels: data, style: style, layout: layout, palette: palette,
                configuration: configuration, reveal: reveal, textScale: textScale, drawMarks: drawMarks,
                drawLabels: drawLabels)
        case .renko(let data, let style):
            drawRenko(
                context: &context, bricks: data.bricks, style: style, layout: layout, palette: palette,
                reveal: reveal, drawMarks: drawMarks)
        case .heikinAshi(let data, let style):
            drawHeikinAshi(
                context: &context, candles: data.candles, style: style, layout: layout,
                palette: palette, reveal: reveal, drawMarks: drawMarks)
        case .marketDepth(let data, let style):
            drawMarketDepth(
                context: &context, levels: data, style: style, layout: layout, palette: palette,
                configuration: configuration, reveal: reveal, textScale: textScale, drawMarks: drawMarks,
                drawLabels: drawLabels)
        case .ohlcVolume(let data, let style):
            drawOHLCVolume(
                context: &context, values: data, style: style, layout: layout, palette: palette,
                configuration: configuration, reveal: reveal, textScale: textScale, drawMarks: drawMarks,
                drawLabels: drawLabels)
        case .pointAndFigure(let data, let style):
            drawPointAndFigure(
                context: &context, columns: data.columns, style: style, layout: layout,
                palette: palette, reveal: reveal, textScale: textScale, drawMarks: drawMarks,
                drawLabels: drawLabels)
        default:
            break
        }
    }

    static func drawVolumeProfile(
        context: inout GraphicsContext,
        levels: [LivelinePriceVolume],
        style: LivelineVolumeProfileStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        configuration: LivelineChartConfiguration,
        reveal: Double,
        textScale: LivelineTextScale,
        drawMarks: Bool,
        drawLabels: Bool
    ) {
        let geometry = LivelineAdvancedLayout.volumeProfile(
            levels: levels, style: style, layout: layout, textScale: textScale)
        let levels = geometry.levels
        guard !levels.isEmpty else { return }
        let plot = geometry.plot
        let pointOfControl = levels.max { $0.volume < $1.volume }?.price
        for (index, level) in levels.enumerated() {
            let rect = geometry.rect(at: index, reveal: reveal)
            let isPOC = style.showsPointOfControl && level.price == pointOfControl
            let color =
                isPOC
                ? (style.pointOfControlColor ?? palette.line)
                : palette.line.opacity(style.resolvedFillOpacity)
            if drawMarks {
                context.fill(
                    Path(roundedRect: rect, cornerRadius: min(2, rect.height / 2)), with: .color(color))
            }
            if drawLabels, style.showsValues, index % max(levels.count / 8, 1) == 0 || isPOC {
                drawText(
                    "\(configuration.formatValue(level.price)) · \(configuration.formatValue(level.volume))",
                    context: &context,
                    at: CGPoint(x: geometry.isRTL ? plot.minX : plot.maxX, y: rect.midY),
                    anchor: geometry.isRTL ? .leading : .trailing,
                    color: isPOC ? color : palette.gridLabel,
                    font: textScale.font(8, weight: isPOC ? .semibold : .regular, design: .monospaced))
            }
        }
    }

    static func drawRenko(
        context: inout GraphicsContext,
        bricks: [LivelineRenkoBrick],
        style: LivelineRenkoStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        reveal: Double,
        drawMarks: Bool
    ) {
        guard drawMarks, !bricks.isEmpty else { return }
        let geometry = LivelineAdvancedLayout.renko(bricks: bricks, style: style, layout: layout)
        for (index, brick) in bricks.prefix(revealedCount(bricks.count, reveal: reveal)).enumerated() {
            let rect = geometry.rect(at: index, layout: layout)
            let color = brick.isRising ? (style.upColor ?? palette.line) : style.downColor
            context.fill(
                Path(roundedRect: rect, cornerRadius: min(style.resolvedCornerRadius, rect.height / 3)),
                with: .color(color.opacity(0.72)))
            context.stroke(
                Path(roundedRect: rect, cornerRadius: min(style.resolvedCornerRadius, rect.height / 3)),
                with: .color(color), lineWidth: 1)
            if style.showsWicks {
                var wick = Path()
                wick.move(to: CGPoint(x: rect.midX, y: layout.y(for: brick.sourceHigh)))
                wick.addLine(to: CGPoint(x: rect.midX, y: layout.y(for: brick.sourceLow)))
                context.stroke(wick, with: .color(color.opacity(0.8)), lineWidth: 1)
            }
        }
    }

    static func drawHeikinAshi(
        context: inout GraphicsContext,
        candles: [LivelineCandle],
        style: LivelineHeikinAshiStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        reveal: Double,
        drawMarks: Bool
    ) {
        guard drawMarks else { return }
        let candles = candles.filter {
            $0.time >= layout.leftEdge - 2 && $0.time <= layout.rightEdge
        }
        guard !candles.isEmpty else { return }
        let width = bucketWidth(
            sortedTimes: candles.lazy.map(\.time), layout: layout, ratio: style.resolvedWidthRatio,
            maximum: 30)
        for candle in candles.prefix(revealedCount(candles.count, reveal: reveal)) {
            let x = layout.x(for: candle.time)
            let color = candle.close >= candle.open ? (style.upColor ?? palette.line) : style.downColor
            var wick = Path()
            wick.move(to: CGPoint(x: x, y: layout.y(for: candle.high)))
            wick.addLine(to: CGPoint(x: x, y: layout.y(for: candle.low)))
            context.stroke(wick, with: .color(color), lineWidth: style.resolvedWickWidth)
            let top = layout.y(for: max(candle.open, candle.close))
            let bottom = layout.y(for: min(candle.open, candle.close))
            let body = CGRect(
                x: x - width / 2, y: min(top, bottom), width: width, height: max(abs(bottom - top), 1.5))
            if candle.close >= candle.open {
                context.stroke(
                    Path(roundedRect: body, cornerRadius: min(style.resolvedCornerRadius, body.height / 3)),
                    with: .color(color), lineWidth: 1.25)
            } else {
                context.fill(
                    Path(roundedRect: body, cornerRadius: min(style.resolvedCornerRadius, body.height / 3)),
                    with: .color(color.opacity(0.84)))
            }
        }
    }

    static func drawMarketDepth(
        context: inout GraphicsContext,
        levels: [LivelineOrderBookLevel],
        style: LivelineMarketDepthStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        configuration: LivelineChartConfiguration,
        reveal: Double,
        textScale: LivelineTextScale,
        drawMarks: Bool,
        drawLabels: Bool
    ) {
        guard
            let geometry = LivelineAdvancedLayout.marketDepth(
                levels: levels, layout: layout, textScale: textScale)
        else { return }
        let curve = geometry.curve
        let plot = geometry.plot
        let point: (LivelinePoint) -> CGPoint = { geometry.point($0) }
        if drawMarks {
            drawDepthCurve(
                context: &context, points: curve.bids, color: style.bidColor, plot: plot, point: point,
                style: style, reveal: reveal, singletonBoundaryX: geometry.bidBoundaryX)
            drawDepthCurve(
                context: &context, points: curve.asks, color: style.askColor, plot: plot, point: point,
                style: style, reveal: reveal, singletonBoundaryX: geometry.askBoundaryX)
            if style.showsSpread, let bid = curve.bestBid, let ask = curve.bestAsk {
                let left = geometry.x(price: bid)
                let right = geometry.x(price: ask)
                context.fill(
                    Path(
                        CGRect(x: min(left, right), y: plot.minY, width: abs(right - left), height: plot.height)
                    ), with: .color(palette.gridLabel.opacity(0.05)))
            }
            if style.showsMidPrice, let bid = curve.bestBid, let ask = curve.bestAsk {
                let x = geometry.x(price: (bid + ask) / 2)
                var line = Path()
                line.move(to: CGPoint(x: x, y: plot.minY))
                line.addLine(to: CGPoint(x: x, y: plot.maxY))
                context.stroke(
                    line, with: .color(palette.referenceLine), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
            }
        }
        if drawLabels, let bid = curve.bestBid, let ask = curve.bestAsk {
            drawText(
                String(
                    format: LivelineStrings.accessibilityNamedValueFormat, LivelineStrings.labelBid,
                    configuration.formatValue(bid)), context: &context,
                at: CGPoint(x: geometry.isRTL ? plot.maxX : plot.minX, y: plot.minY),
                anchor: geometry.isRTL ? .topTrailing : .topLeading, color: style.bidColor,
                font: textScale.font(9, weight: .semibold, design: .monospaced))
            drawText(
                String(
                    format: LivelineStrings.accessibilityNamedValueFormat, LivelineStrings.labelAsk,
                    configuration.formatValue(ask)), context: &context,
                at: CGPoint(x: geometry.isRTL ? plot.minX : plot.maxX, y: plot.minY),
                anchor: geometry.isRTL ? .topLeading : .topTrailing, color: style.askColor,
                font: textScale.font(9, weight: .semibold, design: .monospaced))
        }
    }

    static func drawDepthCurve(
        context: inout GraphicsContext,
        points: [LivelinePoint],
        color: Color,
        plot: CGRect,
        point: (LivelinePoint) -> CGPoint,
        style: LivelineMarketDepthStyle,
        reveal: Double,
        singletonBoundaryX: CGFloat
    ) {
        guard
            let paths = depthCurvePaths(
                points: points, plot: plot, point: point,
                singletonBoundaryX: singletonBoundaryX)
        else { return }
        context.fill(paths.area, with: .color(color.opacity(style.resolvedFillOpacity * reveal)))
        context.stroke(
            paths.line, with: .color(color.opacity(reveal)),
            style: StrokeStyle(lineWidth: style.resolvedLineWidth, lineJoin: .round))
    }

    static func depthCurvePaths(
        points: [LivelinePoint],
        plot: CGRect,
        point: (LivelinePoint) -> CGPoint,
        singletonBoundaryX: CGFloat
    ) -> (line: Path, area: Path)? {
        guard let first = points.first, let last = points.last else { return nil }
        var line = Path()
        let firstPoint = point(first)
        line.move(to: firstPoint)
        if points.count == 1 {
            line.addLine(to: CGPoint(x: singletonBoundaryX, y: firstPoint.y))
        }
        for value in points.dropFirst() {
            let next = point(value)
            line.addLine(to: CGPoint(x: next.x, y: line.currentPoint?.y ?? next.y))
            line.addLine(to: next)
        }
        var area = line
        area.addLine(to: CGPoint(x: line.currentPoint?.x ?? point(last).x, y: plot.maxY))
        area.addLine(to: CGPoint(x: firstPoint.x, y: plot.maxY))
        area.closeSubpath()
        return (line, area)
    }

    static func drawOHLCVolume(
        context: inout GraphicsContext,
        values: [LivelineCandleVolume],
        style: LivelineOHLCVolumeStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        configuration: LivelineChartConfiguration,
        reveal: Double,
        textScale: LivelineTextScale,
        drawMarks: Bool,
        drawLabels: Bool
    ) {
        guard
            let geometry = LivelineAdvancedLayout.ohlcVolume(
                values: values, style: style, layout: layout)
        else { return }
        let values = geometry.values
        let volumeRect = geometry.volumeRect
        let volumeMax = geometry.maximumVolume
        let width = geometry.candleWidth
        let priceY: (Double) -> CGFloat = { geometry.priceY($0) }
        if drawMarks {
            for value in values.prefix(revealedCount(values.count, reveal: reveal)) {
                let x = layout.x(for: value.time)
                let rising = value.close >= value.open
                let color = rising ? (style.upColor ?? palette.line) : style.downColor
                var wick = Path()
                wick.move(to: CGPoint(x: x, y: priceY(value.high)))
                wick.addLine(to: CGPoint(x: x, y: priceY(value.low)))
                context.stroke(wick, with: .color(color), lineWidth: 1)
                let bodyTop = priceY(max(value.open, value.close))
                let bodyBottom = priceY(min(value.open, value.close))
                let body = CGRect(
                    x: x - width / 2, y: min(bodyTop, bodyBottom), width: width,
                    height: max(abs(bodyBottom - bodyTop), 1.5))
                rising
                    ? context.stroke(Path(body), with: .color(color), lineWidth: 1)
                    : context.fill(Path(body), with: .color(color.opacity(0.82)))
                let barHeight = volumeRect.height * CGFloat(value.volume / volumeMax)
                let volumeBar = CGRect(
                    x: x - width / 2, y: volumeRect.maxY - barHeight, width: width, height: barHeight)
                context.fill(Path(volumeBar), with: .color(color.opacity(style.resolvedVolumeOpacity)))
            }
            if style.showsVolumeAverage, values.count >= 2 {
                let average = values.map(\.volume).reduce(0, +) / Double(values.count)
                let y = volumeRect.maxY - volumeRect.height * CGFloat(average / volumeMax)
                var line = Path()
                line.move(to: CGPoint(x: volumeRect.minX, y: y))
                line.addLine(to: CGPoint(x: volumeRect.maxX, y: y))
                context.stroke(
                    line, with: .color(palette.gridLabel.opacity(0.55)),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
        if drawLabels {
            drawText(
                String(
                    format: LivelineStrings.accessibilityNamedValueFormat, LivelineStrings.labelVolumeShort,
                    configuration.formatValue(volumeMax)), context: &context,
                at: CGPoint(x: volumeRect.maxX, y: volumeRect.minY), anchor: .topTrailing,
                color: palette.gridLabel, font: textScale.font(8, weight: .regular, design: .monospaced))
        }
    }

    static func drawPointAndFigure(
        context: inout GraphicsContext,
        columns: [LivelinePointFigureColumn],
        style: LivelinePointAndFigureStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        reveal: Double,
        textScale: LivelineTextScale,
        drawMarks: Bool,
        drawLabels: Bool
    ) {
        guard !columns.isEmpty else { return }
        let geometry = LivelineAdvancedLayout.pointAndFigure(
            columns: columns, style: style, layout: layout, textScale: textScale)
        let plot = geometry.plot
        let box = geometry.box
        if drawMarks {
            for column in columns.prefix(revealedCount(columns.count, reveal: reveal)) {
                let x = geometry.x(column: column)
                for index in geometry.symbolIndices(for: column) {
                    let y = geometry.y(column.low + Double(index) * style.resolvedBoxSize)
                    let rect = CGRect(x: x - box / 2, y: y - box / 2, width: box, height: box)
                    let color = column.isRising ? (style.risingColor ?? palette.line) : style.fallingColor
                    var symbol = Path()
                    if column.isRising {
                        symbol.move(to: CGPoint(x: rect.minX, y: rect.minY))
                        symbol.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                        symbol.move(to: CGPoint(x: rect.maxX, y: rect.minY))
                        symbol.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                    } else {
                        symbol.addEllipse(in: rect.insetBy(dx: 1, dy: 1))
                    }
                    context.stroke(
                        symbol, with: .color(color),
                        style: StrokeStyle(lineWidth: style.resolvedSymbolLineWidth, lineCap: .round))
                }
            }
        }
        if drawLabels {
            drawText(
                String(
                    format: LivelineStrings.labelPointFigureLegendFormat,
                    LivelineStrings.labelRising.lowercased(), LivelineStrings.labelFalling.lowercased()),
                context: &context, at: CGPoint(x: plot.minX, y: plot.minY), anchor: .topLeading,
                color: palette.gridLabel, font: textScale.font(8, weight: .medium))
        }
    }
}
