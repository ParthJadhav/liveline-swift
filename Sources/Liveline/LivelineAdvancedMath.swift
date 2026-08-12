import Foundation

struct LivelineDensitySample: Equatable {
    var value: Double
    var density: Double
}

struct LivelineDensityProfile: Equatable {
    var samples: [LivelineDensitySample]
    var minimum: Double
    var lowerQuartile: Double
    var median: Double
    var upperQuartile: Double
    var maximum: Double
    var peakDensity: Double
}

struct LivelineRenkoBrick: Equatable {
    var time: TimeInterval
    var open: Double
    var close: Double
    var sourceHigh: Double
    var sourceLow: Double

    var isRising: Bool { close >= open }
}

struct LivelinePointFigureColumn: Equatable {
    var index: Int
    var isRising: Bool
    var low: Double
    var high: Double
    var boxSize: Double

    var boxCount: Int {
        let raw = ((high - low) / boxSize).rounded(.down)
        guard raw.isFinite, raw < Double(Int.max - 1) else { return Int.max }
        return max(Int(raw) + 1, 1)
    }
}

struct LivelineMarketDepthCurve: Equatable {
    var bids: [LivelinePoint]
    var asks: [LivelinePoint]
    var bestBid: Double?
    var bestAsk: Double?
}

enum LivelineAdvancedMath {
    static func quantile(_ values: [Double], probability: Double) -> Double {
        let sorted = values.filter(\.isFinite).sorted()
        guard let first = sorted.first else { return 0 }
        guard sorted.count > 1 else { return first }
        let p = probability.livelineClamped(0, 1, fallback: 0.5)
        let position = p * Double(sorted.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = Int(position.rounded(.up))
        guard lower != upper else { return sorted[lower] }
        let fraction = position - Double(lower)
        let lowerValue = sorted[lower]
        let upperValue = sorted[upper]
        if lowerValue.sign == upperValue.sign {
            return lowerValue + (upperValue - lowerValue) * fraction
        }
        return lowerValue * (1 - fraction) + upperValue * fraction
    }

    static func median(_ values: [Double]) -> Double {
        quantile(values, probability: 0.5)
    }

    static func densityProfile(
        values: [Double],
        bandwidth requestedBandwidth: Double?,
        sampleCount: Int = 64
    ) -> LivelineDensityProfile? {
        let originalValues = values.filter(\.isFinite).sorted()
        guard let minimum = originalValues.first, let maximum = originalValues.last else { return nil }
        let maximumMagnitude = max(abs(minimum), abs(maximum))
        let doubledMagnitude = maximumMagnitude * 2
        let scale = doubledMagnitude.isFinite && doubledMagnitude > 0
            ? doubledMagnitude
            : max(maximumMagnitude, 1)
        let values = originalValues.map { $0 / scale }
        let normalizedMinimum = values[0]
        let normalizedMaximum = values[values.count - 1]
        let normalizedLowerQuartile = quantile(values, probability: 0.25)
        let normalizedMedian = quantile(values, probability: 0.5)
        let normalizedUpperQuartile = quantile(values, probability: 0.75)
        let spread = max(normalizedMaximum - normalizedMinimum, 0.000_001)
        let bandwidth: Double
        if let requestedBandwidth, requestedBandwidth.isFinite, requestedBandwidth > 0 {
            let normalized = requestedBandwidth / scale
            bandwidth = max(normalized.isFinite ? normalized : 1, 0.000_000_000_001)
        } else if values.count > 1 {
            let mean = values.reduce(0, +) / Double(values.count)
            let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count - 1)
            let standardDeviation = sqrt(max(variance, 0))
            let robustSigma = min(
                standardDeviation,
                (normalizedUpperQuartile - normalizedLowerQuartile) / 1.34)
            let scale = robustSigma > 0 ? robustSigma : spread / 4
            bandwidth = max(0.9 * scale * pow(Double(values.count), -0.2), spread / 200)
        } else {
            bandwidth = max(abs(normalizedMinimum) * 0.05, 0.000_001)
        }

        let padding = max(bandwidth * 2.5, spread * 0.04)
        let normalizedLimit = Double.greatestFiniteMagnitude / scale
        let domainMin = max(normalizedMinimum - padding, -normalizedLimit)
        let domainMax = min(normalizedMaximum + padding, normalizedLimit)
        let count = min(max(sampleCount, 24), 160)
        let gaussianScale = 1 / (Double(values.count) * bandwidth * sqrt(2 * Double.pi))
        let samples = (0..<count).map { index -> LivelineDensitySample in
            let t = Double(index) / Double(max(count - 1, 1))
            let normalizedValue = domainMin + (domainMax - domainMin) * t
            let sum = values.reduce(0) { partial, observation in
                let z = (normalizedValue - observation) / bandwidth
                return partial + exp(-0.5 * z * z)
            }
            return LivelineDensitySample(value: normalizedValue * scale, density: sum * gaussianScale)
        }
        return LivelineDensityProfile(
            samples: samples,
            minimum: minimum,
            lowerQuartile: normalizedLowerQuartile * scale,
            median: normalizedMedian * scale,
            upperQuartile: normalizedUpperQuartile * scale,
            maximum: maximum,
            peakDensity: max(samples.map(\.density).max() ?? 0, 0.000_001)
        )
    }

    static func renkoBricks(points: [LivelinePoint], brickSize: Double) -> [LivelineRenkoBrick] {
        let points = LivelineInputNormalizer.points(points)
        guard let first = points.first else { return [] }
        let size = brickSize.livelineAtLeast(0.000_001, fallback: 1)
        var anchor = (first.value / size).rounded(.down) * size
        var result: [LivelineRenkoBrick] = []
        result.reserveCapacity(points.count)

        for point in points.dropFirst() {
            let delta = point.value - anchor
            let direction = delta >= 0 ? 1.0 : -1.0
            let rawCount = (abs(delta) / size).rounded(.down)
            // A move this large cannot be represented faithfully inside the
            // bounded derived-series contract. Reject it instead of returning a
            // truncated chart whose final brick and internal anchor disagree
            // with the processed price.
            guard rawCount.isFinite, rawCount <= 10_000 else { return [] }
            let count = Int(rawCount)
            guard count > 0 else { continue }
            guard result.count <= 10_000 - count else { return [] }
            for brickIndex in 0..<count {
                let next = anchor + direction * size
                let isFinalBrick = brickIndex == count - 1
                result.append(
                    LivelineRenkoBrick(
                        time: point.time,
                        open: anchor,
                        close: next,
                        sourceHigh: isFinalBrick ? max(anchor, point.value) : max(anchor, next),
                        sourceLow: isFinalBrick ? min(anchor, point.value) : min(anchor, next)
                    )
                )
                anchor = next
            }
        }
        return result
    }

    static func heikinAshiCandles(_ candles: [LivelineCandle]) -> [LivelineCandle] {
        let candles = LivelineInputNormalizer.candles(candles)
        guard let first = candles.first else { return [] }
        var result: [LivelineCandle] = []
        result.reserveCapacity(candles.count)

        var previousOpen = (first.open + first.close) / 2
        var previousClose = (first.open + first.high + first.low + first.close) / 4
        result.append(
            LivelineCandle(
                time: first.time,
                open: previousOpen,
                high: max(first.high, previousOpen, previousClose),
                low: min(first.low, previousOpen, previousClose),
                close: previousClose
            )
        )

        for candle in candles.dropFirst() {
            let close = (candle.open + candle.high + candle.low + candle.close) / 4
            let open = (previousOpen + previousClose) / 2
            result.append(
                LivelineCandle(
                    time: candle.time,
                    open: open,
                    high: max(candle.high, open, close),
                    low: min(candle.low, open, close),
                    close: close
                )
            )
            previousOpen = open
            previousClose = close
        }
        return result
    }

    static func pointFigureColumns(
        points: [LivelinePoint],
        boxSize: Double,
        reversalBoxes: Int
    ) -> [LivelinePointFigureColumn] {
        let points = LivelineInputNormalizer.points(points)
        guard points.count >= 2, let first = points.first else { return [] }
        let size = boxSize.livelineAtLeast(0.000_001, fallback: 1)
        let reversal = max(reversalBoxes, 1)
        var anchor = (first.value / size).rounded() * size
        guard anchor.isFinite else { return [] }
        var direction: Int = 0
        var columns: [LivelinePointFigureColumn] = []

        for point in points.dropFirst() {
            guard
                let upBoxes = representableBoxDelta(point.value - anchor, size: size),
                let downBoxes = representableBoxDelta(anchor - point.value, size: size)
            else { return [] }

            if direction == 0 {
                if upBoxes >= 1 {
                    direction = 1
                    let high = anchor + Double(upBoxes) * size
                    columns.append(
                        .init(index: 0, isRising: true, low: anchor + size, high: high, boxSize: size))
                    anchor = high
                } else if downBoxes >= 1 {
                    direction = -1
                    let low = anchor - Double(downBoxes) * size
                    columns.append(
                        .init(index: 0, isRising: false, low: low, high: anchor - size, boxSize: size))
                    anchor = low
                }
                continue
            }

            if direction > 0 {
                if upBoxes >= 1, var last = columns.last {
                    last.high = anchor + Double(upBoxes) * size
                    columns[columns.count - 1] = last
                    anchor = last.high
                } else if downBoxes >= reversal {
                    direction = -1
                    let high = anchor - size
                    let low = anchor - Double(downBoxes) * size
                    columns.append(
                        .init(index: columns.count, isRising: false, low: low, high: high, boxSize: size))
                    anchor = low
                }
            } else if downBoxes >= 1, var last = columns.last {
                last.low = anchor - Double(downBoxes) * size
                columns[columns.count - 1] = last
                anchor = last.low
            } else if upBoxes >= reversal {
                direction = 1
                let low = anchor + size
                let high = anchor + Double(upBoxes) * size
                columns.append(
                    .init(index: columns.count, isRising: true, low: low, high: high, boxSize: size))
                anchor = high
            }
        }
        return columns
    }

    private static func representableBoxDelta(_ delta: Double, size: Double) -> Int? {
        let quotient = (delta / size).rounded(.down)
        guard
            quotient.isFinite,
            quotient > Double(Int.min),
            quotient < Double(Int.max)
        else { return nil }
        return Int(quotient)
    }

    static func marketDepthLevels(_ levels: [LivelineOrderBookLevel]) -> [LivelineOrderBookLevel] {
        var sizesByPrice: [Double: (bid: Double, ask: Double)] = [:]
        for level in levels {
            let current = sizesByPrice[level.price] ?? (0, 0)
            let bid = current.bid + level.bidSize
            let ask = current.ask + level.askSize
            sizesByPrice[level.price] = (
                bid.isFinite ? bid : Double.greatestFiniteMagnitude,
                ask.isFinite ? ask : Double.greatestFiniteMagnitude)
        }
        return sizesByPrice.map {
            LivelineOrderBookLevel(price: $0.key, bidSize: $0.value.bid, askSize: $0.value.ask)
        }.sorted { $0.price < $1.price }
    }

    static func marketDepthCurve(_ levels: [LivelineOrderBookLevel]) -> LivelineMarketDepthCurve {
        let levels = marketDepthLevels(levels)
        let bids = levels.filter { $0.bidSize > 0 }.sorted { $0.price > $1.price }
        let asks = levels.filter { $0.askSize > 0 }.sorted { $0.price < $1.price }
        var bidTotal = 0.0
        let bidPoints = bids.map { level -> LivelinePoint in
            let total = bidTotal + level.bidSize
            bidTotal = total.isFinite ? total : Double.greatestFiniteMagnitude
            return LivelinePoint(time: level.price, value: bidTotal)
        }.sorted { $0.time < $1.time }
        var askTotal = 0.0
        let askPoints = asks.map { level -> LivelinePoint in
            let total = askTotal + level.askSize
            askTotal = total.isFinite ? total : Double.greatestFiniteMagnitude
            return LivelinePoint(time: level.price, value: askTotal)
        }
        return LivelineMarketDepthCurve(
            bids: bidPoints,
            asks: askPoints,
            bestBid: bids.first?.price,
            bestAsk: asks.first?.price
        )
    }
}
