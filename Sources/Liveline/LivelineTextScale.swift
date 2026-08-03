import CoreGraphics
import SwiftUI

/// Canvas-drawn text cannot participate in Dynamic Type the way `Text` in a
/// view hierarchy does: `GraphicsContext.draw` resolves whatever font it is
/// handed. The chart therefore reads the environment's type size once per body
/// evaluation and threads this multiplier down the render pipeline, where every
/// hardcoded point size passes through `font(_:weight:design:)`.
///
/// Standard type sizes resolve to a factor of exactly `1`, so charts that never
/// see an accessibility size render byte-for-byte as before.
struct LivelineTextScale: Equatable, Hashable {
    static let standard = LivelineTextScale(factor: 1)

    /// Growth beyond this stops being legible inside a fixed-height chart: axis
    /// labels start colliding faster than the collision pass can thin them out.
    static let maximumFactor: CGFloat = 1.6

    var factor: CGFloat

    init(factor: CGFloat) {
        self.factor = factor.isFinite
            ? min(max(factor, 1), LivelineTextScale.maximumFactor)
            : 1
    }

    var isStandard: Bool {
        factor == 1
    }

    /// Scales a text-derived metric — a line height, a label inset, the gap the
    /// collision pass requires between two axis labels.
    func scaled(_ value: CGFloat) -> CGFloat {
        value * factor
    }

    func font(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> Font {
        Font.system(size: size * factor, weight: weight, design: design)
    }

    /// Standard sizes stay at `1`; the accessibility sizes ramp monotonically to
    /// `maximumFactor`. The curve is deliberately shallower than Dynamic Type's
    /// own body-text ramp because chart text shares a fixed canvas with marks.
    static func resolve(_ size: DynamicTypeSize) -> LivelineTextScale {
        switch size {
        case .xSmall, .small, .medium, .large:
            return LivelineTextScale(factor: 1)
        case .xLarge:
            return LivelineTextScale(factor: 1.06)
        case .xxLarge:
            return LivelineTextScale(factor: 1.12)
        case .xxxLarge:
            return LivelineTextScale(factor: 1.18)
        case .accessibility1:
            return LivelineTextScale(factor: 1.3)
        case .accessibility2:
            return LivelineTextScale(factor: 1.4)
        case .accessibility3:
            return LivelineTextScale(factor: 1.5)
        case .accessibility4:
            return LivelineTextScale(factor: 1.55)
        case .accessibility5:
            return LivelineTextScale(factor: LivelineTextScale.maximumFactor)
        @unknown default:
            return LivelineTextScale(factor: size.isAccessibilitySize ? LivelineTextScale.maximumFactor : 1)
        }
    }
}
