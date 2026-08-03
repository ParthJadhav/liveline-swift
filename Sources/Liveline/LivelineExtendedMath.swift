import CoreGraphics
import Foundation

struct LivelineStackSegment: Equatable {
    var lower: Double
    var upper: Double
}

struct LivelineGaugeGeometry: Equatable {
    var center: CGPoint
    var radius: CGFloat
    var visualBounds: CGRect
}

extension LivelineMath {
    static func easedReveal(_ reveal: Double) -> Double {
        let progress = clamp(reveal.isFinite ? reveal : 0, 0, 1)
        return progress * progress * (3 - 2 * progress)
    }

    static func staggeredReveal(
        index: Int,
        count: Int,
        reveal: Double,
        staggerFraction: Double = 0.35
    ) -> Double {
        guard count > 1 else { return easedReveal(reveal) }
        let stagger = clamp(staggerFraction.isFinite ? staggerFraction : 0.35, 0, 0.95)
        let position = Double(clamp(index, 0, count - 1)) / Double(count - 1)
        let local = (clamp(reveal.isFinite ? reveal : 0, 0, 1) - position * stagger) / (1 - stagger)
        return easedReveal(local)
    }

    static func revealedPoints(_ points: [CGPoint], reveal: Double) -> [CGPoint] {
        guard let first = points.first else { return [] }
        guard points.count > 1 else { return reveal > 0 ? [first] : [] }

        let progress = clamp(reveal.isFinite ? reveal : 0, 0, 1)
        guard progress > 0 else { return [] }
        guard progress < 1 else { return points }

        let position = progress * Double(points.count - 1)
        let lowerIndex = min(Int(floor(position)), points.count - 2)
        let fraction = CGFloat(position - Double(lowerIndex))
        var result = Array(points[...lowerIndex])
        let lower = points[lowerIndex]
        let upper = points[lowerIndex + 1]
        result.append(CGPoint(
            x: lower.x + (upper.x - lower.x) * fraction,
            y: lower.y + (upper.y - lower.y) * fraction
        ))
        return result
    }

    static func resolvedPadding(
        _ padding: LivelinePadding,
        badgeEnabled: Bool,
        showValueAxis: Bool,
        showTimeAxis: Bool
    ) -> LivelineResolvedPadding {
        LivelineResolvedPadding(
            top: padding.top ?? 12,
            right: padding.right ?? (badgeEnabled ? 80 : showValueAxis ? 54 : 12),
            bottom: padding.bottom ?? (showTimeAxis ? 28 : 12),
            left: padding.left ?? 12
        )
    }

    static func gaugeGeometry(
        in rect: CGRect,
        startAngleDegrees: Double,
        sweepDegrees: Double,
        lineWidth: CGFloat,
        hasOuterMarks: Bool,
        showsValue: Bool
    ) -> LivelineGaugeGeometry {
        let start = startAngleDegrees.isFinite ? startAngleDegrees : 150
        let sweep = clamp(abs(sweepDegrees.isFinite ? sweepDegrees : 240), 1, 359.5)
        let sampleCount = max(Int(ceil(sweep / 2)), 2)
        var minimumX = Double.infinity
        var maximumX = -Double.infinity
        var minimumY = Double.infinity
        var maximumY = -Double.infinity

        for index in 0...sampleCount {
            let progress = Double(index) / Double(sampleCount)
            let angle = (start + sweep * progress) * Double.pi / 180
            minimumX = min(minimumX, cos(angle))
            maximumX = max(maximumX, cos(angle))
            minimumY = min(minimumY, sin(angle))
            maximumY = max(maximumY, sin(angle))
        }

        if showsValue {
            minimumX = min(minimumX, -0.30)
            maximumX = max(maximumX, 0.30)
            minimumY = min(minimumY, -0.16)
            maximumY = max(maximumY, 0.30)
        }

        let unitWidth = max(maximumX - minimumX, 0.1)
        let unitHeight = max(maximumY - minimumY, 0.1)
        let outset = max(lineWidth, 1) / 2 + (hasOuterMarks ? 14 : 3)
        let available = rect.insetBy(dx: outset, dy: outset)
        let fittingRadius = min(
            max(available.width, 1) / CGFloat(unitWidth),
            max(available.height, 1) / CGFloat(unitHeight)
        )
        let radius = max(1, min(fittingRadius, min(rect.width, rect.height) * 0.43))
        let unitMidX = (minimumX + maximumX) / 2
        let unitMidY = (minimumY + maximumY) / 2
        let center = CGPoint(
            x: rect.midX - CGFloat(unitMidX) * radius,
            y: rect.midY - CGFloat(unitMidY) * radius
        )
        let visualBounds = CGRect(
            x: center.x + CGFloat(minimumX) * radius,
            y: center.y + CGFloat(minimumY) * radius,
            width: CGFloat(unitWidth) * radius,
            height: CGFloat(unitHeight) * radius
        )

        return LivelineGaugeGeometry(center: center, radius: radius, visualBounds: visualBounds)
    }

    static func stackedSegments(
        values: [Double],
        mode: LivelineStackMode,
        baseline: LivelineStackBaseline
    ) -> [LivelineStackSegment] {
        let segments = stackedSegments(values: values, mode: mode)
        guard baseline == .centered else { return segments }
        let offset = stackedCenteredOffset(segments: segments)
        guard offset != 0 else { return segments }
        return segments.map { LivelineStackSegment(lower: $0.lower + offset, upper: $0.upper + offset) }
    }

    /// Half the stack's own height, negated: applying it puts the middle of the
    /// stack on the value axis' zero line, which is what makes a streamgraph
    /// ripple symmetrically rather than grow off one edge.
    static func stackedCenteredOffset(segments: [LivelineStackSegment]) -> Double {
        guard !segments.isEmpty else { return 0 }
        let upper = segments.map(\.upper).max() ?? 0
        let lower = segments.map(\.lower).min() ?? 0
        return -(upper + lower) / 2
    }

    static func stackedSegments(values: [Double], mode: LivelineStackMode) -> [LivelineStackSegment] {
        let finite = values.map { $0.isFinite ? $0 : 0 }
        let positiveTotal = finite.filter { $0 > 0 }.reduce(0, +)
        let negativeTotal = abs(finite.filter { $0 < 0 }.reduce(0, +))
        var positive = 0.0
        var negative = 0.0

        return finite.map { rawValue in
            let value: Double
            switch mode {
            case .standard:
                value = rawValue
            case .normalized:
                if rawValue > 0 {
                    value = positiveTotal > 0 ? rawValue / positiveTotal : 0
                } else if rawValue < 0 {
                    value = negativeTotal > 0 ? rawValue / negativeTotal : 0
                } else {
                    value = 0
                }
            }

            if value >= 0 {
                let lower = positive
                positive += value
                return LivelineStackSegment(lower: lower, upper: positive)
            }

            let upper = negative
            negative += value
            return LivelineStackSegment(lower: negative, upper: upper)
        }
    }

    static func stackedRangePoints(
        points: [LivelineStackedPoint],
        mode: LivelineStackMode,
        baseline: LivelineStackBaseline = .zero
    ) -> [LivelinePoint] {
        points.flatMap { point in
            let segments = stackedSegments(values: point.values, mode: mode, baseline: baseline)
            let lower = min(segments.map(\.lower).min() ?? 0, segments.map(\.upper).min() ?? 0, 0)
            let upper = max(segments.map(\.lower).max() ?? 0, segments.map(\.upper).max() ?? 0, 0)
            return [
                LivelinePoint(time: point.time, value: lower),
                LivelinePoint(time: point.time, value: upper),
            ]
        }
    }

    static func stackedPrimaryValue(point: LivelineStackedPoint?, mode: LivelineStackMode) -> Double {
        guard let point else { return 0 }
        switch mode {
        case .standard:
            return point.total
        case .normalized:
            if point.values.contains(where: { $0 > 0 }) { return 1 }
            if point.values.contains(where: { $0 < 0 }) { return -1 }
            return 0
        }
    }

    /// Splits raw samples into contiguous frequency bins.
    ///
    /// Non-finite samples are dropped. An empty input produces no bins, and a
    /// set of samples with no spread produces a single zero-width bin holding
    /// all of them. Every bin is half-open except the last, which is closed so
    /// the largest sample is counted.
    static func histogramBins(
        values: [Double],
        binning: LivelineHistogramBinning
    ) -> [LivelineHistogramBin] {
        let samples = values.filter(\.isFinite).sorted()
        guard let minimum = samples.first, let maximum = samples.last else { return [] }
        guard maximum > minimum else {
            return [LivelineHistogramBin(lowerBound: minimum, upperBound: maximum, count: samples.count)]
        }

        let binCount = histogramBinCount(sortedSamples: samples, binning: binning)
        let width = (maximum - minimum) / Double(binCount)
        var counts = [Int](repeating: 0, count: binCount)
        for sample in samples {
            let index = min(Int((sample - minimum) / width), binCount - 1)
            counts[max(index, 0)] += 1
        }
        return (0..<binCount).map { index in
            LivelineHistogramBin(
                lowerBound: minimum + Double(index) * width,
                upperBound: index == binCount - 1 ? maximum : minimum + Double(index + 1) * width,
                count: counts[index]
            )
        }
    }

    /// Number of bins the rule asks for, clamped to something a canvas can draw.
    static func histogramBinCount(
        sortedSamples: [Double],
        binning: LivelineHistogramBinning
    ) -> Int {
        let count = sortedSamples.count
        guard count > 0 else { return 0 }

        func sturges() -> Int {
            count <= 1 ? 1 : Int(ceil(log2(Double(count)))) + 1
        }

        func freedmanDiaconis() -> Int? {
            guard count >= 4,
                  let minimum = sortedSamples.first,
                  let maximum = sortedSamples.last,
                  maximum > minimum
            else {
                return nil
            }
            let iqr = quantile(sortedSamples: sortedSamples, 0.75) - quantile(sortedSamples: sortedSamples, 0.25)
            guard iqr > 0 else { return nil }
            let width = 2 * iqr * pow(Double(count), -1.0 / 3.0)
            guard width > 0 else { return nil }
            let bins = Int(ceil((maximum - minimum) / width))
            return bins > 0 ? bins : nil
        }

        let resolved: Int
        switch binning {
        case .automatic:
            resolved = freedmanDiaconis() ?? sturges()
        case .sturges:
            resolved = sturges()
        case .freedmanDiaconis:
            resolved = freedmanDiaconis() ?? sturges()
        case let .count(explicit):
            resolved = explicit
        }
        return clamp(resolved, 1, 512)
    }

    /// Linear-interpolation quantile over already sorted samples.
    static func quantile(sortedSamples: [Double], _ probability: Double) -> Double {
        guard let first = sortedSamples.first, let last = sortedSamples.last else { return 0 }
        guard sortedSamples.count > 1 else { return first }
        let position = clamp(probability, 0, 1) * Double(sortedSamples.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = min(lower + 1, sortedSamples.count - 1)
        let fraction = position - Double(lower)
        guard lower >= 0 else { return first }
        guard upper < sortedSamples.count else { return last }
        return sortedSamples[lower] + (sortedSamples[upper] - sortedSamples[lower]) * fraction
    }

    /// Fraction of the bullet axis a value sits at, clamped to the track.
    static func bulletProgress(value: Double, range: ClosedRange<Double>) -> Double {
        gaugeProgress(value: value, range: range)
    }

    static func gaugeProgress(value: Double, range: ClosedRange<Double>) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return value >= range.upperBound ? 1 : 0 }
        return clamp((value - range.lowerBound) / span, 0, 1)
    }

    static func heatmapOpacity(
        value: Double,
        minimum: Double,
        maximum: Double,
        minimumOpacity: Double,
        maximumOpacity: Double
    ) -> Double {
        guard maximum > minimum else { return (minimumOpacity + maximumOpacity) / 2 }
        let progress = clamp((value - minimum) / (maximum - minimum), 0, 1)
        return minimumOpacity + progress * (maximumOpacity - minimumOpacity)
    }

    static func polarPoint(center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        CGPoint(
            x: center.x + CGFloat(cos(angle)) * radius,
            y: center.y + CGFloat(sin(angle)) * radius
        )
    }
}

/// One laid-out treemap rectangle, addressed by its position in the node tree:
/// `[i]` for a top-level leaf, `[i, j]` for the `j`th child of the `i`th
/// top-level node.
struct LivelineTreemapTile: Equatable {
    var path: [Int]
    var value: Double
    var rect: CGRect
}

/// One angular span of a sunburst. `fullStart`/`fullEnd` are the exact
/// proportional bounds — a parent's children tile its full span end to end —
/// while `start`/`end` are those bounds inset by the style's gap, which is what
/// actually gets stroked.
struct LivelineSunburstSpan: Equatable {
    var path: [Int]
    var depth: Int
    var value: Double
    var fullStart: Double
    var fullEnd: Double
    var start: Double
    var end: Double

    var fullSweep: Double { fullEnd - fullStart }
    var middle: Double { (fullStart + fullEnd) / 2 }
}

struct LivelineSankeyNode: Equatable {
    var label: String
    var column: Int
    var inflow: Double
    var outflow: Double

    /// What the node's bar is sized by: everything that passes through it.
    var throughput: Double { Swift.max(inflow, outflow) }
}

struct LivelineSankeyResolvedLink: Equatable {
    /// Index into the caller's link array, so colours and hover rows can be
    /// traced back to the input.
    var linkIndex: Int
    var sourceIndex: Int
    var targetIndex: Int
    var value: Double
}

struct LivelineSankeyGraph: Equatable {
    var nodes: [LivelineSankeyNode]
    var links: [LivelineSankeyResolvedLink]
    var columnCount: Int
    /// Links dropped because they closed a cycle, were self-loops, or carried
    /// no value. Surfaced so a debug build can say why an edge vanished.
    var droppedLinkIndices: [Int]

    var total: Double { links.reduce(0) { $0 + $1.value } }

    /// Node indices in each column, in first-appearance order.
    func indices(inColumn column: Int) -> [Int] {
        nodes.indices.filter { nodes[$0].column == column }
    }
}

extension LivelineMath {
    // MARK: - Treemap

    /// Squarified treemap layout (Bruls, Huizing & van Wijk, 2000).
    ///
    /// Returns one rectangle per input value, in input order. Non-positive and
    /// non-finite values get `.zero` — they have no area to occupy — and so
    /// does every value when the target rectangle is degenerate or the values
    /// sum to nothing. The algorithm sorts by value internally, breaking ties
    /// on the original index, so the output is a pure function of the input.
    static func squarifiedRects(values: [Double], in rect: CGRect) -> [CGRect] {
        var result = [CGRect](repeating: .zero, count: values.count)
        guard rect.width > 0, rect.height > 0 else { return result }

        let items = values.enumerated()
            .filter { $0.element.isFinite && $0.element > 0 }
            .sorted { $0.element == $1.element ? $0.offset < $1.offset : $0.element > $1.element }
        let total = items.reduce(0) { $0 + $1.element }
        guard total > 0, !items.isEmpty else { return result }

        // Work in pixel areas so a row's aspect ratio is comparable to the
        // rectangle it is being packed into.
        let scale = Double(rect.width) * Double(rect.height) / total
        let areas = items.map { $0.element * scale }

        var remaining = rect
        var row: [Int] = []
        var rowArea = 0.0

        /// The worst aspect ratio in `row` if it were closed against a strip of
        /// length `side` — the quantity squarify minimizes.
        func worst(_ row: [Int], _ extra: Double?, _ side: Double) -> Double {
            var sum = rowArea
            var maximum = 0.0
            var minimum = Double.greatestFiniteMagnitude
            for index in row {
                maximum = Swift.max(maximum, areas[index])
                minimum = Swift.min(minimum, areas[index])
            }
            if let extra {
                sum += extra
                maximum = Swift.max(maximum, extra)
                minimum = Swift.min(minimum, extra)
            }
            guard sum > 0, side > 0, minimum < .greatestFiniteMagnitude else { return .greatestFiniteMagnitude }
            let sideSquared = side * side
            let sumSquared = sum * sum
            return Swift.max(sideSquared * maximum / sumSquared, sumSquared / (sideSquared * minimum))
        }

        func closeRow() {
            guard !row.isEmpty else { return }
            let vertical = remaining.width >= remaining.height
            let along = vertical ? Double(remaining.height) : Double(remaining.width)
            guard along > 0 else {
                row.removeAll()
                rowArea = 0
                return
            }
            let thickness = CGFloat(rowArea / along)
            var offset = vertical ? remaining.minY : remaining.minX
            for index in row {
                let extent = CGFloat(areas[index] / rowArea) * (vertical ? remaining.height : remaining.width)
                result[items[index].offset] = vertical
                    ? CGRect(x: remaining.minX, y: offset, width: thickness, height: extent)
                    : CGRect(x: offset, y: remaining.minY, width: extent, height: thickness)
                offset += extent
            }
            if vertical {
                remaining = CGRect(
                    x: remaining.minX + thickness,
                    y: remaining.minY,
                    width: Swift.max(remaining.width - thickness, 0),
                    height: remaining.height
                )
            } else {
                remaining = CGRect(
                    x: remaining.minX,
                    y: remaining.minY + thickness,
                    width: remaining.width,
                    height: Swift.max(remaining.height - thickness, 0)
                )
            }
            row.removeAll()
            rowArea = 0
        }

        var index = 0
        while index < areas.count {
            let side = Double(Swift.min(remaining.width, remaining.height))
            if row.isEmpty || worst(row, areas[index], side) <= worst(row, nil, side) {
                row.append(index)
                rowArea += areas[index]
                index += 1
            } else {
                closeRow()
                // A closed row consumed its strip; if nothing is left the
                // remaining values collapse to zero-area rects rather than
                // dividing by zero.
                if remaining.width <= 0 || remaining.height <= 0 { return result }
            }
        }
        closeRow()
        return result
    }

    /// Lays out one or two levels of a treemap: top-level nodes are squarified
    /// across `rect`, and any node with children has its own rectangle
    /// squarified again among them. Only leaves are returned, so a flat list of
    /// nodes and a nested one both produce one tile per drawn cell.
    static func treemapTiles(
        nodes: [LivelineTreemapNode],
        in rect: CGRect,
        padding: CGFloat = 0,
        groupPadding: CGFloat = 0
    ) -> [LivelineTreemapTile] {
        guard !nodes.isEmpty, rect.width > 0, rect.height > 0 else { return [] }
        let inset = Swift.max(padding, 0) / 2
        let group = Swift.max(groupPadding, 0)

        func padded(_ rect: CGRect) -> CGRect? {
            let result = rect.insetBy(dx: inset, dy: inset)
            guard result.width > 0.5, result.height > 0.5 else { return nil }
            return result
        }

        let topRects = squarifiedRects(values: nodes.map(\.resolvedValue), in: rect)
        var tiles: [LivelineTreemapTile] = []
        for (index, node) in nodes.enumerated() {
            let frame = topRects[index]
            guard frame.width > 0, frame.height > 0 else { continue }
            guard !node.children.isEmpty else {
                if let cell = padded(frame) {
                    tiles.append(LivelineTreemapTile(path: [index], value: node.resolvedValue, rect: cell))
                }
                continue
            }
            let inner = frame.insetBy(dx: group / 2, dy: group / 2)
            guard inner.width > 0, inner.height > 0 else { continue }
            let childRects = squarifiedRects(values: node.children.map(\.resolvedValue), in: inner)
            for (childIndex, child) in node.children.enumerated() {
                let childFrame = childRects[childIndex]
                guard childFrame.width > 0, childFrame.height > 0, let cell = padded(childFrame) else { continue }
                tiles.append(
                    LivelineTreemapTile(path: [index, childIndex], value: child.resolvedValue, rect: cell)
                )
            }
        }
        return tiles
    }

    // MARK: - Sunburst

    /// Angular spans for one or two rings of a sunburst, in degrees, starting
    /// at twelve o'clock and running clockwise.
    ///
    /// A parent's children tile the parent's full span exactly; `start`/`end`
    /// then inset each span by half the gap on either side, never past the
    /// point where the segment would invert.
    static func sunburstSpans(
        nodes: [LivelineSunburstNode],
        gapDegrees: Double = 0,
        startDegrees: Double = -90
    ) -> [LivelineSunburstSpan] {
        let weights = nodes.map(\.resolvedValue)
        let total = weights.reduce(0, +)
        guard total > 0 else { return [] }
        let gap = clamp(gapDegrees.isFinite ? gapDegrees : 0, 0, 20)

        func span(path: [Int], depth: Int, value: Double, from start: Double, to end: Double) -> LivelineSunburstSpan {
            let sweep = end - start
            let inset = Swift.min(gap / 2, Swift.max(sweep * 0.35, 0))
            return LivelineSunburstSpan(
                path: path,
                depth: depth,
                value: value,
                fullStart: start,
                fullEnd: end,
                start: start + inset,
                end: end - inset
            )
        }

        var spans: [LivelineSunburstSpan] = []
        var cursor = startDegrees
        for (index, node) in nodes.enumerated() {
            let sweep = weights[index] / total * 360
            let start = cursor
            let end = cursor + sweep
            cursor = end
            guard sweep > 0 else { continue }
            spans.append(span(path: [index], depth: 0, value: weights[index], from: start, to: end))

            let childWeights = node.children.map(\.resolvedValue)
            let childTotal = childWeights.reduce(0, +)
            guard childTotal > 0 else { continue }
            var childCursor = start
            for (childIndex, childWeight) in childWeights.enumerated() {
                let childSweep = childWeight / childTotal * sweep
                let childStart = childCursor
                // The last child closes on the parent's own edge, so rounding
                // never leaves a sliver between the rings.
                let childEnd = childIndex == childWeights.count - 1 ? end : childCursor + childSweep
                childCursor = childEnd
                guard childSweep > 0 else { continue }
                spans.append(
                    span(
                        path: [index, childIndex],
                        depth: 1,
                        value: childWeight,
                        from: childStart,
                        to: childEnd
                    )
                )
            }
        }
        return spans
    }

    // MARK: - Sankey

    /// Derives the node set, the column of each node, and the surviving links
    /// from a flat list of flows.
    ///
    /// Nodes appear in the order their labels are first seen. Columns come from
    /// a single longest-path relaxation over the acyclic remainder — there is
    /// deliberately **no iterative crossing minimization**: the vertical order
    /// inside a column is the input order, which keeps the diagram stable
    /// frame to frame and the layout a pure, single-pass function of the data.
    ///
    /// Cycles are broken by a depth-first walk in input order: an edge back to
    /// a node already on the current stack is dropped and reported in
    /// `droppedLinkIndices`, so a cyclic flow renders as a forest rather than
    /// spinning forever.
    static func sankeyGraph(links: [LivelineSankeyLink]) -> LivelineSankeyGraph {
        var labels: [String] = []
        var indexByLabel: [String: Int] = [:]

        func node(_ label: String) -> Int {
            if let existing = indexByLabel[label] { return existing }
            let index = labels.count
            labels.append(label)
            indexByLabel[label] = index
            return index
        }

        var candidates: [LivelineSankeyResolvedLink] = []
        var dropped: [Int] = []
        for (index, link) in links.enumerated() {
            let source = node(link.source)
            let target = node(link.target)
            guard link.value.isFinite, link.value > 0, source != target else {
                dropped.append(index)
                continue
            }
            candidates.append(
                LivelineSankeyResolvedLink(
                    linkIndex: index,
                    sourceIndex: source,
                    targetIndex: target,
                    value: LivelineScalar.value(link.value)
                )
            )
        }
        guard !labels.isEmpty else {
            return LivelineSankeyGraph(nodes: [], links: [], columnCount: 0, droppedLinkIndices: dropped)
        }

        var outgoing = [[Int]](repeating: [], count: labels.count)
        for (position, link) in candidates.enumerated() {
            outgoing[link.sourceIndex].append(position)
        }

        // Iterative DFS: an edge into a node still on the stack closes a cycle.
        enum Mark { case unseen, onStack, done }
        var marks = [Mark](repeating: .unseen, count: labels.count)
        var removed = Set<Int>()
        var stack: [(node: Int, next: Int)] = []
        for root in labels.indices where marks[root] == .unseen {
            marks[root] = .onStack
            stack.append((root, 0))
            while let frame = stack.last {
                let edges = outgoing[frame.node]
                guard frame.next < edges.count else {
                    marks[frame.node] = .done
                    stack.removeLast()
                    continue
                }
                stack[stack.count - 1].next += 1
                let position = edges[frame.next]
                guard !removed.contains(position) else { continue }
                let target = candidates[position].targetIndex
                switch marks[target] {
                case .onStack:
                    removed.insert(position)
                case .unseen:
                    marks[target] = .onStack
                    stack.append((target, 0))
                case .done:
                    break
                }
            }
        }

        let kept = candidates.enumerated().filter { !removed.contains($0.offset) }.map(\.element)
        dropped.append(contentsOf: removed.map { candidates[$0].linkIndex })
        dropped.sort()

        // Longest-path layering over the acyclic remainder, in topological
        // order so one relaxation pass per edge suffices.
        var indegree = [Int](repeating: 0, count: labels.count)
        var adjacency = [[Int]](repeating: [], count: labels.count)
        for (position, link) in kept.enumerated() {
            indegree[link.targetIndex] += 1
            adjacency[link.sourceIndex].append(position)
        }
        var columns = [Int](repeating: 0, count: labels.count)
        var queue = labels.indices.filter { indegree[$0] == 0 }
        var head = 0
        while head < queue.count {
            let current = queue[head]
            head += 1
            for position in adjacency[current] {
                let target = kept[position].targetIndex
                columns[target] = Swift.max(columns[target], columns[current] + 1)
                indegree[target] -= 1
                if indegree[target] == 0 { queue.append(target) }
            }
        }

        var inflow = [Double](repeating: 0, count: labels.count)
        var outflow = [Double](repeating: 0, count: labels.count)
        for link in kept {
            outflow[link.sourceIndex] += link.value
            inflow[link.targetIndex] += link.value
        }

        let nodes = labels.enumerated().map { index, label in
            LivelineSankeyNode(
                label: label,
                column: columns[index],
                inflow: inflow[index],
                outflow: outflow[index]
            )
        }
        return LivelineSankeyGraph(
            nodes: nodes,
            links: kept,
            columnCount: (columns.max() ?? 0) + 1,
            droppedLinkIndices: dropped
        )
    }
}
