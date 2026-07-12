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

        let ditherPolicy = LivelineMotionPolicy.resolve(
            configuration: LivelineChartConfiguration(style: .dither()),
            capabilities: staticCapabilities,
            reduceMotion: false
        )
        XCTAssertTrue(ditherPolicy.requiresTimeline)

        let staticDitherPolicy = LivelineMotionPolicy.resolve(
            configuration: LivelineChartConfiguration(
                style: .dither(LivelineDitherStyle(bloom: .off, sparkleDensity: 0))
            ),
            capabilities: staticCapabilities,
            reduceMotion: false
        )
        XCTAssertFalse(staticDitherPolicy.requiresTimeline)
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

    func testEveryChartKindBuildsResolvableTooltipTargets() {
        let points = [
            LivelinePoint(time: 1, value: 4),
            LivelinePoint(time: 2, value: 7),
            LivelinePoint(time: 3, value: 5),
        ]
        let categories = [
            LivelineCategoryValue(id: "a", label: "Alpha", value: 6),
            LivelineCategoryValue(id: "b", label: "Beta", value: 4),
        ]
        let contents: [(LivelineChartKind, LivelineChartContent)] = [
            (.line, .line(data: points, value: 5)),
            (.bars, .bars(data: points, style: LivelineBarStyle())),
            (.range, .range(data: [LivelineRangePoint(time: 1, lower: 2, upper: 6)], style: LivelineRangeStyle())),
            (.scatter, .scatter(data: points, value: 5, style: LivelineScatterStyle())),
            (.steps, .steps(data: points, value: 5, style: LivelineStepStyle())),
            (.lollipops, .lollipops(data: points, style: LivelineLollipopStyle())),
            (.bubbles, .bubbles(data: [LivelineBubblePoint(time: 1, value: 4, magnitude: 8)], style: LivelineBubbleStyle())),
            (.boxPlots, .boxPlots(data: [LivelineBoxPlotPoint(time: 1, minimum: 1, lowerQuartile: 2, median: 4, upperQuartile: 6, maximum: 8)], style: LivelineBoxPlotStyle())),
            (.waterfall, .waterfall(data: points, style: LivelineWaterfallStyle())),
            (.errorBars, .errorBars(data: [LivelineErrorBarPoint(time: 1, value: 4, lower: 2, upper: 6)], style: LivelineErrorBarStyle())),
            (.dumbbells, .dumbbells(data: [LivelineDumbbellPoint(time: 1, start: 2, end: 6)], style: LivelineDumbbellStyle())),
            (.stackedBars, .stackedBars(data: [LivelineStackedPoint(time: 1, values: [2, 3])], style: LivelineStackedBarStyle())),
            (.stackedAreas, .stackedAreas(data: [LivelineStackedPoint(time: 1, values: [2, 3])], style: LivelineStackedAreaStyle())),
            (.timeline, .timeline(data: [LivelineTimelineItem(id: "one", label: "Deploy", start: 1, end: 3, lane: 0)], style: LivelineTimelineStyle())),
            (.heatmap, .heatmap(data: [LivelineHeatmapCell(time: 1, row: 0, value: 0.8)], style: LivelineHeatmapStyle(rowLabels: ["API"]))),
            (.radar, .radar(data: [LivelineRadarPoint(label: "A", value: 0.3), LivelineRadarPoint(label: "B", value: 0.8), LivelineRadarPoint(label: "C", value: 0.5)], style: LivelineRadarStyle())),
            (.donut, .donut(data: categories, style: LivelineDonutStyle())),
            (.gauge, .gauge(value: 0.65, range: 0...1, style: LivelineGaugeStyle())),
            (.funnel, .funnel(data: categories, style: LivelineFunnelStyle())),
            (.candle, .candle(data: points, value: 5, candles: [LivelineCandle(time: 1, open: 3, high: 6, low: 2, close: 5)], candleWidth: 1, liveCandle: nil, lineData: points, lineValue: 5)),
            (.series, .series([LivelineSeries(id: "a", data: points, value: 5, color: .blue, label: "Alpha")])),
        ]
        XCTAssertEqual(contents.count, LivelineChartKind.allCases.count)

        let configuration = LivelineChartConfiguration(window: 10, scrub: true, paused: true)
        let layout = LivelineLayout(
            size: CGSize(width: 320, height: 220),
            padding: LivelineResolvedPadding(top: 20, right: 20, bottom: 20, left: 20),
            minValue: 0,
            maxValue: 10,
            leftEdge: 0,
            rightEdge: 10
        )
        let palette = LivelinePalette.resolve(accent: .blue, mode: .dark, lineWidth: 2)

        for (kind, content) in contents {
            let prepared = LivelineChartPreparer.prepare(
                for: content,
                hiddenSeries: [],
                leftEdge: layout.leftEdge,
                rightEdge: layout.rightEdge,
                config: configuration
            )
            let snapshot = LivelineInteractionBuilder.snapshot(
                content: content,
                prepared: prepared,
                layout: layout,
                palette: palette,
                configuration: configuration,
                hiddenSeries: [],
                behavior: content.semantics().capabilities.hoverBehavior
            )
            let firstTarget = snapshot.targets.first
            XCTAssertNotNil(firstTarget, "\(kind) did not create a tooltip target")
            guard let firstTarget else { continue }
            if kind == .candle {
                XCTAssertEqual(firstTarget.selection.hover.time, 1.5)
                XCTAssertEqual(firstTarget.selection.hover.x, layout.x(for: 1.5), accuracy: 0.0001)
            }
            let selection = LivelineHoverResolver.resolveSelection(
                location: firstTarget.selection.anchor,
                snapshot: snapshot
            )
            XCTAssertFalse(selection?.rows.isEmpty ?? true, "\(kind) did not resolve tooltip rows")
        }
    }

    func testTallTooltipMovesBesideHighCandleAnchor() {
        let layout = LivelineLayout(
            size: CGSize(width: 320, height: 220),
            padding: LivelineResolvedPadding(top: 20, right: 20, bottom: 20, left: 20),
            minValue: 0,
            maxValue: 10,
            leftEdge: 0,
            rightEdge: 10
        )
        let anchor = CGPoint(x: 120, y: 38)
        let rect = LivelineRenderer.tooltipRect(
            anchor: anchor,
            size: CGSize(width: 140, height: 90),
            layout: layout
        )

        XCTAssertGreaterThan(rect.minX, anchor.x)
        XCTAssertFalse(rect.contains(anchor))
        XCTAssertGreaterThanOrEqual(rect.minY, layout.padding.top + 4)
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
