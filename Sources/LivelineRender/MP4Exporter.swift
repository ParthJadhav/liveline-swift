#if os(macOS)
import AppKit
import AVFoundation
import CoreVideo
import Foundation
import SwiftUI

@MainActor
final class MP4Exporter {
    private let options: RenderOptions
    private let hostingView: NSHostingView<ChartScene>
    private let bitmap: NSBitmapImageRep
    private let window: NSWindow

    init(options: RenderOptions) throws {
        self.options = options
        hostingView = NSHostingView(rootView: ChartScene(options: options, elapsedTime: 0))
        hostingView.frame = CGRect(x: 0, y: 0, width: options.width, height: options.height)
        hostingView.autoresizingMask = []
        window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.orderOut(nil)

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: options.width,
            pixelsHigh: options.height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bitmapFormat: [],
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw RenderCommandError.message("Could not allocate the offscreen render surface")
        }
        bitmap.size = NSSize(width: options.width, height: options.height)
        self.bitmap = bitmap
    }

    func export() throws {
        let outputURL = options.outputURL
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let bitrate = max(2_000_000, options.width * options.height * options.fps * 2 / 15)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: options.width,
            AVVideoHeightKey: options.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoExpectedSourceFrameRateKey: options.fps,
                AVVideoMaxKeyFrameIntervalKey: options.fps * 2,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ],
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false

        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: options.width,
            kCVPixelBufferHeightKey as String: options.height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attributes)
        guard writer.canAdd(input) else { throw RenderCommandError.message("AVAssetWriter rejected the video input") }
        writer.add(input)

        guard writer.startWriting() else { throw writerError(writer, fallback: "Could not start the MP4 writer") }
        writer.startSession(atSourceTime: .zero)

        let frameCount = max(1, Int((options.duration * Double(options.fps)).rounded()))
        for frameIndex in 0..<frameCount {
            try autoreleasepool {
                let elapsed = Double(frameIndex) / Double(options.fps)
                let image = try renderFrame(elapsedTime: elapsed)
                let pixelBuffer = try makePixelBuffer(from: image, adaptor: adaptor)

                while !input.isReadyForMoreMediaData {
                    if writer.status == .failed { throw writerError(writer, fallback: "MP4 encoding failed") }
                    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.002))
                }

                let time = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(options.fps))
                guard adaptor.append(pixelBuffer, withPresentationTime: time) else {
                    throw writerError(writer, fallback: "Could not append frame \(frameIndex)")
                }
            }

            if frameIndex == 0 || frameIndex + 1 == frameCount || (frameIndex + 1).isMultiple(of: max(options.fps, 1)) {
                progress("Rendered \(frameIndex + 1)/\(frameCount) frames")
            }
        }

        input.markAsFinished()
        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting { semaphore.signal() }
        while semaphore.wait(timeout: .now() + 0.01) == .timedOut {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.005))
        }
        guard writer.status == .completed else { throw writerError(writer, fallback: "Could not finalize the MP4") }
        progress("Wrote \(outputURL.path)")
    }

    private func renderFrame(elapsedTime: TimeInterval) throws -> CGImage {
        hostingView.rootView = ChartScene(options: options, elapsedTime: elapsedTime)
        hostingView.layoutSubtreeIfNeeded()

        // Liveline's deterministic snapshot clock integrates at 60 Hz. Extra
        // display passes let a lower output frame rate retain the same native
        // animation timing without depending on wall-clock scheduling.
        let integrationPasses = max(1, Int(ceil(60 / Double(options.fps))))
        for _ in 0..<integrationPasses {
            hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        }

        guard let image = bitmap.cgImage else {
            throw RenderCommandError.message("Could not read a rendered chart frame")
        }
        return image
    }

    private func makePixelBuffer(
        from image: CGImage,
        adaptor: AVAssetWriterInputPixelBufferAdaptor
    ) throws -> CVPixelBuffer {
        var optionalBuffer: CVPixelBuffer?
        guard let pool = adaptor.pixelBufferPool,
              CVPixelBufferPoolCreatePixelBuffer(nil, pool, &optionalBuffer) == kCVReturnSuccess,
              let buffer = optionalBuffer
        else {
            throw RenderCommandError.message("Could not allocate a video frame")
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            throw RenderCommandError.message("Video frame has no writable storage")
        }

        guard let context = CGContext(
            data: baseAddress,
            width: options.width,
            height: options.height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            throw RenderCommandError.message("Could not create the video drawing context")
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: options.width, height: options.height))
        return buffer
    }

    private func writerError(_ writer: AVAssetWriter, fallback: String) -> RenderCommandError {
        .message(writer.error?.localizedDescription ?? fallback)
    }

    private func progress(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}
#endif
