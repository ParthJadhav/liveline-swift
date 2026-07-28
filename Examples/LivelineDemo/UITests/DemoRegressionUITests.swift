import XCTest

final class DemoRegressionUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        XCUIDevice.shared.appearance = .light
        app?.terminate()
        app = nil
        super.tearDown()
    }

    func testUnknownStorybookScenarioShowsLaunchFailure() {
        launch(["--storybook-scenario", "does-not-exist"])

        XCTAssertTrue(
            element("storybook-launch-error").waitForExistence(timeout: 5),
            "An unknown Storybook ID must not fall back to the normal app"
        )
    }

    func testMarketClockContinuesDuringScrollTracking() {
        launch(["-live-market-timer-tests"])

        let scroll = app.scrollViews["live-market-test-scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        let before = diagnosticInt("live-market-update-count")

        let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62))
        let end = start.withOffset(CGVector(dx: 0, dy: -60))
        start.press(
            forDuration: 0.1,
            thenDragTo: end,
            withVelocity: .slow,
            thenHoldForDuration: 1.8
        )

        let after = diagnosticInt("live-market-update-count")
        XCTAssertGreaterThanOrEqual(
            after - before,
            2,
            "The common-mode market clock should fire repeatedly during one held scroll gesture"
        )
    }

    func testStorybookDetectsScrollingOnSupportedIOSVersions() {
        launch(["-storybook-scroll-tests"])

        let scroll = app.scrollViews["storybook-scroll"]
        let toggle = app.switches["storybook-dither-toggle"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "1")
        XCTAssertEqual(app.staticTexts["storybook-scroll-active"].label, "false")
        let enabled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == 'true'"),
            object: app.staticTexts["storybook-dither-animated"]
        )
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 3), .completed)
        let before = diagnosticInt("storybook-scroll-pause-count")

        scroll.swipeUp(velocity: .slow)

        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { [weak self] _, _ in
                guard let self else { return false }
                return self.diagnosticInt("storybook-scroll-pause-count", recordsFailure: false) > before
            },
            object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 3), .completed)
        let resumed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == 'true'"),
            object: app.staticTexts["storybook-dither-animated"]
        )
        XCTAssertEqual(XCTWaiter.wait(for: [resumed], timeout: 3), .completed)
    }

    func testDitherShowcaseRemainsReachableInLandscape() {
        XCUIDevice.shared.orientation = .landscapeLeft
        launch(["--dither-showcase"])

        let scroll = app.scrollViews["dither-showcase-scroll"]
        let lastPanel = app.staticTexts["dither-panel-title-radar"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))

        XCTAssertTrue(
            scrollToViewport(lastPanel, in: scroll, maximumSwipes: 8),
            "The final Dither panel should intersect the short landscape viewport"
        )
    }

    func testSpreadChartHasLightAndDarkModeCoverage() {
        launch(["-ui-test-dark-appearance"])

        let scroll = app.scrollViews["live-demo-scroll"]
        let spread = element("live-spread-chart")
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))

        XCTAssertTrue(spread.waitForExistence(timeout: 5))
        XCTAssertEqual(spread.value as? String, "Dark theme")
        XCTAssertTrue(
            scrollToViewport(spread, in: scroll, maximumSwipes: 12),
            "The Spread chart should be reachable in the Live demo"
        )

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Spread chart — Dark appearance"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.terminate()
        launch(["-ui-test-light-appearance"])

        let lightScroll = app.scrollViews["live-demo-scroll"]
        let lightSpread = element("live-spread-chart")
        XCTAssertTrue(lightScroll.waitForExistence(timeout: 5))
        XCTAssertTrue(lightSpread.waitForExistence(timeout: 5))
        XCTAssertEqual(lightSpread.value as? String, "Light theme")
        XCTAssertTrue(
            scrollToViewport(lightSpread, in: lightScroll, maximumSwipes: 12),
            "The Spread chart should be reachable in Light Mode"
        )

        let lightAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        lightAttachment.name = "Spread chart — Light appearance"
        lightAttachment.lifetime = .keepAlways
        add(lightAttachment)
    }

    func testWindowControlsRemainAccessibleAtLargestTextSize() {
        launch([
            "--storybook-scenario",
            "line-show-value-windows",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
        ])

        let control = app.buttons["liveline-window-15s"]
        XCTAssertTrue(control.waitForExistence(timeout: 5))
        XCTAssertEqual(control.label, "15s")
        XCTAssertGreaterThanOrEqual(control.frame.width, 44)
        XCTAssertGreaterThanOrEqual(control.frame.height, 44)

        control.tap()
        XCTAssertEqual(control.value as? String, "Selected")
        XCTAssertTrue(control.isSelected)

        app.terminate()
        launch(["--storybook-scenario", "multi-compact"])

        let alpha = app.buttons["liveline-series-alpha"]
        let beta = app.buttons["liveline-series-beta"]
        let gamma = app.buttons["liveline-series-gamma"]
        XCTAssertTrue(alpha.waitForExistence(timeout: 5))
        XCTAssertEqual(alpha.label, "Alpha")
        XCTAssertEqual(alpha.value as? String, "Visible")
        XCTAssertTrue(alpha.isSelected)

        alpha.tap()
        beta.tap()
        let requiredExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == false"),
            object: gamma
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [requiredExpectation], timeout: 2),
            .completed
        )
        XCTAssertEqual(alpha.value as? String, "Hidden")
        XCTAssertEqual(beta.value as? String, "Hidden")
        XCTAssertEqual(gamma.value as? String, "Visible, required")
        XCTAssertTrue(gamma.isSelected)

        app.terminate()
        launch(["--storybook-scenario", "candle-mode-controls"])

        let candle = app.buttons["liveline-mode-candle"]
        let line = app.buttons["liveline-mode-line"]
        XCTAssertTrue(candle.waitForExistence(timeout: 5))
        XCTAssertTrue(line.exists)
        XCTAssertEqual(candle.label, "Candle")
        XCTAssertEqual(line.label, "Line")
        XCTAssertEqual(candle.value as? String, "Selected")
        XCTAssertTrue(candle.isSelected)
    }

    private func launch(_ arguments: [String]) {
        app.launchArguments = arguments
        app.launch()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }

    private func scrollToViewport(
        _ element: XCUIElement,
        in scrollView: XCUIElement,
        maximumSwipes: Int
    ) -> Bool {
        for _ in 0..<maximumSwipes {
            if hasMeaningfulIntersection(element, with: scrollView) {
                return true
            }
            scrollView.swipeUp(velocity: .fast)
        }
        return hasMeaningfulIntersection(element, with: scrollView)
    }

    private func hasMeaningfulIntersection(
        _ element: XCUIElement,
        with viewport: XCUIElement
    ) -> Bool {
        guard element.exists, viewport.exists else { return false }

        let elementFrame = element.frame
        let viewportFrame = viewport.frame.insetBy(dx: 0, dy: 8)
        guard
            elementFrame.width > 0,
            elementFrame.height > 0,
            viewportFrame.width > 0,
            viewportFrame.height > 0
        else {
            return false
        }

        let intersection = elementFrame.intersection(viewportFrame)
        return !intersection.isNull
            && intersection.width >= min(44, elementFrame.width)
            && intersection.height >= min(24, elementFrame.height)
    }

    private func diagnosticInt(_ identifier: String, recordsFailure: Bool = true) -> Int {
        let diagnostic = app.staticTexts[identifier]
        guard diagnostic.waitForExistence(timeout: recordsFailure ? 2 : 0.1) else {
            if recordsFailure {
                XCTFail("Missing diagnostic \(identifier)")
            }
            return 0
        }
        guard let value = Int(diagnostic.label) else {
            if recordsFailure {
                XCTFail("Expected integer diagnostic for \(identifier), got \(diagnostic.label)")
            }
            return 0
        }
        return value
    }
}
