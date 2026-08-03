import CoreGraphics
import Foundation
import SwiftUI

final class LivelineRenderState: ObservableObject {
    var lastTimestamp: TimeInterval?
    var animationElapsed: TimeInterval = 0
    var pausedPresentationTimestamp: TimeInterval?
    var chartIdentity: LivelineChartIdentity?
    var smoothValue: Double?
    var displayMin: Double?
    var displayMax: Double?
    var displayWindow: TimeInterval?
    var chartReveal: Double = 0
    var pauseProgress: Double = 0
    var previousMomentum: LivelineMomentum = .flat
    var arrowUp: Double = 0
    var arrowDown: Double = 0
    var shakeAmplitude: CGFloat = 0
    var particles: [Particle] = []
    var orderbookLabels: [OrderbookLabel] = []
    var orderbookSpawnTimer: TimeInterval = 0
    var orderbookSpeed: CGFloat = 60
    var randomSeed: UInt32?
    var randomState: UInt32?
    var snapshotStartTimestamp: TimeInterval?
    var snapshotElapsedCursor: TimeInterval = 0
    var previousBidTotal: Double = 0
    var previousAskTotal: Double = 0
    var churnRate: Double = 0
    var gridInterval: Double = 0
    var gridLabelAlphas: [Double: Double] = [:]
    var timeAxisLabels: [TimeInterval: TimeAxisLabelState] = [:]
    var seriesAlpha: [String: Double] = [:]
    var interactionSnapshot: LivelineInteractionSnapshot?
    /// Where the right edge would sit if the chart were following live, recorded
    /// on every frame whether or not a viewport has frozen it.
    ///
    /// Zoom and pan are resolved against this rather than against the newest
    /// sample time, so freezing the viewport does not shift the plot by the
    /// live-edge buffer, and a frozen viewport can still tell how far behind it
    /// has fallen.
    var liveRightEdge: TimeInterval?
    /// The right edge actually drawn last frame, eased toward the viewport's
    /// target so returning to live glides instead of cutting.
    var displayRightEdge: TimeInterval?
    var candleDisplayLive: LivelineCandle?
    var candleLiveBirthAlpha: Double = 1
    var candleLiveBullBlend: Double = 0.5
    var candleCloseLineSmooth: Double?
    var candleLineSmoothClose: Double?
    var candleLineTickSmooth: Double?
    var candleLineModeProgress: Double = 0
    var candleLineModeTransition: TimedTransition?
    var candleLineDensityProgress: Double = 0
    var candleLineDensityTransition: TimedTransition?
    var settlesTransitionsImmediately = false
    var ditherGeometryCache: LivelineDitherGeometry?
    var ditherGeometryBuildCount = 0
    var paletteBuildCount = 0
    var legendGutterMeasureCount = 0
    var accessibilityModelBuildCount = 0
    /// Every cached text measurement was taken at this scale; a Dynamic Type
    /// change invalidates them all.
    private(set) var textScale: LivelineTextScale = .standard
    private var preparedChartKey: LivelinePreparedChartKey?
    private var preparedChartCache: LivelinePreparedChart?
    private var waterfallKey: LivelineWaterfallKey?
    private var waterfallCache: [LivelineWaterfallSegment] = []
    private var histogramKey: LivelineHistogramKey?
    private var histogramCache: [LivelineHistogramBin] = []
    private var treemapKey: LivelineTreemapKey?
    private var treemapCache: LivelineTreemapLayout = .empty
    private var sankeyKey: LivelineSankeyKey?
    private var sankeyCache: LivelineSankeyGraph?
    private var paletteCache: [LivelinePaletteKey: LivelinePalette] = [:]
    private var legendGutterCache: [LivelineLegendGutterKey: CGFloat] = [:]
    private var accessibilityModelKey: LivelineAccessibilityModelKey?
    private var accessibilityModelCache: LivelineChartAccessibilityModel?

    /// Resolving a palette bridges the accent through `UIColor`/`NSColor` and
    /// rebuilds every derived shade. That happens for the chart and for each
    /// series on every frame, so memoize on the inputs `resolve` reads.
    func palette(accent: Color, mode: LivelineThemeMode, lineWidth: CGFloat) -> LivelinePalette {
        let key = LivelinePaletteKey(accent: accent, mode: mode, lineWidth: lineWidth)
        if let cached = paletteCache[key] { return cached }
        // A chart draws a handful of accents at most; a theme or accent flip
        // should not let the table grow without bound.
        if paletteCache.count >= 32 { paletteCache.removeAll(keepingCapacity: true) }
        let palette = LivelinePalette.resolve(accent: accent, mode: mode, lineWidth: lineWidth)
        paletteBuildCount += 1
        paletteCache[key] = palette
        return palette
    }

    /// Text measured at one Dynamic Type size says nothing about its width at
    /// another, so a scale change drops every measurement the caches hold.
    func adoptTextScale(_ scale: LivelineTextScale) {
        guard scale != textScale else { return }
        textScale = scale
        legendGutterCache.removeAll(keepingCapacity: true)
        for key in timeAxisLabels.keys {
            timeAxisLabels[key]?.measuredWidth = nil
        }
    }

    /// Legend labels are measured through the graphics context, which is far
    /// too expensive to repeat per frame for a gutter that only changes when
    /// the label set does.
    func legendGutterWidth(
        labels: [String],
        side: LivelineLegendSide,
        measure: () -> CGFloat
    ) -> CGFloat {
        let key = LivelineLegendGutterKey(labels: labels, side: side)
        if let cached = legendGutterCache[key] { return cached }
        if legendGutterCache.count >= 8 { legendGutterCache.removeAll(keepingCapacity: true) }
        let width = measure()
        legendGutterMeasureCount += 1
        legendGutterCache[key] = width
        return width
    }

    /// The accessibility model formats a string per datum. Hover state lives in
    /// `@State`, so every pointer move re-evaluates the body: without this the
    /// whole dataset would be reformatted on each move while VoiceOver runs.
    func accessibilityModel(
        for key: LivelineAccessibilityModelKey,
        make: () -> LivelineChartAccessibilityModel
    ) -> LivelineChartAccessibilityModel {
        if key == accessibilityModelKey, let cached = accessibilityModelCache {
            return cached
        }
        let model = make()
        accessibilityModelBuildCount += 1
        accessibilityModelKey = key
        accessibilityModelCache = model
        return model
    }

    /// Frames repeat far more often than data changes. Reuse the derived
    /// arrays whenever the identity behind them is untouched.
    func preparedChart(for key: LivelinePreparedChartKey) -> LivelinePreparedChart? {
        preparedChartKey == key ? preparedChartCache : nil
    }

    func storePreparedChart(_ chart: LivelinePreparedChart, for key: LivelinePreparedChartKey) {
        preparedChartKey = key
        preparedChartCache = chart
    }

    /// Waterfall segments are a running total over the *entire* dataset, so
    /// recomputing them per frame dominates the chart. Memoize on data identity.
    func waterfallSegments(points: [LivelinePoint], initialValue: Double) -> [LivelineWaterfallSegment] {
        let key = LivelineWaterfallKey(shape: points.livelineShape(lastValue: points.last?.value ?? 0), initialValue: initialValue)
        if waterfallKey == key { return waterfallCache }
        let segments = LivelineMath.waterfallSegments(points: points, initialValue: initialValue)
        waterfallKey = key
        waterfallCache = segments
        return segments
    }

    /// Binning sorts and walks the whole sample set, which is far too much to
    /// repeat per frame for an input that only changes when the caller's data
    /// does. Memoize on the samples' identity and the rule applied to them.
    func histogramBins(
        values: [Double],
        binning: LivelineHistogramBinning
    ) -> [LivelineHistogramBin] {
        let key = LivelineHistogramKey(
            storage: values.livelineStorageIdentity,
            count: values.count,
            first: values.first ?? 0,
            last: values.last ?? 0,
            binning: binning
        )
        if histogramKey == key { return histogramCache }
        let bins = LivelineMath.histogramBins(values: values, binning: binning)
        histogramKey = key
        histogramCache = bins
        return bins
    }

    /// Squarifying walks and sorts the whole node set, so it is memoized on the
    /// nodes' identity *and* the rectangle they are packed into: unlike the
    /// radial kinds, a treemap's layout changes with the plot size, and that is
    /// exactly what makes it worth caching rather than recomputing per frame.
    func treemapLayout(
        nodes: [LivelineTreemapNode],
        style: LivelineTreemapStyle,
        in rect: CGRect
    ) -> LivelineTreemapLayout {
        let key = LivelineTreemapKey(
            storage: nodes.livelineStorageIdentity,
            count: nodes.count,
            firstValue: nodes.first?.resolvedValue ?? 0,
            lastValue: nodes.last?.resolvedValue ?? 0,
            rect: rect,
            padding: style.resolvedPadding,
            groupPadding: style.resolvedGroupPadding,
            groupHeaderHeight: style.resolvedGroupHeaderHeight
        )
        if treemapKey == key { return treemapCache }
        let tiling = LivelineMath.treemapLayout(
            nodes: nodes,
            in: rect,
            padding: style.resolvedPadding,
            groupPadding: style.resolvedGroupPadding,
            groupHeaderHeight: style.resolvedGroupHeaderHeight
        )
        treemapKey = key
        treemapCache = tiling
        return tiling
    }

    /// Cycle breaking and layering walk every edge; the result depends only on
    /// the links, never on the plot size, so it survives a resize.
    func sankeyGraph(links: [LivelineSankeyLink]) -> LivelineSankeyGraph {
        let key = LivelineSankeyKey(
            storage: links.livelineStorageIdentity,
            count: links.count,
            firstValue: links.first?.value ?? 0,
            lastValue: links.last?.value ?? 0
        )
        if sankeyKey == key, let cached = sankeyCache { return cached }
        let graph = LivelineMath.sankeyGraph(links: links)
        sankeyKey = key
        sankeyCache = graph
        return graph
    }

    func frame(for timestamp: TimeInterval, isPaused: Bool) -> LivelineAnimationFrame {
        defer { lastTimestamp = timestamp }
        let deltaMilliseconds: TimeInterval
        if let lastTimestamp {
            deltaMilliseconds = min(max((timestamp - lastTimestamp) * 1000, 0), 50)
        } else {
            deltaMilliseconds = 16.667
        }
        let effectiveDelta = isPaused ? 0 : deltaMilliseconds
        animationElapsed += effectiveDelta / 1000
        return LivelineAnimationFrame(deltaMilliseconds: effectiveDelta, elapsed: animationElapsed)
    }

    /// The delta ``frame(for:isPaused:)`` will report for this timestamp, read
    /// without consuming it.
    ///
    /// `frame(for:isPaused:)` advances `lastTimestamp` and `animationElapsed`,
    /// so it must be called exactly once per draw — and it is called after the
    /// identity reconcile, which may reset both. Smoothing that has to run
    /// *before* the geometry is laid out peeks at the delta through here
    /// instead of taking a second frame.
    func peekDeltaMilliseconds(for timestamp: TimeInterval, isPaused: Bool) -> TimeInterval {
        guard !isPaused else { return 0 }
        guard let lastTimestamp else { return 16.667 }
        return min(max((timestamp - lastTimestamp) * 1000, 0), 50)
    }

    func presentationTimestamp(for timestamp: TimeInterval, isPaused: Bool) -> TimeInterval {
        if isPaused {
            if pausedPresentationTimestamp == nil {
                pausedPresentationTimestamp = timestamp
            }
            return pausedPresentationTimestamp ?? timestamp
        }
        pausedPresentationTimestamp = nil
        return timestamp
    }

    func timestamp(for timestamp: TimeInterval, snapshotElapsedTime: TimeInterval?) -> TimeInterval {
        guard let snapshotElapsedTime else {
            snapshotStartTimestamp = nil
            snapshotElapsedCursor = 0
            return timestamp
        }

        if snapshotStartTimestamp == nil {
            snapshotStartTimestamp = timestamp
            snapshotElapsedCursor = 0
            return timestamp
        }

        let frameInterval = 1.0 / 60.0
        snapshotElapsedCursor = min(snapshotElapsedTime, snapshotElapsedCursor + frameInterval)
        return (snapshotStartTimestamp ?? timestamp) + snapshotElapsedCursor
    }

    func resetIfNeeded(anchorValue: Double, window: TimeInterval) {
        if smoothValue == nil { smoothValue = anchorValue }
        if displayWindow == nil { displayWindow = window }
    }

    func reconcile(identity: LivelineChartIdentity, anchorValue: Double, window: TimeInterval) {
        guard chartIdentity != identity else {
            resetIfNeeded(anchorValue: anchorValue, window: window)
            return
        }

        chartIdentity = identity
        lastTimestamp = nil
        animationElapsed = 0
        pausedPresentationTimestamp = nil
        smoothValue = anchorValue
        displayMin = nil
        displayMax = nil
        displayWindow = window
        liveRightEdge = nil
        displayRightEdge = nil
        chartReveal = 0
        pauseProgress = 0
        previousMomentum = .flat
        arrowUp = 0
        arrowDown = 0
        shakeAmplitude = 0
        particles.removeAll(keepingCapacity: true)
        orderbookLabels.removeAll(keepingCapacity: true)
        orderbookSpawnTimer = 0
        orderbookSpeed = 60
        randomSeed = nil
        randomState = nil
        snapshotStartTimestamp = nil
        snapshotElapsedCursor = 0
        previousBidTotal = 0
        previousAskTotal = 0
        churnRate = 0
        gridInterval = 0
        gridLabelAlphas.removeAll(keepingCapacity: true)
        timeAxisLabels.removeAll(keepingCapacity: true)
        seriesAlpha.removeAll(keepingCapacity: true)
        interactionSnapshot = nil
        candleDisplayLive = nil
        candleLiveBirthAlpha = 1
        candleLiveBullBlend = 0.5
        candleCloseLineSmooth = nil
        candleLineSmoothClose = nil
        candleLineTickSmooth = nil
        candleLineModeProgress = 0
        candleLineModeTransition = nil
        candleLineDensityProgress = 0
        candleLineDensityTransition = nil
        ditherGeometryCache = nil
        preparedChartKey = nil
        preparedChartCache = nil
        waterfallKey = nil
        waterfallCache.removeAll(keepingCapacity: true)
        histogramKey = nil
        histogramCache.removeAll(keepingCapacity: true)
        treemapKey = nil
        treemapCache = .empty
        sankeyKey = nil
        sankeyCache = nil
        paletteCache.removeAll(keepingCapacity: true)
        legendGutterCache.removeAll(keepingCapacity: true)
        accessibilityModelKey = nil
        accessibilityModelCache = nil
    }

    func nextRandom(seed: UInt32) -> Double {
        if randomSeed != seed || randomState == nil {
            randomSeed = seed
            randomState = seed
        }

        var state = (randomState ?? seed) &+ 0x6D2B79F5
        randomState = state
        state = (state ^ (state >> 15)) &* (state | 1)
        state ^= state &+ ((state ^ (state >> 7)) &* (state | 61))
        return Double(state ^ (state >> 14)) / 4_294_967_296.0
    }

    func timedProgress(
        current: Double,
        target: Double,
        duration: TimeInterval,
        timestamp: TimeInterval,
        transition keyPath: ReferenceWritableKeyPath<LivelineRenderState, TimedTransition?>
    ) -> Double {
        if self[keyPath: keyPath]?.target != target {
            self[keyPath: keyPath] = TimedTransition(from: current, target: target, startTimestamp: timestamp)
        }

        guard var transition = self[keyPath: keyPath] else {
            return target
        }

        let elapsed = max(0, timestamp - transition.startTimestamp)
        guard duration > 0, elapsed < duration else {
            self[keyPath: keyPath] = nil
            return target
        }

        let t = elapsed / duration
        let eased = (1 - cos(t * .pi)) / 2
        transition.lastValue = transition.from + (transition.target - transition.from) * eased
        self[keyPath: keyPath] = transition
        return transition.lastValue
    }

    func transitionProgress(
        current: Double,
        target: Double,
        duration: TimeInterval,
        timestamp: TimeInterval,
        transition keyPath: ReferenceWritableKeyPath<LivelineRenderState, TimedTransition?>
    ) -> Double {
        guard !settlesTransitionsImmediately else {
            self[keyPath: keyPath] = nil
            return target
        }
        return timedProgress(
            current: current,
            target: target,
            duration: duration,
            timestamp: timestamp,
            transition: keyPath
        )
    }
}

struct LivelineAnimationFrame: Equatable {
    var deltaMilliseconds: TimeInterval
    var elapsed: TimeInterval
}

struct LivelinePaletteKey: Hashable {
    var accent: Color
    var mode: LivelineThemeMode
    var lineWidth: CGFloat
}

struct LivelineHistogramKey: Equatable {
    var storage: UInt
    var count: Int
    var first: Double
    var last: Double
    var binning: LivelineHistogramBinning
}

struct LivelineTreemapKey: Equatable {
    var storage: UInt
    var count: Int
    var firstValue: Double
    var lastValue: Double
    var rect: CGRect
    var padding: CGFloat
    var groupPadding: CGFloat
    var groupHeaderHeight: CGFloat
}

struct LivelineSankeyKey: Equatable {
    var storage: UInt
    var count: Int
    var firstValue: Double
    var lastValue: Double
}

struct LivelineLegendGutterKey: Hashable {
    var labels: [String]
    var side: LivelineLegendSide
}

struct Particle {
    var position: CGPoint
    var velocity: CGVector
    var color: Color
    var radius: CGFloat
    var life: TimeInterval
    var maxLife: TimeInterval
}

struct OrderbookLabel: Identifiable {
    var id = UUID()
    var y: CGFloat
    var text: String
    var isBid: Bool
    var life: TimeInterval
    var maxLife: TimeInterval
    var intensity: Double
}

struct TimeAxisLabelState {
    var alpha: Double
    var text: String
    /// Measured through the graphics context, which is expensive enough that
    /// it must not repeat while the label text is unchanged.
    var measuredWidth: CGFloat?
}

struct TimedTransition {
    var from: Double
    var target: Double
    var startTimestamp: TimeInterval
    var lastValue: Double

    init(from: Double, target: Double, startTimestamp: TimeInterval) {
        self.from = from
        self.target = target
        self.startTimestamp = startTimestamp
        self.lastValue = from
    }
}
