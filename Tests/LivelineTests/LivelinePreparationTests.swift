import XCTest
@testable import Liveline

final class LivelinePreparationTests: XCTestCase {
    func testContentNormalizationOrdersDeduplicatesAndDropsInvalidPoints() throws {
        let content = LivelineChartContent.line(
            data: [
                LivelinePoint(time: 30, value: 3),
                LivelinePoint(time: 10, value: 1),
                LivelinePoint(time: 20, value: 2),
                LivelinePoint(time: 20, value: 22),
                LivelinePoint(time: .nan, value: 4),
                LivelinePoint(time: 40, value: .infinity),
            ],
            value: .nan
        ).normalized()

        guard case let .line(data, value) = content else {
            return XCTFail("Expected normalized line content")
        }

        XCTAssertEqual(data, [
            LivelinePoint(time: 10, value: 1),
            LivelinePoint(time: 20, value: 22),
            LivelinePoint(time: 30, value: 3),
        ])
        XCTAssertEqual(value, 3)
        XCTAssertEqual(data.livelineVisible(in: 15...25), [LivelinePoint(time: 20, value: 22)])
    }

    func testSortedInputSkipsNormalizationWork() {
        let points = (0..<64).map { LivelinePoint(time: Double($0) * 0.5, value: Double($0)) }

        let normalized = LivelineInputNormalizer.points(points)
        XCTAssertEqual(normalized, points)
        XCTAssertTrue(normalized.livelineSharesStorage(with: points), "sorted input should reuse its buffer")

        let content = LivelineChartContent.line(data: points, value: 63)
        guard case let .line(normalizedData, normalizedValue) = content.normalized() else {
            return XCTFail("Expected normalized line content")
        }
        XCTAssertTrue(normalizedData.livelineSharesStorage(with: points))
        XCTAssertEqual(normalizedValue, 63)
    }

    func testFastPathAndSlowPathAgreeOnUnsortedAndDuplicateInput() {
        let unsorted = [
            LivelinePoint(time: 30, value: 3),
            LivelinePoint(time: 10, value: 1),
            LivelinePoint(time: 20, value: 2),
            LivelinePoint(time: 20, value: 22),
            LivelinePoint(time: .nan, value: 4),
            LivelinePoint(time: 40, value: .infinity),
        ]

        let normalized = LivelineInputNormalizer.points(unsorted)
        XCTAssertFalse(normalized.livelineSharesStorage(with: unsorted))
        // Re-normalizing an already-clean array must be a no-op, so the fast
        // path and the sort path have to land on the same samples.
        XCTAssertEqual(LivelineInputNormalizer.points(normalized), normalized)
        XCTAssertTrue(LivelineInputNormalizer.points(normalized).livelineSharesStorage(with: normalized))

        let cells = [
            LivelineHeatmapCell(time: 20, row: 2, value: 30),
            LivelineHeatmapCell(time: 10, row: 1, value: 20),
            LivelineHeatmapCell(time: 10, row: 1, value: 21),
        ]
        let normalizedCells = LivelineInputNormalizer.heatmap(cells)
        XCTAssertFalse(normalizedCells.livelineSharesStorage(with: cells))
        XCTAssertEqual(LivelineInputNormalizer.heatmap(normalizedCells), normalizedCells)
        XCTAssertTrue(LivelineInputNormalizer.heatmap(normalizedCells).livelineSharesStorage(with: normalizedCells))

        let clean = [
            LivelineSeries(id: "a", data: [LivelinePoint(time: 0, value: 1)], value: 1, color: .blue),
            LivelineSeries(id: "b", data: [LivelinePoint(time: 0, value: 2)], value: 2, color: .red),
        ]
        XCTAssertTrue(LivelineInputNormalizer.series(clean).livelineSharesStorage(with: clean))
    }

    func testPreparedChartCacheInvalidatesOnDataAndEdgeChanges() {
        let state = LivelineRenderState()
        let points = (0..<200).map { LivelinePoint(time: Double($0), value: Double($0 % 11)) }
        let content = LivelineChartContent.line(data: points, value: 5).normalized()
        let configuration = LivelineChartConfiguration()

        func prepare(_ content: LivelineChartContent, leftEdge: TimeInterval) -> LivelinePreparedChart {
            LivelineChartPreparer.prepare(
                for: content,
                hiddenSeries: [],
                leftEdge: leftEdge,
                rightEdge: 150,
                config: configuration,
                state: state
            )
        }

        let first = prepare(content, leftEdge: 10)
        let repeated = prepare(content, leftEdge: 10)
        XCTAssertTrue(
            repeated.primaryVisible.livelineSharesStorage(with: first.primaryVisible),
            "an unchanged frame should reuse the prepared chart"
        )

        let movedEdges = prepare(content, leftEdge: 20)
        XCTAssertFalse(movedEdges.primaryVisible.livelineSharesStorage(with: first.primaryVisible))
        XCTAssertEqual(movedEdges.primaryVisible.first?.time, 18)

        let restored = prepare(content, leftEdge: 10)
        let appended = LivelineChartContent.line(
            data: points + [LivelinePoint(time: 200, value: 4)],
            value: 4
        ).normalized()
        let afterAppend = prepare(appended, leftEdge: 10)
        XCTAssertFalse(
            afterAppend.primaryVisible.livelineSharesStorage(with: restored.primaryVisible),
            "appended samples must invalidate the prepared chart"
        )
        XCTAssertEqual(afterAppend.primaryValue, 4)

        // A prepared chart without render state never consults the cache.
        let uncached = LivelineChartPreparer.prepare(
            for: content,
            hiddenSeries: [],
            leftEdge: 10,
            rightEdge: 150,
            config: configuration
        )
        XCTAssertEqual(uncached.primaryVisible, restored.primaryVisible)
    }

    func testWaterfallSegmentsAreMemoizedUntilSamplesChange() {
        let state = LivelineRenderState()
        let points = (0..<64).map { LivelinePoint(time: Double($0), value: Double($0 % 5) - 2) }

        let first = state.waterfallSegments(points: points, initialValue: 10)
        let repeated = state.waterfallSegments(points: points, initialValue: 10)
        XCTAssertTrue(repeated.livelineSharesStorage(with: first))
        XCTAssertEqual(first, LivelineMath.waterfallSegments(points: points, initialValue: 10))

        let rebased = state.waterfallSegments(points: points, initialValue: 20)
        XCTAssertFalse(rebased.livelineSharesStorage(with: first))
        XCTAssertEqual(rebased, LivelineMath.waterfallSegments(points: points, initialValue: 20))

        let extended = points + [LivelinePoint(time: 64, value: 3)]
        let grown = state.waterfallSegments(points: extended, initialValue: 20)
        XCTAssertEqual(grown, LivelineMath.waterfallSegments(points: extended, initialValue: 20))
    }

    func testTreemapLayoutIsMemoizedPerNodeSetAndPlotSize() {
        let nodes = [
            LivelineTreemapNode(label: "A", value: 6),
            LivelineTreemapNode(label: "B", value: 4),
        ]
        let style = LivelineTreemapStyle()
        let state = LivelineRenderState()
        let rect = CGRect(x: 0, y: 0, width: 200, height: 120)

        let tiles = state.treemapTiles(nodes: nodes, style: style, in: rect)
        XCTAssertEqual(tiles.count, 2)
        XCTAssertTrue(
            state.treemapTiles(nodes: nodes, style: style, in: rect).livelineSharesStorage(with: tiles)
        )
        // A resize is the one input a radial kind would not have; the treemap
        // must fall out of the memo when the plot changes shape.
        XCTAssertFalse(
            state.treemapTiles(nodes: nodes, style: style, in: rect.insetBy(dx: 4, dy: 0))
                .livelineSharesStorage(with: tiles)
        )
        XCTAssertFalse(
            state.treemapTiles(nodes: nodes, style: LivelineTreemapStyle(padding: 8), in: rect)
                .livelineSharesStorage(with: tiles)
        )

        let content = LivelineChartContent.treemap(nodes: nodes, style: style)
        let prepared = LivelineChartPreparer.prepare(
            for: content,
            hiddenSeries: [],
            leftEdge: 0,
            rightEdge: 10,
            config: LivelineChartConfiguration(),
            state: state
        )
        XCTAssertTrue(prepared.hasData)
        XCTAssertEqual(prepared.primaryValue, 10)
        XCTAssertFalse(
            LivelineChartPreparer.prepare(
                for: .treemap(nodes: [], style: style),
                hiddenSeries: [],
                leftEdge: 0,
                rightEdge: 10,
                config: LivelineChartConfiguration()
            ).hasData
        )
    }

    func testSankeyGraphIsMemoizedOnTheLinksAndSurvivesResizes() {
        let links = [
            LivelineSankeyLink(source: "A", target: "B", value: 10),
            LivelineSankeyLink(source: "B", target: "C", value: 4),
        ]
        let state = LivelineRenderState()

        let graph = state.sankeyGraph(links: links)
        XCTAssertEqual(graph.nodes.count, 3)
        XCTAssertEqual(state.sankeyGraph(links: links), graph)
        XCTAssertNotEqual(
            state.sankeyGraph(links: [LivelineSankeyLink(source: "A", target: "B", value: 10)]),
            graph
        )

        let content = LivelineChartContent.sankey(links: links, style: LivelineSankeyStyle())
        let configuration = LivelineChartConfiguration()
        let prepared = LivelineChartPreparer.prepare(
            for: content,
            hiddenSeries: [],
            leftEdge: 0,
            rightEdge: 10,
            config: configuration,
            state: state
        )
        XCTAssertEqual(prepared.rangePoints.map(\.value), [10, 4])
        XCTAssertEqual(prepared.primaryValue, 14)

        // A flow chart's prepared layout does depend on the links, so its cache
        // key has to change with them.
        let key = LivelineChartPreparer.cacheKey(
            for: content,
            hiddenSeries: [],
            leftEdge: 0,
            rightEdge: 10,
            config: configuration
        )
        XCTAssertNotNil(key)
        XCTAssertNotEqual(
            key,
            LivelineChartPreparer.cacheKey(
                for: .sankey(
                    links: [LivelineSankeyLink(source: "A", target: "Z", value: 10)],
                    style: LivelineSankeyStyle()
                ),
                hiddenSeries: [],
                leftEdge: 0,
                rightEdge: 10,
                config: configuration
            )
        )
    }

    func testHistogramPreparationBinsOnceAndSpansTheCountAxis() {
        let values = [1.0, 2, 2, 3, 3, 3, 4, 9]
        let content = LivelineChartContent.histogram(values: values, style: LivelineHistogramStyle(binning: .count(4)))
        let configuration = LivelineChartConfiguration()
        let state = LivelineRenderState()

        let prepared = LivelineChartPreparer.prepare(
            for: content,
            hiddenSeries: [],
            leftEdge: 0,
            rightEdge: 10,
            config: configuration,
            state: state
        )
        let bins = LivelineMath.histogramBins(values: values, binning: .count(4))

        XCTAssertEqual(prepared.rangePoints.map(\.value), bins.map { Double($0.count) })
        XCTAssertEqual(prepared.rangeOverride, 0...Double(bins.map(\.count).max() ?? 1))
        XCTAssertEqual(prepared.primaryValue, Double(values.count))
        XCTAssertTrue(prepared.hasData)

        // Binning is cacheable: identical samples and rule reuse the buffer.
        let repeated = state.histogramBins(values: values, binning: .count(4))
        XCTAssertTrue(state.histogramBins(values: values, binning: .count(4)).livelineSharesStorage(with: repeated))
        XCTAssertFalse(state.histogramBins(values: values, binning: .count(3)).livelineSharesStorage(with: repeated))

        let key = try? XCTUnwrap(LivelineChartPreparer.cacheKey(
            for: content,
            hiddenSeries: [],
            leftEdge: 0,
            rightEdge: 10,
            config: configuration
        ))
        XCTAssertNotNil(key ?? nil)
        XCTAssertNotEqual(
            key ?? nil,
            LivelineChartPreparer.cacheKey(
                for: .histogram(values: values, style: LivelineHistogramStyle(binning: .count(3))),
                hiddenSeries: [],
                leftEdge: 0,
                rightEdge: 10,
                config: configuration
            )
        )
    }

    func testHistogramNormalizationDropsNonFiniteSamplesAndReusesCleanInput() {
        let clean = [1.0, 2, 3]
        guard case let .histogram(values, _) = LivelineChartContent
            .histogram(values: clean, style: LivelineHistogramStyle())
            .normalized()
        else {
            return XCTFail("Expected normalized histogram content")
        }
        XCTAssertTrue(values.livelineSharesStorage(with: clean))

        guard case let .histogram(repaired, _) = LivelineChartContent
            .histogram(values: [1, .nan, 3, .infinity], style: LivelineHistogramStyle())
            .normalized()
        else {
            return XCTFail("Expected normalized histogram content")
        }
        XCTAssertEqual(repaired, [1, 3])
    }

    func testCenteredStackedAreaPreparationCoversTheOffsetStackAndDropsTheValueAxis() {
        let points = [
            LivelineStackedPoint(time: 1, values: [2, 3]),
            LivelineStackedPoint(time: 2, values: [4, 4]),
        ]
        let configuration = LivelineChartConfiguration()
        let zero = LivelineChartContent.stackedAreas(data: points, style: LivelineStackedAreaStyle())
        let centered = LivelineChartContent.stackedAreas(
            data: points,
            style: LivelineStackedAreaStyle(baseline: .centered)
        )

        let zeroPrepared = LivelineChartPreparer.prepare(
            for: zero,
            hiddenSeries: [],
            leftEdge: 0,
            rightEdge: 10,
            config: configuration
        )
        let centeredPrepared = LivelineChartPreparer.prepare(
            for: centered,
            hiddenSeries: [],
            leftEdge: 0,
            rightEdge: 10,
            config: configuration
        )

        XCTAssertEqual(zeroPrepared.rangePoints.map(\.value), [0, 5, 0, 8])
        XCTAssertEqual(centeredPrepared.rangePoints.map(\.value), [-2.5, 2.5, -4, 4])
        // The padded value range still has to cover the whole offset stack.
        XCTAssertLessThanOrEqual(centeredPrepared.rangeOverride?.lowerBound ?? 0, -4)
        XCTAssertGreaterThanOrEqual(centeredPrepared.rangeOverride?.upperBound ?? 0, 4)
        // Layer magnitudes, and therefore the reported value, are untouched.
        XCTAssertEqual(centeredPrepared.primaryValue, zeroPrepared.primaryValue)

        XCTAssertTrue(zero.semantics().capabilities.usesValueAxis)
        XCTAssertFalse(centered.semantics().capabilities.usesValueAxis)
        XCTAssertFalse(centered.semantics().capabilities.usesCartesianGrid)
        XCTAssertTrue(centered.semantics().capabilities.usesTimeAxis)

        // The two baselines must not share a prepared-chart cache entry.
        XCTAssertNotEqual(
            LivelineChartPreparer.cacheKey(for: zero, hiddenSeries: [], leftEdge: 0, rightEdge: 10, config: configuration),
            LivelineChartPreparer.cacheKey(for: centered, hiddenSeries: [], leftEdge: 0, rightEdge: 10, config: configuration)
        )
    }

    func testBulletPreparationUsesTheMeasureAxisAsItsValueRange() {
        let style = LivelineBulletStyle(
            measure: 72,
            target: 80,
            ranges: [LivelineBulletRange(value: 50, label: "Poor"), LivelineBulletRange(value: 100, label: "Good")]
        )
        let prepared = LivelineChartPreparer.prepare(
            for: .bullet(style: style),
            hiddenSeries: [],
            leftEdge: 0,
            rightEdge: 10,
            config: LivelineChartConfiguration()
        )

        XCTAssertEqual(prepared.primaryValue, 72)
        XCTAssertEqual(prepared.rangeOverride, 0...100)
        XCTAssertTrue(prepared.hasData)
    }

    func testInterpolationNormalizesUnorderedInputAtItsSafeInterface() throws {
        let points = [
            LivelinePoint(time: 10, value: 10),
            LivelinePoint(time: 30, value: 30),
            LivelinePoint(time: 20, value: 20),
        ]

        XCTAssertEqual(try XCTUnwrap(LivelineMath.interpolate(points: points, at: 25)), 25, accuracy: 0.0001)
    }

    func testHeatmapNormalizationPreservesRowsAtSharedTimes() {
        let normalized = LivelineInputNormalizer.heatmap([
            LivelineHeatmapCell(time: 20, row: 2, value: 30),
            LivelineHeatmapCell(time: 10, row: 0, value: 10),
            LivelineHeatmapCell(time: 10, row: 1, value: 20),
            LivelineHeatmapCell(time: 10, row: 1, value: 21),
            LivelineHeatmapCell(time: 20, row: 0, value: 40),
        ])

        XCTAssertEqual(normalized.map(\.id), ["10.0-0", "10.0-1", "20.0-0", "20.0-2"])
        XCTAssertEqual(normalized.map(\.value), [10, 21, 40, 30])
    }

    func testCandleNormalizationRepairsBoundsAndWidth() {
        let content = LivelineChartContent.candle(
            data: [],
            value: .nan,
            candles: [LivelineCandle(time: 20, open: 8, high: 4, low: 12, close: 10)],
            candleWidth: -30,
            liveCandle: nil,
            lineData: [],
            lineValue: .infinity
        ).normalized()

        guard case let .candle(_, value, candles, width, _, _, lineValue) = content else {
            return XCTFail("Expected normalized candle content")
        }

        XCTAssertEqual(value, 10)
        XCTAssertEqual(width, 1)
        XCTAssertEqual(candles.first?.high, 12)
        XCTAssertEqual(candles.first?.low, 4)
        XCTAssertNil(lineValue)
    }

    func testRenderingConfigurationRejectsInvalidScalarInputs() {
        let configuration = LivelineChartConfiguration(
            window: -10,
            windows: [
                LivelineWindowOption(label: "bad", seconds: .nan),
                LivelineWindowOption(label: "zero", seconds: 0),
                LivelineWindowOption(label: "valid", seconds: 20),
                LivelineWindowOption(label: "duplicate", seconds: 20),
            ],
            lineWidth: .nan,
            degen: LivelineDegenOptions(scale: -4),
            tooltipY: .infinity,
            lerpSpeed: 4,
            snapshotElapsedTime: -.infinity,
            padding: LivelinePadding(top: -4, right: .nan)
        ).normalizedForRendering()

        XCTAssertEqual(configuration.window, 30)
        XCTAssertEqual(configuration.windows.map(\.seconds), [20])
        XCTAssertEqual(configuration.lineWidth, 2)
        XCTAssertEqual(configuration.degen?.scale, 0)
        XCTAssertEqual(configuration.tooltipY, 14)
        XCTAssertEqual(configuration.lerpSpeed, 1)
        XCTAssertNil(configuration.resolvedSnapshotElapsedTime)
        XCTAssertEqual(configuration.padding.top, 0)
        XCTAssertNil(configuration.padding.right)
    }

    func testPreparedChartUsesNormalizedWindowSlice() {
        let content = LivelineChartContent.line(
            data: (0..<100).map { LivelinePoint(time: Double($0), value: Double($0)) },
            value: 99
        ).normalized()
        let prepared = LivelineChartPreparer.prepare(
            for: content,
            hiddenSeries: [],
            leftEdge: 40,
            rightEdge: 50,
            config: LivelineChartConfiguration()
        )

        XCTAssertEqual(prepared.primaryVisible.first?.time, 38)
        XCTAssertEqual(prepared.primaryVisible.last?.time, 50)
        XCTAssertEqual(prepared.primaryValue, 99)
        XCTAssertTrue(prepared.hasData)
    }

    func testSeriesNormalizationRemovesDuplicateIDsAndInvalidSamples() {
        let series = LivelineInputNormalizer.series([
            LivelineSeries(
                id: "alpha",
                data: [LivelinePoint(time: 2, value: 2), LivelinePoint(time: 1, value: 1)],
                value: .nan,
                color: .blue
            ),
            LivelineSeries(id: "alpha", data: [], value: 4, color: .red),
            LivelineSeries(id: "", data: [], value: 0, color: .green),
        ])

        XCTAssertEqual(series.count, 1)
        XCTAssertEqual(series[0].data.map(\.time), [1, 2])
        XCTAssertEqual(series[0].value, 2)
    }

    func testMutableStylesResolveNonFiniteScalarsAtTheRenderingBoundary() {
        var bar = LivelineBarStyle()
        bar.baseline = .nan
        bar.widthRatio = .nan
        bar.cornerRadius = .infinity
        XCTAssertEqual(bar.resolvedBaseline, 0)
        XCTAssertEqual(bar.resolvedWidthRatio, 0.7)
        XCTAssertEqual(bar.resolvedCornerRadius, 2)

        var radar = LivelineRadarStyle()
        radar.range = (-Double.infinity)...Double.infinity
        radar.fillOpacity = .nan
        XCTAssertEqual(radar.resolvedRange, 0...1)
        XCTAssertEqual(radar.resolvedFillOpacity, 0.18)

        var gauge = LivelineGaugeStyle()
        gauge.sweepDegrees = .nan
        gauge.lineWidth = .nan
        gauge.target = .nan
        XCTAssertEqual(gauge.resolvedSweepDegrees, 240)
        XCTAssertEqual(gauge.resolvedLineWidth, 18)
        XCTAssertNil(gauge.resolvedTarget)
    }

    func testGaugeRangeAndTimelineOrderAreNormalized() {
        let gauge = LivelineChartContent.gauge(
            value: .nan,
            range: (-Double.infinity)...Double.infinity,
            style: LivelineGaugeStyle()
        ).normalized()
        guard case let .gauge(value, range, _) = gauge else {
            return XCTFail("Expected gauge content")
        }
        XCTAssertEqual(value, 0)
        XCTAssertEqual(range, 0...1)

        let timeline = LivelineChartContent.timeline(
            data: [
                LivelineTimelineItem(id: "late", label: "Late", start: 8, end: 9, lane: 0),
                LivelineTimelineItem(id: "early", label: "Early", start: 2, end: 4, lane: 0),
                LivelineTimelineItem(id: "late", label: "Duplicate", start: 1, end: 2, lane: 1),
            ],
            style: LivelineTimelineStyle()
        ).normalized()
        guard case let .timeline(items, _) = timeline else {
            return XCTFail("Expected timeline content")
        }
        XCTAssertEqual(items.map(\.id), ["late", "early"])
        XCTAssertEqual(items.map(\.start), [1, 2])
    }

    func testExtremeFiniteInputsCannotOverflowRenderingGeometry() {
        let points = LivelineInputNormalizer.points([
            LivelinePoint(time: -.greatestFiniteMagnitude, value: -.greatestFiniteMagnitude),
            LivelinePoint(time: .greatestFiniteMagnitude, value: .greatestFiniteMagnitude),
        ])
        XCTAssertEqual(points.map(\.time), [
            -LivelineScalar.maximumTimeMagnitude,
            LivelineScalar.maximumTimeMagnitude,
        ])
        XCTAssertEqual(points.map(\.value), [
            -LivelineScalar.maximumValueMagnitude,
            LivelineScalar.maximumValueMagnitude,
        ])

        let range = LivelineMath.computeRange(
            points: points,
            currentValue: .greatestFiniteMagnitude,
            referenceValue: -.greatestFiniteMagnitude,
            exaggerate: false
        )
        XCTAssertTrue(range.lowerBound.isFinite)
        XCTAssertTrue(range.upperBound.isFinite)
        XCTAssertLessThan(range.lowerBound, range.upperBound)

        let configuration = LivelineChartConfiguration(
            window: .greatestFiniteMagnitude,
            windows: [LivelineWindowOption(label: "huge", seconds: .greatestFiniteMagnitude)],
            lineWidth: .greatestFiniteMagnitude,
            tooltipY: .greatestFiniteMagnitude,
            orderbook: LivelineOrderbookData(
                bids: [LivelineOrderbookLevel(price: .greatestFiniteMagnitude, size: .greatestFiniteMagnitude)],
                asks: []
            ),
            referenceLine: LivelineReferenceLine(value: .greatestFiniteMagnitude),
            activePoint: LivelineActivePoint(
                time: .greatestFiniteMagnitude,
                value: -.greatestFiniteMagnitude
            ),
            padding: LivelinePadding(top: .greatestFiniteMagnitude)
        ).normalizedForRendering()
        XCTAssertEqual(configuration.window, LivelineScalar.maximumTimeMagnitude)
        XCTAssertEqual(configuration.windows.first?.seconds, LivelineScalar.maximumTimeMagnitude)
        XCTAssertEqual(configuration.lineWidth, LivelineScalar.maximumDrawingMagnitude)
        XCTAssertEqual(configuration.tooltipY, LivelineScalar.maximumDrawingMagnitude)
        XCTAssertEqual(configuration.padding.top, LivelineScalar.maximumDrawingMagnitude)
        XCTAssertEqual(configuration.referenceLine?.value, LivelineScalar.maximumValueMagnitude)
        XCTAssertEqual(configuration.activePoint?.time, LivelineScalar.maximumTimeMagnitude)
        XCTAssertEqual(configuration.orderbook?.bids.first?.size, LivelineScalar.maximumValueMagnitude)

        let timeline = LivelineInputNormalizer.timeline([
            LivelineTimelineItem(id: "extreme", label: "Extreme", start: 0, end: 1, lane: .max),
        ])
        let heatmap = LivelineInputNormalizer.heatmap([
            LivelineHeatmapCell(time: 0, row: .max, value: 1),
        ])
        XCTAssertEqual(timeline.first?.lane, LivelineScalar.maximumDiscreteIndex)
        XCTAssertEqual(heatmap.first?.row, LivelineScalar.maximumDiscreteIndex)

        var gauge = LivelineGaugeStyle()
        gauge.startAngleDegrees = .greatestFiniteMagnitude
        XCTAssertTrue(gauge.resolvedStartAngleDegrees.isFinite)
        XCTAssertLessThan(abs(gauge.resolvedStartAngleDegrees), 360)
    }
}
