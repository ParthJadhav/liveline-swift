import CoreGraphics
import Foundation

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
}

/// Converts pointer input into chart values without performing callbacks or
/// mutating rendering state.
enum LivelineHoverResolver {
    static func resolve(
        location: CGPoint?,
        snapshot: LivelineInteractionSnapshot?
    ) -> LivelineHoverPoint? {
        guard let location,
              let snapshot,
              snapshot.isEnabled,
              snapshot.behavior != .none,
              location.x >= snapshot.layout.plotLeftX,
              location.x <= snapshot.layout.rightX
        else {
            return nil
        }

        let time = snapshot.layout.time(for: location.x)
        switch snapshot.behavior {
        case .none:
            return nil
        case .discrete:
            guard let nearest = nearestPoint(to: time, in: snapshot.points) else { return nil }
            return LivelineHoverPoint(
                time: nearest.time,
                value: nearest.value,
                x: snapshot.layout.x(for: nearest.time),
                y: snapshot.layout.y(for: nearest.value)
            )
        case .interpolated:
            guard let value = LivelineMath.interpolateOrdered(points: snapshot.points, at: time) else {
                return nil
            }
            return LivelineHoverPoint(
                time: time,
                value: value,
                x: location.x,
                y: snapshot.layout.y(for: value)
            )
        }
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
