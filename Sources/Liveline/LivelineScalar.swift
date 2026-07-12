import Foundation

enum LivelineScalar {
    /// Keeps value arithmetic comfortably below `Double` overflow while
    /// remaining far beyond any meaningful chart domain.
    static let maximumValueMagnitude = 1e150
    /// Preserves sub-second precision and keeps formatted dates in a range
    /// Foundation calendars can represent predictably.
    static let maximumTimeMagnitude: TimeInterval = 100_000_000_000
    static let maximumDrawingMagnitude: CGFloat = 10_000
    static let maximumDiscreteIndex = 1_024

    static func value(_ value: Double, fallback: Double = 0) -> Double {
        let candidate = value.isFinite ? value : (fallback.isFinite ? fallback : 0)
        return min(max(candidate, -maximumValueMagnitude), maximumValueMagnitude)
    }

    static func time(_ time: TimeInterval) -> TimeInterval? {
        guard time.isFinite else { return nil }
        return min(max(time, -maximumTimeMagnitude), maximumTimeMagnitude)
    }

    static func positiveDuration(_ duration: TimeInterval, fallback: TimeInterval) -> TimeInterval {
        guard duration.isFinite, duration > 0 else {
            let fallback = fallback.isFinite && fallback > 0 ? fallback : 1
            return min(fallback, maximumTimeMagnitude)
        }
        return min(duration, maximumTimeMagnitude)
    }

    static func nondegenerateRange(
        lower: Double,
        upper: Double,
        fallback: ClosedRange<Double>
    ) -> ClosedRange<Double> {
        guard lower.isFinite, upper.isFinite else { return fallback }
        let lower = value(lower)
        let upper = value(upper)
        guard lower <= upper else { return fallback }
        if lower < upper { return lower...upper }

        let expandedLower = lower - 0.5
        let expandedUpper = upper + 0.5
        if expandedLower.isFinite, expandedUpper.isFinite, expandedLower < expandedUpper {
            return expandedLower...expandedUpper
        }
        if lower.nextDown.isFinite { return lower.nextDown...lower }
        if upper.nextUp.isFinite { return upper...upper.nextUp }
        return fallback
    }

    static func quantized(_ value: Double, scale: Double) -> Double {
        guard value.isFinite, scale.isFinite, scale > 0 else { return 0 }
        let scaled = value * scale
        return scaled.isFinite ? scaled.rounded() / scale : value
    }
}

extension BinaryFloatingPoint {
    func livelineFinite(or fallback: Self) -> Self {
        isFinite ? self : fallback
    }

    func livelineAtLeast(_ minimum: Self, fallback: Self) -> Self {
        guard isFinite else { return fallback }
        return Swift.min(Swift.max(self, minimum), Self(10_000))
    }

    func livelineClamped(_ lower: Self, _ upper: Self, fallback: Self) -> Self {
        guard isFinite else { return fallback }
        return Swift.min(Swift.max(self, lower), upper)
    }
}
