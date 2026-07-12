import Foundation
import SwiftUI

struct LivelineTimelineMark {
    var item: LivelineTimelineItem
    var rect: CGRect
    var color: Color
    var reveal: Double
}

struct LivelineTimelineGeometry {
    var progress: Double
    var laneCount: Int
    var laneHeight: CGFloat
    var barHeight: CGFloat
    var marks: [LivelineTimelineMark]
}

struct LivelineHeatmapMark {
    var cell: LivelineHeatmapCell
    var rect: CGRect
    var color: Color
    var opacity: Double
    var reveal: Double
}

struct LivelineHeatmapGeometry {
    var progress: Double
    var rowCount: Int
    var rowHeight: CGFloat
    var cellWidth: CGFloat
    var cellHeight: CGFloat
    var marks: [LivelineHeatmapMark]
}

struct LivelineRadarGeometry {
    var progress: Double
    var center: CGPoint
    var radius: CGFloat
    var angleStep: Double
    var startAngle: Double
    var valuePoints: [CGPoint]
}

struct LivelineDonutSegment {
    var entry: LivelineCategoryValue
    var color: Color
    var startDegrees: Double
    var endDegrees: Double
    var fullStartAngle: Double
    var fullEndAngle: Double
    var middleAngle: Double
    var isFullyRevealed: Bool
}

struct LivelineDonutGeometry {
    var progress: Double
    var center: CGPoint
    var outerRadius: CGFloat
    var innerRadius: CGFloat
    var pathRadius: CGFloat
    var ringWidth: CGFloat
    var total: Double
    var segments: [LivelineDonutSegment]
}

struct LivelineGaugeRenderGeometry {
    var plotRect: CGRect
    var gauge: LivelineGaugeGeometry
    var reveal: Double
    var revealProgress: Double
    var valueProgress: Double
    var targetProgress: Double?
    var startDegrees: Double
    var endDegrees: Double
    var displayedValue: Double
}

struct LivelineFunnelStage {
    var entry: LivelineCategoryValue
    var rect: CGRect
    var color: Color
    var reveal: Double
}

struct LivelineFunnelGeometry {
    var progress: Double
    var stageHeight: CGFloat
    var stages: [LivelineFunnelStage]
}

extension LivelineRenderer {
    static func timelineGeometry(
        items: [LivelineTimelineItem],
        style: LivelineTimelineStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        reveal: Double
    ) -> LivelineTimelineGeometry {
        let progress = LivelineMath.easedReveal(reveal)
        let laneCount = max((items.map(\.lane).max() ?? 0) + 1, 1)
        let laneHeight = layout.chartHeight / CGFloat(laneCount)
        let barHeight = max(laneHeight * style.resolvedBarHeightRatio, 3)
        let marks = items.enumerated().compactMap { index, item -> LivelineTimelineMark? in
            let localReveal = LivelineMath.staggeredReveal(index: index, count: items.count, reveal: reveal)
            guard localReveal > 0.001 else { return nil }
            let x1 = layout.x(for: item.start)
            let x2 = layout.x(for: item.end)
            let displayedX2 = x1 + (x2 - x1) * CGFloat(localReveal)
            let y = layout.padding.top + (CGFloat(item.lane) + 0.5) * laneHeight
            return LivelineTimelineMark(
                item: item,
                rect: CGRect(
                    x: min(x1, displayedX2),
                    y: y - barHeight / 2,
                    width: max(abs(displayedX2 - x1), 2),
                    height: barHeight
                ),
                color: extendedSeriesColor(index: index, colors: style.colors, palette: palette),
                reveal: localReveal
            )
        }
        return LivelineTimelineGeometry(
            progress: progress,
            laneCount: laneCount,
            laneHeight: laneHeight,
            barHeight: barHeight,
            marks: marks
        )
    }

    static func heatmapGeometry(
        cells: [LivelineHeatmapCell],
        style: LivelineHeatmapStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        reveal: Double
    ) -> LivelineHeatmapGeometry {
        let progress = LivelineMath.easedReveal(reveal)
        let rowCount = max((cells.map(\.row).max() ?? 0) + 1, style.rowLabels.count, 1)
        let rowHeight = layout.chartHeight / CGFloat(rowCount)
        let cellWidth = bucketWidth(
            times: Array(Set(cells.map(\.time))).sorted(),
            layout: layout,
            ratio: style.resolvedCellWidthRatio,
            maximum: .greatestFiniteMagnitude
        )
        let cellHeight = max(rowHeight * style.resolvedCellHeightRatio, 1)
        let minimum = cells.map(\.value).min() ?? 0
        let maximum = cells.map(\.value).max() ?? minimum
        let baseColor = style.color ?? palette.line
        let baseRGB = baseColor.livelineRGBA()
        let orderedCells = cells.sorted {
            $0.time == $1.time ? $0.row < $1.row : $0.time < $1.time
        }
        let marks = orderedCells.enumerated().compactMap { index, cell -> LivelineHeatmapMark? in
            let localReveal = LivelineMath.staggeredReveal(index: index, count: orderedCells.count, reveal: reveal)
            guard localReveal > 0.001 else { return nil }
            let opacity = LivelineMath.heatmapOpacity(
                value: cell.value,
                minimum: minimum,
                maximum: maximum,
                minimumOpacity: style.resolvedMinimumOpacity,
                maximumOpacity: style.resolvedMaximumOpacity
            )
            let color = baseRGB.map { palette.backgroundRGB.blended(to: $0, t: opacity).color }
                ?? baseColor.opacity(opacity)
            let centerY = layout.padding.top + (CGFloat(cell.row) + 0.5) * rowHeight
            let displayedWidth = cellWidth * CGFloat(localReveal)
            let displayedHeight = cellHeight * CGFloat(localReveal)
            return LivelineHeatmapMark(
                cell: cell,
                rect: CGRect(
                    x: layout.x(for: cell.time) - displayedWidth / 2,
                    y: centerY - displayedHeight / 2,
                    width: displayedWidth,
                    height: displayedHeight
                ),
                color: color,
                opacity: opacity,
                reveal: localReveal
            )
        }
        return LivelineHeatmapGeometry(
            progress: progress,
            rowCount: rowCount,
            rowHeight: rowHeight,
            cellWidth: cellWidth,
            cellHeight: cellHeight,
            marks: marks
        )
    }

    static func radarGeometry(
        points: [LivelineRadarPoint],
        style: LivelineRadarStyle,
        layout: LivelineLayout,
        reveal: Double
    ) -> LivelineRadarGeometry {
        let progress = LivelineMath.easedReveal(reveal)
        let center = plotCenter(layout)
        let radius = max(8, min(layout.chartWidth, layout.chartHeight) / 2 - (style.showsLabels ? 30 : 8))
        let angleStep = points.isEmpty ? 0 : 2 * Double.pi / Double(points.count)
        let startAngle = -Double.pi / 2
        let valuePoints = points.enumerated().map { index, point -> CGPoint in
            let valueProgress = LivelineMath.clamp(
                (point.value - style.resolvedRange.lowerBound) / (style.resolvedRange.upperBound - style.resolvedRange.lowerBound),
                0,
                1
            )
            return LivelineMath.polarPoint(
                center: center,
                radius: radius * CGFloat(valueProgress * progress),
                angle: startAngle + Double(index) * angleStep
            )
        }
        return LivelineRadarGeometry(
            progress: progress,
            center: center,
            radius: radius,
            angleStep: angleStep,
            startAngle: startAngle,
            valuePoints: valuePoints
        )
    }

    static func donutGeometry(
        data: [LivelineCategoryValue],
        style: LivelineDonutStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        reveal: Double
    ) -> LivelineDonutGeometry {
        let positive = data.filter { $0.value > 0 }
        let total = positive.map(\.value).reduce(0, +)
        let progress = LivelineMath.easedReveal(reveal)
        let center = plotCenter(layout)
        let outerRadius = max(12, min(layout.chartWidth, layout.chartHeight) * (style.showsLabels ? 0.34 : 0.43))
        let innerRadius = outerRadius * style.resolvedInnerRadiusRatio
        let ringWidth = max(2, outerRadius - innerRadius)
        let pathRadius = innerRadius + ringWidth / 2
        var cursor = -90.0
        var consumedSweep = 0.0
        let visibleSweep = 360 * progress
        let segments = positive.enumerated().map { index, entry -> LivelineDonutSegment in
            let sweep = total > 0 ? entry.value / total * 360 : 0
            let gap = min(style.resolvedGapDegrees, sweep * 0.7)
            let revealedSweep = LivelineMath.clamp(visibleSweep - consumedSweep, 0, sweep)
            let start = cursor + gap / 2
            let end = cursor + revealedSweep - gap / 2
            let fullStart = cursor * Double.pi / 180
            let fullEnd = (cursor + sweep) * Double.pi / 180
            let middle = (fullStart + fullEnd) / 2
            defer {
                cursor += sweep
                consumedSweep += sweep
            }
            return LivelineDonutSegment(
                entry: entry,
                color: extendedSeriesColor(index: index, colors: style.colors, palette: palette),
                startDegrees: start,
                endDegrees: end,
                fullStartAngle: fullStart,
                fullEndAngle: fullEnd,
                middleAngle: middle,
                isFullyRevealed: revealedSweep >= sweep * 0.98
            )
        }
        return LivelineDonutGeometry(
            progress: progress,
            center: center,
            outerRadius: outerRadius,
            innerRadius: innerRadius,
            pathRadius: pathRadius,
            ringWidth: ringWidth,
            total: total,
            segments: segments
        )
    }

    static func gaugeRenderGeometry(
        value: Double,
        range: ClosedRange<Double>,
        style: LivelineGaugeStyle,
        layout: LivelineLayout,
        reveal: Double
    ) -> LivelineGaugeRenderGeometry {
        let plotRect = CGRect(
            x: layout.plotLeftX,
            y: layout.padding.top,
            width: layout.chartWidth,
            height: layout.chartHeight
        )
        let gauge = LivelineMath.gaugeGeometry(
            in: plotRect,
            startAngleDegrees: style.resolvedStartAngleDegrees,
            sweepDegrees: style.resolvedSweepDegrees,
            lineWidth: style.resolvedLineWidth,
            hasOuterMarks: style.showsTicks || style.resolvedTarget != nil,
            showsValue: style.showsValue
        )
        return LivelineGaugeRenderGeometry(
            plotRect: plotRect,
            gauge: gauge,
            reveal: reveal,
            revealProgress: LivelineMath.easedReveal(reveal),
            valueProgress: LivelineMath.gaugeProgress(value: value, range: range),
            targetProgress: style.resolvedTarget.map { LivelineMath.gaugeProgress(value: $0, range: range) },
            startDegrees: style.resolvedStartAngleDegrees,
            endDegrees: style.resolvedStartAngleDegrees + style.resolvedSweepDegrees,
            displayedValue: range.lowerBound + (value - range.lowerBound) * LivelineMath.easedReveal(reveal)
        )
    }

    static func funnelGeometry(
        data: [LivelineCategoryValue],
        style: LivelineFunnelStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        reveal: Double
    ) -> LivelineFunnelGeometry {
        let positive = data.filter { $0.value > 0 }
        let progress = LivelineMath.easedReveal(reveal)
        let maximum = positive.map(\.value).max() ?? 1
        let stageHeight = positive.isEmpty ? 0 : max(
            8,
            (layout.chartHeight - style.resolvedSpacing * CGFloat(max(positive.count - 1, 0))) / CGFloat(positive.count)
        )
        let maxWidth = layout.chartWidth * style.resolvedMaximumWidthRatio
        let minWidth = layout.chartWidth * style.resolvedMinimumWidthRatio
        let centerX = (layout.plotLeftX + layout.rightX) / 2
        let stages = positive.enumerated().compactMap { index, entry -> LivelineFunnelStage? in
            let localReveal = LivelineMath.staggeredReveal(
                index: index,
                count: positive.count,
                reveal: reveal,
                staggerFraction: 0.5
            )
            guard localReveal > 0.001 else { return nil }
            let targetWidth = minWidth + CGFloat(entry.value / maximum) * (maxWidth - minWidth)
            let width = targetWidth * CGFloat(localReveal)
            let y = layout.padding.top + CGFloat(index) * (stageHeight + style.resolvedSpacing)
            return LivelineFunnelStage(
                entry: entry,
                rect: CGRect(x: centerX - width / 2, y: y, width: width, height: stageHeight),
                color: extendedSeriesColor(index: index, colors: style.colors, palette: palette),
                reveal: localReveal
            )
        }
        return LivelineFunnelGeometry(progress: progress, stageHeight: stageHeight, stages: stages)
    }

    static func plotCenter(_ layout: LivelineLayout) -> CGPoint {
        CGPoint(x: (layout.plotLeftX + layout.rightX) / 2, y: layout.padding.top + layout.chartHeight / 2)
    }
}
