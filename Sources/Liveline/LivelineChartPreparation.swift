import Foundation

struct LivelinePreparedChart {
    var primaryVisible: [LivelinePoint]
    var rangePoints: [LivelinePoint]
    var rangeOverride: ClosedRange<Double>?
    var primaryValue: Double

    var hasData: Bool {
        !rangePoints.isEmpty
    }
}

enum LivelineChartPreparer {
    static func prepare(
        for content: LivelineChartContent,
        hiddenSeries: Set<String>,
        leftEdge: TimeInterval,
        rightEdge: TimeInterval,
        config: LivelineChartConfiguration
    ) -> LivelinePreparedChart {
        switch content {
        case let .line(data, value):
            let visible = data.livelineVisible(in: (leftEdge - 2)...rightEdge)
            return LivelinePreparedChart(
                primaryVisible: visible,
                rangePoints: visible.isEmpty ? data.livelineSuffix(8) : visible,
                rangeOverride: nil,
                primaryValue: value
            )

        case let .bars(data, style):
            let visible = data.livelineVisible(in: (leftEdge - 2)...rightEdge)
            let source = visible.isEmpty ? data.livelineSuffix(8) : visible
            let range = LivelineMath.barRangePoints(points: source, baseline: style.resolvedBaseline)
            return LivelinePreparedChart(
                primaryVisible: visible,
                rangePoints: range,
                rangeOverride: nil,
                primaryValue: data.last?.value ?? style.resolvedBaseline
            )

        case let .range(data, _):
            let visible = data.livelineVisible(in: (leftEdge - 2)...rightEdge)
            let source = visible.isEmpty ? data.livelineSuffix(8) : visible
            let midpoint = source.map { LivelinePoint(time: $0.time, value: $0.midpoint) }
            let bounds = source.flatMap { point in
                [
                    LivelinePoint(time: point.time, value: min(point.lower, point.upper)),
                    LivelinePoint(time: point.time, value: max(point.lower, point.upper)),
                ]
            }
            let primaryValue = data.last?.midpoint ?? 0
            return LivelinePreparedChart(
                primaryVisible: midpoint,
                rangePoints: midpoint,
                rangeOverride: bounds.isEmpty ? nil : LivelineMath.computeRange(
                    points: bounds,
                    currentValue: primaryValue,
                    referenceValue: config.referenceLine?.value,
                    exaggerate: config.exaggerate
                ),
                primaryValue: primaryValue
            )

        case let .scatter(data, value, _):
            let visible = data.livelineVisible(in: (leftEdge - 2)...rightEdge)
            return LivelinePreparedChart(
                primaryVisible: visible,
                rangePoints: visible.isEmpty ? data.livelineSuffix(8) : visible,
                rangeOverride: nil,
                primaryValue: value
            )

        case let .steps(data, value, _):
            let visible = data.livelineVisible(in: (leftEdge - 2)...rightEdge)
            return LivelinePreparedChart(
                primaryVisible: visible,
                rangePoints: visible.isEmpty ? data.livelineSuffix(8) : visible,
                rangeOverride: nil,
                primaryValue: value
            )

        case let .lollipops(data, style):
            let visible = data.livelineVisible(in: (leftEdge - 2)...rightEdge)
            let source = visible.isEmpty ? data.livelineSuffix(8) : visible
            let primaryValue = data.last?.value ?? style.resolvedBaseline
            let bounds = LivelineMath.barRangePoints(points: source, baseline: style.resolvedBaseline)
            return LivelinePreparedChart(
                primaryVisible: visible,
                rangePoints: source,
                rangeOverride: bounds.isEmpty ? nil : LivelineMath.computeRange(
                    points: bounds,
                    currentValue: primaryValue,
                    referenceValue: config.referenceLine?.value,
                    exaggerate: config.exaggerate
                ),
                primaryValue: primaryValue
            )

        case let .bubbles(data, _):
            let visible = data.livelineVisible(in: (leftEdge - 2)...rightEdge)
            let source = visible.isEmpty ? Array(data.suffix(8)) : visible
            let visiblePoints = visible.map { LivelinePoint(time: $0.time, value: $0.value) }
            let rangePoints = source.map { LivelinePoint(time: $0.time, value: $0.value) }
            return LivelinePreparedChart(
                primaryVisible: visiblePoints,
                rangePoints: rangePoints,
                rangeOverride: nil,
                primaryValue: data.last?.value ?? 0
            )

        case let .boxPlots(data, _):
            let visible = data.livelineVisible(in: (leftEdge - 2)...rightEdge)
            let source = visible.isEmpty ? Array(data.suffix(8)) : visible
            let medians = source.map { LivelinePoint(time: $0.time, value: $0.median) }
            let bounds = source.flatMap { point in
                [
                    LivelinePoint(time: point.time, value: point.minimum),
                    LivelinePoint(time: point.time, value: point.maximum),
                ]
            }
            let primaryValue = data.last?.median ?? 0
            return LivelinePreparedChart(
                primaryVisible: visible.map { LivelinePoint(time: $0.time, value: $0.median) },
                rangePoints: medians,
                rangeOverride: bounds.isEmpty ? nil : LivelineMath.computeRange(
                    points: bounds,
                    currentValue: primaryValue,
                    referenceValue: config.referenceLine?.value,
                    exaggerate: config.exaggerate
                ),
                primaryValue: primaryValue
            )

        case let .waterfall(data, style):
            let segments = LivelineMath.waterfallSegments(points: data, initialValue: style.resolvedInitialValue)
            let visible = segments.livelineVisible(in: (leftEdge - 2)...rightEdge)
            let source = visible.isEmpty ? Array(segments.suffix(8)) : visible
            let endpointPoints = source.map { LivelinePoint(time: $0.time, value: $0.end) }
            let bounds = source.flatMap { segment in
                [
                    LivelinePoint(time: segment.time, value: segment.start),
                    LivelinePoint(time: segment.time, value: segment.end),
                ]
            }
            let primaryValue = segments.last?.end ?? style.resolvedInitialValue
            return LivelinePreparedChart(
                primaryVisible: visible.map { LivelinePoint(time: $0.time, value: $0.end) },
                rangePoints: endpointPoints,
                rangeOverride: bounds.isEmpty ? nil : LivelineMath.computeRange(
                    points: bounds,
                    currentValue: primaryValue,
                    referenceValue: config.referenceLine?.value,
                    exaggerate: config.exaggerate
                ),
                primaryValue: primaryValue
            )

        case let .errorBars(data, _):
            let visible = data.livelineVisible(in: (leftEdge - 2)...rightEdge)
            let source = visible.isEmpty ? Array(data.suffix(8)) : visible
            let values = source.map { LivelinePoint(time: $0.time, value: $0.value) }
            let bounds = source.flatMap {
                [
                    LivelinePoint(time: $0.time, value: $0.lower),
                    LivelinePoint(time: $0.time, value: $0.upper),
                ]
            }
            let primaryValue = data.last?.value ?? 0
            return LivelinePreparedChart(
                primaryVisible: visible.map { LivelinePoint(time: $0.time, value: $0.value) },
                rangePoints: values,
                rangeOverride: bounds.isEmpty ? nil : LivelineMath.computeRange(
                    points: bounds,
                    currentValue: primaryValue,
                    referenceValue: config.referenceLine?.value,
                    exaggerate: config.exaggerate
                ),
                primaryValue: primaryValue
            )

        case let .dumbbells(data, _):
            let visible = data.livelineVisible(in: (leftEdge - 2)...rightEdge)
            let source = visible.isEmpty ? Array(data.suffix(8)) : visible
            let endpoints = source.flatMap {
                [
                    LivelinePoint(time: $0.time, value: $0.start),
                    LivelinePoint(time: $0.time, value: $0.end),
                ]
            }
            let primaryValue = data.last?.end ?? 0
            return LivelinePreparedChart(
                primaryVisible: visible.map { LivelinePoint(time: $0.time, value: $0.end) },
                rangePoints: source.map { LivelinePoint(time: $0.time, value: $0.end) },
                rangeOverride: endpoints.isEmpty ? nil : LivelineMath.computeRange(
                    points: endpoints,
                    currentValue: primaryValue,
                    referenceValue: config.referenceLine?.value,
                    exaggerate: config.exaggerate
                ),
                primaryValue: primaryValue
            )

        case let .stackedBars(data, style):
            let visible = data.livelineVisible(in: (leftEdge - 2)...rightEdge)
            let source = visible.isEmpty ? Array(data.suffix(8)) : visible
            let rangePoints = LivelineMath.stackedRangePoints(points: source, mode: style.mode)
            let primaryValue = LivelineMath.stackedPrimaryValue(point: data.last, mode: style.mode)
            return LivelinePreparedChart(
                primaryVisible: visible.map {
                    LivelinePoint(time: $0.time, value: LivelineMath.stackedPrimaryValue(point: $0, mode: style.mode))
                },
                rangePoints: rangePoints,
                rangeOverride: rangePoints.isEmpty ? nil : LivelineMath.computeRange(
                    points: rangePoints,
                    currentValue: primaryValue,
                    referenceValue: config.referenceLine?.value,
                    exaggerate: config.exaggerate
                ),
                primaryValue: primaryValue
            )

        case let .stackedAreas(data, style):
            let visible = data.livelineVisible(in: (leftEdge - 2)...rightEdge)
            let source = visible.isEmpty ? Array(data.suffix(8)) : visible
            let rangePoints = LivelineMath.stackedRangePoints(points: source, mode: style.mode)
            let primaryValue = LivelineMath.stackedPrimaryValue(point: data.last, mode: style.mode)
            return LivelinePreparedChart(
                primaryVisible: visible.map {
                    LivelinePoint(time: $0.time, value: LivelineMath.stackedPrimaryValue(point: $0, mode: style.mode))
                },
                rangePoints: rangePoints,
                rangeOverride: rangePoints.isEmpty ? nil : LivelineMath.computeRange(
                    points: rangePoints,
                    currentValue: primaryValue,
                    referenceValue: config.referenceLine?.value,
                    exaggerate: config.exaggerate
                ),
                primaryValue: primaryValue
            )

        case let .timeline(data, _):
            let visible = data.filter { $0.end >= leftEdge - 2 && $0.start <= rightEdge }
            let source = visible.isEmpty ? Array(data.suffix(8)) : visible
            let laneCount = max((data.map(\.lane).max() ?? 0) + 1, 1)
            let lastDuration = data.last.map { $0.end - $0.start } ?? 0
            return LivelinePreparedChart(
                primaryVisible: [],
                rangePoints: source.map { LivelinePoint(time: $0.end, value: $0.end - $0.start) },
                rangeOverride: source.isEmpty ? nil : -0.5...Double(laneCount) - 0.5,
                primaryValue: lastDuration
            )

        case let .heatmap(data, style):
            let visible = data.livelineVisible(in: (leftEdge - 2)...rightEdge)
            let source = visible.isEmpty ? Array(data.suffix(8)) : visible
            let rowCount = max((data.map(\.row).max() ?? 0) + 1, style.rowLabels.count, 1)
            return LivelinePreparedChart(
                primaryVisible: [],
                rangePoints: source.map { LivelinePoint(time: $0.time, value: $0.value) },
                rangeOverride: source.isEmpty ? nil : -0.5...Double(rowCount) - 0.5,
                primaryValue: data.last?.value ?? 0
            )

        case let .radar(data, style):
            let hasData = data.count >= 3
            let average = data.isEmpty ? 0 : data.map(\.value).reduce(0, +) / Double(data.count)
            return LivelinePreparedChart(
                primaryVisible: [],
                rangePoints: hasData ? [LivelinePoint(time: 0, value: average)] : [],
                rangeOverride: style.resolvedRange,
                primaryValue: average
            )

        case let .donut(data, _):
            let total = data.map(\.value).reduce(0, +)
            return LivelinePreparedChart(
                primaryVisible: [],
                rangePoints: total > 0 ? [LivelinePoint(time: 0, value: total)] : [],
                rangeOverride: 0...max(total, 1),
                primaryValue: total
            )

        case let .gauge(value, range, _):
            let resolvedValue = value.isFinite ? value : range.lowerBound
            return LivelinePreparedChart(
                primaryVisible: [],
                rangePoints: [LivelinePoint(time: 0, value: resolvedValue)],
                rangeOverride: range.lowerBound == range.upperBound
                    ? (range.lowerBound - 0.5)...(range.upperBound + 0.5)
                    : range,
                primaryValue: resolvedValue
            )

        case let .funnel(data, _):
            let positive = data.filter { $0.value > 0 }
            let lastValue = positive.last?.value ?? 0
            return LivelinePreparedChart(
                primaryVisible: [],
                rangePoints: positive.isEmpty ? [] : [LivelinePoint(time: 0, value: lastValue)],
                rangeOverride: 0...max(positive.map(\.value).max() ?? 1, 1),
                primaryValue: lastValue
            )

        case let .candle(data, value, candles, candleWidth, liveCandle, lineData, lineValue):
            let visible = (lineData.isEmpty ? data : lineData).livelineVisible(in: (leftEdge - 2)...rightEdge)
            var range = visible
            for candle in candles.livelineVisible(in: (leftEdge - 2)...rightEdge, candleWidth: candleWidth) {
                range.append(LivelinePoint(time: candle.time, value: candle.high))
                range.append(LivelinePoint(time: candle.time, value: candle.low))
            }
            if range.isEmpty {
                range = (lineData.isEmpty ? data : lineData).livelineSuffix(8)
            }
            if let liveCandle {
                range.append(LivelinePoint(time: liveCandle.time, value: liveCandle.high))
                range.append(LivelinePoint(time: liveCandle.time, value: liveCandle.low))
            } else if let last = candles.last {
                range.append(LivelinePoint(time: last.time, value: last.high))
                range.append(LivelinePoint(time: last.time, value: last.low))
            }
            return LivelinePreparedChart(
                primaryVisible: visible,
                rangePoints: range,
                rangeOverride: nil,
                primaryValue: lineValue ?? liveCandle?.close ?? value
            )

        case let .series(series):
            let visibleSeries = series.filter { !hiddenSeries.contains($0.id) }
            let visiblePoints = visibleSeries.flatMap { $0.data.livelineVisible(in: (leftEdge - 2)...rightEdge) }
            let fallback = visibleSeries.flatMap { $0.data.livelineSuffix(8) }
            let firstSeries = visibleSeries.first ?? series.first
            let primaryVisible = firstSeries?.data.livelineVisible(in: (leftEdge - 2)...rightEdge) ?? []
            var lower = Double.infinity
            var upper = -Double.infinity
            for entry in visibleSeries {
                let visible = entry.data.livelineVisible(in: (leftEdge - 2)...rightEdge)
                guard visible.count >= 2 else { continue }
                let range = LivelineMath.computeRange(
                    points: visible,
                    currentValue: entry.value,
                    referenceValue: config.referenceLine?.value,
                    exaggerate: config.exaggerate
                )
                lower = min(lower, range.lowerBound)
                upper = max(upper, range.upperBound)
            }
            return LivelinePreparedChart(
                primaryVisible: primaryVisible,
                rangePoints: visiblePoints.isEmpty ? fallback : visiblePoints,
                rangeOverride: lower.isFinite && upper.isFinite ? lower...upper : nil,
                primaryValue: firstSeries?.value ?? 0
            )
        }
    }

}

extension LivelinePreparedChart {
    func swingMagnitude(valueRange: Double) -> Double {
        guard primaryVisible.count >= 2, valueRange > 0 else { return 0 }
        let lookback = min(5, primaryVisible.count - 1)
        let recentDelta = abs(primaryVisible[primaryVisible.count - 1].value - primaryVisible[primaryVisible.count - 1 - lookback].value)
        return min(recentDelta / valueRange, 1)
    }
}
