import XCTest
@testable import Liveline

final class LivelineRuntimeTests: XCTestCase {
    func testWindowSelectionTracksExternalValuesAndOptionChanges() {
        XCTAssertEqual(
            LivelineSelectionReconciler.window(
                current: 30,
                preferred: 60,
                options: [15, 30, 60],
                preferExternalValue: true
            ),
            60
        )
        XCTAssertEqual(
            LivelineSelectionReconciler.window(
                current: 30,
                preferred: 60,
                options: [15, 30],
                preferExternalValue: false
            ),
            30
        )
        XCTAssertEqual(
            LivelineSelectionReconciler.window(
                current: 30,
                preferred: 60,
                options: [15],
                preferExternalValue: false
            ),
            15
        )
    }

    func testSeriesSelectionDropsMissingIDsAndKeepsOneSeriesVisible() {
        XCTAssertEqual(
            LivelineSelectionReconciler.hiddenSeries(
                current: ["removed", "a"],
                availableIDs: ["a", "b"]
            ),
            ["a"]
        )
        XCTAssertEqual(
            LivelineSelectionReconciler.hiddenSeries(
                current: ["a", "b"],
                availableIDs: ["a", "b"]
            ),
            ["b"]
        )

        let hidden = LivelineSelectionReconciler.toggledSeries(
            "a",
            hidden: [],
            availableIDs: ["a", "b"]
        )
        XCTAssertEqual(hidden?.hidden, ["a"])
        XCTAssertEqual(hidden?.isVisible, false)
        XCTAssertNil(
            LivelineSelectionReconciler.toggledSeries(
                "b",
                hidden: ["a"],
                availableIDs: ["a", "b"]
            )
        )
    }

    func testMotionPolicyOnlySchedulesFramesWhenAVisibleEffectNeedsThem() {
        let staticCapabilities = capabilities(isRealtime: false)
        let realtimeCapabilities = capabilities(isRealtime: true)

        let staticPolicy = LivelineMotionPolicy.resolve(
            configuration: LivelineChartConfiguration(fadeEffects: false),
            capabilities: staticCapabilities,
            reduceMotion: false
        )
        XCTAssertFalse(staticPolicy.requiresTimeline)
        XCTAssertTrue(staticPolicy.settlesImmediately)

        let realtimePolicy = LivelineMotionPolicy.resolve(
            configuration: LivelineChartConfiguration(),
            capabilities: realtimeCapabilities,
            reduceMotion: false
        )
        XCTAssertTrue(realtimePolicy.requiresTimeline)
        XCTAssertFalse(realtimePolicy.settlesImmediately)

        let pausedPolicy = LivelineMotionPolicy.resolve(
            configuration: LivelineChartConfiguration(paused: true),
            capabilities: realtimeCapabilities,
            reduceMotion: false
        )
        XCTAssertFalse(pausedPolicy.requiresTimeline)
        XCTAssertTrue(pausedPolicy.isPaused)
        XCTAssertFalse(pausedPolicy.settlesImmediately)

        let reducedPolicy = LivelineMotionPolicy.resolve(
            configuration: LivelineChartConfiguration(),
            capabilities: realtimeCapabilities,
            reduceMotion: true
        )
        XCTAssertFalse(reducedPolicy.requiresTimeline)
        XCTAssertTrue(reducedPolicy.settlesImmediately)
    }

    func testTypedConfigurationOwnsPoliciesAndCallbacksDoNotControlVisibility() {
        var configuration = LivelineChartConfiguration(
            appearance: LivelineChartAppearance(theme: .light, grid: false),
            interaction: LivelineChartInteraction(
                scrub: false,
                showsModeControls: true,
                showsSeriesControls: false
            ),
            motion: LivelineChartMotion(paused: true, lerpSpeed: 0.4)
        )

        XCTAssertEqual(configuration.theme, .light)
        XCTAssertFalse(configuration.grid)
        XCTAssertFalse(configuration.scrub)
        XCTAssertTrue(configuration.showsModeControls)
        XCTAssertFalse(configuration.showsSeriesControls)
        XCTAssertTrue(configuration.paused)
        XCTAssertEqual(configuration.lerpSpeed, 0.4)

        configuration.onModeChange = { _ in }
        XCTAssertTrue(configuration.showsModeControls)
        configuration.onModeChange = nil
        XCTAssertTrue(configuration.showsModeControls)

        configuration.lineWidth = 5
        XCTAssertEqual(configuration.appearance.lineWidth, 5)
        configuration.motion.lerpSpeed = 0.25
        XCTAssertEqual(configuration.lerpSpeed, 0.25)
    }

    func testLegacyConfigurationInfersModeControlVisibilityOnlyAtInitialization() {
        var configuration = LivelineChartConfiguration(onModeChange: { _ in })
        XCTAssertTrue(configuration.showsModeControls)

        configuration.onModeChange = nil
        XCTAssertTrue(configuration.showsModeControls)

        let withoutCallback = LivelineChartConfiguration()
        XCTAssertFalse(withoutCallback.showsModeControls)
    }

    func testHoverResolverInterpolatesAndUsesBinaryNearestPointSelection() {
        let layout = LivelineLayout(
            size: CGSize(width: 120, height: 100),
            padding: LivelineResolvedPadding(top: 10, right: 10, bottom: 10, left: 10),
            minValue: 0,
            maxValue: 10,
            leftEdge: 0,
            rightEdge: 10
        )
        let points = [
            LivelinePoint(time: 0, value: 0),
            LivelinePoint(time: 5, value: 10),
            LivelinePoint(time: 10, value: 0),
        ]

        let interpolated = LivelineHoverResolver.resolve(
            location: CGPoint(x: 35, y: 50),
            snapshot: LivelineInteractionSnapshot(
                layout: layout,
                points: points,
                behavior: .interpolated,
                isEnabled: true
            )
        )
        XCTAssertEqual(interpolated?.time ?? -1, 2.5, accuracy: 0.0001)
        XCTAssertEqual(interpolated?.value ?? -1, 5, accuracy: 0.0001)

        let discrete = LivelineHoverResolver.resolve(
            location: CGPoint(x: 56, y: 50),
            snapshot: LivelineInteractionSnapshot(
                layout: layout,
                points: points,
                behavior: .discrete,
                isEnabled: true
            )
        )
        XCTAssertEqual(discrete?.time, 5)
        XCTAssertNil(
            LivelineHoverResolver.resolve(
                location: CGPoint(x: 0, y: 50),
                snapshot: LivelineInteractionSnapshot(
                    layout: layout,
                    points: points,
                    behavior: .interpolated,
                    isEnabled: true
                )
            )
        )
    }

    func testAnimationClockAndInterpolationFreezeWhilePaused() {
        let state = LivelineRenderState()
        let first = state.frame(for: 100, isPaused: false)
        let paused = state.frame(for: 100.1, isPaused: true)
        let resumed = state.frame(for: 100.2, isPaused: false)

        XCTAssertEqual(first.deltaMilliseconds, 16.667, accuracy: 0.001)
        XCTAssertEqual(paused.deltaMilliseconds, 0)
        XCTAssertEqual(paused.elapsed, first.elapsed, accuracy: 0.0001)
        XCTAssertEqual(resumed.deltaMilliseconds, 50)
        XCTAssertEqual(LivelineMath.lerp(4, 10, speed: 1, deltaTime: 0), 4)

        XCTAssertEqual(state.presentationTimestamp(for: 200, isPaused: true), 200)
        XCTAssertEqual(state.presentationTimestamp(for: 205, isPaused: true), 200)
        XCTAssertEqual(state.presentationTimestamp(for: 206, isPaused: false), 206)
    }

    func testSeededEffectsUseTheRenderStatesDeterministicRandomStream() {
        let first = LivelineRenderState()
        let second = LivelineRenderState()
        let palette = LivelinePalette.resolve(accent: .orange, mode: .dark, lineWidth: 2)

        LivelineRenderer.updateParticles(
            state: first,
            origin: CGPoint(x: 10, y: 20),
            palette: palette,
            momentum: .up,
            swingMagnitude: 0.3,
            options: LivelineDegenOptions(scale: 1),
            randomSeed: 42,
            deltaTime: 16
        )
        LivelineRenderer.updateParticles(
            state: second,
            origin: CGPoint(x: 10, y: 20),
            palette: palette,
            momentum: .up,
            swingMagnitude: 0.3,
            options: LivelineDegenOptions(scale: 1),
            randomSeed: 42,
            deltaTime: 16
        )

        XCTAssertEqual(first.particles.count, second.particles.count)
        for (lhs, rhs) in zip(first.particles, second.particles) {
            XCTAssertEqual(lhs.position, rhs.position)
            XCTAssertEqual(lhs.velocity.dx, rhs.velocity.dx, accuracy: 0.0001)
            XCTAssertEqual(lhs.velocity.dy, rhs.velocity.dy, accuracy: 0.0001)
            XCTAssertEqual(lhs.radius, rhs.radius, accuracy: 0.0001)
        }
    }

    func testRenderStateResetsWhenChartIdentityChanges() {
        let state = LivelineRenderState()
        let line = LivelineChartIdentity(kind: .line)
        state.reconcile(identity: line, anchorValue: 10, window: 30)
        state.smoothValue = 12
        state.chartReveal = 1
        state.seriesAlpha["old"] = 0.5

        state.reconcile(identity: line, anchorValue: 20, window: 60)
        XCTAssertEqual(state.smoothValue, 12)
        XCTAssertEqual(state.chartReveal, 1)

        state.reconcile(identity: LivelineChartIdentity(kind: .bars), anchorValue: 20, window: 60)
        XCTAssertEqual(state.smoothValue, 20)
        XCTAssertEqual(state.displayWindow, 60)
        XCTAssertEqual(state.chartReveal, 0)
        XCTAssertTrue(state.seriesAlpha.isEmpty)
    }

    private func capabilities(isRealtime: Bool) -> LivelineChartCapabilities {
        LivelineChartCapabilities(
            usesValueAxis: true,
            usesCartesianGrid: true,
            usesTimeAxis: true,
            hoverBehavior: .interpolated,
            isRealtime: isRealtime
        )
    }
}
