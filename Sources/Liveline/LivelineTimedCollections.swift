import Foundation

protocol LivelineTimedDatum {
    var time: TimeInterval { get }
}

extension LivelinePoint: LivelineTimedDatum {}
extension LivelineRangePoint: LivelineTimedDatum {}
extension LivelineBubblePoint: LivelineTimedDatum {}
extension LivelineBoxPlotPoint: LivelineTimedDatum {}
extension LivelineCandle: LivelineTimedDatum {}
extension LivelineErrorBarPoint: LivelineTimedDatum {}
extension LivelineDumbbellPoint: LivelineTimedDatum {}
extension LivelineStackedPoint: LivelineTimedDatum {}
extension LivelineHeatmapCell: LivelineTimedDatum {}

extension Array where Element: LivelineTimedDatum {
    func livelineVisible(in range: ClosedRange<TimeInterval>) -> [Element] {
        guard !isEmpty else { return [] }
        let lower = lowerBound(for: range.lowerBound)
        let upper = upperBound(for: range.upperBound)
        guard lower < upper else { return [] }
        return Array(self[lower..<upper])
    }

    private func lowerBound(for time: TimeInterval) -> Int {
        var lower = 0
        var upper = count
        while lower < upper {
            let middle = (lower + upper) / 2
            if self[middle].time < time {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower
    }

    private func upperBound(for time: TimeInterval) -> Int {
        var lower = 0
        var upper = count
        while lower < upper {
            let middle = (lower + upper) / 2
            if self[middle].time <= time {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower
    }
}

extension Array {
    func livelineSuffix(_ maximumLength: Int) -> [Element] {
        Array(suffix(Swift.max(maximumLength, 0)))
    }

    /// Opaque address of the backing buffer. Only ever compared, never
    /// dereferenced, so it is a cheap way to prove two arrays are the same
    /// samples without walking them.
    var livelineStorageIdentity: UInt {
        withUnsafeBufferPointer { buffer in
            buffer.baseAddress.map { UInt(bitPattern: UnsafeRawPointer($0)) } ?? 0
        }
    }

    func livelineSharesStorage(with other: [Element]) -> Bool {
        count == other.count && livelineStorageIdentity == other.livelineStorageIdentity
    }
}

extension Array where Element == LivelineCandle {
    func livelineVisible(in range: ClosedRange<TimeInterval>, candleWidth: TimeInterval)
        -> [LivelineCandle]
    {
        let width = LivelineInputNormalizer.positive(candleWidth, fallback: 1)
        return livelineVisible(in: (range.lowerBound - width)...range.upperBound)
            .filter { $0.time + width >= range.lowerBound }
    }
}
