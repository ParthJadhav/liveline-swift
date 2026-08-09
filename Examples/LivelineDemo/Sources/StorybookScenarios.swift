import Liveline
import SwiftUI

enum StorybookScenarioLaunch {
    case none
    case scenario(StorybookScenario)
    case invalid(String)
}

struct StorybookLaunch {
    static let captureStatusFilename = "liveline-storybook-capture-status.txt"

    static func ditherShowcaseFromArguments() -> Bool {
        ProcessInfo.processInfo.arguments.contains("--dither-showcase")
    }

    static func chartShowcaseFromArguments() -> Bool {
        ProcessInfo.processInfo.arguments.contains("--chart-showcase")
    }

    static func scenarioLaunchFromArguments() -> StorybookScenarioLaunch {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--storybook-scenario") else {
            return .none
        }
        guard arguments.indices.contains(index + 1),
              !arguments[index + 1].hasPrefix("--")
        else {
            return .invalid("Missing scenario ID after --storybook-scenario.")
        }

        let requestedID = arguments[index + 1]
        guard let scenario = StorybookCatalog.scenario(id: requestedID) else {
            return .invalid("Unknown Storybook scenario ID “\(requestedID)”.")
        }
        return .scenario(scenario)
    }

    static func chartOnlyFromArguments() -> Bool {
        ProcessInfo.processInfo.arguments.contains("--storybook-chart-only")
    }

    static func storybookQueryFromArguments() -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--storybook-query"),
              arguments.indices.contains(index + 1),
              !arguments[index + 1].hasPrefix("--")
        else {
            return nil
        }
        return arguments[index + 1]
    }

    static func orderbookSeedFromArguments() -> UInt32? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--storybook-orderbook-seed"),
              arguments.indices.contains(index + 1)
        else {
            return nil
        }

        let rawValue = arguments[index + 1]
        if rawValue.hasPrefix("0x") || rawValue.hasPrefix("0X") {
            return UInt32(rawValue.dropFirst(2), radix: 16)
        }
        return UInt32(rawValue)
    }

    static func snapshotElapsedTimeFromArguments() -> TimeInterval? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--storybook-snapshot-elapsed"),
              arguments.indices.contains(index + 1)
        else {
            return nil
        }

        return TimeInterval(arguments[index + 1])
    }

    static func recordScenarioReady(_ scenarioID: String) {
        writeCaptureStatus(scenarioID)
    }

    static func recordScenarioFailure(_ message: String) {
        writeCaptureStatus("ERROR:\(message.replacingOccurrences(of: "\n", with: " "))")
    }

    private static func writeCaptureStatus(_ value: String) {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--storybook-capture-token"),
              arguments.indices.contains(index + 1),
              !arguments[index + 1].hasPrefix("--"),
              let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        else {
            return
        }

        let payload = "\(arguments[index + 1])|\(value)\n"
        let statusURL = cachesDirectory.appendingPathComponent(captureStatusFilename)
        do {
            try payload.write(to: statusURL, atomically: true, encoding: .utf8)
        } catch {
            assertionFailure("Could not write Storybook capture status: \(error)")
        }
    }
}

struct StorybookLaunchErrorView: View {
    let message: String

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(.red)

                Text("Storybook launch failed")
                    .font(.title2.bold())

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("Check the scenario manifest and launch arguments.")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .frame(maxWidth: 520)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("storybook-launch-error")
        }
        .onAppear {
            StorybookLaunch.recordScenarioFailure(message)
        }
    }
}

struct StorybookScenario: Identifiable {
    let id: String
    let group: String
    let title: String
    let detail: String
    let background: Color
    let height: CGFloat
    let makeView: () -> AnyView

    var interactionSummary: String {
        if id.contains("zoom") {
            return "Drag to inspect, then pinch or pan the plot to explore the viewport."
        }
        if id.contains("controls") || id.contains("windows") || id.contains("line-mode") {
            return "Use the controls above the plot, then drag across the chart to inspect values."
        }
        return "Drag across the chart to inspect its nearest value or category."
    }

    var codeSample: String {
        StorybookCodeSamples.sample(for: self)
    }
}

private enum StorybookCodeSamples {
    static func sample(for scenario: StorybookScenario) -> String {
        let initializer: String
        var includesAccent = true
        switch scenario.group {
        case "Line":
            initializer = "data: points, value: points.last?.value ?? 0"
            includesAccent = true
        case "Candles":
            initializer = """
            data: closingPrices,
                value: closingPrices.last?.value ?? 0,
                candles: candles,
                candleWidth: 30,
                liveCandle: currentCandle
            """
            includesAccent = true
        case "Multi-series":
            initializer = "series: series"
            includesAccent = false
        case "Bars": initializer = "bars: bars"
        case "Range bands": initializer = "range: ranges"
        case "Scatter": initializer = "scatter: points"
        case "Step": initializer = "steps: points"
        case "Lollipop": initializer = "lollipops: events"
        case "Bubble": initializer = "bubbles: bubbles"
        case "Box plot": initializer = "boxPlots: distributions"
        case "Waterfall": initializer = "waterfall: changes"
        case "Error bar": initializer = "errorBars: measurements"
        case "Dumbbell": initializer = "dumbbells: comparisons"
        case "Stacked bar": initializer = "stackedBars: categories"
        case "Stacked area": initializer = "stackedAreas: series"
        case "Timeline": initializer = "timeline: intervals"
        case "Heatmap": initializer = "heatmap: cells"
        case "Radar": initializer = "radar: metrics"
        case "Donut": initializer = "donut: categories"
        case "Gauge": initializer = "gauge: progress"
        case "Funnel": initializer = "funnel: stages"
        case "Histogram": initializer = "histogram: samples"
        case "Bullet": initializer = "bullet: bulletStyle"
        case "Treemap": initializer = "treemap: hierarchy"
        case "Sunburst": initializer = "sunburst: hierarchy"
        case "Sankey": initializer = "sankey: flows"
        default:
            initializer = "data: points, value: points.last?.value ?? 0"
        }

        return renderedSample(initializer: initializer, includesAccent: includesAccent, height: scenario.height)
    }

    private static func renderedSample(
        initializer: String,
        includesAccent: Bool = true,
        height: CGFloat
    ) -> String {
        let accent = includesAccent ? "    color: .blue,\n" : ""
        return """
        LivelineChart(
            \(initializer),
        \(accent)    configuration: LivelineChartConfiguration(
                theme: .automatic,
                scrub: true
            )
        )
        .frame(height: \(Int(height)))
        """
    }
}

enum StorybookCatalog {
    private static let definitions: [StorybookScenario] = [
        lineBasicDark,
        lineBasicLight,
        lineNoGridNoFill,
        lineMinimalBadge,
        lineNoBadge,
        lineMomentumUp,
        lineMomentumDown,
        lineExaggerated,
        lineShowValueWindows,
        lineRoundedWindows,
        lineTextWindows,
        lineZoomPan,
        lineReference,
        lineOrderbook,
        lineDegen,
        lineLoading,
        lineEmpty,
        lineEmptyControls,
        candleBasic,
        candleLight,
        candleLineMode,
        candleModeControls,
        candleNoLive,
        candleWideWindow,
        candleLoading,
        multiBasic,
        multiLight,
        multiCompact,
        multiTwoSeries,
        barBasic,
        barSigned,
        rangeBasic,
        rangeCenterLine,
        scatterBasic,
        scatterConnected,
        stepBasic,
        stepCentered,
        lollipopBasic,
        lollipopDiamond,
        bubbleBasic,
        bubbleDiameter,
        boxPlotBasic,
        boxPlotMinimal,
        waterfallBasic,
        waterfallNoConnectors,
        errorBarBasic,
        errorBarDiamond,
        dumbbellBasic,
        dumbbellDirectional,
        stackedBarBasic,
        stackedBarNormalized,
        stackedAreaBasic,
        stackedAreaNormalized,
        stackedAreaStream,
        timelineBasic,
        timelineCompact,
        heatmapBasic,
        heatmapValues,
        radarBasic,
        radarMinimal,
        donutBasic,
        donutThin,
        gaugeBasic,
        gaugeTarget,
        funnelBasic,
        funnelCompact,
        histogramBasic,
        bulletBasic,
        treemapBasic,
        sunburstBasic,
        sankeyBasic,
    ]

    static let all = definitions

    static func scenario(id: String) -> StorybookScenario? {
        all.first { $0.id == id }
    }

    static var groups: [(name: String, scenarios: [StorybookScenario])] {
        let names = Array(Set(all.map(\.group))).sorted()
        return names.map { name in
            (name, all.filter { $0.group == name })
        }
    }
}

extension StorybookCatalog {

    static func chart<V: View>(
        id: StorybookScenarioID,
        group: String,
        title: String,
        detail: String,
        background: Color,
        height: CGFloat = 280,
        @ViewBuilder makeView: @escaping () -> V
    ) -> StorybookScenario {
        StorybookScenario(
            id: id.rawValue,
            group: group,
            title: title,
            detail: detail,
            background: background,
            height: height,
            makeView: { AnyView(makeView()) }
        )
    }
}
