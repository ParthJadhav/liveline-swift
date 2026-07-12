import Foundation
import SwiftUI

private struct LivelineSnapshotElapsedTimeKey: EnvironmentKey {
    static let defaultValue: TimeInterval? = nil
}

extension EnvironmentValues {
    var livelineSnapshotElapsedTime: TimeInterval? {
        get { self[LivelineSnapshotElapsedTimeKey.self] }
        set { self[LivelineSnapshotElapsedTimeKey.self] = newValue }
    }
}

@_spi(LivelineSnapshotTesting)
public extension View {
    /// Injects a deterministic renderer time for screenshot infrastructure.
    func livelineSnapshotElapsedTime(_ elapsedTime: TimeInterval?) -> some View {
        let normalized = elapsedTime.flatMap { value in
            value.isFinite && value >= 0 ? value : nil
        }
        return environment(\.livelineSnapshotElapsedTime, normalized)
    }
}
