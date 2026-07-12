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
        behavior: LivelineHoverBehavior,
        includeTargets: Bool = true,
        targetLocation: CGPoint? = nil
    ) -> LivelineInteractionSnapshot {
        LivelineInteractionSnapshot(
            layout: layout,
            points: prepared.primaryVisible,
            behavior: behavior,
            isEnabled: configuration.scrub,
            targets: includeTargets ? targets(
                content: content,
                prepared: prepared,
                layout: layout,
                palette: palette,
                configuration: configuration,
                hiddenSeries: hiddenSeries,
                targetLocation: targetLocation
            ) : []
        )
    }

    private static func targets(
        content: LivelineChartContent,
        prepared: LivelinePreparedChart,
        layout: LivelineLayout,
        palette: LivelinePalette,
        configuration: LivelineChartConfiguration,
        hiddenSeries: Set<String>,
        targetLocation: CGPoint?
    ) -> [LivelineInteractionTarget] {
        let value = configuration.formatValue
        let time = configuration.formatTime
        let visibleRange = (layout.leftEdge - 2)...layout.rightEdge

        switch content {
        case .line:
            return interactionSlice(prepared.primaryVisible, nearestTo: targetLocation, layout: layout).map {
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
            let geometry = LivelineRenderer.timelineGeometry(
                items: visible,
                style: style,
                layout: layout,
                palette: palette,
                reveal: 1
            )
            return geometry.marks.map { mark in
                return target(
                    time: mark.item.start,
                    value: mark.item.end - mark.item.start,
                    anchor: CGPoint(x: mark.rect.midX, y: mark.rect.minY),
                    heading: mark.item.label,
                    rows: [
                        row("Start", time(mark.item.start), mark.color.opacity(0.7)),
                        row("End", time(mark.item.end), mark.color),
                        row("Duration", value(mark.item.end - mark.item.start), mark.color),
                    ],
                    region: .rect(mark.rect)
                )
            }

        case let .heatmap(cells, style):
            let visible = cells.livelineVisible(in: visibleRange)
            let geometry = LivelineRenderer.heatmapGeometry(
                cells: visible,
                style: style,
                layout: layout,
                palette: palette,
                reveal: 1
            )
            return geometry.marks.map { mark in
                let label = style.rowLabels.indices.contains(mark.cell.row)
                    ? style.rowLabels[mark.cell.row]
                    : "Row \(mark.cell.row + 1)"
                return target(
                    time: mark.cell.time,
                    value: mark.cell.value,
                    anchor: CGPoint(x: mark.rect.midX, y: mark.rect.midY),
                    heading: time(mark.cell.time),
                    rows: [row(label, value(mark.cell.value), mark.color)],
                    region: .rect(mark.rect)
                )
            }

        case let .radar(points, style):
            guard points.count >= 3 else { return [] }
            let geometry = LivelineRenderer.radarGeometry(points: points, style: style, layout: layout, reveal: 1)
            return points.enumerated().map { index, point in
                let angle = geometry.startAngle + Double(index) * geometry.angleStep
                return target(
                    time: Double(index),
                    value: point.value,
                    anchor: geometry.valuePoints[index],
                    heading: point.label,
                    rows: [row("Value", value(point.value), palette.line)],
                    region: .sector(
                        center: geometry.center,
                        innerRadius: 0,
                        outerRadius: geometry.radius + 22,
                        startAngle: angle - geometry.angleStep / 2,
                        endAngle: angle + geometry.angleStep / 2
                    )
                )
            }

        case let .donut(data, style):
            let geometry = LivelineRenderer.donutGeometry(
                data: data,
                style: style,
                layout: layout,
                palette: palette,
                reveal: 1
            )
            guard geometry.total > 0 else { return [] }
            return geometry.segments.enumerated().map { index, segment in
                return target(
                    time: Double(index),
                    value: segment.entry.value,
                    anchor: LivelineMath.polarPoint(
                        center: geometry.center,
                        radius: geometry.outerRadius,
                        angle: segment.middleAngle
                    ),
                    heading: segment.entry.label,
                    rows: [
                        row("Value", value(segment.entry.value), segment.color),
                        row(
                            "Share",
                            (segment.entry.value / geometry.total * 100).formatted(.number.precision(.fractionLength(1))) + "%",
                            segment.color
                        ),
                    ],
                    region: .sector(
                        center: geometry.center,
                        innerRadius: geometry.innerRadius - 8,
                        outerRadius: geometry.outerRadius + 10,
                        startAngle: segment.fullStartAngle,
                        endAngle: segment.fullEndAngle
                    )
                )
            }

        case let .gauge(gaugeValue, range, style):
            let geometry = LivelineRenderer.gaugeRenderGeometry(
                value: gaugeValue,
                range: range,
                style: style,
                layout: layout,
                reveal: 1
            )
            let angle = (geometry.startDegrees + style.resolvedSweepDegrees * geometry.valueProgress) * Double.pi / 180
            var rows = [row("Value", value(gaugeValue), style.progressColor ?? palette.line)]
            if let targetValue = style.resolvedTarget {
                rows.append(row("Target", value(targetValue), style.targetColor ?? palette.tooltipText))
            }
            return [target(
                time: 0,
                value: gaugeValue,
                anchor: LivelineMath.polarPoint(center: geometry.gauge.center, radius: geometry.gauge.radius, angle: angle),
                heading: "Gauge",
                rows: rows,
                region: .rect(geometry.plotRect)
            )]

        case let .funnel(data, style):
            let geometry = LivelineRenderer.funnelGeometry(
                data: data,
                style: style,
                layout: layout,
                palette: palette,
                reveal: 1
            )
            return geometry.stages.enumerated().map { index, stage in
                return target(
                    time: Double(index),
                    value: stage.entry.value,
                    anchor: CGPoint(x: stage.rect.midX, y: stage.rect.minY),
                    heading: stage.entry.label,
                    rows: [row("Value", value(stage.entry.value), stage.color)],
                    region: .rect(stage.rect)
                )
            }

        case let .candle(_, _, candles, candleWidth, liveCandle, lineData, _):
            // Once candles have morphed into line mode, the visible geometry is
            // the dense line series rather than the candle highs and bodies.
            // Build the interaction model from that same series so the marker,
            // guide, and tooltip remain attached to the rendered path.
            if configuration.lineMode, !lineData.isEmpty {
                let visible = lineData.livelineVisible(in: visibleRange)
                return interactionSlice(visible, nearestTo: targetLocation, layout: layout).map { point in
                    xTarget(
                        point: point,
                        anchorValue: point.value,
                        heading: time(point.time),
                        rows: [row("Value", value(point.value), palette.line)],
                        layout: layout
                    )
                }
            }

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
            let visible = primary.data.livelineVisible(in: visibleRange)
            return interactionSlice(visible, nearestTo: targetLocation, layout: layout).map { point in
                let rows = visibleSeries.compactMap { entry -> LivelineTooltipRow? in
                    guard let interpolated = LivelineMath.interpolateOrdered(points: entry.data, at: point.time) else { return nil }
                    return row(entry.label ?? entry.id, value(interpolated), entry.color)
                }
                return xTarget(point: point, anchorValue: rows.isEmpty ? point.value : visibleSeries.compactMap { LivelineMath.interpolateOrdered(points: $0.data, at: point.time) }.max() ?? point.value, heading: time(point.time), rows: rows, layout: layout)
            }
        }
    }

    private static func interactionSlice<Element: LivelineTimedDatum>(
        _ elements: [Element],
        nearestTo location: CGPoint?,
        layout: LivelineLayout
    ) -> [Element] {
        guard let location, !elements.isEmpty else { return elements }
        let targetTime = layout.time(for: location.x)
        var lower = 0
        var upper = elements.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if elements[middle].time < targetTime {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        if lower == 0 { return [elements[0]] }
        if lower == elements.count { return [elements[elements.count - 1]] }
        let before = elements[lower - 1]
        let after = elements[lower]
        return [targetTime - before.time <= after.time - targetTime ? before : after]
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
                row(
                    "Series \(index + 1)",
                    value(segment.upper - segment.lower),
                    LivelineRenderer.extendedSeriesColor(index: index, colors: colors, palette: palette)
                )
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
                anchor: anchor
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
        region: LivelineInteractionRegion
    ) -> LivelineInteractionTarget {
        LivelineInteractionTarget(
            selection: LivelineTooltipSelection(
                hover: LivelineHoverPoint(time: time, value: value, x: anchor.x, y: anchor.y),
                heading: heading,
                rows: rows,
                anchor: anchor
            ),
            region: region
        )
    }

    private static func row(_ label: String, _ value: String, _ color: Color) -> LivelineTooltipRow {
        LivelineTooltipRow(label: label, value: value, color: color)
    }

}
