import Foundation
import Liveline
import SwiftUI

/// Public-demo footage must show Liveline doing the motion. This view feeds
/// changing native data into every advanced chart instead of animating a
/// screenshot or the chart's surrounding card in post-production.
struct StorybookAdvancedLiveChart: View {
    let scenarioID: String

    @State private var startedAt = Date()

    static let scenarioIDs: Set<String> = [
        "violin-basic", "ridgeline-basic", "calendar-heatmap-basic", "gantt-basic",
        "bump-basic", "horizon-basic", "chord-basic", "parallel-basic", "hexbin-basic",
        "network-basic", "contour-basic", "ternary-basic", "marimekko-basic",
        "polar-area-basic", "waffle-basic", "volume-profile-basic", "renko-basic",
        "heikin-ashi-basic", "market-depth-basic", "ohlc-volume-basic", "point-figure-basic",
    ]

    static func supports(_ scenarioID: String) -> Bool {
        scenarioIDs.contains(scenarioID)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            chart(elapsed: max(0, timeline.date.timeIntervalSince(startedAt)))
        }
    }

    private func chart(elapsed: TimeInterval) -> AnyView {
        switch scenarioID {
        case "violin-basic":
            return AnyView(LivelineChart(
                violin: StorybookData.distributions.enumerated().map { index, series in
                    LivelineDistributionSeries(
                        id: series.id,
                        label: series.label,
                        values: series.values.enumerated().map { valueIndex, value in
                            value + sin(elapsed * 1.45 + Double(index) + Double(valueIndex) * 0.08) * 5
                        }
                    )
                },
                color: StorybookData.blue,
                style: LivelineViolinStyle(colors: StorybookData.segmentColors),
                configuration: configuration(window: 180, suffix: " ms")
            ))

        case "ridgeline-basic":
            return AnyView(LivelineChart(
                ridgeline: StorybookData.distributions.enumerated().map { index, series in
                    LivelineDistributionSeries(
                        id: series.id,
                        label: series.label,
                        values: series.values.enumerated().map { valueIndex, value in
                            value + sin(elapsed * 1.25 + Double(index) * 0.9 + Double(valueIndex) * 0.06) * 6
                        }
                    )
                },
                color: StorybookData.violet,
                style: LivelineRidgelineStyle(colors: StorybookData.segmentColors),
                configuration: configuration(window: 180, suffix: " ms")
            ))

        case "calendar-heatmap-basic":
            return AnyView(LivelineChart(
                calendarHeatmap: StorybookData.calendarActivity.enumerated().map { index, value in
                    LivelineCalendarValue(
                        date: value.date,
                        value: max(0, value.value * liveFactor(index, elapsed: elapsed)),
                        label: value.label
                    )
                },
                color: StorybookData.green,
                style: LivelineCalendarHeatmapStyle(colorScale: [StorybookData.teal, StorybookData.green]),
                configuration: configuration(window: 180, suffix: "")
            ))

        case "gantt-basic":
            return AnyView(LivelineChart(
                gantt: StorybookData.ganttTasks.enumerated().map { index, task in
                    LivelineGanttTask(
                        id: task.id,
                        label: task.label,
                        start: task.start,
                        end: task.end,
                        lane: task.lane,
                        progress: min(1, max(0, task.progress + sin(elapsed * 1.7 + Double(index)) * 0.18)),
                        dependencyIDs: task.dependencyIDs
                    )
                },
                color: StorybookData.blue,
                style: LivelineGanttStyle(colors: StorybookData.segmentColors),
                configuration: configuration(window: 220, suffix: "", padding: LivelinePadding(left: 68))
            ))

        case "bump-basic":
            return AnyView(LivelineChart(
                bump: StorybookData.bumpSeries.enumerated().map { seriesIndex, series in
                    LivelineRankSeries(
                        id: series.id,
                        label: series.label,
                        points: series.points.enumerated().map { pointIndex, point in
                            LivelineRankPoint(
                                time: point.time,
                                rank: point.rank + sin(elapsed * 1.35 + Double(seriesIndex) + Double(pointIndex) * 0.4) * 0.22
                            )
                        }
                    )
                },
                color: StorybookData.blue,
                style: LivelineBumpStyle(colors: StorybookData.segmentColors),
                configuration: configuration(window: 180, suffix: "")
            ))

        case "horizon-basic":
            return AnyView(LivelineChart(
                horizon: StorybookData.horizonPoints.enumerated().map { index, point in
                    LivelinePoint(
                        time: point.time,
                        value: point.value + sin(elapsed * 2 + Double(index) * 0.17) * 7
                    )
                },
                color: StorybookData.blue,
                style: LivelineHorizonStyle(bandCount: 3),
                configuration: configuration(window: 190, suffix: "%")
            ))

        case "chord-basic":
            return AnyView(LivelineChart(
                chord: StorybookData.chordLinks.enumerated().map { index, link in
                    LivelineChordLink(
                        source: link.source,
                        target: link.target,
                        value: link.value * liveFactor(index, elapsed: elapsed)
                    )
                },
                color: StorybookData.violet,
                style: LivelineChordStyle(colors: StorybookData.segmentColors),
                configuration: configuration(window: 180, suffix: "")
            ))

        case "parallel-basic":
            return AnyView(LivelineChart(
                parallelCoordinates: StorybookData.parallelRecords.enumerated().map { recordIndex, record in
                    LivelineParallelRecord(
                        id: record.id,
                        label: record.label,
                        values: record.values.enumerated().map { valueIndex, value in
                            value * liveFactor(recordIndex + valueIndex, elapsed: elapsed)
                        }
                    )
                },
                color: StorybookData.blue,
                style: LivelineParallelCoordinatesStyle(
                    axisLabels: ["Speed", "Cost", "Safety", "Scale", "DX"],
                    colors: StorybookData.segmentColors
                ),
                configuration: configuration(window: 180, suffix: "")
            ))

        case "hexbin-basic":
            return AnyView(LivelineChart(
                hexbin: StorybookData.hexbinPoints.enumerated().map { index, point in
                    LivelineXYPoint(
                        id: point.id,
                        x: point.x + sin(elapsed * 1.6 + Double(index) * 0.09) * 2.2,
                        y: point.y + cos(elapsed * 1.4 + Double(index) * 0.07) * 2.2,
                        weight: point.weight,
                        label: point.label
                    )
                },
                color: StorybookData.cyan,
                style: LivelineHexbinStyle(binsAcross: 20),
                configuration: configuration(window: 180, suffix: "")
            ))

        case "network-basic":
            return AnyView(LivelineChart(
                networkNodes: StorybookData.networkNodes.enumerated().map { index, node in
                    LivelineNetworkNode(
                        id: node.id,
                        label: node.label,
                        weight: node.weight * liveFactor(index, elapsed: elapsed),
                        group: node.group
                    )
                },
                edges: StorybookData.networkEdges.enumerated().map { index, edge in
                    LivelineNetworkEdge(
                        source: edge.source,
                        target: edge.target,
                        value: edge.value * liveFactor(index + 2, elapsed: elapsed)
                    )
                },
                color: StorybookData.blue,
                style: LivelineNetworkStyle(colors: StorybookData.segmentColors),
                configuration: configuration(window: 180, suffix: "")
            ))

        case "contour-basic":
            return AnyView(LivelineChart(
                contour: StorybookData.contourSamples.enumerated().map { index, sample in
                    LivelineContourSample(
                        id: sample.id,
                        x: sample.x,
                        y: sample.y,
                        value: sample.value * liveFactor(index, elapsed: elapsed)
                    )
                },
                color: StorybookData.cyan,
                style: LivelineContourStyle(
                    levelCount: 7,
                    colors: [StorybookData.blue, StorybookData.cyan, StorybookData.green]
                ),
                configuration: configuration(window: 180, suffix: "")
            ))

        case "ternary-basic":
            return AnyView(LivelineChart(
                ternary: StorybookData.ternaryPoints.enumerated().map { index, point in
                    LivelineTernaryPoint(
                        id: point.id,
                        label: point.label,
                        a: point.a * liveFactor(index, elapsed: elapsed),
                        b: point.b * liveFactor(index + 2, elapsed: elapsed),
                        c: point.c * liveFactor(index + 4, elapsed: elapsed),
                        magnitude: point.magnitude
                    )
                },
                color: StorybookData.blue,
                style: LivelineTernaryStyle(
                    axisLabels: ["Compute", "Storage", "Network"],
                    colors: StorybookData.segmentColors
                ),
                configuration: configuration(window: 180, suffix: "%")
            ))

        case "marimekko-basic":
            return AnyView(LivelineChart(
                marimekko: StorybookData.marimekkoColumns.enumerated().map { columnIndex, column in
                    LivelineMarimekkoColumn(
                        id: column.id,
                        label: column.label,
                        width: column.width * liveFactor(columnIndex, elapsed: elapsed),
                        segments: column.segments.enumerated().map { segmentIndex, segment in
                            LivelineCategoryValue(
                                id: segment.id,
                                label: segment.label,
                                value: segment.value * liveFactor(columnIndex + segmentIndex + 1, elapsed: elapsed)
                            )
                        }
                    )
                },
                color: StorybookData.blue,
                style: LivelineMarimekkoStyle(showsValues: true, colors: StorybookData.segmentColors),
                configuration: configuration(window: 180, suffix: "%")
            ))

        case "polar-area-basic":
            return AnyView(LivelineChart(
                polarArea: liveCategories(elapsed: elapsed),
                color: StorybookData.violet,
                style: LivelinePolarAreaStyle(colors: StorybookData.segmentColors),
                configuration: configuration(window: 180, suffix: "%")
            ))

        case "waffle-basic":
            return AnyView(LivelineChart(
                waffle: liveCategories(elapsed: elapsed),
                color: StorybookData.blue,
                style: LivelineWaffleStyle(colors: StorybookData.segmentColors),
                configuration: configuration(window: 180, suffix: "%")
            ))

        case "volume-profile-basic":
            return AnyView(LivelineChart(
                volumeProfile: StorybookData.volumeProfile.enumerated().map { index, level in
                    LivelinePriceVolume(
                        price: level.price,
                        volume: level.volume * liveFactor(index, elapsed: elapsed)
                    )
                },
                color: StorybookData.blue,
                style: LivelineVolumeProfileStyle(
                    showsValues: true,
                    pointOfControlColor: StorybookData.orange
                ),
                configuration: configuration(window: 180, suffix: "")
            ))

        case "renko-basic":
            return AnyView(LivelineChart(
                renko: livePricePoints(count: 180, elapsed: elapsed),
                color: StorybookData.green,
                style: LivelineRenkoStyle(brickSize: 0.8),
                configuration: configuration(window: 180, suffix: "")
            ))

        case "heikin-ashi-basic":
            return AnyView(LivelineChart(
                heikinAshi: StorybookData.candles(width: 15).committed.enumerated().map { index, candle in
                    liveCandle(candle, index: index, elapsed: elapsed)
                },
                color: StorybookData.green,
                configuration: configuration(window: 180, suffix: "")
            ))

        case "market-depth-basic":
            return AnyView(LivelineChart(
                marketDepth: StorybookData.marketDepth.enumerated().map { index, level in
                    LivelineOrderBookLevel(
                        price: level.price,
                        bidSize: level.bidSize * liveFactor(index, elapsed: elapsed),
                        askSize: level.askSize * liveFactor(index + 3, elapsed: elapsed)
                    )
                },
                configuration: configuration(window: 180, suffix: "")
            ))

        case "ohlc-volume-basic":
            return AnyView(LivelineChart(
                ohlcVolume: StorybookData.candleVolumes.enumerated().map { index, candle in
                    let shift = sin(elapsed * 1.5 + Double(index) * 0.22) * 0.55
                    return LivelineCandleVolume(
                        time: candle.time,
                        open: candle.open + shift,
                        high: candle.high + shift,
                        low: candle.low + shift,
                        close: candle.close + shift,
                        volume: candle.volume * liveFactor(index, elapsed: elapsed)
                    )
                },
                color: StorybookData.green,
                configuration: configuration(window: 180, suffix: "")
            ))

        case "point-figure-basic":
            return AnyView(LivelineChart(
                pointAndFigure: livePricePoints(count: 220, elapsed: elapsed),
                color: StorybookData.green,
                style: LivelinePointAndFigureStyle(boxSize: 0.65, reversalBoxes: 3),
                configuration: configuration(window: 220, suffix: "")
            ))

        default:
            return AnyView(EmptyView())
        }
    }

    private func configuration(
        window: TimeInterval,
        suffix: String,
        padding: LivelinePadding = LivelinePadding()
    ) -> LivelineChartConfiguration {
        StorybookData.staticSnapshotConfig(
            theme: .light,
            window: window,
            suffix: suffix,
            padding: padding
        )
    }

    private func liveFactor(_ index: Int, elapsed: TimeInterval) -> Double {
        0.86 + sin(elapsed * 1.7 + Double(index) * 0.61) * 0.14
    }

    private func liveCategories(elapsed: TimeInterval) -> [LivelineCategoryValue] {
        StorybookData.categories.enumerated().map { index, category in
            LivelineCategoryValue(
                id: category.id,
                label: category.label,
                value: category.value * liveFactor(index, elapsed: elapsed)
            )
        }
    }

    private func livePricePoints(count: Int, elapsed: TimeInterval) -> [LivelinePoint] {
        StorybookData.points(.normal, count: count).enumerated().map { index, point in
            LivelinePoint(
                time: point.time,
                value: point.value + sin(elapsed * 1.65 + Double(index) * 0.13) * 0.72
            )
        }
    }

    private func liveCandle(_ candle: LivelineCandle, index: Int, elapsed: TimeInterval) -> LivelineCandle {
        let shift = sin(elapsed * 1.5 + Double(index) * 0.22) * 0.55
        return LivelineCandle(
            time: candle.time,
            open: candle.open + shift,
            high: candle.high + shift,
            low: candle.low + shift,
            close: candle.close + shift
        )
    }
}
