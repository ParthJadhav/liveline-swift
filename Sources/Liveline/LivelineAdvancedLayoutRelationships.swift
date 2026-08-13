import SwiftUI

// MARK: - Chord

struct LivelineChordArc {
    var index: Int
    var label: String
    var value: Double
    var start: Double
    var sweep: Double

    var end: Double { start + sweep }
    var middle: Double { start + sweep / 2 }
}

struct LivelineChordLayout {
    var arcs: [LivelineChordArc]
    var ribbons: [LivelineChordRibbon]
    var center: CGPoint
    var innerRadius: CGFloat
    var outerRadius: CGFloat
}

struct LivelineChordRibbon {
    var index: Int
    var link: LivelineChordLink
    var sourceStart: Double
    var sourceEnd: Double
    var targetStart: Double
    var targetEnd: Double

    func path(center: CGPoint, radius: CGFloat) -> Path {
        let start = LivelineMath.polarPoint(center: center, radius: radius, angle: sourceStart)
        let end = LivelineMath.polarPoint(center: center, radius: radius, angle: targetEnd)
        var ribbon = Path()
        ribbon.move(to: start)
        ribbon.addCurve(to: end, control1: center, control2: center)
        ribbon.addArc(
            center: center, radius: radius, startAngle: .radians(targetEnd),
            endAngle: .radians(targetStart), clockwise: true)
        let sourceReturn = LivelineMath.polarPoint(
            center: center, radius: radius, angle: sourceEnd)
        ribbon.addCurve(to: sourceReturn, control1: center, control2: center)
        ribbon.addArc(
            center: center, radius: radius, startAngle: .radians(sourceEnd),
            endAngle: .radians(sourceStart), clockwise: true)
        ribbon.closeSubpath()
        return ribbon
    }
}

extension LivelineAdvancedLayout {
    static func chordNodeTotals(
        _ links: [LivelineChordLink]
    ) -> [(label: String, value: Double)] {
        var labels: [String] = []
        var seenLabels: Set<String> = []
        var totals: [String: Double] = [:]
        for link in links where link.value > 0 {
            if seenLabels.insert(link.source).inserted { labels.append(link.source) }
            if seenLabels.insert(link.target).inserted { labels.append(link.target) }
            for label in [link.source, link.target] {
                let sum = totals[label, default: 0] + link.value
                totals[label] = sum.isFinite ? sum : Double.greatestFiniteMagnitude
            }
        }
        return labels.map { ($0, totals[$0, default: 0]) }
    }

    static func chord(
        links: [LivelineChordLink],
        style: LivelineChordStyle,
        layout: LivelineLayout,
        textScale: LivelineTextScale
    ) -> LivelineChordLayout {
        let positive = links.filter { $0.value > 0 }
        let nodeTotals = chordNodeTotals(positive)
        let labels = nodeTotals.map(\.label)
        let totals = Dictionary(uniqueKeysWithValues: nodeTotals.map { ($0.label, $0.value) })
        let maximumNodeTotal = max(nodeTotals.map(\.value).max() ?? 0, 0.000_001)
        let scaledTotal = max(nodeTotals.reduce(0) { $0 + $1.value / maximumNodeTotal }, 0.000_001)
        let basePlot = LivelineRenderer.advancedPlotRect(layout)
        let inset = min(
            textScale.scaled(18),
            max(min(basePlot.width, basePlot.height) / 2 - 0.5, 0))
        let plot = basePlot.insetBy(dx: inset, dy: inset)
        let outerRadius = max(min(plot.width, plot.height) / 2, 0)
        let requestedGap = style.resolvedGapDegrees * Double.pi / 180
        let gap = labels.isEmpty ? 0 : min(requestedGap, 2 * Double.pi / Double(labels.count) * 0.9)
        let available = max(2 * Double.pi - gap * Double(labels.count), 0)

        var angle = -Double.pi / 2
        var arcs: [LivelineChordArc] = []
        arcs.reserveCapacity(labels.count)
        for (index, label) in labels.enumerated() {
            let value = totals[label, default: 0]
            let sweep = available * ((value / maximumNodeTotal) / scaledTotal)
            arcs.append(
                LivelineChordArc(index: index, label: label, value: value, start: angle, sweep: sweep)
            )
            angle += sweep + gap
        }
        let arcsByLabel = Dictionary(uniqueKeysWithValues: arcs.map { ($0.label, $0) })
        var offsets: [String: Double] = [:]
        let ribbons = positive.enumerated().compactMap { index, link -> LivelineChordRibbon? in
            guard let source = arcsByLabel[link.source], let target = arcsByLabel[link.target] else {
                return nil
            }
            if link.source == link.target {
                let start = source.start + offsets[link.source, default: 0]
                let sweep = source.sweep * min(2 * link.value / max(source.value, 0.000_001), 1)
                let midpoint = start + sweep / 2
                offsets[link.source, default: 0] += sweep
                return LivelineChordRibbon(
                    index: index, link: link,
                    sourceStart: start, sourceEnd: midpoint,
                    targetStart: midpoint, targetEnd: start + sweep)
            }
            let sourceStart = source.start + offsets[link.source, default: 0]
            let sourceSweep = source.sweep * link.value / max(source.value, 0.000_001)
            offsets[link.source, default: 0] += sourceSweep
            let targetStart = target.start + offsets[link.target, default: 0]
            let targetSweep = target.sweep * link.value / max(target.value, 0.000_001)
            offsets[link.target, default: 0] += targetSweep
            return LivelineChordRibbon(
                index: index, link: link,
                sourceStart: sourceStart, sourceEnd: sourceStart + sourceSweep,
                targetStart: targetStart, targetEnd: targetStart + targetSweep
            )
        }
        return LivelineChordLayout(
            arcs: arcs,
            ribbons: ribbons,
            center: CGPoint(x: plot.midX, y: plot.midY),
            innerRadius: outerRadius * style.resolvedInnerRadiusRatio,
            outerRadius: outerRadius
        )
    }
}

// MARK: - Parallel coordinates

struct LivelineParallelLayout {
    var plot: CGRect
    var body: CGRect
    var axisCount: Int
    var ranges: [ClosedRange<Double>]
    var recordLabelWidth: CGFloat
    var isRTL: Bool

    func x(axis: Int) -> CGFloat {
        let offset = CGFloat(axis) / CGFloat(max(axisCount - 1, 1)) * body.width
        return isRTL ? body.maxX - offset : body.minX + offset
    }

    func y(_ value: Double, axis: Int) -> CGFloat {
        let index = min(max(axis, 0), max(ranges.count - 1, 0))
        guard ranges.indices.contains(index) else { return body.midY }
        return LivelineRenderer.mapped(value, from: ranges[index], to: (body.maxY, body.minY))
    }
}

extension LivelineAdvancedLayout {
    static func parallelCoordinates(
        records: [LivelineParallelRecord],
        layout: LivelineLayout,
        textScale: LivelineTextScale
    ) -> LivelineParallelLayout? {
        let axisCount = records.map(\.values.count).max() ?? 0
        guard axisCount >= 2 else { return nil }
        let labelHeight = textScale.scaled(22)
        let recordLabelWidth =
            records.count <= 8 ? min(textScale.scaled(52), layout.chartWidth * 0.18) : 0
        let plot = LivelineRenderer.advancedPlotRect(layout)
            .insetBy(dx: textScale.scaled(8), dy: textScale.scaled(8))
        let ranges = (0..<axisCount).map { axis -> ClosedRange<Double> in
            let values = records.compactMap { $0.values.indices.contains(axis) ? $0.values[axis] : nil }
            let lower = values.min() ?? 0
            let upper = values.max() ?? 1
            return lower == upper ? (lower - 0.5)...(upper + 0.5) : lower...upper
        }
        return LivelineParallelLayout(
            plot: plot,
            body: CGRect(
                x: plot.minX + (layout.isRTL ? recordLabelWidth : 0),
                y: plot.minY + labelHeight,
                width: max(plot.width - recordLabelWidth, 1),
                height: max(plot.height - labelHeight, 1)
            ),
            axisCount: axisCount,
            ranges: ranges,
            recordLabelWidth: recordLabelWidth,
            isRTL: layout.isRTL
        )
    }

    static func axisLabel(_ labels: [String], at index: Int) -> String {
        labels.indices.contains(index)
            ? labels[index] : String(format: LivelineStrings.labelAxisFormat, index + 1)
    }

    /// The three ternary axis names, filling in any the caller omitted.
    ///
    /// Drawing, hit testing, VoiceOver, and the audio graph all name the same
    /// three axes, so the fallback belongs in one place rather than repeated at
    /// each reader.
    static func ternaryAxisLabels(_ labels: [String]) -> [String] {
        (0..<3).map { labels.indices.contains($0) ? labels[$0] : ["A", "B", "C"][$0] }
    }
}

// MARK: - Hexbin

struct LivelineHexbinCell {
    var column: Int
    var row: Int
    var center: CGPoint
    var count: Int
    var weight: Double
    /// A representative source point, so a tooltip can name a single-point bin.
    var label: String?
}

struct LivelineHexbinLayout {
    var plot: CGRect
    var radius: CGFloat
    /// Sorted by grid position: hex fills overlap slightly, so a stable order
    /// keeps repeated renders of identical input byte-for-byte identical.
    var cells: [LivelineHexbinCell]
    var maximumWeight: Double
}

extension LivelineAdvancedLayout {
    static func hexbinCellsForInspection(
        points: [LivelineXYPoint],
        style: LivelineHexbinStyle
    ) -> [LivelineHexbinCell] {
        // Membership is computed from normalized data coordinates in `hexbin`,
        // so this canonical plot affects only returned centers, never grouping.
        let layout = LivelineLayout(
            size: CGSize(width: 320, height: 320),
            padding: .init(top: 0, right: 0, bottom: 0, left: 0),
            minValue: 0, maxValue: 1, leftEdge: 0, rightEdge: 1)
        return hexbin(
            points: points, style: style, layout: layout, textScale: .standard)?.cells ?? []
    }

    static func hexbin(
        points: [LivelineXYPoint],
        style: LivelineHexbinStyle,
        layout: LivelineLayout,
        textScale: LivelineTextScale
    ) -> LivelineHexbinLayout? {
        guard !points.isEmpty else { return nil }
        let plot = LivelineRenderer.advancedPlotRect(layout)
            .insetBy(dx: textScale.scaled(5), dy: textScale.scaled(5))
        let xMin = points.map(\.x).min() ?? 0
        let xMax = points.map(\.x).max() ?? 1
        let yMin = points.map(\.y).min() ?? 0
        let yMax = points.map(\.y).max() ?? 1
        let radius = max(plot.width / CGFloat(style.resolvedBinsAcross) / 1.5, 2)
        let normalizedRadius = 1 / CGFloat(style.resolvedBinsAcross) / 1.5
        let normalizedRowHeight = normalizedRadius * sqrt(3)

        struct Aggregate {
            var center: CGPoint
            var count: Int
            var weight: Double
            var label: String?
        }
        var bins: [LivelineHexbinCellKey: Aggregate] = [:]
        for point in points {
            let normalizedX = CGFloat(normalizedProgress(point.x, minimum: xMin, maximum: xMax))
            let normalizedY = CGFloat(1 - normalizedProgress(point.y, minimum: yMin, maximum: yMax))
            let column = Int((normalizedX / (normalizedRadius * 1.5)).rounded())
            let rowOffset = column.isMultiple(of: 2) ? 0 : normalizedRowHeight / 2
            let row = Int(((normalizedY - rowOffset) / normalizedRowHeight).rounded())
            let center = CGPoint(
                x: CGFloat(column) * normalizedRadius * 1.5,
                y: CGFloat(row) * normalizedRowHeight + rowOffset)
            let key = LivelineHexbinCellKey(column: column, row: row)
            let current = bins[key]
            let weight = (current?.weight ?? 0) + point.weight
            bins[key] = Aggregate(
                center: center,
                count: (current?.count ?? 0) + 1,
                weight: weight.isFinite ? weight : Double.greatestFiniteMagnitude,
                label: current?.label ?? point.label
            )
        }

        let cells = bins
            .map {
                let normalizedScreenX = layout.isRTL
                    ? 1 - $0.value.center.x
                    : $0.value.center.x
                return LivelineHexbinCell(
                    column: $0.key.column,
                    row: $0.key.row,
                    center: CGPoint(
                        x: plot.minX + normalizedScreenX * plot.width,
                        y: plot.minY + $0.value.center.y * plot.height),
                    count: $0.value.count,
                    weight: $0.value.weight,
                    label: $0.value.label
                )
            }
            .sorted { ($0.column, $0.row) < ($1.column, $1.row) }
        return LivelineHexbinLayout(
            plot: plot,
            radius: radius,
            cells: cells,
            maximumWeight: max(cells.map(\.weight).max() ?? 0, 0.000_001)
        )
    }

    private static func normalizedProgress(
        _ value: Double,
        minimum: Double,
        maximum: Double
    ) -> Double {
        guard minimum != maximum else { return 0.5 }
        let scale = max(abs(minimum), abs(maximum), 1)
        let scaledMinimum = minimum / scale
        let scaledMaximum = maximum / scale
        let span = scaledMaximum - scaledMinimum
        guard span.isFinite, span > 0 else { return 0.5 }
        return ((value / scale - scaledMinimum) / span)
            .livelineClamped(0, 1, fallback: 0.5)
    }
}

struct LivelineHexbinCellKey: Hashable {
    var column: Int
    var row: Int
}

// MARK: - Marimekko

struct LivelineMarimekkoLayout {
    var columns: [LivelineMarimekkoColumn]
    var plot: CGRect
    var body: CGRect
    var geometry: [LivelineMarimekkoColumnGeometry]
    /// Segment identifiers share a colour across columns, numbered in the order
    /// they are first encountered while walking `geometry`.
    var colorIndexBySegmentID: [String: Int]
}

extension LivelineAdvancedLayout {
    static func marimekko(
        columns: [LivelineMarimekkoColumn],
        style: LivelineMarimekkoStyle,
        layout: LivelineLayout,
        textScale: LivelineTextScale,
        displayScale: CGFloat? = nil
    ) -> LivelineMarimekkoLayout {
        let valid = columns.filter { $0.width > 0 && $0.segments.contains { $0.value > 0 } }
        let labelHeight = style.showsLabels ? textScale.scaled(22) : 0
        let plot = LivelineRenderer.advancedPlotRect(layout)
            .insetBy(dx: textScale.scaled(4), dy: textScale.scaled(4))
        let body = CGRect(
            x: plot.minX,
            y: plot.minY,
            width: plot.width,
            height: max(plot.height - labelHeight, 1)
        )
        let rawGeometry = LivelineVisualGeometry.marimekko(
            columns: valid,
            in: body,
            columnSpacing: style.resolvedColumnSpacing,
            segmentSpacing: style.resolvedSegmentSpacing
        )
        let directionalGeometry = layout.isRTL
            ? rawGeometry.map { column in
                LivelineMarimekkoColumnGeometry(
                    columnIndex: column.columnIndex,
                    rect: CGRect(
                        x: body.minX + body.maxX - column.rect.maxX,
                        y: column.rect.minY,
                        width: column.rect.width,
                        height: column.rect.height
                    ),
                    segments: column.segments.map { segment in
                        LivelineMarimekkoSegmentGeometry(
                            columnIndex: segment.columnIndex,
                            segmentIndex: segment.segmentIndex,
                            rect: CGRect(
                                x: body.minX + body.maxX - segment.rect.maxX,
                                y: segment.rect.minY,
                                width: segment.rect.width,
                                height: segment.rect.height
                            )
                        )
                    }
                )
            }
            : rawGeometry
        let geometry = displayScale.map {
            LivelineVisualGeometry.pixelAligned(directionalGeometry, displayScale: $0)
        } ?? directionalGeometry
        var colorIndexBySegmentID: [String: Int] = [:]
        for columnGeometry in geometry {
            let column = valid[columnGeometry.columnIndex]
            for segmentGeometry in columnGeometry.segments {
                let id = column.segments[segmentGeometry.segmentIndex].id
                if colorIndexBySegmentID[id] == nil {
                    colorIndexBySegmentID[id] = colorIndexBySegmentID.count
                }
            }
        }
        return LivelineMarimekkoLayout(
            columns: valid,
            plot: plot,
            body: body,
            geometry: geometry,
            colorIndexBySegmentID: colorIndexBySegmentID
        )
    }
}

// MARK: - Polar area

struct LivelinePolarWedge {
    var index: Int
    var value: LivelineCategoryValue
    var start: Double
    var sweep: Double
    var radius: CGFloat

    var end: Double { start + sweep }
    var middle: Double { start + sweep / 2 }
}

struct LivelinePolarAreaLayout {
    var wedges: [LivelinePolarWedge]
    var center: CGPoint
    var innerRadius: CGFloat
    var outerRadius: CGFloat
}

extension LivelineAdvancedLayout {
    static func polarArea(
        values: [LivelineCategoryValue],
        style: LivelinePolarAreaStyle,
        layout: LivelineLayout,
        textScale: LivelineTextScale
    ) -> LivelinePolarAreaLayout {
        let valid = values.filter { $0.value > 0 }
        let basePlot = LivelineRenderer.advancedPlotRect(layout)
        let inset = min(
            textScale.scaled(20),
            max(min(basePlot.width, basePlot.height) / 2 - 0.5, 0))
        let plot = basePlot.insetBy(dx: inset, dy: inset)
        let outer = max(min(plot.width, plot.height) / 2, 0)
        let inner = outer * style.resolvedInnerRadiusRatio
        let maximum = max(valid.map(\.value).max() ?? 0, 0.000_001)
        let slice = valid.isEmpty ? 0 : 2 * Double.pi / Double(valid.count)
        let requestedGap = style.resolvedGapDegrees * Double.pi / 180
        let gap = slice > 0 ? min(requestedGap, slice * 0.9) : 0
        let wedges = valid.enumerated().map { index, value in
            LivelinePolarWedge(
                index: index,
                value: value,
                start: -Double.pi / 2 + Double(index) * slice + gap / 2,
                sweep: slice - gap,
                radius: CGFloat(
                    sqrt(
                        Double(inner * inner)
                            + Double(outer * outer - inner * inner) * value.value / maximum
                    )
                )
            )
        }
        return LivelinePolarAreaLayout(
            wedges: wedges,
            center: CGPoint(x: plot.midX, y: plot.midY),
            innerRadius: inner,
            outerRadius: outer
        )
    }
}

// MARK: - Network

struct LivelineNetworkPlacement {
    var node: LivelineNetworkNode
    var center: CGPoint
    var size: CGFloat
    var colorIndex: Int
    var connections: Int
}

struct LivelineNetworkGeometry {
    var plot: CGRect
    var placements: [LivelineNetworkPlacement]
    /// Only the first node for a repeated identifier can be addressed by edges.
    var positionsByID: [String: CGPoint]
}

extension LivelineAdvancedLayout {
    static func network(
        nodes: [LivelineNetworkNode],
        edges: [LivelineNetworkEdge],
        style: LivelineNetworkStyle,
        layout: LivelineLayout,
        textScale: LivelineTextScale
    ) -> LivelineNetworkGeometry? {
        guard !nodes.isEmpty else { return nil }
        let availablePlot = LivelineRenderer.advancedPlotRect(layout)
        let horizontalInset = min(
            textScale.scaled(28), max((availablePlot.width - 1) / 2, 0))
        let verticalInset = min(
            textScale.scaled(24), max((availablePlot.height - 1) / 2, 0))
        let plot = availablePlot.insetBy(dx: horizontalInset, dy: verticalInset)
        let center = CGPoint(x: plot.midX, y: plot.midY)
        let radius = min(plot.width, plot.height) * 0.42
        let columns = max(Int(ceil(sqrt(Double(nodes.count)))), 1)
        let rows = max(Int(ceil(Double(nodes.count) / Double(columns))), 1)
        let maxWeight = max(nodes.map(\.weight).max() ?? 0, 0.000_001)

        var connectionCounts: [String: Int] = [:]
        for edge in edges {
            connectionCounts[edge.source, default: 0] += 1
            connectionCounts[edge.target, default: 0] += 1
        }

        var groupIndices: [String: Int] = [:]
        var positionsByID: [String: CGPoint] = [:]
        var placements: [LivelineNetworkPlacement] = []
        placements.reserveCapacity(nodes.count)

        for (index, node) in nodes.enumerated() {
            let point: CGPoint
            switch style.layout {
            case .radial:
                point = LivelineMath.polarPoint(
                    center: center,
                    radius: radius,
                    angle: -Double.pi / 2 + 2 * Double.pi * Double(index) / Double(nodes.count)
                )
            case .grid:
                point = CGPoint(
                    x: plot.minX + (CGFloat(index % columns) + 0.5) / CGFloat(columns) * plot.width,
                    y: plot.minY + (CGFloat(index / columns) + 0.5) / CGFloat(rows) * plot.height
                )
            }
            // Repeated identifiers are legal input; the first placement owns the
            // identifier so edges resolve to exactly one endpoint.
            let ownsIdentifier = positionsByID[node.id] == nil
            if ownsIdentifier { positionsByID[node.id] = point }
            let group = node.group ?? "__\(index)"
            let colorIndex = groupIndices[group] ?? groupIndices.count
            groupIndices[group] = colorIndex
            placements.append(
                LivelineNetworkPlacement(
                    node: node,
                    center: point,
                    size: style.resolvedMinimumNodeSize
                        + (style.resolvedMaximumNodeSize - style.resolvedMinimumNodeSize)
                        * CGFloat(sqrt(node.weight / maxWeight)),
                    colorIndex: colorIndex,
                    connections: ownsIdentifier ? (connectionCounts[node.id] ?? 0) : 0
                )
            )
        }
        return LivelineNetworkGeometry(
            plot: plot,
            placements: placements,
            positionsByID: positionsByID
        )
    }
}

// MARK: - Contour

struct LivelineContourLayout {
    var plot: CGRect
    var xDomain: ClosedRange<Double>
    var yDomain: ClosedRange<Double>
    var valueRange: ClosedRange<Double>
    var subdivisions: Int
    var isRTL: Bool

    func point(x: Double, y: Double) -> CGPoint {
        CGPoint(
            x: LivelineRenderer.mapped(
                x,
                from: xDomain,
                to: isRTL ? (plot.maxX, plot.minX) : (plot.minX, plot.maxX)
            ),
            y: LivelineRenderer.mapped(y, from: yDomain, to: (plot.maxY, plot.minY))
        )
    }

    func interpolatedSample(
        at location: CGPoint,
        samples: [LivelineContourSample]
    ) -> (x: Double, y: Double, value: Double)? {
        guard plot.contains(location), plot.width > 0, plot.height > 0 else { return nil }
        let xs = Array(Set(samples.map(\.x))).sorted()
        let ys = Array(Set(samples.map(\.y))).sorted()
        guard xs.count >= 2, ys.count >= 2 else { return nil }
        let screenProgress = Double((location.x - plot.minX) / plot.width)
        let xProgress = isRTL ? 1 - screenProgress : screenProgress
        let yProgress = Double((plot.maxY - location.y) / plot.height)
        let x = xDomain.lowerBound + xProgress * (xDomain.upperBound - xDomain.lowerBound)
        let y = yDomain.lowerBound + yProgress * (yDomain.upperBound - yDomain.lowerBound)
        let upperX = xs.firstIndex { $0 >= x } ?? xs.count - 1
        let upperY = ys.firstIndex { $0 >= y } ?? ys.count - 1
        let lowerX = max(upperX - 1, 0)
        let lowerY = max(upperY - 1, 0)
        let values = Dictionary(
            uniqueKeysWithValues: samples.map {
                (LivelineContourCoordinate(x: $0.x, y: $0.y), $0.value)
            })
        guard
            let lowerLeft = values[LivelineContourCoordinate(x: xs[lowerX], y: ys[lowerY])],
            let lowerRight = values[LivelineContourCoordinate(x: xs[upperX], y: ys[lowerY])],
            let upperLeft = values[LivelineContourCoordinate(x: xs[lowerX], y: ys[upperY])],
            let upperRight = values[LivelineContourCoordinate(x: xs[upperX], y: ys[upperY])]
        else { return nil }
        let xSpan = xs[upperX] - xs[lowerX]
        let ySpan = ys[upperY] - ys[lowerY]
        let tx = xSpan > 0 ? (x - xs[lowerX]) / xSpan : 0
        let ty = ySpan > 0 ? (y - ys[lowerY]) / ySpan : 0
        let lower = lowerLeft + (lowerRight - lowerLeft) * tx
        let upper = upperLeft + (upperRight - upperLeft) * tx
        return (x, y, lower + (upper - lower) * ty)
    }
}

struct LivelineContourCoordinate: Hashable {
    var x: Double
    var y: Double
}

extension LivelineAdvancedLayout {
    static func contourSamplesByCoordinate(
        _ samples: [LivelineContourSample]
    ) -> [LivelineContourSample] {
        var grouped: [LivelineContourCoordinate: (mean: Double, count: Int)] = [:]
        for sample in samples {
            let key = LivelineContourCoordinate(x: sample.x, y: sample.y)
            let previous = grouped[key] ?? (0, 0)
            let nextCount = previous.count + 1
            let weight = 1 / Double(nextCount)
            grouped[key] = (
                previous.mean * (1 - weight) + sample.value * weight,
                nextCount
            )
        }
        return grouped.map { key, aggregate in
            LivelineContourSample(
                id: "\(key.x):\(key.y)", x: key.x, y: key.y,
                value: aggregate.mean)
        }.sorted { ($0.x, $0.y) < ($1.x, $1.y) }
    }

    static func contour(
        samples: [LivelineContourSample],
        layout: LivelineLayout,
        textScale: LivelineTextScale
    ) -> LivelineContourLayout? {
        let xs = Array(Set(samples.map(\.x))).sorted()
        let ys = Array(Set(samples.map(\.y))).sorted()
        let collapsed = contourSamplesByCoordinate(samples)
        guard xs.count >= 2, ys.count >= 2, collapsed.count == xs.count * ys.count else {
            return nil
        }
        let plot = LivelineRenderer.advancedPlotRect(layout)
            .insetBy(dx: textScale.scaled(5), dy: textScale.scaled(5))
        let minimum = collapsed.map(\.value).min() ?? 0
        let maximum = collapsed.map(\.value).max() ?? 1
        let coarseCellWidth = plot.width / CGFloat(xs.count - 1)
        let coarseCellHeight = plot.height / CGFloat(ys.count - 1)
        return LivelineContourLayout(
            plot: plot,
            xDomain: xs[0]...xs[xs.count - 1],
            yDomain: ys[0]...ys[ys.count - 1],
            valueRange: minimum...max(maximum, minimum),
            subdivisions: min(max(Int(ceil(max(coarseCellWidth, coarseCellHeight) / 4)), 1), 16),
            isRTL: layout.isRTL
        )
    }
}

// MARK: - Ternary

struct LivelineTernaryLayout {
    var a: CGPoint
    var b: CGPoint
    var c: CGPoint
    var labels: [String]

    func point(_ value: LivelineTernaryPoint) -> CGPoint {
        let proportions = value.proportions
        return CGPoint(
            x: a.x * CGFloat(proportions.a) + b.x * CGFloat(proportions.b)
                + c.x * CGFloat(proportions.c),
            y: a.y * CGFloat(proportions.a) + b.y * CGFloat(proportions.b)
                + c.y * CGFloat(proportions.c)
        )
    }
}

extension LivelineAdvancedLayout {
    /// The label-aware triangle used by both drawing and hit testing.
    ///
    /// `GraphicsContext` text measurement is unavailable to the interaction
    /// builder, so this deliberately uses a stable typographic estimate. Keeping
    /// one geometry source is more important than a sub-point reserve difference:
    /// the visible mark and its interactive region must occupy the same point.
    static func ternary(
        style: LivelineTernaryStyle,
        layout: LivelineLayout,
        textScale: LivelineTextScale
    ) -> LivelineTernaryLayout {
        let labels = ternaryAxisLabels(style.axisLabels)
        let plotBounds = LivelineRenderer.advancedPlotRect(layout)
            .insetBy(dx: textScale.scaled(8), dy: textScale.scaled(22))
        let maximumReserve = plotBounds.width * 0.28
        let leftReserve = min(
            estimatedLabelWidth(labels[1], textScale: textScale) + textScale.scaled(9),
            maximumReserve
        )
        let rightReserve = min(
            estimatedLabelWidth(labels[2], textScale: textScale) + textScale.scaled(9),
            maximumReserve
        )
        let plot = CGRect(
            x: plotBounds.minX + leftReserve,
            y: plotBounds.minY,
            width: max(plotBounds.width - leftReserve - rightReserve, 1),
            height: plotBounds.height
        )
        let side = min(plot.width, plot.height * 2 / sqrt(3))
        let height = side * sqrt(3) / 2
        return LivelineTernaryLayout(
            a: CGPoint(x: plot.midX, y: plot.midY - height / 2),
            b: CGPoint(x: plot.midX - side / 2, y: plot.midY + height / 2),
            c: CGPoint(x: plot.midX + side / 2, y: plot.midY + height / 2),
            labels: labels
        )
    }

    /// A stable typographic width estimate for callers that cannot measure.
    ///
    /// `GraphicsContext` text measurement is unavailable to the interaction
    /// builder and to label-flow passes that must stay pure, so this approximates
    /// by character class rather than by count.
    static func estimatedLabelWidth(_ label: String, textScale: LivelineTextScale) -> CGFloat {
        let units = label.reduce(into: CGFloat.zero) { width, character in
            if character.isWhitespace {
                width += 2.8
            } else if character.unicodeScalars.contains(where: { $0.value >= 0x2E80 }) {
                width += 9
            } else if "ilI1|.,'".contains(character) {
                width += 3.2
            } else if "MW@%".contains(character) {
                width += 7.8
            } else {
                width += 5.4
            }
        }
        return textScale.scaled(units)
    }
}

// MARK: - Waffle

struct LivelineWaffleLayout {
    var values: [LivelineCategoryValue]
    var allocations: [Int]
    var plot: CGRect
    var body: CGRect
    var origin: CGPoint
    var cell: CGFloat
    var spacing: CGFloat
    var columns: Int
    var rows: Int
    var isRTL: Bool

    var cellCount: Int { columns * rows }

    /// Cells fill bottom-up from the reading edge.
    func rect(cellIndex: Int) -> CGRect {
        let logicalColumn = cellIndex % columns
        let column = isRTL ? columns - 1 - logicalColumn : logicalColumn
        let row = rows - 1 - cellIndex / columns
        return CGRect(
            x: origin.x + CGFloat(column) * (cell + spacing),
            y: origin.y + CGFloat(row) * (cell + spacing),
            width: cell,
            height: cell
        )
    }

    /// The first cell belonging to each category, in category order.
    var categoryStartIndices: [Int] {
        var start = 0
        return allocations.map { allocation in
            defer { start += allocation }
            return start
        }
    }
}

extension LivelineAdvancedLayout {
    static func allocatedWaffleValues(
        _ values: [LivelineCategoryValue],
        style: LivelineWaffleStyle
    ) -> [LivelineCategoryValue] {
        let positive = values.filter { $0.value > 0 }
        let allocations = LivelineRenderer.waffleAllocations(
            values: positive,
            cellCount: style.resolvedColumns * style.resolvedRows
        )
        return zip(positive, allocations).compactMap { value, allocation in
            allocation > 0 ? value : nil
        }
    }

    static func waffle(
        values: [LivelineCategoryValue],
        style: LivelineWaffleStyle,
        layout: LivelineLayout,
        textScale: LivelineTextScale
    ) -> LivelineWaffleLayout {
        let valid = values.filter { $0.value > 0 }
        let legendHeight = style.showsLegend ? textScale.scaled(24) : 0
        let plot = LivelineRenderer.advancedPlotRect(layout)
            .insetBy(dx: textScale.scaled(6), dy: textScale.scaled(6))
        let body = CGRect(
            x: plot.minX,
            y: plot.minY,
            width: plot.width,
            height: max(plot.height - legendHeight, 1)
        )
        let columns = style.resolvedColumns
        let rows = style.resolvedRows
        let requestedSpacing = style.resolvedSpacing
        let spacing = min(
            requestedSpacing,
            min(
                columns > 1 ? body.width / CGFloat(columns - 1) : requestedSpacing,
                rows > 1 ? body.height / CGFloat(rows - 1) : requestedSpacing
            ) * 0.9
        )
        let cell = min(
            (body.width - spacing * CGFloat(columns - 1)) / CGFloat(columns),
            (body.height - spacing * CGFloat(rows - 1)) / CGFloat(rows)
        )
        let gridWidth = cell * CGFloat(columns) + spacing * CGFloat(columns - 1)
        let gridHeight = cell * CGFloat(rows) + spacing * CGFloat(rows - 1)
        return LivelineWaffleLayout(
            values: valid,
            allocations: LivelineRenderer.waffleAllocations(values: valid, cellCount: columns * rows),
            plot: plot,
            body: body,
            origin: CGPoint(x: body.midX - gridWidth / 2, y: body.midY - gridHeight / 2),
            cell: max(cell, 0.1),
            spacing: spacing,
            columns: columns,
            rows: rows,
            isRTL: layout.isRTL
        )
    }
}
