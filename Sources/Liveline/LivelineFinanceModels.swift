import Foundation
import SwiftUI

/// Aggregated traded volume at one price level.
public struct LivelinePriceVolume: Identifiable, Hashable, Sendable {
    public var price: Double
    public var volume: Double

    public var id: Double { price }

    public init(price: Double, volume: Double) {
        self.price = price.isFinite ? price : 0
        self.volume = volume.isFinite ? max(volume, 0) : 0
    }
}

/// Visual options for horizontal volume-profile charts.
public struct LivelineVolumeProfileStyle {
    public var widthRatio: CGFloat
    public var barSpacing: CGFloat
    public var fillOpacity: Double
    public var showsPointOfControl: Bool
    public var showsValues: Bool
    public var pointOfControlColor: Color?

    public init(
        widthRatio: CGFloat = 0.86,
        barSpacing: CGFloat = 2,
        fillOpacity: Double = 0.68,
        showsPointOfControl: Bool = true,
        showsValues: Bool = false,
        pointOfControlColor: Color? = nil
    ) {
        self.widthRatio = widthRatio
        self.barSpacing = barSpacing
        self.fillOpacity = fillOpacity
        self.showsPointOfControl = showsPointOfControl
        self.showsValues = showsValues
        self.pointOfControlColor = pointOfControlColor
    }

    var resolvedWidthRatio: CGFloat { widthRatio.livelineClamped(0.1, 1, fallback: 0.86) }
    var resolvedBarSpacing: CGFloat { barSpacing.livelineClamped(0, 12, fallback: 2) }
    var resolvedFillOpacity: Double { fillOpacity.livelineClamped(0, 1, fallback: 0.68) }
}

/// Visual options for price-derived Renko bricks.
public struct LivelineRenkoStyle {
    public var brickSize: Double
    public var brickSpacing: CGFloat
    public var cornerRadius: CGFloat
    public var upColor: Color?
    public var downColor: Color
    public var showsWicks: Bool

    public init(
        brickSize: Double,
        brickSpacing: CGFloat = 2,
        cornerRadius: CGFloat = 2,
        upColor: Color? = nil,
        downColor: Color = Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255),
        showsWicks: Bool = false
    ) {
        self.brickSize = brickSize
        self.brickSpacing = brickSpacing
        self.cornerRadius = cornerRadius
        self.upColor = upColor
        self.downColor = downColor
        self.showsWicks = showsWicks
    }

    var resolvedBrickSize: Double { brickSize.livelineAtLeast(0.000_001, fallback: 1) }
    var resolvedBrickSpacing: CGFloat { brickSpacing.livelineClamped(0, 12, fallback: 2) }
    var resolvedCornerRadius: CGFloat { cornerRadius.livelineAtLeast(0, fallback: 2) }
}

/// Visual options for candles transformed with the Heikin-Ashi recurrence.
public struct LivelineHeikinAshiStyle {
    public var widthRatio: CGFloat
    public var cornerRadius: CGFloat
    public var wickWidth: CGFloat
    public var upColor: Color?
    public var downColor: Color

    public init(
        widthRatio: CGFloat = 0.68,
        cornerRadius: CGFloat = 1.5,
        wickWidth: CGFloat = 1,
        upColor: Color? = nil,
        downColor: Color = Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255)
    ) {
        self.widthRatio = widthRatio
        self.cornerRadius = cornerRadius
        self.wickWidth = wickWidth
        self.upColor = upColor
        self.downColor = downColor
    }

    var resolvedWidthRatio: CGFloat { widthRatio.livelineClamped(0.15, 1, fallback: 0.68) }
    var resolvedCornerRadius: CGFloat { cornerRadius.livelineAtLeast(0, fallback: 1.5) }
    var resolvedWickWidth: CGFloat { wickWidth.livelineAtLeast(0.5, fallback: 1) }
}

/// Bid and ask liquidity available at one price level.
public struct LivelineOrderBookLevel: Identifiable, Hashable, Sendable {
    public var price: Double
    public var bidSize: Double
    public var askSize: Double

    public var id: Double { price }

    public init(price: Double, bidSize: Double = 0, askSize: Double = 0) {
        self.price = price.isFinite ? price : 0
        self.bidSize = bidSize.isFinite ? max(bidSize, 0) : 0
        self.askSize = askSize.isFinite ? max(askSize, 0) : 0
    }
}

/// Visual options for cumulative market-depth charts.
public struct LivelineMarketDepthStyle {
    public var bidColor: Color
    public var askColor: Color
    public var fillOpacity: Double
    public var lineWidth: CGFloat
    public var showsSpread: Bool
    public var showsMidPrice: Bool

    public init(
        bidColor: Color = Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255),
        askColor: Color = Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255),
        fillOpacity: Double = 0.2,
        lineWidth: CGFloat = 2,
        showsSpread: Bool = true,
        showsMidPrice: Bool = true
    ) {
        self.bidColor = bidColor
        self.askColor = askColor
        self.fillOpacity = fillOpacity
        self.lineWidth = lineWidth
        self.showsSpread = showsSpread
        self.showsMidPrice = showsMidPrice
    }

    var resolvedFillOpacity: Double { fillOpacity.livelineClamped(0, 1, fallback: 0.2) }
    var resolvedLineWidth: CGFloat { lineWidth.livelineAtLeast(0.5, fallback: 2) }
}

/// One OHLC interval and its traded volume.
public struct LivelineCandleVolume: Identifiable, Hashable, Sendable {
    public var time: TimeInterval
    public var open: Double
    public var high: Double
    public var low: Double
    public var close: Double
    public var volume: Double

    public var id: TimeInterval { time }

    public init(
        time: TimeInterval,
        open: Double,
        high: Double,
        low: Double,
        close: Double,
        volume: Double
    ) {
        let open = open.isFinite ? open : 0
        let high = high.isFinite ? high : open
        let low = low.isFinite ? low : open
        let close = close.isFinite ? close : open
        self.time = time.isFinite ? time : 0
        self.open = open
        self.high = max(low, high, open, close)
        self.low = min(low, high, open, close)
        self.close = close
        self.volume = volume.isFinite ? max(volume, 0) : 0
    }
}

/// Visual options for synchronized OHLC and volume panes.
public struct LivelineOHLCVolumeStyle {
    public var volumeHeightRatio: CGFloat
    public var candleWidthRatio: CGFloat
    public var paneSpacing: CGFloat
    public var upColor: Color?
    public var downColor: Color
    public var volumeOpacity: Double
    public var showsVolumeAverage: Bool

    public init(
        volumeHeightRatio: CGFloat = 0.24,
        candleWidthRatio: CGFloat = 0.66,
        paneSpacing: CGFloat = 10,
        upColor: Color? = nil,
        downColor: Color = Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255),
        volumeOpacity: Double = 0.42,
        showsVolumeAverage: Bool = true
    ) {
        self.volumeHeightRatio = volumeHeightRatio
        self.candleWidthRatio = candleWidthRatio
        self.paneSpacing = paneSpacing
        self.upColor = upColor
        self.downColor = downColor
        self.volumeOpacity = volumeOpacity
        self.showsVolumeAverage = showsVolumeAverage
    }

    var resolvedVolumeHeightRatio: CGFloat {
        volumeHeightRatio.livelineClamped(0.12, 0.42, fallback: 0.24)
    }
    var resolvedCandleWidthRatio: CGFloat {
        candleWidthRatio.livelineClamped(0.15, 1, fallback: 0.66)
    }
    var resolvedPaneSpacing: CGFloat { paneSpacing.livelineClamped(2, 24, fallback: 10) }
    var resolvedVolumeOpacity: Double { volumeOpacity.livelineClamped(0, 1, fallback: 0.42) }
}

/// Visual options for point-and-figure columns derived from a price series.
public struct LivelinePointAndFigureStyle {
    public var boxSize: Double
    public var reversalBoxes: Int
    public var columnSpacing: CGFloat
    public var symbolLineWidth: CGFloat
    public var risingColor: Color?
    public var fallingColor: Color

    public init(
        boxSize: Double,
        reversalBoxes: Int = 3,
        columnSpacing: CGFloat = 4,
        symbolLineWidth: CGFloat = 1.5,
        risingColor: Color? = nil,
        fallingColor: Color = Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255)
    ) {
        self.boxSize = boxSize
        self.reversalBoxes = reversalBoxes
        self.columnSpacing = columnSpacing
        self.symbolLineWidth = symbolLineWidth
        self.risingColor = risingColor
        self.fallingColor = fallingColor
    }

    var resolvedBoxSize: Double { boxSize.livelineAtLeast(0.000_001, fallback: 1) }
    var resolvedReversalBoxes: Int { min(max(reversalBoxes, 1), 10) }
    var resolvedColumnSpacing: CGFloat { columnSpacing.livelineClamped(0, 20, fallback: 4) }
    var resolvedSymbolLineWidth: CGFloat { symbolLineWidth.livelineAtLeast(0.5, fallback: 1.5) }
}
