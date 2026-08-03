import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
/// The platform image type ``LivelineChartImageExporter`` produces: `UIImage`
/// on UIKit platforms, `NSImage` on macOS.
public typealias LivelineImage = UIImage
#elseif canImport(AppKit)
import AppKit
/// The platform image type ``LivelineChartImageExporter`` produces: `UIImage`
/// on UIKit platforms, `NSImage` on macOS.
public typealias LivelineImage = NSImage
#endif

/// Tells the chart that it is drawing one frame that will never be followed by
/// another, so time-based transitions must be shown at their destination
/// instead of at the start of their ramp.
///
/// A live chart reveals, eases its value range, and interpolates its line over
/// many frames. A still export renders exactly one, so without this the fade a
/// chart normally plays on appearance would be captured at its first
/// millisecond and the image would come out nearly blank.
struct LivelineSettledFrameKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var livelineRendersSettledFrame: Bool {
        get { self[LivelineSettledFrameKey.self] }
        set { self[LivelineSettledFrameKey.self] = newValue }
    }
}

/// Renders a ``LivelineChart`` to a still image or PNG data.
///
/// The chart is a live view: its animations, reveals, and pulses advance with
/// wall-clock time. Export therefore pins the renderer to an explicit
/// `elapsedTime` — the same deterministic clock the package's own screenshot
/// infrastructure uses — so nothing about the exported frame depends on when
/// the call happened.
///
/// Because an export is a single frame, transitions a live chart plays over
/// many frames — the appearance reveal, value-range easing, line interpolation
/// — are drawn already settled rather than at the start of their ramp, which is
/// what keeps a chart configured with `fadeEffects` from exporting blank.
/// `elapsedTime` drives the effects that remain a function of time on their own,
/// such as the dither shimmer.
///
/// ```swift
/// let exporter = LivelineChartImageExporter(
///     size: CGSize(width: 640, height: 320),
///     scale: 2,
///     elapsedTime: 3
/// )
/// let data = exporter.pngData(LivelineChart(data: points, value: latest))
/// ```
///
/// Rendering runs on the main actor because it walks a SwiftUI view tree.
/// Both entry points return `nil` when the platform cannot produce a
/// rasterization — a headless environment with no rendering service, or a size
/// that rounds to zero pixels.
///
/// Export is built on `ImageRenderer`, which is iOS 16 / macOS 13 / watchOS 9 —
/// one release above the rest of the package — so this type and its convenience
/// methods on ``LivelineChart`` carry an availability gate. Nothing else in the
/// library depends on it; charts render normally on the older releases.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
@MainActor
public struct LivelineChartImageExporter {
    /// The point size of the exported image.
    public var size: CGSize

    /// The pixel-per-point ratio. `2` matches a Retina screenshot.
    public var scale: CGFloat

    /// The renderer time, in seconds, to freeze the chart at.
    ///
    /// Continuously animated effects — the dither shimmer, the pulse — are
    /// evaluated at this instant instead of at the moment of the call.
    /// Transitions that ramp toward a destination are always exported settled,
    /// so this value does not control them.
    public var elapsedTime: TimeInterval

    /// An opaque color drawn behind the chart. `nil` exports a transparent
    /// background, which most PNG consumers handle but few chart embeds want.
    public var backgroundColor: Color?

    /// An explicit color scheme for the rendered view.
    ///
    /// Only matters for configurations using `LivelineThemeMode.automatic`,
    /// which resolves against the environment. `nil` renders in `.dark`, which
    /// matches the library's default theme and keeps an export reproducible
    /// regardless of where it runs.
    public var colorScheme: ColorScheme?

    /// Creates an exporter.
    ///
    /// - Parameters:
    ///   - size: The point size of the exported image.
    ///   - scale: The pixel-per-point ratio. Defaults to `2`.
    ///   - elapsedTime: The renderer time to freeze the chart at, in seconds.
    ///     Defaults to `0`, the chart's first frame.
    ///   - backgroundColor: An opaque backdrop, or `nil` for transparency.
    ///   - colorScheme: An explicit color scheme, or `nil` for `.dark`.
    public init(
        size: CGSize,
        scale: CGFloat = 2,
        elapsedTime: TimeInterval = 0,
        backgroundColor: Color? = nil,
        colorScheme: ColorScheme? = nil
    ) {
        self.size = size
        self.scale = scale
        self.elapsedTime = elapsedTime
        self.backgroundColor = backgroundColor
        self.colorScheme = colorScheme
    }

    /// Renders the chart to a platform image, or `nil` when rasterization fails.
    public func image(_ chart: LivelineChart) -> LivelineImage? {
        guard let renderer = makeRenderer(chart) else { return nil }
        #if canImport(UIKit)
        return renderer.uiImage
        #elseif canImport(AppKit)
        return renderer.nsImage
        #else
        return nil
        #endif
    }

    /// Renders the chart to a `CGImage`, or `nil` when rasterization fails.
    public func cgImage(_ chart: LivelineChart) -> CGImage? {
        makeRenderer(chart)?.cgImage
    }

    /// Renders the chart and encodes it as PNG data, or `nil` when
    /// rasterization or encoding fails.
    public func pngData(_ chart: LivelineChart) -> Data? {
        guard let cgImage = cgImage(chart) else { return nil }
        return Self.pngData(from: cgImage)
    }

    private var normalizedSize: CGSize? {
        guard size.width.isFinite, size.height.isFinite, size.width >= 1, size.height >= 1 else {
            return nil
        }
        return CGSize(
            width: min(size.width, LivelineScalar.maximumDrawingMagnitude),
            height: min(size.height, LivelineScalar.maximumDrawingMagnitude)
        )
    }

    private var normalizedScale: CGFloat {
        scale.isFinite ? min(max(scale, 0.1), 8) : 2
    }

    private func makeRenderer(_ chart: LivelineChart) -> ImageRenderer<AnyView>? {
        guard let size = normalizedSize else { return nil }
        let content = AnyView(
            ZStack {
                if let backgroundColor {
                    backgroundColor
                }
                chart
            }
            .frame(width: size.width, height: size.height)
            .livelineSnapshotElapsedTime(elapsedTime)
            .environment(\.livelineRendersSettledFrame, true)
            .environment(\.colorScheme, colorScheme ?? .dark)
        )
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
        renderer.scale = normalizedScale
        renderer.isOpaque = backgroundColor != nil
        return renderer
    }

    /// PNG-encodes a `CGImage` through ImageIO, which every Liveline platform
    /// ships — unlike `UIImage.pngData()`, which has no AppKit counterpart.
    static func pngData(from image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public extension LivelineChart {
    /// Renders this chart to a platform image at a pinned renderer time.
    ///
    /// A convenience over ``LivelineChartImageExporter``; see that type for the
    /// meaning of each parameter and for the reproducibility guarantee.
    @MainActor
    func exportedImage(
        size: CGSize,
        scale: CGFloat = 2,
        elapsedTime: TimeInterval = 0,
        backgroundColor: Color? = nil,
        colorScheme: ColorScheme? = nil
    ) -> LivelineImage? {
        LivelineChartImageExporter(
            size: size,
            scale: scale,
            elapsedTime: elapsedTime,
            backgroundColor: backgroundColor,
            colorScheme: colorScheme
        ).image(self)
    }

    /// Renders this chart to PNG data at a pinned renderer time.
    @MainActor
    func exportedPNGData(
        size: CGSize,
        scale: CGFloat = 2,
        elapsedTime: TimeInterval = 0,
        backgroundColor: Color? = nil,
        colorScheme: ColorScheme? = nil
    ) -> Data? {
        LivelineChartImageExporter(
            size: size,
            scale: scale,
            elapsedTime: elapsedTime,
            backgroundColor: backgroundColor,
            colorScheme: colorScheme
        ).pngData(self)
    }
}
