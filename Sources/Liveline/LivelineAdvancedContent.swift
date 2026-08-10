import Foundation

enum LivelineAdvancedChartContent {
    case violin([LivelineDistributionSeries], LivelineViolinStyle)
    case ridgeline([LivelineDistributionSeries], LivelineRidgelineStyle)
    case calendarHeatmap([LivelineCalendarValue], LivelineCalendarHeatmapStyle)
    case gantt([LivelineGanttTask], LivelineGanttStyle)
    case chord([LivelineChordLink], LivelineChordStyle)
    case parallelCoordinates([LivelineParallelRecord], LivelineParallelCoordinatesStyle)
    case hexbin([LivelineXYPoint], LivelineHexbinStyle)
    case bump([LivelineRankSeries], LivelineBumpStyle)
    case horizon([LivelinePoint], LivelineHorizonStyle)
    case marimekko([LivelineMarimekkoColumn], LivelineMarimekkoStyle)
    case polarArea([LivelineCategoryValue], LivelinePolarAreaStyle)
    case network([LivelineNetworkNode], [LivelineNetworkEdge], LivelineNetworkStyle)
    case contour([LivelineContourSample], LivelineContourStyle)
    case ternary([LivelineTernaryPoint], LivelineTernaryStyle)
    case waffle([LivelineCategoryValue], LivelineWaffleStyle)
    case volumeProfile([LivelinePriceVolume], LivelineVolumeProfileStyle)
    case renko(LivelineRenkoSeries, LivelineRenkoStyle)
    case heikinAshi(LivelineHeikinAshiSeries, LivelineHeikinAshiStyle)
    case marketDepth([LivelineOrderBookLevel], LivelineMarketDepthStyle)
    case ohlcVolume([LivelineCandleVolume], LivelineOHLCVolumeStyle)
    case pointAndFigure(LivelinePointFigureSeries, LivelinePointAndFigureStyle)
}

extension LivelineAdvancedChartContent {
    var kind: LivelineChartKind {
        switch self {
        case .violin: return .violin
        case .ridgeline: return .ridgeline
        case .calendarHeatmap: return .calendarHeatmap
        case .gantt: return .gantt
        case .chord: return .chord
        case .parallelCoordinates: return .parallelCoordinates
        case .hexbin: return .hexbin
        case .bump: return .bump
        case .horizon: return .horizon
        case .marimekko: return .marimekko
        case .polarArea: return .polarArea
        case .network: return .network
        case .contour: return .contour
        case .ternary: return .ternary
        case .waffle: return .waffle
        case .volumeProfile: return .volumeProfile
        case .renko: return .renko
        case .heikinAshi: return .heikinAshi
        case .marketDepth: return .marketDepth
        case .ohlcVolume: return .ohlcVolume
        case .pointAndFigure: return .pointAndFigure
        }
    }

    var isEmpty: Bool {
        switch self {
        case .violin(let data, _), .ridgeline(let data, _): return data.allSatisfy { $0.values.isEmpty }
        case .calendarHeatmap(let data, _): return data.isEmpty
        case .gantt(let data, _): return data.isEmpty
        case .chord(let data, _): return !data.contains { $0.value > 0 }
        case .parallelCoordinates(let data, _):
            return data.isEmpty || (data.map(\.values.count).max() ?? 0) < 2
        case .hexbin(let data, _): return data.isEmpty
        case .bump(let data, _): return data.allSatisfy { $0.points.isEmpty }
        case .horizon(let data, _): return data.count < 2
        case .marimekko(let data, _):
            return !data.contains { $0.width > 0 && $0.segments.contains { $0.value > 0 } }
        case .polarArea(let data, _), .waffle(let data, _): return !data.contains { $0.value > 0 }
        case .network(let nodes, _, _): return nodes.isEmpty
        case .contour(let data, _):
            return data.count < 4 || Set(data.map(\.x)).count < 2 || Set(data.map(\.y)).count < 2
        case .ternary(let data, _): return !data.contains { $0.total > 0 }
        case .volumeProfile(let data, _): return !data.contains { $0.volume > 0 }
        case .renko(let data, _): return data.points.count < 2
        case .heikinAshi(let data, _): return data.candles.isEmpty
        case .marketDepth(let data, _): return !data.contains { $0.bidSize > 0 || $0.askSize > 0 }
        case .ohlcVolume(let data, _): return data.isEmpty
        case .pointAndFigure(let data, _): return data.points.count < 2
        }
    }

    func normalized() -> LivelineAdvancedChartContent {
        switch self {
        case .violin(let data, let style):
            return .violin(data.map(Self.distribution), style)
        case .ridgeline(let data, let style):
            return .ridgeline(data.map(Self.distribution), style)
        case .calendarHeatmap(let data, let style):
            let values = data.map {
                LivelineCalendarValue(date: $0.date, value: $0.value, label: $0.label)
            }
            .sorted { $0.date < $1.date }
            return .calendarHeatmap(values, style)
        case .gantt(let data, let style):
            let tasks = data.map {
                LivelineGanttTask(
                    id: $0.id,
                    label: $0.label,
                    start: $0.start,
                    end: $0.end,
                    lane: $0.lane,
                    progress: $0.progress,
                    dependencyIDs: $0.dependencyIDs
                )
            }.sorted { ($0.start, $0.lane, $0.id) < ($1.start, $1.lane, $1.id) }
            return .gantt(tasks, style)
        case .chord(let data, let style):
            return .chord(
                data.map { LivelineChordLink(source: $0.source, target: $0.target, value: $0.value) }, style
            )
        case .parallelCoordinates(let data, let style):
            return .parallelCoordinates(
                data.map { LivelineParallelRecord(id: $0.id, label: $0.label, values: $0.values) }, style)
        case .hexbin(let data, let style):
            return .hexbin(
                data.map {
                    LivelineXYPoint(id: $0.id, x: $0.x, y: $0.y, weight: $0.weight, label: $0.label)
                }, style)
        case .bump(let data, let style):
            return .bump(
                data.map { LivelineRankSeries(id: $0.id, label: $0.label, points: $0.points) }, style)
        case .horizon(let data, let style):
            return .horizon(LivelineInputNormalizer.points(data), style)
        case .marimekko(let data, let style):
            return .marimekko(
                data.map {
                    LivelineMarimekkoColumn(
                        id: $0.id,
                        label: $0.label,
                        width: $0.width,
                        segments: LivelineInputNormalizer.categories($0.segments)
                    )
                }, style)
        case .polarArea(let data, let style):
            return .polarArea(LivelineInputNormalizer.categories(data), style)
        case .network(let nodes, let edges, let style):
            let normalizedNodes = nodes.map {
                LivelineNetworkNode(id: $0.id, label: $0.label, weight: $0.weight, group: $0.group)
            }
            let IDs = Set(normalizedNodes.map(\.id))
            let normalizedEdges =
                edges
                .filter { IDs.contains($0.source) && IDs.contains($0.target) && $0.source != $0.target }
                .map { LivelineNetworkEdge(source: $0.source, target: $0.target, value: $0.value) }
            return .network(normalizedNodes, normalizedEdges, style)
        case .contour(let data, let style):
            return .contour(
                data.map { LivelineContourSample(id: $0.id, x: $0.x, y: $0.y, value: $0.value) }, style)
        case .ternary(let data, let style):
            return .ternary(
                data.map {
                    LivelineTernaryPoint(
                        id: $0.id, label: $0.label, a: $0.a, b: $0.b, c: $0.c, magnitude: $0.magnitude)
                }, style)
        case .waffle(let data, let style):
            return .waffle(LivelineInputNormalizer.categories(data), style)
        case .volumeProfile(let data, let style):
            return .volumeProfile(
                data.map { LivelinePriceVolume(price: $0.price, volume: $0.volume) }.sorted {
                    $0.price < $1.price
                }, style)
        case .renko, .heikinAshi, .pointAndFigure:
            // The derived-series types normalize and derive in their initializer,
            // so these are already in their settled form.
            return self
        case .marketDepth(let data, let style):
            return .marketDepth(
                data.map {
                    LivelineOrderBookLevel(price: $0.price, bidSize: $0.bidSize, askSize: $0.askSize)
                }.sorted { $0.price < $1.price }, style)
        case .ohlcVolume(let data, let style):
            let values = data.map {
                LivelineCandleVolume(
                    time: $0.time,
                    open: $0.open,
                    high: $0.high,
                    low: $0.low,
                    close: $0.close,
                    volume: $0.volume
                )
            }.sorted { $0.time < $1.time }
            return .ohlcVolume(values, style)
        }
    }

    private static func distribution(_ series: LivelineDistributionSeries)
        -> LivelineDistributionSeries
    {
        LivelineDistributionSeries(id: series.id, label: series.label, values: series.values)
    }
}

extension LivelineAdvancedChartContent {
    func semantics() -> LivelineChartSemantics {
        let descriptor = semanticDescriptor
        return LivelineChartSemantics(
            identity: LivelineChartIdentity(kind: kind, seriesIDs: descriptor.seriesIDs),
            capabilities: descriptor.capabilities,
            currentValue: descriptor.currentValue,
            momentum: LivelineMath.detectMomentum(points: descriptor.momentumPoints),
            latestTime: descriptor.latestTime,
            seriesIDs: descriptor.seriesIDs,
            earliestTime: descriptor.earliestTime,
            sampleCount: descriptor.sampleCount
        )
    }

    private var semanticDescriptor: LivelineAdvancedSemanticDescriptor {
        switch self {
        case .violin(let series, _), .ridgeline(let series, _):
            let values = series.flatMap(\.values)
            return .untimed(value: LivelineAdvancedMath.median(values), count: values.count)
        case .calendarHeatmap(let values, _):
            return .untimed(value: values.last?.value ?? 0, count: values.count)
        case .gantt(let tasks, _):
            let latest = tasks.map(\.end).max()
            let earliest = tasks.map(\.start).min()
            return .timed(
                value: tasks.last.map { $0.end - $0.start } ?? 0,
                points: tasks.map { LivelinePoint(time: $0.end, value: $0.end - $0.start) },
                earliest: earliest,
                latest: latest,
                count: tasks.count,
                capabilities: .advancedTimeline
            )
        case .chord(let links, _):
            return .untimed(value: links.reduce(0) { $0 + $1.value }, count: links.count)
        case .parallelCoordinates(let records, _):
            return .untimed(value: records.last?.values.last ?? 0, count: records.count)
        case .hexbin(let points, _):
            return .untimed(value: points.reduce(0) { $0 + $1.weight }, count: points.count)
        case .bump(let series, _):
            let primary = series.first?.points.map { LivelinePoint(time: $0.time, value: $0.rank) } ?? []
            let all = series.flatMap(\.points)
            return .timed(
                value: primary.last?.value ?? 0,
                points: primary,
                earliest: all.map(\.time).min(),
                latest: all.map(\.time).max(),
                count: all.count,
                seriesIDs: series.map(\.id),
                capabilities: .advancedCartesian
            )
        case .horizon(let points, _):
            // Horizon bands fold magnitude into a shared compact baseline;
            // a Cartesian value grid would imply positions the folded bands
            // do not encode. Keep the real time axis without a misleading Y
            // axis.
            return .timed(value: points.last?.value ?? 0, points: points, capabilities: .advancedTimeline)
        case .marimekko(let columns, _):
            return .untimed(value: columns.reduce(0) { $0 + $1.width }, count: columns.count)
        case .polarArea(let values, _), .waffle(let values, _):
            return .untimed(value: values.reduce(0) { $0 + max($1.value, 0) }, count: values.count)
        case .network(let nodes, let edges, _):
            return .untimed(value: edges.reduce(0) { $0 + $1.value }, count: nodes.count)
        case .contour(let samples, _):
            return .untimed(value: samples.last?.value ?? 0, count: samples.count)
        case .ternary(let points, _):
            return .untimed(value: points.reduce(0) { $0 + $1.magnitude }, count: points.count)
        case .volumeProfile(let levels, _):
            return .untimed(value: levels.reduce(0) { $0 + $1.volume }, count: levels.count)
        case .renko(let series, _):
            return .untimed(
                value: series.points.last?.value ?? 0, count: series.points.count,
                capabilities: .advancedOrdinal)
        case .pointAndFigure(let series, _):
            return .untimed(
                value: series.points.last?.value ?? 0, count: series.points.count,
                capabilities: .advancedOrdinal)
        case .heikinAshi(let series, _):
            let points = series.candles.map { LivelinePoint(time: $0.time, value: $0.close) }
            return .timed(
                value: series.candles.last?.close ?? 0, points: points,
                capabilities: .advancedCartesian)
        case .marketDepth(let levels, _):
            let bestBid = levels.filter { $0.bidSize > 0 }.map(\.price).max()
            let bestAsk = levels.filter { $0.askSize > 0 }.map(\.price).min()
            let inside = [bestBid, bestAsk].compactMap { $0 }
            return .untimed(
                value: inside.reduce(0, +) / Double(inside.count.nonzero ?? 1), count: levels.count)
        case .ohlcVolume(let values, _):
            let points = values.map { LivelinePoint(time: $0.time, value: $0.close) }
            return .timed(
                value: values.last?.close ?? 0, points: points, capabilities: .advancedCartesian)
        }
    }
}

private struct LivelineAdvancedSemanticDescriptor {
    var currentValue: Double
    var momentumPoints: [LivelinePoint]
    var earliestTime: TimeInterval?
    var latestTime: TimeInterval?
    var sampleCount: Int
    var seriesIDs: [String]
    var capabilities: LivelineChartCapabilities

    static func untimed(
        value: Double,
        count: Int,
        capabilities: LivelineChartCapabilities = .advancedRadial
    ) -> Self {
        Self(
            currentValue: value,
            momentumPoints: [],
            earliestTime: nil,
            latestTime: nil,
            sampleCount: count,
            seriesIDs: [],
            capabilities: capabilities
        )
    }

    static func timed(
        value: Double,
        points: [LivelinePoint],
        earliest: TimeInterval? = nil,
        latest: TimeInterval? = nil,
        count: Int? = nil,
        seriesIDs: [String] = [],
        capabilities: LivelineChartCapabilities
    ) -> Self {
        Self(
            currentValue: value,
            momentumPoints: points,
            earliestTime: earliest ?? points.first?.time,
            latestTime: latest ?? points.last?.time,
            sampleCount: count ?? points.count,
            seriesIDs: seriesIDs,
            capabilities: capabilities
        )
    }
}

extension LivelineChartCapabilities {
    fileprivate static let advancedRadial = LivelineChartCapabilities(
        usesValueAxis: false,
        usesCartesianGrid: false,
        usesTimeAxis: false,
        hoverBehavior: .discrete
    )

    fileprivate static let advancedTimeline = LivelineChartCapabilities(
        usesValueAxis: false,
        usesCartesianGrid: false,
        usesTimeAxis: true,
        hoverBehavior: .discrete
    )

    fileprivate static let advancedCartesian = LivelineChartCapabilities(
        usesValueAxis: true,
        usesCartesianGrid: true,
        usesTimeAxis: true,
        hoverBehavior: .discrete
    )

    fileprivate static let advancedOrdinal = LivelineChartCapabilities(
        usesValueAxis: true,
        usesCartesianGrid: true,
        usesTimeAxis: false,
        hoverBehavior: .discrete
    )
}

extension Int {
    fileprivate var nonzero: Int? { self == 0 ? nil : self }
}

extension LivelineAdvancedChartContent {
    func prepared(
        leftEdge: TimeInterval,
        rightEdge: TimeInterval,
        configuration: LivelineChartConfiguration
    ) -> LivelinePreparedChart {
        let visibleRange = (leftEdge - 2)...rightEdge
        switch self {
        case .violin(let series, _), .ridgeline(let series, _):
            let values = series.flatMap(\.values)
            return untimedPrepared(values: values, primaryValue: LivelineAdvancedMath.median(values))

        case .calendarHeatmap(let values, _):
            return untimedPrepared(values: values.map(\.value), primaryValue: values.last?.value ?? 0)

        case .gantt(let tasks, _):
            let visible = tasks.filter {
                $0.end >= visibleRange.lowerBound && $0.start <= visibleRange.upperBound
            }
            let source = visible.isEmpty ? tasks : visible
            let laneCount = max((tasks.map(\.lane).max() ?? 0) + 1, 1)
            return LivelinePreparedChart(
                primaryVisible: source.map { LivelinePoint(time: $0.end, value: $0.end - $0.start) },
                rangePoints: source.map { LivelinePoint(time: $0.end, value: Double($0.lane)) },
                rangeOverride: source.isEmpty ? nil : -0.5...Double(laneCount) - 0.5,
                primaryValue: tasks.last.map { $0.end - $0.start } ?? 0
            )

        case .chord(let links, _):
            return untimedPrepared(
                values: links.map(\.value), primaryValue: links.reduce(0) { $0 + $1.value })

        case .parallelCoordinates(let records, _):
            let values = records.flatMap(\.values)
            return untimedPrepared(values: values, primaryValue: records.last?.values.last ?? 0)

        case .hexbin(let points, _):
            return untimedPrepared(
                values: points.map(\.weight), primaryValue: points.reduce(0) { $0 + $1.weight })

        case .bump(let series, _):
            let all = series.flatMap(\.points)
            let primary =
                series.first?.points
                .filter { visibleRange.contains($0.time) }
                .map { LivelinePoint(time: $0.time, value: $0.rank) } ?? []
            let values = all.map(\.rank)
            return timedPrepared(
                primary: primary,
                rangeValues: values,
                primaryValue: primary.last?.value ?? series.first?.points.last?.rank ?? 0,
                includeReference: configuration.referenceLine?.value
            )

        case .horizon(let points, _):
            let visible = points.livelineVisible(in: visibleRange)
            let source = visible.isEmpty ? points : visible
            let magnitude = max(source.map { abs($0.value) }.max() ?? 0, 0.000_001)
            return LivelinePreparedChart(
                primaryVisible: visible,
                rangePoints: source,
                rangeOverride: -magnitude...magnitude,
                primaryValue: points.last?.value ?? 0
            )

        case .marimekko(let columns, _):
            let values = columns.flatMap { $0.segments.map(\.value) }
            return untimedPrepared(values: values, primaryValue: columns.reduce(0) { $0 + $1.width })

        case .polarArea(let values, _), .waffle(let values, _):
            return untimedPrepared(
                values: values.map(\.value), primaryValue: values.reduce(0) { $0 + max($1.value, 0) })

        case .network(let nodes, let edges, _):
            return untimedPrepared(
                values: nodes.map(\.weight), primaryValue: edges.reduce(0) { $0 + $1.value })

        case .contour(let samples, _):
            return untimedPrepared(values: samples.map(\.value), primaryValue: samples.last?.value ?? 0)

        case .ternary(let points, _):
            return untimedPrepared(
                values: points.map(\.magnitude), primaryValue: points.reduce(0) { $0 + $1.magnitude })

        case .volumeProfile(let levels, _):
            return untimedPrepared(
                values: levels.map(\.volume), primaryValue: levels.reduce(0) { $0 + $1.volume })

        case .renko(let series, _):
            let bricks = series.bricks
            let visible = bricks.filter { visibleRange.contains($0.time) }
            let source = visible.isEmpty ? bricks : visible
            let range = source.flatMap { [$0.open, $0.close, $0.sourceHigh, $0.sourceLow] }
            return timedPrepared(
                primary: visible.map { LivelinePoint(time: $0.time, value: $0.close) },
                rangeValues: range,
                primaryValue: bricks.last?.close ?? series.points.last?.value ?? 0,
                includeReference: configuration.referenceLine?.value
            )

        case .heikinAshi(let series, _):
            let transformed = series.candles
            let visible = transformed.filter { visibleRange.contains($0.time) }
            let source = visible.isEmpty ? transformed : visible
            return timedPrepared(
                primary: visible.map { LivelinePoint(time: $0.time, value: $0.close) },
                rangeValues: source.flatMap { [$0.low, $0.high] },
                primaryValue: transformed.last?.close ?? 0,
                includeReference: configuration.referenceLine?.value
            )

        case .marketDepth(let levels, _):
            let curve = LivelineAdvancedMath.marketDepthCurve(levels)
            let inside = [curve.bestBid, curve.bestAsk].compactMap { $0 }
            return untimedPrepared(
                values: (curve.bids + curve.asks).map(\.value),
                primaryValue: inside.reduce(0, +) / Double(inside.count.nonzero ?? 1)
            )

        case .ohlcVolume(let values, _):
            let visible = values.filter { visibleRange.contains($0.time) }
            let source = visible.isEmpty ? values : visible
            return timedPrepared(
                primary: visible.map { LivelinePoint(time: $0.time, value: $0.close) },
                rangeValues: source.flatMap { [$0.low, $0.high] },
                primaryValue: values.last?.close ?? 0,
                includeReference: configuration.referenceLine?.value
            )

        case .pointAndFigure(let series, _):
            return untimedPrepared(
                values: series.columns.flatMap { [$0.low, $0.high] },
                primaryValue: series.points.last?.value ?? 0
            )
        }
    }

    private func untimedPrepared(values: [Double], primaryValue: Double) -> LivelinePreparedChart {
        let finite = values.filter(\.isFinite)
        let range = resolvedRange(finite)
        return LivelinePreparedChart(
            primaryVisible: [],
            rangePoints: finite.enumerated().map {
                LivelinePoint(time: Double($0.offset), value: $0.element)
            },
            rangeOverride: range,
            primaryValue: primaryValue.isFinite ? primaryValue : 0
        )
    }

    private func timedPrepared(
        primary: [LivelinePoint],
        rangeValues: [Double],
        primaryValue: Double,
        includeReference: Double?
    ) -> LivelinePreparedChart {
        var finite = rangeValues.filter(\.isFinite)
        if let includeReference, includeReference.isFinite { finite.append(includeReference) }
        return LivelinePreparedChart(
            primaryVisible: primary,
            rangePoints: finite.enumerated().map {
                LivelinePoint(time: Double($0.offset), value: $0.element)
            },
            rangeOverride: resolvedRange(finite),
            primaryValue: primaryValue.isFinite ? primaryValue : 0
        )
    }

    private func resolvedRange(_ values: [Double]) -> ClosedRange<Double>? {
        guard let lower = values.min(), let upper = values.max() else { return nil }
        if lower == upper {
            let padding = max(abs(lower) * 0.05, 0.5)
            return (lower - padding)...(upper + padding)
        }
        let padding = max((upper - lower) * 0.06, 0.000_001)
        return (lower - padding)...(upper + padding)
    }
}
