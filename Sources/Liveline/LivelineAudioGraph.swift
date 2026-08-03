import Foundation
import SwiftUI

#if canImport(Accessibility)
import Accessibility
#endif

/// A single sonifiable sample. `x` is either a moment on the time axis or a
/// category name, matching the two axis kinds `AXChartDescriptor` supports.
struct LivelineAudioGraphPoint: Equatable {
    var time: TimeInterval?
    var category: String?
    var value: Double
}

struct LivelineAudioGraphSeries: Equatable {
    var name: String
    /// Line-like content is continuous; discrete marks (bars, scatter, box
    /// plots) are not, and VoiceOver sonifies the two differently.
    var isContinuous: Bool
    var points: [LivelineAudioGraphPoint]
}

enum LivelineAudioGraphXAxis: Equatable {
    case time(ClosedRange<TimeInterval>)
    case categories([String])
}

/// The chart described for VoiceOver's Audio Graph, in plain numbers. Building
/// this is the whole cost of the feature, so `LivelineChartDescriptor` only
/// does it when VoiceOver actually asks for a descriptor.
struct LivelineAudioGraphModel: Equatable {
    var title: String
    var summary: String
    var xAxis: LivelineAudioGraphXAxis
    var valueRange: ClosedRange<Double>
    var series: [LivelineAudioGraphSeries]

    var isEmpty: Bool {
        series.allSatisfy(\.points.isEmpty)
    }

    static func make(
        content: LivelineChartContent,
        semantics: LivelineChartSemantics,
        configuration: LivelineChartConfiguration,
        hiddenSeries: Set<String>,
        activeWindow: TimeInterval,
        title: String,
        summary: String
    ) -> LivelineAudioGraphModel {
        // The chart only ever renders the trailing `activeWindow` of a
        // time-based dataset, so the descriptor must describe that same span.
        let visibleRange: ClosedRange<TimeInterval>?
        if let latest = semantics.latestTime, activeWindow.isFinite, activeWindow > 0 {
            visibleRange = (latest - activeWindow)...latest
        } else {
            visibleRange = nil
        }

        func timed(
            _ name: String,
            isContinuous: Bool,
            _ samples: [(TimeInterval, Double)]
        ) -> LivelineAudioGraphSeries {
            let points = samples
                .filter { sample in
                    guard let visibleRange else { return sample.1.isFinite }
                    return sample.1.isFinite && visibleRange.contains(sample.0)
                }
                .map { LivelineAudioGraphPoint(time: $0.0, category: nil, value: $0.1) }
            return LivelineAudioGraphSeries(name: name, isContinuous: isContinuous, points: points)
        }

        func categorical(
            _ name: String,
            isContinuous: Bool,
            _ samples: [(String, Double)]
        ) -> LivelineAudioGraphSeries {
            LivelineAudioGraphSeries(
                name: name,
                isContinuous: isContinuous,
                points: samples
                    .filter { $0.1.isFinite }
                    .map { LivelineAudioGraphPoint(time: nil, category: $0.0, value: $0.1) }
            )
        }

        var series: [LivelineAudioGraphSeries] = []
        var isCategorical = false
        var categoryOrder: [String] = []
        var explicitValueRange: ClosedRange<Double>?

        switch content {
        case let .line(data, _):
            series = [timed(LivelineStrings.labelValue, isContinuous: true, data.map { ($0.time, $0.value) })]

        case let .steps(data, _, _):
            series = [timed(LivelineStrings.labelValue, isContinuous: true, data.map { ($0.time, $0.value) })]

        case let .bars(data, _), let .lollipops(data, _):
            series = [timed(LivelineStrings.labelValue, isContinuous: false, data.map { ($0.time, $0.value) })]

        case let .scatter(data, _, _):
            series = [timed(LivelineStrings.labelValue, isContinuous: false, data.map { ($0.time, $0.value) })]

        case let .range(data, _):
            series = [
                timed(LivelineStrings.labelLower, isContinuous: true, data.map { ($0.time, $0.lower) }),
                timed(LivelineStrings.labelUpper, isContinuous: true, data.map { ($0.time, $0.upper) }),
            ]

        case let .bubbles(data, _):
            series = [
                timed(LivelineStrings.labelValue, isContinuous: false, data.map { ($0.time, $0.value) }),
                timed(LivelineStrings.labelMagnitude, isContinuous: false, data.map { ($0.time, $0.magnitude) }),
            ]

        case let .boxPlots(data, _):
            series = [
                timed(LivelineStrings.labelMedian, isContinuous: false, data.map { ($0.time, $0.median) }),
                timed(LivelineStrings.labelMinimum, isContinuous: false, data.map { ($0.time, $0.minimum) }),
                timed(LivelineStrings.labelFirstQuartile, isContinuous: false, data.map { ($0.time, $0.lowerQuartile) }),
                timed(LivelineStrings.labelThirdQuartile, isContinuous: false, data.map { ($0.time, $0.upperQuartile) }),
                timed(LivelineStrings.labelMaximum, isContinuous: false, data.map { ($0.time, $0.maximum) }),
            ]

        case let .waterfall(data, style):
            let segments = LivelineMath.waterfallSegments(
                points: data,
                initialValue: style.resolvedInitialValue
            )
            series = [timed(LivelineStrings.labelTotal, isContinuous: false, segments.map { ($0.time, $0.end) })]

        case let .errorBars(data, _):
            series = [
                timed(LivelineStrings.labelValue, isContinuous: false, data.map { ($0.time, $0.value) }),
                timed(LivelineStrings.labelLower, isContinuous: false, data.map { ($0.time, $0.lower) }),
                timed(LivelineStrings.labelUpper, isContinuous: false, data.map { ($0.time, $0.upper) }),
            ]

        case let .dumbbells(data, _):
            series = [
                timed(LivelineStrings.labelStart, isContinuous: false, data.map { ($0.time, $0.start) }),
                timed(LivelineStrings.labelEnd, isContinuous: false, data.map { ($0.time, $0.end) }),
            ]

        case let .stackedBars(data, style):
            series = stackedSeries(data, mode: style.mode, isContinuous: false, timed: timed)

        case let .stackedAreas(data, style):
            // Sonification reports each layer's own magnitude, which the
            // baseline offset never changes.
            series = stackedSeries(data, mode: style.mode, isContinuous: true, timed: timed)

        case let .timeline(data, _):
            series = [
                timed(
                    LivelineStrings.labelDuration,
                    isContinuous: false,
                    data.map { ($0.start, $0.end - $0.start) }
                ),
            ]

        case let .heatmap(data, style):
            let rowCount = max((data.map(\.row).max() ?? -1) + 1, style.rowLabels.count)
            series = (0..<max(rowCount, 0)).map { row in
                let name = style.rowLabels.indices.contains(row)
                    ? style.rowLabels[row]
                    : String(format: LivelineStrings.labelRowFormat, row + 1)
                return timed(
                    name,
                    isContinuous: false,
                    data.filter { $0.row == row }.map { ($0.time, $0.value) }
                )
            }

        case let .radar(data, _):
            let points = data.count >= 3 ? data : []
            isCategorical = true
            categoryOrder = points.map(\.label)
            series = [categorical(LivelineStrings.labelValue, isContinuous: false, points.map { ($0.label, $0.value) })]

        case let .donut(data, _), let .funnel(data, _):
            let positive = data.filter { $0.value > 0 }
            isCategorical = true
            categoryOrder = positive.map(\.label)
            series = [categorical(LivelineStrings.labelValue, isContinuous: false, positive.map { ($0.label, $0.value) })]

        case let .gauge(value, range, _):
            isCategorical = true
            categoryOrder = [LivelineStrings.labelGaugeValue]
            // A degenerate configured range would sonify as a divide-by-zero;
            // fall back to the padded range the value itself produces.
            explicitValueRange = range.lowerBound < range.upperBound
                ? range.lowerBound...range.upperBound
                : nil
            series = [categorical(LivelineStrings.labelValue, isContinuous: false, [(LivelineStrings.labelGaugeValue, value)])]

        case let .histogram(values, style):
            let bins = LivelineMath.histogramBins(values: values, binning: style.binning)
            let names = bins.map { bin in
                String(
                    format: LivelineStrings.labelBinRangeFormat,
                    configuration.formatValue(bin.lowerBound),
                    configuration.formatValue(bin.upperBound)
                )
            }
            isCategorical = true
            categoryOrder = names
            series = [
                categorical(
                    LivelineStrings.labelCount,
                    isContinuous: false,
                    zip(names, bins).map { ($0, Double($1.count)) }
                ),
            ]

        case let .bullet(style):
            isCategorical = true
            var samples: [(String, Double)] = [(LivelineStrings.labelMeasure, style.resolvedMeasure)]
            if let target = style.resolvedTarget {
                samples.append((LivelineStrings.labelTarget, target))
            }
            for (index, range) in style.resolvedRanges.enumerated() {
                samples.append((
                    range.label ?? String(format: LivelineStrings.labelBandFormat, index + 1),
                    range.value
                ))
            }
            categoryOrder = samples.map(\.0)
            let axisRange = style.resolvedAxisRange
            explicitValueRange = axisRange.lowerBound < axisRange.upperBound ? axisRange : nil
            series = [categorical(LivelineStrings.labelValue, isContinuous: false, samples)]

        case let .treemap(nodes, _):
            let cells = LivelineChartAccessibilityModel.treemapCells(nodes)
            isCategorical = true
            categoryOrder = cells.map(\.label)
            series = [categorical(LivelineStrings.labelValue, isContinuous: false, cells.map { ($0.label, $0.value) })]

        case let .sunburst(nodes, _):
            let cells = LivelineChartAccessibilityModel.sunburstCells(nodes)
            isCategorical = true
            categoryOrder = cells.map(\.label)
            series = [categorical(LivelineStrings.labelValue, isContinuous: false, cells.map { ($0.label, $0.value) })]

        case let .sankey(links, _):
            // A flow diagram has no axis to sweep, but the link magnitudes do
            // rank meaningfully against each other, so they sonify as one
            // categorical series in the order the caller wrote them.
            let graph = LivelineMath.sankeyGraph(links: links)
            let samples = graph.links.map { link in
                (
                    String(
                        format: LivelineStrings.labelFlowRouteFormat,
                        graph.nodes[link.sourceIndex].label,
                        graph.nodes[link.targetIndex].label
                    ),
                    link.value
                )
            }
            isCategorical = true
            categoryOrder = samples.map(\.0)
            series = [categorical(LivelineStrings.labelFlow, isContinuous: false, samples)]

        case let .candle(data, _, candles, _, liveCandle, lineData, _):
            if configuration.lineMode, !lineData.isEmpty {
                series = [timed(LivelineStrings.labelPrice, isContinuous: true, lineData.map { ($0.time, $0.value) })]
            } else if !candles.isEmpty || liveCandle != nil {
                var values = candles
                if let liveCandle {
                    if let index = values.firstIndex(where: { $0.time == liveCandle.time }) {
                        values[index] = liveCandle
                    } else {
                        values.append(liveCandle)
                    }
                }
                values.sort { $0.time < $1.time }
                series = [
                    timed(LivelineStrings.labelClose, isContinuous: true, values.map { ($0.time, $0.close) }),
                    timed(LivelineStrings.labelOpen, isContinuous: false, values.map { ($0.time, $0.open) }),
                    timed(LivelineStrings.labelHigh, isContinuous: false, values.map { ($0.time, $0.high) }),
                    timed(LivelineStrings.labelLow, isContinuous: false, values.map { ($0.time, $0.low) }),
                ]
            } else {
                series = [timed(LivelineStrings.labelPrice, isContinuous: true, data.map { ($0.time, $0.value) })]
            }

        case let .series(entries):
            series = entries
                .filter { !hiddenSeries.contains($0.id) && $0.livelineIsRenderable }
                .map { entry in
                    timed(
                        entry.label ?? entry.id,
                        isContinuous: true,
                        entry.data.map { ($0.time, $0.value) }
                    )
                }
        }

        series.removeAll { $0.points.isEmpty }

        let xAxis: LivelineAudioGraphXAxis
        if isCategorical {
            xAxis = .categories(categoryOrder)
        } else if let visibleRange {
            xAxis = .time(visibleRange)
        } else {
            let times = series.flatMap { $0.points.compactMap(\.time) }
            xAxis = .time((times.min() ?? 0)...(times.max() ?? times.min() ?? 1))
        }

        return LivelineAudioGraphModel(
            title: title,
            summary: summary,
            xAxis: xAxis,
            valueRange: explicitValueRange ?? valueRange(of: series),
            series: series
        )
    }

    private static func stackedSeries(
        _ data: [LivelineStackedPoint],
        mode: LivelineStackMode,
        isContinuous: Bool,
        timed: (String, Bool, [(TimeInterval, Double)]) -> LivelineAudioGraphSeries
    ) -> [LivelineAudioGraphSeries] {
        let depth = data.map(\.values.count).max() ?? 0
        guard depth > 0 else { return [] }
        let signed = data.map { point -> (TimeInterval, [Double]) in
            let segments = LivelineMath.stackedSegments(values: point.values, mode: mode)
            return (
                point.time,
                zip(point.values, segments).map { rawValue, segment in
                    rawValue < 0
                        ? segment.lower - segment.upper
                        : segment.upper - segment.lower
                }
            )
        }
        return (0..<depth).map { index in
            timed(
                String(format: LivelineStrings.labelSeriesFormat, index + 1),
                isContinuous,
                signed.compactMap { time, values in
                    values.indices.contains(index) ? (time, values[index]) : nil
                }
            )
        }
    }

    /// `AXNumericDataAxisDescriptor` needs a non-degenerate range; a flat series
    /// would otherwise sonify as a divide-by-zero.
    private static func valueRange(of series: [LivelineAudioGraphSeries]) -> ClosedRange<Double> {
        let values = series.flatMap { $0.points.map(\.value) }
        guard let minimum = values.min(), let maximum = values.max() else {
            return 0...1
        }
        guard minimum == maximum else { return minimum...maximum }
        let padding = max(abs(minimum) * 0.1, 0.5)
        return (minimum - padding)...(maximum + padding)
    }
}

#if canImport(Accessibility)
extension LivelineAudioGraphModel {
    func makeChartDescriptor(
        formatValue: @escaping (Double) -> String,
        formatTime: @escaping (TimeInterval) -> String
    ) -> AXChartDescriptor {
        AXChartDescriptor(
            title: title,
            summary: summary,
            xAxis: makeXAxisDescriptor(formatTime: formatTime),
            yAxis: AXNumericDataAxisDescriptor(
                title: LivelineStrings.labelValue,
                range: valueRange,
                gridlinePositions: [],
                valueDescriptionProvider: formatValue
            ),
            series: series.map { entry in
                AXDataSeriesDescriptor(
                    name: entry.name,
                    isContinuous: entry.isContinuous,
                    dataPoints: entry.points.map { point in
                        if let time = point.time {
                            return AXDataPoint(x: time, y: point.value, label: formatTime(time))
                        }
                        return AXDataPoint(x: point.category ?? "", y: point.value)
                    }
                )
            }
        )
    }

    private func makeXAxisDescriptor(
        formatTime: @escaping (TimeInterval) -> String
    ) -> AXDataAxisDescriptor {
        switch xAxis {
        case let .time(range):
            return AXNumericDataAxisDescriptor(
                title: LivelineStrings.labelTime,
                range: range,
                gridlinePositions: [],
                valueDescriptionProvider: formatTime
            )
        case let .categories(categories):
            return AXCategoricalDataAxisDescriptor(title: LivelineStrings.labelCategory, categoryOrder: categories)
        }
    }
}

/// Handed to `accessibilityChartDescriptor(_:)`. It stores only what the chart
/// already has in hand; the descriptor — and the per-datum work behind it — is
/// built when VoiceOver asks, not on every body evaluation.
struct LivelineChartDescriptor: AXChartDescriptorRepresentable {
    var content: LivelineChartContent
    var semantics: LivelineChartSemantics
    var configuration: LivelineChartConfiguration
    var hiddenSeries: Set<String>
    var activeWindow: TimeInterval
    var title: String
    var summary: String

    func makeChartDescriptor() -> AXChartDescriptor {
        model.makeChartDescriptor(
            formatValue: configuration.formatValue,
            formatTime: configuration.formatTime
        )
    }

    func updateChartDescriptor(_ descriptor: AXChartDescriptor) {
        let model = self.model
        descriptor.title = model.title
        descriptor.summary = model.summary
        let rebuilt = model.makeChartDescriptor(
            formatValue: configuration.formatValue,
            formatTime: configuration.formatTime
        )
        descriptor.xAxis = rebuilt.xAxis
        descriptor.yAxis = rebuilt.yAxis
        descriptor.series = rebuilt.series
    }

    private var model: LivelineAudioGraphModel {
        LivelineAudioGraphModel.make(
            content: content,
            semantics: semantics,
            configuration: configuration,
            hiddenSeries: hiddenSeries,
            activeWindow: activeWindow,
            title: title,
            summary: summary
        )
    }
}
#endif

extension View {
    /// Attaches the Audio Graph descriptor where the platform supports it.
    @ViewBuilder
    func livelineAudioGraph(
        content: LivelineChartContent,
        semantics: LivelineChartSemantics,
        configuration: LivelineChartConfiguration,
        hiddenSeries: Set<String>,
        activeWindow: TimeInterval,
        title: String,
        summary: String
    ) -> some View {
        #if canImport(Accessibility)
        accessibilityChartDescriptor(
            LivelineChartDescriptor(
                content: content,
                semantics: semantics,
                configuration: configuration,
                hiddenSeries: hiddenSeries,
                activeWindow: activeWindow,
                title: title,
                summary: summary
            )
        )
        #else
        self
        #endif
    }
}
