import CoreGraphics
import Foundation
import SwiftUI

struct LivelineWaterfallSegment: Equatable {
    var time: TimeInterval
    var start: Double
    var end: Double
    var delta: Double
}

enum LivelineMath {
    static func barRangePoints(points: [LivelinePoint], baseline: Double) -> [LivelinePoint] {
        guard let last = points.last else { return [] }
        return points + [LivelinePoint(time: last.time, value: baseline)]
    }

    static func clamp<T: Comparable>(_ value: T, _ lower: T, _ upper: T) -> T {
        min(max(value, lower), upper)
    }

    static func verticalRangeMarkerRect(
        x: CGFloat,
        upperY: CGFloat,
        lowerY: CGFloat,
        width: CGFloat
    ) -> CGRect {
        let resolvedWidth = max(width, 1)
        let midpoint = (upperY + lowerY) / 2
        let height = max(abs(lowerY - upperY), resolvedWidth)
        return CGRect(
            x: x - resolvedWidth / 2,
            y: midpoint - height / 2,
            width: resolvedWidth,
            height: height
        )
    }

    static func uniqueFormattedGridLabelKeys(
        candidates: [(key: Int, value: Double, priority: Double)],
        formatValue: (Double) -> String
    ) -> Set<Int> {
        var selections: [String: (key: Int, priority: Double)] = [:]

        for candidate in candidates {
            let label = formatValue(candidate.value)
            guard let current = selections[label] else {
                selections[label] = (candidate.key, candidate.priority)
                continue
            }

            if candidate.priority > current.priority
                || (candidate.priority == current.priority && candidate.key < current.key) {
                selections[label] = (candidate.key, candidate.priority)
            }
        }

        return Set(selections.values.map(\.key))
    }

    static func stepScreenPoints(
        points: [CGPoint],
        position: LivelineStepPosition
    ) -> [CGPoint] {
        guard let first = points.first else { return [] }
        guard points.count > 1 else { return [first] }

        var result = [first]
        result.reserveCapacity(points.count * 3)

        for (left, right) in zip(points, points.dropFirst()) {
            switch position {
            case .leading:
                result.append(CGPoint(x: left.x, y: right.y))
                result.append(right)
            case .center:
                let midpointX = (left.x + right.x) / 2
                result.append(CGPoint(x: midpointX, y: left.y))
                result.append(CGPoint(x: midpointX, y: right.y))
                result.append(right)
            case .trailing:
                result.append(CGPoint(x: right.x, y: left.y))
                result.append(right)
            }
        }

        return result
    }

    static func bubbleDiameter(
        magnitude: Double,
        minimumMagnitude: Double,
        maximumMagnitude: Double,
        minimumSize: CGFloat,
        maximumSize: CGFloat,
        scale: LivelineBubbleScale
    ) -> CGFloat {
        guard maximumMagnitude > minimumMagnitude else {
            return (minimumSize + maximumSize) / 2
        }

        let progress = clamp(
            (magnitude - minimumMagnitude) / (maximumMagnitude - minimumMagnitude),
            0,
            1
        )
        switch scale {
        case .area:
            let minimumSquared = Double(minimumSize * minimumSize)
            let maximumSquared = Double(maximumSize * maximumSize)
            return CGFloat(sqrt(minimumSquared + progress * (maximumSquared - minimumSquared)))
        case .diameter:
            return minimumSize + CGFloat(progress) * (maximumSize - minimumSize)
        }
    }

    static func waterfallSegments(
        points: [LivelinePoint],
        initialValue: Double
    ) -> [LivelineWaterfallSegment] {
        var running = initialValue
        return points.map { point in
            let start = running
            running += point.value
            return LivelineWaterfallSegment(
                time: point.time,
                start: start,
                end: running,
                delta: point.value
            )
        }
    }

    static func lerp(_ current: Double, _ target: Double, speed: Double, deltaTime: TimeInterval) -> Double {
        if speed >= 1 { return target }
        let normalized = 1 - pow(1 - speed, deltaTime / 16.667)
        return current + (target - current) * normalized
    }

    static func lerpCGFloat(_ current: CGFloat, _ target: CGFloat, speed: Double, deltaTime: TimeInterval) -> CGFloat {
        CGFloat(lerp(Double(current), Double(target), speed: speed, deltaTime: deltaTime))
    }

    static func computeRange(
        points: [LivelinePoint],
        currentValue: Double,
        referenceValue: Double?,
        exaggerate: Bool
    ) -> ClosedRange<Double> {
        var targetMin = Double.infinity
        var targetMax = -Double.infinity

        for point in points {
            targetMin = min(targetMin, point.value)
            targetMax = max(targetMax, point.value)
        }

        targetMin = min(targetMin, currentValue)
        targetMax = max(targetMax, currentValue)

        if let referenceValue {
            targetMin = min(targetMin, referenceValue)
            targetMax = max(targetMax, referenceValue)
        }

        if !targetMin.isFinite || !targetMax.isFinite {
            targetMin = currentValue - 0.2
            targetMax = currentValue + 0.2
        }

        let rawRange = targetMax - targetMin
        let marginFactor = exaggerate ? 0.01 : 0.12
        let minRange = rawRange * (exaggerate ? 0.02 : 0.10)
        let floorRange = exaggerate ? 0.04 : 0.40
        let requiredRange = minRange == 0 ? floorRange : minRange

        if rawRange < requiredRange {
            let mid = (targetMin + targetMax) / 2
            targetMin = mid - requiredRange / 2
            targetMax = mid + requiredRange / 2
        } else {
            let margin = rawRange * marginFactor
            targetMin -= margin
            targetMax += margin
        }

        return targetMin...targetMax
    }

    static func computeCandleRange(
        candles: [LivelineCandle],
        liveCandle: LivelineCandle?,
        referenceValue: Double?,
        exaggerate: Bool
    ) -> ClosedRange<Double> {
        var points: [LivelinePoint] = []
        points.reserveCapacity(candles.count * 2 + 2)

        for candle in candles {
            points.append(LivelinePoint(time: candle.time, value: candle.high))
            points.append(LivelinePoint(time: candle.time, value: candle.low))
        }

        if let liveCandle {
            points.append(LivelinePoint(time: liveCandle.time, value: liveCandle.high))
            points.append(LivelinePoint(time: liveCandle.time, value: liveCandle.low))
        }

        let current = liveCandle?.close ?? candles.last?.close ?? 0
        return computeRange(points: points, currentValue: current, referenceValue: referenceValue, exaggerate: exaggerate)
    }

    static func interpolate(points: [LivelinePoint], at time: TimeInterval) -> Double? {
        guard let first = points.first else { return nil }
        if time <= first.time { return first.value }
        guard let last = points.last else { return nil }
        if time >= last.time { return last.value }

        var low = 0
        var high = points.count - 1
        while high - low > 1 {
            let mid = (low + high) / 2
            if points[mid].time <= time {
                low = mid
            } else {
                high = mid
            }
        }

        let left = points[low]
        let right = points[high]
        let delta = right.time - left.time
        guard delta != 0 else { return left.value }

        let t = (time - left.time) / delta
        return left.value + (right.value - left.value) * t
    }

    static func detectMomentum(points: [LivelinePoint], lookback: Int = 20) -> LivelineMomentum {
        guard points.count >= 5 else { return .flat }

        let start = max(0, points.count - lookback)
        let lookbackPoints = points[start..<points.count]
        guard let minValue = lookbackPoints.map(\.value).min(),
              let maxValue = lookbackPoints.map(\.value).max()
        else {
            return .flat
        }

        let range = maxValue - minValue
        guard range != 0 else { return .flat }

        let tailStart = max(start, points.count - 5)
        let first = points[tailStart].value
        let last = points[points.count - 1].value
        let threshold = range * 0.12
        let delta = last - first

        if delta > threshold { return .up }
        if delta < -threshold { return .down }
        return .flat
    }

    static func monotoneSplinePath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)

        guard points.count > 1 else { return path }
        if points.count == 2 {
            path.addLine(to: points[1])
            return path
        }

        let count = points.count
        var delta = Array(repeating: CGFloat.zero, count: count - 1)
        var h = Array(repeating: CGFloat.zero, count: count - 1)

        for index in 0..<(count - 1) {
            h[index] = points[index + 1].x - points[index].x
            delta[index] = h[index] == 0 ? 0 : (points[index + 1].y - points[index].y) / h[index]
        }

        var tangents = Array(repeating: CGFloat.zero, count: count)
        tangents[0] = delta[0]
        tangents[count - 1] = delta[count - 2]

        if count > 2 {
            for index in 1..<(count - 1) {
                tangents[index] = delta[index - 1] * delta[index] <= 0 ? 0 : (delta[index - 1] + delta[index]) / 2
            }
        }

        for index in 0..<(count - 1) {
            if delta[index] == 0 {
                tangents[index] = 0
                tangents[index + 1] = 0
            } else {
                let alpha = tangents[index] / delta[index]
                let beta = tangents[index + 1] / delta[index]
                let squareSum = alpha * alpha + beta * beta
                if squareSum > 9 {
                    let scale = 3 / sqrt(squareSum)
                    tangents[index] = scale * alpha * delta[index]
                    tangents[index + 1] = scale * beta * delta[index]
                }
            }
        }

        for index in 0..<(count - 1) {
            let width = h[index]
            path.addCurve(
                to: points[index + 1],
                control1: CGPoint(x: points[index].x + width / 3, y: points[index].y + tangents[index] * width / 3),
                control2: CGPoint(x: points[index + 1].x - width / 3, y: points[index + 1].y - tangents[index + 1] * width / 3)
            )
        }

        return path
    }

    static func loadingY(progress: CGFloat, centerY: CGFloat, amplitude: CGFloat, phase: Double) -> CGFloat {
        let t = Double(progress)
        return centerY + amplitude * CGFloat(
            sin(t * 9.4 + phase) * 0.55 +
            sin(t * 15.7 + phase * 1.3) * 0.30 +
            sin(t * 4.2 + phase * 0.7) * 0.15
        )
    }

    static func loadingBreath(_ time: TimeInterval) -> Double {
        0.22 + 0.08 * sin(time / 1.2 * .pi)
    }
}

struct LivelineLayout {
    var size: CGSize
    var padding: LivelineResolvedPadding
    var minValue: Double
    var maxValue: Double
    var leftEdge: TimeInterval
    var rightEdge: TimeInterval
    var dataLeftReserve: CGFloat = 0
    var dataRightReserve: CGFloat = 0

    var plotLeftX: CGFloat { padding.left + dataLeftReserve }
    var chartWidth: CGFloat { max(1, size.width - padding.left - padding.right - dataLeftReserve - dataRightReserve) }
    var chartHeight: CGFloat { max(1, size.height - padding.top - padding.bottom) }
    var bottomY: CGFloat { size.height - padding.bottom }
    var rightX: CGFloat { size.width - padding.right - dataRightReserve }

    func x(for time: TimeInterval) -> CGFloat {
        let denominator = max(0.001, rightEdge - leftEdge)
        let t = (time - leftEdge) / denominator
        return plotLeftX + CGFloat(t) * chartWidth
    }

    func y(for value: Double) -> CGFloat {
        let range = max(0.001, maxValue - minValue)
        let t = (value - minValue) / range
        return bottomY - CGFloat(t) * chartHeight
    }

    func time(for x: CGFloat) -> TimeInterval {
        let t = Double((x - plotLeftX) / chartWidth)
        return leftEdge + (rightEdge - leftEdge) * t
    }
}
