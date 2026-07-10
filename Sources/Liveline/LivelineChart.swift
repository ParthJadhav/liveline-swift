import SwiftUI

/// A SwiftUI chart view for real-time line, candlestick, multi-series, and
/// discrete time-series data.
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

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
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
        self.init(content: .line(data: data, value: value), accent: color, configuration: configuration)
    }

    /// Creates a time-based bar chart.
    public init(
        bars: [LivelinePoint],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineBarStyle = LivelineBarStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(content: .bars(data: bars, style: style), accent: color, configuration: configuration)
    }

    /// Creates a lower/upper range-band chart.
    public init(
        range: [LivelineRangePoint],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineRangeStyle = LivelineRangeStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(content: .range(data: range, style: style), accent: color, configuration: configuration)
    }

    /// Creates a scatter chart from discrete observations.
    public init(
        scatter: [LivelinePoint],
        value: Double? = nil,
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineScatterStyle = LivelineScatterStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(
            content: .scatter(data: scatter, value: value ?? scatter.last?.value ?? 0, style: style),
            accent: color,
            configuration: configuration
        )
    }

    /// Creates a step chart whose transitions can align within each interval.
    public init(
        steps: [LivelinePoint],
        value: Double? = nil,
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineStepStyle = LivelineStepStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(
            content: .steps(data: steps, value: value ?? steps.last?.value ?? 0, style: style),
            accent: color,
            configuration: configuration
        )
    }

    /// Creates a lollipop chart with stems extending from a configurable baseline.
    public init(
        lollipops: [LivelinePoint],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineLollipopStyle = LivelineLollipopStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(content: .lollipops(data: lollipops, style: style), accent: color, configuration: configuration)
    }

    /// Creates a bubble chart whose marker area or diameter represents magnitude.
    public init(
        bubbles: [LivelineBubblePoint],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineBubbleStyle = LivelineBubbleStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(content: .bubbles(data: bubbles, style: style), accent: color, configuration: configuration)
    }

    /// Creates a time-based box plot from five-number summaries.
    public init(
        boxPlots: [LivelineBoxPlotPoint],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineBoxPlotStyle = LivelineBoxPlotStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(content: .boxPlots(data: boxPlots, style: style), accent: color, configuration: configuration)
    }

    /// Creates a cumulative waterfall chart from time-based deltas.
    public init(
        waterfall: [LivelinePoint],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineWaterfallStyle = LivelineWaterfallStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(content: .waterfall(data: waterfall, style: style), accent: color, configuration: configuration)
    }

    /// Creates an error-bar chart with central estimates and uncertainty bounds.
    public init(
        errorBars: [LivelineErrorBarPoint],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineErrorBarStyle = LivelineErrorBarStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(content: .errorBars(data: errorBars, style: style), accent: color, configuration: configuration)
    }

    /// Creates a dumbbell chart for paired comparisons over time.
    public init(
        dumbbells: [LivelineDumbbellPoint],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineDumbbellStyle = LivelineDumbbellStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(content: .dumbbells(data: dumbbells, style: style), accent: color, configuration: configuration)
    }

    /// Creates a time-based stacked-bar chart.
    public init(
        stackedBars: [LivelineStackedPoint],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineStackedBarStyle = LivelineStackedBarStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(content: .stackedBars(data: stackedBars, style: style), accent: color, configuration: configuration)
    }

    /// Creates a time-based stacked-area chart.
    public init(
        stackedAreas: [LivelineStackedPoint],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineStackedAreaStyle = LivelineStackedAreaStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(content: .stackedAreas(data: stackedAreas, style: style), accent: color, configuration: configuration)
    }

    /// Creates a multi-lane interval timeline.
    public init(
        timeline: [LivelineTimelineItem],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineTimelineStyle = LivelineTimelineStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(content: .timeline(data: timeline, style: style), accent: color, configuration: configuration)
    }

    /// Creates a time-row heatmap.
    public init(
        heatmap: [LivelineHeatmapCell],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineHeatmapStyle = LivelineHeatmapStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(content: .heatmap(data: heatmap, style: style), accent: color, configuration: configuration)
    }

    /// Creates a radial multi-axis radar chart.
    public init(
        radar: [LivelineRadarPoint],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineRadarStyle = LivelineRadarStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(content: .radar(data: radar, style: style), accent: color, configuration: configuration)
    }

    /// Creates a donut chart for categorical composition.
    public init(
        donut: [LivelineCategoryValue],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineDonutStyle = LivelineDonutStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(content: .donut(data: donut, style: style), accent: color, configuration: configuration)
    }

    /// Creates a radial gauge for a value within a closed range.
    public init(
        gauge value: Double,
        range: ClosedRange<Double> = 0...1,
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineGaugeStyle = LivelineGaugeStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(
            content: .gauge(value: value.isFinite ? value : range.lowerBound, range: range, style: style),
            accent: color,
            configuration: configuration
        )
    }

    /// Creates a funnel chart for categorical stage progression.
    public init(
        funnel: [LivelineCategoryValue],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineFunnelStyle = LivelineFunnelStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(content: .funnel(data: funnel, style: style), accent: color, configuration: configuration)
    }

    public init(
        series: [LivelineSeries],
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(
            content: .series(series),
            accent: series.first?.color ?? Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
            configuration: configuration
        )
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
        self.init(
            content: .candle(
                data: data,
                value: value,
                candles: candles,
                candleWidth: candleWidth,
                liveCandle: liveCandle,
                lineData: lineData,
                lineValue: lineValue
            ),
            accent: color,
            configuration: configuration
        )
    }

    private init(
        content: LivelineChartContent,
        accent: Color,
        configuration: LivelineChartConfiguration
    ) {
        self.content = content
        self.accent = accent
        self.baseConfiguration = configuration
        _activeWindow = State(initialValue: configuration.windows.first?.seconds ?? configuration.window)
        _lineMode = State(initialValue: configuration.lineMode)
    }

    public var body: some View {
        let configuration = effectiveConfiguration

        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 6) {
                if configuration.showValue {
                    Text(configuration.formatValue(currentValue))
                        .font(.system(size: 20, weight: .medium, design: .monospaced))
                        .tracking(-0.2)
                        .foregroundColor(valueColor(configuration: configuration))
                        .padding(.leading, resolvedLeftPadding(configuration))
                        .padding(.top, 4)
                        .padding(.bottom, 2)
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
                    .frame(height: controlRowHeight(configuration))
                }

                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    Canvas { context, size in
                        let timestamp = renderState.timestamp(
                            for: timeline.date.timeIntervalSince1970,
                            snapshotElapsedTime: configuration.snapshotElapsedTime
                        )
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
                                timestamp: timestamp,
                                size: size
                            )
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(scrubGesture(configuration))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
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

private struct LivelineModeIcon: View {
    var mode: LivelineChartMode
    var active: Bool
    var color: Color

    var body: some View {
        Canvas { context, _ in
            switch mode {
            case .line:
                var path = Path()
                path.move(to: CGPoint(x: 1, y: 8.5))
                path.addCurve(
                    to: CGPoint(x: 5.5, y: 4),
                    control1: CGPoint(x: 2.5, y: 8.5),
                    control2: CGPoint(x: 3, y: 4)
                )
                path.addCurve(
                    to: CGPoint(x: 8.5, y: 7),
                    control1: CGPoint(x: 7.5, y: 4),
                    control2: CGPoint(x: 7.5, y: 7)
                )
                path.addCurve(
                    to: CGPoint(x: 11, y: 3.5),
                    control1: CGPoint(x: 9.5, y: 7),
                    control2: CGPoint(x: 10, y: 3.5)
                )
                context.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: active ? 1.5 : 1.2, lineCap: .round, lineJoin: .round)
                )

            case .candle:
                var leftWick = Path()
                leftWick.move(to: CGPoint(x: 3.5, y: 1))
                leftWick.addLine(to: CGPoint(x: 3.5, y: 11))
                context.stroke(leftWick, with: .color(color), lineWidth: 1)
                context.fill(Path(roundedRect: CGRect(x: 2, y: 3, width: 3, height: 5), cornerRadius: 0.5), with: .color(color))

                var rightWick = Path()
                rightWick.move(to: CGPoint(x: 8.5, y: 2))
                rightWick.addLine(to: CGPoint(x: 8.5, y: 10))
                context.stroke(rightWick, with: .color(color), lineWidth: 1)
                context.fill(Path(roundedRect: CGRect(x: 7, y: 4, width: 3, height: 4), cornerRadius: 0.5), with: .color(color))
            }
        }
    }
}

private extension LivelineChart {
    var effectiveConfiguration: LivelineChartConfiguration {
        var configuration = baseConfiguration
        configuration.lineMode = lineMode
        return configuration.respectingReducedMotion(accessibilityReduceMotion)
    }

    var currentValue: Double {
        switch content {
        case let .line(_, value):
            return value
        case let .candle(_, value, _, _, liveCandle, _, lineValue):
            return lineValue ?? liveCandle?.close ?? value
        case let .series(series):
            return series.first(where: { !hiddenSeries.contains($0.id) })?.value ?? series.first?.value ?? 0
        case let .bars(data, _):
            return data.last?.value ?? 0
        case let .range(data, _):
            return data.last?.midpoint ?? 0
        case let .scatter(_, value, _):
            return value
        case let .steps(_, value, _):
            return value
        case let .lollipops(data, _):
            return data.last?.value ?? 0
        case let .bubbles(data, _):
            return data.last?.value ?? 0
        case let .boxPlots(data, _):
            return data.last?.median ?? 0
        case let .waterfall(data, style):
            return LivelineMath.waterfallSegments(points: data, initialValue: style.initialValue).last?.end ?? style.initialValue
        case let .errorBars(data, _):
            return data.last?.value ?? 0
        case let .dumbbells(data, _):
            return data.last?.end ?? 0
        case let .stackedBars(data, _), let .stackedAreas(data, _):
            return data.last?.total ?? 0
        case let .timeline(data, _):
            guard let last = data.last else { return 0 }
            return last.end - last.start
        case let .heatmap(data, _):
            return data.last?.value ?? 0
        case let .radar(data, _):
            guard !data.isEmpty else { return 0 }
            return data.map(\.value).reduce(0, +) / Double(data.count)
        case let .donut(data, _):
            return data.map(\.value).reduce(0, +)
        case let .gauge(value, _, _):
            return value
        case let .funnel(data, _):
            return data.last?.value ?? 0
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
        case let .bars(data, _):
            return LivelineMath.detectMomentum(points: data)
        case let .range(data, _):
            return LivelineMath.detectMomentum(points: data.map { LivelinePoint(time: $0.time, value: $0.midpoint) })
        case let .scatter(data, _, _):
            return LivelineMath.detectMomentum(points: data)
        case let .steps(data, _, _):
            return LivelineMath.detectMomentum(points: data)
        case let .lollipops(data, _):
            return LivelineMath.detectMomentum(points: data)
        case let .bubbles(data, _):
            return LivelineMath.detectMomentum(points: data.map { LivelinePoint(time: $0.time, value: $0.value) })
        case let .boxPlots(data, _):
            return LivelineMath.detectMomentum(points: data.map { LivelinePoint(time: $0.time, value: $0.median) })
        case let .waterfall(data, style):
            let points = LivelineMath.waterfallSegments(points: data, initialValue: style.initialValue)
                .map { LivelinePoint(time: $0.time, value: $0.end) }
            return LivelineMath.detectMomentum(points: points)
        case let .errorBars(data, _):
            return LivelineMath.detectMomentum(points: data.map { LivelinePoint(time: $0.time, value: $0.value) })
        case let .dumbbells(data, _):
            return LivelineMath.detectMomentum(points: data.map { LivelinePoint(time: $0.time, value: $0.end) })
        case let .stackedBars(data, _), let .stackedAreas(data, _):
            return LivelineMath.detectMomentum(points: data.map { LivelinePoint(time: $0.time, value: $0.total) })
        case let .timeline(data, _):
            return LivelineMath.detectMomentum(points: data.enumerated().map {
                LivelinePoint(time: Double($0.offset), value: $0.element.end - $0.element.start)
            })
        case let .heatmap(data, _):
            return LivelineMath.detectMomentum(points: data.map { LivelinePoint(time: $0.time, value: $0.value) })
        case .radar, .donut, .gauge, .funnel:
            return .flat
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
            HStack(spacing: configuration.windowStyle == .text ? 4 : 2) {
                ForEach(configuration.windows) { option in
                    let active = activeWindow == option.seconds
                    Button {
                        activeWindow = option.seconds
                        configuration.onWindowChange?(option.seconds)
                    } label: {
                        Text(option.label)
                            .font(.system(size: 11, weight: active ? .semibold : .regular))
                            .lineLimit(1)
                            .offset(y: 1 / 3)
                            .padding(.horizontal, configuration.windowStyle == .text ? 6 : 10)
                            .frame(height: controlButtonHeight(configuration))
                            .foregroundColor(active ? activeControlColor(configuration) : inactiveControlColor(configuration))
                            .background(controlBackground(active: active, configuration: configuration))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(controlGroupPadding(configuration))
            .background(groupBackground(configuration))
            .clipShape(RoundedRectangle(cornerRadius: controlGroupCornerRadius(configuration), style: .continuous))
        }
    }

    @ViewBuilder
    func modeControls(_ configuration: LivelineChartConfiguration) -> some View {
        if shouldShowModeControls(configuration) {
            HStack(spacing: configuration.windowStyle == .text ? 4 : 2) {
                modeButton(mode: .line, active: lineMode, configuration: configuration)
                modeButton(mode: .candle, active: !lineMode, configuration: configuration)
            }
            .padding(controlGroupPadding(configuration))
            .background(groupBackground(configuration))
            .clipShape(RoundedRectangle(cornerRadius: controlGroupCornerRadius(configuration), style: .continuous))
        }
    }

    func modeButton(mode: LivelineChartMode, active: Bool, configuration: LivelineChartConfiguration) -> some View {
        Button {
            lineMode = mode == .line
            configuration.onModeChange?(mode)
        } label: {
            LivelineModeIcon(mode: mode, active: active, color: active ? activeControlColor(configuration) : inactiveControlColor(configuration))
                .frame(width: 12, height: 12)
                .padding(.horizontal, 7)
                .frame(height: controlButtonHeight(configuration))
                .background(controlBackground(active: active, configuration: configuration))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode == .line ? "Line" : "Candle")
    }

    @ViewBuilder
    func seriesControls(_ configuration: LivelineChartConfiguration) -> some View {
        if case let .series(series) = content, series.count > 1 {
            HStack(spacing: configuration.windowStyle == .text ? 4 : 2) {
                ForEach(series) { entry in
                    let visible = !hiddenSeries.contains(entry.id)
                    Button {
                        toggleSeries(entry.id, series: series, configuration: configuration)
                    } label: {
                        HStack(spacing: configuration.seriesToggleCompact ? 0 : 4) {
                            Circle()
                                .fill(entry.color)
                                .frame(width: configuration.seriesToggleCompact ? 8 : 6, height: configuration.seriesToggleCompact ? 8 : 6)
                            if !configuration.seriesToggleCompact {
                                Text(entry.label ?? entry.id)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, seriesButtonHorizontalPadding(configuration))
                        .offset(y: configuration.seriesToggleCompact ? 0 : 1 / 3)
                        .frame(height: seriesButtonHeight(configuration))
                        .foregroundColor(visible ? activeControlColor(configuration) : inactiveControlColor(configuration))
                        .background(controlBackground(active: visible, configuration: configuration))
                        .opacity(visible ? 1 : 0.4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(controlGroupPadding(configuration))
            .background(groupBackground(configuration))
            .clipShape(RoundedRectangle(cornerRadius: controlGroupCornerRadius(configuration), style: .continuous))
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
        configuration.theme == .dark ? Color.white.opacity(0.70) : Color.black.opacity(0.55)
    }

    func inactiveControlColor(_ configuration: LivelineChartConfiguration) -> Color {
        configuration.theme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.22)
    }

    func groupBackground(_ configuration: LivelineChartConfiguration) -> Color {
        switch configuration.windowStyle {
        case .text:
            return .clear
        case .default, .rounded:
            return configuration.theme == .dark ? Color.white.opacity(0.03) : Color.black.opacity(0.02)
        }
    }

    func controlBackground(active: Bool, configuration: LivelineChartConfiguration) -> some View {
        Group {
            if configuration.windowStyle == .text {
                Color.clear
            } else {
                (active ? (configuration.theme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.035)) : Color.clear)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: configuration.windowStyle == .rounded ? 999 : 4, style: .continuous))
    }

    func controlGroupPadding(_ configuration: LivelineChartConfiguration) -> CGFloat {
        switch configuration.windowStyle {
        case .text:
            return 0
        case .rounded:
            return 3
        case .default:
            return 2
        }
    }

    func controlGroupCornerRadius(_ configuration: LivelineChartConfiguration) -> CGFloat {
        configuration.windowStyle == .rounded ? 999 : 6
    }

    func controlRowHeight(_ configuration: LivelineChartConfiguration) -> CGFloat {
        var buttonHeight: CGFloat = 0
        if !configuration.windows.isEmpty {
            buttonHeight = max(buttonHeight, controlButtonHeight(configuration))
        }
        if shouldShowModeControls(configuration) {
            buttonHeight = max(buttonHeight, controlButtonHeight(configuration))
        }
        if shouldShowSeriesControls {
            buttonHeight = max(buttonHeight, seriesButtonHeight(configuration))
        }
        return buttonHeight + controlGroupPadding(configuration) * 2
    }

    func controlButtonHeight(_ configuration: LivelineChartConfiguration) -> CGFloat {
        configuration.windowStyle == .text ? 20 : 22
    }

    func seriesButtonHeight(_ configuration: LivelineChartConfiguration) -> CGFloat {
        guard configuration.seriesToggleCompact else {
            return controlButtonHeight(configuration)
        }
        return configuration.windowStyle == .text ? 12 : 18
    }

    func seriesButtonHorizontalPadding(_ configuration: LivelineChartConfiguration) -> CGFloat {
        if configuration.windowStyle == .text {
            return configuration.seriesToggleCompact ? 4 : 6
        }
        return configuration.seriesToggleCompact ? 7 : 8
    }

    func scrubGesture(_ configuration: LivelineChartConfiguration) -> some Gesture {
        #if os(tvOS)
        TapGesture()
        #else
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard configuration.scrub else { return }
                hoverLocation = value.location
            }
            .onEnded { _ in
                hoverLocation = nil
                configuration.onHover?(nil)
            }
        #endif
    }
}
