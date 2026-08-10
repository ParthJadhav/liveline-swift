import SwiftUI

extension LivelineRenderer {
    static func drawAdvancedContent(
        context: inout GraphicsContext,
        state: LivelineRenderState,
        content: LivelineAdvancedChartContent,
        layout: LivelineLayout,
        palette: LivelinePalette,
        configuration: LivelineChartConfiguration,
        reveal: Double,
        textScale: LivelineTextScale,
        drawLabels: Bool
    ) {
        drawAdvanced(
            context: &context,
            state: state,
            content: content,
            layout: layout,
            palette: palette,
            configuration: configuration,
            reveal: reveal,
            textScale: textScale,
            drawMarks: true,
            drawLabels: drawLabels
        )
    }

    static func drawAdvancedLabels(
        context: inout GraphicsContext,
        state: LivelineRenderState,
        content: LivelineAdvancedChartContent,
        layout: LivelineLayout,
        palette: LivelinePalette,
        configuration: LivelineChartConfiguration,
        reveal: Double,
        textScale: LivelineTextScale
    ) {
        drawAdvanced(
            context: &context,
            state: state,
            content: content,
            layout: layout,
            palette: palette,
            configuration: configuration,
            reveal: reveal,
            textScale: textScale,
            drawMarks: false,
            drawLabels: true
        )
    }

    private static func drawAdvanced(
        context: inout GraphicsContext,
        state: LivelineRenderState,
        content: LivelineAdvancedChartContent,
        layout: LivelineLayout,
        palette: LivelinePalette,
        configuration: LivelineChartConfiguration,
        reveal: Double,
        textScale: LivelineTextScale,
        drawMarks: Bool,
        drawLabels: Bool
    ) {
        switch content {
        case .violin(let data, let style):
            drawViolins(
                context: &context, series: data, style: style, layout: layout, palette: palette,
                reveal: reveal, textScale: textScale, drawMarks: drawMarks, drawLabels: drawLabels)
        case .ridgeline(let data, let style):
            drawRidgelines(
                context: &context, series: data, style: style, layout: layout, palette: palette,
                reveal: reveal, textScale: textScale, drawMarks: drawMarks, drawLabels: drawLabels)
        case .calendarHeatmap(let data, let style):
            drawCalendarHeatmap(
                context: &context, values: data, style: style, layout: layout, palette: palette,
                reveal: reveal, textScale: textScale, drawMarks: drawMarks, drawLabels: drawLabels)
        case .gantt(let data, let style):
            drawGantt(
                context: &context, tasks: data, style: style, layout: layout, palette: palette,
                configuration: configuration, reveal: reveal, textScale: textScale, drawMarks: drawMarks,
                drawLabels: drawLabels)
        case .bump(let data, let style):
            drawBump(
                context: &context, series: data, style: style, layout: layout, palette: palette,
                reveal: reveal, textScale: textScale, drawMarks: drawMarks, drawLabels: drawLabels)
        case .horizon(let data, let style):
            drawHorizon(
                context: &context, points: data, style: style, layout: layout, palette: palette,
                reveal: reveal, drawMarks: drawMarks)
        case .chord(let data, let style):
            drawChord(
                context: &context, links: data, style: style, layout: layout, palette: palette,
                reveal: reveal, textScale: textScale, drawMarks: drawMarks, drawLabels: drawLabels)
        case .parallelCoordinates(let data, let style):
            drawParallelCoordinates(
                context: &context, records: data, style: style, layout: layout, palette: palette,
                reveal: reveal, textScale: textScale, drawMarks: drawMarks, drawLabels: drawLabels)
        case .hexbin(let data, let style):
            drawHexbin(
                context: &context, points: data, style: style, layout: layout, palette: palette,
                reveal: reveal, textScale: textScale, drawMarks: drawMarks, drawLabels: drawLabels)
        case .marimekko(let data, let style):
            drawMarimekko(
                context: &context, columns: data, style: style, layout: layout, palette: palette,
                configuration: configuration, reveal: reveal, textScale: textScale, drawMarks: drawMarks,
                drawLabels: drawLabels)
        case .polarArea(let data, let style):
            drawPolarArea(
                context: &context, values: data, style: style, layout: layout, palette: palette,
                reveal: reveal, textScale: textScale, drawMarks: drawMarks, drawLabels: drawLabels)
        case .network(let nodes, let edges, let style):
            drawNetwork(
                context: &context, nodes: nodes, edges: edges, style: style, layout: layout,
                palette: palette, reveal: reveal, textScale: textScale, drawMarks: drawMarks,
                drawLabels: drawLabels)
        case .contour(let data, let style):
            drawContour(
                context: &context, state: state, samples: data, style: style, layout: layout, palette: palette,
                configuration: configuration, reveal: reveal, textScale: textScale, drawMarks: drawMarks,
                drawLabels: drawLabels)
        case .ternary(let data, let style):
            drawTernary(
                context: &context, points: data, style: style, layout: layout, palette: palette,
                reveal: reveal, textScale: textScale, drawMarks: drawMarks, drawLabels: drawLabels)
        case .waffle(let data, let style):
            drawWaffle(
                context: &context, values: data, style: style, layout: layout, palette: palette,
                configuration: configuration, reveal: reveal, textScale: textScale, drawMarks: drawMarks,
                drawLabels: drawLabels)
        case .volumeProfile, .renko, .heikinAshi, .marketDepth, .ohlcVolume, .pointAndFigure:
            drawAdvancedFinance(
                context: &context,
                content: content,
                layout: layout,
                palette: palette,
                configuration: configuration,
                reveal: reveal,
                textScale: textScale,
                drawMarks: drawMarks,
                drawLabels: drawLabels
            )
        }
    }

    static func advancedPlotRect(_ layout: LivelineLayout) -> CGRect {
        CGRect(
            x: layout.plotLeftX,
            y: layout.padding.top,
            width: max(layout.chartWidth, 1),
            height: max(layout.chartHeight, 1)
        )
    }

    /// How many leading marks a reveal animation has uncovered.
    ///
    /// `reveal` is 0...1 progress, so the *count* is what scales with it.
    /// Rounding `reveal` itself snaps every in-flight frame to 1 and makes the
    /// whole series appear at once, which is the bug this replaced.
    static func revealedCount(_ total: Int, reveal: Double) -> Int {
        guard total > 0, reveal > 0 else { return 0 }
        guard reveal < 1 else { return total }
        return min(Int((Double(total) * reveal).rounded(.up)), total)
    }

    static func advancedColor(index: Int, colors: [Color], palette: LivelinePalette) -> Color {
        extendedSeriesColor(index: index, colors: colors, palette: palette)
    }
}

// MARK: - Distribution and planning

extension LivelineRenderer {
    static func drawViolins(
        context: inout GraphicsContext,
        series: [LivelineDistributionSeries],
        style: LivelineViolinStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        reveal: Double,
        textScale: LivelineTextScale,
        drawMarks: Bool,
        drawLabels: Bool
    ) {
        let geometry = LivelineAdvancedLayout.violin(
            series: series, style: style, layout: layout, textScale: textScale)
        guard !geometry.profiles.isEmpty else { return }
        let halfWidth = geometry.halfWidth(ratio: style.resolvedWidthRatio)

        for (index, item) in geometry.profiles.enumerated() {
            let centerX = geometry.centerX(at: index)
            let domain = item.valueDomain
            let vertical = { (value: Double) in
                mapped(value, from: domain, to: (geometry.bodyBottom, geometry.plot.minY))
            }
            let color = advancedColor(index: index, colors: style.colors, palette: palette)
            if drawMarks {
                let profile = item.profile
                var outline: [CGPoint] = []
                outline.reserveCapacity(profile.samples.count * 2)
                for sample in profile.samples {
                    let x = centerX - halfWidth * CGFloat(sample.density / profile.peakDensity) * CGFloat(reveal)
                    outline.append(CGPoint(x: x, y: vertical(sample.value)))
                }
                for sample in profile.samples.reversed() {
                    let x = centerX + halfWidth * CGFloat(sample.density / profile.peakDensity) * CGFloat(reveal)
                    outline.append(CGPoint(x: x, y: vertical(sample.value)))
                }
                let path = LivelineVisualGeometry.smoothPath(points: outline, closed: true)
                context.fill(path, with: .color(color.opacity(style.resolvedFillOpacity)))
                context.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(
                        lineWidth: style.resolvedLineWidth, lineCap: .round, lineJoin: .round))

                if style.showsQuartiles {
                    var quartile = Path()
                    quartile.move(to: CGPoint(x: centerX, y: vertical(profile.lowerQuartile)))
                    quartile.addLine(to: CGPoint(x: centerX, y: vertical(profile.upperQuartile)))
                    context.stroke(
                        quartile, with: .color(color.opacity(0.9)), lineWidth: max(style.resolvedLineWidth, 2))
                }
                if style.showsMedian {
                    let y = vertical(profile.median)
                    context.fill(
                        Path(ellipseIn: CGRect(x: centerX - 3, y: y - 3, width: 6, height: 6)),
                        with: .color(color))
                }
            }
            if drawLabels, style.showsLabels {
                drawText(
                    item.series.label, context: &context,
                    at: CGPoint(x: centerX, y: geometry.plot.maxY - textScale.scaled(5)), anchor: .bottom,
                    color: palette.gridLabel, font: textScale.font(10, weight: .medium))
            }
        }
    }

    static func drawRidgelines(
        context: inout GraphicsContext,
        series: [LivelineDistributionSeries],
        style: LivelineRidgelineStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        reveal: Double,
        textScale: LivelineTextScale,
        drawMarks: Bool,
        drawLabels: Bool
    ) {
        let geometry = LivelineAdvancedLayout.ridgeline(
            series: series, style: style, layout: layout, textScale: textScale)
        guard !geometry.profiles.isEmpty else { return }
        let body = geometry.body
        let ridgeHeight = geometry.ridgeHeight

        for (index, item) in geometry.profiles.enumerated().reversed() {
            let baseline = geometry.baseline(at: index)
            let color = advancedColor(index: index, colors: style.colors, palette: palette)
            if drawMarks {
                let profile = item.profile
                let ridgePoints = profile.samples.map { sample in
                    let x = mapped(sample.value, from: geometry.valueDomain, to: body.minX...body.maxX)
                    let y =
                        baseline - ridgeHeight * CGFloat(sample.density / profile.peakDensity) * CGFloat(reveal)
                    return CGPoint(x: x, y: y)
                }
                var path = LivelineMath.monotoneSplinePath(points: ridgePoints)
                path.addLine(to: CGPoint(x: body.maxX, y: baseline))
                path.addLine(to: CGPoint(x: body.minX, y: baseline))
                path.closeSubpath()
                context.fill(path, with: .color(color.opacity(style.resolvedFillOpacity)))
                context.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(
                        lineWidth: style.resolvedLineWidth, lineCap: .round, lineJoin: .round))
            }
            if drawLabels, style.showsLabels {
                drawText(
                    item.series.label, context: &context,
                    at: CGPoint(x: body.minX - textScale.scaled(7), y: baseline - textScale.scaled(2)),
                    anchor: .trailing, color: palette.gridLabel, font: textScale.font(10, weight: .medium))
            }
        }
    }

    static func drawCalendarHeatmap(
        context: inout GraphicsContext,
        values: [LivelineCalendarValue],
        style: LivelineCalendarHeatmapStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        reveal: Double,
        textScale: LivelineTextScale,
        drawMarks: Bool,
        drawLabels: Bool
    ) {
        guard
            let geometry = LivelineAdvancedLayout.calendar(
                values: values, style: style, layout: layout, textScale: textScale)
        else { return }
        let calendar = geometry.calendar
        let body = geometry.body
        let valuesByDay = LivelineAdvancedLayout.calendarValuesByDay(values, calendar: calendar)
        // A DateFormatter costs far more to build than to use, and the month
        // labels are drawn from inside the day loop. Build it once, and only
        // when a month label will actually be drawn.
        let monthFormatter: DateFormatter? = {
            guard drawLabels, style.showsMonthLabels else { return nil }
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.locale = calendar.locale
            formatter.dateFormat = "MMM"
            return formatter
        }()

        var labelledMonths: Set<Int> = []
        for dayOffset in 0..<geometry.totalDays {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: geometry.firstDay) else {
                continue
            }
            let rect = geometry.rect(dayOffset: dayOffset)
            let entry = valuesByDay[date]
            let ratio = max(entry?.value ?? 0, 0) / geometry.maximumValue
            let color = calendarHeatColor(ratio: ratio, style: style, palette: palette)
            if drawMarks {
                let radius = min(style.resolvedCornerRadius, geometry.cell / 3)
                context.fill(
                    Path(roundedRect: rect, cornerRadius: radius),
                    with: .color(
                        color.opacity((entry == nil ? style.resolvedEmptyOpacity : max(0.16, ratio)) * reveal)))
            }
            guard let monthFormatter else { continue }
            let monthComponents = calendar.dateComponents([.era, .year, .month], from: date)
            let monthKey =
                (monthComponents.era ?? 0) * 100_000 + (monthComponents.year ?? 0) * 100
                + (monthComponents.month ?? 0)
            if labelledMonths.insert(monthKey).inserted {
                drawText(
                    monthFormatter.string(from: date), context: &context,
                    at: CGPoint(x: rect.minX, y: body.minY - textScale.scaled(6)), anchor: .bottomLeading,
                    color: palette.gridLabel, font: textScale.font(9, weight: .medium))
            }
        }

        if drawLabels, style.showsWeekdayLabels {
            let labels = calendar.veryShortWeekdaySymbols
            for row in [0, 2, 4, 6] {
                let index = (calendar.firstWeekday - 1 + row) % 7
                drawText(
                    labels[index], context: &context,
                    at: CGPoint(
                        x: body.minX - textScale.scaled(5),
                        y: body.minY + CGFloat(row) * (geometry.cell + geometry.spacing) + geometry.cell / 2),
                    anchor: .trailing,
                    color: palette.gridLabel, font: textScale.font(8, weight: .regular))
            }
        }
    }

    static func calendarHeatColor(
        ratio: Double, style: LivelineCalendarHeatmapStyle, palette: LivelinePalette
    ) -> Color {
        guard !style.colorScale.isEmpty else { return palette.line }
        let index = min(
            Int((ratio * Double(style.colorScale.count)).rounded(.down)), style.colorScale.count - 1)
        return style.colorScale[max(index, 0)]
    }

    static func drawGantt(
        context: inout GraphicsContext,
        tasks: [LivelineGanttTask],
        style: LivelineGanttStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        configuration: LivelineChartConfiguration,
        reveal: Double,
        textScale: LivelineTextScale,
        drawMarks: Bool,
        drawLabels: Bool
    ) {
        guard !tasks.isEmpty else { return }
        let geometry = LivelineAdvancedLayout.gantt(
            tasks: tasks, style: style, layout: layout, textScale: textScale)
        let taskByID = LivelineAdvancedLayout.ganttTasksByID(tasks)

        if drawMarks, style.showsDependencies {
            for task in tasks {
                for dependencyID in task.dependencyIDs {
                    guard let dependency = taskByID[dependencyID] else { continue }
                    let start = CGPoint(
                        x: layout.x(for: dependency.end), y: geometry.laneCenterY(dependency.lane))
                    let end = CGPoint(x: layout.x(for: task.start), y: geometry.laneCenterY(task.lane))
                    var path = Path()
                    path.move(to: start)
                    let bend = (start.x + end.x) / 2
                    path.addLine(to: CGPoint(x: bend, y: start.y))
                    path.addLine(to: CGPoint(x: bend, y: end.y))
                    path.addLine(to: end)
                    context.stroke(
                        path, with: .color(palette.referenceLine),
                        style: StrokeStyle(lineWidth: 1, lineJoin: .round))
                }
            }
        }

        for (index, task) in tasks.enumerated() {
            let rect = geometry.rect(for: task, layout: layout, reveal: reveal)
            let color = advancedColor(index: index, colors: style.colors, palette: palette)
            if drawMarks {
                let radius = min(style.resolvedCornerRadius, rect.height / 2)
                context.fill(
                    Path(roundedRect: rect, cornerRadius: radius), with: .color(color.opacity(0.24)))
                if style.showsProgress, task.progress > 0 {
                    let progress = CGRect(
                        x: rect.minX, y: rect.minY, width: rect.width * CGFloat(task.progress),
                        height: rect.height)
                    var clipped = context
                    clipped.clip(to: Path(roundedRect: rect, cornerRadius: radius))
                    clipped.fill(Path(progress), with: .color(color.opacity(0.82)))
                } else {
                    context.stroke(
                        Path(roundedRect: rect, cornerRadius: radius), with: .color(color), lineWidth: 1.25)
                }
            }
            if drawLabels, style.showsLabels, rect.width >= textScale.scaled(34) {
                var labelLayer = context
                labelLayer.clip(to: Path(rect.insetBy(dx: 3, dy: 0)))
                drawText(
                    task.label, context: &labelLayer,
                    at: CGPoint(x: rect.minX + textScale.scaled(5), y: rect.midY), anchor: .leading,
                    color: palette.tooltipText, font: textScale.font(9, weight: .medium))
            }
        }
    }

    static func drawBump(
        context: inout GraphicsContext,
        series: [LivelineRankSeries],
        style: LivelineBumpStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        reveal: Double,
        textScale: LivelineTextScale,
        drawMarks: Bool,
        drawLabels: Bool
    ) {
        guard
            let geometry = LivelineAdvancedLayout.bump(
                series: series, style: style, layout: layout, textScale: textScale)
        else { return }
        let body = geometry.body
        for (index, entry) in series.enumerated() where !entry.points.isEmpty {
            let color = advancedColor(index: index, colors: style.colors, palette: palette)
            var path = Path()
            for (pointIndex, point) in entry.points.enumerated() {
                let x = geometry.x(time: point.time)
                let y = geometry.y(rank: point.rank)
                pointIndex == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
                if drawMarks, style.showsPoints {
                    let size = style.resolvedPointSize * CGFloat(reveal)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - size / 2, y: y - size / 2, width: size, height: size)),
                        with: .color(color))
                }
            }
            if drawMarks {
                var layer = context
                layer.opacity *= reveal
                layer.stroke(
                    path, with: .color(color),
                    style: StrokeStyle(lineWidth: style.resolvedLineWidth, lineCap: .round, lineJoin: .round))
            }
        }
        if drawLabels, style.showsEndLabels {
            let spacing = textScale.scaled(13)
            let labels = series.enumerated().compactMap { index, entry -> (String, Color, CGFloat)? in
                guard let last = entry.points.last else { return nil }
                return (
                    entry.label, advancedColor(index: index, colors: style.colors, palette: palette),
                    geometry.y(rank: last.rank)
                )
            }
            let positions = LivelineVisualGeometry.distributedLabelPositions(
                labels.map { $0.2 },
                minimum: body.minY,
                maximum: body.maxY,
                spacing: spacing
            )
            for (label, y) in zip(labels, positions) {
                drawText(
                    label.0, context: &context, at: CGPoint(x: body.maxX + textScale.scaled(7), y: y),
                    anchor: .leading, color: label.1, font: textScale.font(9, weight: .semibold))
            }
        }
    }

    static func drawHorizon(
        context: inout GraphicsContext,
        points: [LivelinePoint],
        style: LivelineHorizonStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        reveal: Double,
        drawMarks: Bool
    ) {
        guard drawMarks, points.count >= 2 else { return }
        let visible = points.livelineVisible(in: (layout.leftEdge - 2)...layout.rightEdge)
        guard !visible.isEmpty else { return }
        let plot = advancedPlotRect(layout)
        let maximum = max(visible.map { abs($0.value) }.max() ?? 0, 0.000_001)
        let bandHeight = maximum / Double(style.resolvedBandCount)
        let positive = style.positiveColor ?? palette.line
        var layer = context
        layer.clip(to: Path(plot))
        for band in 0..<style.resolvedBandCount {
            let opacity = (0.28 + 0.62 * Double(band + 1) / Double(style.resolvedBandCount)) * reveal
            for sign in [1.0, -1.0] {
                let folded = visible.map { point -> CGPoint in
                    let magnitude = min(max(abs(point.value) - Double(band) * bandHeight, 0), bandHeight)
                    let height = CGFloat(magnitude / bandHeight) * plot.height
                    let y = sign * point.value >= 0 ? plot.maxY - height : plot.maxY
                    return CGPoint(x: layout.x(for: point.time), y: y)
                }
                var path = LivelineMath.monotoneSplinePath(points: folded)
                path.addLine(to: CGPoint(x: folded.last?.x ?? plot.maxX, y: plot.maxY))
                path.addLine(to: CGPoint(x: folded.first?.x ?? plot.minX, y: plot.maxY))
                path.closeSubpath()
                layer.fill(
                    path, with: .color((sign > 0 ? positive : style.negativeColor).opacity(opacity)))
            }
        }
        if style.showsBaseline {
            var baseline = Path()
            baseline.move(to: CGPoint(x: plot.minX, y: plot.maxY))
            baseline.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
            layer.stroke(
                baseline, with: .color(palette.referenceLine),
                style: StrokeStyle(
                    lineWidth: style.resolvedLineWidth, lineCap: .round, lineJoin: .round))
        }
    }
}

extension LivelineRenderer {
    static func mapped(
        _ value: Double, from domain: ClosedRange<Double>, to range: ClosedRange<CGFloat>
    ) -> CGFloat {
        let t = (value - domain.lowerBound) / max(domain.upperBound - domain.lowerBound, 0.000_001)
        return range.lowerBound + CGFloat(t) * (range.upperBound - range.lowerBound)
    }

    static func mapped(
        _ value: Double, from domain: ClosedRange<Double>, to range: (CGFloat, CGFloat)
    ) -> CGFloat {
        let t = (value - domain.lowerBound) / max(domain.upperBound - domain.lowerBound, 0.000_001)
        return range.0 + CGFloat(t) * (range.1 - range.0)
    }
}
