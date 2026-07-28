import Foundation
import XCTest
@testable import Liveline

final class LivelineAccessibilityTests: XCTestCase {
    func testChartAccessibilityAnnouncesSummaryAndSupportsDataInspection() {
        let content = LivelineChartContent.line(
            data: [
                LivelinePoint(time: 1, value: 10),
                LivelinePoint(time: 2, value: 14),
            ],
            value: 14
        )
        let configuration = LivelineChartConfiguration(
            formatValue: { String(Int($0)) },
            formatTime: { "T\(Int($0))" }
        )
        let model = LivelineChartAccessibilityModel.make(
            content: content,
            semantics: content.semantics(),
            configuration: configuration,
            hiddenSeries: []
        )

        XCTAssertEqual(model.label, "Line chart")
        XCTAssertEqual(model.summary, "Current value 14")
        XCTAssertEqual(model.value(at: nil), "Current value 14. 2 data points")
        XCTAssertEqual(model.hint, "Adjust to inspect data points.")
        XCTAssertEqual(model.adjustedIndex(from: nil, direction: .increment), 0)
        XCTAssertEqual(model.value(at: 0), "T1, 10, 1 of 2")
        XCTAssertEqual(model.adjustedIndex(from: 0, direction: .decrement), 0)
        XCTAssertEqual(model.adjustedIndex(from: 1, direction: .increment), 1)
    }

    func testAccessibilityRepresentationExcludesHiddenSeries() {
        let content = LivelineChartContent.series([
            LivelineSeries(
                id: "revenue",
                data: [
                    LivelinePoint(time: 1, value: 12),
                    LivelinePoint(time: 2, value: 14),
                ],
                value: 14,
                color: .blue,
                label: "Revenue"
            ),
            LivelineSeries(
                id: "cost",
                data: [
                    LivelinePoint(time: 1, value: 8),
                    LivelinePoint(time: 2, value: 9),
                ],
                value: 9,
                color: .red,
                label: "Cost"
            ),
        ])
        let configuration = LivelineChartConfiguration(
            formatValue: { String(Int($0)) },
            formatTime: { "T\(Int($0))" }
        )
        let model = LivelineChartAccessibilityModel.make(
            content: content,
            semantics: content.semantics(hiddenSeries: ["cost"]),
            configuration: configuration,
            hiddenSeries: ["cost"]
        )

        XCTAssertEqual(model.label, "Multi-series chart")
        XCTAssertEqual(model.entries.map(\.label), ["Revenue, T1", "Revenue, T2"])
        XCTAssertFalse(model.value(at: 0).contains("Cost"))
    }

    func testAccessibilityRepresentationDescribesEmptyAndStructuredCharts() {
        let empty = LivelineChartContent.bars(data: [], style: LivelineBarStyle())
        var configuration = LivelineChartConfiguration()
        configuration.emptyText = "Nothing yet"
        let emptyModel = LivelineChartAccessibilityModel.make(
            content: empty,
            semantics: empty.semantics(),
            configuration: configuration,
            hiddenSeries: []
        )
        XCTAssertEqual(emptyModel.summary, "Nothing yet")
        XCTAssertEqual(emptyModel.hint, "No chart data is available.")

        configuration.loading = true
        let loadingModel = LivelineChartAccessibilityModel.make(
            content: empty,
            semantics: empty.semantics(),
            configuration: configuration,
            hiddenSeries: []
        )
        XCTAssertEqual(loadingModel.summary, "Loading chart data")
        XCTAssertEqual(loadingModel.value(at: nil), "Loading chart data")
        XCTAssertEqual(loadingModel.hint, "Chart data is loading.")
        XCTAssertTrue(loadingModel.isLoading)

        configuration.loading = false
        let candle = LivelineChartContent.candle(
            data: [],
            value: 13,
            candles: [
                LivelineCandle(time: 1, open: 10, high: 15, low: 9, close: 13),
            ],
            candleWidth: 1,
            liveCandle: nil,
            lineData: [],
            lineValue: nil
        )
        configuration.formatValue = { String(Int($0)) }
        configuration.formatTime = { "T\(Int($0))" }
        let candleModel = LivelineChartAccessibilityModel.make(
            content: candle,
            semantics: candle.semantics(),
            configuration: configuration,
            hiddenSeries: []
        )
        XCTAssertEqual(
            candleModel.entries.first?.value,
            "Open 10, high 15, low 9, close 13"
        )
    }

    func testAccessibilityMatchesRenderableRadialAndSeriesData() {
        let categories = [
            LivelineCategoryValue(id: "positive", label: "Positive", value: 10),
            LivelineCategoryValue(id: "zero", label: "Zero", value: 0),
            LivelineCategoryValue(id: "negative", label: "Negative", value: -15),
        ]
        var configuration = LivelineChartConfiguration()
        configuration.formatValue = { String(Int($0)) }

        let donut = LivelineChartContent.donut(data: categories, style: LivelineDonutStyle())
        let donutModel = LivelineChartAccessibilityModel.make(
            content: donut,
            semantics: donut.semantics(),
            configuration: configuration,
            hiddenSeries: []
        )
        XCTAssertEqual(donut.semantics().currentValue, 10)
        let preparedDonut = LivelineChartPreparer.prepare(
            for: donut,
            hiddenSeries: [],
            leftEdge: 0,
            rightEdge: 1,
            config: configuration
        )
        XCTAssertTrue(preparedDonut.hasData)
        XCTAssertEqual(preparedDonut.primaryValue, 10)
        XCTAssertEqual(donutModel.entries.map(\.label), ["Positive"])
        XCTAssertEqual(donutModel.entries.first?.value, "10, 100.0 percent")

        let funnel = LivelineChartContent.funnel(data: categories, style: LivelineFunnelStyle())
        let funnelModel = LivelineChartAccessibilityModel.make(
            content: funnel,
            semantics: funnel.semantics(),
            configuration: configuration,
            hiddenSeries: []
        )
        XCTAssertEqual(funnel.semantics().currentValue, 10)
        XCTAssertEqual(funnelModel.entries.map(\.label), ["Positive"])

        let insufficientRadar = LivelineChartContent.radar(
            data: [
                LivelineRadarPoint(label: "A", value: 1),
                LivelineRadarPoint(label: "B", value: 2),
            ],
            style: LivelineRadarStyle()
        )
        let radarModel = LivelineChartAccessibilityModel.make(
            content: insufficientRadar,
            semantics: insufficientRadar.semantics(),
            configuration: configuration,
            hiddenSeries: []
        )
        XCTAssertEqual(radarModel.entryCount, 0)
        XCTAssertEqual(radarModel.summary, configuration.emptyText)

        let insufficientSeries = LivelineChartContent.series([
            LivelineSeries(
                id: "single",
                data: [LivelinePoint(time: 1, value: 2)],
                value: 2,
                color: .blue
            ),
        ])
        let seriesModel = LivelineChartAccessibilityModel.make(
            content: insufficientSeries,
            semantics: insufficientSeries.semantics(),
            configuration: configuration,
            hiddenSeries: []
        )
        XCTAssertEqual(seriesModel.entryCount, 0)
        XCTAssertEqual(seriesModel.summary, configuration.emptyText)
    }

    func testSummaryOnlyAccessibilityModelAvoidsFormattingDenseEntries() {
        let points = (0..<10_000).map {
            LivelinePoint(time: Double($0), value: Double($0))
        }
        let content = LivelineChartContent.line(data: points, value: 9_999)
        var formatCallCount = 0
        let configuration = LivelineChartConfiguration(
            formatValue: {
                formatCallCount += 1
                return String(Int($0))
            },
            formatTime: {
                formatCallCount += 1
                return String(Int($0))
            }
        )

        let first = LivelineChartAccessibilityModel.make(
            content: content,
            semantics: content.semantics(),
            configuration: configuration,
            hiddenSeries: [],
            includeEntries: false
        )
        let second = LivelineChartAccessibilityModel.make(
            content: content,
            semantics: content.semantics(),
            configuration: configuration,
            hiddenSeries: [],
            includeEntries: false
        )

        XCTAssertEqual(first.entryCount, points.count)
        XCTAssertTrue(first.entries.isEmpty)
        XCTAssertEqual(second.entryCount, points.count)
        XCTAssertEqual(formatCallCount, 2)
    }

    func testNormalizedStackAccessibilityMatchesRenderedSemantics() {
        let content = LivelineChartContent.stackedAreas(
            data: [LivelineStackedPoint(time: 1, values: [10, -4])],
            style: LivelineStackedAreaStyle(mode: .normalized)
        )
        let configuration = LivelineChartConfiguration(
            formatValue: { String(format: "%.1f", $0) },
            formatTime: { "T\(Int($0))" }
        )
        let model = LivelineChartAccessibilityModel.make(
            content: content,
            semantics: content.semantics(),
            configuration: configuration,
            hiddenSeries: []
        )

        XCTAssertEqual(
            model.entries.first?.value,
            "Series 1 1.0, Series 2 -1.0, total 0.0"
        )
    }
}
