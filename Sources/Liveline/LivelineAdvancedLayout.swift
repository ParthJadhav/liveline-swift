import SwiftUI

/// The single source of truth for where every advanced chart places its marks.
///
/// Drawing and hit testing are two readers of the same geometry. When each one
/// derives its own plot rect, gutters, and slot widths the two drift silently:
/// the tooltip lands beside the mark it names, or a series that fails to produce
/// a density profile shifts every remaining hit region by one slot. Both passes
/// go through this file so a layout change is impossible to apply to only one of
/// them.
///
/// Layouts are pure functions of the content, the style, and the resolved
/// `LivelineLayout`. They never touch `GraphicsContext`, so the interaction
/// builder can call them outside a draw pass.
enum LivelineAdvancedLayout {}

// MARK: - Distributions

/// A distribution paired with the profile that was actually derived for it.
///
/// `densityProfile` returns nil for a series with no finite observations, so the
/// drawn slots are indexed by *this* array rather than by the caller's input.
struct LivelineDistributionProfile {
    var series: LivelineDistributionSeries
    var profile: LivelineDensityProfile

    var valueDomain: ClosedRange<Double> {
        let lower = profile.samples.first?.value ?? profile.minimum
        let upper = profile.samples.last?.value ?? profile.maximum
        return lower <= upper ? lower...upper : upper...lower
    }
}
struct LivelineViolinLayout {
    var profiles: [LivelineDistributionProfile]
    var plot: CGRect
    var bodyBottom: CGFloat
    var slot: CGFloat
    var valueDomain: ClosedRange<Double>

    func centerX(at index: Int) -> CGFloat { plot.minX + slot * (CGFloat(index) + 0.5) }

    func halfWidth(ratio: CGFloat) -> CGFloat { slot * ratio * 0.5 }

    /// The full-height column a violin occupies, used as its hit region.
    func slotRect(at index: Int) -> CGRect {
        CGRect(
            x: plot.minX + CGFloat(index) * slot,
            y: plot.minY,
            width: slot,
            height: max(bodyBottom - plot.minY, 1)
        )
    }
}

struct LivelineRidgelineLayout {
    var profiles: [LivelineDistributionProfile]
    var body: CGRect
    var rowStride: CGFloat
    var ridgeHeight: CGFloat
    var valueDomain: ClosedRange<Double>

    func baseline(at index: Int) -> CGFloat { body.minY + ridgeHeight + rowStride * CGFloat(index) }

    func rowRect(at index: Int) -> CGRect {
        let top = max(baseline(at: index) - ridgeHeight, body.minY)
        return CGRect(
            x: body.minX,
            y: top,
            width: body.width,
            height: min(ridgeHeight, body.maxY - top)
        )
    }
}

extension LivelineAdvancedLayout {
    static func distributionProfiles(
        _ series: [LivelineDistributionSeries],
        bandwidth: Double?
    ) -> [LivelineDistributionProfile] {
        series.compactMap { entry in
            LivelineAdvancedMath.densityProfile(values: entry.values, bandwidth: bandwidth)
                .map { LivelineDistributionProfile(series: entry, profile: $0) }
        }
    }

    static func violin(
        series: [LivelineDistributionSeries],
        style: LivelineViolinStyle,
        layout: LivelineLayout,
        textScale: LivelineTextScale,
        profiles suppliedProfiles: [LivelineDistributionProfile]? = nil
    ) -> LivelineViolinLayout {
        let profiles = suppliedProfiles ?? distributionProfiles(series, bandwidth: style.bandwidth)
        let plot = LivelineRenderer.advancedPlotRect(layout)
            .insetBy(dx: textScale.scaled(4), dy: textScale.scaled(4))
        let labelHeight = style.showsLabels ? textScale.scaled(22) : 0
        let lower = profiles.compactMap { $0.profile.samples.first?.value }.min() ?? 0
        let upper = profiles.compactMap { $0.profile.samples.last?.value }.max() ?? 1
        return LivelineViolinLayout(
            profiles: profiles,
            plot: plot,
            bodyBottom: plot.maxY - labelHeight,
            slot: plot.width / CGFloat(max(profiles.count, 1)),
            valueDomain: lower <= upper ? lower...upper : upper...lower
        )
    }

    static func ridgeline(
        series: [LivelineDistributionSeries],
        style: LivelineRidgelineStyle,
        layout: LivelineLayout,
        textScale: LivelineTextScale,
        profiles suppliedProfiles: [LivelineDistributionProfile]? = nil
    ) -> LivelineRidgelineLayout {
        let profiles = suppliedProfiles ?? distributionProfiles(series, bandwidth: style.bandwidth)
        let plot = LivelineRenderer.advancedPlotRect(layout)
            .insetBy(dx: textScale.scaled(4), dy: textScale.scaled(8))
        let labelWidth = style.showsLabels ? min(textScale.scaled(82), layout.chartWidth * 0.24) : 0
        let body = CGRect(
            x: plot.minX + labelWidth,
            y: plot.minY,
            width: max(plot.width - labelWidth, 1),
            height: plot.height
        )
        let rowStride =
            body.height / CGFloat(max(Double(profiles.count) + Double(style.resolvedOverlap), 1))
        let lower = profiles.compactMap { $0.profile.samples.first?.value }.min() ?? 0
        let upper = profiles.compactMap { $0.profile.samples.last?.value }.max() ?? 1
        return LivelineRidgelineLayout(
            profiles: profiles,
            body: body,
            rowStride: rowStride,
            ridgeHeight: rowStride * (1 + style.resolvedOverlap),
            valueDomain: lower <= upper ? lower...upper : upper...lower
        )
    }
}

// MARK: - Calendar

struct LivelineCalendarLayout {
    var calendar: Calendar
    var firstDay: Date
    var totalDays: Int
    /// Weekday slots before the first day, so day 0 lands on its real weekday row.
    var leadingOffset: Int
    var body: CGRect
    var cell: CGFloat
    var spacing: CGFloat
    var originX: CGFloat
    var maximumValue: Double

    /// `dayOffset` counts civil days from `firstDay`.
    func rect(dayOffset: Int) -> CGRect {
        let index = dayOffset + leadingOffset
        return CGRect(
            x: originX + CGFloat(index / 7) * (cell + spacing),
            y: body.minY + CGFloat(index % 7) * (cell + spacing),
            width: cell,
            height: cell
        )
    }
}

extension LivelineAdvancedLayout {
    static func calendar(
        values: [LivelineCalendarValue],
        style: LivelineCalendarHeatmapStyle,
        layout: LivelineLayout,
        textScale: LivelineTextScale
    ) -> LivelineCalendarLayout? {
        guard let firstDate = values.first?.date, let lastDate = values.last?.date else { return nil }
        var calendar = style.calendar
        calendar.locale = calendar.locale ?? .current
        let firstDay = calendar.startOfDay(for: firstDate)
        let lastDay = calendar.startOfDay(for: lastDate)
        let weekday = calendar.component(.weekday, from: firstDay)
        let leadingOffset = (weekday - calendar.firstWeekday + 7) % 7
        let totalDays = (calendar.dateComponents([.day], from: firstDay, to: lastDay).day ?? 0) + 1
        let weeks = max(Int(ceil(Double(totalDays + leadingOffset) / 7)), 1)
        let weekdayGutter = style.showsWeekdayLabels ? textScale.scaled(22) : 0
        let monthGutter = style.showsMonthLabels ? textScale.scaled(18) : 0
        let plot = LivelineRenderer.advancedPlotRect(layout)
            .insetBy(dx: textScale.scaled(4), dy: textScale.scaled(4))
        let body = CGRect(
            x: plot.minX + weekdayGutter,
            y: plot.minY + monthGutter,
            width: max(plot.width - weekdayGutter, 1),
            height: max(plot.height - monthGutter, 1)
        )
        let requestedSpacing = style.resolvedCellSpacing
        let spacing = min(
            requestedSpacing,
            min(
                weeks > 1 ? body.width / CGFloat(weeks - 1) : requestedSpacing,
                body.height / 6
            ) * 0.9
        )
        let cell = min(
            (body.width - spacing * CGFloat(max(weeks - 1, 0))) / CGFloat(weeks),
            (body.height - spacing * 6) / 7
        )
        let usedWidth = cell * CGFloat(weeks) + spacing * CGFloat(max(weeks - 1, 0))
        return LivelineCalendarLayout(
            calendar: calendar,
            firstDay: firstDay,
            totalDays: totalDays,
            leadingOffset: leadingOffset,
            body: body,
            cell: max(cell, 0.1),
            spacing: spacing,
            originX: body.minX + max((body.width - usedWidth) / 2, 0),
            maximumValue: max(
                calendarValuesByDay(values, calendar: calendar).values
                    .map(\.value).filter { $0 > 0 }.max() ?? 0,
                0.000_001
            )
        )
    }

    /// Collapses same-day entries onto the single cell that represents them.
    ///
    /// Two observations can legitimately share a civil day (a duplicate import,
    /// or two timestamps either side of midnight in the style's calendar), and
    /// `normalized()` only sorts. The last entry for a day wins, matching the
    /// sorted order the caller already relies on.
    static func calendarValuesByDay(
        _ values: [LivelineCalendarValue],
        calendar: Calendar
    ) -> [Date: LivelineCalendarValue] {
        var result: [Date: LivelineCalendarValue] = [:]
        result.reserveCapacity(values.count)
        for value in values {
            result[calendar.startOfDay(for: value.date)] = value
        }
        return result
    }
}

// MARK: - Gantt

struct LivelineGanttLayout {
    var plot: CGRect
    var slot: CGFloat
    var rowSpacing: CGFloat

    func laneCenterY(_ lane: Int) -> CGFloat { plot.minY + slot * (CGFloat(lane) + 0.5) }

    /// `reveal` grows the bar horizontally while the chart animates in; hit
    /// testing asks for the settled bar by leaving it at 1.
    func rect(for task: LivelineGanttTask, layout: LivelineLayout, reveal: Double = 1) -> CGRect {
        let x1 = layout.x(for: task.start)
        let x2 = layout.x(for: task.end)
        let width = max(abs(x2 - x1) * CGFloat(reveal), 2)
        return CGRect(
            x: layout.isRTL ? max(x1, x2) - width : min(x1, x2),
            y: plot.minY + slot * CGFloat(task.lane) + rowSpacing / 2,
            width: width,
            height: max(slot - rowSpacing, 2)
        )
    }
}

extension LivelineAdvancedLayout {
    static func gantt(
        tasks: [LivelineGanttTask],
        style: LivelineGanttStyle,
        layout: LivelineLayout,
        textScale: LivelineTextScale
    ) -> LivelineGanttLayout {
        let laneCount = max((tasks.map(\.lane).max() ?? 0) + 1, 1)
        let plot = LivelineRenderer.advancedPlotRect(layout)
            .insetBy(dx: textScale.scaled(2), dy: textScale.scaled(4))
        return LivelineGanttLayout(
            plot: plot,
            slot: plot.height / CGFloat(laneCount),
            rowSpacing: min(style.resolvedRowSpacing, plot.height / CGFloat(laneCount) * 0.9)
        )
    }

    /// Duplicate task identifiers are legal input, so this keeps the first task
    /// for an identifier instead of trapping the way `uniqueKeysWithValues` does.
    static func ganttTasksByID(_ tasks: [LivelineGanttTask]) -> [String: LivelineGanttTask] {
        var result: [String: LivelineGanttTask] = [:]
        result.reserveCapacity(tasks.count)
        for task in tasks where result[task.id] == nil {
            result[task.id] = task
        }
        return result
    }
}

// MARK: - Bump

struct LivelineBumpLayout {
    var body: CGRect
    var rankDomain: ClosedRange<Double>
    var lowerRankIsBetter: Bool
    var timeDomain: ClosedRange<TimeInterval>
    var isRTL: Bool

    func x(time: TimeInterval) -> CGFloat {
        let x = LivelineRenderer.mapped(time, from: timeDomain, to: body.minX...body.maxX)
        return isRTL ? body.minX + body.maxX - x : x
    }

    func y(rank: Double) -> CGFloat {
        let span = max(rankDomain.upperBound - rankDomain.lowerBound, 0.000_001)
        let t = (rank - rankDomain.lowerBound) / span
        return body.minY + CGFloat(lowerRankIsBetter ? t : 1 - t) * body.height
    }

    /// Finds the visible slice without walking an arbitrarily long live history.
    /// The input model is time-sorted, so two binary searches reduce each render
    /// pass to O(log n + visible points).
    func visibleIndexRange(
        in points: [LivelineRankPoint],
        includingBoundaryPoints: Bool
    ) -> ClosedRange<Int>? {
        guard !points.isEmpty else { return nil }

        var low = 0
        var high = points.count
        while low < high {
            let middle = low + (high - low) / 2
            if points[middle].time < timeDomain.lowerBound {
                low = middle + 1
            } else {
                high = middle
            }
        }
        let firstVisible = low

        low = firstVisible
        high = points.count
        while low < high {
            let middle = low + (high - low) / 2
            if points[middle].time <= timeDomain.upperBound {
                low = middle + 1
            } else {
                high = middle
            }
        }
        let visibleEnd = low
        guard firstVisible < visibleEnd else { return nil }
        let first = includingBoundaryPoints ? max(firstVisible - 1, 0) : firstVisible
        let last = includingBoundaryPoints ? min(visibleEnd, points.count - 1) : visibleEnd - 1
        return first...last
    }
}

extension LivelineAdvancedLayout {
    static func bump(
        series: [LivelineRankSeries],
        style: LivelineBumpStyle,
        layout: LivelineLayout,
        textScale: LivelineTextScale
    ) -> LivelineBumpLayout? {
        let ranks = series.flatMap(\.points).map(\.rank)
        guard let minimum = ranks.min(), let maximum = ranks.max() else { return nil }
        let labelReserve =
            style.showsEndLabels ? min(textScale.scaled(82), layout.chartWidth * 0.26) : 0
        let plot = LivelineRenderer.advancedPlotRect(layout)
            .insetBy(dx: textScale.scaled(3), dy: textScale.scaled(8))
        return LivelineBumpLayout(
            body: CGRect(
                x: plot.minX + (layout.isRTL ? labelReserve : 0),
                y: plot.minY,
                width: max(plot.width - labelReserve, 1),
                height: plot.height
            ),
            rankDomain: minimum...maximum,
            lowerRankIsBetter: style.lowerRankIsBetter,
            timeDomain: layout.leftEdge...(layout.leftEdge == layout.rightEdge
                ? layout.rightEdge + 1 : layout.rightEdge),
            isRTL: layout.isRTL
        )
    }
}
