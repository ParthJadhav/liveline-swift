#if os(macOS)
import AppKit
import SwiftUI
import XCTest
@testable import Liveline

final class LivelineRendererSmokeTests: XCTestCase {
    @MainActor
    func testEveryChartKindRendersAStableFrame() throws {
        let points = [
            LivelinePoint(time: 1, value: 4),
            LivelinePoint(time: 2, value: 7),
            LivelinePoint(time: 3, value: 5),
        ]
        let stacked = [
            LivelineStackedPoint(time: 1, values: [2, 1]),
            LivelineStackedPoint(time: 2, values: [3, 2]),
            LivelineStackedPoint(time: 3, values: [1, 4]),
        ]
        let categories = [
            LivelineCategoryValue(id: "a", label: "Alpha", value: 6),
            LivelineCategoryValue(id: "b", label: "Beta", value: 4),
        ]
        var ditherConfiguration = configuration
        ditherConfiguration.style = .dither(
            LivelineDitherStyle(bloom: .low, sparkleDensity: 0.02, animated: false)
        )
        for config in [configuration, ditherConfiguration] {
            let views: [(String, AnyView)] = [
            ("line", AnyView(LivelineChart(data: points, value: 5, configuration: config))),
            ("bars", AnyView(LivelineChart(bars: points, configuration: config))),
            ("range", AnyView(LivelineChart(range: [
                LivelineRangePoint(time: 1, lower: 2, upper: 5),
                LivelineRangePoint(time: 2, lower: 4, upper: 8),
                LivelineRangePoint(time: 3, lower: 3, upper: 7),
            ], configuration: config))),
            ("scatter", AnyView(LivelineChart(scatter: points, configuration: config))),
            ("steps", AnyView(LivelineChart(steps: points, configuration: config))),
            ("lollipops", AnyView(LivelineChart(lollipops: points, configuration: config))),
            ("bubbles", AnyView(LivelineChart(bubbles: [
                LivelineBubblePoint(time: 1, value: 4, magnitude: 2),
                LivelineBubblePoint(time: 2, value: 7, magnitude: 6),
                LivelineBubblePoint(time: 3, value: 5, magnitude: 4),
            ], configuration: config))),
            ("boxPlots", AnyView(LivelineChart(boxPlots: [
                LivelineBoxPlotPoint(time: 1, minimum: 1, lowerQuartile: 2, median: 3, upperQuartile: 4, maximum: 5),
                LivelineBoxPlotPoint(time: 2, minimum: 2, lowerQuartile: 3, median: 5, upperQuartile: 7, maximum: 8),
            ], configuration: config))),
            ("waterfall", AnyView(LivelineChart(waterfall: points, configuration: config))),
            ("errorBars", AnyView(LivelineChart(errorBars: [
                LivelineErrorBarPoint(time: 1, value: 4, lower: 2, upper: 6),
                LivelineErrorBarPoint(time: 2, value: 6, lower: 3, upper: 8),
            ], configuration: config))),
            ("dumbbells", AnyView(LivelineChart(dumbbells: [
                LivelineDumbbellPoint(time: 1, start: 2, end: 5),
                LivelineDumbbellPoint(time: 2, start: 6, end: 3),
            ], configuration: config))),
            ("stackedBars", AnyView(LivelineChart(stackedBars: stacked, configuration: config))),
            ("stackedAreas", AnyView(LivelineChart(stackedAreas: stacked, configuration: config))),
            ("timeline", AnyView(LivelineChart(timeline: [
                LivelineTimelineItem(id: "one", label: "One", start: 1, end: 2.4, lane: 0),
                LivelineTimelineItem(id: "two", label: "Two", start: 2, end: 3, lane: 1),
            ], configuration: config))),
            ("heatmap", AnyView(LivelineChart(heatmap: [
                LivelineHeatmapCell(time: 1, row: 0, value: 0.2),
                LivelineHeatmapCell(time: 2, row: 0, value: 0.8),
                LivelineHeatmapCell(time: 1, row: 1, value: 0.6),
            ], configuration: config))),
            ("radar", AnyView(LivelineChart(radar: [
                LivelineRadarPoint(label: "A", value: 0.3),
                LivelineRadarPoint(label: "B", value: 0.8),
                LivelineRadarPoint(label: "C", value: 0.5),
            ], configuration: config))),
            ("donut", AnyView(LivelineChart(donut: categories, configuration: config))),
            ("gauge", AnyView(LivelineChart(gauge: 0.65, configuration: config))),
            ("funnel", AnyView(LivelineChart(funnel: categories, configuration: config))),
            ("candle", AnyView(LivelineChart(
                data: points,
                value: 5,
                candles: [
                    LivelineCandle(time: 1, open: 3, high: 6, low: 2, close: 5),
                    LivelineCandle(time: 2, open: 5, high: 8, low: 4, close: 6),
                ],
                candleWidth: 1,
                liveCandle: LivelineCandle(time: 3, open: 6, high: 7, low: 4, close: 5),
                lineData: points,
                configuration: config
            ))),
            ("series", AnyView(LivelineChart(series: [
                LivelineSeries(id: "a", data: points, value: 5, color: .blue, label: "A"),
                LivelineSeries(
                    id: "b",
                    data: points.map { LivelinePoint(time: $0.time, value: $0.value + 2) },
                    value: 7,
                    color: .orange,
                    label: "B"
                ),
            ], configuration: config))),
        ]

            XCTAssertEqual(views.count, LivelineChartKind.allCases.count)
            for (name, view) in views {
                let renderer = ImageRenderer(
                    content: ZStack {
                        Color.black
                        view
                    }
                    .frame(width: 320, height: 220)
                )
                renderer.proposedSize = ProposedViewSize(width: 320, height: 220)
                renderer.scale = 1
                let image: NSImage = try XCTUnwrap(renderer.nsImage, "Failed to render \(name)")
                XCTAssertGreaterThan(image.tiffRepresentation?.count ?? 0, 1_000, name)
            }
        }
    }

    @MainActor
    func testEveryDitherVariantRenders() throws {
        let styles: [LivelineDitherVariant] = [.gradient, .dotted, .hatched, .solid]
        for (index, variant) in styles.enumerated() {
            var config = configuration
            config.style = .dither(
                LivelineDitherStyle(
                    variant: variant,
                    bloom: .off,
                    sparkleDensity: 0.04,
                    animated: false
                )
            )
            let chart = LivelineChart(
                bars: [
                    LivelinePoint(time: 1, value: 4),
                    LivelinePoint(time: 2, value: 7),
                    LivelinePoint(time: 3, value: 5),
                ],
                configuration: config
            )
            let renderer = ImageRenderer(
                content: chart.frame(width: 240, height: 160)
            )
            renderer.proposedSize = ProposedViewSize(width: 240, height: 160)
            let image: NSImage = try XCTUnwrap(renderer.nsImage, "Failed to render dither variant \(index)")
            XCTAssertGreaterThan(image.tiffRepresentation?.count ?? 0, 1_000)
        }
    }

    @MainActor
    func testContainerStyleOverrideRendersNestedChart() throws {
        let chart = LivelineChart(
            bars: [
                LivelinePoint(time: 1, value: 4),
                LivelinePoint(time: 2, value: 7),
                LivelinePoint(time: 3, value: 5),
            ],
            configuration: configuration
        )
        .livelineChartStyle(
            .dither(
                LivelineDitherStyle(
                    variant: .hatched,
                    bloom: .off,
                    animated: false
                )
            )
        )

        let renderer = ImageRenderer(content: chart.frame(width: 240, height: 160))
        renderer.proposedSize = ProposedViewSize(width: 240, height: 160)
        let image: NSImage = try XCTUnwrap(renderer.nsImage)
        XCTAssertGreaterThan(image.tiffRepresentation?.count ?? 0, 1_000)
    }

    @MainActor
    func testContainerStyleOverrideNormalizesInvalidDitherValues() throws {
        let chart = LivelineChart(
            bars: [
                LivelinePoint(time: 1, value: 4),
                LivelinePoint(time: 2, value: 7),
            ],
            configuration: configuration
        )
        .livelineChartStyle(
            .dither(
                LivelineDitherStyle(
                    cellSize: 0,
                    intensity: .infinity,
                    sparkleDensity: -.infinity,
                    animationSpeed: .nan,
                    maximumFramesPerSecond: 0,
                    animated: false
                )
            )
        )

        let renderer = ImageRenderer(content: chart.frame(width: 240, height: 160))
        renderer.proposedSize = ProposedViewSize(width: 240, height: 160)
        let image: NSImage = try XCTUnwrap(renderer.nsImage)
        XCTAssertGreaterThan(image.tiffRepresentation?.count ?? 0, 1_000)
    }

    @MainActor
    func testStructuredTooltipOverlayRendersAboveChartContent() throws {
        let renderer = ImageRenderer(
            content: Canvas { context, size in
                let layout = LivelineLayout(
                    size: size,
                    padding: LivelineResolvedPadding(top: 10, right: 10, bottom: 10, left: 10),
                    minValue: 0,
                    maxValue: 10,
                    leftEdge: 0,
                    rightEdge: 10
                )
                let palette = LivelinePalette.resolve(accent: .blue, mode: .dark, lineWidth: 2)
                LivelineRenderer.drawTooltipSelection(
                    context: &context,
                    layout: layout,
                    palette: palette,
                    selection: LivelineTooltipSelection(
                        hover: LivelineHoverPoint(time: 5, value: 6, x: 120, y: 80),
                        heading: "Jun",
                        rows: [
                            LivelineTooltipRow(label: "Desktop", value: "158", color: .blue),
                            LivelineTooltipRow(label: "Mobile", value: "70", color: .purple),
                        ],
                        anchor: CGPoint(x: 120, y: 80)
                    ),
                    configuration: LivelineChartConfiguration(),
                    alpha: 1
                )
            }
            .frame(width: 240, height: 160)
            .background(Color.black)
        )
        renderer.proposedSize = ProposedViewSize(width: 240, height: 160)
        let image: NSImage = try XCTUnwrap(renderer.nsImage)
        XCTAssertGreaterThan(image.tiffRepresentation?.count ?? 0, 1_000)
    }

    @MainActor
    func testExtremeFiniteValuesRenderWithoutOverflow() throws {
        let chart = LivelineChart(
            data: [
                LivelinePoint(time: -.greatestFiniteMagnitude, value: -.greatestFiniteMagnitude),
                LivelinePoint(time: .greatestFiniteMagnitude, value: .greatestFiniteMagnitude),
            ],
            value: .greatestFiniteMagnitude,
            configuration: LivelineChartConfiguration(
                window: .greatestFiniteMagnitude,
                badge: false,
                pulse: false,
                paused: true,
                referenceLine: LivelineReferenceLine(value: -.greatestFiniteMagnitude),
                formatValue: { _ in "extreme" },
                formatTime: { _ in "time" }
            )
        )
        let renderer = ImageRenderer(
            content: ZStack {
                Color.black
                chart
            }
            .frame(width: 320, height: 220)
        )
        renderer.proposedSize = ProposedViewSize(width: 320, height: 220)
        renderer.scale = 1
        let image: NSImage = try XCTUnwrap(renderer.nsImage)
        XCTAssertGreaterThan(image.tiffRepresentation?.count ?? 0, 1_000)
    }

    @MainActor
    func testHoverOnlyConfigurationDrawsTheTooltipThroughTheRealRenderPath() throws {
        let points = (0..<24).map { LivelinePoint(time: Double($0), value: 4 + Double($0 % 5)) }
        let content = LivelineChartContent.line(data: points, value: 6).normalized()
        let size = CGSize(width: 320, height: 220)

        func rawPixels(of image: CGImage) throws -> Data {
            var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
            let context = try XCTUnwrap(CGContext(
                data: &bytes,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return Data(bytes)
        }

        func frame(hoverLocation: CGPoint?, scrub: Bool, showsTooltipOnHover: Bool) throws -> Data {
            var configuration = LivelineChartConfiguration(
                window: 24,
                badge: false,
                pulse: false,
                scrub: scrub,
                paused: true,
                randomSeed: 7
            )
            configuration.showsTooltipOnHover = showsTooltipOnHover
            configuration = configuration.normalizedForRendering()

            let state = LivelineRenderState()
            let semantics = content.semantics()
            let renderer = ImageRenderer(
                content: ZStack {
                    Color.black
                    Canvas { context, canvasSize in
                        // Settle the reveal animation so only the hover state
                        // differs between the frames being compared.
                        for step in 0..<40 {
                            var pass = context
                            LivelineRenderer.draw(
                                context: &pass,
                                state: state,
                                input: LivelineRenderInput(
                                    content: content,
                                    semantics: semantics,
                                    accent: .blue,
                                    configuration: configuration,
                                    motion: LivelineMotionPolicy(
                                        isPaused: true,
                                        requiresTimeline: false,
                                        settlesImmediately: true,
                                        minimumInterval: 1.0 / 60.0
                                    ),
                                    activeWindow: 24,
                                    hiddenSeries: [],
                                    hoverLocation: hoverLocation,
                                    timestamp: 1_000 + Double(step) / 60,
                                    size: canvasSize
                                )
                            )
                        }
                    }
                }
                .frame(width: size.width, height: size.height)
            )
            renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
            renderer.scale = 1
            let cgImage: CGImage = try XCTUnwrap(renderer.cgImage)
            return try rawPixels(of: cgImage)
        }

        // Repeated ImageRenderer passes carry a little antialiasing jitter that
        // has nothing to do with hover, so count only channel changes far above
        // that floor. Drawn tooltip chrome is opaque and clears it easily.
        func repaintedSamples(_ lhs: Data, _ rhs: Data) -> Int {
            zip(lhs, rhs).count { abs(Int($0) - Int($1)) > 48 }
        }

        let probe = CGPoint(x: size.width * 0.55, y: size.height * 0.5)

        // Each comparison moves exactly one variable: the pointer. The opt-in is
        // held constant within a pair, so any repaint can only be the tooltip.
        let optedInIdle = try frame(hoverLocation: nil, scrub: false, showsTooltipOnHover: true)
        let optedInHovered = try frame(hoverLocation: probe, scrub: false, showsTooltipOnHover: true)
        XCTAssertGreaterThan(
            repaintedSamples(optedInIdle, optedInHovered),
            500,
            "hover-only chart did not draw a tooltip"
        )

        let optedOutIdle = try frame(hoverLocation: nil, scrub: false, showsTooltipOnHover: false)
        let optedOutHovered = try frame(hoverLocation: probe, scrub: false, showsTooltipOnHover: false)
        XCTAssertEqual(
            repaintedSamples(optedOutIdle, optedOutHovered),
            0,
            "pointer drew a tooltip while the opt-in was off"
        )
    }

    @MainActor
    func testReducedMotionSettlesCompleteCandlePresentationThroughRendererInput() throws {
        let points = [
            LivelinePoint(time: 1, value: 10),
            LivelinePoint(time: 2, value: 14),
        ]
        let live = LivelineCandle(time: 2, open: 10, high: 16, low: 9, close: 14)
        let content = LivelineChartContent.candle(
            data: points,
            value: 14,
            candles: [],
            candleWidth: 1,
            liveCandle: live,
            lineData: points,
            lineValue: 14
        )
        var configuration = self.configuration
        configuration.lineMode = true
        configuration.grid = false
        configuration.paused = false

        func render(
            state: LivelineRenderState,
            settlesImmediately: Bool
        ) throws {
            let renderer = ImageRenderer(
                content: Canvas { context, size in
                    var context = context
                    LivelineRenderer.draw(
                        context: &context,
                        state: state,
                        input: LivelineRenderInput(
                            content: content,
                            semantics: content.semantics(),
                            accent: .blue,
                            configuration: configuration,
                            motion: LivelineMotionPolicy(
                                isPaused: false,
                                requiresTimeline: !settlesImmediately,
                                settlesImmediately: settlesImmediately,
                                minimumInterval: 1 / 60
                            ),
                            activeWindow: 10,
                            hiddenSeries: [],
                            hoverLocation: nil,
                            timestamp: 1_000,
                            size: size
                        )
                    )
                }
                .frame(width: 320, height: 220)
            )
            renderer.proposedSize = ProposedViewSize(width: 320, height: 220)
            _ = try XCTUnwrap(renderer.nsImage)
        }

        let reducedState = LivelineRenderState()
        try render(state: reducedState, settlesImmediately: true)
        XCTAssertEqual(reducedState.candleLineModeProgress, 1)
        XCTAssertEqual(reducedState.candleLineDensityProgress, 1)
        XCTAssertEqual(reducedState.candleDisplayLive?.high, live.high)
        XCTAssertEqual(reducedState.candleDisplayLive?.low, live.low)
        XCTAssertEqual(reducedState.candleDisplayLive?.close, live.close)
        XCTAssertEqual(reducedState.candleLiveBirthAlpha, 1)
        XCTAssertEqual(reducedState.candleLineSmoothClose, live.close)
        XCTAssertEqual(reducedState.candleLineTickSmooth, 14)

        let animatedState = LivelineRenderState()
        try render(state: animatedState, settlesImmediately: false)
        XCTAssertLessThan(animatedState.candleLineModeProgress, 1)
        XCTAssertLessThan(animatedState.candleLineDensityProgress, 1)
        XCTAssertEqual(animatedState.candleDisplayLive?.close, live.open)
        XCTAssertLessThan(animatedState.candleLiveBirthAlpha, 1)
    }

    private var configuration: LivelineChartConfiguration {
        LivelineChartConfiguration(
            window: 10,
            badge: false,
            pulse: false,
            endpointDecorations: true,
            fadeEffects: false,
            momentum: .up,
            scrub: false,
            degen: LivelineDegenOptions(scale: 0.1),
            paused: true,
            orderbook: LivelineOrderbookData(
                bids: [LivelineOrderbookLevel(price: 4, size: 2)],
                asks: [LivelineOrderbookLevel(price: 6, size: 3)]
            ),
            activePoint: LivelineActivePoint(time: 2, pulse: false),
            randomSeed: 42
        )
    }
}
#endif
