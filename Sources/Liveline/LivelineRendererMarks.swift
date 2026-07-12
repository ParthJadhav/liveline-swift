import Foundation
import SwiftUI

extension LivelineRenderer {
    static func drawBars(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        points: [LivelinePoint],
        style: LivelineBarStyle,
        reveal: Double
    ) {
        let progress = LivelineMath.easedReveal(reveal)
        guard !points.isEmpty, progress > 0.001 else { return }
        var layer = context
        layer.clip(to: plotClip(layout))

        let baselineY = LivelineMath.clamp(layout.y(for: style.resolvedBaseline), layout.padding.top, layout.bottomY)
        if style.showsBaseline {
            var baselineLayer = layer
            baselineLayer.opacity *= min(progress * 2, 1)
            drawBaseline(context: &baselineLayer, layout: layout, palette: palette, value: style.resolvedBaseline)
        }

        let width = bucketWidth(
            times: points.map(\.time),
            layout: layout,
            ratio: style.resolvedWidthRatio,
            minimum: 1,
            maximum: 48
        )

        for (index, point) in points.enumerated() {
            let localReveal = LivelineMath.staggeredReveal(index: index, count: points.count, reveal: reveal)
            guard localReveal > 0.001 else { continue }
            let x = layout.x(for: point.time)
            let valueY = LivelineMath.clamp(layout.y(for: point.value), layout.padding.top, layout.bottomY)
            let displayedY = baselineY + (valueY - baselineY) * CGFloat(localReveal)
            let top = min(displayedY, baselineY)
            let height = max(abs(displayedY - baselineY), 1)
            let rect = CGRect(x: x - width / 2, y: top, width: width, height: height)
            let radius = min(style.resolvedCornerRadius, width / 2, height / 2)
            let color = point.value >= style.resolvedBaseline ? (style.positiveColor ?? palette.line) : style.negativeColor
            var markLayer = layer
            markLayer.opacity *= min(localReveal * 2, 1)
            markLayer.fill(Path(roundedRect: rect, cornerRadius: radius), with: .color(color))
        }
    }

    @discardableResult
    static func drawRangeBand(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        points: [LivelineRangePoint],
        style: LivelineRangeStyle,
        reveal: Double
    ) -> [LivelinePoint] {
        let progress = LivelineMath.easedReveal(reveal)
        guard !points.isEmpty, progress > 0.001 else { return [] }
        let normalized = points.map { point in
            (
                time: point.time,
                lower: min(point.lower, point.upper),
                upper: max(point.lower, point.upper),
                midpoint: (point.lower + point.upper) / 2
            )
        }
        let upperPoints = normalized.map { CGPoint(x: layout.x(for: $0.time), y: layout.y(for: $0.upper)) }
        let lowerPoints = normalized.map { CGPoint(x: layout.x(for: $0.time), y: layout.y(for: $0.lower)) }
        let midpointData = normalized.map { LivelinePoint(time: $0.time, value: $0.midpoint) }

        var layer = context
        layer.clip(to: plotClip(layout))

        if upperPoints.count == 1, let upper = upperPoints.first, let lower = lowerPoints.first {
            let markerWidth = max(style.resolvedBoundaryLineWidth * 2, 4)
            let midpointY = (upper.y + lower.y) / 2
            let displayedUpperY = midpointY + (upper.y - midpointY) * CGFloat(progress)
            let displayedLowerY = midpointY + (lower.y - midpointY) * CGFloat(progress)
            let markerRect = LivelineMath.verticalRangeMarkerRect(
                x: upper.x,
                upperY: displayedUpperY,
                lowerY: displayedLowerY,
                width: markerWidth
            )
            let marker = Path(roundedRect: markerRect, cornerRadius: markerWidth / 2)

            if style.resolvedFillOpacity > 0 {
                layer.fill(marker, with: .color(palette.line.opacity(style.resolvedFillOpacity)))
            }
            if style.resolvedBoundaryLineWidth > 0 {
                layer.stroke(
                    marker,
                    with: .color(palette.line),
                    style: StrokeStyle(lineWidth: style.resolvedBoundaryLineWidth, lineCap: .round, lineJoin: .round)
                )
            }
            if style.showsCenterLine, style.resolvedCenterLineWidth > 0 {
                let diameter = max(style.resolvedCenterLineWidth * 2, 3)
                let center = CGPoint(x: upper.x, y: midpointY)
                layer.fill(
                    Path(ellipseIn: CGRect(
                        x: center.x - diameter / 2,
                        y: center.y - diameter / 2,
                        width: diameter,
                        height: diameter
                    )),
                    with: .color(palette.line.opacity(0.9))
                )
            }

            return midpointData
        }

        let visibleUpper = LivelineMath.revealedPoints(upperPoints, reveal: progress)
        let visibleLower = LivelineMath.revealedPoints(lowerPoints, reveal: progress)

        var band = Path()
        if let first = visibleUpper.first {
            band.move(to: first)
            for point in visibleUpper.dropFirst() { band.addLine(to: point) }
            for point in visibleLower.reversed() { band.addLine(to: point) }
            band.closeSubpath()
            layer.fill(band, with: .color(palette.line.opacity(style.resolvedFillOpacity)))
        }

        if style.resolvedBoundaryLineWidth > 0 {
            layer.stroke(
                linePath(points: visibleUpper),
                with: .color(palette.line),
                style: StrokeStyle(lineWidth: style.resolvedBoundaryLineWidth, lineCap: .round, lineJoin: .round)
            )
            layer.stroke(
                linePath(points: visibleLower),
                with: .color(palette.line.opacity(0.72)),
                style: StrokeStyle(lineWidth: style.resolvedBoundaryLineWidth, lineCap: .round, lineJoin: .round)
            )
        }

        if style.showsCenterLine, style.resolvedCenterLineWidth > 0 {
            let centerPoints = zip(visibleUpper, visibleLower).map { pair in
                CGPoint(x: pair.0.x, y: (pair.0.y + pair.1.y) / 2)
            }
            layer.stroke(
                LivelineMath.monotoneSplinePath(points: centerPoints),
                with: .color(palette.line.opacity(0.9)),
                style: StrokeStyle(lineWidth: style.resolvedCenterLineWidth, lineCap: .round, lineJoin: .round, dash: [5, 4])
            )
        }

        return midpointData
    }

    static func drawScatter(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        points: [LivelinePoint],
        style: LivelineScatterStyle,
        reveal: Double
    ) {
        let progress = LivelineMath.easedReveal(reveal)
        guard !points.isEmpty, progress > 0.001 else { return }
        let screenPoints = points.map { CGPoint(x: layout.x(for: $0.time), y: layout.y(for: $0.value)) }
        var layer = context
        layer.clip(to: plotClip(layout))

        if style.connection != .none, screenPoints.count >= 2, style.resolvedConnectionLineWidth > 0 {
            let visibleConnection = LivelineMath.revealedPoints(screenPoints, reveal: progress)
            let connectionPath = style.connection == .curved
                ? LivelineMath.monotoneSplinePath(points: visibleConnection)
                : linePath(points: visibleConnection)
            layer.stroke(
                connectionPath,
                with: .color(palette.line.opacity(0.42)),
                style: StrokeStyle(lineWidth: style.resolvedConnectionLineWidth, lineCap: .round, lineJoin: .round)
            )
        }

        for (index, point) in screenPoints.enumerated() {
            let localReveal = LivelineMath.staggeredReveal(index: index, count: screenPoints.count, reveal: reveal)
            let size = style.resolvedPointSize * CGFloat(localReveal)
            guard size > 0.1 else { continue }
            let path = scatterSymbolPath(symbol: style.symbol, center: point, size: size)
            layer.fill(path, with: .color(palette.line))
            if style.resolvedOutlineWidth > 0 {
                layer.stroke(path, with: .color(palette.backgroundRGB.color), lineWidth: style.resolvedOutlineWidth)
            }
        }
    }

    static func drawSteps(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        points: [LivelinePoint],
        style: LivelineStepStyle,
        reveal: Double
    ) {
        let progress = LivelineMath.easedReveal(reveal)
        guard !points.isEmpty, progress > 0.001 else { return }
        let samples = points.map { CGPoint(x: layout.x(for: $0.time), y: layout.y(for: $0.value)) }
        let stepped = LivelineMath.revealedPoints(
            LivelineMath.stepScreenPoints(points: samples, position: style.position),
            reveal: progress
        )
        var layer = context
        layer.clip(to: plotClip(layout))

        if style.resolvedFillOpacity > 0, let first = stepped.first, let last = stepped.last {
            var fill = Path()
            fill.move(to: CGPoint(x: first.x, y: layout.bottomY))
            for point in stepped { fill.addLine(to: point) }
            fill.addLine(to: CGPoint(x: last.x, y: layout.bottomY))
            fill.closeSubpath()
            layer.fill(fill, with: .color(palette.line.opacity(style.resolvedFillOpacity)))
        }

        if style.resolvedLineWidth > 0 {
            layer.stroke(
                linePath(points: stepped),
                with: .color(palette.line),
                style: StrokeStyle(lineWidth: style.resolvedLineWidth, lineCap: .round, lineJoin: .round)
            )
        }

        if stepped.count == 1, let point = stepped.first {
            let size = max(style.resolvedLineWidth * 2, 4)
            layer.fill(Path(ellipseIn: CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)), with: .color(palette.line))
        }
    }

    static func drawLollipops(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        points: [LivelinePoint],
        style: LivelineLollipopStyle,
        reveal: Double
    ) {
        let progress = LivelineMath.easedReveal(reveal)
        guard !points.isEmpty, progress > 0.001 else { return }
        var layer = context
        layer.clip(to: plotClip(layout))
        let baselineY = LivelineMath.clamp(layout.y(for: style.resolvedBaseline), layout.padding.top, layout.bottomY)

        if style.showsBaseline {
            var baselineLayer = layer
            baselineLayer.opacity *= min(progress * 2, 1)
            drawBaseline(context: &baselineLayer, layout: layout, palette: palette, value: style.resolvedBaseline)
        }

        for (index, point) in points.enumerated() {
            let localReveal = LivelineMath.staggeredReveal(index: index, count: points.count, reveal: reveal)
            guard localReveal > 0.001 else { continue }
            let targetCenter = CGPoint(
                x: layout.x(for: point.time),
                y: LivelineMath.clamp(layout.y(for: point.value), layout.padding.top, layout.bottomY)
            )
            let center = CGPoint(
                x: targetCenter.x,
                y: baselineY + (targetCenter.y - baselineY) * CGFloat(localReveal)
            )
            let color = point.value >= style.resolvedBaseline ? (style.positiveColor ?? palette.line) : style.negativeColor

            if style.resolvedStemWidth > 0 {
                var stem = Path()
                stem.move(to: CGPoint(x: center.x, y: baselineY))
                stem.addLine(to: center)
                layer.stroke(stem, with: .color(color.opacity(0.72)), style: StrokeStyle(lineWidth: style.resolvedStemWidth, lineCap: .round))
            }

            let head = scatterSymbolPath(
                symbol: style.headSymbol,
                center: center,
                size: style.resolvedHeadSize * CGFloat(localReveal)
            )
            layer.fill(head, with: .color(color))
            if style.resolvedOutlineWidth > 0 {
                layer.stroke(head, with: .color(palette.backgroundRGB.color), lineWidth: style.resolvedOutlineWidth)
            }
        }
    }

    static func drawBubbles(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        points: [LivelineBubblePoint],
        style: LivelineBubbleStyle,
        reveal: Double
    ) {
        let progress = LivelineMath.easedReveal(reveal)
        guard !points.isEmpty, progress > 0.001 else { return }
        let minimumMagnitude = points.map(\.magnitude).min() ?? 0
        let maximumMagnitude = points.map(\.magnitude).max() ?? minimumMagnitude
        let marks = points.enumerated().map { index, point in
            (
                index: index,
                point: point,
                size: LivelineMath.bubbleDiameter(
                    magnitude: point.magnitude,
                    minimumMagnitude: minimumMagnitude,
                    maximumMagnitude: maximumMagnitude,
                    minimumSize: style.resolvedMinimumSize,
                    maximumSize: style.resolvedMaximumSize,
                    scale: style.scale
                )
            )
        }.sorted { $0.size > $1.size }

        var layer = context
        layer.clip(to: plotClip(layout))

        for mark in marks {
            let localReveal = LivelineMath.staggeredReveal(index: mark.index, count: points.count, reveal: reveal)
            let size = mark.size * CGFloat(localReveal)
            guard size > 0.1 else { continue }
            let inset = size / 2 + style.resolvedOutlineWidth / 2
            let center = CGPoint(
                x: LivelineMath.clamp(layout.x(for: mark.point.time), layout.plotLeftX + inset, layout.rightX - inset),
                y: LivelineMath.clamp(layout.y(for: mark.point.value), layout.padding.top + inset, layout.bottomY - inset)
            )
            let bubble = Path(ellipseIn: CGRect(
                x: center.x - size / 2,
                y: center.y - size / 2,
                width: size,
                height: size
            ))
            layer.fill(bubble, with: .color(palette.line.opacity(style.resolvedFillOpacity)))
            if style.resolvedOutlineWidth > 0 {
                layer.stroke(bubble, with: .color(palette.line), lineWidth: style.resolvedOutlineWidth)
            }
        }
    }

    static func drawBoxPlots(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        points: [LivelineBoxPlotPoint],
        style: LivelineBoxPlotStyle,
        reveal: Double
    ) {
        let progress = LivelineMath.easedReveal(reveal)
        guard !points.isEmpty, progress > 0.001 else { return }
        let width = bucketWidth(
            times: points.map(\.time),
            layout: layout,
            ratio: style.resolvedWidthRatio,
            minimum: 3,
            maximum: 40
        )
        let whiskerWidth = width * style.resolvedWhiskerWidthRatio

        var layer = context
        layer.clip(to: plotClip(layout))

        for (index, point) in points.enumerated() {
            let localReveal = LivelineMath.staggeredReveal(index: index, count: points.count, reveal: reveal)
            guard localReveal > 0.001 else { continue }
            let x = layout.x(for: point.time)
            let medianY = layout.y(for: point.median)
            let local = CGFloat(localReveal)
            let minimumY = medianY + (layout.y(for: point.minimum) - medianY) * local
            let lowerQuartileY = medianY + (layout.y(for: point.lowerQuartile) - medianY) * local
            let upperQuartileY = medianY + (layout.y(for: point.upperQuartile) - medianY) * local
            let maximumY = medianY + (layout.y(for: point.maximum) - medianY) * local

            if style.resolvedOutlineWidth > 0 {
                var whiskers = Path()
                whiskers.move(to: CGPoint(x: x, y: minimumY))
                whiskers.addLine(to: CGPoint(x: x, y: maximumY))
                whiskers.move(to: CGPoint(x: x - whiskerWidth / 2, y: minimumY))
                whiskers.addLine(to: CGPoint(x: x + whiskerWidth / 2, y: minimumY))
                whiskers.move(to: CGPoint(x: x - whiskerWidth / 2, y: maximumY))
                whiskers.addLine(to: CGPoint(x: x + whiskerWidth / 2, y: maximumY))
                layer.stroke(whiskers, with: .color(palette.line.opacity(0.72)), lineWidth: style.resolvedOutlineWidth)
            }

            let box = CGRect(
                x: x - width / 2,
                y: min(upperQuartileY, lowerQuartileY),
                width: width,
                height: max(abs(lowerQuartileY - upperQuartileY), 1)
            )
            let boxPath = Path(roundedRect: box, cornerRadius: min(2, width / 4))
            if style.resolvedFillOpacity > 0 {
                layer.fill(boxPath, with: .color(palette.line.opacity(style.resolvedFillOpacity)))
            }
            if style.resolvedOutlineWidth > 0 {
                layer.stroke(boxPath, with: .color(palette.line), lineWidth: style.resolvedOutlineWidth)
            }
            if style.resolvedMedianLineWidth > 0 {
                var median = Path()
                median.move(to: CGPoint(x: box.minX, y: medianY))
                median.addLine(to: CGPoint(x: box.minX + box.width * local, y: medianY))
                layer.stroke(median, with: .color(palette.line), lineWidth: style.resolvedMedianLineWidth)
            }
        }
    }

    static func drawWaterfall(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        segments: [LivelineWaterfallSegment],
        style: LivelineWaterfallStyle,
        reveal: Double
    ) {
        let progress = LivelineMath.easedReveal(reveal)
        guard !segments.isEmpty, progress > 0.001 else { return }
        let width = bucketWidth(
            times: segments.map(\.time),
            layout: layout,
            ratio: style.resolvedWidthRatio,
            maximum: 48
        )

        var layer = context
        layer.clip(to: plotClip(layout))

        if style.showsBaseline {
            var baselineLayer = layer
            baselineLayer.opacity *= min(progress * 2, 1)
            drawBaseline(context: &baselineLayer, layout: layout, palette: palette, value: style.resolvedInitialValue)
        }

        if style.showsConnectors, style.resolvedConnectorLineWidth > 0 {
            for (index, pair) in zip(segments, segments.dropFirst()).enumerated() {
                let connectorReveal = LivelineMath.staggeredReveal(index: index, count: segments.count, reveal: reveal)
                guard connectorReveal > 0.001 else { continue }
                let current = pair.0
                let next = pair.1
                let y = layout.y(for: current.end)
                let startX = layout.x(for: current.time) + width / 2
                let targetX = layout.x(for: next.time) - width / 2
                var connector = Path()
                connector.move(to: CGPoint(x: startX, y: y))
                connector.addLine(to: CGPoint(
                    x: startX + (targetX - startX) * CGFloat(connectorReveal),
                    y: y
                ))
                layer.stroke(connector, with: .color(palette.gridLabel.opacity(0.55)), style: StrokeStyle(lineWidth: style.resolvedConnectorLineWidth, dash: [2, 3]))
            }
        }

        for (index, segment) in segments.enumerated() {
            let localReveal = LivelineMath.staggeredReveal(index: index, count: segments.count, reveal: reveal)
            guard localReveal > 0.001 else { continue }
            let x = layout.x(for: segment.time)
            let startY = LivelineMath.clamp(layout.y(for: segment.start), layout.padding.top, layout.bottomY)
            let targetEndY = LivelineMath.clamp(layout.y(for: segment.end), layout.padding.top, layout.bottomY)
            let endY = startY + (targetEndY - startY) * CGFloat(localReveal)
            let top = min(startY, endY)
            let height = max(abs(endY - startY), 1)
            let rect = CGRect(x: x - width / 2, y: top, width: width, height: height)
            let radius = min(style.resolvedCornerRadius, width / 2, height / 2)
            let color = segment.delta >= 0 ? (style.positiveColor ?? palette.line) : style.negativeColor
            layer.fill(Path(roundedRect: rect, cornerRadius: radius), with: .color(color))
        }
    }

    static func drawDiscreteCrosshair(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        hover: LivelineHoverPoint?,
        points: [LivelinePoint],
        config: LivelineChartConfiguration,
        alpha: Double
    ) {
        guard let hover, let last = points.last else { return }
        drawLineCrosshair(
            context: &context,
            layout: layout,
            palette: palette,
            hover: hover,
            livePoint: CGPoint(x: layout.x(for: last.time), y: layout.y(for: last.value)),
            config: config,
            alpha: alpha
        )
    }

    static func linePath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        return path
    }

    static func scatterSymbolPath(symbol: LivelineScatterSymbol, center: CGPoint, size: CGFloat) -> Path {
        let half = size / 2
        switch symbol {
        case .circle:
            return Path(ellipseIn: CGRect(x: center.x - half, y: center.y - half, width: size, height: size))
        case .square:
            return Path(roundedRect: CGRect(x: center.x - half, y: center.y - half, width: size, height: size), cornerRadius: min(1.5, half))
        case .diamond:
            var path = Path()
            path.move(to: CGPoint(x: center.x, y: center.y - half))
            path.addLine(to: CGPoint(x: center.x + half, y: center.y))
            path.addLine(to: CGPoint(x: center.x, y: center.y + half))
            path.addLine(to: CGPoint(x: center.x - half, y: center.y))
            path.closeSubpath()
            return path
        }
    }
}
