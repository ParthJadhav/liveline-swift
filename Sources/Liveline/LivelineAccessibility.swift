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
            return "Chart data is loading."
        }
        return entryCount == 0
            ? "No chart data is available."
            : "Adjust to inspect data points."
    }

    func value(at index: Int?) -> String {
        guard let index, entries.indices.contains(index) else {
            guard entryCount > 0 else { return summary }
            let count = entryCount == 1 ? "1 data point" : "\(entryCount) data points"
            return "\(summary). \(count)"
        }
        let entry = entries[index]
        return "\(entry.label), \(entry.value), \(index + 1) of \(entryCount)"
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
                summary: "Loading chart data",
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
                    .map { "Series \($0.offset + 1) \(formatValue($0.element))" }
                    .joined(separator: ", ")
                return LivelineAccessibilityEntry(
                    id: "stack-\(point.time)-\(index)",
                    label: formatTime(point.time),
                    value: "\(values), total \(formatValue(signedValues.reduce(0, +)))"
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
                    value: "Lower \(formatValue(point.lower)), upper \(formatValue(point.upper))"
                )
            }

        case let .bubbles(data, _):
            entries = data.enumerated().map { index, point in
                LivelineAccessibilityEntry(
                    id: "bubble-\(point.time)-\(index)",
                    label: formatTime(point.time),
                    value: "Value \(formatValue(point.value)), magnitude \(formatValue(point.magnitude))"
                )
            }

        case let .boxPlots(data, _):
            entries = data.enumerated().map { index, point in
                LivelineAccessibilityEntry(
                    id: "box-\(point.time)-\(index)",
                    label: formatTime(point.time),
                    value: [
                        "Minimum \(formatValue(point.minimum))",
                        "first quartile \(formatValue(point.lowerQuartile))",
                        "median \(formatValue(point.median))",
                        "third quartile \(formatValue(point.upperQuartile))",
                        "maximum \(formatValue(point.maximum))",
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
                        value: "Change \(formatValue(segment.delta)), total \(formatValue(segment.end))"
                    )
                }

        case let .errorBars(data, _):
            entries = data.enumerated().map { index, point in
                LivelineAccessibilityEntry(
                    id: "error-\(point.time)-\(index)",
                    label: formatTime(point.time),
                    value: "Value \(formatValue(point.value)), lower \(formatValue(point.lower)), upper \(formatValue(point.upper))"
                )
            }

        case let .dumbbells(data, _):
            entries = data.enumerated().map { index, point in
                LivelineAccessibilityEntry(
                    id: "dumbbell-\(point.time)-\(index)",
                    label: formatTime(point.time),
                    value: "Start \(formatValue(point.start)), end \(formatValue(point.end))"
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
                    value: "Start \(formatTime(item.start)), end \(formatTime(item.end)), duration \(formatValue(item.end - item.start))"
                )
            }

        case let .heatmap(data, style):
            entries = data.enumerated().map { index, cell in
                let row = style.rowLabels.indices.contains(cell.row)
                    ? style.rowLabels[cell.row]
                    : "Row \(cell.row + 1)"
                return LivelineAccessibilityEntry(
                    id: "heatmap-\(cell.id)-\(index)",
                    label: "\(row), \(formatTime(cell.time))",
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
                    value: "\(formatValue(entry.value)), \(share.formatted(.number.precision(.fractionLength(1)))) percent"
                )
            }

        case let .gauge(value, range, style):
            var valueDescription = formatValue(value)
            if let target = style.resolvedTarget {
                valueDescription += ", target \(formatValue(target))"
            }
            entries = [
                LivelineAccessibilityEntry(
                    id: "gauge",
                    label: "Gauge value",
                    value: "\(valueDescription), range \(formatValue(range.lowerBound)) to \(formatValue(range.upperBound))"
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
                        value: "Open \(formatValue(candle.open)), high \(formatValue(candle.high)), low \(formatValue(candle.low)), close \(formatValue(candle.close))"
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
            let momentum: String
            switch semantics.momentum {
            case .up:
                momentum = ", trending up"
            case .down:
                momentum = ", trending down"
            case .flat:
                momentum = ""
            }
            summary = "Current value \(formatValue(semantics.currentValue))\(momentum)"
        }

        return LivelineChartAccessibilityModel(
            label: semantics.identity.kind.accessibilityLabel,
            summary: summary,
            entries: entries,
            entryCount: entryCount
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
            identifiers = [style.mode.rawValue]

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
        case .line: return "Line chart"
        case .bars: return "Bar chart"
        case .range: return "Range chart"
        case .scatter: return "Scatter chart"
        case .steps: return "Step chart"
        case .lollipops: return "Lollipop chart"
        case .bubbles: return "Bubble chart"
        case .boxPlots: return "Box plot chart"
        case .waterfall: return "Waterfall chart"
        case .errorBars: return "Error bar chart"
        case .dumbbells: return "Dumbbell chart"
        case .stackedBars: return "Stacked bar chart"
        case .stackedAreas: return "Stacked area chart"
        case .timeline: return "Timeline chart"
        case .heatmap: return "Heatmap chart"
        case .radar: return "Radar chart"
        case .donut: return "Donut chart"
        case .gauge: return "Gauge chart"
        case .funnel: return "Funnel chart"
        case .candle: return "Candlestick chart"
        case .series: return "Multi-series chart"
        }
    }
}
