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
}

struct LivelineAnimationFrame: Equatable {
    var deltaMilliseconds: TimeInterval
    var elapsed: TimeInterval
}

struct Particle: Identifiable {
    var id = UUID()
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
