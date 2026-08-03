import XCTest
@testable import Liveline

final class LivelineMathTests: XCTestCase {
    // MARK: - Squarified treemap

    private func aspectRatio(_ rect: CGRect) -> CGFloat {
        guard rect.width > 0, rect.height > 0 else { return .greatestFiniteMagnitude }
        return max(rect.width / rect.height, rect.height / rect.width)
    }

    func testSquarifiedRectsAllocateAreaInProportionToValue() {
        let values = [6.0, 6, 4, 3, 2, 2, 1]
        let frame = CGRect(x: 10, y: 20, width: 300, height: 200)
        let rects = LivelineMath.squarifiedRects(values: values, in: frame)

        XCTAssertEqual(rects.count, values.count)
        let total = values.reduce(0, +)
        let frameArea = Double(frame.width * frame.height)
        for (value, rect) in zip(values, rects) {
            XCTAssertEqual(Double(rect.width * rect.height), value / total * frameArea, accuracy: 0.5)
            XCTAssertTrue(frame.insetBy(dx: -0.001, dy: -0.001).contains(rect), "\(rect) escaped the frame")
        }
        // The tiles cover the frame exactly once.
        XCTAssertEqual(
            rects.reduce(0.0) { $0 + Double($1.width * $1.height) },
            frameArea,
            accuracy: 1
        )
    }

    func testSquarifiedRectsKeepCellsCloseToSquare() {
        let values = (1...24).map { Double($0) }
        let rects = LivelineMath.squarifiedRects(values: values, in: CGRect(x: 0, y: 0, width: 400, height: 300))

        // Squarifying exists to bound this; a naive slice-and-dice layout of
        // the same values produces ratios an order of magnitude worse.
        for (value, rect) in zip(values, rects) {
            XCTAssertLessThan(aspectRatio(rect), 5, "value \(value) produced \(rect)")
        }
        XCTAssertLessThan(rects.map(aspectRatio).reduce(0, +) / CGFloat(rects.count), 2.5)
    }

    func testSquarifiedRectsDropNonPositiveValuesAndDegenerateFrames() {
        let values = [4.0, 0, -3, .nan, 2, .infinity]
        let rects = LivelineMath.squarifiedRects(values: values, in: CGRect(x: 0, y: 0, width: 100, height: 100))

        XCTAssertEqual(rects.count, values.count)
        XCTAssertEqual(rects[1], .zero)
        XCTAssertEqual(rects[2], .zero)
        XCTAssertEqual(rects[3], .zero)
        XCTAssertEqual(rects[5], .zero)
        XCTAssertGreaterThan(rects[0].width * rects[0].height, 0)
        XCTAssertEqual(
            Double(rects[0].width * rects[0].height) / Double(rects[4].width * rects[4].height),
            2,
            accuracy: 0.01
        )

        XCTAssertTrue(LivelineMath.squarifiedRects(values: [], in: CGRect(x: 0, y: 0, width: 10, height: 10)).isEmpty)
        XCTAssertEqual(
            LivelineMath.squarifiedRects(values: [1, 2], in: CGRect(x: 0, y: 0, width: 0, height: 10)),
            [.zero, .zero]
        )
        XCTAssertEqual(
            LivelineMath.squarifiedRects(values: [0, 0], in: CGRect(x: 0, y: 0, width: 10, height: 10)),
            [.zero, .zero]
        )
    }

    func testSquarifiedRectsAreDeterministicAcrossRuns() {
        let values = [5.0, 5, 3, 3, 1]
        let frame = CGRect(x: 4, y: 6, width: 220, height: 140)
        let first = LivelineMath.squarifiedRects(values: values, in: frame)

        for _ in 0..<4 {
            XCTAssertEqual(LivelineMath.squarifiedRects(values: values, in: frame), first)
        }
        // Equal values are ordered by their original index, never by hash order.
        XCTAssertEqual(first[2].origin.y <= first[3].origin.y || first[2].origin.x <= first[3].origin.x, true)
    }

    func testTreemapTilesSubdivideOnlyNodesThatHaveChildren() {
        let nodes = [
            LivelineTreemapNode(label: "Flat", value: 10),
            LivelineTreemapNode(label: "Group", children: [
                LivelineTreemapNode(label: "A", value: 6),
                LivelineTreemapNode(label: "B", value: 4),
            ]),
        ]
        let tiles = LivelineMath.treemapTiles(nodes: nodes, in: CGRect(x: 0, y: 0, width: 200, height: 200))

        XCTAssertEqual(tiles.map(\.path), [[0], [1, 0], [1, 1]])
        XCTAssertEqual(tiles.map(\.value), [10, 6, 4])
        // The parent's own weight is its children's sum, so the two halves of
        // the frame are equal.
        XCTAssertEqual(
            Double(tiles[0].rect.width * tiles[0].rect.height),
            Double((tiles[1].rect.width * tiles[1].rect.height) + (tiles[2].rect.width * tiles[2].rect.height)),
            accuracy: 1
        )
        XCTAssertTrue(LivelineMath.treemapTiles(nodes: [], in: CGRect(x: 0, y: 0, width: 10, height: 10)).isEmpty)
        XCTAssertTrue(
            LivelineMath.treemapTiles(
                nodes: nodes,
                in: CGRect(x: 0, y: 0, width: 0, height: 200)
            ).isEmpty
        )
    }

    func testTreemapPaddingShrinksEveryCellSymmetrically() {
        let nodes = [
            LivelineTreemapNode(label: "A", value: 1),
            LivelineTreemapNode(label: "B", value: 1),
        ]
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let bare = LivelineMath.treemapTiles(nodes: nodes, in: frame)
        let padded = LivelineMath.treemapTiles(nodes: nodes, in: frame, padding: 4)

        XCTAssertEqual(padded.count, bare.count)
        for (plain, inset) in zip(bare, padded) {
            XCTAssertEqual(inset.rect, plain.rect.insetBy(dx: 2, dy: 2))
        }
    }

    // MARK: - Sunburst spans

    func testSunburstChildSpansTileTheirParentExactly() {
        let nodes = [
            LivelineSunburstNode(label: "Solo", value: 100),
            LivelineSunburstNode(label: "Split", children: [
                LivelineSunburstNode(label: "A", value: 60),
                LivelineSunburstNode(label: "B", value: 40),
            ]),
        ]
        let spans = LivelineMath.sunburstSpans(nodes: nodes)

        XCTAssertEqual(spans.map(\.path), [[0], [1], [1, 0], [1, 1]])
        XCTAssertEqual(spans.map(\.depth), [0, 0, 1, 1])
        // Equal parents split the circle in half, starting at twelve o'clock.
        XCTAssertEqual(spans[0].fullStart, -90, accuracy: 1e-9)
        XCTAssertEqual(spans[0].fullSweep, 180, accuracy: 1e-9)
        XCTAssertEqual(spans[1].fullSweep, 180, accuracy: 1e-9)

        let parent = spans[1]
        let children = spans.filter { $0.depth == 1 }
        XCTAssertEqual(children.map(\.fullSweep).reduce(0, +), parent.fullSweep, accuracy: 1e-9)
        XCTAssertEqual(children.first?.fullStart ?? 0, parent.fullStart, accuracy: 1e-9)
        XCTAssertEqual(children.last?.fullEnd ?? 0, parent.fullEnd, accuracy: 1e-9)
        for (previous, next) in zip(children, children.dropFirst()) {
            XCTAssertEqual(previous.fullEnd, next.fullStart, accuracy: 1e-9)
        }
        XCTAssertEqual(children[0].fullSweep / children[1].fullSweep, 1.5, accuracy: 1e-9)
    }

    func testSunburstGapsInsetEachSpanWithoutMovingItsBounds() {
        let nodes = (0..<4).map { LivelineSunburstNode(label: "N\($0)", value: 1) }
        let spans = LivelineMath.sunburstSpans(nodes: nodes, gapDegrees: 6)

        for span in spans {
            XCTAssertEqual(span.start, span.fullStart + 3, accuracy: 1e-9)
            XCTAssertEqual(span.end, span.fullEnd - 3, accuracy: 1e-9)
            XCTAssertLessThan(span.start, span.end)
        }

        // A gap wider than the wedge is clamped rather than inverting it.
        let slivers = LivelineMath.sunburstSpans(
            nodes: [LivelineSunburstNode(label: "Big", value: 999), LivelineSunburstNode(label: "Tiny", value: 1)],
            gapDegrees: 20
        )
        for span in slivers {
            XCTAssertLessThanOrEqual(span.start, span.end)
        }
        XCTAssertTrue(LivelineMath.sunburstSpans(nodes: []).isEmpty)
        XCTAssertTrue(LivelineMath.sunburstSpans(nodes: [LivelineSunburstNode(label: "Zero", value: 0)]).isEmpty)
    }

    // MARK: - Sankey layout

    func testSankeyGraphLayersNodesByLongestPathFromTheSources() {
        let graph = LivelineMath.sankeyGraph(links: [
            LivelineSankeyLink(source: "A", target: "B", value: 10),
            LivelineSankeyLink(source: "B", target: "D", value: 6),
            LivelineSankeyLink(source: "A", target: "C", value: 5),
            LivelineSankeyLink(source: "C", target: "D", value: 4),
            // A shortcut edge must not pull D back to column 1.
            LivelineSankeyLink(source: "A", target: "D", value: 2),
        ])

        // Nodes appear in the order the links first mention them, which is
        // A, B, then D (from B→D), then C.
        XCTAssertEqual(graph.nodes.map(\.label), ["A", "B", "D", "C"])
        XCTAssertEqual(graph.nodes.map(\.column), [0, 1, 2, 1])
        XCTAssertEqual(graph.columnCount, 3)
        XCTAssertEqual(graph.indices(inColumn: 1), [1, 3])
        XCTAssertEqual(graph.nodes[0].outflow, 17)
        XCTAssertEqual(graph.nodes[0].inflow, 0)
        XCTAssertEqual(graph.nodes[2].inflow, 12)
        XCTAssertEqual(graph.nodes[2].throughput, 12)
        XCTAssertEqual(graph.total, 27)
        XCTAssertTrue(graph.droppedLinkIndices.isEmpty)
    }

    func testSankeyGraphBreaksCyclesAtTheRepeatedNodeAndTerminates() {
        let graph = LivelineMath.sankeyGraph(links: [
            LivelineSankeyLink(source: "A", target: "B", value: 4),
            LivelineSankeyLink(source: "B", target: "C", value: 3),
            LivelineSankeyLink(source: "C", target: "A", value: 2),
        ])

        XCTAssertEqual(graph.droppedLinkIndices, [2])
        XCTAssertEqual(graph.links.map(\.linkIndex), [0, 1])
        XCTAssertEqual(graph.nodes.map(\.column), [0, 1, 2])

        // A two-node cycle, a self-loop, and a zero flow all resolve without
        // hanging or producing a node with no column.
        let tangled = LivelineMath.sankeyGraph(links: [
            LivelineSankeyLink(source: "A", target: "B", value: 5),
            LivelineSankeyLink(source: "B", target: "A", value: 5),
            LivelineSankeyLink(source: "B", target: "B", value: 1),
            LivelineSankeyLink(source: "B", target: "C", value: 0),
        ])
        XCTAssertEqual(tangled.droppedLinkIndices, [1, 2, 3])
        XCTAssertEqual(tangled.links.map(\.linkIndex), [0])
        XCTAssertEqual(tangled.nodes.map(\.label), ["A", "B", "C"])
        XCTAssertEqual(tangled.nodes.map(\.column), [0, 1, 0])

        XCTAssertEqual(LivelineMath.sankeyGraph(links: []).nodes.count, 0)
    }

    func testSankeyGeometryScalesRibbonThicknessWithValue() {
        let links = [
            LivelineSankeyLink(source: "A", target: "B", value: 30),
            LivelineSankeyLink(source: "A", target: "C", value: 10),
        ]
        let layout = LivelineLayout(
            size: CGSize(width: 400, height: 240),
            padding: LivelineResolvedPadding(top: 20, right: 20, bottom: 20, left: 20),
            minValue: 0,
            maxValue: 40,
            leftEdge: 0,
            rightEdge: 10
        )
        let geometry = LivelineRenderer.sankeyGeometry(
            links: links,
            graph: LivelineMath.sankeyGraph(links: links),
            style: LivelineSankeyStyle(),
            layout: layout,
            palette: LivelinePalette.resolve(accent: .blue, mode: .dark, lineWidth: 2),
            reveal: 1
        )

        XCTAssertEqual(geometry.links.count, 2)
        XCTAssertEqual(geometry.nodes.count, 3)
        XCTAssertEqual(
            Double(geometry.links[0].thickness / geometry.links[1].thickness),
            3,
            accuracy: 0.001
        )
        // The source bar is as tall as everything leaving it.
        XCTAssertEqual(
            geometry.nodes[0].rect.height,
            geometry.links[0].thickness + geometry.links[1].thickness,
            accuracy: 0.001
        )
        // Ribbons stack at the source in link order, without overlapping.
        XCTAssertLessThan(geometry.links[0].anchor.y, geometry.links[1].anchor.y)
        XCTAssertLessThan(geometry.nodes[0].rect.maxX, geometry.nodes[1].rect.minX)
        XCTAssertEqual(geometry.nodes[1].rect.minX, geometry.nodes[2].rect.minX, accuracy: 0.001)
    }

    func testSankeyGeometryMirrorsTheFlowInRightToLeftLayouts() {
        let links = [LivelineSankeyLink(source: "A", target: "B", value: 10)]
        func geometry(isRTL: Bool) -> LivelineSankeyGeometry {
            LivelineRenderer.sankeyGeometry(
                links: links,
                graph: LivelineMath.sankeyGraph(links: links),
                style: LivelineSankeyStyle(),
                layout: LivelineLayout(
                    size: CGSize(width: 400, height: 240),
                    padding: LivelineResolvedPadding(top: 20, right: 20, bottom: 20, left: 20),
                    minValue: 0,
                    maxValue: 10,
                    leftEdge: 0,
                    rightEdge: 10,
                    isRTL: isRTL
                ),
                palette: LivelinePalette.resolve(accent: .blue, mode: .dark, lineWidth: 2),
                reveal: 1
            )
        }

        let ltr = geometry(isRTL: false)
        let rtl = geometry(isRTL: true)
        XCTAssertLessThan(ltr.nodes[0].rect.minX, ltr.nodes[1].rect.minX)
        XCTAssertGreaterThan(rtl.nodes[0].rect.minX, rtl.nodes[1].rect.minX)
        XCTAssertEqual(rtl.nodes[0].rect.width, ltr.nodes[0].rect.width, accuracy: 0.001)
        XCTAssertEqual(rtl.nodes[0].rect.height, ltr.nodes[0].rect.height, accuracy: 0.001)
    }

    func testTreemapGeometryMirrorsCellsInRightToLeftLayouts() {
        let nodes = [
            LivelineTreemapNode(label: "A", value: 3),
            LivelineTreemapNode(label: "B", value: 1),
        ]
        func geometry(isRTL: Bool) -> LivelineTreemapGeometry {
            let layout = LivelineLayout(
                size: CGSize(width: 320, height: 200),
                padding: LivelineResolvedPadding(top: 20, right: 20, bottom: 20, left: 20),
                minValue: 0,
                maxValue: 4,
                leftEdge: 0,
                rightEdge: 10,
                isRTL: isRTL
            )
            let rect = CGRect(
                x: layout.plotLeftX,
                y: layout.padding.top,
                width: layout.chartWidth,
                height: layout.chartHeight
            )
            return LivelineRenderer.treemapGeometry(
                nodes: nodes,
                tiles: LivelineMath.treemapTiles(nodes: nodes, in: rect),
                style: LivelineTreemapStyle(),
                layout: layout,
                palette: LivelinePalette.resolve(accent: .blue, mode: .dark, lineWidth: 2),
                reveal: 1
            )
        }

        let ltr = geometry(isRTL: false)
        let rtl = geometry(isRTL: true)
        XCTAssertEqual(ltr.cells.map(\.node.label), ["A", "B"])
        XCTAssertEqual(rtl.cells.map(\.node.label), ["A", "B"])
        XCTAssertLessThan(ltr.cells[0].rect.minX, ltr.cells[1].rect.minX)
        XCTAssertGreaterThan(rtl.cells[0].rect.minX, rtl.cells[1].rect.minX)
        XCTAssertEqual(ltr.cells[0].share, 0.75, accuracy: 1e-9)
    }

    func testSunburstGeometryIsNeverMirroredAndStacksItsTwoRings() {
        let nodes = [
            LivelineSunburstNode(label: "Alpha", value: 3),
            LivelineSunburstNode(label: "Beta", children: [
                LivelineSunburstNode(label: "B1", value: 1),
            ]),
        ]
        func geometry(isRTL: Bool) -> LivelineSunburstGeometry {
            LivelineRenderer.sunburstGeometry(
                nodes: nodes,
                style: LivelineSunburstStyle(),
                layout: LivelineLayout(
                    size: CGSize(width: 320, height: 240),
                    padding: LivelineResolvedPadding(top: 20, right: 20, bottom: 20, left: 20),
                    minValue: 0,
                    maxValue: 4,
                    leftEdge: 0,
                    rightEdge: 10,
                    isRTL: isRTL
                ),
                palette: LivelinePalette.resolve(accent: .blue, mode: .dark, lineWidth: 2),
                reveal: 1
            )
        }

        let ltr = geometry(isRTL: false)
        let rtl = geometry(isRTL: true)
        XCTAssertEqual(ltr.center, rtl.center)
        XCTAssertEqual(ltr.segments.map(\.span.fullStart), rtl.segments.map(\.span.fullStart))
        XCTAssertEqual(ltr.segments.map(\.label), ["Alpha", "Beta", "B1"])
        XCTAssertEqual(ltr.total, 4)

        let inner = ltr.segments[0]
        let outer = ltr.segments[2]
        XCTAssertEqual(inner.innerRadius, ltr.innerRadius, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(outer.innerRadius, inner.outerRadius)
        XCTAssertEqual(outer.outerRadius, ltr.outerRadius, accuracy: 0.001)
        XCTAssertEqual(inner.share, 0.75, accuracy: 1e-9)
    }

    // MARK: - Histogram binning

    func testHistogramBinsCountSamplesAgainstContiguousEdges() {
        let bins = LivelineMath.histogramBins(
            values: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
            binning: .count(5)
        )

        XCTAssertEqual(bins.count, 5)
        XCTAssertEqual(bins.map(\.count), [2, 2, 2, 2, 3])
        XCTAssertEqual(bins.map(\.lowerBound), [0, 2, 4, 6, 8])
        XCTAssertEqual(bins.map(\.upperBound), [2, 4, 6, 8, 10])
        // Edges are contiguous, and every sample lands in exactly one bin.
        XCTAssertEqual(bins.map(\.count).reduce(0, +), 11)
        for (previous, next) in zip(bins, bins.dropFirst()) {
            XCTAssertEqual(previous.upperBound, next.lowerBound)
        }
    }

    func testHistogramBinsPlaceBoundarySamplesInTheUpperBin() {
        let bins = LivelineMath.histogramBins(values: [0, 5, 5, 10], binning: .count(2))

        XCTAssertEqual(bins.map(\.count), [1, 3])
        XCTAssertEqual(bins.first?.lowerBound, 0)
        XCTAssertEqual(bins.last?.upperBound, 10)
    }

    func testHistogramBinsHandleEmptyAndDegenerateInput() {
        XCTAssertTrue(LivelineMath.histogramBins(values: [], binning: .automatic).isEmpty)
        XCTAssertTrue(LivelineMath.histogramBins(values: [.nan, .infinity], binning: .automatic).isEmpty)

        let single = LivelineMath.histogramBins(values: [7], binning: .automatic)
        XCTAssertEqual(single.count, 1)
        XCTAssertEqual(single.first?.lowerBound, 7)
        XCTAssertEqual(single.first?.upperBound, 7)
        XCTAssertEqual(single.first?.count, 1)

        let flat = LivelineMath.histogramBins(values: [3, 3, 3, 3], binning: .count(6))
        XCTAssertEqual(flat.count, 1)
        XCTAssertEqual(flat.first?.count, 4)
    }

    func testHistogramBinCountRulesFollowTheirDefinitions() {
        let samples = (0..<32).map(Double.init)

        XCTAssertEqual(
            LivelineMath.histogramBinCount(sortedSamples: samples, binning: .sturges),
            Int(ceil(log2(32.0))) + 1
        )

        // Freedman-Diaconis: width = 2 * IQR * n^(-1/3).
        let iqr = LivelineMath.quantile(sortedSamples: samples, 0.75)
            - LivelineMath.quantile(sortedSamples: samples, 0.25)
        let width = 2 * iqr * pow(32.0, -1.0 / 3.0)
        XCTAssertEqual(
            LivelineMath.histogramBinCount(sortedSamples: samples, binning: .freedmanDiaconis),
            Int(ceil(31 / width))
        )

        // No spread in the middle half leaves Freedman-Diaconis undefined, so
        // `.automatic` falls back to Sturges.
        let spiked = [Double](repeating: 1, count: 20) + [9]
        XCTAssertEqual(
            LivelineMath.histogramBinCount(sortedSamples: spiked.sorted(), binning: .automatic),
            LivelineMath.histogramBinCount(sortedSamples: spiked.sorted(), binning: .sturges)
        )

        XCTAssertEqual(LivelineMath.histogramBinCount(sortedSamples: samples, binning: .count(0)), 1)
        XCTAssertEqual(LivelineMath.histogramBinCount(sortedSamples: samples, binning: .count(9_999)), 512)
        XCTAssertEqual(LivelineMath.histogramBinCount(sortedSamples: [], binning: .automatic), 0)
    }

    // MARK: - Streamgraph baseline

    func testCenteredStackOffsetsHalveTheStackAroundZero() {
        let values = [2.0, 3.0, 5.0]
        let zero = LivelineMath.stackedSegments(values: values, mode: .standard, baseline: .zero)
        let centered = LivelineMath.stackedSegments(values: values, mode: .standard, baseline: .centered)

        XCTAssertEqual(zero, LivelineMath.stackedSegments(values: values, mode: .standard))
        XCTAssertEqual(centered.count, zero.count)

        let total = values.reduce(0, +)
        XCTAssertEqual(centered.first?.lower ?? 0, -total / 2, accuracy: 1e-9)
        XCTAssertEqual(centered.last?.upper ?? 0, total / 2, accuracy: 1e-9)
        // Every layer keeps its own thickness; only the anchor moves.
        for (offset, plain) in zip(centered, zero) {
            XCTAssertEqual(offset.upper - offset.lower, plain.upper - plain.lower, accuracy: 1e-9)
            XCTAssertEqual(offset.lower, plain.lower - total / 2, accuracy: 1e-9)
        }
    }

    func testCenteredStackRangePointsCoverTheOffsetStack() {
        let points = [
            LivelineStackedPoint(time: 1, values: [2, 3]),
            LivelineStackedPoint(time: 2, values: [4, 4]),
        ]
        let centered = LivelineMath.stackedRangePoints(points: points, mode: .standard, baseline: .centered)

        XCTAssertEqual(centered.map(\.value), [-2.5, 2.5, -4, 4])
        XCTAssertEqual(
            LivelineMath.stackedRangePoints(points: points, mode: .standard, baseline: .zero),
            LivelineMath.stackedRangePoints(points: points, mode: .standard)
        )
    }

    func testZeroBaselineStackingIsUnchangedByTheBaselineOption() {
        for values in [[2.0, 3.0], [-1.0, 4.0, -2.0], [0.0, 0.0]] {
            for mode in LivelineStackMode.allCases {
                XCTAssertEqual(
                    LivelineMath.stackedSegments(values: values, mode: mode, baseline: .zero),
                    LivelineMath.stackedSegments(values: values, mode: mode)
                )
            }
        }
        XCTAssertEqual(LivelineStackedAreaStyle().baseline, .zero)
    }

    // MARK: - Bullet geometry

    func testBulletGeometryMapsBandsMeasureAndTargetOntoTheTrack() {
        let style = LivelineBulletStyle(
            measure: 72,
            target: 80,
            ranges: [
                LivelineBulletRange(value: 100, label: "Good"),
                LivelineBulletRange(value: 50, label: "Poor"),
                LivelineBulletRange(value: 75, label: "OK"),
            ],
            axisRange: 0...100
        )
        let layout = LivelineLayout(
            size: CGSize(width: 320, height: 120),
            padding: LivelineResolvedPadding(top: 10, right: 20, bottom: 10, left: 20),
            minValue: 0,
            maxValue: 100,
            leftEdge: 0,
            rightEdge: 10
        )
        let geometry = LivelineRenderer.bulletGeometry(
            style: style,
            layout: layout,
            palette: LivelinePalette.resolve(accent: .blue, mode: .dark, lineWidth: 2),
            reveal: 1
        )

        // Unordered bands are sorted worst to best and tile the axis end to end.
        XCTAssertEqual(geometry.bands.map(\.range.label), ["Poor", "OK", "Good"])
        XCTAssertEqual(geometry.bands.first?.rect.minX ?? 0, layout.plotLeftX, accuracy: 0.001)
        XCTAssertEqual(geometry.bands.last?.rect.maxX ?? 0, layout.rightX, accuracy: 0.001)
        for (previous, next) in zip(geometry.bands, geometry.bands.dropFirst()) {
            XCTAssertEqual(previous.rect.maxX, next.rect.minX, accuracy: 0.001)
        }

        XCTAssertEqual(geometry.measureProgress, 0.72, accuracy: 1e-9)
        XCTAssertEqual(geometry.measureRect.minX, layout.plotLeftX, accuracy: 0.001)
        XCTAssertEqual(geometry.measureRect.width, layout.chartWidth * 0.72, accuracy: 0.001)
        XCTAssertEqual(geometry.targetProgress ?? 0, 0.8, accuracy: 1e-9)
        XCTAssertEqual(geometry.targetX ?? 0, layout.plotLeftX + layout.chartWidth * 0.8, accuracy: 0.001)
        // The measure bar is thinner than the qualitative track it sits on.
        XCTAssertLessThan(geometry.measureRect.height, geometry.trackRect.height)
    }

    func testBulletStyleDerivesItsAxisAndContainingBand() {
        let style = LivelineBulletStyle(
            measure: 72,
            target: 80,
            ranges: [
                LivelineBulletRange(value: 50, label: "Poor"),
                LivelineBulletRange(value: 75, label: "OK"),
                LivelineBulletRange(value: 100, label: "Good"),
            ]
        )

        XCTAssertEqual(style.resolvedAxisRange, 0...100)
        XCTAssertEqual(style.containingRange?.label, "OK")

        let overshoot = LivelineBulletStyle(measure: 140, ranges: [LivelineBulletRange(value: 100, label: "Good")])
        XCTAssertEqual(overshoot.resolvedAxisRange, 0...140)
        XCTAssertEqual(overshoot.containingRange?.label, "Good")

        let degenerate = LivelineBulletStyle(measure: 0, axisRange: 5...5)
        XCTAssertLessThan(degenerate.resolvedAxisRange.lowerBound, degenerate.resolvedAxisRange.upperBound)
    }

    func testBarRangePointsOnlyAddBaselineToRealData() {
        XCTAssertTrue(LivelineMath.barRangePoints(points: [], baseline: 4).isEmpty)

        let points = [
            LivelinePoint(time: 10, value: 8),
            LivelinePoint(time: 20, value: 12),
        ]
        let rangePoints = LivelineMath.barRangePoints(points: points, baseline: 4)

        XCTAssertEqual(rangePoints.count, 3)
        XCTAssertEqual(rangePoints.last, LivelinePoint(time: 20, value: 4))
    }

    func testRangePointNormalizesBoundsAndExposesMidpoint() {
        let point = LivelineRangePoint(time: 10, lower: 14, upper: 6)

        XCTAssertEqual(point.lower, 6)
        XCTAssertEqual(point.upper, 14)
        XCTAssertEqual(point.midpoint, 10)
    }

    func testBarStyleClampsDrawingValues() {
        let style = LivelineBarStyle(widthRatio: 4, cornerRadius: -3, baseline: 5)

        XCTAssertEqual(style.resolvedWidthRatio, 1)
        XCTAssertEqual(style.resolvedCornerRadius, 0)
        XCTAssertEqual(style.baseline, 5)
    }

    func testRangeStyleClampsOpacityAndLineWidths() {
        let style = LivelineRangeStyle(fillOpacity: 2, boundaryLineWidth: -1, centerLineWidth: -4)

        XCTAssertEqual(style.resolvedFillOpacity, 1)
        XCTAssertEqual(style.resolvedBoundaryLineWidth, 0)
        XCTAssertEqual(style.resolvedCenterLineWidth, 0)
    }

    func testScatterStyleClampsPointAndStrokeSizes() {
        let style = LivelineScatterStyle(pointSize: 0, outlineWidth: -2, connectionLineWidth: -1)

        XCTAssertEqual(style.resolvedPointSize, 2)
        XCTAssertEqual(style.resolvedOutlineWidth, 0)
        XCTAssertEqual(style.resolvedConnectionLineWidth, 0)
    }

    func testSingleRangeMarkerHasVisibleAreaForIntervalAndPoint() {
        let interval = LivelineMath.verticalRangeMarkerRect(x: 20, upperY: 10, lowerY: 40, width: 4)
        XCTAssertEqual(interval, CGRect(x: 18, y: 10, width: 4, height: 30))

        let point = LivelineMath.verticalRangeMarkerRect(x: 20, upperY: 25, lowerY: 25, width: 4)
        XCTAssertEqual(point, CGRect(x: 18, y: 23, width: 4, height: 4))
    }

    func testGridLabelsDeduplicateFormattedValuesByPriority() {
        let keys = LivelineMath.uniqueFormattedGridLabelKeys(
            candidates: [
                (key: 81_800, value: 81.8, priority: 0.4),
                (key: 82_000, value: 82.0, priority: 0.9),
                (key: 82_200, value: 82.2, priority: 0.7),
                (key: 83_000, value: 83.0, priority: 0.5),
            ],
            formatValue: { "\(Int($0.rounded())) ms" }
        )

        XCTAssertEqual(keys, Set([82_000, 83_000]))
    }

    func testEmptyStateTextUsesReadablePaletteOpacity() {
        let dark = LivelinePalette.resolve(accent: .blue, mode: .dark, lineWidth: 2)
        let light = LivelinePalette.resolve(accent: .blue, mode: .light, lineWidth: 2)

        XCTAssertGreaterThanOrEqual(dark.emptyText.livelineRGBA()?.alpha ?? 0, 0.55)
        XCTAssertGreaterThanOrEqual(light.emptyText.livelineRGBA()?.alpha ?? 0, 0.55)
    }

    func testStepStylesClampAndGenerateEachTransitionPosition() {
        let style = LivelineStepStyle(lineWidth: -2, fillOpacity: 4)
        XCTAssertEqual(style.resolvedLineWidth, 0)
        XCTAssertEqual(style.resolvedFillOpacity, 1)

        let input = [CGPoint(x: 0, y: 10), CGPoint(x: 20, y: 30)]
        XCTAssertEqual(
            LivelineMath.stepScreenPoints(points: input, position: .leading),
            [CGPoint(x: 0, y: 10), CGPoint(x: 0, y: 30), CGPoint(x: 20, y: 30)]
        )
        XCTAssertEqual(
            LivelineMath.stepScreenPoints(points: input, position: .center),
            [CGPoint(x: 0, y: 10), CGPoint(x: 10, y: 10), CGPoint(x: 10, y: 30), CGPoint(x: 20, y: 30)]
        )
        XCTAssertEqual(
            LivelineMath.stepScreenPoints(points: input, position: .trailing),
            [CGPoint(x: 0, y: 10), CGPoint(x: 20, y: 10), CGPoint(x: 20, y: 30)]
        )
        XCTAssertEqual(
            LivelineMath.stepScreenPoints(points: [CGPoint(x: 8, y: 12)], position: .center),
            [CGPoint(x: 8, y: 12)]
        )
    }

    func testLollipopStyleClampsDrawingValues() {
        let style = LivelineLollipopStyle(stemWidth: -2, headSize: 0, outlineWidth: -3)

        XCTAssertEqual(style.resolvedStemWidth, 0)
        XCTAssertEqual(style.resolvedHeadSize, 2)
        XCTAssertEqual(style.resolvedOutlineWidth, 0)
    }

    func testBubblePointAndStyleNormalizeInvalidInput() {
        let point = LivelineBubblePoint(time: 10, value: 20, magnitude: -4)
        let style = LivelineBubbleStyle(minimumSize: 30, maximumSize: 4, fillOpacity: -2, outlineWidth: -1)

        XCTAssertEqual(point.magnitude, 0)
        XCTAssertEqual(style.resolvedMinimumSize, 4)
        XCTAssertEqual(style.resolvedMaximumSize, 30)
        XCTAssertEqual(style.resolvedFillOpacity, 0)
        XCTAssertEqual(style.resolvedOutlineWidth, 0)
    }

    func testBubbleDiameterSupportsAreaAndDiameterScaling() {
        let diameter = LivelineMath.bubbleDiameter(
            magnitude: 25,
            minimumMagnitude: 0,
            maximumMagnitude: 100,
            minimumSize: 4,
            maximumSize: 20,
            scale: .diameter
        )
        let area = LivelineMath.bubbleDiameter(
            magnitude: 25,
            minimumMagnitude: 0,
            maximumMagnitude: 100,
            minimumSize: 4,
            maximumSize: 20,
            scale: .area
        )

        XCTAssertEqual(diameter, 8, accuracy: 0.0001)
        XCTAssertEqual(area, sqrt(112), accuracy: 0.0001)
        XCTAssertEqual(
            LivelineMath.bubbleDiameter(
                magnitude: 5,
                minimumMagnitude: 5,
                maximumMagnitude: 5,
                minimumSize: 4,
                maximumSize: 20,
                scale: .area
            ),
            12,
            accuracy: 0.0001
        )
    }

    func testBoxPlotPointNormalizesFiveNumberSummary() {
        let point = LivelineBoxPlotPoint(
            time: 10,
            minimum: 9,
            lowerQuartile: 3,
            median: 7,
            upperQuartile: 1,
            maximum: 5
        )

        XCTAssertEqual(point.minimum, 1)
        XCTAssertEqual(point.lowerQuartile, 3)
        XCTAssertEqual(point.median, 5)
        XCTAssertEqual(point.upperQuartile, 7)
        XCTAssertEqual(point.maximum, 9)
    }

    func testBoxPlotAndWaterfallStylesClampDrawingValues() {
        let box = LivelineBoxPlotStyle(
            widthRatio: 4,
            fillOpacity: -1,
            outlineWidth: -2,
            medianLineWidth: -3,
            whiskerWidthRatio: 0
        )
        XCTAssertEqual(box.resolvedWidthRatio, 1)
        XCTAssertEqual(box.resolvedFillOpacity, 0)
        XCTAssertEqual(box.resolvedOutlineWidth, 0)
        XCTAssertEqual(box.resolvedMedianLineWidth, 0)
        XCTAssertEqual(box.resolvedWhiskerWidthRatio, 0.05)

        let waterfall = LivelineWaterfallStyle(widthRatio: 0, cornerRadius: -2, connectorLineWidth: -3)
        XCTAssertEqual(waterfall.resolvedWidthRatio, 0.05)
        XCTAssertEqual(waterfall.resolvedCornerRadius, 0)
        XCTAssertEqual(waterfall.resolvedConnectorLineWidth, 0)
    }

    func testWaterfallSegmentsPreserveCumulativeStartAndEnd() {
        let segments = LivelineMath.waterfallSegments(
            points: [
                LivelinePoint(time: 10, value: 5),
                LivelinePoint(time: 20, value: -2),
                LivelinePoint(time: 30, value: 4),
            ],
            initialValue: 100
        )

        XCTAssertEqual(segments, [
            LivelineWaterfallSegment(time: 10, start: 100, end: 105, delta: 5),
            LivelineWaterfallSegment(time: 20, start: 105, end: 103, delta: -2),
            LivelineWaterfallSegment(time: 30, start: 103, end: 107, delta: 4),
        ])
    }

    @MainActor
    func testAdditionalChartInitializersConstructViews() {
        let points = [
            LivelinePoint(time: 10, value: 4),
            LivelinePoint(time: 20, value: 8),
        ]
        let ranges = [
            LivelineRangePoint(time: 10, lower: 2, upper: 6),
            LivelineRangePoint(time: 20, lower: 5, upper: 9),
        ]

        let charts = [
            LivelineChart(bars: points, style: LivelineBarStyle(baseline: 5)),
            LivelineChart(range: ranges, style: LivelineRangeStyle(showsCenterLine: true)),
            LivelineChart(
                scatter: points,
                style: LivelineScatterStyle(symbol: .diamond, connection: .curved)
            ),
            LivelineChart(steps: points, style: LivelineStepStyle(position: .center)),
            LivelineChart(lollipops: points, style: LivelineLollipopStyle(headSymbol: .diamond)),
            LivelineChart(
                bubbles: points.map { LivelineBubblePoint(time: $0.time, value: $0.value, magnitude: $0.value) }
            ),
            LivelineChart(
                boxPlots: [
                    LivelineBoxPlotPoint(time: 10, minimum: 1, lowerQuartile: 2, median: 3, upperQuartile: 4, maximum: 5),
                ]
            ),
            LivelineChart(waterfall: points, style: LivelineWaterfallStyle(initialValue: 20)),
        ]

        XCTAssertEqual(charts.count, 8)
    }

    func testErrorBarAndTimelineInputsNormalizeBounds() {
        let error = LivelineErrorBarPoint(time: 10, value: 20, lower: 14, upper: 6)
        XCTAssertEqual(error.lower, 6)
        XCTAssertEqual(error.upper, 14)
        XCTAssertEqual(error.value, 14)

        let interval = LivelineTimelineItem(id: "deploy", label: "Deploy", start: 30, end: 10, lane: -2)
        XCTAssertEqual(interval.start, 10)
        XCTAssertEqual(interval.end, 30)
        XCTAssertEqual(interval.lane, 0)
    }

    func testStackedSegmentsSupportSignedAndNormalizedValues() {
        XCTAssertEqual(
            LivelineMath.stackedSegments(values: [3, 2, -4, -1], mode: .standard),
            [
                LivelineStackSegment(lower: 0, upper: 3),
                LivelineStackSegment(lower: 3, upper: 5),
                LivelineStackSegment(lower: -4, upper: 0),
                LivelineStackSegment(lower: -5, upper: -4),
            ]
        )

        XCTAssertEqual(
            LivelineMath.stackedSegments(values: [3, 1, -2, -2], mode: .normalized),
            [
                LivelineStackSegment(lower: 0, upper: 0.75),
                LivelineStackSegment(lower: 0.75, upper: 1),
                LivelineStackSegment(lower: -0.5, upper: 0),
                LivelineStackSegment(lower: -1, upper: -0.5),
            ]
        )
    }

    func testStackedRangeIncludesPositiveAndNegativeTotals() {
        let points = [LivelineStackedPoint(time: 10, values: [4, -3, 2, -5])]
        let range = LivelineMath.stackedRangePoints(points: points, mode: .standard)

        XCTAssertEqual(range, [
            LivelinePoint(time: 10, value: -8),
            LivelinePoint(time: 10, value: 6),
        ])
        XCTAssertEqual(LivelineMath.stackedPrimaryValue(point: points[0], mode: .standard), -2)
        XCTAssertEqual(LivelineMath.stackedPrimaryValue(point: points[0], mode: .normalized), 1)
    }

    func testGaugeAndHeatmapMathClampToVisibleRanges() {
        XCTAssertEqual(LivelineMath.gaugeProgress(value: -20, range: 0...100), 0)
        XCTAssertEqual(LivelineMath.gaugeProgress(value: 35, range: 0...100), 0.35, accuracy: 0.0001)
        XCTAssertEqual(LivelineMath.gaugeProgress(value: 140, range: 0...100), 1)

        XCTAssertEqual(
            LivelineMath.heatmapOpacity(value: 25, minimum: 0, maximum: 100, minimumOpacity: 0.2, maximumOpacity: 1),
            0.4,
            accuracy: 0.0001
        )
    }

    func testLayoutPaddingOnlyReservesSpaceForVisibleAxes() {
        XCTAssertEqual(
            LivelineMath.resolvedPadding(
                LivelinePadding(),
                badgeEnabled: false,
                showValueAxis: false,
                showTimeAxis: false
            ),
            LivelineResolvedPadding(top: 12, right: 12, bottom: 12, left: 12)
        )
        XCTAssertEqual(
            LivelineMath.resolvedPadding(
                LivelinePadding(),
                badgeEnabled: false,
                showValueAxis: true,
                showTimeAxis: true
            ),
            LivelineResolvedPadding(top: 12, right: 54, bottom: 28, left: 12)
        )
        XCTAssertEqual(
            LivelineMath.resolvedPadding(
                LivelinePadding(top: 3, right: 4, bottom: 5, left: 6),
                badgeEnabled: true,
                showValueAxis: true,
                showTimeAxis: true
            ),
            LivelineResolvedPadding(top: 3, right: 4, bottom: 5, left: 6)
        )
    }

    func testCandleContentReservesValueAxisPaddingForItsInternalGrid() {
        let candleContent = LivelineChartContent.candle(
            data: [],
            value: 0,
            candles: [],
            candleWidth: 30,
            liveCandle: nil,
            lineData: [],
            lineValue: nil
        )

        XCTAssertTrue(candleContent.semantics().capabilities.usesValueAxis)
        XCTAssertFalse(
            LivelineChartContent.gauge(
                value: 0.5,
                range: 0...1,
                style: LivelineGaugeStyle()
            ).semantics().capabilities.usesValueAxis
        )
    }

    func testIntrinsicRevealEasesStaggersAndBuildsPathPrefixes() {
        XCTAssertEqual(LivelineMath.easedReveal(0), 0)
        XCTAssertEqual(LivelineMath.easedReveal(0.5), 0.5, accuracy: 0.0001)
        XCTAssertEqual(LivelineMath.easedReveal(1), 1)
        XCTAssertEqual(LivelineMath.easedReveal(.nan), 0)

        let leading = LivelineMath.staggeredReveal(index: 0, count: 5, reveal: 0.4)
        let trailing = LivelineMath.staggeredReveal(index: 4, count: 5, reveal: 0.4)
        XCTAssertGreaterThan(leading, trailing)
        XCTAssertEqual(LivelineMath.staggeredReveal(index: 4, count: 5, reveal: 1), 1)

        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 10, y: 20),
            CGPoint(x: 20, y: 0),
        ]
        let firstQuarter = LivelineMath.revealedPoints(points, reveal: 0.25)
        XCTAssertEqual(firstQuarter.count, 2)
        XCTAssertEqual(firstQuarter.last?.x ?? -1, 5, accuracy: 0.0001)
        XCTAssertEqual(firstQuarter.last?.y ?? -1, 10, accuracy: 0.0001)

        let finalQuarter = LivelineMath.revealedPoints(points, reveal: 0.75)
        XCTAssertEqual(finalQuarter.count, 3)
        XCTAssertEqual(finalQuarter.last?.x ?? -1, 15, accuracy: 0.0001)
        XCTAssertEqual(finalQuarter.last?.y ?? -1, 10, accuracy: 0.0001)
        XCTAssertEqual(LivelineMath.revealedPoints(points, reveal: 1), points)
    }

    func testReducedMotionSuppressesContinuousAndSpatialEffects() {
        let configuration = LivelineChartConfiguration(
            pulse: true,
            fadeEffects: true,
            degen: LivelineDegenOptions(scale: 1, downMomentum: true)
        )

        let unchanged = configuration.respectingReducedMotion(false)
        XCTAssertTrue(unchanged.pulse)
        XCTAssertTrue(unchanged.fadeEffects)
        XCTAssertNotNil(unchanged.degen)

        let reduced = configuration.respectingReducedMotion(true)
        XCTAssertFalse(reduced.pulse)
        XCTAssertFalse(reduced.fadeEffects)
        XCTAssertNil(reduced.degen)
    }

    func testGaugeGeometryCentersDifferentSweepShapes() {
        let rect = CGRect(x: 0, y: 0, width: 360, height: 240)
        for geometry in [
            LivelineMath.gaugeGeometry(
                in: rect,
                startAngleDegrees: 150,
                sweepDegrees: 240,
                lineWidth: 20,
                hasOuterMarks: true,
                showsValue: true
            ),
            LivelineMath.gaugeGeometry(
                in: rect,
                startAngleDegrees: 180,
                sweepDegrees: 180,
                lineWidth: 14,
                hasOuterMarks: true,
                showsValue: true
            ),
        ] {
            XCTAssertEqual(geometry.visualBounds.midX, rect.midX, accuracy: 0.0001)
            XCTAssertEqual(geometry.visualBounds.midY, rect.midY, accuracy: 0.0001)
            XCTAssertGreaterThan(geometry.radius, 0)
            XCTAssertTrue(rect.insetBy(dx: -0.001, dy: -0.001).contains(geometry.visualBounds))
        }
    }

    func testGaugeStyleNormalizesGeometryAndMarkings() {
        let style = LivelineGaugeStyle(
            startAngleDegrees: .nan,
            sweepDegrees: .infinity,
            lineWidth: .nan,
            trackOpacity: .nan,
            target: .infinity,
            tickCount: 99
        )

        XCTAssertEqual(style.resolvedStartAngleDegrees, 150)
        XCTAssertEqual(style.resolvedSweepDegrees, 240)
        XCTAssertEqual(style.resolvedLineWidth, 18)
        XCTAssertEqual(style.resolvedTrackOpacity, 0.12)
        XCTAssertNil(style.target)
        XCTAssertEqual(style.resolvedTickCount, 25)
    }

    func testExtendedModelsAndStylesNormalizeInvalidInput() {
        let cell = LivelineHeatmapCell(time: 10, row: -4, value: .infinity)
        XCTAssertEqual(cell.row, 0)
        XCTAssertEqual(cell.value, 0)

        let category = LivelineCategoryValue(id: "lost", label: "Lost", value: -4)
        XCTAssertEqual(category.value, 0)

        let errorStyle = LivelineErrorBarStyle(capWidth: -1, lineWidth: -2, pointSize: 0, fillOpacity: 5)
        XCTAssertEqual(errorStyle.resolvedCapWidth, 1)
        XCTAssertEqual(errorStyle.resolvedLineWidth, 0)
        XCTAssertEqual(errorStyle.resolvedPointSize, 2)
        XCTAssertEqual(errorStyle.resolvedFillOpacity, 1)

        let heatmapStyle = LivelineHeatmapStyle(
            minimumOpacity: -1,
            maximumOpacity: 4,
            cellWidthRatio: 0,
            cellHeightRatio: 3,
            cornerRadius: -2
        )
        XCTAssertEqual(heatmapStyle.resolvedMinimumOpacity, 0)
        XCTAssertEqual(heatmapStyle.resolvedMaximumOpacity, 1)
        XCTAssertEqual(heatmapStyle.resolvedCellWidthRatio, 0.05)
        XCTAssertEqual(heatmapStyle.resolvedCellHeightRatio, 1)
        XCTAssertEqual(heatmapStyle.resolvedCornerRadius, 0)
    }

    @MainActor
    func testExtendedChartInitializersConstructViews() {
        let error = [LivelineErrorBarPoint(time: 10, value: 5, lower: 3, upper: 7)]
        let dumbbell = [LivelineDumbbellPoint(time: 10, start: 3, end: 7)]
        let stack = [LivelineStackedPoint(time: 10, values: [2, 3])]
        let timeline = [LivelineTimelineItem(id: "a", label: "A", start: 8, end: 12, lane: 0)]
        let heatmap = [LivelineHeatmapCell(time: 10, row: 0, value: 0.8)]
        let radar = [
            LivelineRadarPoint(label: "A", value: 0.4),
            LivelineRadarPoint(label: "B", value: 0.7),
            LivelineRadarPoint(label: "C", value: 0.5),
        ]
        let categories = [
            LivelineCategoryValue(id: "a", label: "A", value: 4),
            LivelineCategoryValue(id: "b", label: "B", value: 2),
        ]

        let charts = [
            LivelineChart(errorBars: error),
            LivelineChart(dumbbells: dumbbell),
            LivelineChart(stackedBars: stack),
            LivelineChart(stackedAreas: stack),
            LivelineChart(timeline: timeline),
            LivelineChart(heatmap: heatmap),
            LivelineChart(radar: radar),
            LivelineChart(donut: categories),
            LivelineChart(gauge: 0.7),
            LivelineChart(funnel: categories),
        ]

        XCTAssertEqual(charts.count, 10)
    }

    func testInterpolateFindsValueInsideSeries() {
        let points = [
            LivelinePoint(time: 10, value: 100),
            LivelinePoint(time: 20, value: 140),
            LivelinePoint(time: 30, value: 120),
        ]

        XCTAssertEqual(try XCTUnwrap(LivelineMath.interpolate(points: points, at: 15)), 120, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(LivelineMath.interpolate(points: points, at: 25)), 130, accuracy: 0.0001)
    }

    func testInterpolateClampsOutsideSeries() {
        let points = [
            LivelinePoint(time: 10, value: 100),
            LivelinePoint(time: 20, value: 140),
        ]

        XCTAssertEqual(LivelineMath.interpolate(points: points, at: 5), 100)
        XCTAssertEqual(LivelineMath.interpolate(points: points, at: 25), 140)
    }

    func testRangeIncludesReferenceLine() {
        let points = [
            LivelinePoint(time: 1, value: 10),
            LivelinePoint(time: 2, value: 12),
        ]

        let range = LivelineMath.computeRange(points: points, currentValue: 11, referenceValue: 20, exaggerate: false)

        XCTAssertLessThanOrEqual(range.lowerBound, 10)
        XCTAssertGreaterThanOrEqual(range.upperBound, 20)
    }

    func testMomentumUsesRecentMovement() {
        let rising = (0..<12).map { LivelinePoint(time: Double($0), value: Double($0)) }
        let falling = (0..<12).map { LivelinePoint(time: Double($0), value: Double(12 - $0)) }
        let flat = (0..<12).map { LivelinePoint(time: Double($0), value: 4) }

        XCTAssertEqual(LivelineMath.detectMomentum(points: rising), .up)
        XCTAssertEqual(LivelineMath.detectMomentum(points: falling), .down)
        XCTAssertEqual(LivelineMath.detectMomentum(points: flat), .flat)
    }

    func testDecimatorPassesThroughInputsThatFitThePlotWidth() {
        let points = (0..<40).map { LivelinePoint(time: Double($0), value: Double($0 % 7)) }
        let decimated = LivelineDecimator.decimated(points: points, plotWidth: 100)

        XCTAssertEqual(decimated, points)
        XCTAssertTrue(decimated.livelineSharesStorage(with: points))
    }

    func testDecimatorKeepsEndpointsAndColumnExtremes() {
        let width: CGFloat = 40
        let count = 4_000
        let points = (0..<count).map { index -> LivelinePoint in
            let value = sin(Double(index) * 0.03) * 10 + (index % 97 == 0 ? 40 : 0) - (index % 89 == 0 ? 35 : 0)
            return LivelinePoint(time: Double(index), value: value)
        }

        let decimated = LivelineDecimator.decimated(points: points, plotWidth: width)

        XCTAssertLessThan(decimated.count, points.count)
        XCTAssertLessThanOrEqual(decimated.count, LivelineDecimator.sampleLimit(plotWidth: width) + 2)
        XCTAssertEqual(decimated.first, points.first)
        XCTAssertEqual(decimated.last, points.last)
        XCTAssertEqual(decimated.map(\.time), decimated.map(\.time).sorted())
        XCTAssertEqual(decimated.map(\.value).min(), points.map(\.value).min())
        XCTAssertEqual(decimated.map(\.value).max(), points.map(\.value).max())

        // Every horizontal column keeps both of its extremes.
        let columns = LivelineDecimator.sampleLimit(plotWidth: width) / LivelineDecimator.samplesPerPoint
        let span = points[count - 1].time - points[0].time
        var expected: [Int: (min: Double, max: Double)] = [:]
        for point in points {
            let column = min(columns - 1, Int((point.time - points[0].time) / span * Double(columns)))
            let current = expected[column] ?? (point.value, point.value)
            expected[column] = (Swift.min(current.min, point.value), Swift.max(current.max, point.value))
        }
        var produced: [Int: (min: Double, max: Double)] = [:]
        for point in decimated {
            let column = min(columns - 1, Int((point.time - points[0].time) / span * Double(columns)))
            let current = produced[column] ?? (point.value, point.value)
            produced[column] = (Swift.min(current.min, point.value), Swift.max(current.max, point.value))
        }
        for (column, bounds) in expected {
            XCTAssertEqual(produced[column]?.min, bounds.min, "column \(column) lost its minimum")
            XCTAssertEqual(produced[column]?.max, bounds.max, "column \(column) lost its maximum")
        }
    }

    func testDecimatorIsDeterministic() {
        let points = (0..<3_000).map { LivelinePoint(time: Double($0), value: cos(Double($0) * 0.017) * 3) }

        XCTAssertEqual(
            LivelineDecimator.decimated(points: points, plotWidth: 120),
            LivelineDecimator.decimated(points: points, plotWidth: 120)
        )
    }

    func testMonotoneSplinePathCanBeCreatedForMultiplePoints() {
        let path = LivelineMath.monotoneSplinePath(points: [
            CGPoint(x: 0, y: 2),
            CGPoint(x: 10, y: 6),
            CGPoint(x: 20, y: 3),
            CGPoint(x: 30, y: 8),
        ])

        XCTAssertFalse(path.isEmpty)
    }
}
