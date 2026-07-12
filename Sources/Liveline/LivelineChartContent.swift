import Foundation

enum LivelineChartContent {
    case line(data: [LivelinePoint], value: Double)
    case bars(data: [LivelinePoint], style: LivelineBarStyle)
    case range(data: [LivelineRangePoint], style: LivelineRangeStyle)
    case scatter(data: [LivelinePoint], value: Double, style: LivelineScatterStyle)
    case steps(data: [LivelinePoint], value: Double, style: LivelineStepStyle)
    case lollipops(data: [LivelinePoint], style: LivelineLollipopStyle)
    case bubbles(data: [LivelineBubblePoint], style: LivelineBubbleStyle)
    case boxPlots(data: [LivelineBoxPlotPoint], style: LivelineBoxPlotStyle)
    case waterfall(data: [LivelinePoint], style: LivelineWaterfallStyle)
    case errorBars(data: [LivelineErrorBarPoint], style: LivelineErrorBarStyle)
    case dumbbells(data: [LivelineDumbbellPoint], style: LivelineDumbbellStyle)
    case stackedBars(data: [LivelineStackedPoint], style: LivelineStackedBarStyle)
    case stackedAreas(data: [LivelineStackedPoint], style: LivelineStackedAreaStyle)
    case timeline(data: [LivelineTimelineItem], style: LivelineTimelineStyle)
    case heatmap(data: [LivelineHeatmapCell], style: LivelineHeatmapStyle)
    case radar(data: [LivelineRadarPoint], style: LivelineRadarStyle)
    case donut(data: [LivelineCategoryValue], style: LivelineDonutStyle)
    case gauge(value: Double, range: ClosedRange<Double>, style: LivelineGaugeStyle)
    case funnel(data: [LivelineCategoryValue], style: LivelineFunnelStyle)
    case candle(
        data: [LivelinePoint],
        value: Double,
        candles: [LivelineCandle],
        candleWidth: TimeInterval,
        liveCandle: LivelineCandle?,
        lineData: [LivelinePoint],
        lineValue: Double?
    )
    case series([LivelineSeries])
}

enum LivelineChartKind: Hashable, CaseIterable {
    case line
    case bars
    case range
    case scatter
    case steps
    case lollipops
    case bubbles
    case boxPlots
    case waterfall
    case errorBars
    case dumbbells
    case stackedBars
    case stackedAreas
    case timeline
    case heatmap
    case radar
    case donut
    case gauge
    case funnel
    case candle
    case series
}

enum LivelineHoverBehavior: Equatable {
    case none
    case interpolated
    case discrete
}

struct LivelineChartCapabilities: Equatable {
    var usesValueAxis: Bool
    var usesCartesianGrid: Bool
    var usesTimeAxis: Bool
    var hoverBehavior: LivelineHoverBehavior
    var supportsLiveBadge: Bool = false
    var reservesBadgePadding: Bool = false
    var isRealtime: Bool = false
}

struct LivelineChartIdentity: Hashable {
    var kind: LivelineChartKind
    var seriesIDs: [String] = []
}

struct LivelineChartSemantics {
    var identity: LivelineChartIdentity
    var capabilities: LivelineChartCapabilities
    var currentValue: Double
    var momentum: LivelineMomentum
    var latestTime: TimeInterval?
    var seriesIDs: [String]
}

extension LivelineChartContent {
    func normalized() -> LivelineChartContent {
        switch self {
        case let .line(data, value):
            let data = LivelineInputNormalizer.points(data)
            return .line(data: data, value: LivelineInputNormalizer.value(value, fallback: data.last?.value ?? 0))

        case let .bars(data, style):
            return .bars(data: LivelineInputNormalizer.points(data), style: style)

        case let .range(data, style):
            return .range(data: LivelineInputNormalizer.ranges(data), style: style)

        case let .scatter(data, value, style):
            let data = LivelineInputNormalizer.points(data)
            return .scatter(data: data, value: LivelineInputNormalizer.value(value, fallback: data.last?.value ?? 0), style: style)

        case let .steps(data, value, style):
            let data = LivelineInputNormalizer.points(data)
            return .steps(data: data, value: LivelineInputNormalizer.value(value, fallback: data.last?.value ?? 0), style: style)

        case let .lollipops(data, style):
            return .lollipops(data: LivelineInputNormalizer.points(data), style: style)

        case let .bubbles(data, style):
            return .bubbles(data: LivelineInputNormalizer.bubbles(data), style: style)

        case let .boxPlots(data, style):
            return .boxPlots(data: LivelineInputNormalizer.boxPlots(data), style: style)

        case let .waterfall(data, style):
            return .waterfall(data: LivelineInputNormalizer.points(data), style: style)

        case let .errorBars(data, style):
            return .errorBars(data: LivelineInputNormalizer.errorBars(data), style: style)

        case let .dumbbells(data, style):
            return .dumbbells(data: LivelineInputNormalizer.dumbbells(data), style: style)

        case let .stackedBars(data, style):
            return .stackedBars(data: LivelineInputNormalizer.stacked(data), style: style)

        case let .stackedAreas(data, style):
            return .stackedAreas(data: LivelineInputNormalizer.stacked(data), style: style)

        case let .timeline(data, style):
            return .timeline(data: LivelineInputNormalizer.timeline(data), style: style)

        case let .heatmap(data, style):
            return .heatmap(data: LivelineInputNormalizer.heatmap(data), style: style)

        case let .radar(data, style):
            return .radar(data: LivelineInputNormalizer.radar(data), style: style)

        case let .donut(data, style):
            return .donut(data: LivelineInputNormalizer.categories(data), style: style)

        case let .gauge(value, range, style):
            let range = LivelineInputNormalizer.range(range, fallback: 0...1)
            return .gauge(
                value: LivelineInputNormalizer.value(value, fallback: range.lowerBound),
                range: range,
                style: style
            )

        case let .funnel(data, style):
            return .funnel(data: LivelineInputNormalizer.categories(data), style: style)

        case let .candle(data, value, candles, candleWidth, liveCandle, lineData, lineValue):
            let data = LivelineInputNormalizer.points(data)
            let lineData = LivelineInputNormalizer.points(lineData)
            let candles = LivelineInputNormalizer.candles(candles)
            let liveCandle = liveCandle.flatMap(LivelineInputNormalizer.candle)
            let fallback = lineData.last?.value ?? liveCandle?.close ?? data.last?.value ?? candles.last?.close ?? 0
            return .candle(
                data: data,
                value: LivelineInputNormalizer.value(value, fallback: fallback),
                candles: candles,
                candleWidth: LivelineInputNormalizer.positive(candleWidth, fallback: 1),
                liveCandle: liveCandle,
                lineData: lineData,
                lineValue: lineValue.flatMap { $0.isFinite ? $0 : nil }
            )

        case let .series(series):
            return .series(LivelineInputNormalizer.series(series))
        }
    }

    func semantics(hiddenSeries: Set<String> = []) -> LivelineChartSemantics {
        switch self {
        case let .line(data, value):
            return semantics(
                kind: .line,
                capabilities: .line,
                currentValue: value,
                momentumPoints: data,
                latestTime: data.last?.time
            )

        case let .bars(data, style):
            return semantics(
                kind: .bars,
                capabilities: .discreteCartesian,
                currentValue: data.last?.value ?? style.resolvedBaseline,
                momentumPoints: data,
                latestTime: data.last?.time
            )

        case let .range(data, _):
            let points = data.map { LivelinePoint(time: $0.time, value: $0.midpoint) }
            return semantics(
                kind: .range,
                capabilities: .interpolatedCartesian,
                currentValue: data.last?.midpoint ?? 0,
                momentumPoints: points,
                latestTime: data.last?.time
            )

        case let .scatter(data, value, _):
            return semantics(kind: .scatter, capabilities: .discreteCartesian, currentValue: value, momentumPoints: data, latestTime: data.last?.time)

        case let .steps(data, value, _):
            return semantics(kind: .steps, capabilities: .discreteCartesian, currentValue: value, momentumPoints: data, latestTime: data.last?.time)

        case let .lollipops(data, _):
            return semantics(kind: .lollipops, capabilities: .discreteCartesian, currentValue: data.last?.value ?? 0, momentumPoints: data, latestTime: data.last?.time)

        case let .bubbles(data, _):
            let points = data.map { LivelinePoint(time: $0.time, value: $0.value) }
            return semantics(kind: .bubbles, capabilities: .discreteCartesian, currentValue: data.last?.value ?? 0, momentumPoints: points, latestTime: data.last?.time)

        case let .boxPlots(data, _):
            let points = data.map { LivelinePoint(time: $0.time, value: $0.median) }
            return semantics(kind: .boxPlots, capabilities: .discreteCartesian, currentValue: data.last?.median ?? 0, momentumPoints: points, latestTime: data.last?.time)

        case let .waterfall(data, style):
            let points = LivelineMath.waterfallSegments(points: data, initialValue: style.resolvedInitialValue)
                .map { LivelinePoint(time: $0.time, value: $0.end) }
            return semantics(kind: .waterfall, capabilities: .discreteCartesian, currentValue: points.last?.value ?? style.resolvedInitialValue, momentumPoints: points, latestTime: data.last?.time)

        case let .errorBars(data, _):
            let points = data.map { LivelinePoint(time: $0.time, value: $0.value) }
            return semantics(kind: .errorBars, capabilities: .discreteCartesian, currentValue: data.last?.value ?? 0, momentumPoints: points, latestTime: data.last?.time)

        case let .dumbbells(data, _):
            let points = data.map { LivelinePoint(time: $0.time, value: $0.end) }
            return semantics(kind: .dumbbells, capabilities: .discreteCartesian, currentValue: data.last?.end ?? 0, momentumPoints: points, latestTime: data.last?.time)

        case let .stackedBars(data, style):
            let points = data.map { LivelinePoint(time: $0.time, value: LivelineMath.stackedPrimaryValue(point: $0, mode: style.mode)) }
            return semantics(kind: .stackedBars, capabilities: .discreteCartesian, currentValue: points.last?.value ?? 0, momentumPoints: points, latestTime: data.last?.time)

        case let .stackedAreas(data, style):
            let points = data.map { LivelinePoint(time: $0.time, value: LivelineMath.stackedPrimaryValue(point: $0, mode: style.mode)) }
            return semantics(kind: .stackedAreas, capabilities: .discreteCartesian, currentValue: points.last?.value ?? 0, momentumPoints: points, latestTime: data.last?.time)

        case let .timeline(data, _):
            let points = data.enumerated().map { LivelinePoint(time: Double($0.offset), value: $0.element.end - $0.element.start) }
            return semantics(
                kind: .timeline,
                capabilities: .timeline,
                currentValue: data.last.map { $0.end - $0.start } ?? 0,
                momentumPoints: points,
                latestTime: data.map(\.end).max()
            )

        case let .heatmap(data, _):
            let points = data.map { LivelinePoint(time: $0.time, value: $0.value) }
            return semantics(kind: .heatmap, capabilities: .timeline, currentValue: data.last?.value ?? 0, momentumPoints: points, latestTime: data.last?.time)

        case let .radar(data, _):
            let average = data.isEmpty ? 0 : data.map(\.value).reduce(0, +) / Double(data.count)
            return semantics(kind: .radar, capabilities: .radial, currentValue: average, momentumPoints: [], latestTime: nil)

        case let .donut(data, _):
            return semantics(kind: .donut, capabilities: .radial, currentValue: data.map(\.value).reduce(0, +), momentumPoints: [], latestTime: nil)

        case let .gauge(value, _, _):
            return semantics(kind: .gauge, capabilities: .radial, currentValue: value, momentumPoints: [], latestTime: nil)

        case let .funnel(data, _):
            return semantics(kind: .funnel, capabilities: .radial, currentValue: data.last?.value ?? 0, momentumPoints: [], latestTime: nil)

        case let .candle(data, value, candles, candleWidth, liveCandle, lineData, lineValue):
            let points = lineData.isEmpty ? data : lineData
            let latestTick = [data.last?.time, lineData.last?.time, liveCandle?.time].compactMap { $0 }.max()
            return semantics(
                kind: .candle,
                capabilities: .candle,
                currentValue: lineValue ?? liveCandle?.close ?? value,
                momentumPoints: points,
                latestTime: latestTick ?? candles.last.map { $0.time + candleWidth }
            )

        case let .series(series):
            let visible = series.filter { !hiddenSeries.contains($0.id) }
            let primary = visible.first ?? series.first
            let ids = series.map(\.id)
            return semantics(
                kind: .series,
                capabilities: .series,
                currentValue: primary?.value ?? 0,
                momentumPoints: primary?.data ?? [],
                latestTime: series.compactMap { $0.data.last?.time }.max(),
                seriesIDs: ids
            )
        }
    }

    private func semantics(
        kind: LivelineChartKind,
        capabilities: LivelineChartCapabilities,
        currentValue: Double,
        momentumPoints: [LivelinePoint],
        latestTime: TimeInterval?,
        seriesIDs: [String] = []
    ) -> LivelineChartSemantics {
        LivelineChartSemantics(
            identity: LivelineChartIdentity(kind: kind, seriesIDs: seriesIDs),
            capabilities: capabilities,
            currentValue: currentValue,
            momentum: LivelineMath.detectMomentum(points: momentumPoints),
            latestTime: latestTime,
            seriesIDs: seriesIDs
        )
    }
}

private extension LivelineChartCapabilities {
    static let line = LivelineChartCapabilities(
        usesValueAxis: true,
        usesCartesianGrid: true,
        usesTimeAxis: true,
        hoverBehavior: .interpolated,
        supportsLiveBadge: true,
        reservesBadgePadding: true,
        isRealtime: true
    )

    static let interpolatedCartesian = LivelineChartCapabilities(
        usesValueAxis: true,
        usesCartesianGrid: true,
        usesTimeAxis: true,
        hoverBehavior: .interpolated
    )

    static let discreteCartesian = LivelineChartCapabilities(
        usesValueAxis: true,
        usesCartesianGrid: true,
        usesTimeAxis: true,
        hoverBehavior: .discrete
    )

    static let timeline = LivelineChartCapabilities(
        usesValueAxis: false,
        usesCartesianGrid: false,
        usesTimeAxis: true,
        hoverBehavior: .none
    )

    static let radial = LivelineChartCapabilities(
        usesValueAxis: false,
        usesCartesianGrid: false,
        usesTimeAxis: false,
        hoverBehavior: .none
    )

    static let candle = LivelineChartCapabilities(
        usesValueAxis: true,
        usesCartesianGrid: false,
        usesTimeAxis: true,
        hoverBehavior: .interpolated,
        supportsLiveBadge: true,
        reservesBadgePadding: true,
        isRealtime: true
    )

    static let series = LivelineChartCapabilities(
        usesValueAxis: true,
        usesCartesianGrid: true,
        usesTimeAxis: true,
        hoverBehavior: .interpolated,
        reservesBadgePadding: true,
        isRealtime: true
    )
}

protocol LivelineTimedDatum {
    var time: TimeInterval { get }
}

extension LivelinePoint: LivelineTimedDatum {}
extension LivelineRangePoint: LivelineTimedDatum {}
extension LivelineBubblePoint: LivelineTimedDatum {}
extension LivelineBoxPlotPoint: LivelineTimedDatum {}
extension LivelineCandle: LivelineTimedDatum {}
extension LivelineErrorBarPoint: LivelineTimedDatum {}
extension LivelineDumbbellPoint: LivelineTimedDatum {}
extension LivelineStackedPoint: LivelineTimedDatum {}
extension LivelineHeatmapCell: LivelineTimedDatum {}

extension Array where Element: LivelineTimedDatum {
    func livelineVisible(in range: ClosedRange<TimeInterval>) -> [Element] {
        guard !isEmpty else { return [] }
        let lower = lowerBound(for: range.lowerBound)
        let upper = upperBound(for: range.upperBound)
        guard lower < upper else { return [] }
        return Array(self[lower..<upper])
    }

    private func lowerBound(for time: TimeInterval) -> Int {
        var lower = 0
        var upper = count
        while lower < upper {
            let middle = (lower + upper) / 2
            if self[middle].time < time {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower
    }

    private func upperBound(for time: TimeInterval) -> Int {
        var lower = 0
        var upper = count
        while lower < upper {
            let middle = (lower + upper) / 2
            if self[middle].time <= time {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower
    }
}

extension Array {
    func livelineSuffix(_ maximumLength: Int) -> [Element] {
        Array(suffix(Swift.max(maximumLength, 0)))
    }
}

extension Array where Element == LivelineCandle {
    func livelineVisible(in range: ClosedRange<TimeInterval>, candleWidth: TimeInterval) -> [LivelineCandle] {
        let width = LivelineInputNormalizer.positive(candleWidth, fallback: 1)
        return livelineVisible(in: (range.lowerBound - width)...range.upperBound)
            .filter { $0.time + width >= range.lowerBound }
    }
}

enum LivelineInputNormalizer {
    static func value(_ value: Double, fallback: Double) -> Double {
        LivelineScalar.value(value, fallback: fallback)
    }

    static func positive(_ value: Double, fallback: Double) -> Double {
        LivelineScalar.positiveDuration(value, fallback: fallback)
    }

    static func range(
        _ range: ClosedRange<Double>,
        fallback: ClosedRange<Double>
    ) -> ClosedRange<Double> {
        LivelineScalar.nondegenerateRange(
            lower: range.lowerBound,
            upper: range.upperBound,
            fallback: fallback
        )
    }

    static func points(_ source: [LivelinePoint]) -> [LivelinePoint] {
        timed(source) { point in
            guard let time = LivelineScalar.time(point.time), point.value.isFinite else { return nil }
            return LivelinePoint(time: time, value: value(point.value, fallback: 0))
        }
    }

    static func ranges(_ source: [LivelineRangePoint]) -> [LivelineRangePoint] {
        timed(source) { point in
            guard let time = LivelineScalar.time(point.time), point.lower.isFinite, point.upper.isFinite else { return nil }
            return LivelineRangePoint(
                time: time,
                lower: value(point.lower, fallback: 0),
                upper: value(point.upper, fallback: 0)
            )
        }
    }

    static func bubbles(_ source: [LivelineBubblePoint]) -> [LivelineBubblePoint] {
        timed(source) { point in
            guard let time = LivelineScalar.time(point.time), point.value.isFinite, point.magnitude.isFinite else { return nil }
            return LivelineBubblePoint(
                time: time,
                value: value(point.value, fallback: 0),
                magnitude: value(point.magnitude, fallback: 0)
            )
        }
    }

    static func boxPlots(_ source: [LivelineBoxPlotPoint]) -> [LivelineBoxPlotPoint] {
        timed(source) { point in
            let values = [point.minimum, point.lowerQuartile, point.median, point.upperQuartile, point.maximum]
            guard let time = LivelineScalar.time(point.time), values.allSatisfy(\.isFinite) else { return nil }
            return LivelineBoxPlotPoint(
                time: time,
                minimum: value(point.minimum, fallback: 0),
                lowerQuartile: value(point.lowerQuartile, fallback: 0),
                median: value(point.median, fallback: 0),
                upperQuartile: value(point.upperQuartile, fallback: 0),
                maximum: value(point.maximum, fallback: 0)
            )
        }
    }

    static func candles(_ source: [LivelineCandle]) -> [LivelineCandle] {
        timed(source, normalize: candle)
    }

    static func candle(_ candle: LivelineCandle) -> LivelineCandle? {
        let values = [candle.open, candle.high, candle.low, candle.close]
        guard let time = LivelineScalar.time(candle.time), values.allSatisfy(\.isFinite) else { return nil }
        let open = value(candle.open, fallback: 0)
        let high = value(candle.high, fallback: open)
        let low = value(candle.low, fallback: open)
        let close = value(candle.close, fallback: open)
        return LivelineCandle(
            time: time,
            open: open,
            high: max(high, open, close, low),
            low: min(low, open, close, high),
            close: close
        )
    }

    static func errorBars(_ source: [LivelineErrorBarPoint]) -> [LivelineErrorBarPoint] {
        timed(source) { point in
            let values = [point.value, point.lower, point.upper]
            guard let time = LivelineScalar.time(point.time), values.allSatisfy(\.isFinite) else { return nil }
            return LivelineErrorBarPoint(
                time: time,
                value: value(point.value, fallback: 0),
                lower: value(point.lower, fallback: 0),
                upper: value(point.upper, fallback: 0)
            )
        }
    }

    static func dumbbells(_ source: [LivelineDumbbellPoint]) -> [LivelineDumbbellPoint] {
        timed(source) { point in
            guard let time = LivelineScalar.time(point.time), point.start.isFinite, point.end.isFinite else { return nil }
            return LivelineDumbbellPoint(
                time: time,
                start: value(point.start, fallback: 0),
                end: value(point.end, fallback: 0)
            )
        }
    }

    static func stacked(_ source: [LivelineStackedPoint]) -> [LivelineStackedPoint] {
        timed(source) { point in
            guard let time = LivelineScalar.time(point.time) else { return nil }
            return LivelineStackedPoint(
                time: time,
                values: point.values.map { value($0, fallback: 0) }
            )
        }
    }

    static func timeline(_ source: [LivelineTimelineItem]) -> [LivelineTimelineItem] {
        let ordered = source.enumerated().compactMap { offset, item -> (Int, LivelineTimelineItem)? in
            guard !item.id.isEmpty,
                  let start = LivelineScalar.time(item.start),
                  let end = LivelineScalar.time(item.end)
            else { return nil }
            return (
                offset,
                LivelineTimelineItem(
                    id: item.id,
                    label: item.label,
                    start: start,
                    end: end,
                    lane: min(max(item.lane, 0), LivelineScalar.maximumDiscreteIndex)
                )
            )
        }
        .sorted { lhs, rhs in
            if lhs.1.start != rhs.1.start { return lhs.1.start < rhs.1.start }
            if lhs.1.end != rhs.1.end { return lhs.1.end < rhs.1.end }
            return lhs.0 < rhs.0
        }

        var seen = Set<String>()
        return ordered.compactMap { _, item in
            seen.insert(item.id).inserted ? item : nil
        }
    }

    static func heatmap(_ source: [LivelineHeatmapCell]) -> [LivelineHeatmapCell] {
        let normalized = timed(source) { cell in
            guard let time = LivelineScalar.time(cell.time), cell.value.isFinite else { return nil }
            return LivelineHeatmapCell(
                time: time,
                row: min(max(cell.row, 0), LivelineScalar.maximumDiscreteIndex),
                value: value(cell.value, fallback: 0)
            )
        }
        var seen = Set<String>()
        return normalized.filter { seen.insert($0.id).inserted }
    }

    static func radar(_ source: [LivelineRadarPoint]) -> [LivelineRadarPoint] {
        var seen = Set<String>()
        return source.compactMap { point in
            guard !point.label.isEmpty, point.value.isFinite, seen.insert(point.label).inserted else { return nil }
            return LivelineRadarPoint(label: point.label, value: value(point.value, fallback: 0))
        }
    }

    static func categories(_ source: [LivelineCategoryValue]) -> [LivelineCategoryValue] {
        var seen = Set<String>()
        return source.compactMap { entry in
            guard !entry.id.isEmpty, entry.value.isFinite, seen.insert(entry.id).inserted else { return nil }
            return LivelineCategoryValue(
                id: entry.id,
                label: entry.label,
                value: value(entry.value, fallback: 0)
            )
        }
    }

    static func series(_ source: [LivelineSeries]) -> [LivelineSeries] {
        var seen = Set<String>()
        return source.compactMap { entry in
            guard !entry.id.isEmpty, seen.insert(entry.id).inserted else { return nil }
            let data = points(entry.data)
            return LivelineSeries(
                id: entry.id,
                data: data,
                value: value(entry.value, fallback: data.last?.value ?? 0),
                color: entry.color,
                label: entry.label
            )
        }
    }

    private static func timed<Element: LivelineTimedDatum>(
        _ source: [Element],
        normalize: (Element) -> Element?
    ) -> [Element] {
        let normalized = source.enumerated().compactMap { offset, element -> (offset: Int, element: Element)? in
            guard let element = normalize(element), element.time.isFinite else { return nil }
            return (offset, element)
        }
        .sorted {
            $0.element.time == $1.element.time
                ? $0.offset < $1.offset
                : $0.element.time < $1.element.time
        }

        var result: [Element] = []
        result.reserveCapacity(normalized.count)
        for item in normalized {
            if result.last?.time == item.element.time {
                result[result.count - 1] = item.element
            } else {
                result.append(item.element)
            }
        }
        return result
    }
}
