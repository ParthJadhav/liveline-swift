import Foundation
import SwiftUI

/// Pure rules for reconciling view-owned selections when public inputs change.
enum LivelineSelectionReconciler {
    static func window(
        current: TimeInterval,
        preferred: TimeInterval,
        options: [TimeInterval],
        preferExternalValue: Bool
    ) -> TimeInterval {
        let validOptions = options.filter { $0.isFinite && $0 > 0 }
        guard !validOptions.isEmpty else {
            return preferred.isFinite && preferred > 0 ? preferred : 30
        }

        if preferExternalValue, validOptions.contains(preferred) {
            return preferred
        }
        if validOptions.contains(current) {
            return current
        }
        if validOptions.contains(preferred) {
            return preferred
        }
        return validOptions[0]
    }

    static func hiddenSeries(current: Set<String>, availableIDs: [String]) -> Set<String> {
        let available = Set(availableIDs)
        var hidden = current.intersection(available)
        if !availableIDs.isEmpty, hidden.count == available.count {
            hidden.remove(availableIDs[0])
        }
        return hidden
    }

    static func toggledSeries(
        _ id: String,
        hidden current: Set<String>,
        availableIDs: [String]
    ) -> (hidden: Set<String>, isVisible: Bool)? {
        guard availableIDs.contains(id) else { return nil }
        var hidden = hiddenSeries(current: current, availableIDs: availableIDs)
        if hidden.remove(id) != nil {
            return (hidden, true)
        }

        let visibleCount = availableIDs.reduce(into: 0) { count, availableID in
            if !hidden.contains(availableID) { count += 1 }
        }
        guard visibleCount > 1 else { return nil }
        hidden.insert(id)
        return (hidden, false)
    }
}

/// Decides whether SwiftUI should keep requesting frames and how state should
/// settle when it does not. This is the single motion policy used by the chart.
struct LivelineMotionPolicy: Equatable {
    var isPaused: Bool
    var requiresTimeline: Bool
    var settlesImmediately: Bool

    static func resolve(
        configuration: LivelineChartConfiguration,
        capabilities: LivelineChartCapabilities,
        reduceMotion: Bool,
        snapshotElapsedTime: TimeInterval? = nil
    ) -> LivelineMotionPolicy {
        let wantsContinuousFrames = capabilities.isRealtime
            || configuration.fadeEffects
            || configuration.style.requiresContinuousFrames
            || configuration.loading
            || configuration.degen != nil
            || configuration.orderbook != nil
            || configuration.activePoint?.pulse == true
            || snapshotElapsedTime != nil
        let requiresTimeline = !configuration.paused && !reduceMotion && wantsContinuousFrames
        return LivelineMotionPolicy(
            isPaused: configuration.paused,
            requiresTimeline: requiresTimeline,
            settlesImmediately: reduceMotion || (!requiresTimeline && !configuration.paused)
        )
    }
}

struct LivelineInteractionSnapshot {
    var layout: LivelineLayout
    var points: [LivelinePoint]
    var behavior: LivelineHoverBehavior
    var isEnabled: Bool
    var targets: [LivelineInteractionTarget] = []
}

struct LivelineTooltipRow {
    var label: String
    var value: String
    var color: Color
}

struct LivelineTooltipSelection {
    var hover: LivelineHoverPoint
    var heading: String?
    var rows: [LivelineTooltipRow]
    var anchor: CGPoint
    var showsGuide: Bool
}

struct LivelineInteractionTarget {
    var selection: LivelineTooltipSelection
    var region: LivelineInteractionRegion
}

enum LivelineInteractionRegion {
    case x
    case rect(CGRect)
    case circle(center: CGPoint, radius: CGFloat)
    case sector(center: CGPoint, innerRadius: CGFloat, outerRadius: CGFloat, startAngle: Double, endAngle: Double)
}

/// Converts pointer input into chart values without performing callbacks or
/// mutating rendering state.
enum LivelineHoverResolver {
    static func resolve(
        location: CGPoint?,
        snapshot: LivelineInteractionSnapshot?
    ) -> LivelineHoverPoint? {
        resolveSelection(location: location, snapshot: snapshot)?.hover
    }

    static func resolveSelection(
        location: CGPoint?,
        snapshot: LivelineInteractionSnapshot?
    ) -> LivelineTooltipSelection? {
        guard let location,
              let snapshot,
              snapshot.isEnabled
        else {
            return nil
        }

        if !snapshot.targets.isEmpty {
            let direct = snapshot.targets
                .filter { contains(location, region: $0.region) }
                .min { distanceSquared(location, $0.selection.anchor) < distanceSquared(location, $1.selection.anchor) }
            if let direct { return direct.selection }

            let plot = CGRect(
                x: snapshot.layout.plotLeftX,
                y: snapshot.layout.padding.top,
                width: snapshot.layout.chartWidth,
                height: snapshot.layout.chartHeight
            )
            guard plot.contains(location) else { return nil }
            return snapshot.targets
                .filter { if case .x = $0.region { return true }; return false }
                .min { abs($0.selection.anchor.x - location.x) < abs($1.selection.anchor.x - location.x) }?
                .selection
        }

        guard snapshot.behavior != .none,
              location.x >= snapshot.layout.plotLeftX,
              location.x <= snapshot.layout.rightX
        else { return nil }

        let time = snapshot.layout.time(for: location.x)
        let hover: LivelineHoverPoint?
        switch snapshot.behavior {
        case .none:
            return nil
        case .discrete:
            guard let nearest = nearestPoint(to: time, in: snapshot.points) else { return nil }
            hover = LivelineHoverPoint(
                time: nearest.time,
                value: nearest.value,
                x: snapshot.layout.x(for: nearest.time),
                y: snapshot.layout.y(for: nearest.value)
            )
        case .interpolated:
            guard let value = LivelineMath.interpolateOrdered(points: snapshot.points, at: time) else {
                return nil
            }
            hover = LivelineHoverPoint(
                time: time,
                value: value,
                x: location.x,
                y: snapshot.layout.y(for: value)
            )
        }
        guard let hover else { return nil }
        return LivelineTooltipSelection(
            hover: hover,
            heading: nil,
            rows: [],
            anchor: CGPoint(x: hover.x, y: hover.y),
            showsGuide: true
        )
    }

    private static func contains(_ location: CGPoint, region: LivelineInteractionRegion) -> Bool {
        switch region {
        case .x:
            return false
        case let .rect(rect):
            return rect.insetBy(dx: -8, dy: -8).contains(location)
        case let .circle(center, radius):
            return distanceSquared(location, center) <= radius * radius
        case let .sector(center, innerRadius, outerRadius, startAngle, endAngle):
            let dx = location.x - center.x
            let dy = location.y - center.y
            let radius = hypot(dx, dy)
            guard radius >= innerRadius, radius <= outerRadius else { return false }
            let fullTurn = 2 * Double.pi
            var angle = atan2(Double(dy), Double(dx)).truncatingRemainder(dividingBy: fullTurn)
            if angle < 0 { angle += fullTurn }
            var start = startAngle.truncatingRemainder(dividingBy: fullTurn)
            if start < 0 { start += fullTurn }
            var end = endAngle
            while end < start { end += fullTurn }
            if angle < start { angle += fullTurn }
            return angle >= start && angle <= end
        }
    }

    private static func distanceSquared(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return dx * dx + dy * dy
    }

    private static func nearestPoint(to time: TimeInterval, in points: [LivelinePoint]) -> LivelinePoint? {
        guard !points.isEmpty else { return nil }
        var lower = 0
        var upper = points.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if points[middle].time < time {
                lower = middle + 1
            } else {
                upper = middle
            }
        }

        if lower == 0 { return points[0] }
        if lower == points.count { return points[points.count - 1] }
        let before = points[lower - 1]
        let after = points[lower]
        return abs(before.time - time) <= abs(after.time - time) ? before : after
    }
}
