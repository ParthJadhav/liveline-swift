import XCTest

final class StackedChartGestureUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-stacked-gesture-tests"]
        app.launch()
        XCTAssertTrue(chart(0).waitForExistence(timeout: 5))
    }

    func testVerticalDragFromChartCenterScrollsWithoutScrubbing() {
        let initialChartMinY = chart(0).frame.minY

        drag(
            on: chart(0),
            from: CGVector(dx: 0.5, dy: 0.72),
            by: CGVector(dx: 0, dy: -150)
        )

        XCTAssertEqual(diagnosticInt("gesture-hover-updates"), 0)
        XCTAssertEqual(diagnosticText("gesture-hover-active"), "false")
        assertScrolled(from: initialChartMinY, byAtLeast: 70)
        XCTAssertGreaterThan(diagnosticNumber("gesture-scroll-offset"), 70)
    }

    func testVerticalDragWithHorizontalJitterScrollsWithoutScrubbing() {
        let initialChartMinY = chart(0).frame.minY

        drag(
            on: chart(0),
            from: CGVector(dx: 0.45, dy: 0.72),
            by: CGVector(dx: 18, dy: -150)
        )

        XCTAssertEqual(diagnosticInt("gesture-hover-updates"), 0)
        XCTAssertEqual(diagnosticText("gesture-hover-active"), "false")
        assertScrolled(from: initialChartMinY, byAtLeast: 60)
        XCTAssertGreaterThan(diagnosticNumber("gesture-scroll-offset"), 60)
    }

    func testHorizontalScrubWithVerticalJitterDoesNotScroll() {
        drag(
            on: chart(0),
            from: CGVector(dx: 0.18, dy: 0.55),
            by: CGVector(dx: 210, dy: 18)
        )

        XCTAssertLessThan(abs(diagnosticNumber("gesture-scroll-offset")), 3)
        XCTAssertGreaterThan(diagnosticInt("gesture-hover-updates"), 1)
        XCTAssertEqual(diagnosticInt("gesture-hover-clears"), 1)
        XCTAssertEqual(diagnosticText("gesture-hover-active"), "false")
        XCTAssertEqual(diagnosticInt("gesture-hover-direction-violations"), 0)
    }

    func testNearTieRemainsVerticalAndScrolls() {
        let initialChartMinY = chart(0).frame.minY

        drag(
            on: chart(0),
            from: CGVector(dx: 0.35, dy: 0.72),
            by: CGVector(dx: 95, dy: -120)
        )

        XCTAssertEqual(diagnosticInt("gesture-hover-updates"), 0)
        assertScrolled(from: initialChartMinY, byAtLeast: 40)
        XCTAssertGreaterThan(diagnosticNumber("gesture-scroll-offset"), 40)
    }

    func testOppositeHorizontalScrubsEachClearExactlyOnce() {
        drag(
            on: chart(0),
            from: CGVector(dx: 0.18, dy: 0.45),
            by: CGVector(dx: 210, dy: -12)
        )
        drag(
            on: chart(0),
            from: CGVector(dx: 0.82, dy: 0.65),
            by: CGVector(dx: -210, dy: 12)
        )

        XCTAssertLessThan(abs(diagnosticNumber("gesture-scroll-offset")), 3)
        XCTAssertGreaterThan(diagnosticInt("gesture-hover-updates"), 2)
        XCTAssertEqual(diagnosticInt("gesture-hover-clears"), 2)
        XCTAssertEqual(diagnosticText("gesture-hover-active"), "false")
    }

    private func chart(_ index: Int) -> XCUIElement {
        app.otherElements["stacked-chart-\(index)"]
    }

    private func drag(
        on element: XCUIElement,
        from normalizedOffset: CGVector,
        by offset: CGVector
    ) {
        let start = element.coordinate(withNormalizedOffset: normalizedOffset)
        let end = start.withOffset(offset)
        start.press(
            forDuration: 0.05,
            thenDragTo: end,
            withVelocity: .slow,
            thenHoldForDuration: 0
        )
    }

    private func diagnosticText(_ identifier: String) -> String {
        let element = app.staticTexts[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: 2))
        return element.label
    }

    private func diagnosticInt(_ identifier: String) -> Int {
        let text = diagnosticText(identifier)
        guard let value = Int(text) else {
            XCTFail("Expected integer diagnostic for \(identifier), got \(text)")
            return 0
        }
        return value
    }

    private func diagnosticNumber(_ identifier: String) -> Double {
        let text = diagnosticText(identifier)
        guard let value = Double(text) else {
            XCTFail("Expected numeric diagnostic for \(identifier), got \(text)")
            return 0
        }
        return value
    }

    private func assertScrolled(
        from initialChartMinY: CGFloat,
        byAtLeast minimumDistance: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let chart = chart(0)
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                chart.frame.minY < initialChartMinY - minimumDistance
            },
            object: nil
        )

        let result = XCTWaiter.wait(for: [expectation], timeout: 2)
        XCTAssertEqual(
            result,
            .completed,
            "Expected the chart to move vertically with its scroll view; initial minY \(initialChartMinY), final minY \(chart.frame.minY)",
            file: file,
            line: line
        )
    }
}
