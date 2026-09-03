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
    static func proportions(_ values: [Double]) -> [Double] {
        let positive = values.map { $0.isFinite && $0 > 0 ? $0 : 0 }
        guard let scale = positive.max(), scale > 0 else {
            return Array(repeating: 0, count: values.count)
        }
        let scaled = positive.map { $0 / scale }
        let total = scaled.reduce(0, +)
        guard total.isFinite, total > 0 else {
            return Array(repeating: 0, count: values.count)
        }
        return scaled.map { $0 / total }
    }

    static func quantile(_ values: [Double], probability: Double) -> Double {
        quantile(sortedFinite: values.filter(\.isFinite).sorted(), probability: probability)
    }

    /// Quantile over data the caller has already filtered to finite values and
    /// sorted ascending, so profiles that need several cuts sort only once.
    private static func quantile(sortedFinite sorted: [Double], probability: Double) -> Double {
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
        // `values` is already finite and sorted (dividing by a positive scale
        // preserves order), so the quantiles skip re-filtering and re-sorting.
        let normalizedLowerQuartile = quantile(sortedFinite: values, probability: 0.25)
        let normalizedMedian = quantile(sortedFinite: values, probability: 0.5)
        let normalizedUpperQuartile = quantile(sortedFinite: values, probability: 0.75)
        let spread = max(normalizedMaximum - normalizedMinimum, 0.000_001)
        let bandwidth: Double
        if let requestedBandwidth, requestedBandwidth.isFinite, requestedBandwidth > 0 {
            let normalized = requestedBandwidth / scale
            bandwidth = max(normalized.isFinite ? normalized : 1, 0.000_000_000_001)
        } else if values.count > 1 {
            let mean = values.reduce(0, +) / Double(values.count)
            let variance = values.reduce(0) {
                let deviation = $1 - mean
                return $0 + deviation * deviation
            } / Double(values.count - 1)
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
        // Observations beyond six bandwidths contribute less than 2e-8 of a
        // kernel's mass, so each sample sums only the sorted window around it,
        // found by binary search instead of walking every observation.
        let inverseBandwidth = 1 / bandwidth
        let kernelReach = bandwidth * 6
        var peakDensity = 0.0
        var samples: [LivelineDensitySample] = []
        samples.reserveCapacity(count)
        for index in 0..<count {
            let t = Double(index) / Double(max(count - 1, 1))
            let normalizedValue = domainMin + (domainMax - domainMin) * t
            let window = sortedRange(
                of: values,
                from: normalizedValue - kernelReach,
                through: normalizedValue + kernelReach
            )
            var sum = 0.0
            for observation in values[window] {
                let z = (normalizedValue - observation) * inverseBandwidth
                sum += exp(-0.5 * z * z)
            }
            let density = sum * gaussianScale
            peakDensity = max(peakDensity, density)
            samples.append(LivelineDensitySample(value: normalizedValue * scale, density: density))
        }
        return LivelineDensityProfile(
            samples: samples,
            minimum: minimum,
            lowerQuartile: normalizedLowerQuartile * scale,
            median: normalizedMedian * scale,
            upperQuartile: normalizedUpperQuartile * scale,
            maximum: maximum,
            peakDensity: max(peakDensity, 0.000_001)
        )
    }

    /// The index range of a sorted array whose elements fall in
    /// `lowerBound...upperBound`, found with two binary searches.
    private static func sortedRange(
        of sorted: [Double],
        from lowerBound: Double,
        through upperBound: Double
    ) -> Range<Int> {
        var low = 0
        var high = sorted.count
        while low < high {
            let mid = (low + high) / 2
            if sorted[mid] < lowerBound { low = mid + 1 } else { high = mid }
        }
        let start = low
        high = sorted.count
        while low < high {
            let mid = (low + high) / 2
            if sorted[mid] <= upperBound { low = mid + 1 } else { high = mid }
        }
        return start..<low
    }

    static func renkoBricks(points: [LivelinePoint], brickSize: Double) -> [LivelineRenkoBrick] {
        let points = LivelineInputNormalizer.points(points)
        guard let first = points.first else { return [] }
        let size = brickSize.livelinePositive(atLeast: 0.000_001, fallback: 1)
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
            guard count > 0 else {
                if let lastIndex = result.indices.last {
                    result[lastIndex].sourceHigh = max(result[lastIndex].sourceHigh, point.value)
                    result[lastIndex].sourceLow = min(result[lastIndex].sourceLow, point.value)
                }
                continue
            }
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

        func average(_ values: Double...) -> Double {
            values.reduce(0) { $0 + $1 / Double(values.count) }
        }

        var previousOpen = average(first.open, first.close)
        var previousClose = average(first.open, first.high, first.low, first.close)
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
            let close = average(candle.open, candle.high, candle.low, candle.close)
            let open = average(previousOpen, previousClose)
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
        let size = boxSize.livelinePositive(atLeast: 0.000_001, fallback: 1)
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
        var maximumBidSize = -Double.infinity
        var maximumAskSize = -Double.infinity
        for level in levels {
            if level.bidSize > maximumBidSize { maximumBidSize = level.bidSize }
            if level.askSize > maximumAskSize { maximumAskSize = level.askSize }
        }
        let bidScale = max(levels.isEmpty ? 0 : maximumBidSize, 0.000_001)
        let askScale = max(levels.isEmpty ? 0 : maximumAskSize, 0.000_001)
        var sizesByPrice: [Double: (bid: Double, ask: Double, normalizedBid: Double, normalizedAsk: Double)] = [:]
        sizesByPrice.reserveCapacity(levels.count)
        var bidOverflowed = false
        var askOverflowed = false
        for level in levels {
            let current = sizesByPrice[level.price] ?? (0, 0, 0, 0)
            let bid = current.bid + level.bidSize
            let ask = current.ask + level.askSize
            if !bid.isFinite { bidOverflowed = true }
            if !ask.isFinite { askOverflowed = true }
            sizesByPrice[level.price] = (
                bid.isFinite ? bid : Double.greatestFiniteMagnitude,
                ask.isFinite ? ask : Double.greatestFiniteMagnitude,
                current.normalizedBid + level.bidSize / bidScale,
                current.normalizedAsk + level.askSize / askScale)
        }
        // The normalized maxima only rescale overflowed sides, so the extra
        // passes run only in that degenerate case.
        let maximumNormalizedBid = bidOverflowed
            ? max(sizesByPrice.values.lazy.map(\.normalizedBid).max() ?? 0, 0.000_001)
            : 0.000_001
        let maximumNormalizedAsk = askOverflowed
            ? max(sizesByPrice.values.lazy.map(\.normalizedAsk).max() ?? 0, 0.000_001)
            : 0.000_001
        var merged = sizesByPrice.map { price, sizes in
            LivelineOrderBookLevel(
                price: price,
                bidSize: bidOverflowed
                    ? sizes.normalizedBid / maximumNormalizedBid * bidScale
                    : sizes.bid,
                askSize: askOverflowed
                    ? sizes.normalizedAsk / maximumNormalizedAsk * askScale
                    : sizes.ask)
        }
        merged.sort { $0.price < $1.price }
        return merged
    }

    private static func cumulativeDepthPoints(
        _ levels: [LivelineOrderBookLevel],
        size: (LivelineOrderBookLevel) -> Double
    ) -> [LivelinePoint] {
        var maximumSize = -Double.infinity
        for level in levels {
            let levelSize = size(level)
            if levelSize > maximumSize { maximumSize = levelSize }
        }
        let scale = max(levels.isEmpty ? 0 : maximumSize, 0.000_001)
        var rawTotal = 0.0
        var overflowed = false
        var points: [LivelinePoint] = []
        points.reserveCapacity(levels.count)
        for level in levels {
            let nextRawTotal = rawTotal + size(level)
            if nextRawTotal.isFinite {
                rawTotal = nextRawTotal
            } else {
                overflowed = true
            }
            points.append(LivelinePoint(time: level.price, value: rawTotal))
        }
        guard overflowed else { return points }

        // Overflow fallback: rebuild from normalized running totals. This
        // second pass runs only when a cumulative side exceeds Double range.
        var normalizedTotal = 0.0
        var normalizedTotals: [Double] = []
        normalizedTotals.reserveCapacity(levels.count)
        for level in levels {
            normalizedTotal += size(level) / scale
            normalizedTotals.append(normalizedTotal)
        }
        let maximumNormalizedTotal = max(normalizedTotals.last ?? 0, 0.000_001)
        return levels.indices.map { index in
            LivelinePoint(
                time: levels[index].price,
                value: normalizedTotals[index] / maximumNormalizedTotal * scale)
        }
    }

    static func marketDepthCurve(_ levels: [LivelineOrderBookLevel]) -> LivelineMarketDepthCurve {
        // `marketDepthLevels` merges duplicate prices and returns levels sorted
        // ascending, so both sides come from cheap filters and reversals
        // rather than fresh sorts.
        let levels = marketDepthLevels(levels)
        let ascendingBids = levels.filter { $0.bidSize > 0 }
        let asks = levels.filter { $0.askSize > 0 }
        let bids = Array(ascendingBids.reversed())
        var bidPoints = cumulativeDepthPoints(bids) { $0.bidSize }
        bidPoints.reverse()
        let askPoints = cumulativeDepthPoints(asks) { $0.askSize }
        return LivelineMarketDepthCurve(
            bids: bidPoints,
            asks: askPoints,
            bestBid: bids.first?.price,
            bestAsk: asks.first?.price
        )
    }
}
