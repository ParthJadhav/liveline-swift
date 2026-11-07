import Foundation

// Facts about a chart family's data that preparation, drawing, hover,
// accessibility, and the audio graph all depend on. Each is defined once here
// so those readers cannot disagree about what the chart shows.

extension LivelineRenderer {
    /// How far before the left edge samples are still read. The sample just
    /// off-screen lets a line or step enter the plot from the edge instead of
    /// starting at the first fully visible sample.
    static let sampleLookbehind: TimeInterval = 2

    /// Samples kept for range and hover when nothing falls inside the window,
    /// so a chart whose data has scrolled out still has a value range.
    static let fallbackSampleCount = 8

    static func sampleRange(leftEdge: TimeInterval, rightEdge: TimeInterval) -> ClosedRange<TimeInterval> {
        (leftEdge - sampleLookbehind)...rightEdge
    }
}

extension LivelineLayout {
    var sampleRange: ClosedRange<TimeInterval> {
        LivelineRenderer.sampleRange(leftEdge: leftEdge, rightEdge: rightEdge)
    }
}

extension Array where Element == LivelineTimelineItem {
    var livelineLaneCount: Int {
        Swift.max((map(\.lane).max() ?? 0) + 1, 1)
    }

    func livelineOverlapping(_ range: ClosedRange<TimeInterval>) -> [LivelineTimelineItem] {
        filter { $0.end >= range.lowerBound && $0.start <= range.upperBound }
    }
}

extension Array where Element == LivelineHeatmapCell {
    func livelineRowCount(rowLabels: [String]) -> Int {
        Swift.max((map(\.row).max() ?? 0) + 1, rowLabels.count, 1)
    }
}

extension LivelineHeatmapStyle {
    func rowName(_ row: Int) -> String {
        rowLabels.indices.contains(row)
            ? rowLabels[row]
            : String(format: LivelineStrings.labelRowFormat, row + 1)
    }
}

extension Array where Element == LivelineRadarPoint {
    /// A radar needs a polygon, so fewer than three spokes draw nothing.
    var livelineDrawable: [LivelineRadarPoint] {
        count >= 3 ? self : []
    }
}

extension Array where Element == LivelineCategoryValue {
    /// Donut segments and funnel stages exist only for positive values.
    var livelinePositive: [LivelineCategoryValue] {
        filter { $0.value > 0 }
    }
}

extension Array where Element == LivelineSeries {
    func livelineRenderable(hiding hiddenSeries: Set<String>) -> [LivelineSeries] {
        filter { !hiddenSeries.contains($0.id) && $0.livelineIsRenderable }
    }

    /// The series whose value and momentum the chart reports: the first one
    /// drawn in the window when there is one, else the best remaining
    /// candidate so controls and summaries still have a subject.
    func livelinePrimary(
        windowed: LivelineSeries?,
        visible: [LivelineSeries],
        renderable: [LivelineSeries]
    ) -> LivelineSeries? {
        windowed
            ?? renderable.first
            ?? visible.first
            ?? first(where: \.livelineIsRenderable)
            ?? first
    }
}

extension LivelineMath {
    /// Each layer's own signed amount. Stacking turns layers into spans, so
    /// readers need the span's height back with the sign of the raw value.
    static func stackedLayerValues(values: [Double], segments: [LivelineStackSegment]) -> [Double] {
        zip(values, segments).map { rawValue, segment in
            rawValue < 0
                ? segment.lower - segment.upper
                : segment.upper - segment.lower
        }
    }

    static func stackedLayerValues(point: LivelineStackedPoint, mode: LivelineStackMode) -> [Double] {
        stackedLayerValues(
            values: point.values,
            segments: stackedSegments(values: point.values, mode: mode)
        )
    }

    /// Settled candles with the live candle merged in, replacing the settled
    /// candle it shares a timestamp with, in time order.
    static func candles(
        _ candles: [LivelineCandle],
        including liveCandle: LivelineCandle?
    ) -> [LivelineCandle] {
        var values = candles
        if let liveCandle {
            if let index = values.firstIndex(where: { $0.time == liveCandle.time }) {
                values[index] = liveCandle
            } else {
                values.append(liveCandle)
            }
        }
        return values.sorted { $0.time < $1.time }
    }

    static func candleIsVisible(
        _ candle: LivelineCandle,
        width: TimeInterval,
        in range: ClosedRange<TimeInterval>
    ) -> Bool {
        candle.time + width >= range.lowerBound && candle.time <= range.upperBound
    }
}

extension LivelineSankeyGraph {
    func routeLabel(_ link: LivelineSankeyResolvedLink) -> String {
        String(
            format: LivelineStrings.labelFlowRouteFormat,
            nodes[link.sourceIndex].label,
            nodes[link.targetIndex].label
        )
    }
}

extension LivelineFormatters {
    /// A share of a whole in percent, to one decimal place, without the sign.
    static func share(_ percent: Double) -> String {
        percent.formatted(.number.precision(.fractionLength(1)))
    }
}
