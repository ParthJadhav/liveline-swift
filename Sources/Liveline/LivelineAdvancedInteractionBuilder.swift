import SwiftUI

/// Builds hover targets for advanced charts.
///
/// Every case here reads its geometry from `LivelineAdvancedLayout`, the same
/// place the renderers read it from, so a hit region cannot drift away from the
/// mark it belongs to.
enum LivelineAdvancedInteractionBuilder {
    static func targets(
        content: LivelineAdvancedChartContent,
        layout: LivelineLayout,
        palette: LivelinePalette,
        configuration: LivelineChartConfiguration,
        targetLocation: CGPoint?,
        textScale: LivelineTextScale,
        displayScale: CGFloat? = nil,
        state: LivelineRenderState? = nil
    ) -> [LivelineInteractionTarget] {
        switch content {
        case .violin(let series, let style):
            let profiles = state?.distributionProfiles(series: series, bandwidth: style.bandwidth)
            let geometry = LivelineAdvancedLayout.violin(
                series: series, style: style, layout: layout, textScale: textScale,
                profiles: profiles)
            return geometry.profiles.enumerated().map { index, item in
                let rect = geometry.slotRect(at: index)
                let color = LivelineRenderer.advancedColor(
                    index: index, colors: style.colors, palette: palette)
                return target(
                    time: Double(index), value: item.profile.median,
                    anchor: CGPoint(x: rect.midX, y: rect.midY), heading: item.series.label,
                    rows: [
                        row(LivelineStrings.labelSamples, "\(item.series.values.count)", color),
                        row(
                            LivelineStrings.labelLowerQuartile,
                            configuration.formatValue(item.profile.lowerQuartile), color.opacity(0.7)),
                        row(
                            LivelineStrings.labelMedian, configuration.formatValue(item.profile.median), color),
                        row(
                            LivelineStrings.labelUpperQuartile,
                            configuration.formatValue(item.profile.upperQuartile), color.opacity(0.7)),
                    ], region: .rect(rect))
            }

        case .ridgeline(let series, let style):
            let profiles = state?.distributionProfiles(series: series, bandwidth: style.bandwidth)
            let geometry = LivelineAdvancedLayout.ridgeline(
                series: series, style: style, layout: layout, textScale: textScale,
                profiles: profiles)
            return geometry.profiles.enumerated().map { index, item in
                let rect = geometry.rowRect(at: index)
                let color = LivelineRenderer.advancedColor(
                    index: index, colors: style.colors, palette: palette)
                return target(
                    time: Double(index), value: item.profile.median,
                    anchor: CGPoint(x: rect.midX, y: rect.midY), heading: item.series.label,
                    rows: [
                        row(LivelineStrings.labelSamples, "\(item.series.values.count)", color),
                        row(
                            LivelineStrings.labelMedian, configuration.formatValue(item.profile.median), color),
                    ], region: .rect(rect))
            }

        case .calendarHeatmap(let values, let style):
            guard
                let geometry = LivelineAdvancedLayout.calendar(
                    values: values, style: style, layout: layout, textScale: textScale)
            else { return [] }
            let collapsed = LivelineAdvancedLayout.calendarValuesByDay(
                values, calendar: geometry.calendar).values.sorted { $0.date < $1.date }
            return collapsed.compactMap { entry in
                let date = geometry.calendar.startOfDay(for: entry.date)
                guard
                    let day = geometry.calendar.dateComponents([.day], from: geometry.firstDay, to: date).day,
                    day >= 0
                else { return nil }
                let rect = geometry.rect(dayOffset: day)
                return target(
                    time: entry.date.timeIntervalSince1970, value: entry.value,
                    anchor: CGPoint(x: rect.midX, y: rect.midY),
                    heading: entry.label ?? configuration.formatTime(entry.date.timeIntervalSince1970),
                    rows: [
                        row(LivelineStrings.labelValue, configuration.formatValue(entry.value), palette.line)
                    ], region: .rect(rect))
            }

        case .gantt(let tasks, let style):
            let geometry = LivelineAdvancedLayout.gantt(
                tasks: tasks, style: style, layout: layout, textScale: textScale)
            return tasks.map { task in
                let rect = geometry.rect(for: task, layout: layout)
                return target(
                    time: task.start,
                    value: task.end - task.start,
                    anchor: CGPoint(x: rect.midX, y: rect.midY),
                    heading: task.label,
                    rows: [
                        row(
                            LivelineStrings.labelStart, configuration.formatTime(task.start), palette.gridLabel),
                        row(LivelineStrings.labelEnd, configuration.formatTime(task.end), palette.line),
                        row(
                            LivelineStrings.labelProgress,
                            (task.progress * 100).formatted(.number.precision(.fractionLength(0))) + "%",
                            palette.line),
                    ],
                    region: .rect(rect)
                )
            }

        case .bump(let series, let style):
            guard
                let geometry = LivelineAdvancedLayout.bump(
                    series: series, style: style, layout: layout, textScale: textScale)
            else { return [] }
            return series.enumerated().flatMap { index, entry -> [LivelineInteractionTarget] in
                let color = LivelineRenderer.advancedColor(
                    index: index, colors: style.colors, palette: palette)
                guard
                    let visible = geometry.visibleIndexRange(
                        in: entry.points, includingBoundaryPoints: false)
                else { return [] }
                let visiblePoints = Array(entry.points[visible])
                return nearestTimed(
                    visiblePoints, targetLocation: targetLocation, layout: layout, time: \.time
                ).map { point in
                    let center = CGPoint(
                        x: geometry.x(time: point.time), y: geometry.y(rank: point.rank))
                    return target(
                        time: point.time,
                        value: point.rank,
                        anchor: center,
                        heading: entry.label,
                        rows: [
                            row(
                                LivelineStrings.labelTime, configuration.formatTime(point.time),
                                palette.gridLabel),
                            row(LivelineStrings.labelRank, configuration.formatValue(point.rank), color),
                        ],
                        region: .circle(center: center, radius: max(style.resolvedPointSize / 2, 5))
                    )
                }
            }

        case .horizon(let points, _):
            let plot = LivelineRenderer.advancedPlotRect(layout)
            let visible = points.filter { $0.time >= layout.leftEdge - 2 && $0.time <= layout.rightEdge }
            return nearestTimed(
                visible, targetLocation: targetLocation, layout: layout, time: \.time
            ).map {
                point in
                let center = CGPoint(x: layout.x(for: point.time), y: plot.midY)
                return target(
                    time: point.time, value: point.value, anchor: center,
                    heading: configuration.formatTime(point.time),
                    rows: [
                        row(LivelineStrings.labelValue, configuration.formatValue(point.value), palette.line)
                    ], region: .x)
            }

        case .chord(let links, let style):
            let geometry = LivelineAdvancedLayout.chord(
                links: links, style: style, layout: layout, textScale: textScale)
            let ribbonTargets = geometry.ribbons.map { ribbon in
                let path = ribbon.path(center: geometry.center, radius: geometry.innerRadius - 1)
                let bounds = path.boundingRect
                let anchor = CGPoint(x: bounds.midX, y: bounds.midY)
                let colorIndex = geometry.arcs.first { $0.label == ribbon.link.source }?.index ?? 0
                return target(
                    time: Double(ribbon.index), value: ribbon.link.value, anchor: anchor,
                    heading: String(
                        format: LivelineStrings.labelFlowRouteFormat,
                        ribbon.link.source, ribbon.link.target),
                    rows: [
                        row(
                            LivelineStrings.labelValue,
                            configuration.formatValue(ribbon.link.value),
                            LivelineRenderer.advancedColor(
                                index: colorIndex, colors: style.colors, palette: palette))
                    ],
                    region: .path(path))
            }
            let nodeTargets = geometry.arcs.map { arc in
                let anchor = LivelineMath.polarPoint(
                    center: geometry.center,
                    radius: (geometry.innerRadius + geometry.outerRadius) / 2,
                    angle: arc.middle)
                return target(
                    time: Double(arc.index), value: arc.value, anchor: anchor, heading: arc.label,
                    rows: [
                        row(
                            LivelineStrings.labelTotal, configuration.formatValue(arc.value),
                            LivelineRenderer.advancedColor(
                                index: arc.index, colors: style.colors, palette: palette))
                    ],
                    region: .sector(
                        center: geometry.center, innerRadius: geometry.innerRadius,
                        outerRadius: geometry.outerRadius, startAngle: arc.start, endAngle: arc.end))
            }
            return ribbonTargets + nodeTargets

        case .parallelCoordinates(let records, let style):
            guard
                let geometry = LivelineAdvancedLayout.parallelCoordinates(
                    records: records, layout: layout, textScale: textScale)
            else { return [] }
            return records.enumerated().compactMap { index, record in
                guard let last = record.values.last else { return nil }
                let color = LivelineRenderer.advancedColor(
                    index: index, colors: style.colors, palette: palette)
                let rows = record.values.enumerated().map { axis, value in
                    row(
                        LivelineAdvancedLayout.axisLabel(style.axisLabels, at: axis),
                        configuration.formatValue(value), color)
                }
                let finalAxis = record.values.count - 1
                let anchor = CGPoint(
                    x: geometry.x(axis: finalAxis), y: geometry.y(last, axis: finalAxis))
                return target(
                    time: Double(index), value: last, anchor: anchor, heading: record.label, rows: rows,
                    region: .circle(center: anchor, radius: 9))
            }

        case .hexbin(let points, let style):
            // The chart draws one hexagon per bin, not one mark per point, so the
            // hover targets and the tooltip totals have to describe bins too.
            guard
                let geometry = LivelineAdvancedLayout.hexbin(
                    points: points, style: style, layout: layout, textScale: textScale)
            else { return [] }
            return geometry.cells.map { cell in
                target(
                    time: Double(cell.column), value: cell.weight, anchor: cell.center,
                    heading: cell.count == 1 ? (cell.label ?? LivelineStrings.labelPoint) : nil,
                    rows: [
                        row(LivelineStrings.labelCount, "\(cell.count)", palette.line),
                        row(
                            LivelineStrings.labelWeight, configuration.formatValue(cell.weight),
                            palette.gridLabel),
                    ], region: .circle(center: cell.center, radius: max(geometry.radius, 8)))
            }

        case .marimekko(let columns, let style):
            let geometry = LivelineAdvancedLayout.marimekko(
                columns: columns, style: style, layout: layout, textScale: textScale,
                displayScale: displayScale)
            var targets: [LivelineInteractionTarget] = []
            for columnGeometry in geometry.geometry {
                let column = geometry.columns[columnGeometry.columnIndex]
                for segmentGeometry in columnGeometry.segments {
                    let segment = column.segments[segmentGeometry.segmentIndex]
                    let rect = segmentGeometry.rect
                    targets.append(
                        target(
                            time: Double(targets.count), value: segment.value,
                            anchor: CGPoint(x: rect.midX, y: rect.midY),
                            heading: "\(column.label), \(segment.label)",
                            rows: [
                                row(
                                    LivelineStrings.labelColumnWidth, configuration.formatValue(column.width),
                                    palette.gridLabel),
                                row(
                                    LivelineStrings.labelSegment, configuration.formatValue(segment.value),
                                    LivelineRenderer.advancedColor(
                                        index: geometry.colorIndexBySegmentID[segment.id] ?? 0,
                                        colors: style.colors, palette: palette)),
                            ], region: .rect(rect)))
                }
            }
            return targets

        case .polarArea(let values, let style):
            let geometry = LivelineAdvancedLayout.polarArea(
                values: values, style: style, layout: layout, textScale: textScale)
            return geometry.wedges.map { wedge in
                let anchor = LivelineMath.polarPoint(
                    center: geometry.center, radius: (geometry.innerRadius + wedge.radius) / 2,
                    angle: wedge.middle)
                return target(
                    time: Double(wedge.index), value: wedge.value.value, anchor: anchor,
                    heading: wedge.value.label,
                    rows: [
                        row(
                            LivelineStrings.labelValue, configuration.formatValue(wedge.value.value),
                            LivelineRenderer.advancedColor(
                                index: wedge.index, colors: style.colors, palette: palette))
                    ],
                    region: .sector(
                        center: geometry.center, innerRadius: geometry.innerRadius,
                        outerRadius: wedge.radius, startAngle: wedge.start, endAngle: wedge.end))
            }

        case .network(let nodes, let edges, let style):
            guard
                let geometry = LivelineAdvancedLayout.network(
                    nodes: nodes, edges: edges, style: style, layout: layout, textScale: textScale)
            else { return [] }
            return geometry.placements.map { placement in
                let color = LivelineRenderer.advancedColor(
                    index: placement.colorIndex, colors: style.colors, palette: palette)
                return target(
                    time: Double(placement.colorIndex), value: placement.node.weight,
                    anchor: placement.center, heading: placement.node.label,
                    rows: [
                        row(
                            LivelineStrings.labelWeight, configuration.formatValue(placement.node.weight),
                            color),
                        row(LivelineStrings.labelConnections, "\(placement.connections)", palette.gridLabel),
                    ],
                    region: .circle(center: placement.center, radius: max(placement.size / 2, 8)))
            }

        case .contour(let samples, _):
            guard
                let geometry = LivelineAdvancedLayout.contour(
                    samples: samples, layout: layout, textScale: textScale)
            else { return [] }
            return LivelineAdvancedLayout.contourSamplesByCoordinate(samples).map { sample in
                let point = geometry.point(x: sample.x, y: sample.y)
                return target(
                    time: sample.x, value: sample.value, anchor: point,
                    heading: "\(configuration.formatValue(sample.x)), \(configuration.formatValue(sample.y))",
                    rows: [
                        row(LivelineStrings.labelValue, configuration.formatValue(sample.value), palette.line)
                    ], region: .circle(center: point, radius: 8))
            }

        case .ternary(let points, let style):
            let valid = points.filter { $0.total > 0 }
            guard !valid.isEmpty else { return [] }
            let geometry = LivelineAdvancedLayout.ternary(
                style: style, layout: layout, textScale: textScale)
            return valid.enumerated().map { index, value in
                let center = geometry.point(value)
                let color = LivelineRenderer.advancedColor(
                    index: index, colors: style.colors, palette: palette)
                return target(
                    time: Double(index), value: value.magnitude, anchor: center, heading: value.label,
                    rows: [
                        row(geometry.labels[0], percent(value.a / value.total), color),
                        row(geometry.labels[1], percent(value.b / value.total), color),
                        row(geometry.labels[2], percent(value.c / value.total), color),
                        row(LivelineStrings.labelMagnitude, configuration.formatValue(value.magnitude), color),
                    ], region: .circle(center: center, radius: 10))
            }

        case .waffle(let values, let style):
            let geometry = LivelineAdvancedLayout.waffle(
                values: values, style: style, layout: layout, textScale: textScale)
            guard !geometry.values.isEmpty else { return [] }
            let total = geometry.values.reduce(0) { $0 + $1.value }
            let starts = geometry.categoryStartIndices
            return geometry.values.enumerated().compactMap { index, value in
                guard geometry.allocations[index] > 0 else { return nil }
                let cellIndex = min(
                    starts[index] + max(geometry.allocations[index] / 2, 0), geometry.cellCount - 1)
                let rect = geometry.rect(cellIndex: cellIndex)
                let center = CGPoint(x: rect.midX, y: rect.midY)
                return target(
                    time: Double(index), value: value.value, anchor: center, heading: value.label,
                    rows: [
                        row(
                            LivelineStrings.labelValue, configuration.formatValue(value.value),
                            LivelineRenderer.advancedColor(index: index, colors: style.colors, palette: palette)),
                        row(LivelineStrings.labelShare, percent(value.value / total), palette.gridLabel),
                    ], region: .circle(center: center, radius: max(geometry.cell / 2, 8)))
            }

        case .volumeProfile(let levels, let style):
            let geometry = LivelineAdvancedLayout.volumeProfile(
                levels: levels, style: style, layout: layout, textScale: textScale)
            guard !geometry.levels.isEmpty else { return [] }
            return geometry.levels.enumerated().map { index, level in
                let rect = geometry.rect(at: index)
                return target(
                    time: level.price, value: level.volume, anchor: CGPoint(x: rect.midX, y: rect.midY),
                    heading: configuration.formatValue(level.price),
                    rows: [
                        row(LivelineStrings.labelVolume, configuration.formatValue(level.volume), palette.line)
                    ], region: .rect(rect))
            }

        case .renko(let series, let style):
            let bricks = series.bricks
            guard !bricks.isEmpty else { return [] }
            let geometry = LivelineAdvancedLayout.renko(bricks: bricks, style: style, layout: layout)
            return bricks.enumerated().map { index, brick in
                let rect = geometry.rect(at: index, layout: layout)
                let color = brick.isRising ? (style.upColor ?? palette.line) : style.downColor
                return target(
                    time: Double(index), value: brick.close, anchor: CGPoint(x: rect.midX, y: rect.midY),
                    heading: configuration.formatTime(brick.time),
                    rows: [
                        row(LivelineStrings.labelOpen, configuration.formatValue(brick.open), color),
                        row(LivelineStrings.labelClose, configuration.formatValue(brick.close), color),
                    ], region: .rect(rect))
            }

        case .marketDepth(let levels, let style):
            guard
                let geometry = LivelineAdvancedLayout.marketDepth(
                    levels: levels, layout: layout, textScale: textScale)
            else { return [] }
            return [
                (LivelineStrings.labelBid, geometry.curve.bids, style.bidColor),
                (LivelineStrings.labelAsk, geometry.curve.asks, style.askColor),
            ].flatMap { label, points, color in
                points.map { point in
                    let center = geometry.point(point)
                    return target(
                        time: point.time, value: point.value, anchor: center,
                        heading: configuration.formatValue(point.time),
                        rows: [row(label, configuration.formatValue(point.value), color)],
                        region: .circle(center: center, radius: 8))
                }
            }

        case .pointAndFigure(let series, let style):
            let columns = series.columns
            guard !columns.isEmpty else { return [] }
            let geometry = LivelineAdvancedLayout.pointAndFigure(
                columns: columns, style: style, layout: layout, textScale: textScale)
            return columns.map { column in
                let top = geometry.y(column.high)
                let bottom = geometry.y(column.low)
                let rect = CGRect(
                    x: geometry.x(column: column) - geometry.slot / 2,
                    y: min(top, bottom), width: geometry.slot,
                    height: max(abs(bottom - top), geometry.box))
                let center = CGPoint(x: rect.midX, y: rect.midY)
                let color = column.isRising ? (style.risingColor ?? palette.line) : style.fallingColor
                return target(
                    time: Double(column.index), value: column.high, anchor: center,
                    heading: String(format: LivelineStrings.labelColumnFormat, column.index + 1),
                    rows: [
                        row(LivelineStrings.labelLow, configuration.formatValue(column.low), color),
                        row(LivelineStrings.labelHigh, configuration.formatValue(column.high), color),
                        row(LivelineStrings.labelBoxes, "\(column.boxCount)", color),
                    ], region: .rect(rect))
            }

        case .heikinAshi(let series, _):
            let visible = series.candles
                .filter { $0.time >= layout.leftEdge - 2 && $0.time <= layout.rightEdge }
            return nearestTimed(
                visible, targetLocation: targetLocation, layout: layout, time: \.time
            )
                .map { candle in
                    let center = CGPoint(
                        x: layout.x(for: candle.time), y: layout.y(for: candle.close))
                    return target(
                        time: candle.time,
                        value: candle.close,
                        anchor: center,
                        heading: configuration.formatTime(candle.time),
                        rows: ohlcRows(candle, palette: palette, configuration: configuration),
                        region: .x
                    )
                }

        case .ohlcVolume(let values, let style):
            guard
                let geometry = LivelineAdvancedLayout.ohlcVolume(
                    values: values, style: style, layout: layout)
            else { return [] }
            return nearestTimed(
                geometry.values, targetLocation: targetLocation, layout: layout, time: \.time
            ).map { value in
                let center = CGPoint(
                    x: layout.x(for: value.time), y: geometry.priceY(value.close))
                let color = value.close >= value.open ? (style.upColor ?? palette.line) : style.downColor
                let candle = LivelineCandle(
                    time: value.time, open: value.open, high: value.high, low: value.low,
                    close: value.close)
                return target(
                    time: value.time, value: value.close, anchor: center,
                    heading: configuration.formatTime(value.time),
                    rows: ohlcRows(
                        candle, palette: palette, configuration: configuration, accent: color)
                        + [
                            row(
                                LivelineStrings.labelVolume, configuration.formatValue(value.volume),
                                palette.gridLabel)
                        ],
                    region: .x)
            }
        }
    }

    private static func ohlcRows(
        _ candle: LivelineCandle,
        palette: LivelinePalette,
        configuration: LivelineChartConfiguration,
        accent: Color? = nil
    ) -> [LivelineTooltipRow] {
        let highlight = accent ?? palette.line
        return [
            row(LivelineStrings.labelOpen, configuration.formatValue(candle.open), palette.gridLabel),
            row(LivelineStrings.labelHigh, configuration.formatValue(candle.high), highlight),
            row(LivelineStrings.labelLow, configuration.formatValue(candle.low), palette.gridLabel),
            row(LivelineStrings.labelClose, configuration.formatValue(candle.close), highlight),
        ]
    }

    private static func nearestTimed<Element>(
        _ elements: [Element],
        targetLocation: CGPoint?,
        layout: LivelineLayout,
        time: KeyPath<Element, TimeInterval>
    ) -> [Element] {
        guard let targetLocation, !elements.isEmpty else { return elements }
        let targetTime = layout.time(for: targetLocation.x)
        var lower = 0
        var upper = elements.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if elements[middle][keyPath: time] < targetTime {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        if lower == 0 { return [elements[0]] }
        if lower == elements.count { return [elements[elements.count - 1]] }
        let before = elements[lower - 1]
        let after = elements[lower]
        return targetTime - before[keyPath: time] <= after[keyPath: time] - targetTime
            ? [before] : [after]
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

    private static func percent(_ fraction: Double) -> String {
        (fraction * 100).formatted(.number.precision(.fractionLength(1))) + "%"
    }
}
