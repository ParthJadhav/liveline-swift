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
        ]

        XCTAssertEqual(charts.count, 3)
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
