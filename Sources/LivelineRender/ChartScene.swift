#if os(macOS)
import Liveline
import SwiftUI

struct ChartScene: View {
    let options: RenderOptions
    let elapsedTime: TimeInterval

    var body: some View {
        chart
            .padding(.horizontal, max(28, CGFloat(options.width) * 0.035))
            .padding(.vertical, max(24, CGFloat(options.height) * 0.055))
            .frame(width: CGFloat(options.width), height: CGFloat(options.height))
            .background(options.background)
            .environment(\.colorScheme, options.theme == "light" ? .light : .dark)
    }

    private var chart: AnyView {
        let values = animatedValues
        let configuration = LivelineChartConfiguration(
            theme: options.themeMode,
            style: options.chartStyle,
            window: chartWindow,
            grid: options.grid,
            badge: options.chart == .line || options.chart == .candle,
            fill: options.fill,
            pulse: true,
            fadeEffects: false,
            lineWidth: 2,
            scrub: false,
            showValue: options.showValue,
            formatValue: { value in Self.format(value) },
            formatTime: { time in Self.formatTime(time) },
            lerpSpeed: 0.12,
            randomSeed: options.randomSeed,
            snapshotElapsedTime: elapsedTime,
            padding: LivelinePadding(top: 20, right: 82, bottom: 38, left: options.chart == .heatmap ? 76 : 20)
        )
        let accent = options.accent

        switch options.chart {
        case .line:
            let points = timePoints(values)
            return AnyView(LivelineChart(data: points, value: values.last ?? 0, color: accent, configuration: configuration))

        case .bars:
            return AnyView(LivelineChart(
                bars: timePoints(values),
                color: accent,
                style: LivelineBarStyle(widthRatio: 0.72, cornerRadius: 3),
                configuration: configuration
            ))

        case .candle:
            let candles = candleValues(values)
            let close = candles.last?.close ?? 0
            return AnyView(LivelineChart(
                data: candles.map { LivelinePoint(time: $0.time, value: $0.close) },
                value: close,
                candles: candles,
                candleWidth: sampleInterval,
                color: accent,
                configuration: configuration
            ))

        case .multi:
            let colors: [Color] = [accent, Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255), Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255)]
            let names = resolvedLabels(defaults: ["Alpha", "Gamma", "Beta"], count: 3)
            let series = (0..<3).map { seriesIndex in
                let shifted = values.enumerated().map { index, value in
                    value + sin(Double(index) * (0.55 + Double(seriesIndex) * 0.12) + Double(seriesIndex) * 1.7) * (4 + Double(seriesIndex) * 2)
                }
                return LivelineSeries(
                    id: "series-\(seriesIndex)",
                    data: timePoints(shifted),
                    value: shifted.last ?? 0,
                    color: colors[seriesIndex],
                    label: names[seriesIndex]
                )
            }
            return AnyView(LivelineChart(series: series, configuration: configuration))

        case .stackedBar:
            return AnyView(LivelineChart(
                stackedBars: stackedValues(values),
                color: accent,
                style: LivelineStackedBarStyle(widthRatio: 0.76, cornerRadius: 2, segmentSpacing: 1, colors: palette),
                configuration: configuration
            ))

        case .stackedArea:
            return AnyView(LivelineChart(
                stackedAreas: stackedValues(values),
                color: accent,
                style: LivelineStackedAreaStyle(colors: palette, fillOpacity: 0.58, boundaryLineWidth: 1.25),
                configuration: configuration
            ))

        case .timeline:
            let labels = resolvedLabels(defaults: ["Design", "Build", "Test", "Ship"], count: max(values.count, 4))
            let items = values.enumerated().map { index, value in
                let start = baseTime - Double(max(values.count - index, 1)) * sampleInterval
                let duration = max(abs(value), 1) / max(values.map(abs).max() ?? 1, 1) * sampleInterval * 3
                return LivelineTimelineItem(id: "item-\(index)", label: labels[index], start: start, end: start + duration, lane: index % 4)
            }
            return AnyView(LivelineChart(
                timeline: items,
                color: accent,
                style: LivelineTimelineStyle(colors: palette, showsLabels: true),
                configuration: configuration
            ))

        case .heatmap:
            let rows = min(max(options.labels.count, 4), 8)
            let rowLabels = resolvedLabels(defaults: ["US", "EU", "APAC", "LATAM"], count: rows)
            let columns = max(Int(ceil(Double(values.count) / Double(rows))), 1)
            let cells = (0..<(columns * rows)).map { index in
                LivelineHeatmapCell(
                    time: baseTime - Double(columns - 1 - index / rows) * sampleInterval,
                    row: index % rows,
                    value: values[index % values.count]
                )
            }
            return AnyView(LivelineChart(
                heatmap: cells,
                color: accent,
                style: LivelineHeatmapStyle(rowLabels: rowLabels, color: accent),
                configuration: configuration
            ))

        case .radar:
            let labels = resolvedLabels(defaults: ["Speed", "Quality", "Scale", "Safety", "DX", "Reach"], count: values.count)
            let points = values.enumerated().map { LivelineRadarPoint(label: labels[$0.offset], value: $0.element) }
            return AnyView(LivelineChart(
                radar: points,
                color: accent,
                style: LivelineRadarStyle(range: options.minimum...options.maximum, gridLevels: 5, fillOpacity: 0.24),
                configuration: configuration
            ))

        case .donut:
            return AnyView(LivelineChart(
                donut: categories(values),
                color: accent,
                style: LivelineDonutStyle(innerRadiusRatio: 0.58, gapDegrees: 3, colors: palette),
                configuration: configuration
            ))

        case .gauge:
            return AnyView(LivelineChart(
                gauge: values.last ?? options.minimum,
                range: options.minimum...options.maximum,
                color: accent,
                style: LivelineGaugeStyle(lineWidth: max(16, CGFloat(options.height) * 0.025), trackOpacity: 0.16),
                configuration: configuration
            ))

        case .funnel:
            return AnyView(LivelineChart(
                funnel: categories(values),
                color: accent,
                style: LivelineFunnelStyle(colors: palette),
                configuration: configuration
            ))
        }
    }

    private var animatedValues: [Double] {
        switch options.valueMotion {
        case .static:
            options.values
        case .pulse:
            options.values.enumerated().map { index, value in
                let amplitude = max(abs(value) * 0.055, (options.maximum - options.minimum) * 0.012)
                return value + sin(elapsedTime * 2.1 + Double(index) * 0.38) * amplitude
            }
        case .stream:
            options.values.enumerated().map { index, value in
                let phase = elapsedTime * 1.5 + Double(index) * 0.62
                let amplitude = max(abs(value) * 0.075, (options.maximum - options.minimum) * 0.018)
                return value + sin(phase) * amplitude + cos(phase * 0.43) * amplitude * 0.35
            }
        }
    }

    private var baseTime: TimeInterval { 1_788_888_000 }
    private var sampleInterval: TimeInterval { 8 }
    private var chartWindow: TimeInterval {
        let sampleCount: Int
        if options.chart == .heatmap {
            let rows = min(max(options.labels.count, 4), 8)
            sampleCount = max(Int(ceil(Double(options.values.count) / Double(rows))), 1)
        } else {
            sampleCount = options.values.count
        }
        return max(30, Double(max(sampleCount - 1, 1)) * sampleInterval + 12)
    }

    private func timePoints(_ values: [Double]) -> [LivelinePoint] {
        values.enumerated().map { index, value in
            LivelinePoint(time: baseTime - Double(values.count - index - 1) * sampleInterval, value: value)
        }
    }

    private func candleValues(_ values: [Double]) -> [LivelineCandle] {
        values.enumerated().map { index, close in
            let open = index == 0 ? close * 0.985 : values[index - 1]
            let spread = max(abs(close - open) * 0.45, max(abs(close), 1) * 0.018)
            return LivelineCandle(
                time: baseTime - Double(values.count - index - 1) * sampleInterval,
                open: open,
                high: max(open, close) + spread,
                low: min(open, close) - spread,
                close: close
            )
        }
    }

    private func stackedValues(_ values: [Double]) -> [LivelineStackedPoint] {
        values.enumerated().map { index, value in
            let magnitude = max(abs(value), 0.001)
            let wave = (sin(Double(index) * 0.7) + 1) * 0.04
            return LivelineStackedPoint(
                time: baseTime - Double(values.count - index - 1) * sampleInterval,
                values: [magnitude * (0.42 + wave), magnitude * (0.33 - wave * 0.5), magnitude * (0.25 - wave * 0.5)]
            )
        }
    }

    private func categories(_ values: [Double]) -> [LivelineCategoryValue] {
        let labels = resolvedLabels(defaults: ["Pro", "Team", "Starter", "Other", "Free", "Enterprise"], count: values.count)
        return values.enumerated().map {
            LivelineCategoryValue(id: "category-\($0.offset)", label: labels[$0.offset], value: max($0.element, 0))
        }
    }

    private func resolvedLabels(defaults: [String], count: Int) -> [String] {
        (0..<count).map { index in
            if index < options.labels.count, !options.labels[index].isEmpty { return options.labels[index] }
            if index < defaults.count { return defaults[index] }
            return "Item \(index + 1)"
        }
    }

    private var palette: [Color] {
        [
            options.accent,
            Color(red: 139 / 255, green: 92 / 255, blue: 246 / 255),
            Color(red: 6 / 255, green: 182 / 255, blue: 212 / 255),
            Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255),
            Color(red: 249 / 255, green: 115 / 255, blue: 22 / 255),
            Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255),
        ]
    }

    private static func format(_ value: Double) -> String {
        if abs(value) >= 1_000 { return String(format: "%.1f k", value / 1_000) }
        if abs(value.rounded() - value) < 0.005 { return String(format: "%.0f", value) }
        return String(format: "%.2f", value)
    }

    private static func formatTime(_ time: TimeInterval) -> String {
        let seconds = Int(time.rounded()) % 86_400
        return String(format: "%02d:%02d:%02d", seconds / 3_600, (seconds / 60) % 60, seconds % 60)
    }
}
#endif
