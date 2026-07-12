import Foundation
import SwiftUI

enum LivelineInteractionBuilder {
    static func snapshot(
        content: LivelineChartContent,
        prepared: LivelinePreparedChart,
        layout: LivelineLayout,
        palette: LivelinePalette,
        configuration: LivelineChartConfiguration,
        hiddenSeries: Set<String>,
        behavior: LivelineHoverBehavior
    ) -> LivelineInteractionSnapshot {
        LivelineInteractionSnapshot(
            layout: layout,
            points: prepared.primaryVisible,
            behavior: behavior,
            isEnabled: configuration.scrub,
            targets: targets(
                content: content,
                prepared: prepared,
                layout: layout,
                palette: palette,
                configuration: configuration,
                hiddenSeries: hiddenSeries
            )
        )
    }

    private static func targets(
        content: LivelineChartContent,
        prepared: LivelinePreparedChart,
        layout: LivelineLayout,
        palette: LivelinePalette,
        configuration: LivelineChartConfiguration,
        hiddenSeries: Set<String>
    ) -> [LivelineInteractionTarget] {
        let value = configuration.formatValue
        let time = configuration.formatTime
        let visibleRange = (layout.leftEdge - 2)...layout.rightEdge

        switch content {
        case .line:
            return prepared.primaryVisible.map {
                xTarget(point: $0, anchorValue: $0.value, heading: time($0.time), rows: [
                    row("Value", value($0.value), palette.line),
                ], layout: layout)
            }

        case let .bars(data, style):
            return data.livelineVisible(in: visibleRange).map {
                let color = $0.value >= style.resolvedBaseline ? (style.positiveColor ?? palette.line) : style.negativeColor
                return xTarget(point: $0, anchorValue: $0.value, heading: time($0.time), rows: [
                    row("Value", value($0.value), color),
                ], layout: layout)
            }

        case let .range(data, _):
            return data.livelineVisible(in: visibleRange).map {
                xTarget(
                    point: LivelinePoint(time: $0.time, value: $0.midpoint),
                    anchorValue: $0.upper,
                    heading: time($0.time),
                    rows: [
                        row("Lower", value($0.lower), palette.line.opacity(0.65)),
                        row("Upper", value($0.upper), palette.line),
                    ],
                    layout: layout
                )
            }

        case let .scatter(data, _, _), let .steps(data, _, _):
            return data.livelineVisible(in: visibleRange).map {
                xTarget(point: $0, anchorValue: $0.value, heading: time($0.time), rows: [
                    row("Value", value($0.value), palette.line),
                ], layout: layout)
            }

        case let .lollipops(data, style):
            return data.livelineVisible(in: visibleRange).map {
                let color = $0.value >= style.resolvedBaseline ? (style.positiveColor ?? palette.line) : style.negativeColor
                return xTarget(point: $0, anchorValue: $0.value, heading: time($0.time), rows: [
                    row("Value", value($0.value), color),
                ], layout: layout)
            }

        case let .bubbles(data, _):
            return data.livelineVisible(in: visibleRange).map {
                xTarget(
                    point: LivelinePoint(time: $0.time, value: $0.value),
                    anchorValue: $0.value,
                    heading: time($0.time),
                    rows: [
                        row("Value", value($0.value), palette.line),
                        row("Magnitude", value($0.magnitude), palette.line.opacity(0.65)),
                    ],
                    layout: layout
                )
            }

        case let .boxPlots(data, _):
            return data.livelineVisible(in: visibleRange).map {
                xTarget(
                    point: LivelinePoint(time: $0.time, value: $0.median),
                    anchorValue: $0.maximum,
                    heading: time($0.time),
                    rows: [
                        row("Maximum", value($0.maximum), palette.line),
                        row("Q3", value($0.upperQuartile), palette.line.opacity(0.82)),
                        row("Median", value($0.median), palette.line),
                        row("Q1", value($0.lowerQuartile), palette.line.opacity(0.82)),
                        row("Minimum", value($0.minimum), palette.line.opacity(0.65)),
                    ],
                    layout: layout
                )
            }

        case let .waterfall(data, style):
            return LivelineMath.waterfallSegments(points: data, initialValue: style.resolvedInitialValue)
                .livelineVisible(in: visibleRange)
                .map { segment in
                    let color = segment.delta >= 0 ? (style.positiveColor ?? palette.line) : style.negativeColor
                    return xTarget(
                        point: LivelinePoint(time: segment.time, value: segment.end),
                        anchorValue: max(segment.start, segment.end),
                        heading: time(segment.time),
                        rows: [
                            row("Start", value(segment.start), palette.gridLabel),
                            row("Change", value(segment.delta), color),
                            row("End", value(segment.end), color),
                        ],
                        layout: layout
                    )
                }

        case let .errorBars(data, _):
            return data.livelineVisible(in: visibleRange).map {
                xTarget(
                    point: LivelinePoint(time: $0.time, value: $0.value),
                    anchorValue: $0.upper,
                    heading: time($0.time),
                    rows: [
                        row("Upper", value($0.upper), palette.line.opacity(0.72)),
                        row("Value", value($0.value), palette.line),
                        row("Lower", value($0.lower), palette.line.opacity(0.72)),
                    ],
                    layout: layout
                )
            }

        case let .dumbbells(data, style):
            return data.livelineVisible(in: visibleRange).map {
                xTarget(
                    point: LivelinePoint(time: $0.time, value: $0.end),
                    anchorValue: max($0.start, $0.end),
                    heading: time($0.time),
                    rows: [
                        row("Start", value($0.start), style.startColor ?? palette.gridLabel),
                        row("End", value($0.end), style.endColor ?? palette.line),
                    ],
                    layout: layout
                )
            }

        case let .stackedBars(data, style):
            return stackedTargets(data: data, mode: style.mode, colors: style.colors, layout: layout, palette: palette, value: value, time: time)

        case let .stackedAreas(data, style):
            return stackedTargets(data: data, mode: style.mode, colors: style.colors, layout: layout, palette: palette, value: value, time: time)

        case let .timeline(items, style):
            let visible = items.filter { $0.end >= layout.leftEdge - 2 && $0.start <= layout.rightEdge }
            let laneCount = max((items.map(\.lane).max() ?? 0) + 1, 1)
            let laneHeight = layout.chartHeight / CGFloat(laneCount)
            let barHeight = max(laneHeight * style.resolvedBarHeightRatio, 3)
            return visible.enumerated().map { index, item in
                let x1 = layout.x(for: item.start)
                let x2 = layout.x(for: item.end)
                let y = layout.padding.top + (CGFloat(item.lane) + 0.5) * laneHeight
                let rect = CGRect(x: min(x1, x2), y: y - barHeight / 2, width: max(abs(x2 - x1), 2), height: barHeight)
                let color = seriesColor(index: index, colors: style.colors, palette: palette)
                return target(
                    time: item.start,
                    value: item.end - item.start,
                    anchor: CGPoint(x: rect.midX, y: rect.minY),
                    heading: item.label,
                    rows: [
                        row("Start", time(item.start), color.opacity(0.7)),
                        row("End", time(item.end), color),
                        row("Duration", value(item.end - item.start), color),
                    ],
                    region: .rect(rect),
                    showsGuide: false
                )
            }

        case let .heatmap(cells, style):
            let visible = cells.livelineVisible(in: visibleRange)
            let rowCount = max((cells.map(\.row).max() ?? 0) + 1, style.rowLabels.count, 1)
            let rowHeight = layout.chartHeight / CGFloat(rowCount)
            let width = LivelineRenderer.bucketWidth(
                times: Array(Set(cells.map(\.time))).sorted(),
                layout: layout,
                ratio: style.resolvedCellWidthRatio,
                maximum: .greatestFiniteMagnitude
            )
            let height = max(rowHeight * style.resolvedCellHeightRatio, 1)
            return visible.map { cell in
                let center = CGPoint(x: layout.x(for: cell.time), y: layout.padding.top + (CGFloat(cell.row) + 0.5) * rowHeight)
                let label = style.rowLabels.indices.contains(cell.row) ? style.rowLabels[cell.row] : "Row \(cell.row + 1)"
                return target(
                    time: cell.time,
                    value: cell.value,
                    anchor: center,
                    heading: time(cell.time),
                    rows: [row(label, value(cell.value), style.color ?? palette.line)],
                    region: .rect(CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)),
                    showsGuide: false
                )
            }

        case let .radar(points, style):
            guard points.count >= 3 else { return [] }
            let center = plotCenter(layout)
            let radius = max(8, min(layout.chartWidth, layout.chartHeight) / 2 - (style.showsLabels ? 30 : 8))
            let step = 2 * Double.pi / Double(points.count)
            let start = -Double.pi / 2
            return points.enumerated().map { index, point in
                let angle = start + Double(index) * step
                let progress = LivelineMath.clamp((point.value - style.resolvedRange.lowerBound) / (style.resolvedRange.upperBound - style.resolvedRange.lowerBound), 0, 1)
                let anchor = LivelineMath.polarPoint(center: center, radius: radius * CGFloat(progress), angle: angle)
                return target(
                    time: Double(index),
                    value: point.value,
                    anchor: anchor,
                    heading: point.label,
                    rows: [row("Value", value(point.value), palette.line)],
                    region: .sector(center: center, innerRadius: 0, outerRadius: radius + 22, startAngle: angle - step / 2, endAngle: angle + step / 2),
                    showsGuide: false
                )
            }

        case let .donut(data, style):
            let positive = data.filter { $0.value > 0 }
            let total = positive.map(\.value).reduce(0, +)
            guard total > 0 else { return [] }
            let center = plotCenter(layout)
            let outerRadius = max(12, min(layout.chartWidth, layout.chartHeight) * (style.showsLabels ? 0.34 : 0.43))
            let innerRadius = outerRadius * style.resolvedInnerRadiusRatio
            var cursor = -Double.pi / 2
            return positive.enumerated().map { index, entry in
                let sweep = entry.value / total * 2 * Double.pi
                let start = cursor
                let end = cursor + sweep
                let middle = (start + end) / 2
                cursor = end
                let color = seriesColor(index: index, colors: style.colors, palette: palette)
                return target(
                    time: Double(index),
                    value: entry.value,
                    anchor: LivelineMath.polarPoint(center: center, radius: outerRadius, angle: middle),
                    heading: entry.label,
                    rows: [
                        row("Value", value(entry.value), color),
                        row("Share", (entry.value / total * 100).formatted(.number.precision(.fractionLength(1))) + "%", color),
                    ],
                    region: .sector(center: center, innerRadius: innerRadius - 8, outerRadius: outerRadius + 10, startAngle: start, endAngle: end),
                    showsGuide: false
                )
            }

        case let .gauge(gaugeValue, range, style):
            let plotRect = CGRect(x: layout.plotLeftX, y: layout.padding.top, width: layout.chartWidth, height: layout.chartHeight)
            let geometry = LivelineMath.gaugeGeometry(
                in: plotRect,
                startAngleDegrees: style.resolvedStartAngleDegrees,
                sweepDegrees: style.resolvedSweepDegrees,
                lineWidth: style.resolvedLineWidth,
                hasOuterMarks: style.showsTicks || style.resolvedTarget != nil,
                showsValue: style.showsValue
            )
            let progress = LivelineMath.gaugeProgress(value: gaugeValue, range: range)
            let angle = (style.resolvedStartAngleDegrees + style.resolvedSweepDegrees * progress) * Double.pi / 180
            var rows = [row("Value", value(gaugeValue), style.progressColor ?? palette.line)]
            if let targetValue = style.resolvedTarget {
                rows.append(row("Target", value(targetValue), style.targetColor ?? palette.tooltipText))
            }
            return [target(
                time: 0,
                value: gaugeValue,
                anchor: LivelineMath.polarPoint(center: geometry.center, radius: geometry.radius, angle: angle),
                heading: "Gauge",
                rows: rows,
                region: .rect(plotRect),
                showsGuide: false
            )]

        case let .funnel(data, style):
            let positive = data.filter { $0.value > 0 }
            guard !positive.isEmpty else { return [] }
            let maximum = positive.map(\.value).max() ?? 1
            let stageHeight = max(8, (layout.chartHeight - style.resolvedSpacing * CGFloat(max(positive.count - 1, 0))) / CGFloat(positive.count))
            let maxWidth = layout.chartWidth * style.resolvedMaximumWidthRatio
            let minWidth = layout.chartWidth * style.resolvedMinimumWidthRatio
            let centerX = (layout.plotLeftX + layout.rightX) / 2
            return positive.enumerated().map { index, entry in
                let width = minWidth + CGFloat(entry.value / maximum) * (maxWidth - minWidth)
                let rect = CGRect(
                    x: centerX - width / 2,
                    y: layout.padding.top + CGFloat(index) * (stageHeight + style.resolvedSpacing),
                    width: width,
                    height: stageHeight
                )
                let color = seriesColor(index: index, colors: style.colors, palette: palette)
                return target(
                    time: Double(index),
                    value: entry.value,
                    anchor: CGPoint(x: rect.midX, y: rect.minY),
                    heading: entry.label,
                    rows: [row("Value", value(entry.value), color)],
                    region: .rect(rect),
                    showsGuide: false
                )
            }

        case let .candle(_, _, candles, candleWidth, liveCandle, _, _):
            var visible = candles.livelineVisible(in: visibleRange, candleWidth: candleWidth)
            if let liveCandle, liveCandle.time + candleWidth >= visibleRange.lowerBound, liveCandle.time <= visibleRange.upperBound {
                if let index = visible.firstIndex(where: { $0.time == liveCandle.time }) {
                    visible[index] = liveCandle
                } else {
                    visible.append(liveCandle)
                }
            }
            return visible.sorted { $0.time < $1.time }.map { candle in
                let color = LivelineRenderer.candleColor(isUp: candle.close >= candle.open).color
                let centerTime = candle.time + candleWidth / 2
                return xTarget(
                    point: LivelinePoint(time: centerTime, value: candle.close),
                    anchorValue: candle.high,
                    heading: time(candle.time),
                    rows: [
                        row("Open", value(candle.open), color.opacity(0.72)),
                        row("High", value(candle.high), color),
                        row("Low", value(candle.low), color.opacity(0.72)),
                        row("Close", value(candle.close), color),
                    ],
                    layout: layout
                )
            }

        case let .series(series):
            let visibleSeries = series.filter { !hiddenSeries.contains($0.id) }
            guard let primary = visibleSeries.first else { return [] }
            return primary.data.livelineVisible(in: visibleRange).map { point in
                let rows = visibleSeries.compactMap { entry -> LivelineTooltipRow? in
                    guard let interpolated = LivelineMath.interpolateOrdered(points: entry.data, at: point.time) else { return nil }
                    return row(entry.label ?? entry.id, value(interpolated), entry.color)
                }
                return xTarget(point: point, anchorValue: rows.isEmpty ? point.value : visibleSeries.compactMap { LivelineMath.interpolateOrdered(points: $0.data, at: point.time) }.max() ?? point.value, heading: time(point.time), rows: rows, layout: layout)
            }
        }
    }

    private static func stackedTargets(
        data: [LivelineStackedPoint],
        mode: LivelineStackMode,
        colors: [Color],
        layout: LivelineLayout,
        palette: LivelinePalette,
        value: (Double) -> String,
        time: (TimeInterval) -> String
    ) -> [LivelineInteractionTarget] {
        data.livelineVisible(in: (layout.leftEdge - 2)...layout.rightEdge).map { point in
            let segments = LivelineMath.stackedSegments(values: point.values, mode: mode)
            var rows = segments.enumerated().map { index, segment in
                row("Series \(index + 1)", value(segment.upper - segment.lower), seriesColor(index: index, colors: colors, palette: palette))
            }
            let total = segments.map { $0.upper - $0.lower }.reduce(0, +)
            rows.append(row("Total", value(total), palette.tooltipText))
            return xTarget(
                point: LivelinePoint(time: point.time, value: total),
                anchorValue: segments.map(\.upper).max() ?? total,
                heading: time(point.time),
                rows: rows,
                layout: layout
            )
        }
    }

    private static func xTarget(
        point: LivelinePoint,
        anchorValue: Double,
        heading: String?,
        rows: [LivelineTooltipRow],
        layout: LivelineLayout
    ) -> LivelineInteractionTarget {
        let x = layout.x(for: point.time)
        let anchor = CGPoint(
            x: x,
            y: LivelineMath.clamp(layout.y(for: anchorValue), layout.padding.top, layout.bottomY)
        )
        return LivelineInteractionTarget(
            selection: LivelineTooltipSelection(
                hover: LivelineHoverPoint(
                    time: point.time,
                    value: point.value,
                    x: x,
                    y: LivelineMath.clamp(layout.y(for: point.value), layout.padding.top, layout.bottomY)
                ),
                heading: heading,
                rows: rows,
                anchor: anchor,
                showsGuide: true
            ),
            region: .x
        )
    }

    private static func target(
        time: TimeInterval,
        value: Double,
        anchor: CGPoint,
        heading: String?,
        rows: [LivelineTooltipRow],
        region: LivelineInteractionRegion,
        showsGuide: Bool
    ) -> LivelineInteractionTarget {
        LivelineInteractionTarget(
            selection: LivelineTooltipSelection(
                hover: LivelineHoverPoint(time: time, value: value, x: anchor.x, y: anchor.y),
                heading: heading,
                rows: rows,
                anchor: anchor,
                showsGuide: showsGuide
            ),
            region: region
        )
    }

    private static func row(_ label: String, _ value: String, _ color: Color) -> LivelineTooltipRow {
        LivelineTooltipRow(label: label, value: value, color: color)
    }

    private static func plotCenter(_ layout: LivelineLayout) -> CGPoint {
        CGPoint(x: (layout.plotLeftX + layout.rightX) / 2, y: layout.padding.top + layout.chartHeight / 2)
    }

    private static func seriesColor(index: Int, colors: [Color], palette: LivelinePalette) -> Color {
        if !colors.isEmpty { return colors[index % colors.count] }
        let defaults: [Color] = [
            palette.line,
            Color(red: 139 / 255, green: 92 / 255, blue: 246 / 255),
            Color(red: 6 / 255, green: 182 / 255, blue: 212 / 255),
            Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255),
            Color(red: 249 / 255, green: 115 / 255, blue: 22 / 255),
            Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255),
        ]
        return defaults[index % defaults.count]
    }
}
