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
    @Environment(\.accessibilityVoiceOverEnabled) private var accessibilityVoiceOverEnabled
    @Environment(\.accessibilitySwitchControlEnabled) private var accessibilitySwitchControlEnabled
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.livelineSnapshotElapsedTime) private var snapshotElapsedTime
    @Environment(\.livelineChartStyleOverride) private var chartStyleOverride
    @ScaledMetric(relativeTo: .caption) private var scaledControlHitDimension: CGFloat = LivelineControlMetrics.minimumHitDimension
    @StateObject private var renderState = LivelineRenderState()
    @State private var activeWindow: TimeInterval
    @State private var interactionSessions = LivelineInteractionSessions()
    @State private var lastReportedHover: LivelineHoverPoint?
    @State private var lineMode: Bool
    @State private var hiddenSeries: Set<String> = []
    @State private var accessibilityIndex: Int?
    @State private var accessibilityInspectionRequested = false
    #if os(tvOS)
    @State private var remoteScrubIndex: Int?
    @State private var remoteInspectionActive = false
    @FocusState private var remoteChartHasFocus: Bool
    #endif

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

    /// Creates a histogram of raw samples, binned by the style's rule.
    ///
    /// ```swift
    /// LivelineChart(histogram: latencies, style: LivelineHistogramStyle(binning: .count(20)))
    /// ```
    ///
    /// The horizontal axis spans the sample range rather than time, and the
    /// value axis counts the samples that fell in each bin.
    public init(
        histogram values: [Double],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineHistogramStyle = LivelineHistogramStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(content: .histogram(values: values, style: style), accent: color, configuration: configuration)
    }

    /// Creates a bullet chart: a compact horizontal KPI showing a measure
    /// against a target and qualitative bands.
    ///
    /// ```swift
    /// LivelineChart(bullet: LivelineBulletStyle(
    ///     measure: 72,
    ///     target: 80,
    ///     ranges: [
    ///         LivelineBulletRange(value: 50, label: "Poor"),
    ///         LivelineBulletRange(value: 75, label: "OK"),
    ///         LivelineBulletRange(value: 100, label: "Good"),
    ///     ]
    /// ))
    /// ```
    public init(
        bullet style: LivelineBulletStyle,
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(content: .bullet(style: style), accent: color, configuration: configuration)
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
        let content = content.normalized()
        let configuration = configuration.normalizedForRendering()
        self.content = content
        self.accent = accent
        self.baseConfiguration = configuration
        _activeWindow = State(initialValue: configuration.initialWindow)
        _lineMode = State(initialValue: configuration.lineMode)
    }

    public var body: some View {
        let configuration = effectiveConfiguration
        let semantics = content.semantics(
            hiddenSeries: hiddenSeries,
            activeWindow: activeWindow
        )
        let includeAccessibilityEntries = accessibilityVoiceOverEnabled
            || accessibilitySwitchControlEnabled
            || accessibilityInspectionRequested
        // Hover lives in view state, so every pointer move re-evaluates the
        // body. Formatting an entry per datum on each of those moves is the
        // dominant cost while VoiceOver is inspecting the chart.
        let accessibilityModel = renderState.accessibilityModel(
            for: LivelineAccessibilityModelKey.make(
                content: content,
                semantics: semantics,
                configuration: configuration,
                hiddenSeries: hiddenSeries,
                includeEntries: includeAccessibilityEntries
            )
        ) {
            LivelineChartAccessibilityModel.make(
                content: content,
                semantics: semantics,
                configuration: configuration,
                hiddenSeries: hiddenSeries,
                includeEntries: includeAccessibilityEntries
            )
        }
        let resolvedSnapshotElapsedTime = snapshotElapsedTime
            ?? configuration.resolvedSnapshotElapsedTime
        let motion = LivelineMotionPolicy.resolve(
            configuration: configuration,
            capabilities: semantics.capabilities,
            reduceMotion: accessibilityReduceMotion,
            snapshotElapsedTime: resolvedSnapshotElapsedTime
        )

        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 6) {
                if configuration.showValue {
                    Text(configuration.formatValue(semantics.currentValue))
                        .font(.title3.monospaced().weight(.medium))
                        .tracking(-0.2)
                        .foregroundColor(valueColor(configuration: configuration, momentum: semantics.momentum))
                        .padding(.leading, resolvedLeftPadding(configuration))
                        .padding(.top, 4)
                        .padding(.bottom, 2)
                        .animation(.easeOut(duration: 0.2), value: semantics.momentum)
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

                chartSurface(
                    configuration: configuration,
                    semantics: semantics,
                    motion: motion,
                    snapshotElapsedTime: resolvedSnapshotElapsedTime,
                    accessibilityModel: accessibilityModel
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .onChange(of: baseConfiguration.window) { newValue in
            activeWindow = LivelineSelectionReconciler.window(
                current: activeWindow,
                preferred: newValue,
                options: baseConfiguration.windows.map(\.seconds),
                preferExternalValue: true
            )
        }
        .onChange(of: baseConfiguration.windows.map(\.seconds)) { options in
            activeWindow = LivelineSelectionReconciler.window(
                current: activeWindow,
                preferred: baseConfiguration.window,
                options: options,
                preferExternalValue: false
            )
        }
        .onChange(of: baseConfiguration.lineMode) { newValue in
            lineMode = newValue
        }
        .onChange(of: semantics.identity) { identity in
            hiddenSeries = LivelineSelectionReconciler.hiddenSeries(
                current: hiddenSeries,
                availableIDs: identity.seriesIDs
            )
            accessibilityIndex = nil
            accessibilityInspectionRequested = false
        }
        .onChange(of: accessibilityModel.entryCount) { count in
            if let accessibilityIndex, accessibilityIndex >= count {
                self.accessibilityIndex = count > 0 ? count - 1 : nil
            }
        }
        .onChange(of: configuration.scrub) { isEnabled in
            if !isEnabled {
                endHover(source: .scrub, configuration: configuration)
                #if os(tvOS)
                remoteInspectionActive = false
                remoteScrubIndex = nil
                #endif
            }
        }
        .onChange(of: configuration.showsTooltipOnHover) { isEnabled in
            // A cursor parked over the chart produces no further events, so the
            // selection it left behind has to be cleared explicitly.
            if !isEnabled {
                endHover(source: .pointer, configuration: configuration)
            }
        }
        .onDisappear {
            endAllHover(configuration: baseConfiguration, forceNotification: true)
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
    @ViewBuilder
    func chartSurface(
        configuration: LivelineChartConfiguration,
        semantics: LivelineChartSemantics,
        motion: LivelineMotionPolicy,
        snapshotElapsedTime: TimeInterval?,
        accessibilityModel: LivelineChartAccessibilityModel
    ) -> some View {
        if motion.requiresTimeline {
            TimelineView(.animation(minimumInterval: motion.minimumInterval)) { timeline in
                chartCanvas(
                    wallTimestamp: timeline.date.timeIntervalSince1970,
                    configuration: configuration,
                    semantics: semantics,
                    motion: motion,
                    snapshotElapsedTime: snapshotElapsedTime,
                    accessibilityModel: accessibilityModel
                )
            }
        } else {
            chartCanvas(
                wallTimestamp: Date().timeIntervalSince1970,
                configuration: configuration,
                semantics: semantics,
                motion: motion,
                snapshotElapsedTime: snapshotElapsedTime,
                accessibilityModel: accessibilityModel
            )
        }
    }

    func chartCanvas(
        wallTimestamp: TimeInterval,
        configuration: LivelineChartConfiguration,
        semantics: LivelineChartSemantics,
        motion: LivelineMotionPolicy,
        snapshotElapsedTime: TimeInterval?,
        accessibilityModel: LivelineChartAccessibilityModel
    ) -> some View {
        scrubbableChartCanvas(
            wallTimestamp: wallTimestamp,
            configuration: configuration,
            semantics: semantics,
            motion: motion,
            snapshotElapsedTime: snapshotElapsedTime
        )
        // Hover sits outside the press-driven surfaces above so a cursor can
        // inspect the chart without a button held down, and so the iOS scrub
        // overlay does not swallow pointer movement on iPad.
        .livelinePointerHover(
            isEnabled: configuration.showsTooltipOnHover,
            onMove: { location in
                updateHover(at: location, source: .pointer, configuration: configuration)
            },
            onExit: {
                endHover(source: .pointer, configuration: configuration)
            }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityModel.label))
        .accessibilityValue(Text(accessibilityModel.value(at: accessibilityIndex)))
        .accessibilityHint(Text(accessibilityModel.hint))
        .accessibilityAdjustableAction { direction in
            if accessibilityModel.entries.isEmpty,
               accessibilityModel.entryCount > 0 {
                accessibilityInspectionRequested = true
                switch direction {
                case .increment:
                    accessibilityIndex = 0
                case .decrement:
                    accessibilityIndex = accessibilityModel.entryCount - 1
                @unknown default:
                    break
                }
                return
            }
            switch direction {
            case .increment:
                accessibilityIndex = accessibilityModel.adjustedIndex(
                    from: accessibilityIndex,
                    direction: .increment
                )
            case .decrement:
                accessibilityIndex = accessibilityModel.adjustedIndex(
                    from: accessibilityIndex,
                    direction: .decrement
                )
            @unknown default:
                break
            }
        }
        .accessibilityAction(named: Text(LivelineStrings.controlShowSummary)) {
            accessibilityIndex = nil
        }
        // Audio Graph. The representable is cheap to build; the descriptor
        // behind it is only assembled when VoiceOver asks for it.
        .livelineAudioGraph(
            content: content,
            semantics: semantics,
            configuration: configuration,
            hiddenSeries: hiddenSeries,
            activeWindow: activeWindow,
            title: accessibilityModel.label,
            summary: accessibilityModel.summary
        )
    }

    @ViewBuilder
    func scrubbableChartCanvas(
        wallTimestamp: TimeInterval,
        configuration: LivelineChartConfiguration,
        semantics: LivelineChartSemantics,
        motion: LivelineMotionPolicy,
        snapshotElapsedTime: TimeInterval?
    ) -> some View {
        #if os(iOS)
        chartDrawingCanvas(
            wallTimestamp: wallTimestamp,
            configuration: configuration,
            semantics: semantics,
            motion: motion,
            snapshotElapsedTime: snapshotElapsedTime
        )
        .overlay {
            LivelineScrubInteractionView(
                isEnabled: configuration.scrub,
                onScrub: { location in
                    updateHover(at: location, source: .scrub, configuration: configuration)
                },
                onEnd: {
                    endHover(source: .scrub, configuration: configuration)
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        #elseif os(tvOS)
        chartDrawingCanvas(
            wallTimestamp: wallTimestamp,
            configuration: configuration,
            semantics: semantics,
            motion: motion,
            snapshotElapsedTime: snapshotElapsedTime
        )
        .focusable(configuration.scrub)
        .focused($remoteChartHasFocus)
        .onTapGesture {
            toggleRemoteInspection(configuration: configuration)
        }
        .onMoveCommand(perform: remoteMoveHandler(configuration: configuration))
        .onExitCommand(perform: remoteExitHandler(configuration: configuration))
        .onChange(of: remoteChartHasFocus) { hasFocus in
            if !hasFocus {
                endRemoteInspection(configuration: configuration)
            }
        }
        #else
        chartDrawingCanvas(
            wallTimestamp: wallTimestamp,
            configuration: configuration,
            semantics: semantics,
            motion: motion,
            snapshotElapsedTime: snapshotElapsedTime
        )
        .simultaneousGesture(scrubGesture(configuration))
        #endif
    }

    func chartDrawingCanvas(
        wallTimestamp: TimeInterval,
        configuration: LivelineChartConfiguration,
        semantics: LivelineChartSemantics,
        motion: LivelineMotionPolicy,
        snapshotElapsedTime: TimeInterval?
    ) -> some View {
        Canvas { context, size in
            let timestamp = renderState.timestamp(
                for: wallTimestamp,
                snapshotElapsedTime: snapshotElapsedTime
            )
            LivelineRenderer.draw(
                context: &context,
                state: renderState,
                input: LivelineRenderInput(
                    content: content,
                    semantics: semantics,
                    accent: accent,
                    configuration: configuration,
                    motion: motion,
                    activeWindow: activeWindow,
                    hiddenSeries: hiddenSeries,
                    hoverLocation: interactionSessions.activeLocation,
                    timestamp: timestamp,
                    size: size,
                    textScale: textScale
                )
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    /// Canvas text is drawn, not laid out by SwiftUI, so Dynamic Type has to be
    /// resolved here and handed to the renderer explicitly.
    var textScale: LivelineTextScale {
        LivelineTextScale.resolve(dynamicTypeSize)
    }

    /// Every consumer of the theme — palette, renderer, interaction snapshot,
    /// accessibility, audio graph — reads it from here, so `.automatic` is
    /// resolved once against the environment and never travels further.
    var effectiveConfiguration: LivelineChartConfiguration {
        var configuration = baseConfiguration
        configuration.theme = baseConfiguration.theme.resolved(colorScheme: colorScheme)
        configuration.lineMode = lineMode
        if let chartStyleOverride {
            configuration.style = chartStyleOverride.normalizedForRendering()
        }
        return configuration.respectingReducedMotion(accessibilityReduceMotion)
    }

    func valueColor(configuration: LivelineChartConfiguration, momentum: LivelineMomentum) -> Color {
        guard configuration.valueMomentumColor else {
            return configuration.theme == .dark ? Color.white.opacity(0.85) : Color(red: 17 / 255, green: 17 / 255, blue: 17 / 255)
        }

        switch momentum {
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
        !configuration.windows.isEmpty
            || shouldShowModeControls(configuration)
            || shouldShowSeriesControls(configuration)
    }

    func shouldShowModeControls(_ configuration: LivelineChartConfiguration) -> Bool {
        if case .candle = content {
            return configuration.showsModeControls
        }
        return false
    }

    func shouldShowSeriesControls(_ configuration: LivelineChartConfiguration) -> Bool {
        guard configuration.showsSeriesControls else { return false }
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
                            .font(.caption.weight(active ? .semibold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, configuration.windowStyle == .text ? 6 : 10)
                            .frame(
                                minWidth: resolvedControlHitDimension,
                                minHeight: controlButtonHeight(configuration)
                            )
                            .foregroundColor(active ? activeControlColor(configuration) : inactiveControlColor(configuration))
                            .background(controlBackground(active: active, configuration: configuration))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("liveline-window-\(option.label)")
                    .accessibilityLabel(Text(option.label))
                    .accessibilityValue(Text(active ? LivelineStrings.controlSelected : LivelineStrings.controlNotSelected))
                    .accessibilityAddTraits(active ? .isSelected : [])
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
                .frame(width: 16, height: 16)
                .frame(
                    minWidth: resolvedControlHitDimension,
                    minHeight: controlButtonHeight(configuration)
                )
                .background(controlBackground(active: active, configuration: configuration))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(mode == .line ? "liveline-mode-line" : "liveline-mode-candle")
        .accessibilityLabel(mode == .line ? LivelineStrings.controlModeLine : LivelineStrings.controlModeCandle)
        .accessibilityValue(active ? LivelineStrings.controlSelected : LivelineStrings.controlNotSelected)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    @ViewBuilder
    func seriesControls(_ configuration: LivelineChartConfiguration) -> some View {
        if configuration.showsSeriesControls,
           case let .series(series) = content,
           series.count > 1 {
            HStack(spacing: configuration.windowStyle == .text ? 4 : 2) {
                ForEach(series) { entry in
                    let visible = !hiddenSeries.contains(entry.id)
                    let canToggle = LivelineSelectionReconciler.canToggleSeries(
                        entry.id,
                        hidden: hiddenSeries,
                        availableIDs: series.map(\.id)
                    )
                    Button {
                        toggleSeries(entry.id, series: series, configuration: configuration)
                    } label: {
                        HStack(spacing: configuration.seriesToggleCompact ? 0 : 4) {
                            Circle()
                                .fill(visible ? entry.color : Color.clear)
                                .overlay {
                                    Circle().stroke(entry.color, lineWidth: 2)
                                }
                                .frame(width: configuration.seriesToggleCompact ? 10 : 8, height: configuration.seriesToggleCompact ? 10 : 8)
                            if !configuration.seriesToggleCompact {
                                Text(entry.label ?? entry.id)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        .padding(.horizontal, seriesButtonHorizontalPadding(configuration))
                        .frame(
                            minWidth: resolvedControlHitDimension,
                            minHeight: seriesButtonHeight(configuration)
                        )
                        .foregroundColor(visible ? activeControlColor(configuration) : inactiveControlColor(configuration))
                        .background(controlBackground(active: visible, configuration: configuration))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canToggle)
                    .accessibilityIdentifier("liveline-series-\(entry.id)")
                    .accessibilityLabel(Text(entry.label ?? entry.id))
                    .accessibilityValue(Text(
                        visible
                            ? (canToggle ? LivelineStrings.controlSeriesVisible : LivelineStrings.controlSeriesVisibleRequired)
                            : LivelineStrings.controlSeriesHidden
                    ))
                    .accessibilityHint(Text(
                        canToggle
                            ? (visible ? LivelineStrings.controlSeriesHintHide : LivelineStrings.controlSeriesHintShow)
                            : LivelineStrings.controlSeriesHintLocked
                    ))
                    .accessibilityAddTraits(visible ? .isSelected : [])
                }
            }
            .padding(controlGroupPadding(configuration))
            .background(groupBackground(configuration))
            .clipShape(RoundedRectangle(cornerRadius: controlGroupCornerRadius(configuration), style: .continuous))
        }
    }

    func toggleSeries(_ id: String, series: [LivelineSeries], configuration: LivelineChartConfiguration) {
        guard let selection = LivelineSelectionReconciler.toggledSeries(
            id,
            hidden: hiddenSeries,
            availableIDs: series.map(\.id)
        ) else { return }
        hiddenSeries = selection.hidden
        configuration.onSeriesToggle?(id, selection.isVisible)
    }

    func activeControlColor(_ configuration: LivelineChartConfiguration) -> Color {
        configuration.theme == .dark ? Color.white.opacity(0.94) : Color.black.opacity(0.86)
    }

    func inactiveControlColor(_ configuration: LivelineChartConfiguration) -> Color {
        configuration.theme == .dark ? Color.white.opacity(0.66) : Color.black.opacity(0.62)
    }

    func groupBackground(_ configuration: LivelineChartConfiguration) -> Color {
        switch configuration.windowStyle {
        case .text:
            return .clear
        case .default, .rounded:
            return configuration.theme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
        }
    }

    func controlBackground(active: Bool, configuration: LivelineChartConfiguration) -> some View {
        Group {
            if configuration.windowStyle == .text {
                Color.clear
            } else {
                if active {
                    configuration.theme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.11)
                } else {
                    configuration.theme == .dark ? Color.white.opacity(0.035) : Color.black.opacity(0.025)
                }
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
        if shouldShowSeriesControls(configuration) {
            buttonHeight = max(buttonHeight, seriesButtonHeight(configuration))
        }
        return buttonHeight + controlGroupPadding(configuration) * 2
    }

    func controlButtonHeight(_ configuration: LivelineChartConfiguration) -> CGFloat {
        resolvedControlHitDimension
    }

    func seriesButtonHeight(_ configuration: LivelineChartConfiguration) -> CGFloat {
        resolvedControlHitDimension
    }

    var resolvedControlHitDimension: CGFloat {
        max(LivelineControlMetrics.minimumHitDimension, scaledControlHitDimension)
    }

    func seriesButtonHorizontalPadding(_ configuration: LivelineChartConfiguration) -> CGFloat {
        if configuration.windowStyle == .text {
            return configuration.seriesToggleCompact ? 4 : 6
        }
        return configuration.seriesToggleCompact ? 7 : 8
    }

    #if !os(tvOS)
    func scrubGesture(_ configuration: LivelineChartConfiguration) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard configuration.scrub else { return }
                updateHover(at: value.location, source: .scrub, configuration: configuration)
            }
            .onEnded { _ in
                endHover(source: .scrub, configuration: configuration)
            }
    }
    #endif

    func updateHover(
        at location: CGPoint,
        source: LivelineInteractionSource,
        configuration: LivelineChartConfiguration
    ) {
        interactionSessions.update(location, source: source)
        reportHover(
            resolvedHover(at: location, configuration: configuration),
            configuration: configuration
        )
    }

    func resolvedHover(
        at location: CGPoint,
        configuration: LivelineChartConfiguration
    ) -> LivelineHoverPoint? {
        if let hover = LivelineHoverResolver.resolve(
            location: location,
            snapshot: renderState.interactionSnapshot
        ) {
            return hover
        }

        // Idle snapshots deliberately omit formatted targets. Cartesian charts
        // can resolve directly from their points, but radial and region-based
        // charts need a targeted snapshot before the very first callback.
        guard let currentSnapshot = renderState.interactionSnapshot,
              currentSnapshot.targets.isEmpty,
              currentSnapshot.behavior == LivelineHoverBehavior.none,
              let snapshot = targetedInteractionSnapshot(
                configuration: configuration,
                targetLocation: location
              )
        else {
            return nil
        }
        renderState.interactionSnapshot = snapshot
        return LivelineHoverResolver.resolve(location: location, snapshot: snapshot)
    }

    func targetedInteractionSnapshot(
        configuration: LivelineChartConfiguration,
        targetLocation: CGPoint?
    ) -> LivelineInteractionSnapshot? {
        guard let current = renderState.interactionSnapshot,
              current.isEnabled else {
            return nil
        }
        let prepared = LivelineChartPreparer.prepare(
            for: content,
            hiddenSeries: hiddenSeries,
            leftEdge: current.layout.leftEdge,
            rightEdge: current.layout.rightEdge,
            config: configuration,
            state: renderState
        )
        return LivelineInteractionBuilder.snapshot(
            content: content,
            prepared: prepared,
            layout: current.layout,
            palette: renderState.palette(
                accent: accent,
                mode: configuration.theme,
                lineWidth: configuration.lineWidth
            ),
            configuration: configuration,
            hiddenSeries: hiddenSeries,
            behavior: current.behavior,
            targetLocation: targetLocation
        )
    }

    func reportHover(_ hover: LivelineHoverPoint?, configuration: LivelineChartConfiguration) {
        guard hover != lastReportedHover else { return }
        lastReportedHover = hover
        configuration.onHover?(hover)
    }

    func endHover(
        source: LivelineInteractionSource,
        configuration: LivelineChartConfiguration
    ) {
        let previousLocation = interactionSessions.activeLocation
        if let fallback = interactionSessions.end(source) {
            reportHover(
                resolvedHover(at: fallback, configuration: configuration),
                configuration: configuration
            )
            return
        }
        guard previousLocation != nil || lastReportedHover != nil else { return }
        let hadHover = lastReportedHover != nil
        lastReportedHover = nil
        if hadHover {
            configuration.onHover?(nil)
        }
    }

    func endAllHover(
        configuration: LivelineChartConfiguration,
        forceNotification: Bool = false
    ) {
        interactionSessions.clear()
        let hadHover = lastReportedHover != nil
        lastReportedHover = nil
        if hadHover || forceNotification {
            configuration.onHover?(nil)
        }
    }

    #if os(tvOS)
    func remoteMoveHandler(
        configuration: LivelineChartConfiguration
    ) -> ((MoveCommandDirection) -> Void)? {
        guard remoteInspectionActive else { return nil }
        return { direction in
            moveRemoteSelection(direction, configuration: configuration)
        }
    }

    func remoteExitHandler(
        configuration: LivelineChartConfiguration
    ) -> (() -> Void)? {
        guard remoteInspectionActive else { return nil }
        return {
            endRemoteInspection(configuration: configuration)
        }
    }

    func toggleRemoteInspection(configuration: LivelineChartConfiguration) {
        guard configuration.scrub else { return }
        if remoteInspectionActive {
            endRemoteInspection(configuration: configuration)
            return
        }

        guard let snapshot = targetedInteractionSnapshot(
            configuration: configuration,
            targetLocation: nil
        ),
        !snapshot.targets.isEmpty else {
            return
        }

        remoteInspectionActive = true
        selectRemoteTarget(
            snapshot.targets.count - 1,
            snapshot: snapshot,
            configuration: configuration
        )
    }

    func moveRemoteSelection(
        _ direction: MoveCommandDirection,
        configuration: LivelineChartConfiguration
    ) {
        guard configuration.scrub, remoteInspectionActive else {
            return
        }

        let step: LivelineRemoteSelectionStep
        switch direction {
        case .left:
            step = .backward
        case .right:
            step = .forward
        case .up, .down:
            endRemoteInspection(configuration: configuration)
            return
        @unknown default:
            return
        }

        guard let snapshot = targetedInteractionSnapshot(
            configuration: configuration,
            targetLocation: nil
        ),
        !snapshot.targets.isEmpty else {
            endRemoteInspection(configuration: configuration)
            return
        }

        guard let nextIndex = LivelineRemoteSelectionPolicy.nextIndex(
            current: remoteScrubIndex,
            targetCount: snapshot.targets.count,
            step: step
        ) else {
            return
        }
        selectRemoteTarget(
            nextIndex,
            snapshot: snapshot,
            configuration: configuration
        )
    }

    func selectRemoteTarget(
        _ index: Int,
        snapshot: LivelineInteractionSnapshot,
        configuration: LivelineChartConfiguration
    ) {
        guard snapshot.targets.indices.contains(index) else { return }
        remoteScrubIndex = index
        renderState.interactionSnapshot = snapshot
        let selection = snapshot.targets[index].selection
        interactionSessions.update(selection.anchor, source: .scrub)
        reportHover(selection.hover, configuration: configuration)
    }

    func endRemoteInspection(configuration: LivelineChartConfiguration) {
        remoteInspectionActive = false
        remoteScrubIndex = nil
        endHover(source: .scrub, configuration: configuration)
    }
    #endif
}
