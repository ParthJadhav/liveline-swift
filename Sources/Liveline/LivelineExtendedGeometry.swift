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

struct LivelineHistogramBar {
    var bin: LivelineHistogramBin
    var rect: CGRect
    var reveal: Double
}

struct LivelineHistogramGeometry {
    var progress: Double
    /// The sample range the bars span, which is what the horizontal axis shows.
    var valueRange: ClosedRange<Double>
    var barWidth: CGFloat
    var color: Color
    var bars: [LivelineHistogramBar]
}

struct LivelineBulletBand {
    var range: LivelineBulletRange
    var rect: CGRect
    var color: Color
}

struct LivelineBulletGeometry {
    var progress: Double
    var plotRect: CGRect
    var trackRect: CGRect
    var measureRect: CGRect
    var bands: [LivelineBulletBand]
    var axisRange: ClosedRange<Double>
    var measureProgress: Double
    var targetProgress: Double?
    var targetX: CGFloat?
    var displayedMeasure: Double
    /// Carried on the geometry so the label pass — which never sees the layout
    /// — can anchor the caption and the value on the right sides.
    var isRTL: Bool = false
}

extension LivelineRenderer {
    static func timelineGeometry(
        items: [LivelineTimelineItem],
        totalLaneCount: Int? = nil,
        style: LivelineTimelineStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        reveal: Double
    ) -> LivelineTimelineGeometry {
        let progress = LivelineMath.easedReveal(reveal)
        let visibleLaneCount = (items.map(\.lane).max() ?? 0) + 1
        let laneCount = max(totalLaneCount ?? visibleLaneCount, visibleLaneCount, 1)
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
        totalRowCount: Int? = nil,
        style: LivelineHeatmapStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        reveal: Double
    ) -> LivelineHeatmapGeometry {
        let progress = LivelineMath.easedReveal(reveal)
        let visibleRowCount = (cells.map(\.row).max() ?? 0) + 1
        let rowCount = max(totalRowCount ?? visibleRowCount, visibleRowCount, style.rowLabels.count, 1)
        let rowHeight = layout.chartHeight / CGFloat(rowCount)
        // Heatmap cells repeat a time per row and are not pre-sorted, so this
        // kind still needs an explicit unique-and-sorted projection.
        let cellWidth = bucketWidth(
            sortedTimes: Set(cells.map(\.time)).sorted(),
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

    /// Bars sit side by side across the whole plot width — the horizontal axis
    /// is the sample range, not time — and grow up from the value axis' zero.
    static func histogramGeometry(
        bins: [LivelineHistogramBin],
        style: LivelineHistogramStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        reveal: Double
    ) -> LivelineHistogramGeometry {
        let progress = LivelineMath.easedReveal(reveal)
        let color = style.color ?? palette.line
        let lower = bins.first?.lowerBound ?? 0
        let upper = bins.last?.upperBound ?? lower
        let valueRange = lower <= upper ? lower...upper : upper...lower
        guard !bins.isEmpty else {
            return LivelineHistogramGeometry(
                progress: progress,
                valueRange: valueRange,
                barWidth: 0,
                color: color,
                bars: []
            )
        }

        let slotWidth = layout.chartWidth / CGFloat(bins.count)
        let barWidth = max(slotWidth - style.resolvedBarSpacing, 1)
        let baselineY = LivelineMath.clamp(layout.y(for: 0), layout.padding.top, layout.bottomY)
        let bars = bins.enumerated().compactMap { index, bin -> LivelineHistogramBar? in
            let localReveal = LivelineMath.staggeredReveal(index: index, count: bins.count, reveal: reveal)
            guard localReveal > 0.001 else { return nil }
            let topY = layout.y(for: Double(bin.count))
            let height = max((baselineY - topY) * CGFloat(localReveal), 0)
            // Bins ascend along the value axis, which follows the reading
            // direction just like the time axis does.
            let x = layout.plotLeftX + CGFloat(index) * slotWidth + (slotWidth - barWidth) / 2
            return LivelineHistogramBar(
                bin: bin,
                rect: layout.mirrored(CGRect(x: x, y: baselineY - height, width: barWidth, height: height)),
                reveal: localReveal
            )
        }
        return LivelineHistogramGeometry(
            progress: progress,
            valueRange: valueRange,
            barWidth: barWidth,
            color: color,
            bars: bars
        )
    }

    /// Layered horizontal geometry: qualitative bands behind a thinner measure
    /// bar, both anchored to the axis' lower bound, plus the target tick.
    static func bulletGeometry(
        style: LivelineBulletStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        reveal: Double
    ) -> LivelineBulletGeometry {
        let progress = LivelineMath.easedReveal(reveal)
        let plotRect = CGRect(
            x: layout.plotLeftX,
            y: layout.padding.top,
            width: layout.chartWidth,
            height: layout.chartHeight
        )
        let axisRange = style.resolvedAxisRange
        let centerY = plotRect.midY
        let trackHeight = max(plotRect.height * style.resolvedBarHeightRatio, 6)
        let measureHeight = max(plotRect.height * style.resolvedMeasureHeightRatio, 3)
        let trackRect = CGRect(
            x: plotRect.minX,
            y: centerY - trackHeight / 2,
            width: plotRect.width,
            height: trackHeight
        )

        // The measure grows from the axis' lower bound toward the reading
        // direction: rightwards in LTR, leftwards in RTL.
        func x(for value: Double) -> CGFloat {
            layout.mirrored(
                plotRect.minX + CGFloat(LivelineMath.bulletProgress(value: value, range: axisRange)) * plotRect.width
            )
        }

        let ranges = style.resolvedRanges
        let bands = ranges.enumerated().map { index, range -> LivelineBulletBand in
            let startValue = index == 0 ? axisRange.lowerBound : ranges[index - 1].value
            let startX = x(for: startValue)
            // A band never runs backwards past its own start, whichever way
            // "forward" points.
            let endX = layout.isRTL
                ? min(x(for: range.value), startX)
                : max(x(for: range.value), startX)
            let color = range.color
                ?? extendedSeriesColor(index: index, colors: [], palette: palette)
            return LivelineBulletBand(
                range: range,
                rect: CGRect(
                    x: min(startX, endX),
                    y: trackRect.minY,
                    width: abs(endX - startX),
                    height: trackRect.height
                ),
                color: color
            )
        }

        let measureProgress = LivelineMath.bulletProgress(value: style.resolvedMeasure, range: axisRange)
        let measureWidth = plotRect.width * CGFloat(measureProgress) * CGFloat(progress)
        let measureRect = layout.mirrored(
            CGRect(
                x: plotRect.minX,
                y: centerY - measureHeight / 2,
                width: max(measureWidth, 0),
                height: measureHeight
            )
        )
        let targetProgress = style.resolvedTarget.map {
            LivelineMath.bulletProgress(value: $0, range: axisRange)
        }
        return LivelineBulletGeometry(
            progress: progress,
            plotRect: plotRect,
            trackRect: trackRect,
            measureRect: measureRect,
            bands: bands,
            axisRange: axisRange,
            measureProgress: measureProgress,
            targetProgress: targetProgress,
            targetX: style.resolvedTarget.map { x(for: $0) },
            displayedMeasure: axisRange.lowerBound
                + (style.resolvedMeasure - axisRange.lowerBound) * progress,
            isRTL: layout.isRTL
        )
    }

    static func plotCenter(_ layout: LivelineLayout) -> CGPoint {
        CGPoint(x: (layout.plotLeftX + layout.rightX) / 2, y: layout.padding.top + layout.chartHeight / 2)
    }
}

struct LivelineTreemapCell {
    var node: LivelineTreemapNode
    /// The top-level node this cell belongs to, when the cell is a child.
    var parentLabel: String?
    var rect: CGRect
    var color: Color
    /// Multiplier applied on top of the style's fill opacity, used to separate
    /// siblings that share a group colour.
    var opacity: Double
    var value: Double
    /// Fraction of the whole treemap this cell occupies, in `0...1`.
    var share: Double
    var reveal: Double
}

struct LivelineTreemapGeometry {
    var progress: Double
    var plotRect: CGRect
    var total: Double
    var cells: [LivelineTreemapCell]
}

struct LivelineSunburstSegment {
    var span: LivelineSunburstSpan
    var label: String
    var value: Double
    var color: Color
    var innerRadius: CGFloat
    var outerRadius: CGFloat
    /// The span's end after the reveal animation has swept it.
    var revealedEnd: Double
    var isFullyRevealed: Bool
    /// Fraction of the whole sunburst this segment's own value represents.
    var share: Double

    var pathRadius: CGFloat { (innerRadius + outerRadius) / 2 }
    var ringWidth: CGFloat { max(outerRadius - innerRadius, 1) }
}

struct LivelineSunburstGeometry {
    var progress: Double
    var center: CGPoint
    var innerRadius: CGFloat
    var outerRadius: CGFloat
    var total: Double
    var segments: [LivelineSunburstSegment]
}

struct LivelineSankeyNodeMark {
    var node: LivelineSankeyNode
    var index: Int
    var rect: CGRect
    var color: Color
}

struct LivelineSankeyLinkMark {
    var link: LivelineSankeyResolvedLink
    var sourceLabel: String
    var targetLabel: String
    var path: Path
    var color: Color
    var thickness: CGFloat
    /// The ribbon's midpoint, used as the hover anchor.
    var anchor: CGPoint
}

struct LivelineSankeyGeometry {
    var progress: Double
    var plotRect: CGRect
    var total: Double
    var nodes: [LivelineSankeyNodeMark]
    var links: [LivelineSankeyLinkMark]
}

extension LivelineRenderer {
    /// Squarified cells across the whole plot. The layout itself is a pure
    /// function of the values and the rectangle — this pass only attaches
    /// colours, shares, and the reveal stagger.
    static func treemapGeometry(
        nodes: [LivelineTreemapNode],
        tiles: [LivelineTreemapTile],
        style: LivelineTreemapStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        reveal: Double
    ) -> LivelineTreemapGeometry {
        let progress = LivelineMath.easedReveal(reveal)
        let plotRect = CGRect(
            x: layout.plotLeftX,
            y: layout.padding.top,
            width: layout.chartWidth,
            height: layout.chartHeight
        )
        let total = nodes.reduce(0) { $0 + $1.resolvedValue }
        let cells = tiles.enumerated().compactMap { index, tile -> LivelineTreemapCell? in
            guard let topIndex = tile.path.first, nodes.indices.contains(topIndex) else { return nil }
            let parent = nodes[topIndex]
            let node: LivelineTreemapNode
            let childIndex: Int?
            if tile.path.count > 1, parent.children.indices.contains(tile.path[1]) {
                node = parent.children[tile.path[1]]
                childIndex = tile.path[1]
            } else {
                node = parent
                childIndex = nil
            }
            let localReveal = LivelineMath.staggeredReveal(index: index, count: tiles.count, reveal: reveal)
            guard localReveal > 0.001 else { return nil }
            let base = node.color
                ?? parent.color
                ?? extendedSeriesColor(index: topIndex, colors: style.colors, palette: palette)
            // Siblings inside a group share the parent's hue, separated by a
            // shallow opacity ramp rather than a second unrelated colour.
            let opacity = childIndex.map { max(1 - Double($0) * 0.11, 0.55) } ?? 1
            return LivelineTreemapCell(
                node: node,
                parentLabel: childIndex == nil ? nil : parent.label,
                // Cells tile the plot in reading order, so a right-to-left
                // layout mirrors them just like it mirrors a bar chart.
                rect: layout.mirrored(tile.rect),
                color: base,
                opacity: opacity,
                value: tile.value,
                share: total > 0 ? tile.value / total : 0,
                reveal: localReveal
            )
        }
        return LivelineTreemapGeometry(progress: progress, plotRect: plotRect, total: total, cells: cells)
    }

    /// Two concentric rings of annular segments. Radial kinds are never
    /// mirrored: a right-to-left reader still reads a ring clockwise.
    static func sunburstGeometry(
        nodes: [LivelineSunburstNode],
        style: LivelineSunburstStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        reveal: Double
    ) -> LivelineSunburstGeometry {
        let progress = LivelineMath.easedReveal(reveal)
        let center = plotCenter(layout)
        let outerRadius = max(12, min(layout.chartWidth, layout.chartHeight) * (style.showsLabels ? 0.36 : 0.45))
        let holeRadius = outerRadius * style.resolvedInnerRadiusRatio
        let spacing = min(style.resolvedRingSpacing, max(outerRadius - holeRadius - 4, 0))
        let band = max(outerRadius - holeRadius - spacing, 2)
        let innerThickness = max(band * style.resolvedInnerRingRatio, 1)
        let outerThickness = max(band - innerThickness, 1)
        let total = nodes.reduce(0) { $0 + $1.resolvedValue }

        let spans = LivelineMath.sunburstSpans(nodes: nodes, gapDegrees: style.resolvedGapDegrees)
        let segments = spans.compactMap { span -> LivelineSunburstSegment? in
            guard let topIndex = span.path.first, nodes.indices.contains(topIndex) else { return nil }
            let parent = nodes[topIndex]
            let node: LivelineSunburstNode
            let childIndex: Int?
            if span.depth == 1, parent.children.indices.contains(span.path[1]) {
                node = parent.children[span.path[1]]
                childIndex = span.path[1]
            } else {
                node = parent
                childIndex = nil
            }
            let base = node.color
                ?? parent.color
                ?? extendedSeriesColor(index: topIndex, colors: style.colors, palette: palette)
            let color = childIndex.map { base.opacity(max(1 - Double($0) * 0.13, 0.5)) } ?? base
            let inner = span.depth == 0 ? holeRadius : holeRadius + innerThickness + spacing
            let outer = span.depth == 0 ? holeRadius + innerThickness : holeRadius + innerThickness + spacing + outerThickness
            let revealedEnd = span.start + (span.end - span.start) * progress
            return LivelineSunburstSegment(
                span: span,
                label: node.label,
                value: span.value,
                color: color,
                innerRadius: inner,
                outerRadius: outer,
                revealedEnd: revealedEnd,
                isFullyRevealed: progress >= 0.98,
                share: total > 0 ? span.value / total : 0
            )
        }
        return LivelineSunburstGeometry(
            progress: progress,
            center: center,
            innerRadius: holeRadius,
            outerRadius: outerRadius,
            total: total,
            segments: segments
        )
    }

    /// Node bars per column with cubic ribbons between them. The columns run in
    /// the reading direction, so a right-to-left layout flows right to left.
    static func sankeyGeometry(
        links: [LivelineSankeyLink],
        graph: LivelineSankeyGraph,
        style: LivelineSankeyStyle,
        layout: LivelineLayout,
        palette: LivelinePalette,
        reveal: Double
    ) -> LivelineSankeyGeometry {
        let progress = LivelineMath.easedReveal(reveal)
        let plotRect = CGRect(
            x: layout.plotLeftX,
            y: layout.padding.top,
            width: layout.chartWidth,
            height: layout.chartHeight
        )
        guard !graph.nodes.isEmpty, graph.columnCount > 0, plotRect.width > 0, plotRect.height > 0 else {
            return LivelineSankeyGeometry(
                progress: progress,
                plotRect: plotRect,
                total: graph.total,
                nodes: [],
                links: []
            )
        }

        let nodeWidth = min(style.resolvedNodeWidth, plotRect.width / CGFloat(max(graph.columnCount, 1)) / 2)
        let spacing = style.resolvedNodeSpacing
        let columns = (0..<graph.columnCount).map { graph.indices(inColumn: $0) }

        // One value-to-pixel scale shared by every column, so a node's height
        // means the same thing wherever it sits.
        var scale = CGFloat.greatestFiniteMagnitude
        for column in columns where !column.isEmpty {
            let throughput = column.reduce(0) { $0 + graph.nodes[$1].throughput }
            let available = plotRect.height - spacing * CGFloat(column.count - 1)
            guard throughput > 0, available > 0 else { continue }
            scale = min(scale, available / CGFloat(throughput))
        }
        guard scale.isFinite, scale > 0 else {
            return LivelineSankeyGeometry(
                progress: progress,
                plotRect: plotRect,
                total: graph.total,
                nodes: [],
                links: []
            )
        }

        let columnStep = graph.columnCount > 1
            ? (plotRect.width - nodeWidth) / CGFloat(graph.columnCount - 1)
            : 0
        var rects = [CGRect](repeating: .zero, count: graph.nodes.count)
        for (columnIndex, column) in columns.enumerated() {
            guard !column.isEmpty else { continue }
            let heights = column.map { max(CGFloat(graph.nodes[$0].throughput) * scale, 1) }
            let stackHeight = heights.reduce(0, +) + spacing * CGFloat(column.count - 1)
            var y = plotRect.minY + (plotRect.height - stackHeight) / 2
            let x = plotRect.minX + CGFloat(columnIndex) * columnStep
            for (offset, nodeIndex) in column.enumerated() {
                rects[nodeIndex] = CGRect(x: x, y: y, width: nodeWidth, height: heights[offset])
                y += heights[offset] + spacing
            }
        }

        // Ribbons stack at both ends in link order — the same order the caller
        // wrote them, which is what keeps the picture stable across frames.
        var sourceCursor = [CGFloat](repeating: 0, count: graph.nodes.count)
        var targetCursor = [CGFloat](repeating: 0, count: graph.nodes.count)
        let linkMarks = graph.links.compactMap { link -> LivelineSankeyLinkMark? in
            let sourceRect = rects[link.sourceIndex]
            let targetRect = rects[link.targetIndex]
            let thickness = max(CGFloat(link.value) * scale, 1)
            let startY = sourceRect.minY + sourceCursor[link.sourceIndex]
            let endY = targetRect.minY + targetCursor[link.targetIndex]
            sourceCursor[link.sourceIndex] += thickness
            targetCursor[link.targetIndex] += thickness

            let x1 = sourceRect.maxX
            let x2 = targetRect.minX
            guard x2 > x1 else { return nil }
            let sweep = (x2 - x1) * CGFloat(progress)
            let controlOffset = (x2 - x1) / 2
            var path = Path()
            path.move(to: CGPoint(x: x1, y: startY))
            path.addCurve(
                to: CGPoint(x: x1 + sweep, y: startY + (endY - startY) * CGFloat(progress)),
                control1: CGPoint(x: x1 + controlOffset, y: startY),
                control2: CGPoint(x: x2 - controlOffset, y: endY)
            )
            path.addLine(to: CGPoint(
                x: x1 + sweep,
                y: startY + (endY - startY) * CGFloat(progress) + thickness
            ))
            path.addCurve(
                to: CGPoint(x: x1, y: startY + thickness),
                control1: CGPoint(x: x2 - controlOffset, y: endY + thickness),
                control2: CGPoint(x: x1 + controlOffset, y: startY + thickness)
            )
            path.closeSubpath()

            let color = links.indices.contains(link.linkIndex) ? links[link.linkIndex].color : nil
            return LivelineSankeyLinkMark(
                link: link,
                sourceLabel: graph.nodes[link.sourceIndex].label,
                targetLabel: graph.nodes[link.targetIndex].label,
                path: layout.mirrored(path),
                color: color ?? extendedSeriesColor(
                    index: link.sourceIndex,
                    colors: style.colors,
                    palette: palette
                ),
                thickness: thickness,
                anchor: CGPoint(
                    x: layout.mirrored((x1 + x2) / 2),
                    y: (startY + endY) / 2 + thickness / 2
                )
            )
        }

        let nodeMarks = graph.nodes.enumerated().compactMap { index, node -> LivelineSankeyNodeMark? in
            guard rects[index].height > 0 else { return nil }
            return LivelineSankeyNodeMark(
                node: node,
                index: index,
                rect: layout.mirrored(rects[index]),
                color: extendedSeriesColor(index: index, colors: style.colors, palette: palette)
            )
        }
        return LivelineSankeyGeometry(
            progress: progress,
            plotRect: plotRect,
            total: graph.total,
            nodes: nodeMarks,
            links: linkMarks
        )
    }
}
