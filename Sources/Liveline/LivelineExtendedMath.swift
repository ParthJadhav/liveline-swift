import CoreGraphics
import Foundation

struct LivelineStackSegment: Equatable {
    var lower: Double
    var upper: Double
}

extension LivelineMath {
    static func stackedSegments(values: [Double], mode: LivelineStackMode) -> [LivelineStackSegment] {
        let finite = values.map { $0.isFinite ? $0 : 0 }
        let positiveTotal = finite.filter { $0 > 0 }.reduce(0, +)
        let negativeTotal = abs(finite.filter { $0 < 0 }.reduce(0, +))
        var positive = 0.0
        var negative = 0.0

        return finite.map { rawValue in
            let value: Double
            switch mode {
            case .standard:
                value = rawValue
            case .normalized:
                if rawValue > 0 {
                    value = positiveTotal > 0 ? rawValue / positiveTotal : 0
                } else if rawValue < 0 {
                    value = negativeTotal > 0 ? rawValue / negativeTotal : 0
                } else {
                    value = 0
                }
            }

            if value >= 0 {
                let lower = positive
                positive += value
                return LivelineStackSegment(lower: lower, upper: positive)
            }

            let upper = negative
            negative += value
            return LivelineStackSegment(lower: negative, upper: upper)
        }
    }

    static func stackedRangePoints(points: [LivelineStackedPoint], mode: LivelineStackMode) -> [LivelinePoint] {
        points.flatMap { point in
            let segments = stackedSegments(values: point.values, mode: mode)
            let lower = min(segments.map(\.lower).min() ?? 0, segments.map(\.upper).min() ?? 0, 0)
            let upper = max(segments.map(\.lower).max() ?? 0, segments.map(\.upper).max() ?? 0, 0)
            return [
                LivelinePoint(time: point.time, value: lower),
                LivelinePoint(time: point.time, value: upper),
            ]
        }
    }

    static func stackedPrimaryValue(point: LivelineStackedPoint?, mode: LivelineStackMode) -> Double {
        guard let point else { return 0 }
        switch mode {
        case .standard:
            return point.total
        case .normalized:
            if point.values.contains(where: { $0 > 0 }) { return 1 }
            if point.values.contains(where: { $0 < 0 }) { return -1 }
            return 0
        }
    }

    static func gaugeProgress(value: Double, range: ClosedRange<Double>) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return value >= range.upperBound ? 1 : 0 }
        return clamp((value - range.lowerBound) / span, 0, 1)
    }

    static func heatmapOpacity(
        value: Double,
        minimum: Double,
        maximum: Double,
        minimumOpacity: Double,
        maximumOpacity: Double
    ) -> Double {
        guard maximum > minimum else { return (minimumOpacity + maximumOpacity) / 2 }
        let progress = clamp((value - minimum) / (maximum - minimum), 0, 1)
        return minimumOpacity + progress * (maximumOpacity - minimumOpacity)
    }

    static func polarPoint(center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        CGPoint(
            x: center.x + CGFloat(cos(angle)) * radius,
            y: center.y + CGFloat(sin(angle)) * radius
        )
    }
}
