import SwiftUI

struct LivelineMarimekkoSegmentGeometry {
    var columnIndex: Int
    var segmentIndex: Int
    var rect: CGRect
}

struct LivelineMarimekkoColumnGeometry {
    var columnIndex: Int
    var rect: CGRect
    var segments: [LivelineMarimekkoSegmentGeometry]
}

struct LivelineContourFillCell {
    var level: Int
    var rect: CGRect
}

struct LivelineContourLine {
    var level: Int
    var points: [CGPoint]
    var isClosed: Bool
}

struct LivelineContourGeometry {
    var fillCells: [LivelineContourFillCell]
    var lines: [LivelineContourLine]
}

enum LivelineVisualGeometry {
    private struct ContourCoordinate: Hashable {
        var x: Double
        var y: Double
    }

    private struct ContourSegment {
        var start: CGPoint
        var end: CGPoint
    }

    private struct PointKey: Hashable {
        var x: Int
        var y: Int
    }

    /// Allocates internal gaps once, then distributes the remaining drawable
    /// width and height proportionally. The outer edges stay flush and the last
    /// rectangle absorbs floating-point remainder, so no seam accumulates.
    static func marimekko(
        columns: [LivelineMarimekkoColumn],
        in body: CGRect,
        columnSpacing: CGFloat,
        segmentSpacing: CGFloat
    ) -> [LivelineMarimekkoColumnGeometry] {
        let valid = columns.enumerated().compactMap { index, column in
            let segments = column.segments.enumerated().filter { $0.element.value > 0 }
            return column.width > 0 && !segments.isEmpty ? (index, column, segments) : nil
        }
        guard !valid.isEmpty, body.width > 0, body.height > 0 else { return [] }

        let horizontalGap = min(
            max(columnSpacing, 0),
            body.width / CGFloat(max(valid.count - 1, 1))
        )
        let horizontalGapBudget = horizontalGap * CGFloat(max(valid.count - 1, 0))
        let drawableWidth = max(body.width - horizontalGapBudget, 0)
        let totalWidth = max(valid.reduce(0) { $0 + $1.1.width }, 0.000_001)

        var result: [LivelineMarimekkoColumnGeometry] = []
        result.reserveCapacity(valid.count)
        var x = body.minX

        for (validIndex, item) in valid.enumerated() {
            let isLastColumn = validIndex == valid.count - 1
            let width = isLastColumn
                ? max(body.maxX - x, 0)
                : drawableWidth * CGFloat(item.1.width / totalWidth)
            let columnRect = CGRect(x: x, y: body.minY, width: width, height: body.height)

            let verticalGap = min(
                max(segmentSpacing, 0),
                body.height / CGFloat(max(item.2.count - 1, 1))
            )
            let verticalGapBudget = verticalGap * CGFloat(max(item.2.count - 1, 0))
            let drawableHeight = max(body.height - verticalGapBudget, 0)
            let totalValue = max(item.2.reduce(0) { $0 + $1.element.value }, 0.000_001)
            var y = body.maxY
            var segments: [LivelineMarimekkoSegmentGeometry] = []
            segments.reserveCapacity(item.2.count)

            for (segmentOrder, segment) in item.2.enumerated() {
                let isLastSegment = segmentOrder == item.2.count - 1
                let height = isLastSegment
                    ? max(y - body.minY, 0)
                    : drawableHeight * CGFloat(segment.element.value / totalValue)
                let rect = CGRect(x: x, y: y - height, width: width, height: height)
                segments.append(
                    LivelineMarimekkoSegmentGeometry(
                        columnIndex: item.0,
                        segmentIndex: segment.offset,
                        rect: rect
                    )
                )
                y = rect.minY - (isLastSegment ? 0 : verticalGap)
            }

            result.append(
                LivelineMarimekkoColumnGeometry(
                    columnIndex: item.0,
                    rect: columnRect,
                    segments: segments
                )
            )
            x = columnRect.maxX + (isLastColumn ? 0 : horizontalGap)
        }

        return result
    }

    /// Snaps every painted Marimekko edge to the same device-pixel grid.
    /// Shared edges are rounded identically, so a one-point gutter stays the
    /// same physical width horizontally and vertically without soft seams.
    static func pixelAligned(
        _ geometry: [LivelineMarimekkoColumnGeometry],
        displayScale: CGFloat
    ) -> [LivelineMarimekkoColumnGeometry] {
        let scale = displayScale.livelineClamped(1, 8, fallback: 1)

        func aligned(_ rect: CGRect) -> CGRect {
            let minX = (rect.minX * scale).rounded() / scale
            let minY = (rect.minY * scale).rounded() / scale
            let maxX = (rect.maxX * scale).rounded() / scale
            let maxY = (rect.maxY * scale).rounded() / scale
            return CGRect(
                x: minX,
                y: minY,
                width: max(maxX - minX, 0),
                height: max(maxY - minY, 0)
            )
        }

        return geometry.map { column in
            LivelineMarimekkoColumnGeometry(
                columnIndex: column.columnIndex,
                rect: aligned(column.rect),
                segments: column.segments.map { segment in
                    LivelineMarimekkoSegmentGeometry(
                        columnIndex: segment.columnIndex,
                        segmentIndex: segment.segmentIndex,
                        rect: aligned(segment.rect)
                    )
                }
            )
        }
    }

    /// Rounds a sampled polyline with midpoint quadratics. Each curve remains
    /// inside the local control-point hull, which avoids the overshoot and
    /// self-intersections that unconstrained splines can introduce in contour
    /// topology.
    static func smoothPath(points: [CGPoint], closed: Bool) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        guard points.count > 2 else {
            path.move(to: first)
            for point in points.dropFirst() { path.addLine(to: point) }
            if closed { path.closeSubpath() }
            return path
        }

        if closed {
            let start = midpoint(points[points.count - 1], first)
            path.move(to: start)
            for index in points.indices {
                let point = points[index]
                let next = points[(index + 1) % points.count]
                path.addQuadCurve(to: midpoint(point, next), control: point)
            }
            path.closeSubpath()
        } else {
            path.move(to: first)
            for index in 1..<(points.count - 1) {
                path.addQuadCurve(
                    to: midpoint(points[index], points[index + 1]),
                    control: points[index]
                )
            }
            path.addLine(to: points[points.count - 1])
        }
        return path
    }

    /// Distributes direct labels without changing their order. The requested
    /// gap is reduced only when the available band physically cannot fit it.
    static func distributedLabelPositions(
        _ desired: [CGFloat],
        minimum: CGFloat,
        maximum: CGFloat,
        spacing requestedSpacing: CGFloat
    ) -> [CGFloat] {
        guard !desired.isEmpty else { return [] }
        guard desired.count > 1 else {
            return [min(max(desired[0], minimum), maximum)]
        }
        let indexed = desired.enumerated().sorted {
            $0.element == $1.element ? $0.offset < $1.offset : $0.element < $1.element
        }
        let available = max(maximum - minimum, 0)
        let spacing = min(max(requestedSpacing, 0), available / CGFloat(desired.count - 1))
        var sorted = indexed.map { min(max($0.element, minimum), maximum) }

        for index in 1..<sorted.count {
            sorted[index] = max(sorted[index], sorted[index - 1] + spacing)
        }
        if let overflow = sorted.last.map({ $0 - maximum }), overflow > 0 {
            for index in sorted.indices { sorted[index] -= overflow }
        }
        if sorted[0] < minimum {
            sorted[0] = minimum
            for index in 1..<sorted.count {
                sorted[index] = max(sorted[index], sorted[index - 1] + spacing)
            }
        }

        var result = Array(repeating: CGFloat.zero, count: desired.count)
        for (sortedIndex, item) in indexed.enumerated() {
            result[item.offset] = sorted[sortedIndex]
        }
        return result
    }

    static func contour(
        samples: [LivelineContourSample],
        levelCount: Int,
        plot: CGRect,
        subdivisions: Int
    ) -> LivelineContourGeometry {
        let xs = Array(Set(samples.map(\.x))).sorted()
        let ys = Array(Set(samples.map(\.y))).sorted()
        guard xs.count >= 2, ys.count >= 2, plot.width > 0, plot.height > 0 else {
            return LivelineContourGeometry(fillCells: [], lines: [])
        }

        let levels = min(max(levelCount, 2), 16)
        let subdivisions = min(max(subdivisions, 2), 16)
        let minimum = samples.map(\.value).min() ?? 0
        let maximum = samples.map(\.value).max() ?? minimum
        let span = max(maximum - minimum, 0.000_001)

        // Duplicate coordinates are legal input. Average them deterministically
        // instead of relying on Dictionary(uniqueKeysWithValues:), which traps.
        var grouped: [ContourCoordinate: (sum: Double, count: Int)] = [:]
        for sample in samples {
            let key = ContourCoordinate(x: sample.x, y: sample.y)
            let prior = grouped[key] ?? (0, 0)
            grouped[key] = (prior.sum + sample.value, prior.count + 1)
        }
        let values = grouped.mapValues { $0.sum / Double($0.count) }
        func coarseValue(x: Int, y: Int) -> Double {
            values[ContourCoordinate(x: xs[x], y: ys[y])] ?? minimum
        }
        func clampedCoarseValue(x: Int, y: Int) -> Double {
            coarseValue(
                x: min(max(x, 0), xs.count - 1),
                y: min(max(y, 0), ys.count - 1)
            )
        }
        func cubic(_ p0: Double, _ p1: Double, _ p2: Double, _ p3: Double, _ t: Double) -> Double {
            let t2 = t * t
            let t3 = t2 * t
            return 0.5
                * ((2 * p1) + (-p0 + p2) * t
                    + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                    + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
        }

        let columnCount = (xs.count - 1) * subdivisions + 1
        let rowCount = (ys.count - 1) * subdivisions + 1
        var denseValues = Array(repeating: minimum, count: columnCount * rowCount)
        var screenXs = Array(repeating: CGFloat.zero, count: columnCount)
        var screenYs = Array(repeating: CGFloat.zero, count: rowCount)
        let xDomain = xs[0]...xs[xs.count - 1]
        let yDomain = ys[0]...ys[ys.count - 1]

        for denseX in 0..<columnCount {
            let cellX = min(denseX / subdivisions, xs.count - 2)
            let localX = Double(denseX - cellX * subdivisions) / Double(subdivisions)
            let valueX = xs[cellX] + (xs[cellX + 1] - xs[cellX]) * localX
            screenXs[denseX] = LivelineRenderer.mapped(
                valueX, from: xDomain, to: plot.minX...plot.maxX)
        }
        for denseY in 0..<rowCount {
            let cellY = min(denseY / subdivisions, ys.count - 2)
            let localY = Double(denseY - cellY * subdivisions) / Double(subdivisions)
            let valueY = ys[cellY] + (ys[cellY + 1] - ys[cellY]) * localY
            screenYs[denseY] = LivelineRenderer.mapped(
                valueY, from: yDomain, to: (plot.maxY, plot.minY))
        }

        for denseY in 0..<rowCount {
            let cellY = min(denseY / subdivisions, ys.count - 2)
            let localY = Double(denseY - cellY * subdivisions) / Double(subdivisions)
            for denseX in 0..<columnCount {
                let cellX = min(denseX / subdivisions, xs.count - 2)
                let localX = Double(denseX - cellX * subdivisions) / Double(subdivisions)
                func interpolatedRow(_ row: Int) -> Double {
                    cubic(
                        clampedCoarseValue(x: cellX - 1, y: cellY + row),
                        clampedCoarseValue(x: cellX, y: cellY + row),
                        clampedCoarseValue(x: cellX + 1, y: cellY + row),
                        clampedCoarseValue(x: cellX + 2, y: cellY + row),
                        localX
                    )
                }
                let interpolated = cubic(
                    interpolatedRow(-1),
                    interpolatedRow(0),
                    interpolatedRow(1),
                    interpolatedRow(2),
                    localY
                )
                var localMinimum = Double.infinity
                var localMaximum = -Double.infinity
                for row in -1...2 {
                    for column in -1...2 {
                        let sample = clampedCoarseValue(
                            x: cellX + column,
                            y: cellY + row
                        )
                        localMinimum = min(localMinimum, sample)
                        localMaximum = max(localMaximum, sample)
                    }
                }
                denseValues[denseY * columnCount + denseX] = min(
                    max(interpolated, localMinimum),
                    localMaximum
                )
            }
        }

        func value(_ x: Int, _ y: Int) -> Double {
            denseValues[y * columnCount + x]
        }
        func level(for value: Double) -> Int {
            min(max(Int(((value - minimum) / span) * Double(levels)), 0), levels - 1)
        }

        var fillCells: [LivelineContourFillCell] = []
        fillCells.reserveCapacity((columnCount - 1) * (rowCount - 1))
        for y in 0..<(rowCount - 1) {
            for x in 0..<(columnCount - 1) {
                let average = (value(x, y) + value(x + 1, y) + value(x + 1, y + 1)
                    + value(x, y + 1)) / 4
                fillCells.append(
                    LivelineContourFillCell(
                        level: level(for: average),
                        rect: CGRect(
                            x: screenXs[x],
                            y: screenYs[y + 1],
                            width: max(screenXs[x + 1] - screenXs[x], 0),
                            height: max(screenYs[y] - screenYs[y + 1], 0)
                        )
                    )
                )
            }
        }

        var lines: [LivelineContourLine] = []
        let tolerance = max(min(plot.width, plot.height) / 100_000, 0.000_1)
        for level in 1..<levels {
            let threshold = minimum + span * Double(level) / Double(levels)
            var segments: [ContourSegment] = []
            segments.reserveCapacity((columnCount - 1) * (rowCount - 1) / 2)
            for y in 0..<(rowCount - 1) {
                for x in 0..<(columnCount - 1) {
                    let cellValues = [
                        value(x, y), value(x + 1, y), value(x + 1, y + 1), value(x, y + 1),
                    ]
                    let cellPoints = [
                        CGPoint(x: screenXs[x], y: screenYs[y]),
                        CGPoint(x: screenXs[x + 1], y: screenYs[y]),
                        CGPoint(x: screenXs[x + 1], y: screenYs[y + 1]),
                        CGPoint(x: screenXs[x], y: screenYs[y + 1]),
                    ]
                    let edgePairs = [(0, 1), (1, 2), (2, 3), (3, 0)]
                    var crossings: [Int: CGPoint] = [:]
                    for (edge, pair) in edgePairs.enumerated()
                    where (cellValues[pair.0] >= threshold) != (cellValues[pair.1] >= threshold) {
                        let delta = cellValues[pair.1] - cellValues[pair.0]
                        let amount = abs(delta) < 0.000_001
                            ? 0.5 : (threshold - cellValues[pair.0]) / delta
                        crossings[edge] = interpolated(
                            cellPoints[pair.0], cellPoints[pair.1], CGFloat(amount))
                    }

                    let mask = cellValues.enumerated().reduce(0) { partial, item in
                        item.element >= threshold ? partial | (1 << item.offset) : partial
                    }
                    let centerHigh = cellValues.reduce(0, +) / 4 >= threshold
                    let pairs: [(Int, Int)]
                    switch mask {
                    case 1, 14: pairs = [(3, 0)]
                    case 2, 13: pairs = [(0, 1)]
                    case 3, 12: pairs = [(3, 1)]
                    case 4, 11: pairs = [(1, 2)]
                    case 6, 9: pairs = [(0, 2)]
                    case 7, 8: pairs = [(3, 2)]
                    case 5:
                        pairs = centerHigh ? [(0, 1), (2, 3)] : [(3, 0), (1, 2)]
                    case 10:
                        pairs = centerHigh ? [(3, 0), (1, 2)] : [(0, 1), (2, 3)]
                    default: pairs = []
                    }
                    for pair in pairs {
                        if let start = crossings[pair.0], let end = crossings[pair.1] {
                            segments.append(ContourSegment(start: start, end: end))
                        }
                    }
                }
            }

            for polyline in stitched(segments, tolerance: tolerance) where polyline.points.count >= 2 {
                lines.append(
                    LivelineContourLine(
                        level: level,
                        points: polyline.points,
                        isClosed: polyline.isClosed
                    )
                )
            }
        }

        return LivelineContourGeometry(fillCells: fillCells, lines: lines)
    }

    private static func midpoint(_ first: CGPoint, _ second: CGPoint) -> CGPoint {
        CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
    }

    private static func interpolated(
        _ first: CGPoint, _ second: CGPoint, _ progress: CGFloat
    ) -> CGPoint {
        CGPoint(
            x: first.x + (second.x - first.x) * progress,
            y: first.y + (second.y - first.y) * progress
        )
    }

    private static func key(for point: CGPoint, tolerance: CGFloat) -> PointKey {
        PointKey(
            x: Int((point.x / tolerance).rounded()),
            y: Int((point.y / tolerance).rounded())
        )
    }

    private static func stitched(
        _ segments: [ContourSegment], tolerance: CGFloat
    ) -> [(points: [CGPoint], isClosed: Bool)] {
        guard !segments.isEmpty else { return [] }
        var adjacency: [PointKey: [Int]] = [:]
        var endpoints: [(PointKey, PointKey)] = []
        endpoints.reserveCapacity(segments.count)
        for (index, segment) in segments.enumerated() {
            let start = key(for: segment.start, tolerance: tolerance)
            let end = key(for: segment.end, tolerance: tolerance)
            endpoints.append((start, end))
            adjacency[start, default: []].append(index)
            adjacency[end, default: []].append(index)
        }

        var unused = Set(segments.indices)
        var result: [(points: [CGPoint], isClosed: Bool)] = []
        while let seed = unused.first {
            let seedKeys = endpoints[seed]
            let startKey = adjacency[seedKeys.0]?.count == 1
                ? seedKeys.0
                : (adjacency[seedKeys.1]?.count == 1 ? seedKeys.1 : seedKeys.0)
            var currentKey = startKey
            var points: [CGPoint] = []
            var isClosed = false

            while let edge = adjacency[currentKey]?.first(where: { unused.contains($0) }) {
                unused.remove(edge)
                let edgeKeys = endpoints[edge]
                let segment = segments[edge]
                if points.isEmpty {
                    points.append(currentKey == edgeKeys.0 ? segment.start : segment.end)
                }
                if currentKey == edgeKeys.0 {
                    currentKey = edgeKeys.1
                    points.append(segment.end)
                } else {
                    currentKey = edgeKeys.0
                    points.append(segment.start)
                }
                if currentKey == startKey {
                    isClosed = true
                    break
                }
            }

            if isClosed, points.count > 1 { points.removeLast() }
            result.append((points, isClosed))
        }
        return result
    }
}
