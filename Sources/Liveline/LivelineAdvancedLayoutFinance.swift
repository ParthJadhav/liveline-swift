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
    static func volumeProfile(
        levels: [LivelinePriceVolume],
        style: LivelineVolumeProfileStyle,
        layout: LivelineLayout,
        textScale: LivelineTextScale
    ) -> LivelineVolumeProfileLayout {
        let valid = levels.filter { $0.volume > 0 }
        let labelWidth = style.showsValues ? textScale.scaled(70) : 0
        let plot = LivelineRenderer.advancedPlotRect(layout)
            .insetBy(dx: textScale.scaled(5), dy: textScale.scaled(5))
        let body = CGRect(
            x: plot.minX,
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
            barSpacing: style.resolvedBarSpacing,
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
        return CGRect(
            x: plot.minX + CGFloat(index) * slot + brickSpacing / 2,
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
        return LivelineRenkoLayout(
            bricks: bricks,
            plot: plot,
            slot: slot,
            width: max(slot - style.resolvedBrickSpacing, 1),
            brickSpacing: style.resolvedBrickSpacing
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

    func x(column: LivelinePointFigureColumn) -> CGFloat {
        body.minX + slot * (CGFloat(column.index) + 0.5)
    }

    func y(_ value: Double) -> CGFloat {
        LivelineRenderer.mapped(value, from: valueDomain, to: (body.maxY, body.minY))
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
            .insetBy(dx: textScale.scaled(6), dy: textScale.scaled(6))
        let legendHeight = textScale.scaled(15)
        let body = CGRect(
            x: plot.minX,
            y: plot.minY + legendHeight,
            width: plot.width,
            height: max(plot.height - legendHeight, 1)
        )
        let low = columns.map(\.low).min() ?? 0
        let high = columns.map(\.high).max() ?? 1
        let slot = body.width / CGFloat(max(columns.count, 1))
        return LivelinePointFigureLayout(
            columns: columns,
            plot: plot,
            body: body,
            slot: slot,
            box: min(
                slot - style.resolvedColumnSpacing,
                body.height
                    / CGFloat(max(Int(((high - low) / style.resolvedBoxSize).rounded(.down)) + 1, 1))
            ),
            valueDomain: low...(low == high ? high + 1 : high)
        )
    }
}

// MARK: - Market depth

struct LivelineMarketDepthLayout {
    var curve: LivelineMarketDepthCurve
    var plot: CGRect
    var priceDomain: ClosedRange<Double>
    var maximumSize: Double

    func x(price: Double) -> CGFloat {
        LivelineRenderer.mapped(price, from: priceDomain, to: plot.minX...plot.maxX)
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
        return LivelineMarketDepthLayout(
            curve: curve,
            plot: plot,
            priceDomain: minimum...(minimum == maximum ? maximum + 1 : maximum),
            maximumSize: max(all.map(\.value).max() ?? 0, 0.000_001)
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
            priceDomain: low...(low == high ? high + 1 : high),
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
