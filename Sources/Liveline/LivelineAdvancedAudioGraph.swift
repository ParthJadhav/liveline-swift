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
        visibleRange: ClosedRange<TimeInterval>?
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
        case .calendarHeatmap(let values, _):
            return time([
                timed(
                    LivelineStrings.labelValue, continuous: false,
                    values.map { ($0.date.timeIntervalSince1970, $0.value) })
            ])
        case .gantt(let tasks, _):
            return time([
                timed(
                    LivelineStrings.labelDuration, continuous: false,
                    tasks.map { ($0.start, $0.end - $0.start) })
            ])
        case .chord(let links, _):
            let samples = links.filter { $0.value > 0 }.map {
                (String(format: LivelineStrings.labelFlowRouteFormat, $0.source, $0.target), $0.value)
            }
            return categories([categorical(LivelineStrings.labelFlow, samples)], order: samples.map(\.0))
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
        case .hexbin(let points, _):
            let order = points.map { $0.label ?? $0.id }
            return categories(
                [
                    categorical(LivelineStrings.labelX, zip(order, points).map { ($0, $1.x) }),
                    categorical(LivelineStrings.labelY, zip(order, points).map { ($0, $1.y) }),
                    categorical(LivelineStrings.labelWeight, zip(order, points).map { ($0, $1.weight) }),
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
            let labels = columns.map(\.label)
            return categories(
                [categorical(LivelineStrings.labelColumnWidth, columns.map { ($0.label, $0.width) })],
                order: labels)
        case .polarArea(let values, _), .waffle(let values, _):
            let positive = values.filter { $0.value > 0 }
            return categories(
                [categorical(LivelineStrings.labelValue, positive.map { ($0.label, $0.value) })],
                order: positive.map(\.label))
        case .network(let nodes, let edges, _):
            let order = nodes.map(\.label)
            return categories(
                [
                    categorical(LivelineStrings.labelWeight, nodes.map { ($0.label, $0.weight) }),
                    categorical(
                        LivelineStrings.labelConnections,
                        nodes.map { node in
                            (
                                node.label,
                                Double(edges.filter { $0.source == node.id || $0.target == node.id }.count)
                            )
                        }),
                ], order: order)
        case .contour(let samples, _):
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
                    categorical(axes[0], valid.map { ($0.label, $0.a / $0.total) }),
                    categorical(axes[1], valid.map { ($0.label, $0.b / $0.total) }),
                    categorical(axes[2], valid.map { ($0.label, $0.c / $0.total) }),
                ], order: order, range: 0...1)
        case .volumeProfile(let levels, _):
            let order = levels.map { String($0.price) }
            return categories(
                [categorical(LivelineStrings.labelVolume, zip(order, levels).map { ($0, $1.volume) })],
                order: order)
        case .renko(let series, _):
            let bricks = series.bricks
            return time([
                timed(LivelineStrings.labelClose, continuous: false, bricks.map { ($0.time, $0.close) })
            ])
        case .heikinAshi(let series, _):
            return time(candleSeries(series.candles, timed: timed))
        case .marketDepth(let levels, _):
            let curve = LivelineAdvancedMath.marketDepthCurve(levels)
            return time([
                timed(LivelineStrings.labelBid, continuous: true, curve.bids.map { ($0.time, $0.value) }),
                timed(LivelineStrings.labelAsk, continuous: true, curve.asks.map { ($0.time, $0.value) }),
            ])
        case .ohlcVolume(let values, _):
            let candles = values.map {
                LivelineCandle(time: $0.time, open: $0.open, high: $0.high, low: $0.low, close: $0.close)
            }
            return time(
                candleSeries(candles, timed: timed) + [
                    timed(LivelineStrings.labelVolume, continuous: false, values.map { ($0.time, $0.volume) })
                ])
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
