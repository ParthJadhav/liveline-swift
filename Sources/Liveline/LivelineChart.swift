import SwiftUI

/// A SwiftUI chart view for real-time line, candlestick, and multi-series data.
///
/// The view fills the size given by its parent. In most apps you will use it with
/// an explicit height:
///
/// ```swift
/// LivelineChart(data: points, value: latest)
///     .frame(height: 280)
/// ```
public struct LivelineChart: View {
    private let content: LivelineChartContent
    private let accent: Color
    private let baseConfiguration: LivelineChartConfiguration

    @StateObject private var renderState = LivelineRenderState()
    @State private var activeWindow: TimeInterval
    @State private var hoverLocation: CGPoint?
    @State private var lineMode: Bool
    @State private var hiddenSeries: Set<String> = []

    public init(
        data: [LivelinePoint],
        value: Double,
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.content = .line(data: data, value: value)
        self.accent = color
        self.baseConfiguration = configuration
        _activeWindow = State(initialValue: configuration.windows.first?.seconds ?? configuration.window)
        _lineMode = State(initialValue: configuration.lineMode)
    }

    public init(
        series: [LivelineSeries],
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.content = .series(series)
        self.accent = series.first?.color ?? Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255)
        self.baseConfiguration = configuration
        _activeWindow = State(initialValue: configuration.windows.first?.seconds ?? configuration.window)
        _lineMode = State(initialValue: configuration.lineMode)
    }

    public init(
        data: [LivelinePoint],
        value: Double,
        candles: [LivelineCandle],
        candleWidth: TimeInterval,
        liveCandle: LivelineCandle? = nil,
        lineData: [LivelinePoint] = [],
        lineValue: Double? = nil,
        color: Color = Color(red: 247 / 255, green: 147 / 255, blue: 26 / 255),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.content = .candle(
            data: data,
            value: value,
            candles: candles,
            candleWidth: candleWidth,
            liveCandle: liveCandle,
            lineData: lineData,
            lineValue: lineValue
        )
        self.accent = color
        self.baseConfiguration = configuration
        _activeWindow = State(initialValue: configuration.windows.first?.seconds ?? configuration.window)
        _lineMode = State(initialValue: configuration.lineMode)
    }

    public var body: some View {
        let configuration = effectiveConfiguration

        VStack(alignment: .leading, spacing: 6) {
            if configuration.showValue {
                Text(configuration.formatValue(currentValue))
                    .font(.system(size: 20, weight: .medium, design: .monospaced))
                    .foregroundColor(valueColor(configuration: configuration))
                    .padding(.leading, resolvedLeftPadding(configuration))
                    .padding(.top, 4)
                    .animation(.easeOut(duration: 0.2), value: currentMomentum)
            }

            if hasControls(configuration) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        windowControls(configuration)
                        modeControls(configuration)
                        seriesControls(configuration)
                    }
                    .padding(.leading, resolvedLeftPadding(configuration))
                    .padding(.trailing, 8)
                }
                .frame(height: 34)
            }

            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                Canvas { context, size in
                    LivelineRenderer.draw(
                        context: &context,
                        state: renderState,
                        input: LivelineRenderInput(
                            content: content,
                            accent: accent,
                            configuration: configuration,
                            activeWindow: activeWindow,
                            hiddenSeries: hiddenSeries,
                            hoverLocation: hoverLocation,
                            timestamp: timeline.date.timeIntervalSince1970,
                            size: size
                        )
                    )
                }
                .contentShape(Rectangle())
                .gesture(scrubGesture(configuration))
            }
        }
        .onChange(of: baseConfiguration.window) { newValue in
            if baseConfiguration.windows.isEmpty {
                activeWindow = newValue
            }
        }
        .onDisappear {
            baseConfiguration.onHover?(nil)
        }
    }
}

private extension LivelineChart {
    var effectiveConfiguration: LivelineChartConfiguration {
        var configuration = baseConfiguration
        configuration.lineMode = lineMode
        return configuration
    }

    var currentValue: Double {
        switch content {
        case let .line(_, value):
            return value
        case let .candle(_, value, _, _, liveCandle, _, lineValue):
            return lineValue ?? liveCandle?.close ?? value
        case let .series(series):
            return series.first(where: { !hiddenSeries.contains($0.id) })?.value ?? series.first?.value ?? 0
        }
    }

    var currentMomentum: LivelineMomentum {
        switch content {
        case let .line(data, _):
            return LivelineMath.detectMomentum(points: data)
        case let .candle(data, _, _, _, _, lineData, _):
            return LivelineMath.detectMomentum(points: lineData.isEmpty ? data : lineData)
        case let .series(series):
            return LivelineMath.detectMomentum(points: series.first(where: { !hiddenSeries.contains($0.id) })?.data ?? [])
        }
    }

    func valueColor(configuration: LivelineChartConfiguration) -> Color {
        guard configuration.valueMomentumColor else {
            return configuration.theme == .dark ? Color.white.opacity(0.85) : Color(red: 17 / 255, green: 17 / 255, blue: 17 / 255)
        }

        switch currentMomentum {
        case .up:
            return Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255)
        case .down:
            return Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255)
        case .flat:
            return configuration.theme == .dark ? Color.white.opacity(0.85) : Color(red: 17 / 255, green: 17 / 255, blue: 17 / 255)
        }
    }

    func resolvedLeftPadding(_ configuration: LivelineChartConfiguration) -> CGFloat {
        configuration.padding.left ?? 12
    }

    func hasControls(_ configuration: LivelineChartConfiguration) -> Bool {
        !configuration.windows.isEmpty || shouldShowModeControls(configuration) || shouldShowSeriesControls
    }

    func shouldShowModeControls(_ configuration: LivelineChartConfiguration) -> Bool {
        if case .candle = content {
            return configuration.onModeChange != nil
        }
        return false
    }

    var shouldShowSeriesControls: Bool {
        if case let .series(series) = content {
            return series.count > 1
        }
        return false
    }

    @ViewBuilder
    func windowControls(_ configuration: LivelineChartConfiguration) -> some View {
        if !configuration.windows.isEmpty {
            HStack(spacing: 2) {
                ForEach(configuration.windows) { option in
                    Button {
                        activeWindow = option.seconds
                        configuration.onWindowChange?(option.seconds)
                    } label: {
                        Text(option.label)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .lineLimit(1)
                            .padding(.horizontal, configuration.windowStyle == .text ? 4 : 9)
                            .frame(height: 26)
                            .foregroundColor(activeWindow == option.seconds ? activeControlColor(configuration) : inactiveControlColor(configuration))
                            .background(controlBackground(active: activeWindow == option.seconds, configuration: configuration))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(configuration.windowStyle == .text ? 0 : 3)
            .background(groupBackground(configuration))
            .clipShape(RoundedRectangle(cornerRadius: configuration.windowStyle == .rounded ? 14 : 7, style: .continuous))
        }
    }

    @ViewBuilder
    func modeControls(_ configuration: LivelineChartConfiguration) -> some View {
        if shouldShowModeControls(configuration) {
            HStack(spacing: 2) {
                modeButton(title: "Candle", mode: .candle, active: !lineMode, configuration: configuration)
                modeButton(title: "Line", mode: .line, active: lineMode, configuration: configuration)
            }
            .padding(3)
            .background(groupBackground(configuration))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }

    func modeButton(title: String, mode: LivelineChartMode, active: Bool, configuration: LivelineChartConfiguration) -> some View {
        Button {
            lineMode = mode == .line
            configuration.onModeChange?(mode)
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .lineLimit(1)
                .padding(.horizontal, 9)
                .frame(height: 26)
                .foregroundColor(active ? activeControlColor(configuration) : inactiveControlColor(configuration))
                .background(controlBackground(active: active, configuration: configuration))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    func seriesControls(_ configuration: LivelineChartConfiguration) -> some View {
        if case let .series(series) = content, series.count > 1 {
            HStack(spacing: 5) {
                ForEach(series) { entry in
                    let visible = !hiddenSeries.contains(entry.id)
                    Button {
                        toggleSeries(entry.id, series: series, configuration: configuration)
                    } label: {
                        HStack(spacing: configuration.seriesToggleCompact ? 0 : 5) {
                            Circle()
                                .fill(entry.color)
                                .frame(width: 8, height: 8)
                            if !configuration.seriesToggleCompact {
                                Text(entry.label ?? entry.id)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, configuration.seriesToggleCompact ? 8 : 9)
                        .frame(height: 26)
                        .foregroundColor(visible ? activeControlColor(configuration) : inactiveControlColor(configuration))
                        .background(controlBackground(active: visible, configuration: configuration))
                        .opacity(visible ? 1 : 0.55)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    func toggleSeries(_ id: String, series: [LivelineSeries], configuration: LivelineChartConfiguration) {
        if hiddenSeries.contains(id) {
            hiddenSeries.remove(id)
            configuration.onSeriesToggle?(id, true)
        } else {
            let visibleCount = series.filter { !hiddenSeries.contains($0.id) }.count
            guard visibleCount > 1 else { return }
            hiddenSeries.insert(id)
            configuration.onSeriesToggle?(id, false)
        }
    }

    func activeControlColor(_ configuration: LivelineChartConfiguration) -> Color {
        configuration.theme == .dark ? Color.white.opacity(0.78) : Color.black.opacity(0.68)
    }

    func inactiveControlColor(_ configuration: LivelineChartConfiguration) -> Color {
        configuration.theme == .dark ? Color.white.opacity(0.28) : Color.black.opacity(0.28)
    }

    func groupBackground(_ configuration: LivelineChartConfiguration) -> Color {
        switch configuration.windowStyle {
        case .text:
            return .clear
        case .default, .rounded:
            return configuration.theme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.045)
        }
    }

    func controlBackground(active: Bool, configuration: LivelineChartConfiguration) -> some View {
        Group {
            if configuration.windowStyle == .text {
                Color.clear
            } else {
                (active ? (configuration.theme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)) : Color.clear)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: configuration.windowStyle == .rounded ? 13 : 5, style: .continuous))
    }

    func scrubGesture(_ configuration: LivelineChartConfiguration) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard configuration.scrub else { return }
                hoverLocation = value.location
            }
            .onEnded { _ in
                hoverLocation = nil
                configuration.onHover?(nil)
            }
    }
}
