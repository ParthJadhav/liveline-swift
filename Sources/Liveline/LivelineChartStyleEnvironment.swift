import SwiftUI

private struct LivelineChartStyleOverrideKey: EnvironmentKey {
    static let defaultValue: LivelineChartStyle? = nil
}

extension EnvironmentValues {
    var livelineChartStyleOverride: LivelineChartStyle? {
        get { self[LivelineChartStyleOverrideKey.self] }
        set { self[LivelineChartStyleOverrideKey.self] = newValue }
    }
}

public extension View {
    /// Overrides the rendering style of every ``LivelineChart`` below this view.
    ///
    /// Apply this to a container when a group of charts should switch styles
    /// together. Passing `nil` preserves each chart's configured style.
    func livelineChartStyle(_ style: LivelineChartStyle?) -> some View {
        environment(\.livelineChartStyleOverride, style)
    }
}
