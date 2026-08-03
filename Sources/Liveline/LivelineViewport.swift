import CoreGraphics
import Foundation

/// The slice of time a chart is showing: how much of it is on screen, and
/// whether that slice is pinned to the newest data or frozen in absolute time.
///
/// A viewport layers on top of the window selection rather than replacing it.
/// The selected window (the `1m` / `5m` chips) is the *starting* span; zooming
/// multiplies it and panning slides it, and the result is handed to the
/// renderer as the same left/right edges it already draws from. A chart with no
/// zoom or pan applied has no viewport at all and follows live exactly as
/// before.
///
/// Every operation is pure: it takes the current viewport plus a
/// ``LivelineViewportLimits`` and returns the next viewport. Nothing here reads
/// a gesture, a clock, or a view.
public struct LivelineViewport: Equatable {
    /// Seconds of data visible across the plot.
    public var span: TimeInterval

    /// The absolute right edge, in seconds since 1970, while the viewport is
    /// frozen — or `nil` while it follows the live edge.
    ///
    /// Freezing stores absolute time, so newly streamed samples move the live
    /// edge without moving what the reader is looking at.
    public var frozenEnd: TimeInterval?

    public init(span: TimeInterval, frozenEnd: TimeInterval? = nil) {
        self.span = span
        self.frozenEnd = frozenEnd
    }

    /// True while the right edge tracks the newest data.
    public var isFollowingLive: Bool { frozenEnd == nil }

    /// The right edge to draw, given where the live edge currently sits.
    public func end(liveEdge: TimeInterval) -> TimeInterval {
        frozenEnd ?? liveEdge
    }

    /// The visible time range, given where the live edge currently sits.
    public func range(liveEdge: TimeInterval) -> ClosedRange<TimeInterval> {
        let end = end(liveEdge: liveEdge)
        return (end - span)...end
    }
}

/// The bounds every zoom and pan is resolved against: how far the data reaches,
/// how far in and out the span may go, and how close to the live edge counts as
/// live.
public struct LivelineViewportLimits: Equatable {
    /// Oldest sample through the current live edge. Panning never leaves it.
    public var domain: ClosedRange<TimeInterval>

    /// The tightest span a pinch may reach.
    public var minimumSpan: TimeInterval

    /// The widest span a pinch may reach.
    public var maximumSpan: TimeInterval

    /// How close to the live edge, as a fraction of the visible span, re-engages
    /// live follow. Small enough that stopping short of the edge stays frozen,
    /// large enough that flicking to the end snaps.
    public var followSnapFraction: Double

    public init(
        domain: ClosedRange<TimeInterval>,
        minimumSpan: TimeInterval,
        maximumSpan: TimeInterval,
        followSnapFraction: Double = LivelineViewportLimits.defaultFollowSnapFraction
    ) {
        self.domain = domain
        self.minimumSpan = minimumSpan
        self.maximumSpan = max(minimumSpan, maximumSpan)
        self.followSnapFraction = followSnapFraction
    }

    public static let defaultFollowSnapFraction: Double = 0.02

    /// The default ceiling on zooming out: the selected window times this, then
    /// capped again by how much data actually exists.
    public static let defaultMaximumZoomOut: Double = 8

    /// The floor the minimum span can never go below, whatever the data says.
    /// Sub-millisecond spans divide badly in the layout's time-to-x mapping.
    public static let absoluteMinimumSpan: TimeInterval = 0.001

    /// Derives limits from what the chart already knows: the selected window,
    /// the extent of the data, and how many samples are in it.
    ///
    /// - Parameters:
    ///   - window: The window the picker has selected — the un-zoomed span.
    ///   - domain: Oldest sample through the current live edge.
    ///   - sampleCount: Samples inside `domain`, used to derive a "few samples"
    ///     zoom-in floor when no explicit minimum is configured.
    ///   - minimumSpan: An explicit floor, overriding the derived one.
    ///   - maximumZoomOut: Multiplier applied to `window` for the ceiling.
    public static func resolve(
        window: TimeInterval,
        domain: ClosedRange<TimeInterval>,
        sampleCount: Int = 0,
        minimumSpan: TimeInterval? = nil,
        maximumZoomOut: Double = LivelineViewportLimits.defaultMaximumZoomOut,
        followSnapFraction: Double = LivelineViewportLimits.defaultFollowSnapFraction
    ) -> LivelineViewportLimits {
        let safeWindow = window.isFinite && window > 0 ? window : 30
        let extent = max(domain.upperBound - domain.lowerBound, safeWindow)
        let cap = maximumZoomOut.isFinite && maximumZoomOut >= 1 ? maximumZoomOut : defaultMaximumZoomOut
        // Never wider than the data actually covers, and never narrower than the
        // window the reader picked.
        let ceiling = max(safeWindow, min(extent, safeWindow * cap))

        let floor: TimeInterval
        if let minimumSpan, minimumSpan.isFinite, minimumSpan > 0 {
            floor = minimumSpan
        } else if sampleCount > 1 {
            // Three sample intervals: enough for a visible segment on either
            // side of whatever the reader zoomed into.
            let interval = (domain.upperBound - domain.lowerBound) / Double(sampleCount - 1)
            floor = max(absoluteMinimumSpan, interval * 3)
        } else {
            floor = max(absoluteMinimumSpan, safeWindow / 50)
        }

        return LivelineViewportLimits(
            domain: domain,
            minimumSpan: min(floor, ceiling),
            maximumSpan: ceiling,
            followSnapFraction: followSnapFraction
        )
    }
}

extension LivelineViewport {
    /// A viewport showing exactly `window` seconds and following the live edge.
    public static func following(window: TimeInterval) -> LivelineViewport {
        LivelineViewport(span: window, frozenEnd: nil)
    }

    /// Multiplies the visible span, keeping the moment under the gesture
    /// centroid at the same place on screen.
    ///
    /// - Parameters:
    ///   - factor: Magnification. Greater than one zooms in — a pinch outwards
    ///     shows less time.
    ///   - anchorFraction: Where the centroid sits across the plot in *time*
    ///     order: `0` is the oldest visible moment, `1` the newest. Callers on
    ///     a right-to-left layout convert through ``LivelineLayout`` first, so
    ///     this is always reading-direction independent.
    ///
    /// A viewport that is following live keeps following: the pinch pivots on
    /// the live edge whatever the centroid says, so a zoom never silently
    /// detaches a live chart. Panning is the only thing that disengages.
    public func zoomed(
        by factor: Double,
        anchorFraction: Double,
        limits: LivelineViewportLimits
    ) -> LivelineViewport {
        guard factor.isFinite, factor > 0 else { return self }
        let resolvedAnchor = isFollowingLive
            ? 1
            : (anchorFraction.isFinite ? min(max(anchorFraction, 0), 1) : 0.5)

        let currentEnd = end(liveEdge: limits.domain.upperBound)
        let currentStart = currentEnd - span
        let anchorTime = currentStart + span * resolvedAnchor
        let requestedSpan = span / factor
        let nextSpan = min(max(requestedSpan, limits.minimumSpan), limits.maximumSpan)
        return LivelineViewport.resolved(
            start: anchorTime - nextSpan * resolvedAnchor,
            span: nextSpan,
            limits: limits
        )
    }

    /// Translates the visible range by a number of seconds, clamped to the data
    /// domain. Positive moves toward newer data.
    ///
    /// Landing within ``LivelineViewportLimits/followSnapFraction`` of the live
    /// edge re-engages live follow; landing short of it freezes the viewport in
    /// absolute time.
    public func panned(by timeDelta: TimeInterval, limits: LivelineViewportLimits) -> LivelineViewport {
        guard timeDelta.isFinite else { return self }
        let currentEnd = end(liveEdge: limits.domain.upperBound)
        return LivelineViewport.resolved(
            start: currentEnd - span + timeDelta,
            span: span,
            limits: limits
        )
    }

    /// Re-engages live follow at the current zoom — what the "Live" control does.
    public func followingLive(limits: LivelineViewportLimits) -> LivelineViewport {
        LivelineViewport(
            span: min(max(span, limits.minimumSpan), limits.maximumSpan),
            frozenEnd: nil
        )
    }

    /// Converts a horizontal drag into a pan in seconds.
    ///
    /// Dragging the plot moves the data with the finger, so the visible range
    /// travels the other way. In a right-to-left layout the live edge is on the
    /// left, and the same physical direction — toward the live edge — still
    /// means "show newer data", so the sign flips with the reading direction.
    public static func panTimeDelta(
        translation: CGFloat,
        plotWidth: CGFloat,
        span: TimeInterval,
        isRTL: Bool
    ) -> TimeInterval {
        guard translation.isFinite, plotWidth.isFinite, plotWidth > 0, span.isFinite else { return 0 }
        let fraction = Double(-translation / plotWidth)
        return fraction * span * (isRTL ? -1 : 1)
    }

    /// Clamps a candidate range into the domain and decides whether it counts
    /// as live. The single place span clamping, domain clamping, and the follow
    /// threshold meet.
    private static func resolved(
        start: TimeInterval,
        span: TimeInterval,
        limits: LivelineViewportLimits
    ) -> LivelineViewport {
        let nextSpan = min(max(span, limits.minimumSpan), limits.maximumSpan)
        let liveEdge = limits.domain.upperBound
        let maximumStart = liveEdge - nextSpan
        // A span wider than the data leaves no room to pan: the range is pinned
        // with its right edge on the live edge and hangs off the left.
        let minimumStart = min(limits.domain.lowerBound, maximumStart)
        let nextStart = min(max(start.isFinite ? start : maximumStart, minimumStart), maximumStart)
        let nextEnd = nextStart + nextSpan
        let snap = abs(limits.followSnapFraction) * nextSpan
        let followsLive = liveEdge - nextEnd <= snap
        return LivelineViewport(span: nextSpan, frozenEnd: followsLive ? nil : nextEnd)
    }
}
