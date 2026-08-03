import Foundation

struct LivelineAccessibilityEntry: Equatable {
    var id: String
    var label: String
    var value: String
}

enum LivelineAccessibilityAdjustment {
    case increment
    case decrement
}

/// A compact, adjustable accessibility representation for the Canvas-backed
/// chart. VoiceOver users hear the chart summary first and can then swipe up
/// or down to inspect every supplied datum without relying on visual scrubbing.
struct LivelineChartAccessibilityModel: Equatable {
    var label: String
    var summary: String
    var entries: [LivelineAccessibilityEntry]
    var entryCount: Int
    var isLoading = false

    var hint: String {
        if isLoading {
            return LivelineStrings.accessibilityHintLoading
        }
        return entryCount == 0
            ? LivelineStrings.accessibilityHintEmpty
            : LivelineStrings.accessibilityHintAdjustable
    }

    func value(at index: Int?) -> String {
        guard let index, entries.indices.contains(index) else {
            guard entryCount > 0 else { return summary }
            let count = entryCount == 1
                ? LivelineStrings.accessibilityCountOne
                : String(format: LivelineStrings.accessibilityCountOtherFormat, entryCount)
            return String(format: LivelineStrings.accessibilitySummaryWithCountFormat, summary, count)
        }
        let entry = entries[index]
        return String(
            format: LivelineStrings.accessibilityEntryFormat,
            entry.label,
            entry.value,
            index + 1,
            entryCount
        )
    }

    func adjustedIndex(
        from current: Int?,
        direction: LivelineAccessibilityAdjustment
    ) -> Int? {
        guard entryCount > 0 else { return nil }
        switch direction {
        case .increment:
            return min((current ?? -1) + 1, entryCount - 1)
        case .decrement:
            return max((current ?? entryCount) - 1, 0)
        }
    }

    static func make(
        content: LivelineChartContent,
        semantics: LivelineChartSemantics,
        configuration: LivelineChartConfiguration,
        hiddenSeries: Set<String>,
        includeEntries: Bool = true
    ) -> LivelineChartAccessibilityModel {
        if configuration.loading {
            return LivelineChartAccessibilityModel(
                label: semantics.identity.kind.accessibilityLabel,
                summary: LivelineStrings.accessibilitySummaryLoading,
                entries: [],
                entryCount: 0,
                isLoading: true
            )
        }

        let formatValue = configuration.formatValue
        let formatTime = configuration.formatTime
        let entryCount = accessibleEntryCount(
            content: content,
            configuration: configuration,
            hiddenSeries: hiddenSeries
        )
        let entries: [LivelineAccessibilityEntry]

        func pointEntries(_ points: [LivelinePoint], prefix: String? = nil) -> [LivelineAccessibilityEntry] {
            points.enumerated().map { index, point in
                let time = formatTime(point.time)
                return LivelineAccessibilityEntry(
                    id: "\(prefix ?? "point")-\(point.time)-\(index)",
                    label: [prefix, time].compactMap { $0 }.joined(separator: ", "),
                    value: formatValue(point.value)
                )
            }
        }

        func stackedEntries(
            _ data: [LivelineStackedPoint],
            mode: LivelineStackMode
        ) -> [LivelineAccessibilityEntry] {
            data.enumerated().map { index, point in
                let segments = LivelineMath.stackedSegments(values: point.values, mode: mode)
                let signedValues = zip(point.values, segments).map { rawValue, segment in
                    rawValue < 0
                        ? segment.lower - segment.upper
                        : segment.upper - segment.lower
                }
                let values = signedValues.enumerated()
                    .map {
                        String(
                            format: LivelineStrings.accessibilityStackedSeriesFormat,
                            $0.offset + 1,
                            formatValue($0.element)
                        )
                    }
                    .joined(separator: ", ")
                return LivelineAccessibilityEntry(
                    id: "stack-\(point.time)-\(index)",
                    label: formatTime(point.time),
                    value: String(
                        format: LivelineStrings.accessibilityStackedValueFormat,
                        values,
                        formatValue(signedValues.reduce(0, +))
                    )
                )
            }
        }

        switch includeEntries ? content : nil {
        case let .line(data, _),
             let .bars(data, _),
             let .scatter(data, _, _),
             let .steps(data, _, _),
             let .lollipops(data, _):
            entries = pointEntries(data)

        case let .range(data, _):
            entries = data.enumerated().map { index, point in
                LivelineAccessibilityEntry(
                    id: "range-\(point.time)-\(index)",
                    label: formatTime(point.time),
                    value: String(
                        format: LivelineStrings.accessibilityRangeValueFormat,
                        formatValue(point.lower),
                        formatValue(point.upper)
                    )
                )
            }

        case let .bubbles(data, _):
            entries = data.enumerated().map { index, point in
                LivelineAccessibilityEntry(
                    id: "bubble-\(point.time)-\(index)",
                    label: formatTime(point.time),
                    value: String(
                        format: LivelineStrings.accessibilityBubbleValueFormat,
                        formatValue(point.value),
                        formatValue(point.magnitude)
                    )
                )
            }

        case let .boxPlots(data, _):
            entries = data.enumerated().map { index, point in
                LivelineAccessibilityEntry(
                    id: "box-\(point.time)-\(index)",
                    label: formatTime(point.time),
                    value: [
                        String(format: LivelineStrings.accessibilityBoxMinimumFormat, formatValue(point.minimum)),
                        String(format: LivelineStrings.accessibilityBoxLowerQuartileFormat, formatValue(point.lowerQuartile)),
                        String(format: LivelineStrings.accessibilityBoxMedianFormat, formatValue(point.median)),
                        String(format: LivelineStrings.accessibilityBoxUpperQuartileFormat, formatValue(point.upperQuartile)),
                        String(format: LivelineStrings.accessibilityBoxMaximumFormat, formatValue(point.maximum)),
                    ].joined(separator: ", ")
                )
            }

        case let .waterfall(data, style):
            entries = LivelineMath.waterfallSegments(points: data, initialValue: style.resolvedInitialValue)
                .enumerated()
                .map { index, segment in
                    LivelineAccessibilityEntry(
                        id: "waterfall-\(segment.time)-\(index)",
                        label: formatTime(segment.time),
                        value: String(
                            format: LivelineStrings.accessibilityWaterfallValueFormat,
                            formatValue(segment.delta),
                            formatValue(segment.end)
                        )
                    )
                }

        case let .errorBars(data, _):
            entries = data.enumerated().map { index, point in
                LivelineAccessibilityEntry(
                    id: "error-\(point.time)-\(index)",
                    label: formatTime(point.time),
                    value: String(
                        format: LivelineStrings.accessibilityErrorBarValueFormat,
                        formatValue(point.value),
                        formatValue(point.lower),
                        formatValue(point.upper)
                    )
                )
            }

        case let .dumbbells(data, _):
            entries = data.enumerated().map { index, point in
                LivelineAccessibilityEntry(
                    id: "dumbbell-\(point.time)-\(index)",
                    label: formatTime(point.time),
                    value: String(
                        format: LivelineStrings.accessibilityDumbbellValueFormat,
                        formatValue(point.start),
                        formatValue(point.end)
                    )
                )
            }

        case let .stackedBars(data, style):
            entries = stackedEntries(data, mode: style.mode)

        case let .stackedAreas(data, style):
            entries = stackedEntries(data, mode: style.mode)

        case let .timeline(data, _):
            entries = data.map { item in
                LivelineAccessibilityEntry(
                    id: item.id,
                    label: item.label,
                    value: String(
                        format: LivelineStrings.accessibilityTimelineValueFormat,
                        formatTime(item.start),
                        formatTime(item.end),
                        formatValue(item.end - item.start)
                    )
                )
            }

        case let .heatmap(data, style):
            entries = data.enumerated().map { index, cell in
                let row = style.rowLabels.indices.contains(cell.row)
                    ? style.rowLabels[cell.row]
                    : String(format: LivelineStrings.labelRowFormat, cell.row + 1)
                return LivelineAccessibilityEntry(
                    id: "heatmap-\(cell.id)-\(index)",
                    label: String(format: LivelineStrings.accessibilityHeatmapLabelFormat, row, formatTime(cell.time)),
                    value: formatValue(cell.value)
                )
            }

        case let .radar(data, _):
            entries = (data.count >= 3 ? data : []).enumerated().map { index, point in
                LivelineAccessibilityEntry(
                    id: "radar-\(point.id)-\(index)",
                    label: point.label,
                    value: formatValue(point.value)
                )
            }

        case let .donut(data, _):
            let positive = data.filter { $0.value > 0 }
            let total = positive.reduce(0) { $0 + $1.value }
            entries = positive.enumerated().map { index, entry in
                let share = entry.value / total * 100
                return LivelineAccessibilityEntry(
                    id: "donut-\(entry.id)-\(index)",
                    label: entry.label,
                    value: String(
                        format: LivelineStrings.accessibilityDonutValueFormat,
                        formatValue(entry.value),
                        share.formatted(.number.precision(.fractionLength(1)))
                    )
                )
            }

        case let .gauge(value, range, style):
            var valueDescription = formatValue(value)
            if let target = style.resolvedTarget {
                valueDescription = String(
                    format: LivelineStrings.accessibilityGaugeTargetFormat,
                    valueDescription,
                    formatValue(target)
                )
            }
            entries = [
                LivelineAccessibilityEntry(
                    id: "gauge",
                    label: LivelineStrings.labelGaugeValue,
                    value: String(
                        format: LivelineStrings.accessibilityGaugeValueFormat,
                        valueDescription,
                        formatValue(range.lowerBound),
                        formatValue(range.upperBound)
                    )
                ),
            ]

        case let .funnel(data, _):
            entries = data.filter { $0.value > 0 }.enumerated().map { index, entry in
                LivelineAccessibilityEntry(
                    id: "funnel-\(entry.id)-\(index)",
                    label: entry.label,
                    value: formatValue(entry.value)
                )
            }

        case let .histogram(values, style):
            entries = LivelineMath.histogramBins(values: values, binning: style.binning)
                .enumerated()
                .map { index, bin in
                    LivelineAccessibilityEntry(
                        id: "histogram-\(index)-\(bin.lowerBound)",
                        label: String(
                            format: LivelineStrings.labelBinRangeFormat,
                            formatValue(bin.lowerBound),
                            formatValue(bin.upperBound)
                        ),
                        value: String(format: LivelineStrings.labelSampleCountFormat, bin.count)
                    )
                }

        case let .bullet(style):
            entries = [
                LivelineAccessibilityEntry(
                    id: "bullet-measure",
                    label: style.label ?? LivelineStrings.labelMeasure,
                    value: bulletSummary(style: style, formatValue: formatValue)
                ),
            ] + style.resolvedRanges.enumerated().map { index, range in
                LivelineAccessibilityEntry(
                    id: "bullet-band-\(index)-\(range.value)",
                    label: range.label ?? String(format: LivelineStrings.labelBandFormat, index + 1),
                    value: String(
                        format: LivelineStrings.accessibilityBulletBandValueFormat,
                        formatValue(range.value)
                    )
                )
            }

        case let .treemap(nodes, _):
            let cells = treemapCells(nodes)
            let total = cells.reduce(0) { $0 + $1.value }
            entries = cells.enumerated().map { index, cell in
                LivelineAccessibilityEntry(
                    id: "treemap-\(cell.id)-\(index)",
                    label: cell.label,
                    value: shareDescription(cell.value, total: total, formatValue: formatValue)
                )
            }

        case let .sunburst(nodes, _):
            let cells = sunburstCells(nodes)
            let total = nodes.reduce(0) { $0 + $1.resolvedValue }
            entries = cells.enumerated().map { index, cell in
                LivelineAccessibilityEntry(
                    id: "sunburst-\(cell.id)-\(index)",
                    label: cell.label,
                    value: shareDescription(cell.value, total: total, formatValue: formatValue)
                )
            }

        case let .sankey(links, _):
            let graph = LivelineMath.sankeyGraph(links: links)
            entries = graph.links.enumerated().map { index, link in
                LivelineAccessibilityEntry(
                    id: "sankey-\(link.linkIndex)-\(index)",
                    label: String(
                        format: LivelineStrings.labelFlowRouteFormat,
                        graph.nodes[link.sourceIndex].label,
                        graph.nodes[link.targetIndex].label
                    ),
                    value: formatValue(link.value)
                )
            }

        case let .candle(data, _, candles, _, liveCandle, lineData, _):
            if configuration.lineMode, !lineData.isEmpty {
                entries = pointEntries(lineData)
            } else if !candles.isEmpty || liveCandle != nil {
                var values = candles
                if let liveCandle {
                    if let index = values.firstIndex(where: { $0.time == liveCandle.time }) {
                        values[index] = liveCandle
                    } else {
                        values.append(liveCandle)
                    }
                }
                entries = values.sorted { $0.time < $1.time }.enumerated().map { index, candle in
                    LivelineAccessibilityEntry(
                        id: "candle-\(candle.time)-\(index)",
                        label: formatTime(candle.time),
                        value: String(
                            format: LivelineStrings.accessibilityCandleValueFormat,
                            formatValue(candle.open),
                            formatValue(candle.high),
                            formatValue(candle.low),
                            formatValue(candle.close)
                        )
                    )
                }
            } else {
                entries = pointEntries(data)
            }

        case let .series(series):
            entries = series
                .filter { !hiddenSeries.contains($0.id) && $0.livelineIsRenderable }
                .flatMap { entry in
                    pointEntries(entry.data, prefix: entry.label ?? entry.id)
                }

        case nil:
            entries = []
        }

        let summary: String
        if entryCount == 0 {
            summary = configuration.emptyText
        } else {
            let format: String
            switch semantics.momentum {
            case .up:
                format = LivelineStrings.accessibilityCurrentValueUpFormat
            case .down:
                format = LivelineStrings.accessibilityCurrentValueDownFormat
            case .flat:
                format = LivelineStrings.accessibilityCurrentValueFormat
            }
            summary = String(format: format, formatValue(semantics.currentValue))
        }

        return LivelineChartAccessibilityModel(
            label: semantics.identity.kind.accessibilityLabel,
            summary: summary,
            entries: entries,
            entryCount: entryCount
        )
    }

    /// "72 of target 80, in 'good' range" — the one phrase a bullet chart is
    /// read for, assembled from whichever of the three parts the caller gave.
    static func bulletSummary(
        style: LivelineBulletStyle,
        formatValue: (Double) -> String
    ) -> String {
        var summary = formatValue(style.resolvedMeasure)
        if let target = style.resolvedTarget {
            summary = String(
                format: LivelineStrings.accessibilityBulletTargetFormat,
                summary,
                formatValue(target)
            )
        }
        if let band = style.containingRange, let label = band.label, !label.isEmpty {
            summary = String(
                format: LivelineStrings.accessibilityBulletRangeFormat,
                summary,
                label
            )
        }
        return summary
    }

    /// The drawn cells of a treemap: a node's children when it has any, the
    /// node itself otherwise, with zero-weight entries dropped exactly as the
    /// layout drops them.
    static func treemapCells(_ nodes: [LivelineTreemapNode]) -> [(id: String, label: String, value: Double)] {
        nodes.flatMap { node -> [(id: String, label: String, value: Double)] in
            guard node.children.isEmpty else {
                return node.children
                    .filter { $0.resolvedValue > 0 }
                    .map { (id: "\(node.id)-\($0.id)", label: $0.label, value: $0.resolvedValue) }
            }
            guard node.resolvedValue > 0 else { return [] }
            return [(id: node.id, label: node.label, value: node.resolvedValue)]
        }
    }

    /// Both rings of a sunburst, outer ring immediately after the parent it
    /// subdivides, which is the order a VoiceOver reader swipes through.
    static func sunburstCells(_ nodes: [LivelineSunburstNode]) -> [(id: String, label: String, value: Double)] {
        nodes.flatMap { node -> [(id: String, label: String, value: Double)] in
            guard node.resolvedValue > 0 else { return [] }
            return [(id: node.id, label: node.label, value: node.resolvedValue)]
                + node.children
                    .filter { $0.resolvedValue > 0 }
                    .map { (id: "\(node.id)-\($0.id)", label: $0.label, value: $0.resolvedValue) }
        }
    }

    /// "12, 30.0 percent" — the value alongside its share of the whole, the
    /// same phrasing a donut segment is read with.
    static func shareDescription(
        _ value: Double,
        total: Double,
        formatValue: (Double) -> String
    ) -> String {
        guard total > 0 else { return formatValue(value) }
        return String(
            format: LivelineStrings.accessibilityDonutValueFormat,
            formatValue(value),
            (value / total * 100).formatted(.number.precision(.fractionLength(1)))
        )
    }

    private static func accessibleEntryCount(
        content: LivelineChartContent,
        configuration: LivelineChartConfiguration,
        hiddenSeries: Set<String>
    ) -> Int {
        switch content {
        case let .line(data, _),
             let .bars(data, _),
             let .scatter(data, _, _),
             let .steps(data, _, _),
             let .lollipops(data, _):
            return data.count
        case let .range(data, _):
            return data.count
        case let .bubbles(data, _):
            return data.count
        case let .boxPlots(data, _):
            return data.count
        case let .waterfall(data, _):
            return data.count
        case let .errorBars(data, _):
            return data.count
        case let .dumbbells(data, _):
            return data.count
        case let .stackedBars(data, _), let .stackedAreas(data, _):
            return data.count
        case let .timeline(data, _):
            return data.count
        case let .heatmap(data, _):
            return data.count
        case let .radar(data, _):
            return data.count >= 3 ? data.count : 0
        case let .donut(data, _), let .funnel(data, _):
            return data.reduce(into: 0) { count, entry in
                if entry.value > 0 { count += 1 }
            }
        case .gauge:
            return 1
        case let .histogram(values, style):
            return LivelineMath.histogramBins(values: values, binning: style.binning).count
        case let .bullet(style):
            return 1 + style.resolvedRanges.count
        case let .treemap(nodes, _):
            return treemapCells(nodes).count
        case let .sunburst(nodes, _):
            return sunburstCells(nodes).count
        case let .sankey(links, _):
            return LivelineMath.sankeyGraph(links: links).links.count
        case let .candle(data, _, candles, _, liveCandle, lineData, _):
            if configuration.lineMode, !lineData.isEmpty {
                return lineData.count
            }
            if !candles.isEmpty || liveCandle != nil {
                guard let liveCandle else { return candles.count }
                return candles.contains(where: { $0.time == liveCandle.time })
                    ? candles.count
                    : candles.count + 1
            }
            return data.count
        case let .series(series):
            return series.reduce(into: 0) { count, entry in
                if !hiddenSeries.contains(entry.id), entry.livelineIsRenderable {
                    count += entry.data.count
                }
            }
        }
    }
}

/// Identity of everything `LivelineChartAccessibilityModel.make` reads. Hover
/// lives in view state, so the body re-evaluates on every pointer move: a
/// matching key means the previous model is still correct and the dataset does
/// not have to be reformatted. Formatters are closures and cannot be compared,
/// so they are represented by what they produce for a fixed probe.
struct LivelineAccessibilityModelKey: Equatable {
    var kind: LivelineChartKind
    var shapes: [LivelineDataShape]
    var identifiers: [String]
    var variants: [Double]
    var hiddenSeries: Set<String>
    var includeEntries: Bool
    var loading: Bool
    var lineMode: Bool
    var emptyText: String
    var currentValue: Double
    var momentum: LivelineMomentum
    var formatterProbe: [String]

    static func make(
        content: LivelineChartContent,
        semantics: LivelineChartSemantics,
        configuration: LivelineChartConfiguration,
        hiddenSeries: Set<String>,
        includeEntries: Bool
    ) -> LivelineAccessibilityModelKey {
        var shapes: [LivelineDataShape] = []
        var identifiers: [String] = []
        var variants: [Double] = []

        switch content {
        case let .line(data, value):
            shapes = [data.livelineShape(lastValue: data.last?.value ?? 0)]
            variants = [value]

        case let .bars(data, _), let .lollipops(data, _):
            shapes = [data.livelineShape(lastValue: data.last?.value ?? 0)]

        case let .range(data, _):
            shapes = [data.livelineShape(lastValue: data.last?.upper ?? 0)]

        case let .scatter(data, value, _), let .steps(data, value, _):
            shapes = [data.livelineShape(lastValue: data.last?.value ?? 0)]
            variants = [value]

        case let .bubbles(data, _):
            shapes = [data.livelineShape(lastValue: data.last?.magnitude ?? 0)]

        case let .boxPlots(data, _):
            shapes = [data.livelineShape(lastValue: data.last?.median ?? 0)]

        case let .waterfall(data, style):
            shapes = [data.livelineShape(lastValue: data.last?.value ?? 0)]
            variants = [style.resolvedInitialValue]

        case let .errorBars(data, _):
            shapes = [data.livelineShape(lastValue: data.last?.upper ?? 0)]

        case let .dumbbells(data, _):
            shapes = [data.livelineShape(lastValue: data.last?.end ?? 0)]

        case let .stackedBars(data, style):
            shapes = [data.livelineShape(lastValue: LivelineMath.stackedPrimaryValue(point: data.last, mode: style.mode))]
            identifiers = [style.mode.rawValue]

        case let .stackedAreas(data, style):
            shapes = [data.livelineShape(lastValue: LivelineMath.stackedPrimaryValue(point: data.last, mode: style.mode))]
            identifiers = [style.mode.rawValue, style.baseline.rawValue]

        case let .timeline(data, _):
            shapes = [untimedShape(data, lastValue: data.last?.end ?? 0)]
            identifiers = [data.last?.label ?? ""]

        case let .heatmap(data, style):
            shapes = [data.livelineShape(lastValue: data.last?.value ?? 0)]
            identifiers = style.rowLabels

        case let .radar(data, _):
            shapes = [untimedShape(data, lastValue: data.last?.value ?? 0)]

        case let .donut(data, _), let .funnel(data, _):
            shapes = [untimedShape(data, lastValue: data.last?.value ?? 0)]

        case let .gauge(value, range, style):
            variants = [value, range.lowerBound, range.upperBound, style.resolvedTarget ?? .infinity]

        case let .histogram(values, style):
            shapes = [untimedShape(values, lastValue: values.last ?? 0)]
            identifiers = [style.binning.cacheIdentifier]

        case let .bullet(style):
            let range = style.resolvedAxisRange
            variants = [
                style.resolvedMeasure,
                style.resolvedTarget ?? .infinity,
                range.lowerBound,
                range.upperBound,
            ] + style.resolvedRanges.map(\.value)
            identifiers = [style.label ?? ""] + style.resolvedRanges.map { $0.label ?? "" }

        case let .treemap(nodes, style):
            variants = nodes.map(\.resolvedValue)
            identifiers = nodes.map(\.label) + nodes.flatMap { $0.children.map(\.label) }
                + ["\(style.showsValues)"]

        case let .sunburst(nodes, style):
            variants = nodes.map(\.resolvedValue)
            identifiers = nodes.map(\.label) + nodes.flatMap { $0.children.map(\.label) }
                + ["\(style.showsValues)"]

        case let .sankey(links, _):
            variants = links.map(\.value)
            identifiers = links.flatMap { [$0.source, $0.target] }

        case let .candle(data, value, candles, candleWidth, liveCandle, lineData, lineValue):
            shapes = [
                data.livelineShape(lastValue: data.last?.value ?? 0),
                candles.livelineShape(lastValue: candles.last?.close ?? 0),
                lineData.livelineShape(lastValue: lineData.last?.value ?? 0),
            ]
            variants = [
                value,
                candleWidth,
                lineValue ?? .infinity,
                liveCandle?.time ?? .infinity,
                liveCandle?.open ?? .infinity,
                liveCandle?.high ?? .infinity,
                liveCandle?.low ?? .infinity,
                liveCandle?.close ?? .infinity,
            ]

        case let .series(series):
            shapes = series.map { $0.data.livelineShape(lastValue: $0.value) }
            identifiers = series.flatMap { [$0.id, $0.label ?? ""] }
        }

        return LivelineAccessibilityModelKey(
            kind: semantics.identity.kind,
            shapes: shapes,
            identifiers: identifiers,
            variants: variants,
            hiddenSeries: hiddenSeries,
            includeEntries: includeEntries,
            loading: configuration.loading,
            lineMode: configuration.lineMode,
            emptyText: configuration.emptyText,
            currentValue: semantics.currentValue,
            momentum: semantics.momentum,
            formatterProbe: [
                configuration.formatValue(0),
                configuration.formatValue(1234.5678),
                configuration.formatValue(-9876.54321),
                configuration.formatTime(0),
                configuration.formatTime(1_700_000_000),
            ]
        )
    }

    private static func untimedShape<Element>(_ array: [Element], lastValue: Double) -> LivelineDataShape {
        LivelineDataShape(
            storage: array.livelineStorageIdentity,
            count: array.count,
            firstTime: 0,
            lastTime: 0,
            lastValue: lastValue
        )
    }
}

private extension LivelineChartKind {
    var accessibilityLabel: String {
        switch self {
        case .line: return LivelineStrings.chartKindLine
        case .bars: return LivelineStrings.chartKindBars
        case .range: return LivelineStrings.chartKindRange
        case .scatter: return LivelineStrings.chartKindScatter
        case .steps: return LivelineStrings.chartKindSteps
        case .lollipops: return LivelineStrings.chartKindLollipops
        case .bubbles: return LivelineStrings.chartKindBubbles
        case .boxPlots: return LivelineStrings.chartKindBoxPlots
        case .waterfall: return LivelineStrings.chartKindWaterfall
        case .errorBars: return LivelineStrings.chartKindErrorBars
        case .dumbbells: return LivelineStrings.chartKindDumbbells
        case .stackedBars: return LivelineStrings.chartKindStackedBars
        case .stackedAreas: return LivelineStrings.chartKindStackedAreas
        case .timeline: return LivelineStrings.chartKindTimeline
        case .heatmap: return LivelineStrings.chartKindHeatmap
        case .radar: return LivelineStrings.chartKindRadar
        case .donut: return LivelineStrings.chartKindDonut
        case .gauge: return LivelineStrings.chartKindGauge
        case .funnel: return LivelineStrings.chartKindFunnel
        case .histogram: return LivelineStrings.chartKindHistogram
        case .bullet: return LivelineStrings.chartKindBullet
        case .treemap: return LivelineStrings.chartKindTreemap
        case .sunburst: return LivelineStrings.chartKindSunburst
        case .sankey: return LivelineStrings.chartKindSankey
        case .candle: return LivelineStrings.chartKindCandle
        case .series: return LivelineStrings.chartKindSeries
        }
    }
}
