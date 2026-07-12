import XCTest
@testable import Liveline

final class LivelinePreparationTests: XCTestCase {
    func testContentNormalizationOrdersDeduplicatesAndDropsInvalidPoints() throws {
        let content = LivelineChartContent.line(
            data: [
                LivelinePoint(time: 30, value: 3),
                LivelinePoint(time: 10, value: 1),
                LivelinePoint(time: 20, value: 2),
                LivelinePoint(time: 20, value: 22),
                LivelinePoint(time: .nan, value: 4),
                LivelinePoint(time: 40, value: .infinity),
            ],
            value: .nan
        ).normalized()

        guard case let .line(data, value) = content else {
            return XCTFail("Expected normalized line content")
        }

        XCTAssertEqual(data, [
            LivelinePoint(time: 10, value: 1),
            LivelinePoint(time: 20, value: 22),
            LivelinePoint(time: 30, value: 3),
        ])
        XCTAssertEqual(value, 3)
        XCTAssertEqual(data.livelineVisible(in: 15...25), [LivelinePoint(time: 20, value: 22)])
    }

    func testInterpolationNormalizesUnorderedInputAtItsSafeInterface() throws {
        let points = [
            LivelinePoint(time: 10, value: 10),
            LivelinePoint(time: 30, value: 30),
            LivelinePoint(time: 20, value: 20),
        ]

        XCTAssertEqual(try XCTUnwrap(LivelineMath.interpolate(points: points, at: 25)), 25, accuracy: 0.0001)
    }

    func testHeatmapNormalizationPreservesRowsAtSharedTimes() {
        let normalized = LivelineInputNormalizer.heatmap([
            LivelineHeatmapCell(time: 20, row: 2, value: 30),
            LivelineHeatmapCell(time: 10, row: 0, value: 10),
            LivelineHeatmapCell(time: 10, row: 1, value: 20),
            LivelineHeatmapCell(time: 10, row: 1, value: 21),
            LivelineHeatmapCell(time: 20, row: 0, value: 40),
        ])

        XCTAssertEqual(normalized.map(\.id), ["10.0-0", "10.0-1", "20.0-0", "20.0-2"])
        XCTAssertEqual(normalized.map(\.value), [10, 21, 40, 30])
    }

    func testCandleNormalizationRepairsBoundsAndWidth() {
        let content = LivelineChartContent.candle(
            data: [],
            value: .nan,
            candles: [LivelineCandle(time: 20, open: 8, high: 4, low: 12, close: 10)],
            candleWidth: -30,
            liveCandle: nil,
            lineData: [],
            lineValue: .infinity
        ).normalized()

        guard case let .candle(_, value, candles, width, _, _, lineValue) = content else {
            return XCTFail("Expected normalized candle content")
        }

        XCTAssertEqual(value, 10)
        XCTAssertEqual(width, 1)
        XCTAssertEqual(candles.first?.high, 12)
        XCTAssertEqual(candles.first?.low, 4)
        XCTAssertNil(lineValue)
    }

    func testRenderingConfigurationRejectsInvalidScalarInputs() {
        let configuration = LivelineChartConfiguration(
            window: -10,
            windows: [
                LivelineWindowOption(label: "bad", seconds: .nan),
                LivelineWindowOption(label: "zero", seconds: 0),
                LivelineWindowOption(label: "valid", seconds: 20),
                LivelineWindowOption(label: "duplicate", seconds: 20),
            ],
            lineWidth: .nan,
            degen: LivelineDegenOptions(scale: -4),
            tooltipY: .infinity,
            lerpSpeed: 4,
            snapshotElapsedTime: -.infinity,
            padding: LivelinePadding(top: -4, right: .nan)
        ).normalizedForRendering()

        XCTAssertEqual(configuration.window, 30)
        XCTAssertEqual(configuration.windows.map(\.seconds), [20])
        XCTAssertEqual(configuration.lineWidth, 2)
        XCTAssertEqual(configuration.degen?.scale, 0)
        XCTAssertEqual(configuration.tooltipY, 14)
        XCTAssertEqual(configuration.lerpSpeed, 1)
        XCTAssertNil(configuration.resolvedSnapshotElapsedTime)
        XCTAssertEqual(configuration.padding.top, 0)
        XCTAssertNil(configuration.padding.right)
    }

    func testPreparedChartUsesNormalizedWindowSlice() {
        let content = LivelineChartContent.line(
            data: (0..<100).map { LivelinePoint(time: Double($0), value: Double($0)) },
            value: 99
        ).normalized()
        let prepared = LivelineChartPreparer.prepare(
            for: content,
            hiddenSeries: [],
            leftEdge: 40,
            rightEdge: 50,
            config: LivelineChartConfiguration()
        )

        XCTAssertEqual(prepared.primaryVisible.first?.time, 38)
        XCTAssertEqual(prepared.primaryVisible.last?.time, 50)
        XCTAssertEqual(prepared.primaryValue, 99)
        XCTAssertTrue(prepared.hasData)
    }

    func testSeriesNormalizationRemovesDuplicateIDsAndInvalidSamples() {
        let series = LivelineInputNormalizer.series([
            LivelineSeries(
                id: "alpha",
                data: [LivelinePoint(time: 2, value: 2), LivelinePoint(time: 1, value: 1)],
                value: .nan,
                color: .blue
            ),
            LivelineSeries(id: "alpha", data: [], value: 4, color: .red),
            LivelineSeries(id: "", data: [], value: 0, color: .green),
        ])

        XCTAssertEqual(series.count, 1)
        XCTAssertEqual(series[0].data.map(\.time), [1, 2])
        XCTAssertEqual(series[0].value, 2)
    }

    func testMutableStylesResolveNonFiniteScalarsAtTheRenderingBoundary() {
        var bar = LivelineBarStyle()
        bar.baseline = .nan
        bar.widthRatio = .nan
        bar.cornerRadius = .infinity
        XCTAssertEqual(bar.resolvedBaseline, 0)
        XCTAssertEqual(bar.resolvedWidthRatio, 0.7)
        XCTAssertEqual(bar.resolvedCornerRadius, 2)

        var radar = LivelineRadarStyle()
        radar.range = (-Double.infinity)...Double.infinity
        radar.fillOpacity = .nan
        XCTAssertEqual(radar.resolvedRange, 0...1)
        XCTAssertEqual(radar.resolvedFillOpacity, 0.18)

        var gauge = LivelineGaugeStyle()
        gauge.sweepDegrees = .nan
        gauge.lineWidth = .nan
        gauge.target = .nan
        XCTAssertEqual(gauge.resolvedSweepDegrees, 240)
        XCTAssertEqual(gauge.resolvedLineWidth, 18)
        XCTAssertNil(gauge.resolvedTarget)
    }

    func testGaugeRangeAndTimelineOrderAreNormalized() {
        let gauge = LivelineChartContent.gauge(
            value: .nan,
            range: (-Double.infinity)...Double.infinity,
            style: LivelineGaugeStyle()
        ).normalized()
        guard case let .gauge(value, range, _) = gauge else {
            return XCTFail("Expected gauge content")
        }
        XCTAssertEqual(value, 0)
        XCTAssertEqual(range, 0...1)

        let timeline = LivelineChartContent.timeline(
            data: [
                LivelineTimelineItem(id: "late", label: "Late", start: 8, end: 9, lane: 0),
                LivelineTimelineItem(id: "early", label: "Early", start: 2, end: 4, lane: 0),
                LivelineTimelineItem(id: "late", label: "Duplicate", start: 1, end: 2, lane: 1),
            ],
            style: LivelineTimelineStyle()
        ).normalized()
        guard case let .timeline(items, _) = timeline else {
            return XCTFail("Expected timeline content")
        }
        XCTAssertEqual(items.map(\.id), ["late", "early"])
        XCTAssertEqual(items.map(\.start), [1, 2])
    }

    func testExtremeFiniteInputsCannotOverflowRenderingGeometry() {
        let points = LivelineInputNormalizer.points([
            LivelinePoint(time: -.greatestFiniteMagnitude, value: -.greatestFiniteMagnitude),
            LivelinePoint(time: .greatestFiniteMagnitude, value: .greatestFiniteMagnitude),
        ])
        XCTAssertEqual(points.map(\.time), [
            -LivelineScalar.maximumTimeMagnitude,
            LivelineScalar.maximumTimeMagnitude,
        ])
        XCTAssertEqual(points.map(\.value), [
            -LivelineScalar.maximumValueMagnitude,
            LivelineScalar.maximumValueMagnitude,
        ])

        let range = LivelineMath.computeRange(
            points: points,
            currentValue: .greatestFiniteMagnitude,
            referenceValue: -.greatestFiniteMagnitude,
            exaggerate: false
        )
        XCTAssertTrue(range.lowerBound.isFinite)
        XCTAssertTrue(range.upperBound.isFinite)
        XCTAssertLessThan(range.lowerBound, range.upperBound)

        let configuration = LivelineChartConfiguration(
            window: .greatestFiniteMagnitude,
            windows: [LivelineWindowOption(label: "huge", seconds: .greatestFiniteMagnitude)],
            lineWidth: .greatestFiniteMagnitude,
            tooltipY: .greatestFiniteMagnitude,
            orderbook: LivelineOrderbookData(
                bids: [LivelineOrderbookLevel(price: .greatestFiniteMagnitude, size: .greatestFiniteMagnitude)],
                asks: []
            ),
            referenceLine: LivelineReferenceLine(value: .greatestFiniteMagnitude),
            activePoint: LivelineActivePoint(
                time: .greatestFiniteMagnitude,
                value: -.greatestFiniteMagnitude
            ),
            padding: LivelinePadding(top: .greatestFiniteMagnitude)
        ).normalizedForRendering()
        XCTAssertEqual(configuration.window, LivelineScalar.maximumTimeMagnitude)
        XCTAssertEqual(configuration.windows.first?.seconds, LivelineScalar.maximumTimeMagnitude)
        XCTAssertEqual(configuration.lineWidth, LivelineScalar.maximumDrawingMagnitude)
        XCTAssertEqual(configuration.tooltipY, LivelineScalar.maximumDrawingMagnitude)
        XCTAssertEqual(configuration.padding.top, LivelineScalar.maximumDrawingMagnitude)
        XCTAssertEqual(configuration.referenceLine?.value, LivelineScalar.maximumValueMagnitude)
        XCTAssertEqual(configuration.activePoint?.time, LivelineScalar.maximumTimeMagnitude)
        XCTAssertEqual(configuration.orderbook?.bids.first?.size, LivelineScalar.maximumValueMagnitude)

        let timeline = LivelineInputNormalizer.timeline([
            LivelineTimelineItem(id: "extreme", label: "Extreme", start: 0, end: 1, lane: .max),
        ])
        let heatmap = LivelineInputNormalizer.heatmap([
            LivelineHeatmapCell(time: 0, row: .max, value: 1),
        ])
        XCTAssertEqual(timeline.first?.lane, LivelineScalar.maximumDiscreteIndex)
        XCTAssertEqual(heatmap.first?.row, LivelineScalar.maximumDiscreteIndex)

        var gauge = LivelineGaugeStyle()
        gauge.startAngleDegrees = .greatestFiniteMagnitude
        XCTAssertTrue(gauge.resolvedStartAngleDegrees.isFinite)
        XCTAssertLessThan(abs(gauge.resolvedStartAngleDegrees), 360)
    }
}
