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
    let content: LivelineChartContent
    let accent: Color
    let baseConfiguration: LivelineChartConfiguration

    @Environment(\.accessibilityReduceMotion) var accessibilityReduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) var accessibilityVoiceOverEnabled
    @Environment(\.accessibilitySwitchControlEnabled) var accessibilitySwitchControlEnabled
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.layoutDirection) var layoutDirection
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.displayScale) var displayScale
    @Environment(\.livelineSnapshotElapsedTime) var snapshotElapsedTime
    @Environment(\.livelineRendersSettledFrame) var rendersSettledFrame
    @Environment(\.livelineChartStyleOverride) var chartStyleOverride
    @ScaledMetric(relativeTo: .caption) var scaledControlHitDimension: CGFloat = LivelineControlMetrics.minimumHitDimension
    @StateObject var renderState = LivelineRenderState()
    @State var activeWindow: TimeInterval
    @State var interactionSessions = LivelineInteractionSessions()
    @State var lastReportedHover: LivelineHoverPoint?
    @State var lineMode: Bool
    @State var hiddenSeries: Set<String> = []
    @State var accessibilityIndex: Int?
    @State var accessibilityInspectionRequested = false
    /// The zoom-and-pan viewport, or `nil` while the chart has never been
    /// zoomed or panned. `nil` is not the same as "following live at the
    /// selected window": it means no viewport is involved at all, so the
    /// renderer takes exactly the path it took before this feature existed.
    @State var viewport: LivelineViewport?
    /// The viewport a pinch or a drag started from. Both gestures report
    /// cumulative values, so each update is applied to the baseline rather than
    /// compounded onto the previous frame.
    @State var zoomBaseline: LivelineViewport?
    @State var panBaseline: LivelineViewport?
    #if os(tvOS)
    @State var remoteScrubIndex: Int?
    @State var remoteInspectionActive = false
    @FocusState var remoteChartHasFocus: Bool
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

    /// Creates a treemap: nested rectangles whose areas are proportional to
    /// their values, packed by the squarified algorithm.
    ///
    /// ```swift
    /// LivelineChart(treemap: [
    ///     LivelineTreemapNode(label: "Compute", value: 480),
    ///     LivelineTreemapNode(label: "Storage", children: [
    ///         LivelineTreemapNode(label: "Hot", value: 180),
    ///         LivelineTreemapNode(label: "Cold", value: 60),
    ///     ]),
    /// ])
    /// ```
    ///
    /// A flat list of leaves and a one-level hierarchy are both accepted; a
    /// node with children ignores its own `value` in favour of their sum.
    /// Non-positive weights occupy no area and are dropped.
    public init(
        treemap nodes: [LivelineTreemapNode],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineTreemapStyle = LivelineTreemapStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(content: .treemap(nodes: nodes, style: style), accent: color, configuration: configuration)
    }

    /// Creates a sunburst: two concentric rings where the inner ring is the
    /// top-level nodes and the outer ring subdivides each node's own span among
    /// its children.
    ///
    /// ```swift
    /// LivelineChart(sunburst: [
    ///     LivelineSunburstNode(label: "Direct", value: 320),
    ///     LivelineSunburstNode(label: "Search", children: [
    ///         LivelineSunburstNode(label: "Organic", value: 210),
    ///         LivelineSunburstNode(label: "Paid", value: 90),
    ///     ]),
    /// ])
    /// ```
    ///
    /// Like every radial kind, a sunburst reads clockwise in both layout
    /// directions.
    public init(
        sunburst nodes: [LivelineSunburstNode],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineSunburstStyle = LivelineSunburstStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(content: .sunburst(nodes: nodes, style: style), accent: color, configuration: configuration)
    }

    /// Creates a Sankey diagram from a flat list of flows.
    ///
    /// ```swift
    /// LivelineChart(sankey: [
    ///     LivelineSankeyLink(source: "Visits", target: "Signups", value: 420),
    ///     LivelineSankeyLink(source: "Signups", target: "Paid", value: 120),
    /// ])
    /// ```
    ///
    /// Nodes are derived from the link endpoints and placed in columns by a
    /// single longest-path pass; their vertical order inside a column is the
    /// order the links were written, with no crossing minimization. A cycle is
    /// broken by dropping the link that closes it. In a right-to-left layout
    /// the flow runs right to left.
    public init(
        sankey links: [LivelineSankeyLink],
        color: Color = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
        style: LivelineSankeyStyle = LivelineSankeyStyle(),
        configuration: LivelineChartConfiguration = LivelineChartConfiguration()
    ) {
        self.init(content: .sankey(links: links, style: style), accent: color, configuration: configuration)
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

    init(
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
            activeWindow: visibleSpan
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
            snapshotElapsedTime: resolvedSnapshotElapsedTime,
            rendersSettledFrame: rendersSettledFrame
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
                            liveControl(configuration, semantics: semantics)
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
        .onChange(of: activeWindow) { _ in
            // Picking a window is a fresh choice of span: it clears any zoom
            // and returns the chart to the live edge.
            viewport = nil
            zoomBaseline = nil
            panBaseline = nil
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
            viewport = nil
            zoomBaseline = nil
            panBaseline = nil
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
struct LivelineModeIcon: View {
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
