import Foundation
import SwiftUI
import XCTest

@testable import Liveline

final class LivelineAdvancedChartTests: XCTestCase {
    /// The finance renderers used to round `reveal` itself rather than the mark
    /// count, which snapped every in-flight frame to the full series and made the
    /// reveal animation a no-op. Pin the monotonic ramp so that cannot return.
    func testRevealedCountRampsWithProgressRatherThanSnappingToTheFullSeries() {
        XCTAssertEqual(LivelineRenderer.revealedCount(10, reveal: 0), 0)
        XCTAssertEqual(LivelineRenderer.revealedCount(10, reveal: 0.05), 1)
        XCTAssertEqual(LivelineRenderer.revealedCount(10, reveal: 0.5), 5)
        XCTAssertEqual(LivelineRenderer.revealedCount(10, reveal: 0.91), 10)
        XCTAssertEqual(LivelineRenderer.revealedCount(10, reveal: 1), 10)

        XCTAssertEqual(LivelineRenderer.revealedCount(0, reveal: 1), 0)
        XCTAssertEqual(
            LivelineRenderer.revealedCount(10, reveal: 1.4), 10,
            "An overshooting spring must never index past the series.")
        XCTAssertEqual(LivelineRenderer.revealedCount(10, reveal: -0.2), 0)

        let counts = stride(from: 0.0, through: 1.0, by: 0.05).map {
            LivelineRenderer.revealedCount(24, reveal: $0)
        }
        XCTAssertEqual(counts, counts.sorted(), "Marks may only ever be added as the reveal advances.")
        XCTAssertGreaterThan(
            Set(counts).count, 2, "A reveal that only ever reports 0 or the total is not animating.")
    }

    func testDistributionStatisticsAreFiniteDeterministicAndRobust() throws {
        XCTAssertEqual(LivelineAdvancedMath.quantile([1, 2, 3, 4], probability: 0.25), 1.75)
        XCTAssertEqual(LivelineAdvancedMath.quantile([.nan, 8, .infinity], probability: 2), 8)
        XCTAssertEqual(LivelineAdvancedMath.quantile([], probability: 0.5), 0)

        let profile = try XCTUnwrap(
            LivelineAdvancedMath.densityProfile(
                values: [1, 2, 2, 3, .nan, .infinity],
                bandwidth: nil,
                sampleCount: 8
            )
        )
        XCTAssertEqual(profile.samples.count, 24, "Density sampling keeps a useful visual floor.")
        XCTAssertEqual(profile.minimum, 1)
        XCTAssertEqual(profile.median, 2)
        XCTAssertEqual(profile.maximum, 3)
        XCTAssertGreaterThan(profile.peakDensity, 0)
        XCTAssertTrue(
            profile.samples.allSatisfy { $0.value.isFinite && $0.density.isFinite && $0.density >= 0 })
        XCTAssertEqual(
            profile,
            LivelineAdvancedMath.densityProfile(values: [1, 2, 2, 3], bandwidth: nil, sampleCount: 8)
        )
    }

    func testFinanceTransformsFollowTheirPublishedRecurrences() {
        let points = [
            LivelinePoint(time: 0, value: 100),
            LivelinePoint(time: 1, value: 103),
            LivelinePoint(time: 2, value: 101),
        ]
        let bricks = LivelineAdvancedMath.renkoBricks(points: points, brickSize: 1)
        XCTAssertEqual(bricks.map(\.close), [101, 102, 103, 102, 101])
        XCTAssertEqual(bricks.map(\.isRising), [true, true, true, false, false])
        XCTAssertEqual(bricks, LivelineAdvancedMath.renkoBricks(points: points, brickSize: 1))

        let transformed = LivelineAdvancedMath.heikinAshiCandles([
            LivelineCandle(time: 0, open: 10, high: 14, low: 8, close: 12),
            LivelineCandle(time: 1, open: 12, high: 16, low: 10, close: 14),
        ])
        XCTAssertEqual(transformed.count, 2)
        XCTAssertEqual(transformed[0].open, 11)
        XCTAssertEqual(transformed[0].close, 11)
        XCTAssertEqual(transformed[0].high, 14)
        XCTAssertEqual(transformed[0].low, 8)
        XCTAssertEqual(transformed[1].open, 11)
        XCTAssertEqual(transformed[1].close, 13)
        XCTAssertEqual(transformed[1].high, 16)
        XCTAssertEqual(transformed[1].low, 10)

        let columns = LivelineAdvancedMath.pointFigureColumns(
            points: [100, 103, 99, 104].enumerated().map {
                LivelinePoint(time: Double($0.offset), value: $0.element)
            },
            boxSize: 1,
            reversalBoxes: 3
        )
        XCTAssertEqual(columns.count, 3)
        XCTAssertEqual(columns.map(\.isRising), [true, false, true])
        XCTAssertEqual(columns.map(\.low), [101, 99, 100])
        XCTAssertEqual(columns.map(\.high), [103, 102, 104])
        XCTAssertEqual(columns.map(\.boxCount), [3, 4, 5])
    }

    func testMarketDepthSortsAndAccumulatesEachSideFromTheInsideOut() {
        let curve = LivelineAdvancedMath.marketDepthCurve([
            LivelineOrderBookLevel(price: 99, bidSize: 2),
            LivelineOrderBookLevel(price: 102, askSize: 2),
            LivelineOrderBookLevel(price: 100, bidSize: 1),
            LivelineOrderBookLevel(price: 101, askSize: 1.5),
        ])

        XCTAssertEqual(curve.bestBid, 100)
        XCTAssertEqual(curve.bestAsk, 101)
        XCTAssertEqual(curve.bids.map(\.time), [99, 100])
        XCTAssertEqual(curve.bids.map(\.value), [3, 1])
        XCTAssertEqual(curve.asks.map(\.time), [101, 102])
        XCTAssertEqual(curve.asks.map(\.value), [1.5, 3.5])

        let content = LivelineAdvancedChartContent.marketDepth(
            [
                LivelineOrderBookLevel(price: 100, bidSize: 1),
                LivelineOrderBookLevel(price: 102, askSize: 1),
            ], .init())
        XCTAssertEqual(
            content.prepared(leftEdge: 0, rightEdge: 1, configuration: .init()).primaryValue,
            101
        )
    }

    func testPublicModelsNormalizeUnsafeInputAndStylesStayWithinRenderableBounds() {
        XCTAssertEqual(
            LivelineDistributionSeries(id: "d", label: "D", values: [1, .nan, 2]).values, [1, 2])
        XCTAssertEqual(LivelineXYPoint(id: "p", x: .nan, y: .infinity, weight: -4).x, 0)
        XCTAssertEqual(LivelineXYPoint(id: "p", x: .nan, y: .infinity, weight: -4).y, 0)
        XCTAssertEqual(LivelineXYPoint(id: "p", x: .nan, y: .infinity, weight: -4).weight, 0)
        XCTAssertEqual(LivelineTernaryPoint(id: "t", label: "T", a: -1, b: .nan, c: 2).total, 2)
        XCTAssertEqual(LivelineOrderBookLevel(price: .nan, bidSize: -1, askSize: .infinity).price, 0)
        let task = LivelineGanttTask(
            id: "g", label: "G", start: .nan, end: 4, lane: -2, progress: .infinity)
        XCTAssertEqual(task.start, 0)
        XCTAssertEqual(task.end, 4)
        XCTAssertEqual(task.lane, 0)
        XCTAssertEqual(task.progress, 0)
        XCTAssertEqual(
            LivelineRankPoint(time: .infinity, rank: .nan), LivelineRankPoint(time: 0, rank: 0))

        let interval = LivelineCandleVolume(
            time: .nan,
            open: .nan,
            high: .infinity,
            low: -2,
            close: 3,
            volume: -.infinity
        )
        XCTAssertEqual(interval.time, 0)
        XCTAssertEqual(interval.open, 0)
        XCTAssertEqual(interval.high, 3)
        XCTAssertEqual(interval.low, -2)
        XCTAssertEqual(interval.close, 3)
        XCTAssertEqual(interval.volume, 0)

        XCTAssertEqual(LivelineHorizonStyle(bandCount: 100).resolvedBandCount, 6)
        XCTAssertEqual(LivelineHexbinStyle(binsAcross: 1).resolvedBinsAcross, 4)
        XCTAssertEqual(LivelineContourStyle(levelCount: 100).resolvedLevelCount, 16)
        XCTAssertEqual(LivelineWaffleStyle(columns: 0, rows: 100).resolvedColumns, 1)
        XCTAssertEqual(LivelineWaffleStyle(columns: 0, rows: 100).resolvedRows, 40)
        XCTAssertEqual(
            LivelinePointAndFigureStyle(boxSize: .nan, reversalBoxes: 100).resolvedBoxSize, 1)
        XCTAssertEqual(
            LivelinePointAndFigureStyle(boxSize: .nan, reversalBoxes: 100).resolvedReversalBoxes, 10)

        XCTAssertTrue(
            LivelineAdvancedChartContent.horizon([LivelinePoint(time: 0, value: 1)], .init()).isEmpty)
        XCTAssertTrue(
            LivelineAdvancedChartContent.contour(
                [
                    .init(id: "0", x: 0, y: 0, value: 0),
                    .init(id: "1", x: 0, y: 1, value: 1),
                    .init(id: "2", x: 0, y: 2, value: 2),
                    .init(id: "3", x: 0, y: 3, value: 3),
                ], .init()
            ).isEmpty)
    }

    /// Renko bricks, Heikin-Ashi candles, and point-and-figure columns are derived
    /// once, in the series type, and read by range preparation, drawing, hit
    /// testing, VoiceOver, and the audio graph. Pin that they all describe the
    /// same shapes — a reader that re-derives with its own parameters would drift
    /// silently, which is exactly what owning the derivation is meant to prevent.
    func testDerivedFinanceSeriesAreComputedOnceAndAgreeAcrossEveryReader() throws {
        let prices = [100.0, 103, 99, 104, 101].enumerated().map {
            LivelinePoint(time: Double($0.offset), value: $0.element)
        }
        let renkoStyle = LivelineRenkoStyle(brickSize: 1)
        let figureStyle = LivelinePointAndFigureStyle(boxSize: 1, reversalBoxes: 3)
        let candles = [
            LivelineCandle(time: 0, open: 10, high: 14, low: 8, close: 12),
            LivelineCandle(time: 1, open: 12, high: 16, low: 10, close: 14),
        ]

        let renko = LivelineRenkoSeries(points: prices, style: renkoStyle)
        let heikin = LivelineHeikinAshiSeries(source: candles)
        let figure = LivelinePointFigureSeries(points: prices, style: figureStyle)

        // The stored derivation matches the published transform exactly.
        XCTAssertEqual(
            renko.bricks,
            LivelineAdvancedMath.renkoBricks(
                points: prices, brickSize: renkoStyle.resolvedBrickSize))
        XCTAssertEqual(heikin.candles, LivelineAdvancedMath.heikinAshiCandles(candles))
        XCTAssertEqual(
            figure.columns,
            LivelineAdvancedMath.pointFigureColumns(
                points: prices,
                boxSize: figureStyle.resolvedBoxSize,
                reversalBoxes: figureStyle.resolvedReversalBoxes))
        XCTAssertFalse(renko.bricks.isEmpty)
        XCTAssertFalse(figure.columns.isEmpty)

        let cases: [(String, LivelineAdvancedChartContent, Int)] = [
            ("Renko", .renko(renko, renkoStyle), renko.bricks.count),
            ("Heikin-Ashi", .heikinAshi(heikin, LivelineHeikinAshiStyle()), heikin.candles.count),
            ("Point and figure", .pointAndFigure(figure, figureStyle), figure.columns.count),
        ]
        let configuration = LivelineChartConfiguration()
        for (name, content, derivedCount) in cases {
            XCTAssertEqual(
                content.accessibilityEntryCount, derivedCount,
                "\(name) VoiceOver count disagrees with the derived shapes")
            XCTAssertEqual(
                content.accessibilityEntries(
                    formatValue: configuration.formatValue, formatTime: configuration.formatTime
                ).count,
                derivedCount,
                "\(name) VoiceOver entries disagree with the derived shapes")

            let targets = LivelineAdvancedInteractionBuilder.targets(
                content: content,
                layout: LivelineLayout(
                    size: CGSize(width: 360, height: 240),
                    padding: LivelineResolvedPadding(top: 20, right: 20, bottom: 20, left: 20),
                    minValue: 90,
                    maxValue: 110,
                    leftEdge: 0,
                    rightEdge: 5
                ),
                palette: LivelinePalette.resolve(accent: .blue, mode: .dark, lineWidth: 2),
                configuration: configuration,
                targetLocation: nil,
                textScale: .standard
            )
            XCTAssertEqual(
                targets.count, derivedCount,
                "\(name) has a hover target per derived shape")

            // Normalization is a fixed point: the series already derived on init.
            guard case .advanced(let renormalized) = LivelineChartContent.advanced(content).normalized()
            else { return XCTFail("\(name) lost its advanced content through normalization") }
            XCTAssertEqual(
                renormalized.accessibilityEntryCount, derivedCount,
                "\(name) re-derived something different when normalized again")
        }
    }

    func testEveryAdvancedChartProvidesInspectableAccessibilityAndAudioGraphData() {
        let configuration = LivelineChartConfiguration(
            formatValue: { String(format: "%.1f", $0) },
            formatTime: { "T\(Int($0))" }
        )

        for fixture in Self.fixtures {
            let content = LivelineChartContent.advanced(fixture.content)
            let model = LivelineChartAccessibilityModel.make(
                content: content,
                semantics: content.semantics(),
                configuration: configuration,
                hiddenSeries: []
            )
            XCTAssertGreaterThan(
                model.entryCount, 0, "\(fixture.name) has no inspectable accessibility entries")
            XCTAssertFalse(model.label.isEmpty, "\(fixture.name) has no accessibility chart label")
            XCTAssertFalse(model.value(at: 0).isEmpty, "\(fixture.name) has no first accessibility value")

            let audio = LivelineAdvancedAudioGraph.make(content: fixture.content, visibleRange: nil)
            XCTAssertFalse(audio.series.isEmpty, "\(fixture.name) has no Audio Graph series")
            XCTAssertTrue(
                audio.series.contains { !$0.points.isEmpty },
                "\(fixture.name) has no sonifiable Audio Graph samples"
            )
        }
    }

    func testDerivedOrdinalFinanceChartsDoNotMisrepresentColumnsAsTime() {
        let renko = LivelineChartContent.advanced(Self.fixture(named: "Renko"))
        let pointAndFigure = LivelineChartContent.advanced(Self.fixture(named: "Point and figure"))
        let horizon = LivelineChartContent.advanced(Self.fixture(named: "Horizon"))
        XCTAssertFalse(renko.semantics().capabilities.usesTimeAxis)
        XCTAssertFalse(pointAndFigure.semantics().capabilities.usesTimeAxis)
        XCTAssertTrue(renko.semantics().capabilities.usesValueAxis)
        XCTAssertTrue(pointAndFigure.semantics().capabilities.usesValueAxis)
        XCTAssertTrue(horizon.semantics().capabilities.usesTimeAxis)
        XCTAssertFalse(horizon.semantics().capabilities.usesValueAxis)
    }

    func testAdvancedInteractionTargetsShareAccessibilityScaleGeometryWithRendering() throws {
        let layout = LivelineLayout(
            size: CGSize(width: 360, height: 240),
            padding: LivelineResolvedPadding(top: 20, right: 20, bottom: 20, left: 20),
            minValue: 0,
            maxValue: 20,
            leftEdge: 0,
            rightEdge: 10
        )
        let palette = LivelinePalette.resolve(accent: .blue, mode: .dark, lineWidth: 2)
        let scale = LivelineTextScale(factor: LivelineTextScale.maximumFactor)
        let style = LivelineTernaryStyle(axisLabels: ["Compute", "Storage", "Network"])
        let point = LivelineTernaryPoint(id: "balanced", label: "Balanced", a: 2, b: 3, c: 5)
        let geometry = LivelineAdvancedLayout.ternary(style: style, layout: layout, textScale: scale)
        let expected = geometry.point(point)
        let target = try XCTUnwrap(
            LivelineAdvancedInteractionBuilder.targets(
                content: .ternary([point], style),
                layout: layout,
                palette: palette,
                configuration: .init(),
                targetLocation: nil,
                textScale: scale
            ).first)

        XCTAssertEqual(target.selection.anchor.x, expected.x, accuracy: 0.001)
        XCTAssertEqual(target.selection.anchor.y, expected.y, accuracy: 0.001)

        let ohlcStyle = LivelineOHLCVolumeStyle(volumeHeightRatio: 0.3, paneSpacing: 8)
        let ohlc = [
            LivelineCandleVolume(time: 2, open: 8, high: 14, low: 4, close: 10, volume: 40),
            LivelineCandleVolume(time: 7, open: 10, high: 18, low: 6, close: 16, volume: 70),
        ]
        let ohlcTarget = try XCTUnwrap(
            LivelineAdvancedInteractionBuilder.targets(
                content: .ohlcVolume(ohlc, ohlcStyle),
                layout: layout,
                palette: palette,
                configuration: .init(),
                targetLocation: nil,
                textScale: scale
            ).last)
        let plot = LivelineRenderer.advancedPlotRect(layout)
        let priceHeight =
            plot.height - plot.height * ohlcStyle.resolvedVolumeHeightRatio
            - ohlcStyle.resolvedPaneSpacing
        let expectedY = LivelineRenderer.mapped(
            16, from: 4...18, to: (plot.minY + priceHeight, plot.minY))
        XCTAssertEqual(ohlcTarget.selection.anchor.y, expectedY, accuracy: 0.001)
    }

    /// A `Dictionary(uniqueKeysWithValues:)` over user-supplied identifiers traps
    /// on a repeat. Every advanced chart that keys data by an identifier the
    /// caller controls has to survive duplicates instead.
    func testAdvancedLayoutsToleratesDuplicateCallerSuppliedIdentifiers() throws {
        let layout = LivelineLayout(
            size: CGSize(width: 360, height: 240),
            padding: LivelineResolvedPadding(top: 20, right: 20, bottom: 20, left: 20),
            minValue: 0,
            maxValue: 20,
            leftEdge: 0,
            rightEdge: 10
        )
        let scale = LivelineTextScale.standard

        let day = Date(timeIntervalSince1970: 1_700_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let sameDay = [
            LivelineCalendarValue(date: day, value: 3),
            LivelineCalendarValue(date: day.addingTimeInterval(3600), value: 9),
        ]
        let byDay = LivelineAdvancedLayout.calendarValuesByDay(sameDay, calendar: calendar)
        XCTAssertEqual(byDay.count, 1, "Two readings on one civil day share a single cell.")
        XCTAssertEqual(byDay[calendar.startOfDay(for: day)]?.value, 9, "The later reading wins.")

        let repeatedTasks = [
            LivelineGanttTask(id: "build", label: "Build", start: 0, end: 4, lane: 0),
            LivelineGanttTask(id: "build", label: "Rebuild", start: 5, end: 9, lane: 1),
        ]
        let tasksByID = LivelineAdvancedLayout.ganttTasksByID(repeatedTasks)
        XCTAssertEqual(tasksByID.count, 1)
        XCTAssertEqual(tasksByID["build"]?.label, "Build")

        let repeatedNodes = [
            LivelineNetworkNode(id: "core", label: "Core", weight: 4),
            LivelineNetworkNode(id: "core", label: "Core copy", weight: 2),
            LivelineNetworkNode(id: "edge", label: "Edge", weight: 1),
        ]
        let network = try XCTUnwrap(
            LivelineAdvancedLayout.network(
                nodes: repeatedNodes,
                edges: [LivelineNetworkEdge(source: "core", target: "edge", value: 1)],
                style: LivelineNetworkStyle(),
                layout: layout,
                textScale: scale
            ))
        XCTAssertEqual(network.placements.count, 3, "Every node is still drawn and hoverable.")
        XCTAssertEqual(network.positionsByID.count, 2, "An edge resolves to one endpoint per id.")
        XCTAssertEqual(network.placements[0].connections, 1)
        XCTAssertEqual(network.placements[2].connections, 1)
    }

    /// The chart draws one hexagon per bin, so the hover targets have to describe
    /// bins as well — one target per raw point would leave hit regions scattered
    /// away from the marks and report a single sample instead of the bin total.
    func testHexbinTargetsDescribeDrawnBinsRatherThanRawPoints() throws {
        let layout = LivelineLayout(
            size: CGSize(width: 360, height: 240),
            padding: LivelineResolvedPadding(top: 20, right: 20, bottom: 20, left: 20),
            minValue: 0,
            maxValue: 20,
            leftEdge: 0,
            rightEdge: 10
        )
        let style = LivelineHexbinStyle(binsAcross: 4)
        let points = (0..<24).map {
            LivelineXYPoint(id: "p\($0)", x: Double($0 % 3), y: Double($0 % 2), weight: 2)
        }
        let geometry = try XCTUnwrap(
            LivelineAdvancedLayout.hexbin(
                points: points, style: style, layout: layout, textScale: .standard))
        XCTAssertLessThan(geometry.cells.count, points.count, "Points aggregate into bins.")
        XCTAssertEqual(geometry.cells.map(\.count).reduce(0, +), points.count)
        XCTAssertEqual(
            geometry.cells.map { ($0.column, $0.row) }.map { [$0.0, $0.1] },
            geometry.cells.map { ($0.column, $0.row) }.sorted { $0 < $1 }.map { [$0.0, $0.1] },
            "Bin order is stable so identical input renders identically."
        )

        let targets = LivelineAdvancedInteractionBuilder.targets(
            content: .hexbin(points, style),
            layout: layout,
            palette: LivelinePalette.resolve(accent: .blue, mode: .dark, lineWidth: 2),
            configuration: .init(),
            targetLocation: nil,
            textScale: .standard
        )
        XCTAssertEqual(targets.count, geometry.cells.count)
        for (target, cell) in zip(targets, geometry.cells) {
            XCTAssertEqual(target.selection.anchor.x, cell.center.x, accuracy: 0.001)
            XCTAssertEqual(target.selection.anchor.y, cell.center.y, accuracy: 0.001)
        }
    }

    /// A series with no finite observations produces no density profile and so is
    /// never drawn. Hit testing has to index the drawn profiles, not the caller's
    /// array, or every remaining violin's region slides one slot out of place.
    func testViolinTargetsFollowDrawnProfilesWhenASeriesHasNoFiniteValues() throws {
        let layout = LivelineLayout(
            size: CGSize(width: 360, height: 240),
            padding: LivelineResolvedPadding(top: 20, right: 20, bottom: 20, left: 20),
            minValue: 0,
            maxValue: 20,
            leftEdge: 0,
            rightEdge: 10
        )
        let style = LivelineViolinStyle()
        let series = [
            LivelineDistributionSeries(id: "empty", label: "Empty", values: []),
            LivelineDistributionSeries(id: "real", label: "Real", values: [1, 2, 3, 4]),
        ]
        let geometry = LivelineAdvancedLayout.violin(
            series: series, style: style, layout: layout, textScale: .standard)
        XCTAssertEqual(geometry.profiles.count, 1)
        XCTAssertEqual(geometry.profiles[0].series.id, "real")

        let targets = LivelineAdvancedInteractionBuilder.targets(
            content: .violin(series, style),
            layout: layout,
            palette: LivelinePalette.resolve(accent: .blue, mode: .dark, lineWidth: 2),
            configuration: .init(),
            targetLocation: nil,
            textScale: .standard
        )
        let target = try XCTUnwrap(targets.first)
        XCTAssertEqual(targets.count, 1)
        XCTAssertEqual(
            target.selection.anchor.x, geometry.centerX(at: 0), accuracy: 0.001,
            "The region sits on the violin that is actually painted."
        )
        XCTAssertEqual(target.selection.heading, "Real")
    }

    func testMarimekkoDefaultGuttersAreUniformAndPixelAligned() {
        let style = LivelineMarimekkoStyle()
        XCTAssertEqual(style.resolvedColumnSpacing, 1)
        XCTAssertEqual(style.resolvedSegmentSpacing, 1)

        let columns = [
            LivelineMarimekkoColumn(
                id: "a", label: "A", width: 3,
                segments: [
                    .init(id: "one", label: "One", value: 2),
                    .init(id: "two", label: "Two", value: 1),
                ]),
            LivelineMarimekkoColumn(
                id: "b", label: "B", width: 2,
                segments: [
                    .init(id: "one", label: "One", value: 1),
                    .init(id: "two", label: "Two", value: 1),
                ]),
        ]
        let raw = LivelineVisualGeometry.marimekko(
            columns: columns,
            in: CGRect(x: 0.1, y: 0.2, width: 101, height: 103),
            columnSpacing: style.resolvedColumnSpacing,
            segmentSpacing: style.resolvedSegmentSpacing
        )
        let geometry = LivelineVisualGeometry.pixelAligned(raw, displayScale: 3)

        let columnGap = geometry[1].rect.minX - geometry[0].rect.maxX
        let segmentGap = geometry[0].segments[0].rect.minY - geometry[0].segments[1].rect.maxY
        XCTAssertEqual(columnGap, 1, accuracy: 0.000_1)
        XCTAssertEqual(segmentGap, columnGap, accuracy: 0.000_1)

        for rect in geometry.flatMap({ column in
            [column.rect] + column.segments.map(\.rect)
        }) {
            for edge in [rect.minX, rect.minY, rect.maxX, rect.maxY] {
                XCTAssertEqual(edge * 3, (edge * 3).rounded(), accuracy: 0.000_1)
            }
        }
    }

    func testMarimekkoGeometryBudgetsOnlyInternalGapsAndPreservesProportions() throws {
        let columns = [
            LivelineMarimekkoColumn(
                id: "a", label: "A", width: 46,
                segments: [
                    .init(id: "one", label: "One", value: 62),
                    .init(id: "two", label: "Two", value: 28),
                    .init(id: "three", label: "Three", value: 10),
                ]),
            LivelineMarimekkoColumn(
                id: "b", label: "B", width: 32,
                segments: [
                    .init(id: "one", label: "One", value: 45),
                    .init(id: "two", label: "Two", value: 55),
                ]),
            LivelineMarimekkoColumn(
                id: "c", label: "C", width: 22,
                segments: [.init(id: "one", label: "One", value: 100)]),
        ]
        let body = CGRect(x: 10, y: 20, width: 500, height: 240)
        let geometry = LivelineVisualGeometry.marimekko(
            columns: columns,
            in: body,
            columnSpacing: 3,
            segmentSpacing: 2
        )

        XCTAssertEqual(geometry.count, 3)
        XCTAssertEqual(geometry[0].rect.minX, body.minX, accuracy: 0.000_1)
        XCTAssertEqual(geometry[2].rect.maxX, body.maxX, accuracy: 0.000_1)
        XCTAssertEqual(geometry[1].rect.minX - geometry[0].rect.maxX, 3, accuracy: 0.000_1)
        XCTAssertEqual(geometry[2].rect.minX - geometry[1].rect.maxX, 3, accuracy: 0.000_1)
        XCTAssertEqual(
            geometry[0].rect.width / geometry[1].rect.width,
            CGFloat(46) / 32,
            accuracy: 0.000_1)
        XCTAssertEqual(
            geometry[1].rect.width / geometry[2].rect.width,
            CGFloat(32) / 22,
            accuracy: 0.000_1)

        let firstSegments = geometry[0].segments
        XCTAssertEqual(firstSegments[0].rect.maxY, body.maxY, accuracy: 0.000_1)
        XCTAssertEqual(firstSegments[2].rect.minY, body.minY, accuracy: 0.000_1)
        XCTAssertEqual(firstSegments[0].rect.minY - firstSegments[1].rect.maxY, 2, accuracy: 0.000_1)
        XCTAssertEqual(firstSegments[1].rect.minY - firstSegments[2].rect.maxY, 2, accuracy: 0.000_1)

        let layout = LivelineLayout(
            size: CGSize(width: 540, height: 280),
            padding: LivelineResolvedPadding(top: 20, right: 20, bottom: 20, left: 20),
            minValue: 0,
            maxValue: 100,
            leftEdge: 0,
            rightEdge: 1
        )
        let style = LivelineMarimekkoStyle(columnSpacing: 3, segmentSpacing: 2)
        let palette = LivelinePalette.resolve(accent: .blue, mode: .light, lineWidth: 2)
        let targets = LivelineAdvancedInteractionBuilder.targets(
            content: .marimekko(columns, style),
            layout: layout,
            palette: palette,
            configuration: .init(),
            targetLocation: nil,
            textScale: .init(factor: 1)
        )
        XCTAssertEqual(targets.count, 6)
        XCTAssertEqual(targets[0].selection.anchor.x, targets[1].selection.anchor.x, accuracy: 0.000_1)
        XCTAssertEqual(targets[3].selection.anchor.x, targets[4].selection.anchor.x, accuracy: 0.000_1)
        XCTAssertLessThan(targets[0].selection.anchor.x, targets[3].selection.anchor.x)
        XCTAssertLessThan(targets[3].selection.anchor.x, targets[5].selection.anchor.x)
    }

    func testContourGeometryIsDenseStitchedAndSafeForDuplicateCoordinates() {
        var samples = (0..<9).flatMap { y in
            (0..<9).map { x in
                let dx = Double(x) - 4
                let dy = Double(y) - 4
                return LivelineContourSample(
                    id: "\(x)-\(y)",
                    x: Double(x),
                    y: Double(y),
                    value: exp(-(dx * dx + dy * dy) / 5) * 100
                )
            }
        }
        samples.append(.init(id: "duplicate", x: 4, y: 4, value: 98))
        let geometry = LivelineVisualGeometry.contour(
            samples: samples,
            levelCount: 6,
            plot: CGRect(x: 10, y: 20, width: 320, height: 240),
            subdivisions: 8
        )

        XCTAssertEqual(geometry.fillCells.count, 64 * 64)
        XCTAssertTrue(geometry.fillCells.allSatisfy { $0.rect.width > 0 && $0.rect.height > 0 })
        XCTAssertEqual(Set(geometry.lines.map(\.level)), Set(1..<6))
        XCTAssertTrue(geometry.lines.allSatisfy { $0.points.count > 8 })
        XCTAssertTrue(geometry.lines.allSatisfy(\.isClosed))
        XCTAssertTrue(
            geometry.lines.flatMap(\.points).allSatisfy {
                $0.x.isFinite && $0.y.isFinite
                    && $0.x >= 10 && $0.x <= 330
                    && $0.y >= 20 && $0.y <= 260
            })
    }

    func testContourGeometryCacheTracksDataStyleAndPlotChanges() {
        let samples = (0..<3).flatMap { y in
            (0..<3).map { x in
                LivelineContourSample(
                    id: "\(x)-\(y)",
                    x: Double(x),
                    y: Double(y),
                    value: Double(x * x + y)
                )
            }
        }
        let state = LivelineRenderState()
        let plot = CGRect(x: 10, y: 20, width: 240, height: 160)

        _ = state.contourGeometry(
            samples: samples, levelCount: 6, plot: plot, subdivisions: 8)
        _ = state.contourGeometry(
            samples: samples, levelCount: 6, plot: plot, subdivisions: 8)
        XCTAssertEqual(state.contourGeometryBuildCount, 1)

        var changed = samples
        changed[4].value += 0.25
        _ = state.contourGeometry(
            samples: changed, levelCount: 6, plot: plot, subdivisions: 8)
        XCTAssertEqual(state.contourGeometryBuildCount, 2)

        _ = state.contourGeometry(
            samples: changed,
            levelCount: 7,
            plot: plot.insetBy(dx: 1, dy: 1),
            subdivisions: 8
        )
        XCTAssertEqual(state.contourGeometryBuildCount, 3)
    }

    func testDirectLabelDistributionPreservesSpacingAndValueAxisSkipsLegendGutter() {
        let positions = LivelineVisualGeometry.distributedLabelPositions(
            [95, 95, 95],
            minimum: 0,
            maximum: 100,
            spacing: 20
        )
        XCTAssertEqual(positions, [60, 80, 100])

        let mixed = LivelineVisualGeometry.distributedLabelPositions(
            [90, 10, 12],
            minimum: 0,
            maximum: 100,
            spacing: 20
        )
        XCTAssertEqual(mixed[0], 90, accuracy: 0.000_1)
        XCTAssertEqual(mixed[1], 10, accuracy: 0.000_1)
        XCTAssertEqual(mixed[2], 30, accuracy: 0.000_1)

        let ltr = LivelineLayout(
            size: CGSize(width: 300, height: 200),
            padding: .init(top: 10, right: 50, bottom: 20, left: 10),
            minValue: 0,
            maxValue: 1,
            leftEdge: 0,
            rightEdge: 1,
            dataRightReserve: 32
        )
        XCTAssertEqual(ltr.valueAxisLabelX(offset: 6), 256, accuracy: 0.000_1)

        let rtl = LivelineLayout(
            size: CGSize(width: 300, height: 200),
            padding: .init(top: 10, right: 10, bottom: 20, left: 50),
            minValue: 0,
            maxValue: 1,
            leftEdge: 0,
            rightEdge: 1,
            dataLeftReserve: 32,
            isRTL: true
        )
        XCTAssertEqual(rtl.valueAxisLabelX(offset: 6), 44, accuracy: 0.000_1)
    }

    func testDenseAdvancedLayoutsKeepPositiveGeometryAndBoundSymbolWork() throws {
        let layout = LivelineLayout(
            size: CGSize(width: 120, height: 90),
            padding: .init(top: 5, right: 5, bottom: 5, left: 5),
            minValue: 0, maxValue: 100, leftEdge: 0, rightEdge: 10)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))
        let days = (0..<365).map { offset in
            LivelineCalendarValue(
                date: calendar.date(byAdding: .day, value: offset, to: start)!, value: Double(offset + 1))
        }
        let calendarGeometry = try XCTUnwrap(
            LivelineAdvancedLayout.calendar(
                values: days,
                style: .init(calendar: calendar, cellSpacing: 8),
                layout: layout,
                textScale: .standard))
        XCTAssertGreaterThan(calendarGeometry.cell, 0)

        let waffle = LivelineAdvancedLayout.waffle(
            values: [.init(id: "all", label: "All", value: 1)],
            style: .init(columns: 40, rows: 40, spacing: 10, showsLegend: false),
            layout: layout,
            textScale: .standard)
        XCTAssertGreaterThan(waffle.cell, 0)

        let tasks = (0..<20).map {
            LivelineGanttTask(id: "\($0)", label: "Task", start: 0, end: 10, lane: $0)
        }
        let gantt = LivelineAdvancedLayout.gantt(
            tasks: tasks, style: .init(rowSpacing: 20), layout: layout, textScale: .standard)
        XCTAssertLessThan(gantt.rowSpacing, gantt.slot)
        XCTAssertGreaterThan(gantt.rect(for: tasks.last!, layout: layout).height, 0)

        let levels = (0..<80).map { LivelinePriceVolume(price: Double($0), volume: 1) }
        let volume = LivelineAdvancedLayout.volumeProfile(
            levels: levels, style: .init(barSpacing: 12), layout: layout, textScale: .standard)
        XCTAssertLessThan(volume.barSpacing, volume.slot)
        XCTAssertGreaterThan(volume.rect(at: 0).height, 0)

        let column = LivelinePointFigureColumn(
            index: 0, isRising: true, low: 0, high: 100, boxSize: 0.000_001)
        let figure = LivelineAdvancedLayout.pointAndFigure(
            columns: [column], style: .init(boxSize: 0.000_001, columnSpacing: 20),
            layout: layout, textScale: .standard)
        XCTAssertGreaterThan(figure.box, 0)
        XCTAssertLessThanOrEqual(figure.symbolIndices(for: column).count, 2_048)
    }

    func testChordGeometryPartitionsLinksAndHandlesLargeGapsAndSelfLinks() {
        let layout = LivelineLayout(
            size: CGSize(width: 320, height: 240),
            padding: .init(top: 10, right: 10, bottom: 10, left: 10),
            minValue: 0, maxValue: 10, leftEdge: 0, rightEdge: 1)
        let links = [
            LivelineChordLink(source: "A", target: "A", value: 2),
            LivelineChordLink(source: "A", target: "B", value: 3),
            LivelineChordLink(source: "A", target: "C", value: 1),
        ]
        let geometry = LivelineAdvancedLayout.chord(
            links: links, style: .init(gapDegrees: 12), layout: layout, textScale: .standard)
        XCTAssertEqual(geometry.arcs.map(\.label), ["A", "B", "C"])
        XCTAssertEqual(geometry.ribbons.count, links.count)
        let aEndpoints = geometry.ribbons.flatMap { ribbon -> [ClosedRange<Double>] in
            var result: [ClosedRange<Double>] = []
            if ribbon.link.source == "A" { result.append(ribbon.sourceStart...ribbon.sourceEnd) }
            if ribbon.link.target == "A" { result.append(ribbon.targetStart...ribbon.targetEnd) }
            return result
        }.sorted { $0.lowerBound < $1.lowerBound }
        for pair in zip(aEndpoints, aEndpoints.dropFirst()) {
            XCTAssertLessThanOrEqual(pair.0.upperBound, pair.1.lowerBound + 0.000_001)
        }
        let first = geometry.arcs.first!.start
        let last = geometry.arcs.last!.end
        XCTAssertLessThanOrEqual(last - first, 2 * Double.pi + 0.000_001)
    }

    func testAggregatedMarksProduceOneMatchingHoverTarget() throws {
        let layout = LivelineLayout(
            size: CGSize(width: 320, height: 240),
            padding: .init(top: 20, right: 20, bottom: 20, left: 20),
            minValue: 0, maxValue: 20, leftEdge: 0, rightEdge: 10)
        let palette = LivelinePalette.resolve(accent: .blue, mode: .light, lineWidth: 2)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let calendarTargets = LivelineAdvancedInteractionBuilder.targets(
            content: .calendarHeatmap([
                .init(date: day, value: 2),
                .init(date: day.addingTimeInterval(3_600), value: 8),
            ], .init(calendar: calendar)),
            layout: layout, palette: palette, configuration: .init(),
            targetLocation: nil, textScale: .standard)
        XCTAssertEqual(calendarTargets.count, 1)
        XCTAssertEqual(calendarTargets[0].selection.hover.value, 8)

        let contour = [
            LivelineContourSample(id: "a", x: 0, y: 0, value: 2),
            LivelineContourSample(id: "b", x: 0, y: 0, value: 6),
            LivelineContourSample(id: "c", x: 1, y: 0, value: 1),
            LivelineContourSample(id: "d", x: 0, y: 1, value: 2),
            LivelineContourSample(id: "e", x: 1, y: 1, value: 3),
        ]
        let contourTargets = LivelineAdvancedInteractionBuilder.targets(
            content: .contour(contour, .init()), layout: layout, palette: palette,
            configuration: .init(), targetLocation: nil, textScale: .standard)
        XCTAssertEqual(contourTargets.count, 4)
        XCTAssertEqual(contourTargets.first { $0.selection.hover.time == 0 }?.selection.hover.value, 4)
    }

    func testPolarAreaBoundsGapsAndPreservesAnnularAreaRatios() {
        let layout = LivelineLayout(
            size: CGSize(width: 320, height: 240),
            padding: .init(top: 10, right: 10, bottom: 10, left: 10),
            minValue: 0, maxValue: 10, leftEdge: 0, rightEdge: 1)
        let crowded = (0..<25).map {
            LivelineCategoryValue(id: "\($0)", label: "\($0)", value: 1)
        }
        let crowdedGeometry = LivelineAdvancedLayout.polarArea(
            values: crowded, style: .init(gapDegrees: 15), layout: layout, textScale: .standard)
        XCTAssertTrue(crowdedGeometry.wedges.allSatisfy { $0.sweep > 0 })

        let annular = LivelineAdvancedLayout.polarArea(
            values: [
                .init(id: "small", label: "Small", value: 1),
                .init(id: "large", label: "Large", value: 4),
            ], style: .init(innerRadiusRatio: 0.75, gapDegrees: 0),
            layout: layout, textScale: .standard)
        let areas = annular.wedges.map {
            Double($0.radius * $0.radius - annular.innerRadius * annular.innerRadius)
        }
        XCTAssertEqual(areas[0] / areas[1], 0.25, accuracy: 0.000_1)
    }

    func testBumpAndParallelTargetsFollowVisibleAndFinalGeometry() throws {
        let layout = LivelineLayout(
            size: CGSize(width: 320, height: 240),
            padding: .init(top: 20, right: 20, bottom: 20, left: 20),
            minValue: 1, maxValue: 3, leftEdge: 2, rightEdge: 4)
        let palette = LivelinePalette.resolve(accent: .blue, mode: .light, lineWidth: 2)
        let rank = LivelineRankSeries(
            id: "team", label: "Falcons",
            points: (0...6).map { .init(time: Double($0), rank: Double($0 % 3 + 1)) })
        let bumpTargets = LivelineAdvancedInteractionBuilder.targets(
            content: .bump([rank], .init()), layout: layout, palette: palette,
            configuration: .init(), targetLocation: nil, textScale: .standard)
        XCTAssertEqual(bumpTargets.count, 3)
        XCTAssertTrue(bumpTargets.allSatisfy { $0.selection.heading == "Falcons" })
        XCTAssertFalse(
            LivelineChartContent.advanced(.bump([rank], .init())).semantics().capabilities
                .usesCartesianGrid)

        var rtl = layout
        rtl.isRTL = true
        let ltrGeometry = try XCTUnwrap(
            LivelineAdvancedLayout.bump(
                series: [rank], style: .init(), layout: layout, textScale: .standard))
        let rtlGeometry = try XCTUnwrap(
            LivelineAdvancedLayout.bump(
                series: [rank], style: .init(), layout: rtl, textScale: .standard))
        XCTAssertEqual(
            ltrGeometry.x(time: 4) + rtlGeometry.x(time: 4),
            layout.plotLeftX + layout.rightX,
            accuracy: 0.001)

        let records = [
            LivelineParallelRecord(id: "short", label: "Short", values: [1, 2]),
            LivelineParallelRecord(id: "long", label: "Long", values: [1, 2, 3]),
        ]
        let parallel = try XCTUnwrap(
            LivelineAdvancedLayout.parallelCoordinates(
                records: records, layout: layout, textScale: .standard))
        let parallelTargets = LivelineAdvancedInteractionBuilder.targets(
            content: .parallelCoordinates(records, .init()), layout: layout, palette: palette,
            configuration: .init(), targetLocation: nil, textScale: .standard)
        XCTAssertEqual(parallelTargets[0].selection.anchor.x, parallel.x(axis: 1), accuracy: 0.001)
    }

    func testAdvancedAudioGraphMatchesRenderedDimensionsAndViewport() {
        let distributions = [
            LivelineDistributionSeries(id: "empty", label: "Empty", values: []),
            LivelineDistributionSeries(id: "real", label: "Real", values: [2, 3, 4]),
        ]
        let distributionAudio = LivelineAdvancedAudioGraph.make(
            content: .violin(distributions, .init()), visibleRange: nil)
        XCTAssertEqual(distributionAudio.categoryOrder, ["Real"])

        let ganttAudio = LivelineAdvancedAudioGraph.make(
            content: .gantt([
                .init(id: "overlap", label: "Overlap", start: 0, end: 8, lane: 0),
                .init(id: "outside", label: "Outside", start: 0, end: 1, lane: 1),
            ], .init()), visibleRange: 5...10)
        XCTAssertEqual(ganttAudio.series[0].points.count, 1)
        XCTAssertEqual(ganttAudio.series[0].points[0].time, 5)

        let marimekkoAudio = LivelineAdvancedAudioGraph.make(
            content: .marimekko([
                .init(
                    id: "one", label: "One", width: 2,
                    segments: [.init(id: "a", label: "A", value: 3)])
            ], .init()), visibleRange: nil)
        XCTAssertEqual(marimekkoAudio.series.map(\.name), [LivelineStrings.labelColumnWidth, "A"])

        let volumeAudio = LivelineAdvancedAudioGraph.make(
            content: .volumeProfile([
                .init(price: 100, volume: 0), .init(price: 101, volume: 5),
            ], .init()), visibleRange: nil, formatValue: { "P\(Int($0))" })
        XCTAssertEqual(volumeAudio.categoryOrder, ["P101"])

        let depthAudio = LivelineAdvancedAudioGraph.make(
            content: .marketDepth([.init(price: 99, bidSize: 2)], .init()),
            visibleRange: nil, formatValue: { "P\(Int($0))" })
        XCTAssertTrue(depthAudio.isCategorical)
        XCTAssertEqual(depthAudio.categoryOrder, ["P99"])

        let renkoStyle = LivelineRenkoStyle(brickSize: 1)
        let renkoAudio = LivelineAdvancedAudioGraph.make(
            content: .renko(
                .init(points: [.init(time: 0, value: 100), .init(time: 1, value: 103)], style: renkoStyle),
                renkoStyle), visibleRange: nil)
        XCTAssertTrue(renkoAudio.isCategorical)

        let ohlcAudio = LivelineAdvancedAudioGraph.make(
            content: .ohlcVolume([
                .init(time: 0, open: 10, high: 12, low: 9, close: 11, volume: 1_000_000)
            ], .init()), visibleRange: nil)
        XCTAssertTrue(ohlcAudio.series.contains { $0.name == LivelineStrings.labelVolume })
    }

    func testLatestReviewFindingsStayAlignedAcrossGeometryAndInspectionModes() throws {
        XCTAssertTrue(
            LivelineAdvancedMath.pointFigureColumns(
                points: [
                    .init(time: 0, value: 0),
                    .init(time: 1, value: Double.greatestFiniteMagnitude),
                ], boxSize: 0.000_001, reversalBoxes: 3
            ).isEmpty,
            "An unrepresentable box delta must not trap during chart construction."
        )

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let calendarContent = LivelineAdvancedChartContent.calendarHeatmap([
            .init(date: day, value: 2),
            .init(date: day.addingTimeInterval(3_600), value: 8),
        ], .init(calendar: calendar))
        XCTAssertEqual(calendarContent.accessibilityEntryCount, 1)
        XCTAssertEqual(
            calendarContent.accessibilityEntries(
                formatValue: { String($0) }, formatTime: { String($0) }
            ).map(\.value),
            ["8.0"]
        )

        let marimekko = LivelineAdvancedAudioGraph.make(
            content: .marimekko([
                .init(
                    id: "hidden", label: "Hidden", width: 0,
                    segments: [.init(id: "h", label: "H", value: 10)]),
                .init(
                    id: "visible", label: "Visible", width: 2,
                    segments: [.init(id: "v", label: "V", value: 3)]),
            ], .init()),
            visibleRange: nil
        )
        XCTAssertEqual(marimekko.categoryOrder, ["Visible"])
        XCTAssertTrue(marimekko.series.allSatisfy { series in
            series.points.allSatisfy { $0.category == "Visible" }
        })

        let compactMekko = LivelineVisualGeometry.marimekko(
            columns: [
                .init(
                    id: "a", label: "A", width: 1,
                    segments: [
                        .init(id: "a1", label: "A1", value: 1),
                        .init(id: "a2", label: "A2", value: 1),
                    ]),
                .init(
                    id: "b", label: "B", width: 1,
                    segments: [
                        .init(id: "b1", label: "B1", value: 1),
                        .init(id: "b2", label: "B2", value: 1),
                    ]),
            ],
            in: CGRect(x: 0, y: 0, width: 10, height: 10),
            columnSpacing: 16,
            segmentSpacing: 16
        )
        XCTAssertTrue(compactMekko.allSatisfy { $0.rect.width > 0 })
        XCTAssertTrue(compactMekko.flatMap(\.segments).allSatisfy { $0.rect.height > 0 })

        var rtlLayout = LivelineLayout(
            size: CGSize(width: 160, height: 120),
            padding: .init(top: 10, right: 10, bottom: 10, left: 10),
            minValue: 0, maxValue: 10, leftEdge: 0, rightEdge: 1)
        rtlLayout.isRTL = true
        let volumeLayout = LivelineAdvancedLayout.volumeProfile(
            levels: [.init(price: 100, volume: 5)],
            style: .init(showsValues: true), layout: rtlLayout, textScale: .standard)
        XCTAssertGreaterThan(volumeLayout.body.minX, volumeLayout.plot.minX)

        var denseBricks: [LivelineRenkoBrick] = []
        for index in 0..<100 {
            denseBricks.append(
                LivelineRenkoBrick(
                    time: Double(index), open: Double(index), close: Double(index + 1),
                    sourceHigh: Double(index + 1), sourceLow: Double(index)))
        }
        let denseRenkoStyle = LivelineRenkoStyle(brickSize: 1, brickSpacing: 12)
        let renko = LivelineAdvancedLayout.renko(
            bricks: denseBricks, style: denseRenkoStyle, layout: rtlLayout)
        XCTAssertLessThanOrEqual(renko.brickSpacing, renko.slot * 0.5)
        XCTAssertLessThanOrEqual(
            renko.rect(at: 99, layout: rtlLayout).maxX,
            renko.plot.maxX + 0.000_1)

        let ternaryPoint = LivelineTernaryPoint(
            id: "mix", label: "Mix", a: 1, b: 2, c: 3, magnitude: 42)
        let ternaryContent = LivelineAdvancedChartContent.ternary([ternaryPoint], .init())
        let ternaryEntry = try XCTUnwrap(
            ternaryContent.accessibilityEntries(
                formatValue: { String($0) }, formatTime: { String($0) }).first)
        XCTAssertTrue(ternaryEntry.value.contains("42"))
        let ternaryAudio = LivelineAdvancedAudioGraph.make(
            content: ternaryContent, visibleRange: nil)
        XCTAssertTrue(ternaryAudio.series.contains { $0.name == LivelineStrings.labelMagnitude })

        let depthContent = LivelineAdvancedChartContent.marketDepth([
            .init(price: 100, bidSize: 10),
            .init(price: 99, bidSize: 20),
        ], .init())
        let depthEntries = depthContent.accessibilityEntries(
            formatValue: { String($0) }, formatTime: { String($0) })
        XCTAssertEqual(depthEntries.count, 2)
        XCTAssertTrue(depthEntries.contains { $0.value.contains("30") })

        let repeatedPoints = (0..<12).map {
            LivelineXYPoint(id: "p\($0)", x: 1, y: 1, weight: 2)
        }
        let hexbinContent = LivelineAdvancedChartContent.hexbin(
            repeatedPoints, .init(binsAcross: 4))
        let hexbinEntries = hexbinContent.accessibilityEntries(
            formatValue: { String($0) }, formatTime: { String($0) })
        XCTAssertEqual(hexbinContent.accessibilityEntryCount, 1)
        XCTAssertEqual(hexbinEntries.count, 1)
        XCTAssertTrue(hexbinEntries[0].value.contains("12"))
        XCTAssertTrue(hexbinEntries[0].value.contains("24"))
    }

    func testTargetedAdvancedInteractionFormatsOnlyNearestTimedMarks() {
        let layout = LivelineLayout(
            size: CGSize(width: 320, height: 240),
            padding: .init(top: 20, right: 20, bottom: 20, left: 20),
            minValue: 0, maxValue: 100, leftEdge: 0, rightEdge: 99)
        let palette = LivelinePalette.resolve(accent: .blue, mode: .light, lineWidth: 2)
        let points = (0..<100).map { LivelinePoint(time: Double($0), value: Double($0)) }
        let location = CGPoint(x: layout.x(for: 60), y: layout.y(for: 60))

        let horizon = LivelineAdvancedInteractionBuilder.targets(
            content: .horizon(points, .init()), layout: layout, palette: palette,
            configuration: .init(), targetLocation: location, textScale: .standard)
        XCTAssertEqual(horizon.count, 1)
        XCTAssertEqual(horizon[0].selection.hover.time, 60)

        let bump = LivelineAdvancedInteractionBuilder.targets(
            content: .bump([
                .init(
                    id: "rank", label: "Rank",
                    points: points.map { .init(time: $0.time, rank: $0.value) })
            ], .init()),
            layout: layout, palette: palette, configuration: .init(),
            targetLocation: location, textScale: .standard)
        XCTAssertEqual(bump.count, 1)
        XCTAssertEqual(bump[0].selection.hover.time, 60)

        let candles = points.map {
            LivelineCandleVolume(
                time: $0.time, open: $0.value, high: $0.value + 1,
                low: $0.value - 1, close: $0.value, volume: 10)
        }
        let ohlc = LivelineAdvancedInteractionBuilder.targets(
            content: .ohlcVolume(candles, .init()), layout: layout, palette: palette,
            configuration: .init(), targetLocation: location, textScale: .standard)
        XCTAssertEqual(ohlc.count, 1)
        XCTAssertEqual(ohlc[0].selection.hover.time, 60)
    }

    func testNewestReviewFindingsAreBoundedMirroredAndAggregated() throws {
        let extremeTask = LivelineGanttTask(
            id: "extreme", label: "Extreme", start: 0, end: 1, lane: Int.max)
        XCTAssertEqual(extremeTask.lane, 10_000)
        let ganttContent = LivelineAdvancedChartContent.gantt([extremeTask], .init())
        let ganttPrepared = ganttContent.prepared(
            leftEdge: 0, rightEdge: 1, configuration: .init())
        XCTAssertEqual(ganttPrepared.rangeOverride?.upperBound, 10_000.5)

        let cumulativeRenko = LivelineAdvancedMath.renkoBricks(
            points: [
                .init(time: 0, value: 0),
                .init(time: 1, value: 6_000),
                .init(time: 2, value: 0),
            ],
            brickSize: 1
        )
        XCTAssertTrue(cumulativeRenko.isEmpty)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let recent = Date(timeIntervalSince1970: 1_900_000_000)
        let ancient = try XCTUnwrap(
            calendar.date(byAdding: .year, value: -100, to: recent))
        let calendarValues = [
            LivelineCalendarValue(date: ancient, value: 4),
            LivelineCalendarValue(date: recent, value: 8),
        ]
        let supported = LivelineAdvancedLayout.calendarValuesInSupportedSpan(
            calendarValues, calendar: calendar)
        XCTAssertEqual(supported.map(\.value), [8])
        XCTAssertEqual(LivelineCalendarValue(date: recent, value: -4).value, 0)

        let layout = LivelineLayout(
            size: CGSize(width: 320, height: 240),
            padding: .init(top: 20, right: 20, bottom: 20, left: 20),
            minValue: 0, maxValue: 10, leftEdge: 4, rightEdge: 6)
        let calendarGeometry = try XCTUnwrap(
            LivelineAdvancedLayout.calendar(
                values: calendarValues, style: .init(calendar: calendar),
                layout: layout, textScale: .standard))
        XCTAssertLessThanOrEqual(
            calendarGeometry.totalDays, LivelineAdvancedLayout.maximumCalendarDays)

        let sparseRank = LivelineRankSeries(
            id: "sparse", label: "Sparse",
            points: [.init(time: 0, rank: 1), .init(time: 10, rank: 2)])
        let bump = try XCTUnwrap(
            LivelineAdvancedLayout.bump(
                series: [sparseRank], style: .init(), layout: layout, textScale: .standard))
        XCTAssertEqual(
            bump.visibleIndexRange(in: sparseRank.points, includingBoundaryPoints: true),
            0...1)
        XCTAssertNil(
            bump.visibleIndexRange(in: sparseRank.points, includingBoundaryPoints: false))

        let bricks = [
            LivelineRenkoBrick(time: 0, open: 0, close: 1, sourceHigh: 1, sourceLow: 0),
            LivelineRenkoBrick(time: 1, open: 1, close: 2, sourceHigh: 2, sourceLow: 1),
        ]
        let renkoStyle = LivelineRenkoStyle(brickSize: 1, brickSpacing: 2)
        let ltrRenko = LivelineAdvancedLayout.renko(
            bricks: bricks, style: renkoStyle, layout: layout)
        var rtlLayout = layout
        rtlLayout.isRTL = true
        let rtlRenko = LivelineAdvancedLayout.renko(
            bricks: bricks, style: renkoStyle, layout: rtlLayout)
        XCTAssertLessThan(
            ltrRenko.rect(at: 0, layout: layout).midX,
            ltrRenko.rect(at: 1, layout: layout).midX)
        XCTAssertGreaterThan(
            rtlRenko.rect(at: 0, layout: rtlLayout).midX,
            rtlRenko.rect(at: 1, layout: rtlLayout).midX)

        let duplicateNodes = [
            LivelineNetworkNode(id: "shared", label: "Owner"),
            LivelineNetworkNode(id: "shared", label: "Duplicate"),
            LivelineNetworkNode(id: "target", label: "Target"),
        ]
        let edge = LivelineNetworkEdge(source: "shared", target: "target", value: 2)
        let network = try XCTUnwrap(
            LivelineAdvancedLayout.network(
                nodes: duplicateNodes, edges: [edge], style: .init(),
                layout: layout, textScale: .standard))
        XCTAssertEqual(network.placements.map(\.connections), [1, 0, 1])

        let duplicateLevels = [
            LivelinePriceVolume(price: 100, volume: 6),
            LivelinePriceVolume(price: 100, volume: 6),
            LivelinePriceVolume(price: 101, volume: 10),
        ]
        let aggregated = LivelineAdvancedLayout.volumeProfileLevels(duplicateLevels)
        XCTAssertEqual(aggregated.map(\.price), [100, 101])
        XCTAssertEqual(aggregated.map(\.volume), [12, 10])
        let volumeContent = LivelineAdvancedChartContent.volumeProfile(
            duplicateLevels, .init())
        XCTAssertEqual(volumeContent.accessibilityEntryCount, 2)
        let volumeAudio = LivelineAdvancedAudioGraph.make(
            content: volumeContent, visibleRange: nil)
        XCTAssertEqual(volumeAudio.categoryOrder.count, 2)

        let tinyLayout = LivelineLayout(
            size: CGSize(width: 24, height: 24),
            padding: .init(top: 8, right: 8, bottom: 8, left: 8),
            minValue: 0, maxValue: 1, leftEdge: 0, rightEdge: 1)
        let chord = LivelineAdvancedLayout.chord(
            links: [.init(source: "A", target: "B", value: 1)],
            style: .init(), layout: tinyLayout, textScale: .init(factor: 3))
        XCTAssertGreaterThanOrEqual(chord.innerRadius, 0)
        XCTAssertGreaterThanOrEqual(chord.outerRadius, chord.innerRadius)
    }

    func testPostCIReviewFindingsShareRenderableGeometryAndDerivedData() throws {
        let layout = LivelineLayout(
            size: CGSize(width: 320, height: 240),
            padding: .init(top: 20, right: 20, bottom: 20, left: 20),
            minValue: 0, maxValue: 10, leftEdge: 0, rightEdge: 10)
        let columns = [
            LivelinePointFigureColumn(index: 0, isRising: true, low: 1, high: 2, boxSize: 1),
            LivelinePointFigureColumn(index: 1, isRising: false, low: 0, high: 1, boxSize: 1),
        ]
        let ltrFigure = LivelineAdvancedLayout.pointAndFigure(
            columns: columns, style: .init(boxSize: 1), layout: layout, textScale: .standard)
        var rtlLayout = layout
        rtlLayout.isRTL = true
        let rtlFigure = LivelineAdvancedLayout.pointAndFigure(
            columns: columns, style: .init(boxSize: 1), layout: rtlLayout, textScale: .standard)
        XCTAssertLessThan(ltrFigure.x(column: columns[0]), ltrFigure.x(column: columns[1]))
        XCTAssertGreaterThan(rtlFigure.x(column: columns[0]), rtlFigure.x(column: columns[1]))

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let calendarAudio = LivelineAdvancedAudioGraph.make(
            content: .calendarHeatmap([
                .init(date: day, value: 2),
                .init(date: day.addingTimeInterval(3_600), value: 8),
            ], .init(calendar: calendar)),
            visibleRange: nil)
        XCTAssertEqual(calendarAudio.series[0].points.map(\.value), [8])

        let repeatedPoints = (0..<4).map {
            LivelineXYPoint(id: "p\($0)", x: 1, y: 1, weight: 2)
        }
        let hexbinAudio = LivelineAdvancedAudioGraph.make(
            content: .hexbin(repeatedPoints, .init(binsAcross: 4)), visibleRange: nil)
        XCTAssertEqual(hexbinAudio.categoryOrder.count, 1)
        XCTAssertEqual(hexbinAudio.series[0].points.map(\.value), [4])
        XCTAssertEqual(hexbinAudio.series[1].points.map(\.value), [8])

        let visibleSegment = LivelineCategoryValue(id: "segment", label: "Segment", value: 4)
        let marimekko = LivelineAdvancedChartContent.marimekko([
            .init(id: "hidden", label: "Hidden", width: 0, segments: [visibleSegment]),
            .init(id: "visible", label: "Visible", width: 2, segments: [visibleSegment]),
        ], .init())
        XCTAssertEqual(marimekko.accessibilityEntryCount, 1)
        XCTAssertEqual(
            marimekko.accessibilityEntries(
                formatValue: { String($0) }, formatTime: { String($0) }).count,
            1)

        let contourSamples = [
            LivelineContourSample(id: "a", x: 0, y: 0, value: 2),
            LivelineContourSample(id: "b", x: 0, y: 0, value: 6),
            LivelineContourSample(id: "c", x: 1, y: 0, value: 1),
            LivelineContourSample(id: "d", x: 0, y: 1, value: 2),
            LivelineContourSample(id: "e", x: 1, y: 1, value: 3),
        ]
        let contourContent = LivelineAdvancedChartContent.contour(contourSamples, .init())
        XCTAssertEqual(contourContent.accessibilityEntryCount, 4)
        XCTAssertEqual(
            contourContent.accessibilityEntries(
                formatValue: { String($0) }, formatTime: { String($0) }).count,
            4)
        XCTAssertEqual(
            LivelineAdvancedAudioGraph.make(content: contourContent, visibleRange: nil)
                .categoryOrder.count,
            4)
        let denseGrid = (0..<10).flatMap { y in
            (0..<10).map { x in
                LivelineContourSample(
                    id: "\(x)-\(y)", x: Double(x), y: Double(y), value: Double(x + y))
            }
        }
        let compactContourLayout = LivelineLayout(
            size: CGSize(width: 30, height: 30),
            padding: .init(top: 5, right: 5, bottom: 5, left: 5),
            minValue: 0, maxValue: 20, leftEdge: 0, rightEdge: 9)
        XCTAssertEqual(
            LivelineAdvancedLayout.contour(
                samples: denseGrid, layout: compactContourLayout, textScale: .standard)?.subdivisions,
            1)

        let extremeTernary = LivelineTernaryPoint(
            id: "extreme", label: "Extreme",
            a: Double.greatestFiniteMagnitude, b: Double.greatestFiniteMagnitude, c: 0)
        XCTAssertTrue(extremeTernary.total.isFinite)
        XCTAssertEqual(extremeTernary.proportions.a, 0.5)
        XCTAssertEqual(extremeTernary.proportions.b, 0.5)
        let ternaryPoint = LivelineAdvancedLayout.ternary(
            style: .init(), layout: layout, textScale: .standard).point(extremeTernary)
        XCTAssertTrue(ternaryPoint.x.isFinite && ternaryPoint.y.isFinite)

        let nodes = [
            LivelineNetworkNode(id: "a", label: "Alpha"),
            LivelineNetworkNode(id: "b", label: "Beta"),
        ]
        let networkTargets = LivelineAdvancedInteractionBuilder.targets(
            content: .network(nodes, [.init(source: "a", target: "b", value: 3)], .init()),
            layout: layout,
            palette: LivelinePalette.resolve(accent: .blue, mode: .light, lineWidth: 2),
            configuration: .init(), targetLocation: nil, textScale: .standard)
        XCTAssertEqual(networkTargets.count, 3)
        XCTAssertEqual(networkTargets[0].selection.heading, "Alpha to Beta")

        let depthPaths = try XCTUnwrap(
            LivelineRenderer.depthCurvePaths(
                points: [.init(time: 80, value: 5)],
                plot: CGRect(x: 0, y: 0, width: 100, height: 100),
                point: { _ in CGPoint(x: 80, y: 50) },
                singletonBoundaryX: 0))
        XCTAssertTrue(depthPaths.area.contains(CGPoint(x: 10, y: 90)))

        let residualBricks = LivelineAdvancedMath.renkoBricks(
            points: [.init(time: 0, value: 100), .init(time: 1, value: 103.5)],
            brickSize: 1)
        XCTAssertEqual(residualBricks.map(\.sourceHigh), [101, 102, 103.5])
        XCTAssertEqual(residualBricks.map(\.sourceLow), [100, 101, 102])
    }

    func testThirdReviewBatchUsesSharedDomainsBoundariesAndInspectionGeometry() throws {
        let renkoStyle = LivelineRenkoStyle(brickSize: 1)
        let renkoSeries = LivelineRenkoSeries(
            points: [
                .init(time: 0, value: 0),
                .init(time: 1, value: 10),
                .init(time: 100, value: 11),
            ],
            style: renkoStyle)
        let renkoPrepared = LivelineAdvancedChartContent.renko(renkoSeries, renkoStyle)
            .prepared(leftEdge: 99, rightEdge: 101, configuration: .init())
        XCTAssertLessThan(try XCTUnwrap(renkoPrepared.rangeOverride).lowerBound, 0)

        let hexbinPoints = [
            LivelineXYPoint(id: "a", x: 0, y: 0, weight: 1),
            LivelineXYPoint(id: "b", x: 0.2, y: 0.25, weight: 2),
            LivelineXYPoint(id: "c", x: 0.8, y: 0.75, weight: 3),
            LivelineXYPoint(id: "d", x: 1, y: 1, weight: 4),
        ]
        func hexbinLayout(width: CGFloat, height: CGFloat) -> LivelineHexbinLayout? {
            LivelineAdvancedLayout.hexbin(
                points: hexbinPoints, style: .init(binsAcross: 8),
                layout: LivelineLayout(
                    size: CGSize(width: width, height: height),
                    padding: .init(top: 5, right: 5, bottom: 5, left: 5),
                    minValue: 0, maxValue: 1, leftEdge: 0, rightEdge: 1),
                textScale: .standard)
        }
        let wideHexbins = try XCTUnwrap(hexbinLayout(width: 480, height: 160))
        let tallHexbins = try XCTUnwrap(hexbinLayout(width: 160, height: 480))
        XCTAssertEqual(
            wideHexbins.cells.map { ($0.column, $0.row, $0.count) }.description,
            tallHexbins.cells.map { ($0.column, $0.row, $0.count) }.description)
        XCTAssertEqual(wideHexbins.cells.map(\.weight), tallHexbins.cells.map(\.weight))

        let tinyLayout = LivelineLayout(
            size: CGSize(width: 24, height: 24),
            padding: .init(top: 8, right: 8, bottom: 8, left: 8),
            minValue: 0, maxValue: 1, leftEdge: 0, rightEdge: 1)
        let polar = LivelineAdvancedLayout.polarArea(
            values: [.init(id: "a", label: "A", value: 1)],
            style: .init(), layout: tinyLayout, textScale: .init(factor: 3))
        XCTAssertGreaterThanOrEqual(polar.innerRadius, 0)
        XCTAssertGreaterThanOrEqual(polar.outerRadius, polar.innerRadius)

        let parallelRecords = [
            LivelineParallelRecord(id: "record", label: "Record", values: [1, 2, 3])
        ]
        let baseLayout = LivelineLayout(
            size: CGSize(width: 320, height: 240),
            padding: .init(top: 20, right: 20, bottom: 20, left: 20),
            minValue: 0, maxValue: 20, leftEdge: 0, rightEdge: 10)
        let ltrParallel = try XCTUnwrap(
            LivelineAdvancedLayout.parallelCoordinates(
                records: parallelRecords, layout: baseLayout, textScale: .standard))
        var rtlLayout = baseLayout
        rtlLayout.isRTL = true
        let rtlParallel = try XCTUnwrap(
            LivelineAdvancedLayout.parallelCoordinates(
                records: parallelRecords, layout: rtlLayout, textScale: .standard))
        XCTAssertLessThan(ltrParallel.x(axis: 0), ltrParallel.x(axis: 2))
        XCTAssertGreaterThan(rtlParallel.x(axis: 0), rtlParallel.x(axis: 2))

        let lowResolutionKey = LivelineAdvancedChartContent.hexbin(
            hexbinPoints, .init(binsAcross: 4)).accessibilityCacheDescriptor
        let highResolutionKey = LivelineAdvancedChartContent.hexbin(
            hexbinPoints, .init(binsAcross: 40)).accessibilityCacheDescriptor
        XCTAssertNotEqual(lowResolutionKey.variants, highResolutionKey.variants)

        let depth = LivelineAdvancedMath.marketDepthCurve([
            .init(price: 100, bidSize: 3, askSize: 2),
            .init(price: 100, bidSize: 4, askSize: 5),
            .init(price: 101, askSize: 1),
        ])
        XCTAssertEqual(depth.bids.count, 1)
        XCTAssertEqual(depth.bids[0].value, 7)
        XCTAssertEqual(depth.asks.map(\.value), [7, 8])

        let contourSamples = [
            LivelineContourSample(id: "00", x: 0, y: 0, value: 0),
            LivelineContourSample(id: "10", x: 1, y: 0, value: 10),
            LivelineContourSample(id: "01", x: 0, y: 1, value: 10),
            LivelineContourSample(id: "11", x: 1, y: 1, value: 20),
        ]
        let contourGeometry = try XCTUnwrap(
            LivelineAdvancedLayout.contour(
                samples: contourSamples, layout: baseLayout, textScale: .standard))
        let contourTargets = LivelineAdvancedInteractionBuilder.targets(
            content: .contour(contourSamples, .init()), layout: baseLayout,
            palette: LivelinePalette.resolve(accent: .blue, mode: .light, lineWidth: 2),
            configuration: .init(), targetLocation: CGPoint(
                x: contourGeometry.plot.midX, y: contourGeometry.plot.midY),
            textScale: .standard)
        XCTAssertEqual(contourTargets.count, 1)
        XCTAssertEqual(contourTargets[0].selection.hover.value, 10, accuracy: 0.000_1)

        let chordLinks = [
            LivelineChordLink(source: "A", target: "B", value: 2),
            LivelineChordLink(source: "B", target: "C", value: 3),
        ]
        let chordContent = LivelineAdvancedChartContent.chord(chordLinks, .init())
        XCTAssertEqual(chordContent.accessibilityEntryCount, 5)
        let chordEntries = chordContent.accessibilityEntries(
            formatValue: { String($0) }, formatTime: { String($0) })
        XCTAssertEqual(chordEntries.filter { $0.id.hasPrefix("chord-node-") }.count, 3)

        let sparseHorizon = [
            LivelinePoint(time: 0, value: 2),
            LivelinePoint(time: 10, value: 8),
        ]
        XCTAssertEqual(
            sparseHorizon.livelineVisibleIncludingBoundaryPoints(in: 4...6),
            sparseHorizon)

        var mutatedRank = LivelineRankPoint(time: 1, rank: 2)
        mutatedRank.time = .nan
        mutatedRank.rank = .infinity
        let normalizedBump = LivelineAdvancedChartContent.bump([
            .init(id: "rank", label: "Rank", points: [mutatedRank])
        ], .init()).normalized()
        guard case .bump(let normalizedSeries, _) = normalizedBump else {
            return XCTFail("Expected bump content")
        }
        XCTAssertEqual(normalizedSeries[0].points, [.init(time: 0, rank: 0)])
    }

    func testFourthReviewBatchCoversRenderedPathsAndExtremeFiniteInputs() throws {
        let layout = LivelineLayout(
            size: CGSize(width: 320, height: 240),
            padding: .init(top: 20, right: 20, bottom: 20, left: 20),
            minValue: 0, maxValue: 10, leftEdge: 0, rightEdge: 10)
        let palette = LivelinePalette.resolve(accent: .blue, mode: .light, lineWidth: 2)

        let parallelRecords = [
            LivelineParallelRecord(id: "record", label: "Record", values: [1, 9, 2])
        ]
        let parallelGeometry = try XCTUnwrap(
            LivelineAdvancedLayout.parallelCoordinates(
                records: parallelRecords, layout: layout, textScale: .standard))
        let parallelTargets = LivelineAdvancedInteractionBuilder.targets(
            content: .parallelCoordinates(parallelRecords, .init()), layout: layout,
            palette: palette, configuration: .init(), targetLocation: nil,
            textScale: .standard)
        guard case .path(let parallelPath) = try XCTUnwrap(parallelTargets.first).region else {
            return XCTFail("Expected the rendered parallel polyline to be the hit region")
        }
        let parallelSegmentPoint = CGPoint(
            x: (parallelGeometry.x(axis: 0) + parallelGeometry.x(axis: 1)) / 2,
            y: (parallelGeometry.y(1, axis: 0) + parallelGeometry.y(9, axis: 1)) / 2)
        XCTAssertTrue(parallelPath.contains(parallelSegmentPoint))

        let depthLevels = [
            LivelineOrderBookLevel(price: 99, bidSize: 1),
            LivelineOrderBookLevel(price: 100, bidSize: 2),
        ]
        let depthGeometry = try XCTUnwrap(
            LivelineAdvancedLayout.marketDepth(
                levels: depthLevels, layout: layout, textScale: .standard))
        let depthTargets = LivelineAdvancedInteractionBuilder.targets(
            content: .marketDepth(depthLevels, .init()), layout: layout, palette: palette,
            configuration: .init(), targetLocation: nil, textScale: .standard)
        guard case .path(let depthPath) = try XCTUnwrap(depthTargets.first).region else {
            return XCTFail("Expected the rendered market-depth step to be the hit region")
        }
        let firstDepthPoint = depthGeometry.point(depthGeometry.curve.bids[0])
        let secondDepthPoint = depthGeometry.point(depthGeometry.curve.bids[1])
        XCTAssertTrue(depthPath.contains(CGPoint(
            x: (firstDepthPoint.x + secondDepthPoint.x) / 2,
            y: firstDepthPoint.y)))

        let extremeHexbins = try XCTUnwrap(
            LivelineAdvancedLayout.hexbin(
                points: [
                    .init(id: "minimum", x: -Double.greatestFiniteMagnitude,
                          y: -Double.greatestFiniteMagnitude),
                    .init(id: "maximum", x: Double.greatestFiniteMagnitude,
                          y: Double.greatestFiniteMagnitude),
                ],
                style: .init(binsAcross: 12), layout: layout, textScale: .standard))
        XCTAssertEqual(extremeHexbins.cells.count, 2)
        XCTAssertTrue(extremeHexbins.cells.allSatisfy {
            $0.center.x.isFinite && $0.center.y.isFinite
        })

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        var shifted = utc
        shifted.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 12 * 3_600))
        let calendarValues = [
            LivelineCalendarValue(date: Date(timeIntervalSince1970: 1_700_000_000), value: 1)
        ]
        let utcKey = LivelineAdvancedChartContent.calendarHeatmap(
            calendarValues, .init(calendar: utc)).accessibilityCacheDescriptor
        let shiftedKey = LivelineAdvancedChartContent.calendarHeatmap(
            calendarValues, .init(calendar: shifted)).accessibilityCacheDescriptor
        XCTAssertNotEqual(utcKey.identifiers, shiftedKey.identifiers)

        let extremeMekko = LivelineVisualGeometry.marimekko(
            columns: [
                .init(
                    id: "a", label: "A", width: .greatestFiniteMagnitude,
                    segments: [.init(id: "one", label: "One", value: .greatestFiniteMagnitude)]),
                .init(
                    id: "b", label: "B", width: .greatestFiniteMagnitude,
                    segments: [.init(id: "two", label: "Two", value: .greatestFiniteMagnitude)]),
            ],
            in: CGRect(x: 0, y: 0, width: 200, height: 100),
            columnSpacing: 0, segmentSpacing: 0)
        XCTAssertEqual(extremeMekko[0].rect.width, extremeMekko[1].rect.width, accuracy: 0.000_1)

        let extremeDensity = try XCTUnwrap(
            LivelineAdvancedMath.densityProfile(
                values: [-Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude],
                bandwidth: nil))
        XCTAssertTrue(extremeDensity.samples.allSatisfy {
            $0.value.isFinite && $0.density.isFinite
        })
        XCTAssertTrue(extremeDensity.lowerQuartile.isFinite)
        XCTAssertTrue(extremeDensity.median.isFinite)
        XCTAssertTrue(extremeDensity.upperQuartile.isFinite)

        let mekkoAudio = LivelineAdvancedAudioGraph.make(
            content: .marimekko([
                .init(
                    id: "column", label: "Column", width: 1,
                    segments: [
                        .init(id: "first", label: "Shared", value: 2),
                        .init(id: "second", label: "Shared", value: 3),
                    ])
            ], .init()),
            visibleRange: nil)
        XCTAssertEqual(mekkoAudio.series.map(\.name), [
            LivelineStrings.labelColumnWidth, "Shared", "Shared",
        ])
        XCTAssertEqual(mekkoAudio.series.dropFirst().compactMap { $0.points.first?.value }, [2, 3])

        let networkAudio = LivelineAdvancedAudioGraph.make(
            content: .network(
                [
                    .init(id: "a", label: "Alpha"),
                    .init(id: "b", label: "Beta"),
                ],
                [.init(source: "a", target: "b", value: 7)],
                .init()),
            visibleRange: nil)
        let flow = try XCTUnwrap(
            networkAudio.series.first { $0.name == LivelineStrings.labelFlow })
        XCTAssertEqual(flow.points.map(\.value), [7])
        XCTAssertEqual(flow.points.first?.category, "Alpha to Beta")
    }

    func testLatestReviewBatchMirrorsAdvancedGeometryAndKeepsCompactLayoutsReadable() throws {
        let layout = LivelineLayout(
            size: CGSize(width: 320, height: 240),
            padding: .init(top: 20, right: 20, bottom: 20, left: 20),
            minValue: 0, maxValue: 10, leftEdge: 0, rightEdge: 10)
        var rtlLayout = layout
        rtlLayout.isRTL = true

        let hexbinPoints = [
            LivelineXYPoint(id: "left", x: 0, y: 0),
            LivelineXYPoint(id: "right", x: 10, y: 10),
        ]
        let ltrHexbin = try XCTUnwrap(
            LivelineAdvancedLayout.hexbin(
                points: hexbinPoints, style: .init(binsAcross: 8), layout: layout,
                textScale: .standard))
        let rtlHexbin = try XCTUnwrap(
            LivelineAdvancedLayout.hexbin(
                points: hexbinPoints, style: .init(binsAcross: 8), layout: rtlLayout,
                textScale: .standard))
        XCTAssertEqual(ltrHexbin.cells.count, rtlHexbin.cells.count)
        for (ltr, rtl) in zip(ltrHexbin.cells, rtlHexbin.cells) {
            XCTAssertEqual(ltr.column, rtl.column)
            XCTAssertEqual(
                ltr.center.x + rtl.center.x,
                ltrHexbin.plot.minX + ltrHexbin.plot.maxX,
                accuracy: 0.000_1)
        }

        let mekkoColumns = [
            LivelineMarimekkoColumn(
                id: "first", label: "First", width: 1,
                segments: [.init(id: "one", label: "One", value: 1)]),
            LivelineMarimekkoColumn(
                id: "second", label: "Second", width: 2,
                segments: [.init(id: "two", label: "Two", value: 2)]),
        ]
        let ltrMekko = LivelineAdvancedLayout.marimekko(
            columns: mekkoColumns, style: .init(), layout: layout, textScale: .standard)
        let rtlMekko = LivelineAdvancedLayout.marimekko(
            columns: mekkoColumns, style: .init(), layout: rtlLayout, textScale: .standard)
        for (ltr, rtl) in zip(ltrMekko.geometry, rtlMekko.geometry) {
            XCTAssertEqual(ltr.rect.width, rtl.rect.width, accuracy: 0.000_1)
            XCTAssertEqual(
                ltr.rect.midX + rtl.rect.midX,
                ltrMekko.body.minX + ltrMekko.body.maxX,
                accuracy: 0.000_1)
        }

        let contourSamples = (0..<2).flatMap { y in
            (0..<2).map { x in
                LivelineContourSample(
                    id: "\(x)-\(y)", x: Double(x), y: Double(y),
                    value: Double(x + y))
            }
        }
        let ltrContour = try XCTUnwrap(
            LivelineAdvancedLayout.contour(
                samples: contourSamples, layout: layout, textScale: .standard))
        let rtlContour = try XCTUnwrap(
            LivelineAdvancedLayout.contour(
                samples: contourSamples, layout: rtlLayout, textScale: .standard))
        XCTAssertEqual(
            ltrContour.point(x: 0, y: 0).x + rtlContour.point(x: 0, y: 0).x,
            ltrContour.plot.minX + ltrContour.plot.maxX,
            accuracy: 0.000_1)
        let rtlContourGeometry = LivelineVisualGeometry.contour(
            samples: contourSamples, levelCount: 4, plot: rtlContour.plot,
            subdivisions: rtlContour.subdivisions, isRTL: true)
        XCTAssertTrue(rtlContourGeometry.fillCells.allSatisfy { $0.rect.width > 0 })
        let contourState = LivelineRenderState()
        _ = contourState.contourGeometry(
            samples: contourSamples, levelCount: 4, plot: rtlContour.plot,
            subdivisions: rtlContour.subdivisions, isRTL: false)
        _ = contourState.contourGeometry(
            samples: contourSamples, levelCount: 4, plot: rtlContour.plot,
            subdivisions: rtlContour.subdivisions, isRTL: true)
        XCTAssertEqual(contourState.contourGeometryBuildCount, 2)

        let waffleValues = [
            LivelineCategoryValue(id: "large", label: "Large", value: 3),
            LivelineCategoryValue(id: "small", label: "Small", value: 1),
        ]
        let waffleStyle = LivelineWaffleStyle(
            columns: 2, rows: 2, spacing: 0, showsLegend: false)
        let ltrWaffle = LivelineAdvancedLayout.waffle(
            values: waffleValues, style: waffleStyle, layout: layout, textScale: .standard)
        let rtlWaffle = LivelineAdvancedLayout.waffle(
            values: waffleValues, style: waffleStyle, layout: rtlLayout, textScale: .standard)
        XCTAssertEqual(
            ltrWaffle.rect(cellIndex: 0).midX + rtlWaffle.rect(cellIndex: 0).midX,
            ltrWaffle.body.minX + ltrWaffle.body.maxX,
            accuracy: 0.000_1)

        let depthLevels = [
            LivelineOrderBookLevel(price: 99, bidSize: 3),
            LivelineOrderBookLevel(price: 101, askSize: 4),
        ]
        let ltrDepth = try XCTUnwrap(
            LivelineAdvancedLayout.marketDepth(
                levels: depthLevels, layout: layout, textScale: .standard))
        let rtlDepth = try XCTUnwrap(
            LivelineAdvancedLayout.marketDepth(
                levels: depthLevels, layout: rtlLayout, textScale: .standard))
        XCTAssertEqual(
            ltrDepth.x(price: 99) + rtlDepth.x(price: 99),
            ltrDepth.plot.minX + ltrDepth.plot.maxX,
            accuracy: 0.000_1)
        XCTAssertEqual(rtlDepth.bidBoundaryX, rtlDepth.plot.maxX)
        XCTAssertEqual(rtlDepth.askBoundaryX, rtlDepth.plot.minX)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let firstDay = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))
        let calendarValues = (0..<15).map { offset in
            LivelineCalendarValue(
                date: calendar.date(byAdding: .day, value: offset, to: firstDay)!,
                value: Double(offset + 1))
        }
        let calendarStyle = LivelineCalendarHeatmapStyle(calendar: calendar)
        let ltrCalendar = try XCTUnwrap(
            LivelineAdvancedLayout.calendar(
                values: calendarValues, style: calendarStyle, layout: layout,
                textScale: .standard))
        let rtlCalendar = try XCTUnwrap(
            LivelineAdvancedLayout.calendar(
                values: calendarValues, style: calendarStyle, layout: rtlLayout,
                textScale: .standard))
        XCTAssertEqual(
            ltrCalendar.rect(dayOffset: 0).midX + rtlCalendar.rect(dayOffset: 0).midX,
            rtlCalendar.body.minX + ltrCalendar.body.maxX,
            accuracy: 0.000_1)
        XCTAssertGreaterThan(ltrCalendar.body.minX, rtlCalendar.body.minX)

        let tinyLayout = LivelineLayout(
            size: CGSize(width: 24, height: 24),
            padding: .init(top: 8, right: 8, bottom: 8, left: 8),
            minValue: 0, maxValue: 1, leftEdge: 0, rightEdge: 1)
        let compactNetwork = try XCTUnwrap(
            LivelineAdvancedLayout.network(
                nodes: [.init(id: "node", label: "Node")], edges: [], style: .init(),
                layout: tinyLayout, textScale: .init(factor: 3)))
        XCTAssertGreaterThanOrEqual(compactNetwork.plot.width, 1)
        XCTAssertGreaterThanOrEqual(compactNetwork.plot.height, 1)
        XCTAssertTrue(compactNetwork.placements.allSatisfy {
            $0.center.x.isFinite && $0.center.y.isFinite
        })
    }

    func testLatestReviewBatchKeepsDerivedDataAccessibleInteractiveAndInRange() throws {
        let maximum = Double.greatestFiniteMagnitude
        let transformed = LivelineAdvancedMath.heikinAshiCandles([
            LivelineCandle(time: 0, open: maximum, high: maximum, low: maximum, close: maximum),
            LivelineCandle(time: 1, open: maximum, high: maximum, low: maximum, close: maximum),
        ])
        XCTAssertEqual(transformed.count, 2)
        XCTAssertTrue(transformed.allSatisfy {
            $0.open.isFinite && $0.high.isFinite && $0.low.isFinite && $0.close.isFinite
        })
        XCTAssertGreaterThan(transformed[0].open, 0)
        XCTAssertEqual(transformed[0].open, transformed[0].close)

        let singleCellStyle = LivelineWaffleStyle(
            columns: 1, rows: 1, spacing: 0, showsLegend: false)
        let sparseWaffle = LivelineAdvancedChartContent.waffle([
            .init(id: "allocated", label: "Allocated", value: 999),
            .init(id: "unallocated", label: "Unallocated", value: 1),
        ], singleCellStyle)
        XCTAssertEqual(sparseWaffle.accessibilityEntryCount, 1)
        XCTAssertEqual(
            sparseWaffle.accessibilityEntries(
                formatValue: { String($0) }, formatTime: { String($0) }).map(\.label),
            ["Allocated"])
        XCTAssertEqual(
            LivelineAdvancedAudioGraph.make(content: sparseWaffle, visibleRange: nil).categoryOrder,
            ["Allocated"])

        let tasks = [
            LivelineGanttTask(id: "plan", label: "Plan", start: 0, end: 2, lane: 0),
            LivelineGanttTask(
                id: "build", label: "Build", start: 2, end: 6, lane: 1,
                dependencyIDs: ["plan"]),
        ]
        let ganttEntries = LivelineAdvancedChartContent.gantt(tasks, .init())
            .accessibilityEntries(formatValue: { String($0) }, formatTime: { String($0) })
        XCTAssertTrue(try XCTUnwrap(ganttEntries.first { $0.id == "build" }).value.contains("Plan"))
        let hiddenDependencyEntries = LivelineAdvancedChartContent.gantt(
            tasks, .init(showsDependencies: false)
        ).accessibilityEntries(formatValue: { String($0) }, formatTime: { String($0) })
        XCTAssertFalse(
            try XCTUnwrap(hiddenDependencyEntries.first { $0.id == "build" }).value.contains("Plan"))

        let layout = LivelineLayout(
            size: CGSize(width: 320, height: 240),
            padding: .init(top: 20, right: 20, bottom: 20, left: 20),
            minValue: 0, maxValue: 10, leftEdge: 4, rightEdge: 6)
        XCTAssertEqual(
            LivelineAdvancedLayout.ganttTaskIndicesIntersectingViewport(
                [
                    .init(id: "before", label: "Before", start: 0, end: 3, lane: 0),
                    .init(id: "visible", label: "Visible", start: 5, end: 7, lane: 1),
                    .init(id: "after", label: "After", start: 8, end: 9, lane: 2),
                ],
                layout: layout),
            [1])

        let palette = LivelinePalette.resolve(accent: .blue, mode: .light, lineWidth: 2)
        let interactiveValues = [
            LivelineCategoryValue(id: "large", label: "Large", value: 3),
            LivelineCategoryValue(id: "small", label: "Small", value: 1),
        ]
        let interactiveStyle = LivelineWaffleStyle(
            columns: 2, rows: 2, spacing: 0, showsLegend: false)
        let interactiveGeometry = LivelineAdvancedLayout.waffle(
            values: interactiveValues, style: interactiveStyle, layout: layout,
            textScale: .standard)
        let waffleTargets = LivelineAdvancedInteractionBuilder.targets(
            content: .waffle(interactiveValues, interactiveStyle), layout: layout,
            palette: palette, configuration: .init(), targetLocation: nil,
            textScale: .standard)
        guard case .path(let largeRegion) = try XCTUnwrap(waffleTargets.first).region else {
            return XCTFail("Expected every allocated waffle cell to form the hit region")
        }
        for index in 0..<interactiveGeometry.allocations[0] {
            let rect = interactiveGeometry.rect(cellIndex: index)
            XCTAssertTrue(largeRegion.contains(CGPoint(x: rect.midX, y: rect.midY)))
        }

        let flatCandle = LivelineCandleVolume(
            time: 5, open: 100, high: 100, low: 100, close: 100, volume: 10)
        let flatGeometry = try XCTUnwrap(
            LivelineAdvancedLayout.ohlcVolume(
                values: [flatCandle], style: .init(), layout: layout))
        XCTAssertEqual(flatGeometry.priceY(100), flatGeometry.priceRect.midY, accuracy: 0.000_1)

        let pointFigureStyle = LivelinePointAndFigureStyle(boxSize: 1)
        let pointFigure = LivelinePointFigureSeries(
            points: [
                .init(time: 0, value: 100),
                .init(time: 1, value: 102),
                .init(time: 2, value: 104),
            ],
            style: pointFigureStyle)
        var configuration = LivelineChartConfiguration()
        configuration.referenceLine = LivelineReferenceLine(value: 200)
        let prepared = LivelineAdvancedChartContent.pointAndFigure(
            pointFigure, pointFigureStyle
        ).prepared(leftEdge: 0, rightEdge: 2, configuration: configuration)
        XCTAssertTrue(prepared.rangePoints.contains { $0.value == 200 })
        XCTAssertTrue(try XCTUnwrap(prepared.rangeOverride).contains(200))
    }

    func testAccessibilityAndPreparationRejectInvisibleOrMisleadingData() throws {
        let nodes = [
            LivelineNetworkNode(id: "a", label: "Alpha"),
            LivelineNetworkNode(id: "b", label: "Beta"),
        ]
        let content = LivelineAdvancedChartContent.network(
            nodes,
            [.init(source: "a", target: "b", value: 0), .init(source: "a", target: "b", value: 4)],
            .init()).normalized()
        guard case .network(_, let edges, _) = content else { return XCTFail("Expected network") }
        XCTAssertEqual(edges.count, 1)
        XCTAssertEqual(content.accessibilityEntryCount, 3)
        let accessibilityEntries = content.accessibilityEntries(
            formatValue: { String($0) }, formatTime: { String($0) })
        XCTAssertTrue(
            accessibilityEntries.contains {
                $0.label == "Alpha to Beta" && $0.value.contains("4")
            })

        let point = LivelineTernaryPoint(id: "t", label: "T", a: 1, b: 2, c: 3)
        let oldKey = LivelineAdvancedChartContent.ternary(
            [point], .init(axisLabels: ["A", "B", "C"])).accessibilityCacheDescriptor
        let newKey = LivelineAdvancedChartContent.ternary(
            [point], .init(axisLabels: ["X", "Y", "Z"])).accessibilityCacheDescriptor
        XCTAssertNotEqual(oldKey.identifiers, newKey.identifiers)

        let sparse = LivelineAdvancedChartContent.contour([
            .init(id: "0", x: 0, y: 0, value: 0),
            .init(id: "1", x: 1, y: 0, value: 1),
            .init(id: "2", x: 0, y: 1, value: 1),
        ], .init())
        XCTAssertTrue(sparse.isEmpty)
        XCTAssertFalse(
            sparse.prepared(leftEdge: 0, rightEdge: 1, configuration: .init()).hasData)

        let hugeRenkoStyle = LivelineRenkoStyle(brickSize: 0.000_001)
        let hugeRenko = LivelineRenkoSeries(
            points: [.init(time: 0, value: 0), .init(time: 1, value: 100)],
            style: hugeRenkoStyle)
        XCTAssertTrue(hugeRenko.bricks.isEmpty)
        XCTAssertTrue(LivelineAdvancedChartContent.renko(hugeRenko, hugeRenkoStyle).isEmpty)

        let wickPoints = [LivelinePoint(time: 0, value: 100), LivelinePoint(time: 1, value: 101.9)]
        let hiddenStyle = LivelineRenkoStyle(brickSize: 1, showsWicks: false)
        let shownStyle = LivelineRenkoStyle(brickSize: 1, showsWicks: true)
        let series = LivelineRenkoSeries(points: wickPoints, style: hiddenStyle)
        let hidden = LivelineAdvancedChartContent.renko(series, hiddenStyle)
            .prepared(leftEdge: 0, rightEdge: 2, configuration: .init())
        let shown = LivelineAdvancedChartContent.renko(series, shownStyle)
            .prepared(leftEdge: 0, rightEdge: 2, configuration: .init())
        XCTAssertEqual(hidden.rangePoints.map(\.value).max(), 101)
        XCTAssertEqual(shown.rangePoints.map(\.value).max(), 101.9)
    }

    func testDistributionProfilesShareOneDomainAndOneRenderStateCacheEntry() {
        let series = [
            LivelineDistributionSeries(id: "small", label: "Small", values: [0, 1]),
            LivelineDistributionSeries(id: "large", label: "Large", values: [100, 110]),
        ]
        let state = LivelineRenderState()
        let first = state.distributionProfiles(series: series, bandwidth: nil)
        let second = state.distributionProfiles(series: series, bandwidth: nil)
        XCTAssertEqual(first.map(\.profile), second.map(\.profile))
        XCTAssertEqual(state.distributionProfileBuildCount, 1)

        let layout = LivelineLayout(
            size: CGSize(width: 320, height: 240),
            padding: .init(top: 20, right: 20, bottom: 20, left: 20),
            minValue: 0, maxValue: 110, leftEdge: 0, rightEdge: 1)
        let geometry = LivelineAdvancedLayout.violin(
            series: series, style: .init(), layout: layout, textScale: .standard, profiles: first)
        XCTAssertLessThanOrEqual(geometry.valueDomain.lowerBound, 0)
        XCTAssertGreaterThanOrEqual(geometry.valueDomain.upperBound, 110)
    }

    func testNewestReviewFindingsPreserveCacheGeometryAndExtremeFiniteData() {
        let tasks = [
            LivelineGanttTask(id: "plan", label: "Plan", start: 0, end: 1, lane: 0),
            LivelineGanttTask(
                id: "ship", label: "Ship", start: 1, end: 2, lane: 1,
                dependencyIDs: ["plan"]),
        ]
        let visibleDependencies = LivelineAdvancedChartContent.gantt(
            tasks, .init(showsDependencies: true)).accessibilityCacheDescriptor
        let hiddenDependencies = LivelineAdvancedChartContent.gantt(
            tasks, .init(showsDependencies: false)).accessibilityCacheDescriptor
        XCTAssertNotEqual(visibleDependencies.variants, hiddenDependencies.variants)

        let waffleValues = [
            LivelineCategoryValue(
                id: "large", label: "Large", value: Double.greatestFiniteMagnitude),
            LivelineCategoryValue(id: "small", label: "Small", value: 1),
        ]
        let smallGrid = LivelineAdvancedChartContent.waffle(
            waffleValues, .init(columns: 1, rows: 1)).accessibilityCacheDescriptor
        let largeGrid = LivelineAdvancedChartContent.waffle(
            waffleValues, .init(columns: 10, rows: 10)).accessibilityCacheDescriptor
        XCTAssertNotEqual(smallGrid.variants, largeGrid.variants)
        XCTAssertEqual(
            LivelineRenderer.waffleAllocations(values: waffleValues, cellCount: 100),
            [100, 0])

        let body = CGRect(x: 10, y: 20, width: 200, height: 80)
        XCTAssertEqual(
            LivelineRenderer.horizontalRevealClip(in: body, reveal: 0.25, isRTL: false),
            CGRect(x: 10, y: 20, width: 50, height: 80))
        XCTAssertEqual(
            LivelineRenderer.horizontalRevealClip(in: body, reveal: 0.25, isRTL: true),
            CGRect(x: 160, y: 20, width: 50, height: 80))

        let emptyAdvanced: [LivelineAdvancedChartContent] = [
            .horizon([.init(time: 0, value: 1)], .init()),
            .parallelCoordinates(
                [.init(id: "record", label: "Record", values: [1])], .init()),
            .contour([
                .init(id: "00", x: 0, y: 0, value: 1),
                .init(id: "10", x: 1, y: 0, value: 2),
                .init(id: "01", x: 0, y: 1, value: 3),
            ], .init()),
        ]
        for advanced in emptyAdvanced {
            let content = LivelineChartContent.advanced(advanced)
            let model = LivelineChartAccessibilityModel.make(
                content: content,
                semantics: content.semantics(),
                configuration: .init(),
                hiddenSeries: [])
            XCTAssertEqual(model.entryCount, 0)
            XCTAssertTrue(model.entries.isEmpty)
        }

        let maximum = Double.greatestFiniteMagnitude
        let collapsed = LivelineAdvancedLayout.contourSamplesByCoordinate([
            .init(id: "first", x: 0, y: 0, value: maximum),
            .init(id: "second", x: 0, y: 0, value: maximum),
        ])
        XCTAssertEqual(collapsed.first?.value, maximum)

        let extremeContour = [
            LivelineContourSample(id: "00", x: 0, y: 0, value: -maximum),
            LivelineContourSample(id: "10", x: 1, y: 0, value: maximum),
            LivelineContourSample(id: "01", x: 0, y: 1, value: maximum),
            LivelineContourSample(id: "11", x: 1, y: 1, value: -maximum),
        ]
        let contourGeometry = LivelineVisualGeometry.contour(
            samples: extremeContour,
            levelCount: 7,
            plot: CGRect(x: 0, y: 0, width: 240, height: 160),
            subdivisions: 4)
        XCTAssertFalse(contourGeometry.fillCells.isEmpty)
        XCTAssertTrue(contourGeometry.fillCells.allSatisfy { (0..<7).contains($0.level) })

        let depth = LivelineAdvancedChartContent.marketDepth([
            .init(price: maximum / 2, bidSize: 1),
            .init(price: maximum, askSize: 1),
        ], .init())
        let midpoint = depth.prepared(
            leftEdge: 0, rightEdge: 1, configuration: .init()).primaryValue
        XCTAssertTrue(midpoint.isFinite)
        XCTAssertEqual(midpoint / maximum, 0.75, accuracy: 0.000_001)
    }

    private static func fixture(named name: String) -> LivelineAdvancedChartContent {
        fixtures.first { $0.name == name }!.content
    }

    private static let fixtures: [(name: String, content: LivelineAdvancedChartContent)] = {
        let points = [
            LivelinePoint(time: 0, value: 100),
            LivelinePoint(time: 1, value: 103),
            LivelinePoint(time: 2, value: 99),
            LivelinePoint(time: 3, value: 104),
        ]
        let candles = [
            LivelineCandle(time: 0, open: 100, high: 104, low: 98, close: 102),
            LivelineCandle(time: 1, open: 102, high: 105, low: 99, close: 101),
        ]
        let categories = [
            LivelineCategoryValue(id: "a", label: "A", value: 60),
            LivelineCategoryValue(id: "b", label: "B", value: 40),
        ]
        return [
            ("Violin", .violin([.init(id: "d", label: "Desktop", values: [1, 2, 3])], .init())),
            ("Ridgeline", .ridgeline([.init(id: "d", label: "Desktop", values: [1, 2, 3])], .init())),
            (
                "Calendar heatmap",
                .calendarHeatmap(
                    [.init(date: Date(timeIntervalSince1970: 1), value: 2, label: "Day")], .init())
            ),
            (
                "Gantt",
                .gantt([.init(id: "g", label: "Build", start: 0, end: 2, lane: 0, progress: 0.5)], .init())
            ),
            ("Chord", .chord([.init(source: "A", target: "B", value: 2)], .init())),
            (
                "Parallel coordinates",
                .parallelCoordinates(
                    [.init(id: "p", label: "Plan", values: [1, 2, 3])],
                    .init(axisLabels: ["Speed", "Cost", "Safety"]))
            ),
            ("Hexbin", .hexbin([.init(id: "h", x: 1, y: 2, weight: 3, label: "Request")], .init())),
            (
                "Bump",
                .bump(
                    [
                        .init(
                            id: "r", label: "Rank", points: [.init(time: 0, rank: 2), .init(time: 1, rank: 1)])
                    ], .init())
            ),
            ("Horizon", .horizon(points, .init())),
            (
                "Marimekko",
                .marimekko([.init(id: "m", label: "Region", width: 2, segments: categories)], .init())
            ),
            ("Polar area", .polarArea(categories, .init())),
            (
                "Network",
                .network(
                    [.init(id: "a", label: "A"), .init(id: "b", label: "B")],
                    [.init(source: "a", target: "b")], .init())
            ),
            (
                "Contour",
                .contour(
                    [
                        .init(id: "0", x: 0, y: 0, value: 0), .init(id: "1", x: 1, y: 0, value: 1),
                        .init(id: "2", x: 0, y: 1, value: 1), .init(id: "3", x: 1, y: 1, value: 2),
                    ], .init())
            ),
            (
                "Ternary",
                .ternary(
                    [.init(id: "t", label: "T", a: 2, b: 3, c: 5)],
                    .init(axisLabels: ["Compute", "Storage", "Network"]))
            ),
            ("Waffle", .waffle(categories, .init())),
            ("Volume profile", .volumeProfile([.init(price: 100, volume: 5)], .init())),
            (
                "Renko",
                .renko(
                    LivelineRenkoSeries(points: points, style: .init(brickSize: 1)),
                    .init(brickSize: 1))
            ),
            ("Heikin-Ashi", .heikinAshi(LivelineHeikinAshiSeries(source: candles), .init())),
            (
                "Market depth",
                .marketDepth([.init(price: 99, bidSize: 2), .init(price: 101, askSize: 3)], .init())
            ),
            (
                "OHLC and volume",
                .ohlcVolume(
                    candles.enumerated().map { index, candle in
                        .init(
                            time: candle.time, open: candle.open, high: candle.high, low: candle.low,
                            close: candle.close, volume: Double(index + 1) * 10)
                    }, .init())
            ),
            (
                "Point and figure",
                .pointAndFigure(
                    LivelinePointFigureSeries(
                        points: points, style: .init(boxSize: 1, reversalBoxes: 2)),
                    .init(boxSize: 1, reversalBoxes: 2))
            ),
        ]
    }()
}
