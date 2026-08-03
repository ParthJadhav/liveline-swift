import SwiftUI
import XCTest
@testable import Liveline

/// Zoom and pan are pure functions over a viewport and its limits, so the whole
/// interaction model can be checked without ever recognizing a gesture.
final class LivelineViewportTests: XCTestCase {
    /// A hundred seconds of data at one sample per second, shown thirty at a
    /// time — so the zoom-out ceiling is the data extent and the zoom-in floor
    /// is three sample intervals.
    private var limits: LivelineViewportLimits {
        LivelineViewportLimits.resolve(
            window: 30,
            domain: 0...100,
            sampleCount: 101
        )
    }

    // MARK: - Limits

    func testLimitsClampZoomOutToTheDataExtentAndZoomInToAFewSamples() {
        let limits = limits
        XCTAssertEqual(limits.maximumSpan, 100, accuracy: 0.0001)
        XCTAssertEqual(limits.minimumSpan, 3, accuracy: 0.0001)
    }

    func testLimitsCapZoomOutAtTheConfiguredMultipleOfTheWindow() {
        // Far more data than eight windows' worth: the multiplier, not the
        // extent, is what stops the zoom.
        let limits = LivelineViewportLimits.resolve(window: 10, domain: 0...1000)
        XCTAssertEqual(limits.maximumSpan, 80, accuracy: 0.0001)

        let tighter = LivelineViewportLimits.resolve(window: 10, domain: 0...1000, maximumZoomOut: 2)
        XCTAssertEqual(tighter.maximumSpan, 20, accuracy: 0.0001)
    }

    func testLimitsPreferAnExplicitMinimumSpan() {
        let limits = LivelineViewportLimits.resolve(
            window: 30,
            domain: 0...100,
            sampleCount: 101,
            minimumSpan: 12
        )
        XCTAssertEqual(limits.minimumSpan, 12, accuracy: 0.0001)
    }

    func testLimitsNeverInvertWhenTheDataIsThinnerThanTheWindow() {
        let limits = LivelineViewportLimits.resolve(window: 30, domain: 0...1, sampleCount: 2)
        XCTAssertLessThanOrEqual(limits.minimumSpan, limits.maximumSpan)
        // The window the reader picked is still honored even with less data.
        XCTAssertEqual(limits.maximumSpan, 30, accuracy: 0.0001)
    }

    // MARK: - Zoom clamping

    func testZoomClampsAtTheMinimumSpan() {
        let zoomed = LivelineViewport(span: 30, frozenEnd: 60)
            .zoomed(by: 1_000, anchorFraction: 0.5, limits: limits)
        XCTAssertEqual(zoomed.span, limits.minimumSpan, accuracy: 0.0001)
    }

    func testZoomClampsAtTheMaximumSpan() {
        let zoomed = LivelineViewport(span: 30, frozenEnd: 60)
            .zoomed(by: 0.001, anchorFraction: 0.5, limits: limits)
        XCTAssertEqual(zoomed.span, limits.maximumSpan, accuracy: 0.0001)
    }

    func testZoomIgnoresNonsenseFactors() {
        let viewport = LivelineViewport(span: 30, frozenEnd: 60)
        XCTAssertEqual(viewport.zoomed(by: .nan, anchorFraction: 0.5, limits: limits), viewport)
        XCTAssertEqual(viewport.zoomed(by: 0, anchorFraction: 0.5, limits: limits), viewport)
        XCTAssertEqual(viewport.zoomed(by: -2, anchorFraction: 0.5, limits: limits), viewport)
    }

    // MARK: - Anchored zoom

    func testZoomKeepsTheMomentUnderTheCentroidInPlace() {
        let viewport = LivelineViewport(span: 30, frozenEnd: 60)
        for anchor in [0.0, 0.25, 0.5, 0.75, 1.0] {
            let before = viewport.range(liveEdge: limits.domain.upperBound)
            let anchoredTime = before.lowerBound + 30 * anchor

            let zoomed = viewport.zoomed(by: 2, anchorFraction: anchor, limits: limits)
            let after = zoomed.range(liveEdge: limits.domain.upperBound)

            XCTAssertEqual(zoomed.span, 15, accuracy: 0.0001)
            let fraction = (anchoredTime - after.lowerBound) / zoomed.span
            XCTAssertEqual(fraction, anchor, accuracy: 0.0001, "anchor \(anchor) drifted")
        }
    }

    func testZoomWhileFollowingLiveKeepsTheLiveEdgePinned() {
        // A pinch centered anywhere must not detach a live chart: only panning
        // disengages, so the live edge is the pivot regardless of the centroid.
        let zoomed = LivelineViewport.following(window: 30)
            .zoomed(by: 2, anchorFraction: 0, limits: limits)

        XCTAssertTrue(zoomed.isFollowingLive)
        XCTAssertEqual(zoomed.span, 15, accuracy: 0.0001)
        XCTAssertEqual(zoomed.range(liveEdge: 100).upperBound, 100, accuracy: 0.0001)
    }

    // MARK: - Pan clamping

    func testPanClampsAtTheOldestSample() {
        let panned = LivelineViewport(span: 30, frozenEnd: 60)
            .panned(by: -1_000, limits: limits)

        XCTAssertEqual(panned.range(liveEdge: 100).lowerBound, 0, accuracy: 0.0001)
        XCTAssertEqual(panned.frozenEnd, 30)
    }

    func testPanClampsAtTheLiveEdgeAndReengagesFollowing() {
        let panned = LivelineViewport(span: 30, frozenEnd: 60)
            .panned(by: 1_000, limits: limits)

        XCTAssertTrue(panned.isFollowingLive)
        XCTAssertEqual(panned.range(liveEdge: 100).upperBound, 100, accuracy: 0.0001)
    }

    func testPanCannotEscapeADomainNarrowerThanTheSpan() {
        // Thirty seconds of viewport over ten seconds of data: there is nothing
        // to pan to, and the right edge stays on the live edge.
        let narrow = LivelineViewportLimits.resolve(window: 30, domain: 0...10, sampleCount: 11)
        let panned = LivelineViewport.following(window: 30).panned(by: -500, limits: narrow)

        XCTAssertTrue(panned.isFollowingLive)
        XCTAssertEqual(panned.range(liveEdge: 10).upperBound, 10, accuracy: 0.0001)
    }

    func testPanIgnoresNonFiniteDeltas() {
        let viewport = LivelineViewport(span: 30, frozenEnd: 60)
        XCTAssertEqual(viewport.panned(by: .nan, limits: limits), viewport)
    }

    // MARK: - Follow-live engagement

    func testPanningAwayFromTheLiveEdgeFreezesTheViewportInAbsoluteTime() {
        // The snap threshold is two percent of the span: 0.6s here.
        let frozen = LivelineViewport.following(window: 30).panned(by: -1, limits: limits)
        XCTAssertFalse(frozen.isFollowingLive)
        XCTAssertEqual(frozen.frozenEnd ?? 0, 99, accuracy: 0.0001)

        // Newer data arriving moves the live edge, not the frozen viewport.
        let laterLimits = LivelineViewportLimits.resolve(window: 30, domain: 0...140, sampleCount: 141)
        XCTAssertEqual(frozen.range(liveEdge: laterLimits.domain.upperBound).upperBound, 99, accuracy: 0.0001)
    }

    func testStoppingInsideTheSnapThresholdStaysLive() {
        let nudged = LivelineViewport.following(window: 30).panned(by: -0.5, limits: limits)
        XCTAssertTrue(nudged.isFollowingLive)
    }

    func testPanningBackToWithinTheSnapThresholdReengagesFollowing() {
        let frozen = LivelineViewport(span: 30, frozenEnd: 90)
        XCTAssertFalse(frozen.panned(by: 9, limits: limits).isFollowingLive, "one second short still reads as frozen")
        XCTAssertTrue(frozen.panned(by: 9.5, limits: limits).isFollowingLive)
    }

    func testFollowingLiveKeepsTheZoomItReengagesAt() {
        let resumed = LivelineViewport(span: 12, frozenEnd: 40).followingLive(limits: limits)
        XCTAssertTrue(resumed.isFollowingLive)
        XCTAssertEqual(resumed.span, 12, accuracy: 0.0001)
        XCTAssertEqual(resumed.range(liveEdge: 100).lowerBound, 88, accuracy: 0.0001)
    }

    // MARK: - Drag to time

    func testDragTranslatesIntoSecondsProportionalToThePlot() {
        // Half the plot width is half the visible span.
        let delta = LivelineViewport.panTimeDelta(translation: -100, plotWidth: 200, span: 30, isRTL: false)
        XCTAssertEqual(delta, 15, accuracy: 0.0001)
    }

    func testDragTowardTheLiveEdgeShowsNewerDataInBothReadingDirections() {
        // Left-to-right: the live edge is on the right, so dragging leftwards
        // pulls newer data into view.
        let ltr = LivelineViewport.panTimeDelta(translation: -60, plotWidth: 300, span: 30, isRTL: false)
        XCTAssertGreaterThan(ltr, 0)

        // Right-to-left: the live edge is on the left, so the same intent is the
        // opposite physical direction and the sign flips with it.
        let rtl = LivelineViewport.panTimeDelta(translation: 60, plotWidth: 300, span: 30, isRTL: true)
        XCTAssertGreaterThan(rtl, 0)
        XCTAssertEqual(ltr, rtl, accuracy: 0.0001)

        // And the mirrored drag moves the mirrored way.
        XCTAssertEqual(
            LivelineViewport.panTimeDelta(translation: 60, plotWidth: 300, span: 30, isRTL: false),
            -ltr,
            accuracy: 0.0001
        )
    }

    func testDragIgnoresDegenerateGeometry() {
        XCTAssertEqual(LivelineViewport.panTimeDelta(translation: 10, plotWidth: 0, span: 30, isRTL: false), 0)
        XCTAssertEqual(LivelineViewport.panTimeDelta(translation: .nan, plotWidth: 300, span: 30, isRTL: false), 0)
    }

    // MARK: - Scroll wheel

    func testScrollPanClaimsTheDominantAxisAndShiftedWheels() {
        XCTAssertEqual(LivelineScrollPanPolicy.horizontalDelta(deltaX: -9, deltaY: 2, isShiftPressed: false), -9)
        // A mostly vertical swipe belongs to whatever the chart is embedded in.
        XCTAssertEqual(LivelineScrollPanPolicy.horizontalDelta(deltaX: 1, deltaY: 8, isShiftPressed: false), 0)
        // A wheel mouse only reports the vertical axis; Shift redirects it.
        XCTAssertEqual(LivelineScrollPanPolicy.horizontalDelta(deltaX: 0, deltaY: 8, isShiftPressed: true), 8)
        XCTAssertEqual(LivelineScrollPanPolicy.horizontalDelta(deltaX: .nan, deltaY: 8, isShiftPressed: true), 0)
    }

    // MARK: - Configuration

    func testZoomAndPanIsOffByDefaultAndLimitsAreSanitized() {
        var configuration = LivelineChartConfiguration(style: .standard)
        XCTAssertFalse(configuration.zoomAndPan)
        XCTAssertNil(configuration.minimumSpan)
        XCTAssertEqual(configuration.maximumZoomOut, LivelineViewportLimits.defaultMaximumZoomOut)

        configuration.minimumSpan = -3
        configuration.maximumZoomOut = 0.2
        let normalized = configuration.normalizedForRendering()
        XCTAssertNil(normalized.minimumSpan)
        XCTAssertEqual(normalized.maximumZoomOut, LivelineViewportLimits.defaultMaximumZoomOut)
    }

    // MARK: - Renderer hand-off

    private func renderInput(
        zoomAndPan: Bool,
        settlesImmediately: Bool,
        frozenRightEdge: TimeInterval?,
        timestamp: TimeInterval
    ) -> LivelineRenderInput {
        let points = (0..<20).map { LivelinePoint(time: Double($0), value: Double($0 % 5)) }
        let content = LivelineChartContent.line(data: points, value: 4)
        var configuration = LivelineChartConfiguration(style: .standard)
        configuration.zoomAndPan = zoomAndPan
        return LivelineRenderInput(
            content: content,
            semantics: content.semantics(),
            accent: .blue,
            configuration: configuration,
            motion: LivelineMotionPolicy(
                isPaused: false,
                requiresTimeline: !settlesImmediately,
                settlesImmediately: settlesImmediately
            ),
            activeWindow: 30,
            frozenRightEdge: frozenRightEdge,
            hiddenSeries: [],
            hoverLocation: nil,
            timestamp: timestamp,
            size: CGSize(width: 320, height: 200)
        )
    }

    func testASettledFrameDrawsTheFrozenEdgeExactly() {
        // Image exports and snapshot tests draw a single frame: they must land
        // on the viewport's edge rather than partway through a glide.
        let state = LivelineRenderState()
        state.displayRightEdge = 40
        let edge = LivelineRenderer.resolvedRightEdge(
            target: 90,
            state: state,
            input: renderInput(
                zoomAndPan: true,
                settlesImmediately: true,
                frozenRightEdge: 90,
                timestamp: 0
            )
        )
        XCTAssertEqual(edge, 90, accuracy: 0.0001)
    }

    func testReturningToLiveEasesTheRightEdgeRatherThanCutting() {
        let state = LivelineRenderState()
        state.displayRightEdge = 80
        state.lastTimestamp = 0
        let edge = LivelineRenderer.resolvedRightEdge(
            target: 90,
            state: state,
            input: renderInput(
                zoomAndPan: true,
                settlesImmediately: false,
                frozenRightEdge: nil,
                timestamp: 1.0 / 60.0
            )
        )
        XCTAssertGreaterThan(edge, 80)
        XCTAssertLessThan(edge, 90)
        XCTAssertEqual(state.displayRightEdge ?? 0, edge, accuracy: 0.0001)
    }

    func testChartsWithoutZoomAndPanNeverGlideTheirRightEdge() {
        // The default path has to be untouched: no easing, no lag behind live.
        let state = LivelineRenderState()
        state.displayRightEdge = 80
        state.lastTimestamp = 0
        let edge = LivelineRenderer.resolvedRightEdge(
            target: 90,
            state: state,
            input: renderInput(
                zoomAndPan: false,
                settlesImmediately: false,
                frozenRightEdge: nil,
                timestamp: 1.0 / 60.0
            )
        )
        XCTAssertEqual(edge, 90, accuracy: 0.0001)
    }

    func testALargeJumpCutsInsteadOfGliding() {
        let state = LivelineRenderState()
        state.displayRightEdge = 0
        state.lastTimestamp = 0
        let edge = LivelineRenderer.resolvedRightEdge(
            target: 10_000,
            state: state,
            input: renderInput(
                zoomAndPan: true,
                settlesImmediately: false,
                frozenRightEdge: nil,
                timestamp: 1.0 / 60.0
            )
        )
        XCTAssertEqual(edge, 10_000, accuracy: 0.0001)
    }

    func testTimeDomainTravelsWithTheChartSemantics() {
        let points = (0..<50).map { LivelinePoint(time: Double($0), value: Double($0 % 7)) }
        let semantics = LivelineChartContent.line(data: points, value: 3).semantics()

        XCTAssertEqual(semantics.earliestTime, 0)
        XCTAssertEqual(semantics.latestTime, 49)
        XCTAssertEqual(semantics.sampleCount, 50)
    }
}
