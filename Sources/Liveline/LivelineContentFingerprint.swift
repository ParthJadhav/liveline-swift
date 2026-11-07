import Foundation

/// Cheap stand-in for an array's contents: the backing buffer plus where its
/// endpoints sit (their times, for timed samples) and the last value. Matching
/// shapes mean the elements are the same array, without walking them.
struct LivelineDataShape: Equatable {
    var storage: UInt
    var count: Int
    var first: Double
    var last: Double
    var lastValue: Double

    init<Element>(
        _ array: [Element],
        first: Double = 0,
        last: Double = 0,
        lastValue: Double = 0
    ) {
        storage = array.livelineStorageIdentity
        count = array.count
        self.first = first
        self.last = last
        self.lastValue = lastValue
    }
}

extension Array where Element: LivelineTimedDatum {
    func livelineShape(lastValue: Double = 0) -> LivelineDataShape {
        LivelineDataShape(self, first: first?.time ?? 0, last: last?.time ?? 0, lastValue: lastValue)
    }
}

/// Identity of everything a chart's content holds that anything derived from
/// it can read: data, the values beside it, and the style fields that change
/// what is derived. Equal fingerprints mean derived results can be reused.
struct LivelineContentFingerprint: Equatable {
    var kind: LivelineChartKind
    var shapes: [LivelineDataShape] = []
    var identifiers: [String] = []
    var variants: [Double] = []
}

extension LivelineChartContent {
    var fingerprint: LivelineContentFingerprint {
        switch self {
        case let .line(data, value):
            return .init(kind: .line, shapes: [data.livelineShape(lastValue: data.last?.value ?? 0)], variants: [value])

        case let .bars(data, style):
            return .init(kind: .bars, shapes: [data.livelineShape(lastValue: data.last?.value ?? 0)], variants: [style.resolvedBaseline])

        case let .range(data, _):
            return .init(
                kind: .range,
                shapes: [data.livelineShape(lastValue: data.last?.upper ?? 0)],
                variants: [data.last?.lower ?? 0]
            )

        case let .scatter(data, value, _):
            return .init(kind: .scatter, shapes: [data.livelineShape(lastValue: data.last?.value ?? 0)], variants: [value])

        case let .steps(data, value, _):
            return .init(kind: .steps, shapes: [data.livelineShape(lastValue: data.last?.value ?? 0)], variants: [value])

        case let .lollipops(data, style):
            return .init(kind: .lollipops, shapes: [data.livelineShape(lastValue: data.last?.value ?? 0)], variants: [style.resolvedBaseline])

        case let .bubbles(data, _):
            return .init(
                kind: .bubbles,
                shapes: [data.livelineShape(lastValue: data.last?.value ?? 0)],
                variants: [data.last?.magnitude ?? 0]
            )

        case let .boxPlots(data, _):
            return .init(kind: .boxPlots, shapes: [data.livelineShape(lastValue: data.last?.median ?? 0)])

        case let .waterfall(data, style):
            return .init(kind: .waterfall, shapes: [data.livelineShape(lastValue: data.last?.value ?? 0)], variants: [style.resolvedInitialValue])

        case let .errorBars(data, _):
            return .init(
                kind: .errorBars,
                shapes: [data.livelineShape(lastValue: data.last?.upper ?? 0)],
                variants: [data.last?.value ?? 0]
            )

        case let .dumbbells(data, _):
            return .init(kind: .dumbbells, shapes: [data.livelineShape(lastValue: data.last?.end ?? 0)])

        case let .stackedBars(data, style):
            return .init(
                kind: .stackedBars,
                shapes: [data.livelineShape(lastValue: LivelineMath.stackedPrimaryValue(point: data.last, mode: style.mode))],
                identifiers: [style.mode.rawValue]
            )

        case let .stackedAreas(data, style):
            return .init(
                kind: .stackedAreas,
                shapes: [data.livelineShape(lastValue: LivelineMath.stackedPrimaryValue(point: data.last, mode: style.mode))],
                identifiers: [style.mode.rawValue, style.baseline.rawValue]
            )

        case let .timeline(data, _):
            return .init(
                kind: .timeline,
                shapes: [LivelineDataShape(data, first: data.first?.start ?? 0, last: data.last?.end ?? 0)],
                identifiers: [data.last?.label ?? ""]
            )

        case let .heatmap(data, style):
            return .init(kind: .heatmap, shapes: [data.livelineShape(lastValue: data.last?.value ?? 0)], identifiers: style.rowLabels)

        case let .radar(data, style):
            let range = style.resolvedRange
            return .init(
                kind: .radar,
                shapes: [LivelineDataShape(data, lastValue: data.last?.value ?? 0)],
                variants: [range.lowerBound, range.upperBound]
            )

        case let .donut(data, _):
            return .init(kind: .donut, shapes: [LivelineDataShape(data, lastValue: data.last?.value ?? 0)])

        case let .funnel(data, _):
            return .init(kind: .funnel, shapes: [LivelineDataShape(data, lastValue: data.last?.value ?? 0)])

        case let .gauge(value, range, style):
            return .init(kind: .gauge, variants: [value, range.lowerBound, range.upperBound, style.resolvedTarget ?? .infinity])

        case let .histogram(values, style):
            return .init(
                kind: .histogram,
                shapes: [LivelineDataShape(values, first: values.first ?? 0, last: values.last ?? 0)],
                identifiers: [style.binning.cacheIdentifier]
            )

        case let .bullet(style):
            let range = style.resolvedAxisRange
            return .init(
                kind: .bullet,
                identifiers: [style.label ?? ""] + style.resolvedRanges.map { $0.label ?? "" },
                variants: [
                    style.resolvedMeasure,
                    style.resolvedTarget ?? .infinity,
                    range.lowerBound,
                    range.upperBound,
                ] + style.resolvedRanges.map(\.value)
            )

        case let .treemap(nodes, style):
            return .init(
                kind: .treemap,
                identifiers: nodes.map(\.label) + nodes.flatMap { $0.children.map(\.label) } + ["\(style.showsValues)"],
                variants: nodes.map(\.resolvedValue)
            )

        case let .sunburst(nodes, style):
            return .init(
                kind: .sunburst,
                identifiers: nodes.map(\.label) + nodes.flatMap { $0.children.map(\.label) } + ["\(style.showsValues)"],
                variants: nodes.map(\.resolvedValue)
            )

        case let .sankey(links, _):
            return .init(
                kind: .sankey,
                identifiers: links.flatMap { [$0.source, $0.target] },
                variants: links.map(\.value)
            )

        case let .candle(data, value, candles, candleWidth, liveCandle, lineData, lineValue):
            return .init(
                kind: .candle,
                shapes: [
                    data.livelineShape(lastValue: data.last?.value ?? 0),
                    candles.livelineShape(lastValue: candles.last?.close ?? 0),
                    lineData.livelineShape(lastValue: lineData.last?.value ?? 0),
                ],
                variants: [
                    value,
                    candleWidth,
                    lineValue ?? .infinity,
                    liveCandle?.time ?? .infinity,
                    liveCandle?.open ?? .infinity,
                    liveCandle?.high ?? .infinity,
                    liveCandle?.low ?? .infinity,
                    liveCandle?.close ?? .infinity,
                ]
            )

        case let .series(series):
            return .init(
                kind: .series,
                shapes: series.map { $0.data.livelineShape(lastValue: $0.value) },
                identifiers: series.flatMap { [$0.id, $0.label ?? ""] }
            )
        }
    }
}
