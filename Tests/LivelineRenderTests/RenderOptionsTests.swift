#if os(macOS)
import AVFoundation
import CoreGraphics
import XCTest
@testable import LivelineRender

final class RenderOptionsTests: XCTestCase {
    func testMinimumVideoDimensionsAreSupported() throws {
        var options = RenderOptions()
        options.width = 320
        options.height = 180

        XCTAssertNoThrow(try options.validate())
    }

    func testDimensionsTooSmallForAUsableChartAreRejected() {
        var options = RenderOptions()
        options.width = 160
        options.height = 90

        XCTAssertThrowsError(try options.validate()) { error in
            XCTAssertTrue(error.localizedDescription.contains("from 320 through 8192"))
            XCTAssertTrue(error.localizedDescription.contains("from 180 through 8192"))
        }
    }

    func testSubframeDurationIsRejected() {
        var options = RenderOptions()
        options.fps = 30
        options.duration = 0.01

        XCTAssertThrowsError(try options.validate()) { error in
            XCTAssertTrue(error.localizedDescription.contains("at least two frames"))
        }
    }

    func testSingleFrameDurationIsRejectedToPreserveVideoFrameRate() {
        var options = RenderOptions()
        options.fps = 30
        options.duration = 0.0333333333333333

        XCTAssertThrowsError(try options.validate())
    }

    func testTwoFrameDurationIsAccepted() {
        var options = RenderOptions()
        options.fps = 30
        options.duration = 0.0666666666666666

        XCTAssertNoThrow(try options.validate())
        XCTAssertEqual(options.frameCount, 2)
    }

    func testFrameCountRoundsUpWithoutFloatingPointOverrun() {
        var options = RenderOptions()
        options.fps = 30
        options.duration = 0.1

        XCTAssertEqual(options.frameCount, 3)

        options.duration = 0.1001
        XCTAssertEqual(options.frameCount, 4)
    }

    @MainActor
    func testMinimumSupportedExportsContainPlottedChartSpans() throws {
        for chart in [RenderChart.line, .multi, .radar, .donut] {
            let image = try exportedFirstFrame(chart: chart)
            let plotRegion = CGRect(
                x: CGFloat(image.width) * 0.08,
                y: CGFloat(image.height) * 0.12,
                width: CGFloat(image.width) * 0.68,
                height: CGFloat(image.height) * 0.68
            )
            let bounds = try XCTUnwrap(
                chromaticChartBounds(in: image, searchRegion: plotRegion),
                "No chart-colored pixels for \(chart.rawValue)"
            )
            let minimumWidthFraction: CGFloat = switch chart {
            case .line, .multi: 0.40
            default: 0.10
            }
            XCTAssertGreaterThan(
                bounds.width,
                plotRegion.width * minimumWidthFraction,
                "Chart-colored content is too narrow for \(chart.rawValue): \(bounds)"
            )
            XCTAssertGreaterThan(
                bounds.height,
                plotRegion.height * 0.08,
                "Chart-colored content is too short for \(chart.rawValue): \(bounds)"
            )
        }
    }

    @MainActor
    func testAssetMetadataAlwaysReportsDefinedFrameRateAndDuration() async throws {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("liveline-render-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        var options = RenderOptions()
        options.width = 320
        options.height = 180
        options.fps = 30
        options.duration = 2 / 30
        options.styleName = "standard"
        options.animatedDither = false
        options.output = outputURL.path
        try MP4Exporter(options: options).export()

        let asset = AVURLAsset(url: outputURL)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(tracks.first)
        let nominalFrameRate = try await track.load(.nominalFrameRate)
        let duration = try await asset.load(.duration)
        XCTAssertEqual(nominalFrameRate, 30, accuracy: 0.001)
        XCTAssertEqual(CMTimeGetSeconds(duration), 2 / 30, accuracy: 0.000_001)
    }

    @MainActor
    func testFFprobeReportsDefinedFrameRateAndDurationWhenInstalled() throws {
        guard let ffprobeURL = executable(named: "ffprobe") else {
            throw XCTSkip("ffprobe is not installed")
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("liveline-render-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        var options = RenderOptions()
        options.width = 320
        options.height = 180
        options.fps = 30
        options.duration = 2 / 30
        options.styleName = "standard"
        options.animatedDither = false
        options.output = outputURL.path
        try MP4Exporter(options: options).export()

        let output = Pipe()
        let process = Process()
        process.executableURL = ffprobeURL
        process.arguments = [
            "-v", "error",
            "-select_streams", "v:0",
            "-show_entries", "stream=r_frame_rate,avg_frame_rate,nb_frames,duration",
            "-of", "default=noprint_wrappers=1",
            outputURL.path,
        ]
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()

        let metadata = String(
            decoding: output.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        )
        XCTAssertEqual(process.terminationStatus, 0, metadata)
        let fields = metadataFields(metadata)
        XCTAssertEqual(try rational(try XCTUnwrap(fields["r_frame_rate"])), 30, accuracy: 0.001)
        XCTAssertEqual(try rational(try XCTUnwrap(fields["avg_frame_rate"])), 30, accuracy: 0.001)
        XCTAssertEqual(
            try XCTUnwrap(Double(try XCTUnwrap(fields["duration"]))),
            2 / 30,
            accuracy: 0.000_001
        )
        XCTAssertEqual(try XCTUnwrap(Int(try XCTUnwrap(fields["nb_frames"]))), 2)
    }

    @MainActor
    private func exportedFirstFrame(chart: RenderChart) throws -> CGImage {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("liveline-render-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        var options = RenderOptions()
        options.chart = chart
        options.values = [20, 48, 34, 72, 58, 90]
        options.width = 320
        options.height = 180
        options.fps = 30
        options.duration = 2 / 30
        options.styleName = "standard"
        options.animatedDither = false
        options.grid = false
        options.fill = false
        options.accentHex = "FF2D55"
        options.backgroundHex = "000000"
        options.output = outputURL.path
        try options.validate()
        try MP4Exporter(options: options).export()

        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: outputURL))
        generator.appliesPreferredTrackTransform = true
        return try generator.copyCGImage(at: .zero, actualTime: nil)
    }

    private func chromaticChartBounds(
        in image: CGImage,
        searchRegion: CGRect
    ) -> CGRect? {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let region = searchRegion
            .intersection(CGRect(x: 0, y: 0, width: width, height: height))
            .integral
        guard !region.isNull, !region.isEmpty else { return nil }
        let lowerX = max(0, Int(region.minX))
        let upperX = min(width, Int(region.maxX))
        let lowerY = max(0, Int(region.minY))
        let upperY = min(height, Int(region.maxY))
        var minimumX = width
        var maximumX = -1
        var minimumY = height
        var maximumY = -1
        for y in lowerY..<upperY {
            for x in lowerX..<upperX {
                let offset = (y * width + x) * 4
                let red = Int(pixels[offset])
                let green = Int(pixels[offset + 1])
                let blue = Int(pixels[offset + 2])
                let brightest = max(red, green, blue)
                let darkest = min(red, green, blue)
                guard brightest > 80, brightest - darkest > 36 else {
                    continue
                }
                minimumX = min(minimumX, x)
                maximumX = max(maximumX, x)
                minimumY = min(minimumY, y)
                maximumY = max(maximumY, y)
            }
        }

        guard maximumX >= minimumX, maximumY >= minimumY else { return nil }
        return CGRect(
            x: minimumX,
            y: minimumY,
            width: maximumX - minimumX + 1,
            height: maximumY - minimumY + 1
        )
    }

    private func executable(named name: String) -> URL? {
        let output = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        guard process.terminationStatus == 0 else { return nil }
        let path = String(
            decoding: output.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : URL(fileURLWithPath: path)
    }

    private func metadataFields(_ metadata: String) -> [String: String] {
        Dictionary(uniqueKeysWithValues: metadata.split(whereSeparator: \.isNewline).compactMap { line in
            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }
            return (parts[0], parts[1])
        })
    }

    private func rational(_ value: String) throws -> Double {
        let parts = value.split(separator: "/", maxSplits: 1).compactMap { Double($0) }
        guard parts.count == 2, parts[1] != 0 else {
            throw RenderCommandError.message("Invalid rational metadata value: \(value)")
        }
        return parts[0] / parts[1]
    }
}
#endif
