import Foundation
import Liveline
import SwiftUI

@MainActor
final class DemoMarket: ObservableObject {
    @Published var ticks: [LivelinePoint]
    @Published var latest: Double
    @Published var candles: [LivelineCandle]
    @Published var liveCandle: LivelineCandle
    @Published var spread: [LivelineSeries]
    @Published var orderbook: LivelineOrderbookData

    private var timer: Timer?
    private let candleWidth: TimeInterval = 30
    private var startTime: TimeInterval
    private var phase = 0.0

    init() {
        let now = Date().timeIntervalSince1970
        startTime = now - 210
        var value = 42_100.0
        var generatedTicks: [LivelinePoint] = []
        for index in 0..<220 {
            let time = startTime + Double(index)
            value += sin(Double(index) * 0.12) * 10 + cos(Double(index) * 0.03) * 5
            generatedTicks.append(LivelinePoint(time: time, value: value))
        }
        let initialLatest = generatedTicks.last?.value ?? value
        let initialCandles = DemoMarket.makeCandles(from: generatedTicks, candleWidth: candleWidth)
        ticks = generatedTicks
        latest = initialLatest
        candles = initialCandles
        liveCandle = initialCandles.last ?? LivelineCandle(time: now, open: initialLatest, high: initialLatest, low: initialLatest, close: initialLatest)
        spread = DemoMarket.makeSeries(from: generatedTicks)
        orderbook = DemoMarket.makeOrderbook(mid: initialLatest)
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        phase += 0.34
        let now = Date().timeIntervalSince1970
        let impulse = sin(phase) * 14 + cos(phase * 0.37) * 8 + Double.random(in: -8...8)
        latest = max(1, latest + impulse)
        ticks.append(LivelinePoint(time: now, value: latest))
        ticks = Array(ticks.suffix(420))

        updateLiveCandle(time: now, value: latest)
        spread = DemoMarket.makeSeries(from: ticks)
        orderbook = DemoMarket.makeOrderbook(mid: latest)
    }

    private func updateLiveCandle(time: TimeInterval, value: Double) {
        let bucket = floor(time / candleWidth) * candleWidth
        if liveCandle.time == bucket {
            liveCandle.close = value
            liveCandle.high = max(liveCandle.high, value)
            liveCandle.low = min(liveCandle.low, value)
        } else {
            candles.append(liveCandle)
            candles = Array(candles.suffix(80))
            liveCandle = LivelineCandle(time: bucket, open: value, high: value, low: value, close: value)
        }
    }

    private static func makeCandles(from points: [LivelinePoint], candleWidth: TimeInterval) -> [LivelineCandle] {
        let groups = Dictionary(grouping: points) { point in
            floor(point.time / candleWidth) * candleWidth
        }

        return groups.keys.sorted().compactMap { key in
            guard let bucket = groups[key]?.sorted(by: { $0.time < $1.time }),
                  let first = bucket.first,
                  let last = bucket.last
            else {
                return nil
            }

            let values = bucket.map(\.value)
            return LivelineCandle(
                time: key,
                open: first.value,
                high: values.max() ?? first.value,
                low: values.min() ?? first.value,
                close: last.value
            )
        }
    }

    private static func makeSeries(from source: [LivelinePoint]) -> [LivelineSeries] {
        let base = source.suffix(240)
        let alpha = base.enumerated().map { index, point in
            LivelinePoint(time: point.time, value: point.value + sin(Double(index) * 0.08) * 32)
        }
        let beta = base.enumerated().map { index, point in
            LivelinePoint(time: point.time, value: point.value - 120 + cos(Double(index) * 0.06) * 26)
        }
        let gamma = base.enumerated().map { index, point in
            LivelinePoint(time: point.time, value: point.value + 90 + sin(Double(index) * 0.04 + 2) * 44)
        }

        return [
            LivelineSeries(id: "alpha", data: alpha, value: alpha.last?.value ?? 0, color: .blue, label: "Alpha"),
            LivelineSeries(id: "beta", data: beta, value: beta.last?.value ?? 0, color: .red, label: "Beta"),
            LivelineSeries(id: "gamma", data: gamma, value: gamma.last?.value ?? 0, color: .green, label: "Gamma"),
        ]
    }

    private static func makeOrderbook(mid: Double) -> LivelineOrderbookData {
        let bids = (0..<12).map { index in
            LivelineOrderbookLevel(price: mid - Double(index + 1) * 4, size: Double.random(in: 0.5...18))
        }
        let asks = (0..<12).map { index in
            LivelineOrderbookLevel(price: mid + Double(index + 1) * 4, size: Double.random(in: 0.5...18))
        }
        return LivelineOrderbookData(bids: bids, asks: asks)
    }
}
