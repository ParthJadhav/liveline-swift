import Foundation

/// Price series paired with the shapes derived from them.
///
/// Renko bricks, Heikin-Ashi candles, and point-and-figure columns are pure
/// functions of a price series plus a couple of style parameters, but they are
/// not free: each walks the whole series, and Renko can emit several bricks per
/// input point. Five subsystems need the same answer — range preparation, the
/// draw pass, hit testing, VoiceOver, and the audio graph — and each used to
/// derive its own copy, so the work ran several times per frame and any change
/// to a derivation had five call sites to keep in step.
///
/// Each type below derives once, in its only initializer, at the point where
/// the chart content is normalized. A value cannot exist whose derived shapes
/// disagree with its prices, and no reader can recompute them by accident.

/// A price series and the Renko bricks derived from it.
struct LivelineRenkoSeries {
    let points: [LivelinePoint]
    let bricks: [LivelineRenkoBrick]

    init(points: [LivelinePoint], style: LivelineRenkoStyle) {
        let normalized = LivelineInputNormalizer.points(points)
        self.points = normalized
        self.bricks = LivelineAdvancedMath.renkoBricks(
            points: normalized, brickSize: style.resolvedBrickSize)
    }
}

/// Source OHLC intervals and their Heikin-Ashi transform.
struct LivelineHeikinAshiSeries {
    let source: [LivelineCandle]
    let candles: [LivelineCandle]

    init(source: [LivelineCandle]) {
        let normalized = LivelineInputNormalizer.candles(source)
        self.source = normalized
        self.candles = LivelineAdvancedMath.heikinAshiCandles(normalized)
    }
}

/// A price series and the point-and-figure columns derived from it.
struct LivelinePointFigureSeries {
    let points: [LivelinePoint]
    let columns: [LivelinePointFigureColumn]

    init(points: [LivelinePoint], style: LivelinePointAndFigureStyle) {
        let normalized = LivelineInputNormalizer.points(points)
        self.points = normalized
        self.columns = LivelineAdvancedMath.pointFigureColumns(
            points: normalized,
            boxSize: style.resolvedBoxSize,
            reversalBoxes: style.resolvedReversalBoxes
        )
    }
}
