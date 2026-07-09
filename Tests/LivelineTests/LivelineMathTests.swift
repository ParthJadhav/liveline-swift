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
