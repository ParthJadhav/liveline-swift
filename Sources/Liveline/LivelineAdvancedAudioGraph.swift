import Foundation

struct LivelineAdvancedAudioGraphDescriptor {
    var series: [LivelineAudioGraphSeries]
    var isCategorical: Bool
    var categoryOrder: [String]
    var valueRange: ClosedRange<Double>?
}

enum LivelineAdvancedAudioGraph {
    static func make(
        content: LivelineAdvancedChartContent,
        visibleRange: ClosedRange<TimeInterval>?,
        formatValue: (Double) -> String = { String($0) }
    ) -> LivelineAdvancedAudioGraphDescriptor {
        func timed(_ name: String, continuous: Bool, _ samples: [(TimeInterval, Double)])
            -> LivelineAudioGraphSeries
        {
            LivelineAudioGraphSeries(
                name: name,
                isContinuous: continuous,
                points: samples.compactMap { time, value in
                    guard value.isFinite, visibleRange?.contains(time) ?? true else { return nil }
                    return LivelineAudioGraphPoint(time: time, category: nil, value: value)
                }
            )
        }
        func categorical(_ name: String, _ samples: [(String, Double)]) -> LivelineAudioGraphSeries {
            LivelineAudioGraphSeries(
                name: name,
                isContinuous: false,
                points: samples.compactMap { category, value in
                    guard value.isFinite else { return nil }
                    return LivelineAudioGraphPoint(time: nil, category: category, value: value)
                }
            )
        }
        func categories(
            _ series: [LivelineAudioGraphSeries], order: [String], range: ClosedRange<Double>? = nil
        ) -> LivelineAdvancedAudioGraphDescriptor {
            LivelineAdvancedAudioGraphDescriptor(
                series: series, isCategorical: true, categoryOrder: order, valueRange: range)
        }
        func time(_ series: [LivelineAudioGraphSeries], range: ClosedRange<Double>? = nil)
            -> LivelineAdvancedAudioGraphDescriptor
        {
            LivelineAdvancedAudioGraphDescriptor(
                series: series, isCategorical: false, categoryOrder: [], valueRange: range)
        }

        switch content {
        case .violin(let series, _), .ridgeline(let series, _):
            let series = series.filter { !$0.values.isEmpty }
            let order = series.map(\.label)
            return categories(
                [
                    categorical(
                        LivelineStrings.labelMedian,
                        series.map { ($0.label, LivelineAdvancedMath.median($0.values)) }),
                    categorical(
                        LivelineStrings.labelFirstQuartile,
                        series.map { ($0.label, LivelineAdvancedMath.quantile($0.values, probability: 0.25)) }),
                    categorical(
                        LivelineStrings.labelThirdQuartile,
                        series.map { ($0.label, LivelineAdvancedMath.quantile($0.values, probability: 0.75)) }),
                ], order: order)
        case .calendarHeatmap(let values, let style):
            let supported = LivelineAdvancedLayout.calendarValuesInSupportedSpan(
                values, calendar: style.calendar)
            let values = LivelineAdvancedLayout.calendarValuesByDay(
                supported, calendar: style.calendar).values.sorted { $0.date < $1.date }
            return time([
                timed(
                    LivelineStrings.labelValue, continuous: false,
                    values.map { ($0.date.timeIntervalSince1970, $0.value) })
            ])
        case .gantt(let tasks, _):
            let visible = tasks.filter { task in
                guard let visibleRange else { return true }
                return task.end >= visibleRange.lowerBound && task.start <= visibleRange.upperBound
            }
            return time([
                LivelineAudioGraphSeries(
                    name: LivelineStrings.labelDuration,
                    isContinuous: false,
                    points: visible.map { task in
                        LivelineAudioGraphPoint(
                            time: max(task.start, visibleRange?.lowerBound ?? task.start),
                            category: nil, value: task.end - task.start)
                    })
            ])
        case .chord(let links, _):
            let nodeSamples = LivelineAdvancedLayout.chordNodeTotals(links).map {
                ($0.label, $0.value)
            }
            let linkSamples = links.filter { $0.value > 0 }.map {
                (String(format: LivelineStrings.labelFlowRouteFormat, $0.source, $0.target), $0.value)
            }
            return categories(
                [
                    categorical(LivelineStrings.labelTotal, nodeSamples),
                    categorical(LivelineStrings.labelFlow, linkSamples),
                ],
                order: nodeSamples.map(\.0) + linkSamples.map(\.0))
        case .parallelCoordinates(let records, let style):
            let axisCount = records.map(\.values.count).max() ?? 0
            let order = records.map(\.label)
            let series = (0..<axisCount).map { axis in
                categorical(
                    LivelineAdvancedLayout.axisLabel(style.axisLabels, at: axis),
                    records.compactMap {
                        $0.values.indices.contains(axis) ? ($0.label, $0.values[axis]) : nil
                    })
            }
            return categories(series, order: order)
        case .hexbin(let points, let style):
            let cells = LivelineAdvancedLayout.hexbinCellsForInspection(
                points: points, style: style)
            let order = cells.enumerated().map { index, cell in
                cell.count == 1 ? (cell.label ?? "\(LivelineStrings.labelPoint) \(index + 1)")
                    : "\(LivelineStrings.labelPoint) \(index + 1)"
            }
            return categories(
                [
                    categorical(
                        LivelineStrings.labelCount,
                        zip(order, cells).map { ($0, Double($1.count)) }),
                    categorical(
                        LivelineStrings.labelWeight,
                        zip(order, cells).map { ($0, $1.weight) }),
                ], order: order)
        case .bump(let series, _):
            return time(
                series.map { entry in
                    timed(entry.label, continuous: true, entry.points.map { ($0.time, $0.rank) })
                })
        case .horizon(let points, _):
            return time([
                timed(LivelineStrings.labelValue, continuous: true, points.map { ($0.time, $0.value) })
            ])
        case .marimekko(let columns, _):
            let columns = columns.filter { column in
                column.width > 0 && column.segments.contains { $0.value > 0 }
            }
            let labels = columns.map(\.label)
            var segmentOrder: [(id: String, label: String)] = []
            for segment in columns.flatMap(\.segments)
            where segment.value > 0 && !segmentOrder.contains(where: { $0.id == segment.id }) {
                segmentOrder.append((segment.id, segment.label))
            }
            let segmentSeries = segmentOrder.map { segmentIdentity in
                categorical(
                    segmentIdentity.label,
                    columns.compactMap { column in
                        let value = column.segments
                            .filter { $0.id == segmentIdentity.id && $0.value > 0 }
                            .reduce(0) { $0 + $1.value }
                        return value > 0 ? (column.label, value) : nil
                    })
            }
            return categories(
                [categorical(LivelineStrings.labelColumnWidth, columns.map { ($0.label, $0.width) })]
                    + segmentSeries,
                order: labels)
        case .polarArea(let values, _), .waffle(let values, _):
            let positive = values.filter { $0.value > 0 }
            return categories(
                [categorical(LivelineStrings.labelValue, positive.map { ($0.label, $0.value) })],
                order: positive.map(\.label))
        case .network(let nodes, let edges, _):
            let nodeOrder = nodes.map(\.label)
            var seenNodeIDs: Set<String> = []
            let connectionSamples = nodes.map { node -> (String, Double) in
                let ownsIdentifier = seenNodeIDs.insert(node.id).inserted
                let count = ownsIdentifier
                    ? edges.filter { $0.source == node.id || $0.target == node.id }.count
                    : 0
                return (node.label, Double(count))
            }
            var labelsByID: [String: String] = [:]
            for node in nodes where labelsByID[node.id] == nil { labelsByID[node.id] = node.label }
            let edgeSamples = edges.filter { $0.value > 0 }.map {
                (
                    String(
                        format: LivelineStrings.labelFlowRouteFormat,
                        labelsByID[$0.source] ?? $0.source,
                        labelsByID[$0.target] ?? $0.target),
                    $0.value
                )
            }
            return categories(
                [
                    categorical(LivelineStrings.labelWeight, nodes.map { ($0.label, $0.weight) }),
                    categorical(LivelineStrings.labelConnections, connectionSamples),
                    categorical(LivelineStrings.labelFlow, edgeSamples),
                ], order: nodeOrder + edgeSamples.map(\.0))
        case .contour(let samples, _):
            let samples = LivelineAdvancedLayout.contourSamplesByCoordinate(samples)
            let order = samples.map(\.id)
            return categories(
                [categorical(LivelineStrings.labelValue, zip(order, samples).map { ($0, $1.value) })],
                order: order)
        case .ternary(let points, let style):
            let valid = points.filter { $0.total > 0 }
            let order = valid.map(\.label)
            let axes = LivelineAdvancedLayout.ternaryAxisLabels(style.axisLabels)
            return categories(
                [
                    categorical(axes[0], valid.map { ($0.label, $0.proportions.a) }),
                    categorical(axes[1], valid.map { ($0.label, $0.proportions.b) }),
                    categorical(axes[2], valid.map { ($0.label, $0.proportions.c) }),
                    categorical(LivelineStrings.labelMagnitude, valid.map { ($0.label, $0.magnitude) }),
                ], order: order)
        case .volumeProfile(let levels, _):
            let levels = LivelineAdvancedLayout.volumeProfileLevels(levels)
            let order = levels.map { formatValue($0.price) }
            return categories(
                [categorical(LivelineStrings.labelVolume, zip(order, levels).map { ($0, $1.volume) })],
                order: order)
        case .renko(let series, _):
            let bricks = series.bricks
            let order = bricks.indices.map {
                String(format: LivelineStrings.labelColumnFormat, $0 + 1)
            }
            return categories(
                [categorical(LivelineStrings.labelClose, zip(order, bricks).map { ($0, $1.close) })],
                order: order)
        case .heikinAshi(let series, _):
            return time(candleSeries(series.candles, timed: timed))
        case .marketDepth(let levels, _):
            let curve = LivelineAdvancedMath.marketDepthCurve(levels)
            let prices = Array(Set((curve.bids + curve.asks).map(\.time))).sorted()
            let order = prices.map(formatValue)
            return categories([
                categorical(
                    LivelineStrings.labelBid,
                    curve.bids.map { (formatValue($0.time), $0.value) }),
                categorical(
                    LivelineStrings.labelAsk,
                    curve.asks.map { (formatValue($0.time), $0.value) }),
            ], order: order)
        case .ohlcVolume(let values, _):
            let candles = values.map {
                LivelineCandle(time: $0.time, open: $0.open, high: $0.high, low: $0.low, close: $0.close)
            }
            return time(
                candleSeries(candles, timed: timed)
                    + [timed(LivelineStrings.labelVolume, continuous: false, values.map { ($0.time, $0.volume) })]
            )
        case .pointAndFigure(let series, _):
            let columns = series.columns
            let order = columns.map { String(format: LivelineStrings.labelColumnFormat, $0.index + 1) }
            return categories(
                [
                    categorical(LivelineStrings.labelLow, zip(order, columns).map { ($0, $1.low) }),
                    categorical(LivelineStrings.labelHigh, zip(order, columns).map { ($0, $1.high) }),
                ], order: order)
        }
    }

    private static func candleSeries(
        _ candles: [LivelineCandle],
        timed: (String, Bool, [(TimeInterval, Double)]) -> LivelineAudioGraphSeries
    ) -> [LivelineAudioGraphSeries] {
        [
            timed(LivelineStrings.labelClose, true, candles.map { ($0.time, $0.close) }),
            timed(LivelineStrings.labelOpen, false, candles.map { ($0.time, $0.open) }),
            timed(LivelineStrings.labelHigh, false, candles.map { ($0.time, $0.high) }),
            timed(LivelineStrings.labelLow, false, candles.map { ($0.time, $0.low) }),
        ]
    }
}
