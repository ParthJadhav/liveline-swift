import XCTest
@testable import Liveline

final class LivelineMathTests: XCTestCase {
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
