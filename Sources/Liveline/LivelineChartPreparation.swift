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

/// Identity of a prepared chart. Everything `prepare` reads is either covered
/// here or derived from it, so a matching key means a matching result.
struct LivelinePreparedChartKey: Equatable {
    var content: LivelineContentFingerprint
    var hiddenSeries: Set<String>
    var leftEdge: TimeInterval
    var rightEdge: TimeInterval
    var referenceValue: Double?
    var exaggerate: Bool
}

enum LivelineChartPreparer {
    static func prepare(
        for content: LivelineChartContent,
        hiddenSeries: Set<String>,
        leftEdge: TimeInterval,
        rightEdge: TimeInterval,
        config: LivelineChartConfiguration,
        state: LivelineRenderState? = nil
    ) -> LivelinePreparedChart {
        guard let state else {
            return build(
                for: content,
                hiddenSeries: hiddenSeries,
                leftEdge: leftEdge,
                rightEdge: rightEdge,
                config: config,
                state: nil
            )
        }
        let key = cacheKey(
            for: content,
            hiddenSeries: hiddenSeries,
            leftEdge: leftEdge,
            rightEdge: rightEdge,
            config: config
        )
        return state.preparedChart(for: key) {
            build(
                for: content,
                hiddenSeries: hiddenSeries,
                leftEdge: leftEdge,
                rightEdge: rightEdge,
                config: config,
                state: state
            )
        }
    }

    private static func build(
        for content: LivelineChartContent,
        hiddenSeries: Set<String>,
        leftEdge: TimeInterval,
        rightEdge: TimeInterval,
        config: LivelineChartConfiguration,
        state: LivelineRenderState?
    ) -> LivelinePreparedChart {
        let sampleRange = LivelineRenderer.sampleRange(leftEdge: leftEdge, rightEdge: rightEdge)
        switch content {
        case let .line(data, value):
            let (visible, source) = window(data, range: sampleRange)
            return LivelinePreparedChart(
                primaryVisible: visible,
                rangePoints: source,
                rangeOverride: nil,
                primaryValue: value
            )

        case let .bars(data, style):
            let (visible, source) = window(data, range: sampleRange)
            let range = LivelineMath.barRangePoints(points: source, baseline: style.resolvedBaseline)
            return LivelinePreparedChart(
                primaryVisible: visible,
                rangePoints: range,
                rangeOverride: nil,
                primaryValue: data.last?.value ?? style.resolvedBaseline
            )

        case let .range(data, _):
            let (_, source) = window(data, range: sampleRange)
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
                rangeOverride: rangeOverride(bounds: bounds, primaryValue: primaryValue, config: config),
                primaryValue: primaryValue
            )

        case let .scatter(data, value, _):
            let (visible, source) = window(data, range: sampleRange)
            return LivelinePreparedChart(
                primaryVisible: visible,
                rangePoints: source,
                rangeOverride: nil,
                primaryValue: value
            )

        case let .steps(data, value, _):
            let (visible, source) = window(data, range: sampleRange)
            return LivelinePreparedChart(
                primaryVisible: visible,
                rangePoints: source,
                rangeOverride: nil,
                primaryValue: value
            )

        case let .lollipops(data, style):
            let (visible, source) = window(data, range: sampleRange)
            let primaryValue = data.last?.value ?? style.resolvedBaseline
            let bounds = LivelineMath.barRangePoints(points: source, baseline: style.resolvedBaseline)
            return LivelinePreparedChart(
                primaryVisible: visible,
                rangePoints: source,
                rangeOverride: rangeOverride(bounds: bounds, primaryValue: primaryValue, config: config),
                primaryValue: primaryValue
            )

        case let .bubbles(data, _):
            let (visible, source) = window(data, range: sampleRange)
            let visiblePoints = visible.map { LivelinePoint(time: $0.time, value: $0.value) }
            let rangePoints = source.map { LivelinePoint(time: $0.time, value: $0.value) }
            return LivelinePreparedChart(
                primaryVisible: visiblePoints,
                rangePoints: rangePoints,
                rangeOverride: nil,
                primaryValue: data.last?.value ?? 0
            )

        case let .boxPlots(data, _):
            let (visible, source) = window(data, range: sampleRange)
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
                rangeOverride: rangeOverride(bounds: bounds, primaryValue: primaryValue, config: config),
                primaryValue: primaryValue
            )

        case let .waterfall(data, style):
            let segments = LivelineMath.waterfallSegments(
                points: data,
                initialValue: style.resolvedInitialValue,
                state: state
            )
            let (visible, source) = window(segments, range: sampleRange)
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
                rangeOverride: rangeOverride(bounds: bounds, primaryValue: primaryValue, config: config),
                primaryValue: primaryValue
            )

        case let .errorBars(data, _):
            let (visible, source) = window(data, range: sampleRange)
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
                rangeOverride: rangeOverride(bounds: bounds, primaryValue: primaryValue, config: config),
                primaryValue: primaryValue
            )

        case let .dumbbells(data, _):
            let (visible, source) = window(data, range: sampleRange)
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
                rangeOverride: rangeOverride(bounds: endpoints, primaryValue: primaryValue, config: config),
                primaryValue: primaryValue
            )

        case let .stackedBars(data, style):
            let (visible, source) = window(data, range: sampleRange)
            let rangePoints = LivelineMath.stackedRangePoints(points: source, mode: style.mode)
            let primaryValue = LivelineMath.stackedPrimaryValue(point: data.last, mode: style.mode)
            return LivelinePreparedChart(
                primaryVisible: visible.map {
                    LivelinePoint(time: $0.time, value: LivelineMath.stackedPrimaryValue(point: $0, mode: style.mode))
                },
                rangePoints: rangePoints,
                rangeOverride: rangeOverride(bounds: rangePoints, primaryValue: primaryValue, config: config),
                primaryValue: primaryValue
            )

        case let .stackedAreas(data, style):
            let (visible, source) = window(data, range: sampleRange)
            let rangePoints = LivelineMath.stackedRangePoints(
                points: source,
                mode: style.mode,
                baseline: style.baseline
            )
            let primaryValue = LivelineMath.stackedPrimaryValue(point: data.last, mode: style.mode)
            return LivelinePreparedChart(
                primaryVisible: visible.map {
                    LivelinePoint(time: $0.time, value: LivelineMath.stackedPrimaryValue(point: $0, mode: style.mode))
                },
                rangePoints: rangePoints,
                rangeOverride: rangeOverride(bounds: rangePoints, primaryValue: primaryValue, config: config),
                primaryValue: primaryValue
            )

        case let .timeline(data, _):
            let visible = data.livelineOverlapping(sampleRange)
            let source = visible.isEmpty ? data.livelineSuffix(LivelineRenderer.fallbackSampleCount) : visible
            let laneCount = data.livelineLaneCount
            let lastDuration = data.last.map { $0.end - $0.start } ?? 0
            return LivelinePreparedChart(
                primaryVisible: [],
                rangePoints: source.map { LivelinePoint(time: $0.end, value: $0.end - $0.start) },
                rangeOverride: source.isEmpty ? nil : -0.5...Double(laneCount) - 0.5,
                primaryValue: lastDuration
            )

        case let .heatmap(data, style):
            let (_, source) = window(data, range: sampleRange)
            let rowCount = data.livelineRowCount(rowLabels: style.rowLabels)
            return LivelinePreparedChart(
                primaryVisible: [],
                rangePoints: source.map { LivelinePoint(time: $0.time, value: $0.value) },
                rangeOverride: source.isEmpty ? nil : -0.5...Double(rowCount) - 0.5,
                primaryValue: data.last?.value ?? 0
            )

        case let .radar(data, style):
            let hasData = !data.livelineDrawable.isEmpty
            let average = data.isEmpty ? 0 : data.map(\.value).reduce(0, +) / Double(data.count)
            return LivelinePreparedChart(
                primaryVisible: [],
                rangePoints: hasData ? [LivelinePoint(time: 0, value: average)] : [],
                rangeOverride: style.resolvedRange,
                primaryValue: average
            )

        case let .donut(data, _):
            let total = data.livelinePositive.map(\.value).reduce(0, +)
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
            let positive = data.livelinePositive
            let lastValue = positive.last?.value ?? 0
            return LivelinePreparedChart(
                primaryVisible: [],
                rangePoints: positive.isEmpty ? [] : [LivelinePoint(time: 0, value: lastValue)],
                rangeOverride: 0...max(positive.map(\.value).max() ?? 1, 1),
                primaryValue: lastValue
            )

        case let .histogram(values, style):
            let bins = state?.histogramBins(values: values, binning: style.binning)
                ?? LivelineMath.histogramBins(values: values, binning: style.binning)
            let maximumCount = bins.map(\.count).max() ?? 0
            return LivelinePreparedChart(
                primaryVisible: [],
                rangePoints: bins.isEmpty
                    ? []
                    : bins.enumerated().map { LivelinePoint(time: Double($0.offset), value: Double($0.element.count)) },
                rangeOverride: 0...Double(max(maximumCount, 1)),
                primaryValue: Double(values.count)
            )

        case let .bullet(style):
            let range = style.resolvedAxisRange
            return LivelinePreparedChart(
                primaryVisible: [],
                rangePoints: [LivelinePoint(time: 0, value: style.resolvedMeasure)],
                rangeOverride: range,
                primaryValue: style.resolvedMeasure
            )

        case let .treemap(nodes, _):
            // Hierarchy kinds carry no axis; the range points exist only so
            // `hasData` can tell an empty chart from a populated one.
            let values = nodes.map(\.resolvedValue).filter { $0 > 0 }
            return LivelinePreparedChart(
                primaryVisible: [],
                rangePoints: values.enumerated().map { LivelinePoint(time: Double($0.offset), value: $0.element) },
                rangeOverride: 0...max(values.max() ?? 1, 1),
                primaryValue: values.reduce(0, +)
            )

        case let .sunburst(nodes, _):
            let values = nodes.map(\.resolvedValue).filter { $0 > 0 }
            return LivelinePreparedChart(
                primaryVisible: [],
                rangePoints: values.enumerated().map { LivelinePoint(time: Double($0.offset), value: $0.element) },
                rangeOverride: 0...max(values.max() ?? 1, 1),
                primaryValue: values.reduce(0, +)
            )

        case let .sankey(links, _):
            let graph = state?.sankeyGraph(links: links) ?? LivelineMath.sankeyGraph(links: links)
            return LivelinePreparedChart(
                primaryVisible: [],
                rangePoints: graph.links.enumerated().map {
                    LivelinePoint(time: Double($0.offset), value: $0.element.value)
                },
                rangeOverride: 0...max(graph.links.map(\.value).max() ?? 1, 1),
                primaryValue: graph.total
            )

        case let .candle(data, value, candles, candleWidth, liveCandle, lineData, lineValue):
            let lineSource = lineData.isEmpty ? data : lineData
            let visible = lineSource.livelineVisible(in: sampleRange)
            var range = visible
            for candle in candles.livelineVisible(in: sampleRange, candleWidth: candleWidth) {
                range.append(LivelinePoint(time: candle.time, value: candle.high))
                range.append(LivelinePoint(time: candle.time, value: candle.low))
            }

            let liveCandleIsVisible = liveCandle.map {
                LivelineMath.candleIsVisible($0, width: candleWidth, in: sampleRange)
            } ?? false
            if let liveCandle, liveCandleIsVisible {
                range.append(LivelinePoint(time: liveCandle.time, value: liveCandle.high))
                range.append(LivelinePoint(time: liveCandle.time, value: liveCandle.low))
            }

            let usesFallbackRange = range.isEmpty
            if usesFallbackRange {
                range = lineSource.livelineSuffix(LivelineRenderer.fallbackSampleCount)
                if let fallback = liveCandle ?? candles.last {
                    range.append(LivelinePoint(time: fallback.time, value: fallback.high))
                    range.append(LivelinePoint(time: fallback.time, value: fallback.low))
                }
            }
            return LivelinePreparedChart(
                primaryVisible: visible,
                rangePoints: range,
                rangeOverride: nil,
                primaryValue: lineValue
                    ?? ((liveCandleIsVisible || usesFallbackRange) ? liveCandle?.close : nil)
                    ?? value
            )

        case let .series(series):
            let visibleSeries = series.filter { !hiddenSeries.contains($0.id) }
            let renderableSlices = LivelineSeriesSelector.visibleSlices(
                series: visibleSeries,
                visibleRange: sampleRange
            )
            let globallyRenderableSeries = visibleSeries.filter(\.livelineIsRenderable)
            let visiblePoints = renderableSlices.flatMap { $0.points }
            let fallback = globallyRenderableSeries.flatMap { $0.data.livelineSuffix(LivelineRenderer.fallbackSampleCount) }
            let firstSeries = series.livelinePrimary(
                windowed: renderableSlices.first?.series,
                visible: visibleSeries,
                renderable: globallyRenderableSeries
            )
            let primaryVisible = renderableSlices.first?.points ?? []
            var lower = Double.infinity
            var upper = -Double.infinity
            for slice in renderableSlices {
                let range = LivelineMath.computeRange(
                    points: slice.points,
                    currentValue: slice.series.value,
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

    /// The samples in the window, and the ones the value range is fitted to:
    /// the same samples, or the most recent few when none are in the window.
    private static func window<Element: LivelineTimedDatum>(
        _ data: [Element],
        range: ClosedRange<TimeInterval>
    ) -> (visible: [Element], source: [Element]) {
        let visible = data.livelineVisible(in: range)
        return (visible, visible.isEmpty ? data.livelineSuffix(LivelineRenderer.fallbackSampleCount) : visible)
    }

    private static func rangeOverride(
        bounds: [LivelinePoint],
        primaryValue: Double,
        config: LivelineChartConfiguration
    ) -> ClosedRange<Double>? {
        guard !bounds.isEmpty else { return nil }
        return LivelineMath.computeRange(
            points: bounds,
            currentValue: primaryValue,
            referenceValue: config.referenceLine?.value,
            exaggerate: config.exaggerate
        )
    }

    static func cacheKey(
        for content: LivelineChartContent,
        hiddenSeries: Set<String>,
        leftEdge: TimeInterval,
        rightEdge: TimeInterval,
        config: LivelineChartConfiguration
    ) -> LivelinePreparedChartKey {
        LivelinePreparedChartKey(
            content: content.fingerprint,
            hiddenSeries: hiddenSeries,
            leftEdge: leftEdge,
            rightEdge: rightEdge,
            referenceValue: config.referenceLine?.value,
            exaggerate: config.exaggerate
        )
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
