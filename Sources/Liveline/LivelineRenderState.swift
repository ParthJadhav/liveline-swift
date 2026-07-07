import CoreGraphics
import Foundation
import SwiftUI

final class LivelineRenderState: ObservableObject {
    var lastTimestamp: TimeInterval?
    var animationStartTimestamp: TimeInterval?
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
    var orderbookRandomSeed: UInt32?
    var orderbookRandomState: UInt32?
    var snapshotStartTimestamp: TimeInterval?
    var snapshotElapsedCursor: TimeInterval = 0
    var previousBidTotal: Double = 0
    var previousAskTotal: Double = 0
    var churnRate: Double = 0
    var gridInterval: Double = 0
    var gridLabelAlphas: [Int: Double] = [:]
    var timeAxisLabels: [Int: TimeAxisLabelState] = [:]
    var seriesAlpha: [String: Double] = [:]
    var lastHover: LivelineHoverPoint?

    func deltaTime(for timestamp: TimeInterval) -> TimeInterval {
        defer { lastTimestamp = timestamp }
        guard let lastTimestamp else { return 16.667 }
        return min(max((timestamp - lastTimestamp) * 1000, 0), 50)
    }

    func animationTime(for timestamp: TimeInterval) -> TimeInterval {
        if animationStartTimestamp == nil {
            animationStartTimestamp = timestamp
        }
        return timestamp - (animationStartTimestamp ?? timestamp)
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

    func nextOrderbookRandom(seed: UInt32) -> Double {
        if orderbookRandomSeed != seed || orderbookRandomState == nil {
            orderbookRandomSeed = seed
            orderbookRandomState = seed
        }

        var state = (orderbookRandomState ?? seed) &+ 0x6D2B79F5
        orderbookRandomState = state
        state = (state ^ (state >> 15)) &* (state | 1)
        state ^= state &+ ((state ^ (state >> 7)) &* (state | 61))
        return Double(state ^ (state >> 14)) / 4_294_967_296.0
    }
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
