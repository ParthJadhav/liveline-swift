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

/// One interpolation source for both rendered contours and inspected values.
/// Values are normalized before Catmull-Rom interpolation so extreme finite
/// inputs cannot overflow intermediate arithmetic.
struct LivelineContourSampler {
    let xs: [Double]
    let ys: [Double]
    let valueScale: Double
    let minimumNormalizedValue: Double
    let maximumNormalizedValue: Double

    /// Normalized values in row-major order: `values[y * xs.count + x]`.
    /// A flat grid keeps the interpolation loops on O(1) array reads instead
    /// of hashing a Double pair per probe.
    private let values: [Double]

    init?(samples: [LivelineContourSample]) {
        let collapsed = LivelineAdvancedLayout.contourSamplesByCoordinate(samples)
        let xs = Array(Set(collapsed.map(\.x))).sorted()
        let ys = Array(Set(collapsed.map(\.y))).sorted()
        guard xs.count >= 2, ys.count >= 2, collapsed.count == xs.count * ys.count else {
            return nil
        }
        let valueScale = max(collapsed.lazy.map { abs($0.value) }.max() ?? 0, 1)
        var xIndices: [Double: Int] = [:]
        xIndices.reserveCapacity(xs.count)
        for (index, x) in xs.enumerated() { xIndices[x] = index }
        var yIndices: [Double: Int] = [:]
        yIndices.reserveCapacity(ys.count)
        for (index, y) in ys.enumerated() { yIndices[y] = index }
        var grid = Array(repeating: Double.zero, count: xs.count * ys.count)
        var minimumNormalizedValue = Double.infinity
        var maximumNormalizedValue = -Double.infinity
        for sample in collapsed {
            guard let xIndex = xIndices[sample.x], let yIndex = yIndices[sample.y] else {
                return nil
            }
            let normalized = sample.value / valueScale
            grid[yIndex * xs.count + xIndex] = normalized
            minimumNormalizedValue = min(minimumNormalizedValue, normalized)
            maximumNormalizedValue = max(maximumNormalizedValue, normalized)
        }
        self.xs = xs
        self.ys = ys
        self.valueScale = valueScale
        self.minimumNormalizedValue = minimumNormalizedValue.isFinite ? minimumNormalizedValue : 0
        self.maximumNormalizedValue = maximumNormalizedValue.isFinite ? maximumNormalizedValue : 0
        self.values = grid
    }

    func normalizedValue(x: Double, y: Double) -> Double? {
        guard
            x.isFinite, y.isFinite,
            x >= xs[0], x <= xs[xs.count - 1],
            y >= ys[0], y <= ys[ys.count - 1]
        else { return nil }
        let cellX = min(xs.lastIndex { $0 <= x } ?? 0, xs.count - 2)
        let cellY = min(ys.lastIndex { $0 <= y } ?? 0, ys.count - 2)
        let xSpan = xs[cellX + 1] - xs[cellX]
        let ySpan = ys[cellY + 1] - ys[cellY]
        let localX = xSpan > 0 ? (x - xs[cellX]) / xSpan : 0
        let localY = ySpan > 0 ? (y - ys[cellY]) / ySpan : 0
        return normalizedValue(cellX: cellX, cellY: cellY, localX: localX, localY: localY)
    }

    /// The interpolation core, entered with the grid cell already resolved so
    /// dense-grid construction skips the per-node coordinate search.
    func normalizedValue(cellX: Int, cellY: Int, localX: Double, localY: Double) -> Double {
        let width = xs.count
        let height = ys.count

        func cubic(
            _ p0: Double, _ p1: Double, _ p2: Double, _ p3: Double, _ t: Double
        ) -> Double {
            let t2 = t * t
            let t3 = t2 * t
            return 0.5
                * ((2 * p1) + (-p0 + p2) * t
                    + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                    + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
        }

        var localMinimum = Double.infinity
        var localMaximum = -Double.infinity
        var rowValues = (Double.zero, Double.zero, Double.zero, Double.zero)
        let column0 = min(max(cellX - 1, 0), width - 1)
        let column1 = min(max(cellX, 0), width - 1)
        let column2 = min(max(cellX + 1, 0), width - 1)
        let column3 = min(max(cellX + 2, 0), width - 1)
        for row in 0..<4 {
            let clampedY = min(max(cellY + row - 1, 0), height - 1)
            let base = clampedY * width
            let p0 = values[base + column0]
            let p1 = values[base + column1]
            let p2 = values[base + column2]
            let p3 = values[base + column3]
            localMinimum = min(localMinimum, min(min(p0, p1), min(p2, p3)))
            localMaximum = max(localMaximum, max(max(p0, p1), max(p2, p3)))
            let value = cubic(p0, p1, p2, p3, localX)
            switch row {
            case 0: rowValues.0 = value
            case 1: rowValues.1 = value
            case 2: rowValues.2 = value
            default: rowValues.3 = value
            }
        }
        let interpolated = cubic(rowValues.0, rowValues.1, rowValues.2, rowValues.3, localY)
        return min(max(interpolated, localMinimum), localMaximum)
    }

    func value(x: Double, y: Double) -> Double? {
        guard let normalized = normalizedValue(x: x, y: y) else { return nil }
        let value = normalized * valueScale
        return value.isFinite ? value : nil
    }
}

enum LivelineVisualGeometry {
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

        let horizontalGapCount = max(valid.count - 1, 0)
        let horizontalGapBudgetLimit = max(body.width - CGFloat(valid.count) * 0.5, 0)
        let horizontalGap = min(
            max(columnSpacing, 0),
            horizontalGapBudgetLimit / CGFloat(max(horizontalGapCount, 1))
        )
        let horizontalGapBudget = horizontalGap * CGFloat(horizontalGapCount)
        let drawableWidth = max(body.width - horizontalGapBudget, 0)
        let maximumWidth = max(valid.map { $0.1.width }.max() ?? 0, 0.000_001)
        let totalWidth = max(valid.reduce(0) { $0 + $1.1.width / maximumWidth }, 0.000_001)

        var result: [LivelineMarimekkoColumnGeometry] = []
        result.reserveCapacity(valid.count)
        var x = body.minX

        for (validIndex, item) in valid.enumerated() {
            let isLastColumn = validIndex == valid.count - 1
            let width = isLastColumn
                ? max(body.maxX - x, 0)
                : drawableWidth * CGFloat((item.1.width / maximumWidth) / totalWidth)
            let columnRect = CGRect(x: x, y: body.minY, width: width, height: body.height)

            let verticalGapCount = max(item.2.count - 1, 0)
            let verticalGapBudgetLimit = max(body.height - CGFloat(item.2.count) * 0.5, 0)
            let verticalGap = min(
                max(segmentSpacing, 0),
                verticalGapBudgetLimit / CGFloat(max(verticalGapCount, 1))
            )
            let verticalGapBudget = verticalGap * CGFloat(verticalGapCount)
            let drawableHeight = max(body.height - verticalGapBudget, 0)
            let maximumValue = max(item.2.map { $0.element.value }.max() ?? 0, 0.000_001)
            let totalValue = max(
                item.2.reduce(0) { $0 + $1.element.value / maximumValue },
                0.000_001)
            var y = body.maxY
            var segments: [LivelineMarimekkoSegmentGeometry] = []
            segments.reserveCapacity(item.2.count)

            for (segmentOrder, segment) in item.2.enumerated() {
                let isLastSegment = segmentOrder == item.2.count - 1
                let height = isLastSegment
                    ? max(y - body.minY, 0)
                    : drawableHeight
                        * CGFloat((segment.element.value / maximumValue) / totalValue)
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
        subdivisions: Int,
        isRTL: Bool = false
    ) -> LivelineContourGeometry {
        guard
            let sampler = LivelineContourSampler(samples: samples),
            plot.width > 0, plot.height > 0
        else {
            return LivelineContourGeometry(fillCells: [], lines: [])
        }
        let xs = sampler.xs
        let ys = sampler.ys

        let levels = min(max(levelCount, 2), 16)
        let subdivisions = min(max(subdivisions, 1), 16)
        let minimum = sampler.minimumNormalizedValue
        let maximum = sampler.maximumNormalizedValue
        let span = max(maximum - minimum, 0.000_001)

        let columnCount = (xs.count - 1) * subdivisions + 1
        let rowCount = (ys.count - 1) * subdivisions + 1
        var denseValues = Array(repeating: minimum, count: columnCount * rowCount)
        var screenXs = Array(repeating: CGFloat.zero, count: columnCount)
        var screenYs = Array(repeating: CGFloat.zero, count: rowCount)
        var valueXs = Array(repeating: Double.zero, count: columnCount)
        var valueYs = Array(repeating: Double.zero, count: rowCount)
        let xDomain = xs[0]...xs[xs.count - 1]
        let yDomain = ys[0]...ys[ys.count - 1]

        // Each dense node's owning coarse cell and local parameter are derived
        // once per axis, so the interpolation loop below never searches the
        // coordinate arrays.
        var cellXs = Array(repeating: 0, count: columnCount)
        var localXs = Array(repeating: Double.zero, count: columnCount)
        var cellYs = Array(repeating: 0, count: rowCount)
        var localYs = Array(repeating: Double.zero, count: rowCount)

        for denseX in 0..<columnCount {
            let cellX = min(denseX / subdivisions, xs.count - 2)
            let localX = Double(denseX - cellX * subdivisions) / Double(subdivisions)
            let valueX = xs[cellX] + (xs[cellX + 1] - xs[cellX]) * localX
            valueXs[denseX] = valueX
            screenXs[denseX] = LivelineRenderer.mapped(
                valueX,
                from: xDomain,
                to: isRTL ? (plot.maxX, plot.minX) : (plot.minX, plot.maxX)
            )
            // Recover the cell the coordinate search would pick for the
            // reconstructed valueX, which can land in the next cell when the
            // interpolation rounds up to an exact grid coordinate.
            var searchCellX = cellX
            if valueX >= xs[cellX + 1] { searchCellX = min(cellX + 1, xs.count - 2) }
            let xSpan = xs[searchCellX + 1] - xs[searchCellX]
            cellXs[denseX] = searchCellX
            localXs[denseX] = xSpan > 0 ? (valueX - xs[searchCellX]) / xSpan : 0
        }
        for denseY in 0..<rowCount {
            let cellY = min(denseY / subdivisions, ys.count - 2)
            let localY = Double(denseY - cellY * subdivisions) / Double(subdivisions)
            let valueY = ys[cellY] + (ys[cellY + 1] - ys[cellY]) * localY
            valueYs[denseY] = valueY
            screenYs[denseY] = LivelineRenderer.mapped(
                valueY, from: yDomain, to: (plot.maxY, plot.minY))
            var searchCellY = cellY
            if valueY >= ys[cellY + 1] { searchCellY = min(cellY + 1, ys.count - 2) }
            let ySpan = ys[searchCellY + 1] - ys[searchCellY]
            cellYs[denseY] = searchCellY
            localYs[denseY] = ySpan > 0 ? (valueY - ys[searchCellY]) / ySpan : 0
        }

        for denseY in 0..<rowCount {
            let cellY = cellYs[denseY]
            let localY = localYs[denseY]
            guard valueYs[denseY] >= ys[0], valueYs[denseY] <= ys[ys.count - 1] else { continue }
            for denseX in 0..<columnCount {
                guard valueXs[denseX] >= xs[0], valueXs[denseX] <= xs[xs.count - 1] else { continue }
                denseValues[denseY * columnCount + denseX] = sampler.normalizedValue(
                    cellX: cellXs[denseX], cellY: cellY, localX: localXs[denseX], localY: localY)
            }
        }

        func value(_ x: Int, _ y: Int) -> Double {
            denseValues[y * columnCount + x]
        }
        func level(for value: Double) -> Int {
            min(max(Int(((value - minimum) / span) * Double(levels)), 0), levels - 1)
        }

        var thresholds = Array(repeating: Double.zero, count: levels)
        for level in 1..<levels {
            thresholds[level] = minimum + span * Double(level) / Double(levels)
        }
        let levelScale = Double(levels) / span

        var fillCells: [LivelineContourFillCell] = []
        fillCells.reserveCapacity((columnCount - 1) * (rowCount - 1))
        var segmentsByLevel = Array(repeating: [ContourSegment](), count: levels)

        // One sweep over the dense cells computes both the fill level and, for
        // only the levels a cell's value range actually crosses, its contour
        // segments. Cells are visited in the same row-major order for every
        // level, so per-level segment order — and therefore stitching — matches
        // a per-level sweep.
        for y in 0..<(rowCount - 1) {
            let topY = screenYs[y]
            let bottomY = screenYs[y + 1]
            let rowHeight = max(topY - bottomY, 0)
            for x in 0..<(columnCount - 1) {
                let value0 = value(x, y)
                let value1 = value(x + 1, y)
                let value2 = value(x + 1, y + 1)
                let value3 = value(x, y + 1)
                let sum = value0 + value1 + value2 + value3
                fillCells.append(
                    LivelineContourFillCell(
                        level: level(for: sum / 4),
                        rect: CGRect(
                            x: min(screenXs[x], screenXs[x + 1]),
                            y: bottomY,
                            width: abs(screenXs[x + 1] - screenXs[x]),
                            height: rowHeight
                        )
                    )
                )

                let cellMinimum = min(min(value0, value1), min(value2, value3))
                let cellMaximum = max(max(value0, value1), max(value2, value3))
                // A level line crosses this cell only when its threshold lies
                // within the cell's value range; the ±1 slack keeps boundary
                // rounding from skipping a level the comparisons would accept.
                var lowerLevel = 1
                var upperLevel = levels - 1
                if cellMinimum.isFinite, cellMaximum.isFinite {
                    let lowerEstimate = ((cellMinimum - minimum) * levelScale).rounded(.down) - 1
                    let upperEstimate = ((cellMaximum - minimum) * levelScale).rounded(.up) + 1
                    if lowerEstimate > 1, lowerEstimate.isFinite {
                        lowerLevel = min(Int(lowerEstimate), levels)
                    }
                    if upperEstimate < Double(levels - 1), upperEstimate.isFinite {
                        upperLevel = max(Int(upperEstimate), 0)
                    }
                }
                guard lowerLevel <= upperLevel else { continue }

                for level in lowerLevel...upperLevel {
                    let threshold = thresholds[level]
                    let high0 = value0 >= threshold
                    let high1 = value1 >= threshold
                    let high2 = value2 >= threshold
                    let high3 = value3 >= threshold
                    let mask = (high0 ? 1 : 0) | (high1 ? 2 : 0) | (high2 ? 4 : 0) | (high3 ? 8 : 0)
                    guard mask != 0, mask != 15 else { continue }

                    // Edge n runs from corner n to corner (n + 1) % 4; corners
                    // start top-left and wind clockwise in screen space.
                    func crossing(_ edge: Int) -> CGPoint {
                        let startValue: Double
                        let endValue: Double
                        let startPoint: CGPoint
                        let endPoint: CGPoint
                        switch edge {
                        case 0:
                            startValue = value0
                            endValue = value1
                            startPoint = CGPoint(x: screenXs[x], y: topY)
                            endPoint = CGPoint(x: screenXs[x + 1], y: topY)
                        case 1:
                            startValue = value1
                            endValue = value2
                            startPoint = CGPoint(x: screenXs[x + 1], y: topY)
                            endPoint = CGPoint(x: screenXs[x + 1], y: bottomY)
                        case 2:
                            startValue = value2
                            endValue = value3
                            startPoint = CGPoint(x: screenXs[x + 1], y: bottomY)
                            endPoint = CGPoint(x: screenXs[x], y: bottomY)
                        default:
                            startValue = value3
                            endValue = value0
                            startPoint = CGPoint(x: screenXs[x], y: bottomY)
                            endPoint = CGPoint(x: screenXs[x], y: topY)
                        }
                        let delta = endValue - startValue
                        let amount = abs(delta) < 0.000_001
                            ? 0.5 : (threshold - startValue) / delta
                        return interpolated(startPoint, endPoint, CGFloat(amount))
                    }
                    func appendSegment(_ startEdge: Int, _ endEdge: Int) {
                        segmentsByLevel[level].append(
                            ContourSegment(start: crossing(startEdge), end: crossing(endEdge)))
                    }

                    switch mask {
                    case 1, 14: appendSegment(3, 0)
                    case 2, 13: appendSegment(0, 1)
                    case 3, 12: appendSegment(3, 1)
                    case 4, 11: appendSegment(1, 2)
                    case 6, 9: appendSegment(0, 2)
                    case 7, 8: appendSegment(3, 2)
                    case 5:
                        if sum / 4 >= threshold {
                            appendSegment(0, 1)
                            appendSegment(2, 3)
                        } else {
                            appendSegment(3, 0)
                            appendSegment(1, 2)
                        }
                    case 10:
                        if sum / 4 >= threshold {
                            appendSegment(3, 0)
                            appendSegment(1, 2)
                        } else {
                            appendSegment(0, 1)
                            appendSegment(2, 3)
                        }
                    default: break
                    }
                }
            }
        }

        var lines: [LivelineContourLine] = []
        let tolerance = max(min(plot.width, plot.height) / 100_000, 0.000_1)
        for level in 1..<levels {
            for polyline in stitched(segmentsByLevel[level], tolerance: tolerance)
            where polyline.points.count >= 2 {
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

        // Seeds advance through the segments in construction order rather than
        // hash order, so the stitched polylines are deterministic across
        // processes instead of following the per-run Set hashing seed.
        var used = [Bool](repeating: false, count: segments.count)
        var seedCursor = 0
        var result: [(points: [CGPoint], isClosed: Bool)] = []
        while seedCursor < segments.count {
            guard !used[seedCursor] else {
                seedCursor += 1
                continue
            }
            let seed = seedCursor
            let seedKeys = endpoints[seed]
            let startKey = adjacency[seedKeys.0]?.count == 1
                ? seedKeys.0
                : (adjacency[seedKeys.1]?.count == 1 ? seedKeys.1 : seedKeys.0)
            var currentKey = startKey
            var points: [CGPoint] = []
            var isClosed = false

            while let edge = adjacency[currentKey]?.first(where: { !used[$0] }) {
                used[edge] = true
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
