import Foundation

struct LivelineAdvancedAccessibilityCacheDescriptor {
    var shapes: [LivelineDataShape]
    var identifiers: [String]
    var variants: [Double]
}

extension LivelineAdvancedChartContent {
    var accessibilityEntryCount: Int {
        switch self {
        case .violin(let series, _), .ridgeline(let series, _):
            return series.filter { !$0.values.isEmpty }.count
        case .calendarHeatmap(let values, let style):
            return LivelineAdvancedLayout.calendarValuesByDay(values, calendar: style.calendar).count
        case .gantt(let tasks, _): return tasks.count
        case .chord(let links, _): return links.filter { $0.value > 0 }.count
        case .parallelCoordinates(let records, _): return records.count
        case .hexbin(let points, let style):
            return accessibilityHexbins(points: points, style: style).count
        case .bump(let series, _): return series.reduce(0) { $0 + $1.points.count }
        case .horizon(let points, _): return points.count
        case .marimekko(let columns, _):
            return columns.reduce(0) { $0 + $1.segments.filter { $0.value > 0 }.count }
        case .polarArea(let values, _), .waffle(let values, _):
            return values.filter { $0.value > 0 }.count
        case .network(let nodes, let edges, _):
            return nodes.count + edges.filter { $0.value > 0 }.count
        case .contour(let samples, _): return samples.count
        case .ternary(let points, _): return points.filter { $0.total > 0 }.count
        case .volumeProfile(let levels, _): return levels.filter { $0.volume > 0 }.count
        case .renko(let series, _): return series.bricks.count
        case .heikinAshi(let series, _): return series.candles.count
        case .marketDepth(let levels, _):
            let curve = LivelineAdvancedMath.marketDepthCurve(levels)
            return curve.bids.count + curve.asks.count
        case .ohlcVolume(let values, _): return values.count
        case .pointAndFigure(let series, _): return series.columns.count
        }
    }

    func accessibilityEntries(
        formatValue: (Double) -> String,
        formatTime: (TimeInterval) -> String
    ) -> [LivelineAccessibilityEntry] {
        switch self {
        case .violin(let series, _), .ridgeline(let series, _):
            return series.compactMap { series in
                guard !series.values.isEmpty else { return nil }
                return LivelineAccessibilityEntry(
                    id: series.id,
                    label: series.label,
                    value: String(
                        format: LivelineStrings.accessibilityDistributionFormat,
                        series.values.count,
                        formatValue(LivelineAdvancedMath.median(series.values)),
                        formatValue(LivelineAdvancedMath.quantile(series.values, probability: 0.25)),
                        formatValue(LivelineAdvancedMath.quantile(series.values, probability: 0.75))
                    )
                )
            }

        case .calendarHeatmap(let values, let style):
            let values = LivelineAdvancedLayout.calendarValuesByDay(
                values, calendar: style.calendar).values.sorted { $0.date < $1.date }
            return values.map {
                LivelineAccessibilityEntry(
                    id: "calendar-\($0.date.timeIntervalSinceReferenceDate)",
                    label: $0.label ?? formatTime($0.date.timeIntervalSince1970),
                    value: formatValue($0.value)
                )
            }

        case .gantt(let tasks, _):
            return tasks.map {
                LivelineAccessibilityEntry(
                    id: $0.id,
                    label: $0.label,
                    value: String(
                        format: LivelineStrings.accessibilityGanttFormat,
                        formatTime($0.start),
                        formatTime($0.end),
                        formatValue($0.end - $0.start),
                        percent($0.progress)
                    )
                )
            }

        case .chord(let links, _):
            return links.filter { $0.value > 0 }.map {
                LivelineAccessibilityEntry(
                    id: $0.id,
                    label: String(format: LivelineStrings.labelFlowRouteFormat, $0.source, $0.target),
                    value: formatValue($0.value)
                )
            }

        case .parallelCoordinates(let records, let style):
            return records.map { record in
                let values = record.values.enumerated().map { index, value in
                    String(
                        format: LivelineStrings.accessibilityNamedValueFormat,
                        LivelineAdvancedLayout.axisLabel(style.axisLabels, at: index),
                        formatValue(value))
                }.joined(separator: ", ")
                return LivelineAccessibilityEntry(id: record.id, label: record.label, value: values)
            }

        case .hexbin(let points, let style):
            return accessibilityHexbins(points: points, style: style).map {
                LivelineAccessibilityEntry(
                    id: "hexbin-\($0.column)-\($0.row)",
                    label: $0.count == 1 ? ($0.label ?? LivelineStrings.labelPoint) : LivelineStrings.labelPoint,
                    value: String(
                        format: LivelineStrings.accessibilityNamedValueFormat,
                        LivelineStrings.labelCount, "\($0.count)")
                        + ", " + String(
                            format: LivelineStrings.accessibilityNamedValueFormat,
                            LivelineStrings.labelWeight, formatValue($0.weight))
                )
            }

        case .bump(let series, _):
            return series.flatMap { series in
                series.points.map {
                    LivelineAccessibilityEntry(
                        id: "\(series.id)-\($0.time)",
                        label: "\(series.label), \(formatTime($0.time))",
                        value: String(
                            format: LivelineStrings.accessibilityNamedValueFormat, LivelineStrings.labelRank,
                            formatValue($0.rank))
                    )
                }
            }

        case .horizon(let points, _):
            return points.map {
                LivelineAccessibilityEntry(
                    id: "horizon-\($0.time)", label: formatTime($0.time), value: formatValue($0.value))
            }

        case .marimekko(let columns, _):
            return columns.flatMap { column in
                column.segments.filter { $0.value > 0 }.map {
                    LivelineAccessibilityEntry(
                        id: "\(column.id)-\($0.id)",
                        label: "\(column.label), \($0.label)",
                        value: [
                            String(
                                format: LivelineStrings.accessibilityNamedValueFormat,
                                LivelineStrings.labelColumnWidth, formatValue(column.width)),
                            String(
                                format: LivelineStrings.accessibilityNamedValueFormat, LivelineStrings.labelSegment,
                                formatValue($0.value)),
                        ].joined(separator: ", ")
                    )
                }
            }

        case .polarArea(let values, _), .waffle(let values, _):
            let positive = values.filter { $0.value > 0 }
            let total = positive.reduce(0) { $0 + $1.value }
            return positive.map {
                LivelineAccessibilityEntry(
                    id: $0.id,
                    label: $0.label,
                    value: shareDescription($0.value, total: total, formatValue: formatValue)
                )
            }

        case .network(let nodes, let edges, _):
            var labelsByID: [String: String] = [:]
            for node in nodes where labelsByID[node.id] == nil { labelsByID[node.id] = node.label }
            let nodeEntries = nodes.map { node in
                let connections = edges.filter { $0.source == node.id || $0.target == node.id }
                return LivelineAccessibilityEntry(
                    id: node.id,
                    label: node.label,
                    value: String(
                        format: LivelineStrings.accessibilityNetworkFormat, formatValue(node.weight),
                        connections.count)
                )
            }
            let edgeEntries = edges.filter { $0.value > 0 }.enumerated().map { index, edge in
                LivelineAccessibilityEntry(
                    id: "network-edge-\(index)-\(edge.source)-\(edge.target)",
                    label: String(
                        format: LivelineStrings.labelFlowRouteFormat,
                        labelsByID[edge.source] ?? edge.source,
                        labelsByID[edge.target] ?? edge.target),
                    value: String(
                        format: LivelineStrings.accessibilityNamedValueFormat,
                        LivelineStrings.labelWeight, formatValue(edge.value))
                )
            }
            return nodeEntries + edgeEntries

        case .contour(let samples, _):
            return samples.map {
                LivelineAccessibilityEntry(
                    id: $0.id,
                    label: [
                        String(
                            format: LivelineStrings.accessibilityNamedValueFormat, LivelineStrings.labelX,
                            formatValue($0.x)),
                        String(
                            format: LivelineStrings.accessibilityNamedValueFormat, LivelineStrings.labelY,
                            formatValue($0.y)),
                    ].joined(separator: ", "),
                    value: formatValue($0.value)
                )
            }

        case .ternary(let points, let style):
            let axes = LivelineAdvancedLayout.ternaryAxisLabels(style.axisLabels)
            return points.filter { $0.total > 0 }.map {
                LivelineAccessibilityEntry(
                    id: $0.id,
                    label: $0.label,
                    value: String(
                        format: LivelineStrings.accessibilityTernaryFormat,
                        axes[0], percent($0.a / $0.total),
                        axes[1], percent($0.b / $0.total),
                        axes[2], percent($0.c / $0.total)
                    ) + ", " + String(
                        format: LivelineStrings.accessibilityNamedValueFormat,
                        LivelineStrings.labelMagnitude, formatValue($0.magnitude))
                )
            }

        case .volumeProfile(let levels, _):
            return levels.filter { $0.volume > 0 }.map {
                LivelineAccessibilityEntry(
                    id: "volume-profile-\($0.price)",
                    label: String(
                        format: LivelineStrings.accessibilityNamedValueFormat, LivelineStrings.labelPrice,
                        formatValue($0.price)),
                    value: String(
                        format: LivelineStrings.accessibilityNamedValueFormat, LivelineStrings.labelVolume,
                        formatValue($0.volume))
                )
            }

        case .renko(let series, _):
            return series.bricks
                .enumerated().map { index, brick in
                    LivelineAccessibilityEntry(
                        id: "renko-\(index)",
                        label: formatTime(brick.time),
                        value: String(
                            format: LivelineStrings.accessibilityBrickFormat,
                            brick.isRising ? LivelineStrings.labelRising : LivelineStrings.labelFalling,
                            formatValue(brick.open),
                            formatValue(brick.close)
                        )
                    )
                }

        case .heikinAshi(let series, _):
            return series.candles.map { candle in
                LivelineAccessibilityEntry(
                    id: "heikin-\(candle.time)",
                    label: formatTime(candle.time),
                    value: ohlcDescription(candle, formatValue: formatValue)
                )
            }

        case .marketDepth(let levels, _):
            let curve = LivelineAdvancedMath.marketDepthCurve(levels)
            return [
                (LivelineStrings.labelBid, curve.bids),
                (LivelineStrings.labelAsk, curve.asks),
            ].flatMap { side, points in
                points.map {
                    LivelineAccessibilityEntry(
                        id: "depth-\(side)-\($0.time)",
                        label: side + ", " + String(
                            format: LivelineStrings.accessibilityNamedValueFormat,
                            LivelineStrings.labelPrice, formatValue($0.time)),
                        value: String(
                            format: LivelineStrings.accessibilityNamedValueFormat,
                            LivelineStrings.labelVolume, formatValue($0.value))
                    )
                }
            }

        case .ohlcVolume(let values, _):
            return values.map {
                let candle = LivelineCandle(
                    time: $0.time, open: $0.open, high: $0.high, low: $0.low, close: $0.close)
                return LivelineAccessibilityEntry(
                    id: "ohlc-volume-\($0.time)",
                    label: formatTime($0.time),
                    value: String(
                        format: LivelineStrings.accessibilityCandleVolumeFormat,
                        ohlcDescription(candle, formatValue: formatValue),
                        formatValue($0.volume)
                    )
                )
            }

        case .pointAndFigure(let series, _):
            return series.columns.map {
                LivelineAccessibilityEntry(
                    id: "point-figure-\($0.index)",
                    label: String(
                        format: LivelineStrings.accessibilityPointFigureLabelFormat,
                        $0.isRising ? LivelineStrings.labelRising : LivelineStrings.labelFalling,
                        $0.isRising ? "X" : "O",
                        $0.index + 1
                    ),
                    value: String(
                        format: LivelineStrings.accessibilityRangeBoxesFormat,
                        formatValue($0.low),
                        formatValue($0.high),
                        $0.boxCount
                    )
                )
            }
        }
    }

    var accessibilityCacheDescriptor: LivelineAdvancedAccessibilityCacheDescriptor {
        let identifiers: [String]
        let variants: [Double]
        let count: Int
        switch self {
        case .violin(let series, _), .ridgeline(let series, _):
            identifiers = series.flatMap { [$0.id, $0.label] }
            variants = series.flatMap(\.values)
            count = variants.count
        case .calendarHeatmap(let values, _):
            identifiers = values.map { $0.label ?? "" }
            variants = values.flatMap { [$0.date.timeIntervalSinceReferenceDate, $0.value] }
            count = values.count
        case .gantt(let tasks, _):
            identifiers = tasks.flatMap { [$0.id, $0.label] + $0.dependencyIDs }
            variants = tasks.flatMap { [$0.start, $0.end, Double($0.lane), $0.progress] }
            count = tasks.count
        case .chord(let links, _):
            identifiers = links.flatMap { [$0.source, $0.target] }
            variants = links.map(\.value)
            count = links.count
        case .parallelCoordinates(let records, let style):
            identifiers = style.axisLabels + records.flatMap { [$0.id, $0.label] }
            variants = records.flatMap(\.values)
            count = records.count
        case .hexbin(let points, _):
            identifiers = points.flatMap { [$0.id, $0.label ?? ""] }
            variants = points.flatMap { [$0.x, $0.y, $0.weight] }
            count = points.count
        case .bump(let series, _):
            identifiers = series.flatMap { [$0.id, $0.label] }
            variants = series.flatMap { $0.points.flatMap { [$0.time, $0.rank] } }
            count = variants.count / 2
        case .horizon(let points, _):
            identifiers = []
            variants = points.flatMap { [$0.time, $0.value] }
            count = points.count
        case .marimekko(let columns, _):
            identifiers = columns.flatMap { [$0.id, $0.label] + $0.segments.map(\.label) }
            variants = columns.flatMap { [$0.width] + $0.segments.map(\.value) }
            count = columns.count
        case .polarArea(let values, _), .waffle(let values, _):
            identifiers = values.map(\.label)
            variants = values.map(\.value)
            count = values.count
        case .network(let nodes, let edges, let style):
            identifiers =
                [style.layout.rawValue] + nodes.flatMap { [$0.id, $0.label, $0.group ?? ""] }
                + edges.flatMap { [$0.source, $0.target] }
            variants = nodes.map(\.weight) + edges.map(\.value)
            count = nodes.count + edges.count
        case .contour(let samples, _):
            identifiers = samples.map(\.id)
            variants = samples.flatMap { [$0.x, $0.y, $0.value] }
            count = samples.count
        case .ternary(let points, let style):
            identifiers = LivelineAdvancedLayout.ternaryAxisLabels(style.axisLabels)
                + points.flatMap { [$0.id, $0.label] }
            variants = points.flatMap { [$0.a, $0.b, $0.c, $0.magnitude] }
            count = points.count
        case .volumeProfile(let levels, _):
            identifiers = []
            variants = levels.flatMap { [$0.price, $0.volume] }
            count = levels.count
        case .renko(let series, let style):
            identifiers = []
            variants = [style.resolvedBrickSize] + series.points.flatMap { [$0.time, $0.value] }
            count = series.points.count
        case .heikinAshi(let series, _):
            identifiers = []
            variants = series.source.flatMap { [$0.time, $0.open, $0.high, $0.low, $0.close] }
            count = series.source.count
        case .marketDepth(let levels, _):
            identifiers = []
            variants = levels.flatMap { [$0.price, $0.bidSize, $0.askSize] }
            count = levels.count
        case .ohlcVolume(let values, _):
            identifiers = []
            variants = values.flatMap { [$0.time, $0.open, $0.high, $0.low, $0.close, $0.volume] }
            count = values.count
        case .pointAndFigure(let series, let style):
            identifiers = []
            variants =
                [style.resolvedBoxSize, Double(style.resolvedReversalBoxes)]
                + series.points.flatMap { [$0.time, $0.value] }
            count = series.points.count
        }
        return LivelineAdvancedAccessibilityCacheDescriptor(
            shapes: [
                LivelineDataShape(
                    storage: 0, count: count, firstTime: variants.first ?? 0, lastTime: variants.last ?? 0,
                    lastValue: variants.last ?? 0)
            ],
            identifiers: identifiers,
            variants: variants
        )
    }

    private func percent(_ value: Double) -> String {
        String(
            format: LivelineStrings.accessibilityPercentFormat,
            (value * 100).formatted(.number.precision(.fractionLength(1)))
        )
    }

    private func accessibilityHexbins(
        points: [LivelineXYPoint],
        style: LivelineHexbinStyle
    ) -> [LivelineHexbinCell] {
        let layout = LivelineLayout(
            size: CGSize(width: 320, height: 320),
            padding: .init(top: 0, right: 0, bottom: 0, left: 0),
            minValue: 0, maxValue: 1, leftEdge: 0, rightEdge: 1)
        return LivelineAdvancedLayout.hexbin(
            points: points, style: style, layout: layout, textScale: .standard)?.cells ?? []
    }

    private func shareDescription(
        _ value: Double,
        total: Double,
        formatValue: (Double) -> String
    ) -> String {
        guard total > 0 else { return formatValue(value) }
        return "\(formatValue(value)), \(percent(value / total))"
    }

    private func ohlcDescription(_ candle: LivelineCandle, formatValue: (Double) -> String) -> String {
        String(
            format: LivelineStrings.accessibilityCandleValueFormat,
            formatValue(candle.open),
            formatValue(candle.high),
            formatValue(candle.low),
            formatValue(candle.close)
        )
    }
}
