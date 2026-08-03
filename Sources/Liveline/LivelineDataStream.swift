import Foundation
import SwiftUI

/// A bounded, time-ordered buffer of ``LivelinePoint`` values for streaming
/// charts.
///
/// Live feeds arrive one sample at a time and almost always in order. The
/// stream keeps the samples sorted by time, drops everything older than the
/// configured capacity or retention window, and publishes the result so a view
/// can hand it straight to a ``LivelineChart`` initializer:
///
/// ```swift
/// @StateObject private var stream = LivelineDataStream(capacity: 600)
///
/// var body: some View {
///     LivelineChart(data: stream.points, value: stream.points.last?.value ?? 0)
///         .task {
///             try? await stream.consume(ticks)
///         }
/// }
/// ```
///
/// Appending a sample newer than the current last one is an O(1) amortized
/// array append; only an out-of-order sample pays for a binary-search insert.
/// Because every published array holds finite, strictly increasing times, it
/// satisfies the renderer's sorted-input fast path — the normalizer hands the
/// caller's own buffer to the render pipeline instead of sorting and copying it
/// on every frame.
///
/// The class is `@MainActor` because `@Published` drives SwiftUI updates.
@MainActor
public final class LivelineDataStream: ObservableObject {
    /// Roughly ten minutes of one-hertz samples: enough history for the longest
    /// built-in window option without letting an unattended feed grow forever.
    public nonisolated static let defaultCapacity = 600

    /// The buffered samples, oldest first, with strictly increasing times.
    @Published public private(set) var points: [LivelinePoint] = []

    /// The largest number of samples the stream keeps. Older samples are
    /// trimmed from the front once the buffer grows past it.
    public var capacity: Int {
        didSet {
            capacity = Self.normalizedCapacity(capacity)
            trim()
        }
    }

    /// An optional time window, in seconds, measured back from the newest
    /// sample. Samples older than it are trimmed even when the buffer is under
    /// capacity. `nil` keeps everything capacity allows.
    public var retention: TimeInterval? {
        didSet {
            retention = Self.normalizedRetention(retention)
            trim()
        }
    }

    /// Creates an empty stream.
    ///
    /// - Parameters:
    ///   - capacity: The largest number of samples to keep. Values below one
    ///     are raised to one.
    ///   - retention: An optional age limit in seconds, relative to the newest
    ///     sample. Non-finite or non-positive values are treated as `nil`.
    public init(capacity: Int = LivelineDataStream.defaultCapacity, retention: TimeInterval? = nil) {
        self.capacity = Self.normalizedCapacity(capacity)
        self.retention = Self.normalizedRetention(retention)
    }

    /// Appends one sample, keeping the buffer sorted by time.
    ///
    /// A sample newer than the current last one takes the append fast path. A
    /// sample that repeats an existing time replaces that entry, which is how
    /// the renderer's own normalizer resolves duplicate timestamps. Samples
    /// with a non-finite time or value are ignored.
    public func append(_ point: LivelinePoint) {
        guard insert(point) else { return }
        trim()
    }

    /// Appends a batch of samples, keeping the buffer sorted by time.
    ///
    /// Trimming runs once for the whole batch rather than once per sample.
    public func append(contentsOf newPoints: some Sequence<LivelinePoint>) {
        var changed = false
        for point in newPoints where insert(point) {
            changed = true
        }
        guard changed else { return }
        trim()
    }

    /// Replaces the buffer with `newPoints`, sorting, de-duplicating, and
    /// trimming them the same way ``append(_:)`` would.
    public func replace(_ newPoints: [LivelinePoint]) {
        points.removeAll(keepingCapacity: true)
        points.reserveCapacity(newPoints.count)
        for point in newPoints {
            _ = insert(point)
        }
        trim()
    }

    /// Empties the buffer.
    public func removeAll() {
        guard !points.isEmpty else { return }
        points.removeAll(keepingCapacity: true)
    }

    /// Appends every value an asynchronous sequence produces, as it arrives.
    ///
    /// The method returns when the sequence finishes, and rethrows whatever the
    /// sequence throws. Cancelling the surrounding task stops consumption and
    /// leaves the samples appended so far in place.
    ///
    /// ```swift
    /// .task { try? await stream.consume(priceTicks) }
    /// ```
    public func consume<Source: AsyncSequence>(_ sequence: Source) async throws
    where Source.Element == LivelinePoint {
        for try await point in sequence {
            append(point)
        }
    }

    // MARK: - Internals

    /// Inserts one sample and reports whether the buffer changed. The common
    /// case — a sample newer than everything buffered — is a plain append.
    @discardableResult
    private func insert(_ point: LivelinePoint) -> Bool {
        guard point.time.isFinite, point.value.isFinite else { return false }
        let normalized = LivelinePoint(
            time: min(max(point.time, -LivelineScalar.maximumTimeMagnitude), LivelineScalar.maximumTimeMagnitude),
            value: LivelineScalar.value(point.value)
        )

        guard let last = points.last else {
            points.append(normalized)
            return true
        }
        if normalized.time > last.time {
            points.append(normalized)
            return true
        }
        if normalized.time == last.time {
            points[points.count - 1] = normalized
            return true
        }

        let index = insertionIndex(for: normalized.time)
        if index < points.count, points[index].time == normalized.time {
            points[index] = normalized
        } else {
            points.insert(normalized, at: index)
        }
        return true
    }

    /// First index whose time is greater than or equal to `time`.
    private func insertionIndex(for time: TimeInterval) -> Int {
        var lower = 0
        var upper = points.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if points[middle].time < time {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower
    }

    private func trim() {
        if let retention, let newest = points.last?.time {
            let oldest = newest - retention
            if let first = points.first, first.time < oldest {
                let index = insertionIndex(for: oldest)
                if index > 0 {
                    points.removeFirst(index)
                }
            }
        }
        if points.count > capacity {
            points.removeFirst(points.count - capacity)
        }
    }

    private static func normalizedCapacity(_ capacity: Int) -> Int {
        max(capacity, 1)
    }

    private static func normalizedRetention(_ retention: TimeInterval?) -> TimeInterval? {
        retention.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
    }
}
