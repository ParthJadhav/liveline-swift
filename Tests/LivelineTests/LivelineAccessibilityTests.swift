import Foundation
import SwiftUI
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

    func testHistogramAccessibilityReadsEachBinAsARangeAndCount() {
        let configuration = LivelineChartConfiguration(
            formatValue: { String(Int($0)) },
            formatTime: { "T\(Int($0))" }
        )
        let content = LivelineChartContent.histogram(
            values: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
            style: LivelineHistogramStyle(binning: .count(5))
        )
        let model = LivelineChartAccessibilityModel.make(
            content: content,
            semantics: content.semantics(),
            configuration: configuration,
            hiddenSeries: []
        )

        XCTAssertEqual(model.label, "Histogram")
        XCTAssertEqual(model.entryCount, 5)
        XCTAssertEqual(model.entries.map(\.label), ["0 to 2", "2 to 4", "4 to 6", "6 to 8", "8 to 10"])
        XCTAssertEqual(model.entries.map(\.value), ["2 values", "2 values", "2 values", "2 values", "3 values"])
        XCTAssertEqual(model.value(at: 0), "0 to 2, 2 values, 1 of 5")

        let empty = LivelineChartContent.histogram(values: [], style: LivelineHistogramStyle())
        let emptyModel = LivelineChartAccessibilityModel.make(
            content: empty,
            semantics: empty.semantics(),
            configuration: configuration,
            hiddenSeries: []
        )
        XCTAssertEqual(emptyModel.entryCount, 0)
        XCTAssertEqual(emptyModel.summary, configuration.emptyText)
    }

    func testBulletAccessibilitySummarizesMeasureAgainstTargetAndBand() {
        let configuration = LivelineChartConfiguration(
            formatValue: { String(Int($0)) },
            formatTime: { "T\(Int($0))" }
        )
        let style = LivelineBulletStyle(
            measure: 72,
            target: 80,
            ranges: [
                LivelineBulletRange(value: 50, label: "poor"),
                LivelineBulletRange(value: 75, label: "good"),
                LivelineBulletRange(value: 100, label: "great"),
            ],
            label: "Conversion"
        )
        let content = LivelineChartContent.bullet(style: style)
        let model = LivelineChartAccessibilityModel.make(
            content: content,
            semantics: content.semantics(),
            configuration: configuration,
            hiddenSeries: []
        )

        XCTAssertEqual(model.label, "Bullet chart")
        XCTAssertEqual(content.semantics().currentValue, 72)
        XCTAssertEqual(model.entryCount, 4)
        XCTAssertEqual(model.entries.first?.label, "Conversion")
        XCTAssertEqual(model.entries.first?.value, "72 of target 80, in 'good' range")
        XCTAssertEqual(model.entries.dropFirst().map(\.label), ["poor", "good", "great"])
        XCTAssertEqual(model.entries.last?.value, "Up to 100")

        // A bare measure degrades to the value alone.
        let bare = LivelineBulletStyle(measure: 72)
        XCTAssertEqual(
            LivelineChartAccessibilityModel.bulletSummary(style: bare, formatValue: configuration.formatValue),
            "72"
        )
        XCTAssertEqual(
            LivelineChartAccessibilityModel.bulletSummary(
                style: LivelineBulletStyle(measure: 72, target: 80),
                formatValue: configuration.formatValue
            ),
            "72 of target 80"
        )
    }

    func testHierarchyAndFlowAccessibilityReadEachCellWithItsShare() {
        let configuration = LivelineChartConfiguration(
            formatValue: { String(Int($0)) },
            formatTime: { "T\(Int($0))" }
        )

        let treemap = LivelineChartContent.treemap(
            nodes: [
                LivelineTreemapNode(label: "Compute", value: 50),
                LivelineTreemapNode(label: "Storage", children: [
                    LivelineTreemapNode(label: "Hot", value: 30),
                    LivelineTreemapNode(label: "Cold", value: 20),
                    LivelineTreemapNode(label: "Empty", value: 0),
                ]),
                LivelineTreemapNode(label: "Dropped", value: -4),
            ],
            style: LivelineTreemapStyle()
        )
        let treemapModel = LivelineChartAccessibilityModel.make(
            content: treemap,
            semantics: treemap.semantics(),
            configuration: configuration,
            hiddenSeries: []
        )

        XCTAssertEqual(treemapModel.label, "Treemap")
        // Only drawn cells are read: a parent is replaced by its children, and
        // zero or negative weights never take up space.
        XCTAssertEqual(treemapModel.entries.map(\.label), ["Compute", "Hot", "Cold"])
        XCTAssertEqual(treemapModel.entryCount, 3)
        XCTAssertEqual(treemapModel.entries.map(\.value), ["50, 50.0 percent", "30, 30.0 percent", "20, 20.0 percent"])
        XCTAssertEqual(treemapModel.value(at: 1), "Hot, 30, 30.0 percent, 2 of 3")

        let sunburst = LivelineChartContent.sunburst(
            nodes: [
                LivelineSunburstNode(label: "Direct", value: 60),
                LivelineSunburstNode(label: "Search", children: [
                    LivelineSunburstNode(label: "Organic", value: 30),
                    LivelineSunburstNode(label: "Paid", value: 10),
                ]),
            ],
            style: LivelineSunburstStyle()
        )
        let sunburstModel = LivelineChartAccessibilityModel.make(
            content: sunburst,
            semantics: sunburst.semantics(),
            configuration: configuration,
            hiddenSeries: []
        )

        XCTAssertEqual(sunburstModel.label, "Sunburst chart")
        // A parent is read before the children that subdivide it.
        XCTAssertEqual(sunburstModel.entries.map(\.label), ["Direct", "Search", "Organic", "Paid"])
        XCTAssertEqual(sunburstModel.entryCount, 4)
        XCTAssertEqual(sunburstModel.entries[1].value, "40, 40.0 percent")
        XCTAssertEqual(sunburstModel.entries[3].value, "10, 10.0 percent")

        let sankey = LivelineChartContent.sankey(
            links: [
                LivelineSankeyLink(source: "Visits", target: "Signups", value: 40),
                LivelineSankeyLink(source: "Signups", target: "Paid", value: 12),
                // Closes a cycle, so it never reaches the reader either.
                LivelineSankeyLink(source: "Paid", target: "Visits", value: 3),
            ],
            style: LivelineSankeyStyle()
        )
        let sankeyModel = LivelineChartAccessibilityModel.make(
            content: sankey,
            semantics: sankey.semantics(),
            configuration: configuration,
            hiddenSeries: []
        )

        XCTAssertEqual(sankeyModel.label, "Sankey diagram")
        XCTAssertEqual(sankeyModel.entries.map(\.label), ["Visits to Signups", "Signups to Paid"])
        XCTAssertEqual(sankeyModel.entries.map(\.value), ["40", "12"])
        XCTAssertEqual(sankeyModel.entryCount, 2)

        for empty in [
            LivelineChartContent.treemap(nodes: [], style: LivelineTreemapStyle()),
            LivelineChartContent.sunburst(nodes: [], style: LivelineSunburstStyle()),
            LivelineChartContent.sankey(links: [], style: LivelineSankeyStyle()),
        ] {
            let model = LivelineChartAccessibilityModel.make(
                content: empty,
                semantics: empty.semantics(),
                configuration: configuration,
                hiddenSeries: []
            )
            XCTAssertEqual(model.entryCount, 0)
            XCTAssertEqual(model.summary, configuration.emptyText)
        }
    }

    func testAudioGraphSonifiesHierarchyCellsAndFlowLinksAsCategories() {
        let configuration = LivelineChartConfiguration(
            formatValue: { String(Int($0)) },
            formatTime: { "T\(Int($0))" }
        )

        let treemap = LivelineChartContent.treemap(
            nodes: [
                LivelineTreemapNode(label: "Compute", value: 50),
                LivelineTreemapNode(label: "Storage", children: [
                    LivelineTreemapNode(label: "Hot", value: 30),
                ]),
            ],
            style: LivelineTreemapStyle()
        )
        let treemapModel = LivelineAudioGraphModel.make(
            content: treemap,
            semantics: treemap.semantics(),
            configuration: configuration,
            hiddenSeries: [],
            activeWindow: 60,
            title: "Treemap",
            summary: "80"
        )
        XCTAssertEqual(treemapModel.xAxis, .categories(["Compute", "Hot"]))
        XCTAssertEqual(treemapModel.series.first?.points.map(\.value), [50, 30])

        let sankey = LivelineChartContent.sankey(
            links: [
                LivelineSankeyLink(source: "Visits", target: "Signups", value: 40),
                LivelineSankeyLink(source: "Signups", target: "Paid", value: 12),
            ],
            style: LivelineSankeyStyle()
        )
        let sankeyModel = LivelineAudioGraphModel.make(
            content: sankey,
            semantics: sankey.semantics(),
            configuration: configuration,
            hiddenSeries: [],
            activeWindow: 60,
            title: "Sankey diagram",
            summary: "52"
        )
        XCTAssertEqual(sankeyModel.xAxis, .categories(["Visits to Signups", "Signups to Paid"]))
        XCTAssertEqual(sankeyModel.series.count, 1)
        XCTAssertFalse(sankeyModel.series[0].isContinuous)
        XCTAssertEqual(sankeyModel.series[0].points.map(\.value), [40, 12])
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

    func testAccessibilityModelIsMemoizedUntilItsInputsChange() {
        var data = (0..<12).map { LivelinePoint(time: Double($0), value: Double($0)) }
        var content = LivelineChartContent.line(data: data, value: data.last?.value ?? 0)
        var configuration = LivelineChartConfiguration(
            formatValue: { String(Int($0)) },
            formatTime: { "T\(Int($0))" }
        )
        let state = LivelineRenderState()

        func model(includeEntries: Bool = true) -> LivelineChartAccessibilityModel {
            let semantics = content.semantics()
            return state.accessibilityModel(
                for: LivelineAccessibilityModelKey.make(
                    content: content,
                    semantics: semantics,
                    configuration: configuration,
                    hiddenSeries: [],
                    includeEntries: includeEntries
                )
            ) {
                LivelineChartAccessibilityModel.make(
                    content: content,
                    semantics: semantics,
                    configuration: configuration,
                    hiddenSeries: [],
                    includeEntries: includeEntries
                )
            }
        }

        // Repeated body evaluations — a pointer moving over the chart — reuse
        // the model instead of reformatting every datum.
        let first = model()
        XCTAssertEqual(model(), first)
        XCTAssertEqual(model(), first)
        XCTAssertEqual(state.accessibilityModelBuildCount, 1)

        // VoiceOver switching on has to produce entries.
        XCTAssertTrue(model(includeEntries: false).entries.isEmpty)
        XCTAssertEqual(state.accessibilityModelBuildCount, 2)
        XCTAssertEqual(model().entries.count, 12)
        XCTAssertEqual(state.accessibilityModelBuildCount, 3)

        // New samples, a new formatter, and loading all invalidate it.
        data.append(LivelinePoint(time: 12, value: 40))
        content = .line(data: data, value: 40)
        XCTAssertEqual(model().entries.count, 13)
        XCTAssertEqual(state.accessibilityModelBuildCount, 4)

        configuration.formatValue = { "<\(Int($0))>" }
        XCTAssertEqual(model().entries.last?.value, "<40>")
        XCTAssertEqual(state.accessibilityModelBuildCount, 5)

        configuration.loading = true
        XCTAssertTrue(model().isLoading)
        XCTAssertEqual(state.accessibilityModelBuildCount, 6)
    }

    // MARK: - Audio Graph

    func testAudioGraphDescribesVisibleWindowAndContinuousLineSeries() {
        let data = (0...20).map { LivelinePoint(time: TimeInterval($0), value: Double($0) * 2) }
        let content = LivelineChartContent.line(data: data, value: 40)
        let configuration = LivelineChartConfiguration(
            formatValue: { String(Int($0)) },
            formatTime: { "T\(Int($0))" }
        )
        let model = LivelineAudioGraphModel.make(
            content: content,
            semantics: content.semantics(activeWindow: 5),
            configuration: configuration,
            hiddenSeries: [],
            activeWindow: 5,
            title: "Line chart",
            summary: "Current value 40"
        )

        XCTAssertEqual(model.title, "Line chart")
        XCTAssertEqual(model.summary, "Current value 40")
        XCTAssertEqual(model.xAxis, .time(15...20))
        // Only the trailing window is rendered, so only it is described.
        XCTAssertEqual(model.series.count, 1)
        XCTAssertEqual(model.series[0].name, "Value")
        XCTAssertTrue(model.series[0].isContinuous)
        XCTAssertEqual(model.series[0].points.map(\.value), [30, 32, 34, 36, 38, 40])
        XCTAssertEqual(model.valueRange, 30...40)
    }

    func testAudioGraphMarksDiscreteContentAndPadsFlatSeries() {
        let content = LivelineChartContent.bars(
            data: [
                LivelinePoint(time: 1, value: 7),
                LivelinePoint(time: 2, value: 7),
            ],
            style: LivelineBarStyle()
        )
        let model = LivelineAudioGraphModel.make(
            content: content,
            semantics: content.semantics(activeWindow: 10),
            configuration: LivelineChartConfiguration(),
            hiddenSeries: [],
            activeWindow: 10,
            title: "Bar chart",
            summary: "Current value 7"
        )

        XCTAssertEqual(model.series.count, 1)
        XCTAssertFalse(model.series[0].isContinuous)
        // A flat series would sonify as a divide-by-zero without padding.
        XCTAssertLessThan(model.valueRange.lowerBound, 7)
        XCTAssertGreaterThan(model.valueRange.upperBound, 7)
    }

    func testAudioGraphEmitsOneSeriesPerVisibleMultiSeriesEntry() {
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

        let all = LivelineAudioGraphModel.make(
            content: content,
            semantics: content.semantics(activeWindow: 10),
            configuration: LivelineChartConfiguration(),
            hiddenSeries: [],
            activeWindow: 10,
            title: "Multi-series chart",
            summary: "2 series"
        )
        XCTAssertEqual(all.series.map(\.name), ["Revenue", "Cost"])
        XCTAssertEqual(all.series.map { $0.points.map(\.value) }, [[12, 14], [8, 9]])
        XCTAssertTrue(all.series.allSatisfy(\.isContinuous))
        XCTAssertEqual(all.valueRange, 8...14)

        // Toggling a series off in the legend removes it from the Audio Graph.
        let visible = LivelineAudioGraphModel.make(
            content: content,
            semantics: content.semantics(hiddenSeries: ["cost"], activeWindow: 10),
            configuration: LivelineChartConfiguration(),
            hiddenSeries: ["cost"],
            activeWindow: 10,
            title: "Multi-series chart",
            summary: "1 series"
        )
        XCTAssertEqual(visible.series.map(\.name), ["Revenue"])
    }

    func testAudioGraphDescribesCategoricalContentByLabel() {
        let content = LivelineChartContent.donut(
            data: [
                LivelineCategoryValue(id: "direct", label: "Direct", value: 40),
                LivelineCategoryValue(id: "search", label: "Search", value: 60),
                LivelineCategoryValue(id: "empty", label: "Empty", value: 0),
            ],
            style: LivelineDonutStyle()
        )
        let model = LivelineAudioGraphModel.make(
            content: content,
            semantics: content.semantics(),
            configuration: LivelineChartConfiguration(),
            hiddenSeries: [],
            activeWindow: 60,
            title: "Donut chart",
            summary: "Total 100"
        )

        XCTAssertEqual(model.xAxis, .categories(["Direct", "Search"]))
        XCTAssertEqual(model.series.count, 1)
        XCTAssertEqual(model.series[0].points.map(\.category), ["Direct", "Search"])
        XCTAssertEqual(model.series[0].points.map(\.value), [40, 60])
    }

    func testAudioGraphDescribesHistogramBinsAndBulletBandsAsCategories() {
        let configuration = LivelineChartConfiguration(
            formatValue: { String(Int($0)) },
            formatTime: { "T\(Int($0))" }
        )
        let histogram = LivelineChartContent.histogram(
            values: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
            style: LivelineHistogramStyle(binning: .count(5))
        )
        let histogramModel = LivelineAudioGraphModel.make(
            content: histogram,
            semantics: histogram.semantics(),
            configuration: configuration,
            hiddenSeries: [],
            activeWindow: 60,
            title: "Histogram",
            summary: "11 samples"
        )

        XCTAssertEqual(
            histogramModel.xAxis,
            .categories(["0 to 2", "2 to 4", "4 to 6", "6 to 8", "8 to 10"])
        )
        XCTAssertEqual(histogramModel.series.count, 1)
        XCTAssertFalse(histogramModel.series[0].isContinuous)
        XCTAssertEqual(histogramModel.series[0].points.map(\.value), [2, 2, 2, 2, 3])

        let bullet = LivelineChartContent.bullet(style: LivelineBulletStyle(
            measure: 72,
            target: 80,
            ranges: [LivelineBulletRange(value: 50, label: "poor"), LivelineBulletRange(value: 100, label: "good")],
            axisRange: 0...100
        ))
        let bulletModel = LivelineAudioGraphModel.make(
            content: bullet,
            semantics: bullet.semantics(),
            configuration: configuration,
            hiddenSeries: [],
            activeWindow: 60,
            title: "Bullet chart",
            summary: "72 of target 80"
        )

        XCTAssertEqual(bulletModel.xAxis, .categories(["Measure", "Target", "poor", "good"]))
        XCTAssertEqual(bulletModel.series.first?.points.map(\.value), [72, 80, 50, 100])
        XCTAssertEqual(bulletModel.valueRange, 0...100)
    }

    #if canImport(Accessibility)
    @MainActor
    func testChartDescriptorBuildsAxesAndSeriesForVoiceOver() {
        let content = LivelineChartContent.line(
            data: (0...4).map { LivelinePoint(time: TimeInterval($0), value: Double($0) * 3) },
            value: 12
        )
        let configuration = LivelineChartConfiguration(
            formatValue: { String(Int($0)) },
            formatTime: { "T\(Int($0))" }
        )
        let representable = LivelineChartDescriptor(
            content: content,
            semantics: content.semantics(activeWindow: 4),
            configuration: configuration,
            hiddenSeries: [],
            activeWindow: 4,
            title: "Line chart",
            summary: "Current value 12"
        )

        let descriptor = representable.makeChartDescriptor()
        XCTAssertEqual(descriptor.title, "Line chart")
        XCTAssertEqual(descriptor.summary, "Current value 12")
        XCTAssertEqual(descriptor.series.count, 1)
        XCTAssertTrue(descriptor.series[0].isContinuous)
        XCTAssertEqual(descriptor.series[0].dataPoints.count, 5)
        // Point labels and axis descriptions go through the chart's formatters.
        XCTAssertEqual(descriptor.series[0].dataPoints.first?.label, "T0")

        let xAxis = descriptor.xAxis as? AXNumericDataAxisDescriptor
        XCTAssertEqual(xAxis?.range, 0...4)
        XCTAssertEqual(xAxis?.valueDescriptionProvider(4), "T4")
        XCTAssertEqual(descriptor.yAxis?.range, 0...12)
        XCTAssertEqual(descriptor.yAxis?.valueDescriptionProvider(12), "12")

        // Updating in place must not leave the previous shape behind.
        var updated = representable
        updated.content = .series([
            LivelineSeries(
                id: "a",
                data: [LivelinePoint(time: 1, value: 5), LivelinePoint(time: 2, value: 6)],
                value: 6,
                color: .blue,
                label: "A"
            ),
            LivelineSeries(
                id: "b",
                data: [LivelinePoint(time: 1, value: 9), LivelinePoint(time: 2, value: 11)],
                value: 11,
                color: .red,
                label: "B"
            ),
        ])
        updated.title = "Multi-series chart"
        updated.updateChartDescriptor(descriptor)
        XCTAssertEqual(descriptor.title, "Multi-series chart")
        XCTAssertEqual(descriptor.series.map(\.name), ["A", "B"])
    }
    #endif

    // MARK: - Dynamic Type

    func testTextScaleIsExactlyOneAtStandardTypeSizes() {
        for size in [DynamicTypeSize.xSmall, .small, .medium, .large] {
            let scale = LivelineTextScale.resolve(size)
            XCTAssertTrue(scale.isStandard, "\(size) must not perturb deterministic rendering")
            XCTAssertEqual(scale.factor, 1)
            XCTAssertEqual(scale.font(11), Font.system(size: 11, weight: .regular, design: .default))
            XCTAssertEqual(scale.scaled(15), 15)
        }
    }

    func testTextScaleGrowsMonotonicallyAndStaysClamped() {
        let ordered = DynamicTypeSize.allCases.map { LivelineTextScale.resolve($0).factor }
        for (previous, next) in zip(ordered, ordered.dropFirst()) {
            XCTAssertGreaterThanOrEqual(next, previous)
        }

        XCTAssertGreaterThan(LivelineTextScale.resolve(.accessibility1).factor, 1)
        XCTAssertEqual(LivelineTextScale.resolve(.accessibility5).factor, LivelineTextScale.maximumFactor)
        // Out-of-band factors are clamped rather than trusted.
        XCTAssertEqual(LivelineTextScale(factor: 12).factor, LivelineTextScale.maximumFactor)
        XCTAssertEqual(LivelineTextScale(factor: 0.2).factor, 1)
        XCTAssertEqual(LivelineTextScale(factor: .nan).factor, 1)
    }

    @MainActor
    func testTextScaleChangeInvalidatesCachedTextMeasurements() {
        let state = LivelineRenderState()
        state.timeAxisLabels[1] = TimeAxisLabelState(alpha: 1, text: "T1", measuredWidth: 18)
        let measured = state.legendGutterWidth(labels: ["Revenue"], side: .trailing) { 40 }
        XCTAssertEqual(measured, 40)
        XCTAssertEqual(state.legendGutterMeasureCount, 1)

        // Same scale: the measurements stand.
        state.adoptTextScale(.standard)
        XCTAssertEqual(state.timeAxisLabels[1]?.measuredWidth, 18)
        _ = state.legendGutterWidth(labels: ["Revenue"], side: .trailing) { 40 }
        XCTAssertEqual(state.legendGutterMeasureCount, 1)

        // A Dynamic Type change makes every stored width a lie.
        state.adoptTextScale(LivelineTextScale.resolve(.accessibility3))
        XCTAssertNil(state.timeAxisLabels[1]?.measuredWidth)
        _ = state.legendGutterWidth(labels: ["Revenue"], side: .trailing) { 60 }
        XCTAssertEqual(state.legendGutterMeasureCount, 2)
    }
}
