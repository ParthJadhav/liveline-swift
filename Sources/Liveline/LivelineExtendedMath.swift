import CoreGraphics
import Foundation

struct LivelineStackSegment: Equatable {
    var lower: Double
    var upper: Double
}

struct LivelineGaugeGeometry: Equatable {
    var center: CGPoint
    var radius: CGFloat
    var visualBounds: CGRect
}

extension LivelineMath {
    static func resolvedPadding(
        _ padding: LivelinePadding,
        badgeEnabled: Bool,
        showValueAxis: Bool,
        showTimeAxis: Bool
    ) -> LivelineResolvedPadding {
        LivelineResolvedPadding(
            top: padding.top ?? 12,
            right: padding.right ?? (badgeEnabled ? 80 : showValueAxis ? 54 : 12),
            bottom: padding.bottom ?? (showTimeAxis ? 28 : 12),
            left: padding.left ?? 12
        )
    }

    static func gaugeGeometry(
        in rect: CGRect,
        startAngleDegrees: Double,
        sweepDegrees: Double,
        lineWidth: CGFloat,
        hasOuterMarks: Bool,
        showsValue: Bool
    ) -> LivelineGaugeGeometry {
        let start = startAngleDegrees.isFinite ? startAngleDegrees : 150
        let sweep = clamp(abs(sweepDegrees.isFinite ? sweepDegrees : 240), 1, 359.5)
        let sampleCount = max(Int(ceil(sweep / 2)), 2)
        var minimumX = Double.infinity
        var maximumX = -Double.infinity
        var minimumY = Double.infinity
        var maximumY = -Double.infinity

        for index in 0...sampleCount {
            let progress = Double(index) / Double(sampleCount)
            let angle = (start + sweep * progress) * Double.pi / 180
            minimumX = min(minimumX, cos(angle))
            maximumX = max(maximumX, cos(angle))
            minimumY = min(minimumY, sin(angle))
            maximumY = max(maximumY, sin(angle))
        }

        if showsValue {
            minimumX = min(minimumX, -0.30)
            maximumX = max(maximumX, 0.30)
            minimumY = min(minimumY, -0.16)
            maximumY = max(maximumY, 0.30)
        }

        let unitWidth = max(maximumX - minimumX, 0.1)
        let unitHeight = max(maximumY - minimumY, 0.1)
        let outset = max(lineWidth, 1) / 2 + (hasOuterMarks ? 14 : 3)
        let available = rect.insetBy(dx: outset, dy: outset)
        let fittingRadius = min(
            max(available.width, 1) / CGFloat(unitWidth),
            max(available.height, 1) / CGFloat(unitHeight)
        )
        let radius = max(1, min(fittingRadius, min(rect.width, rect.height) * 0.43))
        let unitMidX = (minimumX + maximumX) / 2
        let unitMidY = (minimumY + maximumY) / 2
        let center = CGPoint(
            x: rect.midX - CGFloat(unitMidX) * radius,
            y: rect.midY - CGFloat(unitMidY) * radius
        )
        let visualBounds = CGRect(
            x: center.x + CGFloat(minimumX) * radius,
            y: center.y + CGFloat(minimumY) * radius,
            width: CGFloat(unitWidth) * radius,
            height: CGFloat(unitHeight) * radius
        )

        return LivelineGaugeGeometry(center: center, radius: radius, visualBounds: visualBounds)
    }

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
