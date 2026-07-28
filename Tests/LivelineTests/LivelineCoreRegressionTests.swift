import SwiftUI
import XCTest
@testable import Liveline

final class LivelineCoreRegressionTests: XCTestCase {
    private let layout = LivelineLayout(
        size: CGSize(width: 320, height: 220),
        padding: LivelineResolvedPadding(top: 20, right: 20, bottom: 20, left: 20),
        minValue: -20,
        maxValue: 20,
        leftEdge: 0,
        rightEdge: 10
    )

    private var palette: LivelinePalette {
        LivelinePalette.resolve(accent: .blue, mode: .dark, lineWidth: 2)
    }

    func testOrderbookSizeAtIntegerBoundaryUsesSafeScientificFormatting() {
        let boundary = Double(Int.max)

        for size in [boundary, boundary.nextUp] {
            let formatted = LivelineRenderer.formatOrderSize(size)
            XCTAssertTrue(formatted.hasPrefix("$"))
            XCTAssertTrue(formatted.lowercased().contains("e"))
        }
        XCTAssertEqual(
            LivelineRenderer.formatOrderSize(boundary.nextDown),
            "$9223372036854774784"
        )
        XCTAssertEqual(LivelineRenderer.formatOrderSize(12.4), "$12")
        XCTAssertEqual(LivelineRenderer.formatOrderSize(1.25), "$1.2")
        XCTAssertEqual(LivelineRenderer.formatOrderSize(0.25), "$0.25")
    }

    func testMixedSignStackTooltipPreservesSignsAndNetTotal() throws {
        let point = LivelineStackedPoint(time: 5, values: [10, -4])
        let content = LivelineChartContent.stackedBars(
            data: [point],
            style: LivelineStackedBarStyle()
        )
        var configuration = LivelineChartConfiguration(scrub: true, paused: true)
        configuration.formatValue = { String($0) }
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
            behavior: .discrete
        )
        let target = try XCTUnwrap(snapshot.targets.first)

        XCTAssertEqual(target.selection.rows.map(\.value), ["10.0", "-4.0", "6.0"])
        XCTAssertEqual(target.selection.hover.value, 6)
    }

    func testNormalizedMixedSignStackTooltipPreservesDirections() throws {
        let point = LivelineStackedPoint(time: 5, values: [10, -4])
        let content = LivelineChartContent.stackedAreas(
            data: [point],
            style: LivelineStackedAreaStyle(mode: .normalized)
        )
        var configuration = LivelineChartConfiguration(scrub: true, paused: true)
        configuration.formatValue = { String($0) }
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
            behavior: .discrete
        )
        let target = try XCTUnwrap(snapshot.targets.first)

        XCTAssertEqual(target.selection.rows.map(\.value), ["1.0", "-1.0", "0.0"])
        XCTAssertEqual(target.selection.hover.value, 0)
    }

    func testFirstInsufficientSeriesDoesNotBecomePrimary() throws {
        let content = LivelineChartContent.series([
            LivelineSeries(
                id: "empty",
                data: [],
                value: -999,
                color: .purple,
                label: "Empty"
            ),
            LivelineSeries(
                id: "insufficient",
                data: [LivelinePoint(time: 50, value: 999)],
                value: 999,
                color: .red,
                label: "Insufficient"
            ),
            LivelineSeries(
                id: "renderable",
                data: [
                    LivelinePoint(time: 4, value: 10),
                    LivelinePoint(time: 6, value: 20),
                ],
                value: 20,
                color: .blue,
                label: "Renderable"
            ),
        ])
        let configuration = LivelineChartConfiguration(scrub: true, paused: true)

        let semantics = content.semantics()
        XCTAssertEqual(semantics.currentValue, 20)
        XCTAssertEqual(semantics.latestTime, 6)

        let prepared = LivelineChartPreparer.prepare(
            for: content,
            hiddenSeries: [],
            leftEdge: layout.leftEdge,
            rightEdge: layout.rightEdge,
            config: configuration
        )
        XCTAssertEqual(prepared.primaryValue, 20)
        XCTAssertEqual(prepared.primaryVisible.map(\.value), [10, 20])
        XCTAssertFalse(prepared.rangePoints.contains { $0.value == 999 })

        let snapshot = LivelineInteractionBuilder.snapshot(
            content: content,
            prepared: prepared,
            layout: layout,
            palette: palette,
            configuration: configuration,
            hiddenSeries: [],
            behavior: .interpolated
        )
        let target = try XCTUnwrap(snapshot.targets.first)
        XCTAssertEqual(target.selection.rows.map(\.label), ["Renderable"])
    }

    func testFirstSeriesNeedsTwoPointsInsideTheVisibleWindowToBecomePrimary() throws {
        let content = LivelineChartContent.series([
            LivelineSeries(
                id: "mostly-offscreen",
                data: [
                    LivelinePoint(time: -53, value: 500),
                    LivelinePoint(time: -52, value: 600),
                    LivelinePoint(time: -51, value: 700),
                    LivelinePoint(time: -50, value: 800),
                    LivelinePoint(time: 5, value: 999),
                ],
                value: 999,
                color: .red,
                label: "Mostly offscreen"
            ),
            LivelineSeries(
                id: "visible",
                data: [
                    LivelinePoint(time: 2, value: 10),
                    LivelinePoint(time: 3, value: 12),
                    LivelinePoint(time: 4, value: 10),
                    LivelinePoint(time: 5, value: 16),
                    LivelinePoint(time: 6, value: 20),
                ],
                value: 20,
                color: .blue,
                label: "Visible"
            ),
        ])
        let configuration = LivelineChartConfiguration(scrub: true, paused: true)
        let semantics = content.semantics(activeWindow: 10)
        let prepared = LivelineChartPreparer.prepare(
            for: content,
            hiddenSeries: [],
            leftEdge: layout.leftEdge,
            rightEdge: layout.rightEdge,
            config: configuration
        )

        XCTAssertEqual(semantics.currentValue, 20)
        XCTAssertEqual(semantics.momentum, .up)
        XCTAssertEqual(prepared.primaryValue, 20)
        XCTAssertEqual(prepared.primaryVisible.map(\.value), [10, 12, 10, 16, 20])
        XCTAssertEqual(prepared.rangePoints.map(\.value), [10, 12, 10, 16, 20])

        let snapshot = LivelineInteractionBuilder.snapshot(
            content: content,
            prepared: prepared,
            layout: layout,
            palette: palette,
            configuration: configuration,
            hiddenSeries: [],
            behavior: .interpolated
        )
        let target = try XCTUnwrap(snapshot.targets.first)
        XCTAssertEqual(target.selection.rows.map(\.label), ["Visible"])
    }

    func testSeriesSemanticsUsesTheSameBufferedWindowAsRendering() throws {
        let content = LivelineChartContent.series([
            LivelineSeries(
                id: "buffered-boundary",
                data: [
                    LivelinePoint(time: 69, value: 10),
                    LivelinePoint(time: 99, value: 20),
                ],
                value: 20,
                color: .red,
                label: "Buffered boundary"
            ),
            LivelineSeries(
                id: "strict-window",
                data: [
                    LivelinePoint(time: 90, value: 100),
                    LivelinePoint(time: 100, value: 120),
                ],
                value: 120,
                color: .blue,
                label: "Strict window"
            ),
        ])
        let window: TimeInterval = 30
        let rightEdge = 100 + window * LivelineRenderer.windowBufferNoBadge
        let leftEdge = rightEdge - window
        let configuration = LivelineChartConfiguration(window: window, scrub: true, paused: true)
        let semantics = content.semantics(activeWindow: window)
        let prepared = LivelineChartPreparer.prepare(
            for: content,
            hiddenSeries: [],
            leftEdge: leftEdge,
            rightEdge: rightEdge,
            config: configuration
        )
        let bufferedLayout = LivelineLayout(
            size: layout.size,
            padding: layout.padding,
            minValue: layout.minValue,
            maxValue: 140,
            leftEdge: leftEdge,
            rightEdge: rightEdge
        )
        let snapshot = LivelineInteractionBuilder.snapshot(
            content: content,
            prepared: prepared,
            layout: bufferedLayout,
            palette: palette,
            configuration: configuration,
            hiddenSeries: [],
            behavior: .interpolated
        )

        XCTAssertEqual(semantics.currentValue, 20)
        XCTAssertEqual(prepared.primaryValue, 20)
        XCTAssertEqual(prepared.primaryVisible.map(\.time), [69, 99])
        XCTAssertEqual(
            try XCTUnwrap(snapshot.targets.first).selection.rows.map(\.label),
            ["Buffered boundary", "Strict window"]
        )
    }

    func testTimelineAndUnlabeledHeatmapUseGlobalLaneAndRowCounts() throws {
        let timeline = LivelineChartContent.timeline(
            data: [
                LivelineTimelineItem(id: "visible", label: "Visible", start: 1, end: 2, lane: 0),
                LivelineTimelineItem(id: "offscreen", label: "Offscreen", start: 20, end: 21, lane: 2),
            ],
            style: LivelineTimelineStyle()
        )
        let heatmap = LivelineChartContent.heatmap(
            data: [
                LivelineHeatmapCell(time: 1, row: 0, value: 0.25),
                LivelineHeatmapCell(time: 20, row: 2, value: 0.75),
            ],
            style: LivelineHeatmapStyle()
        )
        let labeledHeatmap = LivelineChartContent.heatmap(
            data: [
                LivelineHeatmapCell(time: 1, row: 0, value: 0.25),
                LivelineHeatmapCell(time: 20, row: 2, value: 0.75),
            ],
            style: LivelineHeatmapStyle(rowLabels: ["Top", "Middle", "Bottom"])
        )
        let configuration = LivelineChartConfiguration(scrub: true, paused: true)
        let shiftedLayout = LivelineLayout(
            size: layout.size,
            padding: layout.padding,
            minValue: layout.minValue,
            maxValue: layout.maxValue,
            leftEdge: 15,
            rightEdge: 25
        )

        func firstAnchor(
            for content: LivelineChartContent,
            layout targetLayout: LivelineLayout
        ) throws -> CGPoint {
            let prepared = LivelineChartPreparer.prepare(
                for: content,
                hiddenSeries: [],
                leftEdge: targetLayout.leftEdge,
                rightEdge: targetLayout.rightEdge,
                config: configuration
            )
            let snapshot = LivelineInteractionBuilder.snapshot(
                content: content,
                prepared: prepared,
                layout: targetLayout,
                palette: palette,
                configuration: configuration,
                hiddenSeries: [],
                behavior: .none
            )
            return try XCTUnwrap(snapshot.targets.first).selection.anchor
        }

        let rowHeight = layout.chartHeight / 3
        let expectedFirstRowCenter = layout.padding.top + rowHeight / 2
        let expectedTimelineTop = expectedFirstRowCenter
            - rowHeight * LivelineTimelineStyle().resolvedBarHeightRatio / 2
        let expectedLastRowCenter = expectedFirstRowCenter + rowHeight * 2
        let expectedLastTimelineTop = expectedTimelineTop + rowHeight * 2
        XCTAssertEqual(
            try firstAnchor(for: timeline, layout: layout).y,
            expectedTimelineTop,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try firstAnchor(for: timeline, layout: shiftedLayout).y,
            expectedLastTimelineTop,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try firstAnchor(for: heatmap, layout: layout).y,
            expectedFirstRowCenter,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try firstAnchor(for: heatmap, layout: shiftedLayout).y,
            expectedLastRowCenter,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try firstAnchor(for: labeledHeatmap, layout: layout).y,
            expectedFirstRowCenter,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try firstAnchor(for: labeledHeatmap, layout: shiftedLayout).y,
            expectedLastRowCenter,
            accuracy: 0.0001
        )
    }

    func testOffscreenActivePointDoesNotExpandVisibleValueRange() {
        let prepared = LivelinePreparedChart(
            primaryVisible: [
                LivelinePoint(time: 2, value: 4),
                LivelinePoint(time: 8, value: 6),
            ],
            rangePoints: [
                LivelinePoint(time: 2, value: 4),
                LivelinePoint(time: 8, value: 6),
            ],
            rangeOverride: nil,
            primaryValue: 6
        )
        var configuration = LivelineChartConfiguration()
        configuration.activePoint = LivelineActivePoint(time: 50, value: 1_000)

        let unchanged = LivelineRenderer.rangeIncludingActivePoint(
            3...7,
            renderData: prepared,
            visibleTimeRange: 0...10,
            config: configuration
        )
        XCTAssertEqual(unchanged, 3...7)

        configuration.activePoint = LivelineActivePoint(time: 5, value: 1_000)
        let expanded = LivelineRenderer.rangeIncludingActivePoint(
            3...7,
            renderData: prepared,
            visibleTimeRange: 0...10,
            config: configuration
        )
        XCTAssertEqual(expanded, 3...1_000)
    }

    func testOffscreenFallbackCandleDoesNotDistortPopulatedVisibleRange() {
        let content = LivelineChartContent.candle(
            data: [
                LivelinePoint(time: 2, value: 10),
                LivelinePoint(time: 8, value: 12),
            ],
            value: 12,
            candles: [
                LivelineCandle(time: 100, open: 0, high: 1_000, low: -1_000, close: 0),
            ],
            candleWidth: 1,
            liveCandle: nil,
            lineData: [],
            lineValue: nil
        )

        let prepared = LivelineChartPreparer.prepare(
            for: content,
            hiddenSeries: [],
            leftEdge: 0,
            rightEdge: 10,
            config: LivelineChartConfiguration()
        )

        XCTAssertEqual(prepared.rangePoints.map(\.value), [10, 12])
    }

    func testOffscreenLiveCandleCloseDoesNotDistortPopulatedVisibleRange() {
        let content = LivelineChartContent.candle(
            data: [
                LivelinePoint(time: 2, value: 10),
                LivelinePoint(time: 8, value: 12),
            ],
            value: 12,
            candles: [],
            candleWidth: 1,
            liveCandle: LivelineCandle(
                time: 100,
                open: 900,
                high: 1_000,
                low: 800,
                close: 900
            ),
            lineData: [],
            lineValue: nil
        )

        let prepared = LivelineChartPreparer.prepare(
            for: content,
            hiddenSeries: [],
            leftEdge: 0,
            rightEdge: 10,
            config: LivelineChartConfiguration()
        )

        XCTAssertEqual(prepared.rangePoints.map(\.value), [10, 12])
        XCTAssertEqual(prepared.primaryValue, 12)
    }

    func testVisibleLiveCandleStillContributesItsRangeAndClose() {
        let content = LivelineChartContent.candle(
            data: [
                LivelinePoint(time: 2, value: 10),
                LivelinePoint(time: 8, value: 12),
            ],
            value: 12,
            candles: [],
            candleWidth: 1,
            liveCandle: LivelineCandle(
                time: 8,
                open: 12,
                high: 20,
                low: 6,
                close: 18
            ),
            lineData: [],
            lineValue: nil
        )

        let prepared = LivelineChartPreparer.prepare(
            for: content,
            hiddenSeries: [],
            leftEdge: 0,
            rightEdge: 10,
            config: LivelineChartConfiguration()
        )

        XCTAssertTrue(prepared.rangePoints.contains { $0.value == 20 })
        XCTAssertTrue(prepared.rangePoints.contains { $0.value == 6 })
        XCTAssertEqual(prepared.primaryValue, 18)
    }

    func testOffscreenLiveCandleRemainsPrimaryWhenFallbackIsNeeded() {
        let liveCandle = LivelineCandle(
            time: 100,
            open: 900,
            high: 1_000,
            low: 800,
            close: 900
        )
        let content = LivelineChartContent.candle(
            data: [],
            value: 12,
            candles: [],
            candleWidth: 1,
            liveCandle: liveCandle,
            lineData: [],
            lineValue: nil
        )

        let prepared = LivelineChartPreparer.prepare(
            for: content,
            hiddenSeries: [],
            leftEdge: 0,
            rightEdge: 10,
            config: LivelineChartConfiguration()
        )

        XCTAssertEqual(prepared.rangePoints.map(\.value), [1_000, 800])
        XCTAssertEqual(prepared.primaryValue, 900)
    }

    func testLastCandleStillContributesWhenVisibleWindowNeedsFallbackData() {
        let content = LivelineChartContent.candle(
            data: [],
            value: 12,
            candles: [
                LivelineCandle(time: 100, open: 10, high: 14, low: 8, close: 12),
            ],
            candleWidth: 1,
            liveCandle: nil,
            lineData: [],
            lineValue: nil
        )

        let prepared = LivelineChartPreparer.prepare(
            for: content,
            hiddenSeries: [],
            leftEdge: 0,
            rightEdge: 10,
            config: LivelineChartConfiguration()
        )

        XCTAssertEqual(prepared.rangePoints.map(\.value), [14, 8])
    }
}
