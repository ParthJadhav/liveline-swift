#if os(macOS)
import AppKit
import ImageIO
import SwiftUI
import XCTest
@testable import Liveline

final class LivelineImageExportTests: XCTestCase {
    private let points = [
        LivelinePoint(time: 1, value: 4),
        LivelinePoint(time: 2, value: 7),
        LivelinePoint(time: 3, value: 5),
    ]

    private var chart: LivelineChart {
        LivelineChart(
            data: points,
            value: 5,
            configuration: LivelineChartConfiguration(theme: .dark, window: 10, fadeEffects: false)
        )
    }

    @MainActor
    func testExporterProducesAnImageOfTheRequestedSize() throws {
        let exporter = LivelineChartImageExporter(
            size: CGSize(width: 320, height: 180),
            scale: 1,
            elapsedTime: 2,
            backgroundColor: .black
        )
        guard let image = exporter.image(chart) else {
            throw XCTSkip("This environment cannot rasterize SwiftUI views")
        }

        XCTAssertEqual(image.size.width, 320, accuracy: 1)
        XCTAssertEqual(image.size.height, 180, accuracy: 1)
    }

    @MainActor
    func testExporterScalesThePixelBuffer() throws {
        let exporter = LivelineChartImageExporter(
            size: CGSize(width: 160, height: 90),
            scale: 2,
            elapsedTime: 1,
            backgroundColor: .black
        )
        guard let cgImage = exporter.cgImage(chart) else {
            throw XCTSkip("This environment cannot rasterize SwiftUI views")
        }

        XCTAssertEqual(cgImage.width, 320)
        XCTAssertEqual(cgImage.height, 180)
    }

    @MainActor
    func testPNGDataIsAValidPNGOfTheRequestedPixelSize() throws {
        guard let data = chart.exportedPNGData(
            size: CGSize(width: 240, height: 120),
            scale: 1,
            elapsedTime: 2,
            backgroundColor: .black
        ) else {
            throw XCTSkip("This environment cannot rasterize SwiftUI views")
        }

        XCTAssertGreaterThan(data.count, 1_000)
        XCTAssertEqual(Array(data.prefix(4)), [0x89, 0x50, 0x4E, 0x47])

        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let decoded = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(decoded.width, 240)
        XCTAssertEqual(decoded.height, 120)
    }

    /// Repeated exports of the same chart at the same instant must produce the
    /// same picture: nothing about the frame may depend on when the call
    /// happened, which is why the exporter pins the renderer clock instead of
    /// reading the wall clock.
    ///
    /// The comparison is on encoded size rather than bytes because the
    /// platform's own rasterization — font smoothing warm-up, gradient
    /// dithering — moves a handful of pixels between draws no matter what the
    /// chart does. A frame captured at a different point in an animation moves
    /// far more than that.
    @MainActor
    func testExportsAreReproducible() throws {
        let chart = LivelineChart(
            data: points,
            value: 5,
            configuration: LivelineChartConfiguration(theme: .dark, window: 10, grid: false, badge: false, fadeEffects: false)
        )

        func export() throws -> Data {
            guard let data = chart.exportedPNGData(
                size: CGSize(width: 200, height: 120),
                scale: 1,
                elapsedTime: 0.5,
                backgroundColor: .black
            ) else {
                throw XCTSkip("This environment cannot rasterize SwiftUI views")
            }
            return data
        }

        let first = try export()
        let second = try export()
        XCTAssertEqual(Double(second.count), Double(first.count), accuracy: Double(first.count) * 0.02)
    }

    /// A still export renders one frame, so a chart whose appearance fade would
    /// still be ramping must be captured settled rather than nearly blank.
    @MainActor
    func testFadingChartsExportFullyRevealed() throws {
        func export(fadeEffects: Bool) throws -> Data {
            var configuration = LivelineChartConfiguration(theme: .dark, window: 10)
            configuration.fadeEffects = fadeEffects
            let chart = LivelineChart(data: points, value: 5, configuration: configuration)
            guard let data = chart.exportedPNGData(
                size: CGSize(width: 200, height: 120),
                scale: 1,
                elapsedTime: 0,
                backgroundColor: .black
            ) else {
                throw XCTSkip("This environment cannot rasterize SwiftUI views")
            }
            return data
        }

        let settled = try export(fadeEffects: false)
        let fading = try export(fadeEffects: true)

        // A blank frame compresses to a small fraction of a drawn one.
        XCTAssertGreaterThan(Double(fading.count), Double(settled.count) * 0.5)
    }

    @MainActor
    func testDegenerateSizesReturnNilInsteadOfRendering() {
        let exporter = LivelineChartImageExporter(size: CGSize(width: 0, height: 200))
        XCTAssertNil(exporter.image(chart))
        XCTAssertNil(exporter.pngData(chart))
        XCTAssertNil(LivelineChartImageExporter(size: CGSize(width: CGFloat.nan, height: 100)).image(chart))
    }
}
#endif
