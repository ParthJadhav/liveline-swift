import CoreGraphics
import Foundation

/// A chart-wide rendering style applied uniformly to every Liveline chart kind.
public enum LivelineChartStyle {
    /// Liveline's regular vector rendering.
    case standard

    /// Ordered-dither rendering inspired by Dither Kit.
    case dither(LivelineDitherStyle = LivelineDitherStyle())
}

/// The ordered-dither texture used by ``LivelineChartStyle/dither(_:)``.
public enum LivelineDitherVariant: Sendable {
    /// A Bayer-matrix fade that becomes denser toward the bottom of the plot.
    case gradient

    /// Open, separated pixels with transparent gaps.
    case dotted

    /// Diagonal pixel hatching.
    case hatched

    /// A solid chart with bloom and optional pixel sparkles.
    case solid
}

/// The coloured glow drawn behind a dithered chart.
public enum LivelineDitherBloom: Sendable {
    case off
    case low
    case high
    case aura
}

/// Configures Liveline's universal ordered-dither chart effect.
///
/// The defaults mirror Dither Kit's two-point cells, gradient texture, subtle
/// bloom, and winking colour sparkles. Set `animated` to `false` for a stable
/// texture; Liveline also disables dither motion automatically when Reduce
/// Motion is enabled.
public struct LivelineDitherStyle: Sendable {
    public var variant: LivelineDitherVariant
    public var bloom: LivelineDitherBloom
    public var cellSize: CGFloat
    public var intensity: Double
    public var sparkleDensity: Double
    public var animationSpeed: Double
    public var maximumFramesPerSecond: Double
    public var animated: Bool

    public init(
        variant: LivelineDitherVariant = .gradient,
        bloom: LivelineDitherBloom = .low,
        cellSize: CGFloat = 2,
        intensity: Double = 1,
        sparkleDensity: Double = 0.018,
        animationSpeed: Double = 1,
        maximumFramesPerSecond: Double = 30,
        animated: Bool = true
    ) {
        self.variant = variant
        self.bloom = bloom
        self.cellSize = cellSize
        self.intensity = intensity
        self.sparkleDensity = sparkleDensity
        self.animationSpeed = animationSpeed
        self.maximumFramesPerSecond = maximumFramesPerSecond
        self.animated = animated
    }
}

extension LivelineChartStyle {
    var requiresContinuousFrames: Bool {
        guard case let .dither(style) = self else { return false }
        return style.animated && (style.bloom != .off || style.sparkleDensity > 0)
    }

    func normalizedForRendering() -> LivelineChartStyle {
        guard case let .dither(style) = self else { return .standard }
        var normalized = style
        normalized.cellSize = style.cellSize.isFinite
            ? min(max(style.cellSize, 1), 16)
            : 2
        normalized.intensity = style.intensity.isFinite
            ? min(max(style.intensity, 0), 1)
            : 1
        normalized.sparkleDensity = style.sparkleDensity.isFinite
            ? min(max(style.sparkleDensity, 0), 0.2)
            : 0.018
        normalized.animationSpeed = style.animationSpeed.isFinite
            ? min(max(style.animationSpeed, 0), 8)
            : 1
        normalized.maximumFramesPerSecond = style.maximumFramesPerSecond.isFinite
            ? min(max(style.maximumFramesPerSecond, 1), 120)
            : 30
        return .dither(normalized)
    }

    func respectingReducedMotion(_ enabled: Bool) -> LivelineChartStyle {
        guard enabled, case let .dither(style) = self else { return self }
        var reduced = style
        reduced.animated = false
        return .dither(reduced)
    }

    var preferredFrameInterval: TimeInterval? {
        guard case let .dither(style) = self, style.animated else { return nil }
        return 1 / style.maximumFramesPerSecond
    }
}
