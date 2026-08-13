import SwiftUI

// MARK: - Volume profile

struct LivelineVolumeProfileLayout {
    var levels: [LivelinePriceVolume]
    var plot: CGRect
    var body: CGRect
    var slot: CGFloat
    var maximumVolume: Double
    var widthRatio: CGFloat
    var barSpacing: CGFloat
    var isRTL: Bool

    func rect(at index: Int, reveal: Double = 1) -> CGRect {
        let volume = levels.indices.contains(index) ? levels[index].volume : 0
        let width = body.width * widthRatio * CGFloat(volume / maximumVolume) * CGFloat(reveal)
        return CGRect(
            x: isRTL ? body.maxX - width : body.minX,
            y: body.maxY - CGFloat(index + 1) * slot + barSpacing / 2,
            width: width,
            height: max(slot - barSpacing, 1)
        )
    }
}

extension LivelineAdvancedLayout {
    static func volumeProfileLevels(_ levels: [LivelinePriceVolume]) -> [LivelinePriceVolume] {
        let positive = levels.filter { $0.volume > 0 }
        let scale = max(positive.map(\.volume).max() ?? 0, 0.000_001)
        var volumeByPrice: [Double: Double] = [:]
        var normalizedVolumeByPrice: [Double: Double] = [:]
        var overflowed = false
        for level in positive {
            let total = volumeByPrice[level.price, default: 0] + level.volume
            if total.isFinite {
                volumeByPrice[level.price] = total
            } else {
                overflowed = true
            }
            normalizedVolumeByPrice[level.price, default: 0] += level.volume / scale
        }
        if overflowed {
            let maximumNormalized = max(normalizedVolumeByPrice.values.max() ?? 0, 0.000_001)
            volumeByPrice = normalizedVolumeByPrice.mapValues { normalized in
                normalized / maximumNormalized * scale
            }
        }
        return volumeByPrice.map { LivelinePriceVolume(price: $0.key, volume: $0.value) }
            .sorted { $0.price < $1.price }
    }

    static func volumeProfile(
        levels: [LivelinePriceVolume],
        style: LivelineVolumeProfileStyle,
        layout: LivelineLayout,
        textScale: LivelineTextScale
    ) -> LivelineVolumeProfileLayout {
        let valid = volumeProfileLevels(levels)
        let plot = LivelineRenderer.advancedPlotRect(layout)
            .insetBy(dx: textScale.scaled(5), dy: textScale.scaled(5))
        let labelWidth = style.showsValues
            ? min(textScale.scaled(70), max(plot.width - 1, 0))
            : 0
        let body = CGRect(
            x: layout.isRTL ? plot.minX + labelWidth : plot.minX,
            y: plot.minY,
            width: max(plot.width - labelWidth, 1),
            height: plot.height
        )
        return LivelineVolumeProfileLayout(
            levels: valid,
            plot: plot,
            body: body,
            slot: body.height / CGFloat(max(valid.count, 1)),
            maximumVolume: max(valid.map(\.volume).max() ?? 0, 0.000_001),
            widthRatio: style.resolvedWidthRatio,
            barSpacing: min(
                style.resolvedBarSpacing,
                body.height / CGFloat(max(valid.count, 1)) * 0.9
            ),
            isRTL: layout.isRTL
        )
    }
}

// MARK: - Renko

struct LivelineRenkoLayout {
    var bricks: [LivelineRenkoBrick]
    var plot: CGRect
    var slot: CGFloat
    var width: CGFloat
    var brickSpacing: CGFloat

    func rect(at index: Int, layout: LivelineLayout) -> CGRect {
        guard bricks.indices.contains(index) else { return .zero }
        let brick = bricks[index]
        let top = layout.y(for: max(brick.open, brick.close))
        let bottom = layout.y(for: min(brick.open, brick.close))
        let slotX = layout.isRTL
            ? plot.maxX - CGFloat(index + 1) * slot
            : plot.minX + CGFloat(index) * slot
        return CGRect(
            x: slotX + brickSpacing / 2,
            y: min(top, bottom),
            width: width,
            height: max(abs(bottom - top), 1)
        )
    }
}

extension LivelineAdvancedLayout {
    static func renko(
        bricks: [LivelineRenkoBrick],
        style: LivelineRenkoStyle,
        layout: LivelineLayout
    ) -> LivelineRenkoLayout {
        let plot = LivelineRenderer.advancedPlotRect(layout)
        let slot = plot.width / CGFloat(max(bricks.count, 1))
        let brickSpacing = min(style.resolvedBrickSpacing, slot * 0.5)
        return LivelineRenkoLayout(
            bricks: bricks,
            plot: plot,
            slot: slot,
            width: max(slot - brickSpacing, CGFloat.ulpOfOne),
            brickSpacing: brickSpacing
        )
    }
}

// MARK: - Point and figure

struct LivelinePointFigureLayout {
    var columns: [LivelinePointFigureColumn]
    var plot: CGRect
    var body: CGRect
    var slot: CGFloat
    var box: CGFloat
    var valueDomain: ClosedRange<Double>
    var isRTL: Bool

    func x(column: LivelinePointFigureColumn) -> CGFloat {
        let offset = slot * (CGFloat(column.index) + 0.5)
        return isRTL ? body.maxX - offset : body.minX + offset
    }

    func y(_ value: Double) -> CGFloat {
        LivelineRenderer.mapped(value, from: valueDomain, to: (body.maxY, body.minY))
    }

    /// At most one symbol per visible pixel row is useful. Bounding this list
    /// also prevents tiny public box sizes from turning one column into millions
    /// of paths on the render thread.
    func symbolIndices(for column: LivelinePointFigureColumn) -> [Int] {
        let capacity = max(min(Int(body.height / max(box, 1)), 2_048), 1)
        guard column.boxCount > capacity else { return Array(0..<column.boxCount) }
        return (0..<capacity).map { sample in
            Int(
                (Double(sample) * Double(column.boxCount - 1) / Double(max(capacity - 1, 1)))
                    .rounded()
            )
        }
    }
}

extension LivelineAdvancedLayout {
    static func pointAndFigure(
        columns: [LivelinePointFigureColumn],
        style: LivelinePointAndFigureStyle,
        layout: LivelineLayout,
        textScale: LivelineTextScale
    ) -> LivelinePointFigureLayout {
        let plot = LivelineRenderer.advancedPlotRect(layout)
        let body = plot
        let slot = body.width / CGFloat(max(columns.count, 1))
        return LivelinePointFigureLayout(
            columns: columns,
            plot: plot,
            body: body,
            slot: slot,
            box: max(
                min(
                    slot - min(style.resolvedColumnSpacing, slot * 0.9),
                    body.height * CGFloat(style.resolvedBoxSize)
                        / CGFloat(max(layout.maxValue - layout.minValue, 0.000_001))
                ),
                0.1
            ),
            valueDomain: layout.minValue...max(layout.maxValue, layout.minValue + 0.000_001),
            isRTL: layout.isRTL
        )
    }
}

// MARK: - Market depth

struct LivelineMarketDepthLayout {
    var curve: LivelineMarketDepthCurve
    var plot: CGRect
    var priceDomain: ClosedRange<Double>
    var maximumSize: Double
    var isRTL: Bool

    var bidBoundaryX: CGFloat { isRTL ? plot.maxX : plot.minX }
    var askBoundaryX: CGFloat { isRTL ? plot.minX : plot.maxX }

    func x(price: Double) -> CGFloat {
        LivelineRenderer.mapped(
            price,
            from: priceDomain,
            to: isRTL ? (plot.maxX, plot.minX) : (plot.minX, plot.maxX)
        )
    }

    func point(_ value: LivelinePoint) -> CGPoint {
        CGPoint(
            x: x(price: value.time),
            y: LivelineRenderer.mapped(value.value, from: 0...maximumSize, to: (plot.maxY, plot.minY))
        )
    }
}

extension LivelineAdvancedLayout {
    static func marketDepth(
        levels: [LivelineOrderBookLevel],
        layout: LivelineLayout,
        textScale: LivelineTextScale
    ) -> LivelineMarketDepthLayout? {
        let curve = LivelineAdvancedMath.marketDepthCurve(levels)
        let all = curve.bids + curve.asks
        guard !all.isEmpty else { return nil }
        let plot = LivelineRenderer.advancedPlotRect(layout)
            .insetBy(dx: textScale.scaled(8), dy: textScale.scaled(8))
        let minimum = all.map(\.time).min() ?? 0
        let maximum = all.map(\.time).max() ?? 1
        let priceDomain: ClosedRange<Double>
        if minimum == maximum {
            let padding = max(abs(minimum) * 0.01, 1)
            priceDomain = (minimum - padding)...(maximum + padding)
        } else {
            priceDomain = minimum...maximum
        }
        return LivelineMarketDepthLayout(
            curve: curve,
            plot: plot,
            priceDomain: priceDomain,
            maximumSize: max(all.map(\.value).max() ?? 0, 0.000_001),
            isRTL: layout.isRTL
        )
    }
}

// MARK: - OHLC and volume

struct LivelineOHLCVolumeLayout {
    var values: [LivelineCandleVolume]
    var plot: CGRect
    var priceRect: CGRect
    var volumeRect: CGRect
    var priceDomain: ClosedRange<Double>
    var maximumVolume: Double
    var candleWidth: CGFloat

    func priceY(_ value: Double) -> CGFloat {
        LivelineRenderer.mapped(value, from: priceDomain, to: (priceRect.maxY, priceRect.minY))
    }
}

extension LivelineAdvancedLayout {
    static func ohlcVolume(
        values: [LivelineCandleVolume],
        style: LivelineOHLCVolumeStyle,
        layout: LivelineLayout
    ) -> LivelineOHLCVolumeLayout? {
        let visible = values.filter { $0.time >= layout.leftEdge - 2 && $0.time <= layout.rightEdge }
        guard !visible.isEmpty else { return nil }
        let plot = LivelineRenderer.advancedPlotRect(layout)
        let volumeHeight = plot.height * style.resolvedVolumeHeightRatio
        let low = visible.map(\.low).min() ?? 0
        let high = visible.map(\.high).max() ?? 1
        let priceDomain: ClosedRange<Double>
        if low == high {
            let padding = max(abs(low) * 0.05, 0.5)
            priceDomain = (low - padding)...(high + padding)
        } else {
            priceDomain = low...high
        }
        return LivelineOHLCVolumeLayout(
            values: visible,
            plot: plot,
            priceRect: CGRect(
                x: plot.minX,
                y: plot.minY,
                width: plot.width,
                height: max(plot.height - volumeHeight - style.resolvedPaneSpacing, 1)
            ),
            volumeRect: CGRect(
                x: plot.minX,
                y: plot.maxY - volumeHeight,
                width: plot.width,
                height: volumeHeight
            ),
            priceDomain: priceDomain,
            maximumVolume: max(visible.map(\.volume).max() ?? 0, 0.000_001),
            candleWidth: LivelineRenderer.bucketWidth(
                sortedTimes: visible.lazy.map(\.time),
                layout: layout,
                ratio: style.resolvedCandleWidthRatio,
                maximum: 24
            )
        )
    }
}
