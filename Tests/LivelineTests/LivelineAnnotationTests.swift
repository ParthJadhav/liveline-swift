import CoreGraphics
import SwiftUI
import XCTest
@testable import Liveline

final class LivelineAnnotationTests: XCTestCase {
    private let layout = LivelineLayout(
        size: CGSize(width: 320, height: 220),
        padding: LivelineResolvedPadding(top: 20, right: 20, bottom: 20, left: 20),
        minValue: 0,
        maxValue: 10,
        leftEdge: 0,
        rightEdge: 10
    )

    // MARK: - Models

    func testValueReferenceLineKeepsTheOriginalInitializerBehavior() {
        let line = LivelineReferenceLine(value: 42, label: "Open")

        XCTAssertEqual(line.value, 42)
        XCTAssertEqual(line.label, "Open")
        XCTAssertEqual(line.axis, .value)
        XCTAssertNil(line.color)
        XCTAssertEqual(line.dash, .dashed)
    }

    func testTimeReferenceLineCarriesAxisColorAndDash() {
        let line = LivelineReferenceLine(value: 5, axis: .time, label: "Open bell", color: .red, dash: .dotted)

        XCTAssertEqual(line.axis, .time)
        XCTAssertEqual(line.dash, .dotted)
        XCTAssertEqual(line.dash.pattern, [1, 3])
        XCTAssertEqual(LivelineAnnotationDash.solid.pattern, [])
    }

    func testBandBoundsNormalizeInvertedInputAndRejectNonFiniteInput() {
        XCTAssertEqual(LivelineReferenceBand(start: 8, end: 2).bounds, 2...8)
        XCTAssertEqual(LivelineReferenceBand(start: 2, end: 8).bounds, 2...8)
        XCTAssertEqual(LivelineReferenceBand(start: 4, end: 4).bounds, 4...4)
        XCTAssertNil(LivelineReferenceBand(start: .nan, end: 4).bounds)
        XCTAssertNil(LivelineReferenceBand(start: 4, end: .infinity).bounds)
    }

    // MARK: - Geometry

    func testValueLineMapsToYAndClipsOutsideThePlot() {
        // minValue 0, maxValue 10 across a 180pt plot starting at y = 20.
        XCTAssertEqual(LivelineAnnotationGeometry.position(
            for: LivelineReferenceLine(value: 5),
            layout: layout
        ) ?? -1, 110, accuracy: 0.001)

        XCTAssertNil(LivelineAnnotationGeometry.position(for: LivelineReferenceLine(value: 40), layout: layout))
        XCTAssertNil(LivelineAnnotationGeometry.position(for: LivelineReferenceLine(value: -40), layout: layout))
        XCTAssertNil(LivelineAnnotationGeometry.position(for: LivelineReferenceLine(value: .nan), layout: layout))
    }

    func testTimeLineMapsToXAndClipsOutsideThePlot() {
        // leftEdge 0, rightEdge 10 across a 280pt plot starting at x = 20.
        XCTAssertEqual(LivelineAnnotationGeometry.position(
            for: LivelineReferenceLine(value: 5, axis: .time),
            layout: layout
        ) ?? -1, 160, accuracy: 0.001)

        XCTAssertNil(LivelineAnnotationGeometry.position(
            for: LivelineReferenceLine(value: 50, axis: .time),
            layout: layout
        ))
        XCTAssertNil(LivelineAnnotationGeometry.position(
            for: LivelineReferenceLine(value: -50, axis: .time),
            layout: layout
        ))
    }

    func testValueBandSpansThePlotWidthBetweenItsBounds() throws {
        let rect = try XCTUnwrap(LivelineAnnotationGeometry.rect(
            for: LivelineReferenceBand(start: 2, end: 6),
            layout: layout
        ))

        XCTAssertEqual(rect.minX, layout.plotLeftX, accuracy: 0.001)
        XCTAssertEqual(rect.width, layout.chartWidth, accuracy: 0.001)
        XCTAssertEqual(rect.minY, layout.y(for: 6), accuracy: 0.001)
        XCTAssertEqual(rect.maxY, layout.y(for: 2), accuracy: 0.001)
    }

    func testTimeBandSpansThePlotHeightBetweenItsBounds() throws {
        let rect = try XCTUnwrap(LivelineAnnotationGeometry.rect(
            for: LivelineReferenceBand(axis: .time, start: 7, end: 3),
            layout: layout
        ))

        XCTAssertEqual(rect.minY, layout.padding.top, accuracy: 0.001)
        XCTAssertEqual(rect.height, layout.chartHeight, accuracy: 0.001)
        XCTAssertEqual(rect.minX, layout.x(for: 3), accuracy: 0.001)
        XCTAssertEqual(rect.maxX, layout.x(for: 7), accuracy: 0.001)
    }

    func testDegenerateAndOutOfRangeBandsAreSafe() throws {
        // Both edges equal: a hairline, never a zero-area rectangle.
        let degenerate = try XCTUnwrap(LivelineAnnotationGeometry.rect(
            for: LivelineReferenceBand(start: 5, end: 5),
            layout: layout
        ))
        XCTAssertEqual(degenerate.height, 0.5, accuracy: 0.001)

        let degenerateTime = try XCTUnwrap(LivelineAnnotationGeometry.rect(
            for: LivelineReferenceBand(axis: .time, start: 5, end: 5),
            layout: layout
        ))
        XCTAssertEqual(degenerateTime.width, 0.5, accuracy: 0.001)

        // Partly visible bands clamp to the plot instead of overflowing it.
        let clamped = try XCTUnwrap(LivelineAnnotationGeometry.rect(
            for: LivelineReferenceBand(start: -100, end: 4),
            layout: layout
        ))
        XCTAssertEqual(clamped.maxY, layout.bottomY, accuracy: 0.001)

        XCTAssertNil(LivelineAnnotationGeometry.rect(
            for: LivelineReferenceBand(start: 100, end: 200),
            layout: layout
        ))
        XCTAssertNil(LivelineAnnotationGeometry.rect(
            for: LivelineReferenceBand(axis: .time, start: 100, end: 200),
            layout: layout
        ))
        XCTAssertNil(LivelineAnnotationGeometry.rect(
            for: LivelineReferenceBand(start: .nan, end: 2),
            layout: layout
        ))
    }

    // MARK: - Configuration

    func testNormalizationDropsInvalidAnnotationsAndClampsOpacity() {
        var configuration = LivelineChartConfiguration(theme: .dark)
        configuration.referenceLines = [
            LivelineReferenceLine(value: 5),
            LivelineReferenceLine(value: .nan),
            LivelineReferenceLine(value: .infinity, axis: .time),
        ]
        configuration.referenceBands = [
            LivelineReferenceBand(start: 9, end: 1, opacity: 4),
            LivelineReferenceBand(start: .nan, end: 1),
        ]

        let normalized = configuration.normalizedForRendering()

        XCTAssertEqual(normalized.referenceLines.map(\.value), [5])
        XCTAssertEqual(normalized.referenceBands.count, 1)
        XCTAssertEqual(normalized.referenceBands.first?.start, 1)
        XCTAssertEqual(normalized.referenceBands.first?.end, 9)
        XCTAssertEqual(normalized.referenceBands.first?.opacity, 1)
    }

    /// Only the single `referenceLine` widens the automatic value range; the
    /// annotation arrays are draw-time only, which is what keeps them out of
    /// the prepared-chart cache key.
    func testAnnotationArraysDoNotWidenTheAutomaticValueRange() {
        let points = [
            LivelinePoint(time: 1, value: 4),
            LivelinePoint(time: 2, value: 6),
        ]
        let prepared = LivelinePreparedChart(
            primaryVisible: points,
            rangePoints: points,
            rangeOverride: nil,
            primaryValue: 6
        )

        var plain = LivelineChartConfiguration(theme: .dark)
        plain.grid = true
        var annotated = plain
        annotated.referenceLines = [LivelineReferenceLine(value: 1_000)]
        annotated.referenceBands = [LivelineReferenceBand(start: -500, end: -400)]
        var referenced = plain
        referenced.referenceLine = LivelineReferenceLine(value: 1_000)

        func range(_ configuration: LivelineChartConfiguration) -> ClosedRange<Double> {
            LivelineRenderer.valueRange(
                renderData: prepared,
                smoothValue: 6,
                visibleTimeRange: 0...3,
                config: configuration
            )
        }

        XCTAssertEqual(range(annotated), range(plain))
        XCTAssertGreaterThan(range(referenced).upperBound, range(plain).upperBound)
    }

    // MARK: - Rendering

    #if os(macOS)
    @MainActor
    func testChartWithAnnotationsRendersAFrame() throws {
        var configuration = LivelineChartConfiguration(theme: .dark, window: 10)
        configuration.fadeEffects = false
        configuration.referenceLines = [
            LivelineReferenceLine(value: 5, label: "Mid"),
            LivelineReferenceLine(value: 2, axis: .time, label: "Open", color: .red, dash: .dotted),
        ]
        configuration.referenceBands = [
            LivelineReferenceBand(start: 6, end: 4, label: "Target"),
            LivelineReferenceBand(axis: .time, start: 2.5, end: 2.5, label: "Now"),
        ]

        let chart = LivelineChart(
            data: [
                LivelinePoint(time: 1, value: 4),
                LivelinePoint(time: 2, value: 7),
                LivelinePoint(time: 3, value: 5),
            ],
            value: 5,
            configuration: configuration
        )

        let renderer = ImageRenderer(content: chart.frame(width: 320, height: 220))
        renderer.proposedSize = ProposedViewSize(width: 320, height: 220)
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.nsImage)
        XCTAssertGreaterThan(image.tiffRepresentation?.count ?? 0, 1_000)
    }
    #endif
}
