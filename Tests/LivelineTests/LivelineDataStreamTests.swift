import XCTest
@testable import Liveline

final class LivelineDataStreamTests: XCTestCase {
    @MainActor
    func testAppendKeepsSamplesOrderedAndReplacesDuplicateTimes() {
        let stream = LivelineDataStream()
        stream.append(LivelinePoint(time: 1, value: 10))
        stream.append(LivelinePoint(time: 3, value: 30))
        // Out of order: must slot in rather than land at the end.
        stream.append(LivelinePoint(time: 2, value: 20))
        // Repeated time: replaces the existing sample, matching the renderer's
        // own duplicate-timestamp rule.
        stream.append(LivelinePoint(time: 3, value: 33))

        XCTAssertEqual(stream.points, [
            LivelinePoint(time: 1, value: 10),
            LivelinePoint(time: 2, value: 20),
            LivelinePoint(time: 3, value: 33),
        ])
    }

    @MainActor
    func testAppendIgnoresNonFiniteSamples() {
        let stream = LivelineDataStream()
        stream.append(LivelinePoint(time: 1, value: 10))
        stream.append(LivelinePoint(time: .nan, value: 5))
        stream.append(LivelinePoint(time: 2, value: .infinity))

        XCTAssertEqual(stream.points, [LivelinePoint(time: 1, value: 10)])
    }

    @MainActor
    func testAppendContentsOfTrimsToCapacityFromTheFront() {
        let stream = LivelineDataStream(capacity: 3)
        stream.append(contentsOf: (1...10).map { LivelinePoint(time: TimeInterval($0), value: Double($0)) })

        XCTAssertEqual(stream.points.map(\.time), [8, 9, 10])
    }

    @MainActor
    func testRetentionDropsSamplesOlderThanTheWindow() {
        let stream = LivelineDataStream(capacity: 100, retention: 5)
        stream.append(contentsOf: (0...10).map { LivelinePoint(time: TimeInterval($0), value: Double($0)) })

        XCTAssertEqual(stream.points.first?.time, 5)
        XCTAssertEqual(stream.points.last?.time, 10)

        // Tightening the window trims immediately.
        stream.retention = 2
        XCTAssertEqual(stream.points.map(\.time), [8, 9, 10])
    }

    @MainActor
    func testRetentionIgnoresNonPositiveWindows() {
        let stream = LivelineDataStream(capacity: 10, retention: -1)
        XCTAssertNil(stream.retention)
        stream.append(contentsOf: (0...3).map { LivelinePoint(time: TimeInterval($0), value: 1) })
        XCTAssertEqual(stream.points.count, 4)
    }

    @MainActor
    func testReplaceSortsDeduplicatesAndTrims() {
        let stream = LivelineDataStream(capacity: 3)
        stream.append(LivelinePoint(time: 99, value: 1))
        stream.replace([
            LivelinePoint(time: 4, value: 4),
            LivelinePoint(time: 1, value: 1),
            LivelinePoint(time: 3, value: 3),
            LivelinePoint(time: 1, value: 11),
            LivelinePoint(time: 2, value: 2),
        ])

        XCTAssertEqual(stream.points, [
            LivelinePoint(time: 2, value: 2),
            LivelinePoint(time: 3, value: 3),
            LivelinePoint(time: 4, value: 4),
        ])
    }

    @MainActor
    func testRemoveAllEmptiesTheBuffer() {
        let stream = LivelineDataStream()
        stream.append(LivelinePoint(time: 1, value: 1))
        stream.removeAll()
        XCTAssertTrue(stream.points.isEmpty)
    }

    /// The whole point of keeping the buffer sorted: the renderer's normalizer
    /// must hand the stream's own array straight through instead of sorting and
    /// copying it on every frame.
    @MainActor
    func testPublishedPointsSatisfyTheNormalizerFastPath() {
        let stream = LivelineDataStream(capacity: 50)
        stream.append(contentsOf: (0..<40).map { LivelinePoint(time: TimeInterval($0), value: Double($0 % 7)) })
        stream.append(LivelinePoint(time: 12.5, value: 3))
        stream.append(LivelinePoint(time: 40, value: 1))

        let points = stream.points
        XCTAssertTrue(LivelineInputNormalizer.points(points).livelineSharesStorage(with: points))
    }

    @MainActor
    func testConsumeAppendsValuesFromAnAsyncSequence() async throws {
        let stream = LivelineDataStream()
        let sequence = AsyncStream<LivelinePoint> { continuation in
            for index in 1...4 {
                continuation.yield(LivelinePoint(time: TimeInterval(index), value: Double(index)))
            }
            continuation.finish()
        }

        try await stream.consume(sequence)

        XCTAssertEqual(stream.points.map(\.value), [1, 2, 3, 4])
    }
}
