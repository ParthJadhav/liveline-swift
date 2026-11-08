import XCTest
@testable import Liveline

final class LivelinePriceRangeTests: XCTestCase {
    func testSubCentRangeUsesFullPlotHeight() {
        for price in [0.0047, 0.000000047, 70_000.0] {
            let lower = price
            let upper = price * 1.001
            let layout = LivelineLayout(
                size: CGSize(width: 300, height: 400),
                padding: LivelineResolvedPadding(top: 12, right: 6, bottom: 22, left: 6),
                minValue: lower, maxValue: upper, leftEdge: 0, rightEdge: 60
            )
            XCTAssertEqual(layout.y(for: lower), 378, accuracy: 1e-8)
            XCTAssertEqual(layout.y(for: upper), 12, accuracy: 1e-8)
            XCTAssertEqual(layout.y(for: (lower + upper) / 2), 195, accuracy: 1e-6)
            XCTAssertEqual(LivelineScalar.valueSpan(lower: lower, upper: upper), upper - lower)
        }
    }

    func testFlatPricesUseRelativePaddingAndRemainCentered() {
        for price in [0.0047, 1e-12, 70_000.0, -0.0047] {
            for exaggerate in [false, true] {
                let range = LivelineMath.computeRange(
                    points: [LivelinePoint(time: 0, value: price)],
                    currentValue: price, referenceValue: nil, exaggerate: exaggerate
                )
                XCTAssertLessThan(range.lowerBound, price)
                XCTAssertGreaterThan(range.upperBound, price)
                XCTAssertLessThan(range.upperBound - range.lowerBound, abs(price) * 0.01)
                XCTAssertEqual((range.lowerBound + range.upperBound) / 2, price, accuracy: abs(price) * 1e-12)
            }
        }
    }

    func testZeroAndDegenerateRangesStayFinite() {
        for price in [0.0, Double.leastNormalMagnitude, Double.leastNonzeroMagnitude] {
            let range = LivelineScalar.nondegenerateRange(lower: price, upper: price, fallback: -1...1)
            XCTAssertTrue(range.lowerBound.isFinite)
            XCTAssertTrue(range.upperBound.isFinite)
            XCTAssertGreaterThan(range.upperBound, range.lowerBound)
            XCTAssertGreaterThan(LivelineScalar.valueSpan(lower: price, upper: price), 0)
        }
    }
}
