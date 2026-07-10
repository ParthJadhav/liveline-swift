import XCTest
@testable import Liveline

final class LivelineMathTests: XCTestCase {
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

        XCTAssertGreaterThanOrEqual(dark.emptyText.livelineRGBA().alpha, 0.55)
        XCTAssertGreaterThanOrEqual(light.emptyText.livelineRGBA().alpha, 0.55)
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
