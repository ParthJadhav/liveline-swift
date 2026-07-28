import XCTest
@testable import Liveline

final class LivelineRuntimeTests: XCTestCase {
    func testScrubPanAcceptsHorizontalVelocityInEitherDirection() {
        XCTAssertTrue(
            LivelineScrubPanPolicy.shouldBegin(
                velocity: CGPoint(x: 100, y: 99)
            )
        )
        XCTAssertTrue(
            LivelineScrubPanPolicy.shouldBegin(
                velocity: CGPoint(x: -80, y: 20)
            )
        )
    }

    func testScrubPanRejectsVerticalVelocityInEitherDirection() {
        XCTAssertFalse(
            LivelineScrubPanPolicy.shouldBegin(
                velocity: CGPoint(x: 99, y: 100)
            )
        )
        XCTAssertFalse(
            LivelineScrubPanPolicy.shouldBegin(
                velocity: CGPoint(x: 20, y: -80)
            )
        )
    }

    func testScrubPanGivesExactTiesAndStationaryInputToScrolling() {
        XCTAssertFalse(
            LivelineScrubPanPolicy.shouldBegin(
                velocity: CGPoint(x: 100, y: 100)
            )
        )
        XCTAssertFalse(
            LivelineScrubPanPolicy.shouldBegin(
                velocity: CGPoint(x: -100, y: 100)
            )
        )
        XCTAssertFalse(
            LivelineScrubPanPolicy.shouldBegin(
                velocity: .zero
            )
        )
    }

    func testScrubPanRejectsNonFiniteVelocity() {
        XCTAssertFalse(
            LivelineScrubPanPolicy.shouldBegin(
                velocity: CGPoint(x: CGFloat.infinity, y: 0)
            )
        )
        XCTAssertFalse(
            LivelineScrubPanPolicy.shouldBegin(
                velocity: CGPoint(x: 0, y: CGFloat.nan)
            )
        )
    }

    func testScrubSessionLocksUntilTheGestureFinishes() {
        var session = LivelineScrubSession()

        XCTAssertFalse(session.shouldUpdate)
        XCTAssertTrue(session.begin())
        XCTAssertTrue(session.shouldUpdate)
        XCTAssertFalse(session.begin())

        // Direction changes do not re-run recognition once horizontal input
        // owns this touch sequence.
        XCTAssertTrue(session.shouldUpdate)
        XCTAssertTrue(session.finish())
        XCTAssertFalse(session.shouldUpdate)
    }

    func testScrubSessionClearsOnlyOnceForRepeatedEndOrCancel() {
        var session = LivelineScrubSession()

        XCTAssertFalse(session.finish())
        XCTAssertTrue(session.begin())
        XCTAssertTrue(session.finish())
        XCTAssertFalse(session.finish())
    }

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
        XCTAssertFalse(
            LivelineSelectionReconciler.canToggleSeries(
                "b",
                hidden: ["a"],
                availableIDs: ["a", "b"]
            )
        )
        XCTAssertTrue(
            LivelineSelectionReconciler.canToggleSeries(
                "a",
                hidden: ["a"],
                availableIDs: ["a", "b"]
            )
        )
    }

    func testPointerAndScrubSessionsEndIndependently() {
        var sessions = LivelineInteractionSessions()
        let pointer = CGPoint(x: 20, y: 30)
        let scrub = CGPoint(x: 80, y: 40)

        sessions.update(pointer, source: .pointer)
        sessions.update(scrub, source: .scrub)
        XCTAssertEqual(sessions.activeSource, .scrub)
        XCTAssertEqual(sessions.activeLocation, scrub)

        XCTAssertEqual(sessions.end(.scrub), pointer)
        XCTAssertEqual(sessions.activeSource, .pointer)
        XCTAssertEqual(sessions.activeLocation, pointer)

        // Ending an already-inactive modality leaves the active owner intact.
        XCTAssertEqual(sessions.end(.scrub), pointer)
        XCTAssertEqual(sessions.end(.pointer), nil)
        XCTAssertNil(sessions.activeSource)

        sessions.update(scrub, source: .scrub)
        sessions.update(pointer, source: .pointer)
        XCTAssertEqual(sessions.end(.pointer), scrub)
        XCTAssertEqual(sessions.activeSource, .scrub)
        XCTAssertEqual(sessions.activeLocation, scrub)
        XCTAssertEqual(sessions.end(.pointer), scrub)
        XCTAssertNil(sessions.end(.scrub))
    }

    func testTVRemoteSelectionPolicyClampsAndHandlesEmptyData() {
        XCTAssertNil(
            LivelineRemoteSelectionPolicy.nextIndex(
                current: nil,
                targetCount: 0,
                step: .forward
            )
        )
        XCTAssertEqual(
            LivelineRemoteSelectionPolicy.nextIndex(
                current: nil,
                targetCount: 4,
                step: .forward
            ),
            3
        )
        XCTAssertEqual(
            LivelineRemoteSelectionPolicy.nextIndex(
                current: 3,
                targetCount: 4,
                step: .backward
            ),
            2
        )
        XCTAssertEqual(
            LivelineRemoteSelectionPolicy.nextIndex(
                current: 0,
                targetCount: 4,
                step: .backward
            ),
            0
        )
        XCTAssertEqual(
            LivelineRemoteSelectionPolicy.nextIndex(
                current: 99,
                targetCount: 4,
                step: .forward
            ),
            3
        )
    }

    func testChartControlHitDimensionMeetsAccessibilityMinimum() {
        XCTAssertGreaterThanOrEqual(LivelineControlMetrics.minimumHitDimension, 44)
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
        XCTAssertEqual(ditherPolicy.minimumInterval, 1.0 / 30.0, accuracy: 0.0001)
        XCTAssertEqual(realtimePolicy.minimumInterval, 1.0 / 60.0, accuracy: 0.0001)

        let realtimeDitherPolicy = LivelineMotionPolicy.resolve(
            configuration: LivelineChartConfiguration(style: .dither()),
            capabilities: realtimeCapabilities,
            reduceMotion: false
        )
        XCTAssertEqual(realtimeDitherPolicy.minimumInterval, 1.0 / 30.0, accuracy: 0.0001)

        let highFrameRateDitherPolicy = LivelineMotionPolicy.resolve(
            configuration: LivelineChartConfiguration(
                style: .dither(LivelineDitherStyle(maximumFramesPerSecond: 45))
            ),
            capabilities: staticCapabilities,
            reduceMotion: false
        )
        XCTAssertEqual(highFrameRateDitherPolicy.minimumInterval, 1.0 / 45.0, accuracy: 0.0001)

        let staticDitherPolicy = LivelineMotionPolicy.resolve(
            configuration: LivelineChartConfiguration(
                style: .dither(LivelineDitherStyle(bloom: .off, sparkleDensity: 0))
            ),
            capabilities: staticCapabilities,
            reduceMotion: false
        )
        XCTAssertFalse(staticDitherPolicy.requiresTimeline)
    }

    func testDitherFrameRateIsNormalizedAtRenderingBoundary() {
        func resolvedRate(_ rate: Double) -> Double {
            let configuration = LivelineChartConfiguration(
                style: .dither(LivelineDitherStyle(maximumFramesPerSecond: rate))
            ).normalizedForRendering()
            guard case let .dither(style) = configuration.style else { return 0 }
            return style.maximumFramesPerSecond
        }

        XCTAssertEqual(resolvedRate(.nan), 30)
        XCTAssertEqual(resolvedRate(0), 1)
        XCTAssertEqual(resolvedRate(240), 120)
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

    func testHoverTooltipIsOptInAndSurvivesEveryConfigurationEntryPoint() {
        XCTAssertFalse(LivelineChartConfiguration().showsTooltipOnHover)
        XCTAssertFalse(LivelineChartConfiguration(style: .standard).showsTooltipOnHover)
        XCTAssertFalse(LivelineChartInteraction().showsTooltipOnHover)
        XCTAssertFalse(LivelineChartConfiguration(scrub: false).showsTooltipOnHover)

        var configuration = LivelineChartConfiguration(
            appearance: LivelineChartAppearance(),
            interaction: LivelineChartInteraction(scrub: false, showsTooltipOnHover: true)
        )
        XCTAssertTrue(configuration.showsTooltipOnHover)
        XCTAssertTrue(configuration.interaction.showsTooltipOnHover)

        configuration.showsTooltipOnHover = false
        XCTAssertFalse(configuration.interaction.showsTooltipOnHover)
        configuration.interaction.showsTooltipOnHover = true
        XCTAssertTrue(configuration.showsTooltipOnHover)

        // Normalization is a rendering concern; the opt-in must pass through it.
        XCTAssertTrue(configuration.normalizedForRendering().showsTooltipOnHover)
        XCTAssertTrue(configuration.respectingReducedMotion(true).showsTooltipOnHover)
    }

    func testHoverOnlyChartResolvesTooltipsWithoutScrubbing() {
        let points = [
            LivelinePoint(time: 1, value: 4),
            LivelinePoint(time: 2, value: 7),
            LivelinePoint(time: 3, value: 5),
        ]
        let content = LivelineChartContent.line(data: points, value: 5)
        let layout = LivelineLayout(
            size: CGSize(width: 320, height: 220),
            padding: LivelineResolvedPadding(top: 20, right: 20, bottom: 20, left: 20),
            minValue: 0,
            maxValue: 10,
            leftEdge: 0,
            rightEdge: 10
        )
        let palette = LivelinePalette.resolve(accent: .blue, mode: .dark, lineWidth: 2)

        func snapshot(scrub: Bool, hover: Bool) -> LivelineInteractionSnapshot {
            let configuration = LivelineChartConfiguration(
                appearance: LivelineChartAppearance(),
                interaction: LivelineChartInteraction(scrub: scrub, showsTooltipOnHover: hover)
            )
            let prepared = LivelineChartPreparer.prepare(
                for: content,
                hiddenSeries: [],
                leftEdge: layout.leftEdge,
                rightEdge: layout.rightEdge,
                config: configuration
            )
            return LivelineInteractionBuilder.snapshot(
                content: content,
                prepared: prepared,
                layout: layout,
                palette: palette,
                configuration: configuration,
                hiddenSeries: [],
                behavior: content.semantics().capabilities.hoverBehavior
            )
        }

        let probe = CGPoint(x: layout.x(for: 2), y: layout.y(for: 7))

        // Hover alone is enough; the two input paths gate the tooltip together.
        let hoverOnly = snapshot(scrub: false, hover: true)
        XCTAssertTrue(hoverOnly.isEnabled)
        XCTAssertEqual(LivelineHoverResolver.resolve(location: probe, snapshot: hoverOnly)?.time, 2)
        XCTAssertFalse(LivelineHoverResolver.resolveSelection(location: probe, snapshot: hoverOnly)?.rows.isEmpty ?? true)

        XCTAssertTrue(snapshot(scrub: true, hover: false).isEnabled)
        XCTAssertTrue(snapshot(scrub: true, hover: true).isEnabled)

        let inert = snapshot(scrub: false, hover: false)
        XCTAssertFalse(inert.isEnabled)
        XCTAssertNil(LivelineHoverResolver.resolve(location: probe, snapshot: inert))
        XCTAssertNil(LivelineHoverResolver.resolveSelection(location: probe, snapshot: inert))
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

    func testTooltipVerticalOffsetRemainsConfigurable() {
        let layout = LivelineLayout(
            size: CGSize(width: 320, height: 220),
            padding: LivelineResolvedPadding(top: 20, right: 20, bottom: 20, left: 20),
            minValue: 0,
            maxValue: 10,
            leftEdge: 0,
            rightEdge: 10
        )
        let anchor = CGPoint(x: 160, y: 150)
        let base = LivelineRenderer.tooltipRect(
            anchor: anchor,
            size: CGSize(width: 120, height: 40),
            layout: layout
        )
        let shifted = LivelineRenderer.tooltipRect(
            anchor: anchor,
            size: CGSize(width: 120, height: 40),
            layout: layout,
            verticalOffset: 18
        )

        XCTAssertEqual(shifted.minY, base.minY + 18, accuracy: 0.0001)
    }

    func testCandleLineModeTooltipTracksDenseLineInsteadOfCandleHigh() {
        let linePoints = [
            LivelinePoint(time: 1.25, value: 4.25),
            LivelinePoint(time: 1.75, value: 4.75),
        ]
        let content = LivelineChartContent.candle(
            data: linePoints,
            value: 4.75,
            candles: [LivelineCandle(time: 1, open: 3, high: 9, low: 2, close: 5)],
            candleWidth: 1,
            liveCandle: nil,
            lineData: linePoints,
            lineValue: 4.75
        )
        let configuration = LivelineChartConfiguration(window: 10, scrub: true, paused: true, lineMode: true)
        let layout = LivelineLayout(
            size: CGSize(width: 320, height: 220),
            padding: LivelineResolvedPadding(top: 20, right: 20, bottom: 20, left: 20),
            minValue: 0,
            maxValue: 10,
            leftEdge: 0,
            rightEdge: 10
        )
        let palette = LivelinePalette.resolve(accent: .orange, mode: .dark, lineWidth: 2)
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

        XCTAssertEqual(snapshot.targets.count, linePoints.count)
        XCTAssertEqual(snapshot.targets[0].selection.hover.time, linePoints[0].time)
        XCTAssertEqual(snapshot.targets[0].selection.hover.value, linePoints[0].value)
        XCTAssertEqual(snapshot.targets[0].selection.anchor.x, layout.x(for: linePoints[0].time), accuracy: 0.0001)
        XCTAssertEqual(snapshot.targets[0].selection.anchor.y, layout.y(for: linePoints[0].value), accuracy: 0.0001)
        XCTAssertEqual(snapshot.targets[0].selection.rows.map(\.label), ["Value"])
    }

    func testDitherGeometryIsBuiltOnceAcrossAnimationFrames() {
        let state = LivelineRenderState()
        let layout = LivelineLayout(
            size: CGSize(width: 320, height: 220),
            padding: LivelineResolvedPadding(top: 20, right: 20, bottom: 20, left: 20),
            minValue: 0,
            maxValue: 10,
            leftEdge: 0,
            rightEdge: 10
        )
        let style = LivelineDitherStyle(cellSize: 2, sparkleDensity: 0.018)

        let first = LivelineRenderer.ditherGeometry(state: state, layout: layout, style: style)
        for _ in 0..<120 {
            _ = LivelineRenderer.ditherGeometry(state: state, layout: layout, style: style)
        }

        XCTAssertEqual(state.ditherGeometryBuildCount, 1)
        XCTAssertGreaterThan(first.cellCount, 10_000)
        XCTAssertLessThan(first.sparkles.count, first.cellCount / 10)

        var changedStyle = style
        changedStyle.cellSize = 3
        _ = LivelineRenderer.ditherGeometry(state: state, layout: layout, style: changedStyle)
        XCTAssertEqual(state.ditherGeometryBuildCount, 2)
    }

    func testIdleInteractionSnapshotSkipsFormattedTargetsButStillResolvesHover() {
        let points = [LivelinePoint(time: 1, value: 3), LivelinePoint(time: 2, value: 5)]
        let content = LivelineChartContent.line(data: points, value: 5)
        let configuration = LivelineChartConfiguration(window: 10, scrub: true, paused: true)
        let layout = LivelineLayout(
            size: CGSize(width: 320, height: 220),
            padding: LivelineResolvedPadding(top: 20, right: 20, bottom: 20, left: 20),
            minValue: 0,
            maxValue: 10,
            leftEdge: 0,
            rightEdge: 10
        )
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
            palette: LivelinePalette.resolve(accent: .blue, mode: .dark, lineWidth: 2),
            configuration: configuration,
            hiddenSeries: [],
            behavior: .interpolated,
            includeTargets: false
        )

        XCTAssertTrue(snapshot.targets.isEmpty)
        XCTAssertNotNil(
            LivelineHoverResolver.resolve(
                location: CGPoint(x: layout.x(for: 1.5), y: layout.y(for: 4)),
                snapshot: snapshot
            )
        )
    }

    func testTargetedDenseSnapshotFormatsOnlyTheNearestPoint() {
        let points = (0..<100).map { LivelinePoint(time: Double($0), value: Double($0)) }
        let content = LivelineChartContent.line(data: points, value: 99)
        let configuration = LivelineChartConfiguration(window: 100, scrub: true, paused: true)
        let layout = LivelineLayout(
            size: CGSize(width: 320, height: 220),
            padding: LivelineResolvedPadding(top: 20, right: 20, bottom: 20, left: 20),
            minValue: 0,
            maxValue: 100,
            leftEdge: 0,
            rightEdge: 100
        )
        let prepared = LivelineChartPreparer.prepare(
            for: content,
            hiddenSeries: [],
            leftEdge: layout.leftEdge,
            rightEdge: layout.rightEdge,
            config: configuration
        )
        let targetLocation = CGPoint(x: layout.x(for: 50.4), y: layout.y(for: 50.4))
        let snapshot = LivelineInteractionBuilder.snapshot(
            content: content,
            prepared: prepared,
            layout: layout,
            palette: LivelinePalette.resolve(accent: .blue, mode: .dark, lineWidth: 2),
            configuration: configuration,
            hiddenSeries: [],
            behavior: .interpolated,
            targetLocation: targetLocation
        )

        XCTAssertEqual(snapshot.targets.count, 1)
        XCTAssertEqual(snapshot.targets[0].selection.hover.time, 50)

        let movedHover = LivelineHoverResolver.resolve(
            location: CGPoint(x: layout.x(for: 72.5), y: layout.y(for: 72.5)),
            snapshot: snapshot
        )
        XCTAssertEqual(movedHover?.time ?? 0, 72.5, accuracy: 0.0001)
        XCTAssertEqual(movedHover?.value ?? 0, 72.5, accuracy: 0.0001)
    }

    func testEveryDirectRegionFamilyResolvesItsFirstEventFromAnIdleSnapshot() throws {
        let categories = [
            LivelineCategoryValue(id: "a", label: "Alpha", value: 6),
            LivelineCategoryValue(id: "b", label: "Beta", value: 4),
        ]
        let contents: [(String, LivelineChartContent)] = [
            (
                "timeline",
                .timeline(
                    data: [LivelineTimelineItem(id: "one", label: "Deploy", start: 1, end: 3, lane: 0)],
                    style: LivelineTimelineStyle()
                )
            ),
            (
                "heatmap",
                .heatmap(
                    data: [LivelineHeatmapCell(time: 1, row: 0, value: 0.8)],
                    style: LivelineHeatmapStyle(rowLabels: ["API"])
                )
            ),
            (
                "radar",
                .radar(
                    data: [
                        LivelineRadarPoint(label: "A", value: 0.3),
                        LivelineRadarPoint(label: "B", value: 0.8),
                        LivelineRadarPoint(label: "C", value: 0.5),
                    ],
                    style: LivelineRadarStyle()
                )
            ),
            ("donut", .donut(data: categories, style: LivelineDonutStyle())),
            ("gauge", .gauge(value: 0.65, range: 0...1, style: LivelineGaugeStyle())),
            ("funnel", .funnel(data: categories, style: LivelineFunnelStyle())),
        ]
        let layout = LivelineLayout(
            size: CGSize(width: 320, height: 220),
            padding: LivelineResolvedPadding(top: 20, right: 20, bottom: 20, left: 20),
            minValue: 0,
            maxValue: 10,
            leftEdge: 0,
            rightEdge: 10
        )
        let configuration = LivelineChartConfiguration(window: 10, scrub: true, paused: true)
        let palette = LivelinePalette.resolve(accent: .blue, mode: .dark, lineWidth: 2)

        for (name, content) in contents {
            let prepared = LivelineChartPreparer.prepare(
                for: content,
                hiddenSeries: [],
                leftEdge: layout.leftEdge,
                rightEdge: layout.rightEdge,
                config: configuration
            )
            let idle = LivelineInteractionBuilder.snapshot(
                content: content,
                prepared: prepared,
                layout: layout,
                palette: palette,
                configuration: configuration,
                hiddenSeries: [],
                behavior: .none,
                includeTargets: false
            )
            XCTAssertTrue(idle.targets.isEmpty, "\(name) idle snapshot was not lightweight")
            XCTAssertNil(
                LivelineHoverResolver.resolve(
                    location: LivelineRenderer.plotCenter(layout),
                    snapshot: idle
                ),
                "\(name) unexpectedly resolved without its targeted fallback"
            )

            let complete = LivelineInteractionBuilder.snapshot(
                content: content,
                prepared: prepared,
                layout: layout,
                palette: palette,
                configuration: configuration,
                hiddenSeries: [],
                behavior: .none
            )
            let location = try XCTUnwrap(complete.targets.first, "\(name) built no target")
                .selection.anchor
            let targeted = LivelineInteractionBuilder.snapshot(
                content: content,
                prepared: prepared,
                layout: layout,
                palette: palette,
                configuration: configuration,
                hiddenSeries: [],
                behavior: .none,
                targetLocation: location
            )
            XCTAssertNotNil(
                LivelineHoverResolver.resolve(location: location, snapshot: targeted),
                "\(name) failed to resolve its first targeted event"
            )
        }
    }

    func testFullTurnSectorContainsEveryPointAroundTheRing() {
        let center = CGPoint(x: 100, y: 100)
        let selection = LivelineTooltipSelection(
            hover: LivelineHoverPoint(time: 0, value: 1, x: 100, y: 40),
            heading: "Only segment",
            rows: [],
            anchor: CGPoint(x: 100, y: 40)
        )
        let snapshot = LivelineInteractionSnapshot(
            layout: LivelineLayout(
                size: CGSize(width: 200, height: 200),
                padding: LivelineResolvedPadding(top: 0, right: 0, bottom: 0, left: 0),
                minValue: 0,
                maxValue: 1,
                leftEdge: 0,
                rightEdge: 1
            ),
            points: [],
            behavior: .none,
            isEnabled: true,
            targets: [
                LivelineInteractionTarget(
                    selection: selection,
                    region: .sector(
                        center: center,
                        innerRadius: 40,
                        outerRadius: 80,
                        startAngle: -.pi / 2,
                        endAngle: -.pi / 2 + 2 * .pi
                    )
                ),
            ]
        )

        for location in [
            CGPoint(x: 100, y: 40),
            CGPoint(x: 160, y: 100),
            CGPoint(x: 100, y: 160),
            CGPoint(x: 40, y: 100),
        ] {
            XCTAssertEqual(
                LivelineHoverResolver.resolve(location: location, snapshot: snapshot)?.value,
                1
            )
        }
        XCTAssertNil(
            LivelineHoverResolver.resolve(
                location: CGPoint(x: 100, y: 90),
                snapshot: snapshot
            )
        )
    }

    func testSingleCategoryDonutBuildsAFullRingTargetEndToEnd() throws {
        let content = LivelineChartContent.donut(
            data: [LivelineCategoryValue(id: "only", label: "Only", value: 10)],
            style: LivelineDonutStyle()
        )
        let configuration = LivelineChartConfiguration(window: 10, scrub: true, paused: true)
        let layout = LivelineLayout(
            size: CGSize(width: 200, height: 200),
            padding: LivelineResolvedPadding(top: 10, right: 10, bottom: 10, left: 10),
            minValue: 0,
            maxValue: 10,
            leftEdge: 0,
            rightEdge: 10
        )
        let prepared = LivelineChartPreparer.prepare(
            for: content,
            hiddenSeries: [],
            leftEdge: 0,
            rightEdge: 10,
            config: configuration
        )
        let snapshot = LivelineInteractionBuilder.snapshot(
            content: content,
            prepared: prepared,
            layout: layout,
            palette: LivelinePalette.resolve(accent: .blue, mode: .dark, lineWidth: 2),
            configuration: configuration,
            hiddenSeries: [],
            behavior: .none
        )
        let target = try XCTUnwrap(snapshot.targets.first)
        guard case let .sector(center, innerRadius, outerRadius, _, _) = target.region else {
            return XCTFail("Single-category donut did not build a sector")
        }
        let radius = (innerRadius + outerRadius) / 2

        for point in [
            CGPoint(x: center.x + radius, y: center.y),
            CGPoint(x: center.x, y: center.y + radius),
            CGPoint(x: center.x - radius, y: center.y),
            CGPoint(x: center.x, y: center.y - radius),
        ] {
            XCTAssertEqual(
                LivelineHoverResolver.resolve(location: point, snapshot: snapshot)?.value,
                10
            )
        }
    }

    func testPartialAndWrappingSectorHitRulesRemainDirectional() {
        let center = CGPoint(x: 100, y: 100)
        let selection = LivelineTooltipSelection(
            hover: LivelineHoverPoint(time: 0, value: 1, x: 100, y: 100),
            heading: "Segment",
            rows: [],
            anchor: center
        )
        func snapshot(start: Double, end: Double) -> LivelineInteractionSnapshot {
            LivelineInteractionSnapshot(
                layout: LivelineLayout(
                    size: CGSize(width: 200, height: 200),
                    padding: LivelineResolvedPadding(top: 0, right: 0, bottom: 0, left: 0),
                    minValue: 0,
                    maxValue: 1,
                    leftEdge: 0,
                    rightEdge: 1
                ),
                points: [],
                behavior: .none,
                isEnabled: true,
                targets: [
                    LivelineInteractionTarget(
                        selection: selection,
                        region: .sector(
                            center: center,
                            innerRadius: 20,
                            outerRadius: 80,
                            startAngle: start,
                            endAngle: end
                        )
                    ),
                ]
            )
        }

        let partial = snapshot(start: 0, end: .pi / 2)
        XCTAssertNotNil(
            LivelineHoverResolver.resolve(location: CGPoint(x: 150, y: 100), snapshot: partial)
        )
        XCTAssertNotNil(
            LivelineHoverResolver.resolve(location: CGPoint(x: 100, y: 150), snapshot: partial)
        )
        XCTAssertNil(
            LivelineHoverResolver.resolve(location: CGPoint(x: 50, y: 100), snapshot: partial)
        )

        let wrapping = snapshot(start: 3 * .pi / 2, end: 5 * .pi / 2)
        XCTAssertNotNil(
            LivelineHoverResolver.resolve(location: CGPoint(x: 150, y: 100), snapshot: wrapping)
        )
        XCTAssertNil(
            LivelineHoverResolver.resolve(location: CGPoint(x: 50, y: 100), snapshot: wrapping)
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

    func testReducedMotionSettlesTimedTransitionsOnTheFirstFrame() {
        let state = LivelineRenderState()
        state.candleLineModeTransition = TimedTransition(
            from: 0,
            target: 1,
            startTimestamp: 10
        )
        state.settlesTransitionsImmediately = true

        let progress = state.transitionProgress(
            current: 0,
            target: 1,
            duration: 0.5,
            timestamp: 10,
            transition: \.candleLineModeTransition
        )

        XCTAssertEqual(progress, 1)
        XCTAssertNil(state.candleLineModeTransition)
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
