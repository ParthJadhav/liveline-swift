import AppKit
import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers
@_spi(LivelineSnapshotTesting) import Liveline

// MARK: - Output

/// The repository root, derived from this source file so the generator runs
/// from any working directory and on any checkout.
let repositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // ShotGen
    .deletingLastPathComponent()  // Sources
    .deletingLastPathComponent()  // shotgen
    .deletingLastPathComponent()  // tools
    .deletingLastPathComponent()  // remotion

let outputDirectory = ProcessInfo.processInfo.environment["SHOTGEN_OUT"]
    .map { URL(fileURLWithPath: $0) }
    ?? repositoryRoot.appendingPathComponent("Docs/pr-assets")
let shotFilter = ProcessInfo.processInfo.environment["SHOTGEN_ONLY"]
let shotSize = CGSize(width: 720, height: 420)
let shotScale: CGFloat = 2
let pinnedElapsedTime: TimeInterval = 3.0

let darkBackground = Color(red: 0.043, green: 0.055, blue: 0.078)
let lightBackground = Color(red: 0.976, green: 0.980, blue: 0.988)

let blue = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255)
let violet = Color(red: 167 / 255, green: 139 / 255, blue: 250 / 255)
let cyan = Color(red: 34 / 255, green: 211 / 255, blue: 238 / 255)
let green = Color(red: 52 / 255, green: 211 / 255, blue: 153 / 255)
let amber = Color(red: 251 / 255, green: 191 / 255, blue: 36 / 255)
let red = Color(red: 248 / 255, green: 113 / 255, blue: 113 / 255)
let pink = Color(red: 244 / 255, green: 114 / 255, blue: 182 / 255)

// Light-mode inks. The release-video clips render against `lightBackground`, so
// anything that used to be white — the bullet target tick, the legend heading —
// has to flip to a dark ink or it vanishes.
let targetTick = Color(red: 0.11, green: 0.11, blue: 0.12)
let headingInk = Color(red: 0.11, green: 0.11, blue: 0.12).opacity(0.88)

// MARK: - Deterministic sample data

/// A tiny seeded LCG so every sample below is byte-identical between runs.
struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407 }

    mutating func nextUnit() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double((state >> 11) & 0x1F_FFFF_FFFF_FFFF) / Double(0x20_0000_0000_0000)
    }

    /// Box–Muller, driven entirely off the seeded uniform stream.
    mutating func nextNormal(mean: Double, standardDeviation: Double) -> Double {
        let u1 = max(nextUnit(), 1e-12)
        let u2 = nextUnit()
        let magnitude = (-2 * log(u1)).squareRoot()
        return mean + standardDeviation * magnitude * cos(2 * .pi * u2)
    }
}

let baseTime: TimeInterval = 1_722_600_000

/// Revenue per minute, 120 samples over a 120-second window: a rising trend
/// with believable jitter, no wall-clock or unseeded randomness anywhere.
let revenuePoints: [LivelinePoint] = {
    var generator = SeededGenerator(seed: 20_260_803)
    var level = 41_500.0
    return (0..<120).map { index in
        let t = Double(index)
        // A late rally so the chart closes on an uptick: the value header
        // derives its own momentum from the tail of the series, and a green
        // header beside a green badge is the honest reading of this data.
        let rally = t > 104 ? 110.0 : 0
        let drift = 62 * sin(t * 0.09) + 34 * sin(t * 0.021 + 1.4) + rally
        level += drift + generator.nextNormal(mean: 24, standardDeviation: 130)
        return LivelinePoint(time: baseTime - Double(119 - index), value: level)
    }
}()

let revenueValue = revenuePoints.last?.value ?? 0

/// p95 API latency in milliseconds, with a visible step at the deploy moment.
let deployTime = baseTime - 46
let latencyPoints: [LivelinePoint] = {
    var generator = SeededGenerator(seed: 771_003)
    return (0..<120).map { index in
        let time = baseTime - Double(119 - index)
        let postDeploy = time >= deployTime
        let base = postDeploy ? 186.0 : 268.0
        let wobble = 16 * sin(Double(index) * 0.31) + 9 * cos(Double(index) * 0.13)
        return LivelinePoint(time: time, value: base + wobble + generator.nextNormal(mean: 0, standardDeviation: 7))
    }
}()

/// 500 normally-distributed request durations for the histogram.
let latencySamples: [Double] = {
    var generator = SeededGenerator(seed: 424_242)
    return (0..<500).map { _ in generator.nextNormal(mean: 242, standardDeviation: 38) }
}()

/// Five traffic regions over 48 slots, for the centred-baseline streamgraph.
let regionLabels = ["us-east", "us-west", "eu-central", "ap-south", "sa-east"]
let streamPoints: [LivelineStackedPoint] = (0..<48).map { index in
    let t = Double(index)
    return LivelineStackedPoint(
        time: baseTime - Double(47 - index) * 30,
        values: [
            34 + 11 * sin(t * 0.18) + 5 * sin(t * 0.07 + 0.4),
            26 + 9 * cos(t * 0.15 + 0.9) + 4 * sin(t * 0.05),
            19 + 7 * sin(t * 0.23 + 1.8),
            14 + 6 * cos(t * 0.21 + 2.6) + 3 * sin(t * 0.09),
            8 + 4 * sin(t * 0.27 + 0.6),
        ]
    )
}

let cloudSpend: [LivelineTreemapNode] = [
    LivelineTreemapNode(label: "Compute", value: 486, color: blue),
    LivelineTreemapNode(label: "Storage", color: violet, children: [
        LivelineTreemapNode(label: "Hot", value: 188),
        LivelineTreemapNode(label: "Cold", value: 104),
        LivelineTreemapNode(label: "Archive", value: 41),
    ]),
    LivelineTreemapNode(label: "Network", value: 214, color: cyan),
    LivelineTreemapNode(label: "Observability", value: 132, color: green),
    LivelineTreemapNode(label: "Databases", value: 176, color: amber),
    LivelineTreemapNode(label: "CDN", value: 88, color: pink),
    LivelineTreemapNode(label: "Other", value: 47, color: red),
]

let acquisition: [LivelineSunburstNode] = [
    LivelineSunburstNode(label: "Search", color: blue, children: [
        LivelineSunburstNode(label: "Organic", value: 224),
        LivelineSunburstNode(label: "Paid", value: 96),
    ]),
    LivelineSunburstNode(label: "Direct", color: violet, children: [
        LivelineSunburstNode(label: "App", value: 140),
        LivelineSunburstNode(label: "Web", value: 112),
    ]),
    LivelineSunburstNode(label: "Social", color: cyan, children: [
        LivelineSunburstNode(label: "Posts", value: 128),
        LivelineSunburstNode(label: "Ads", value: 72),
    ]),
    LivelineSunburstNode(label: "Referral", color: green, children: [
        LivelineSunburstNode(label: "Partners", value: 96),
        LivelineSunburstNode(label: "Blogs", value: 58),
    ]),
    LivelineSunburstNode(label: "Email", color: amber, children: [
        LivelineSunburstNode(label: "Lifecycle", value: 74),
        LivelineSunburstNode(label: "Digest", value: 40),
    ]),
]

let funnelLinks: [LivelineSankeyLink] = [
    LivelineSankeyLink(source: "Search", target: "Landing", value: 420, color: blue),
    LivelineSankeyLink(source: "Search", target: "Pricing", value: 180, color: blue),
    LivelineSankeyLink(source: "Social", target: "Landing", value: 240, color: cyan),
    LivelineSankeyLink(source: "Social", target: "Blog", value: 200, color: cyan),
    LivelineSankeyLink(source: "Referral", target: "Pricing", value: 160, color: violet),
    LivelineSankeyLink(source: "Landing", target: "Signup", value: 380, color: green),
    LivelineSankeyLink(source: "Landing", target: "Bounce", value: 280, color: red),
    LivelineSankeyLink(source: "Pricing", target: "Signup", value: 210, color: green),
    LivelineSankeyLink(source: "Pricing", target: "Bounce", value: 130, color: red),
    LivelineSankeyLink(source: "Blog", target: "Signup", value: 64, color: green),
    LivelineSankeyLink(source: "Blog", target: "Bounce", value: 136, color: red),
]

let planMix: [LivelineCategoryValue] = [
    LivelineCategoryValue(id: "enterprise", label: "Enterprise", value: 412),
    LivelineCategoryValue(id: "business", label: "Business", value: 318),
    LivelineCategoryValue(id: "team", label: "Team", value: 246),
    LivelineCategoryValue(id: "pro", label: "Pro", value: 174),
    LivelineCategoryValue(id: "free", label: "Free", value: 96),
]

// MARK: - Formatters

func currency(_ value: Double) -> String {
    "$\(String(format: "%.1f", value / 1000))k"
}

func milliseconds(_ value: Double) -> String {
    "\(Int(value.rounded())) ms"
}

// MARK: - Configuration helpers

/// The value badge and the value-axis labels are drawn in the trailing gutter,
/// so it has to be wide enough to hold them — and mirrored for the RTL scene,
/// where both move to the leading edge.
func baseConfiguration(theme: LivelineThemeMode = .dark, mirrored: Bool = false) -> LivelineChartConfiguration {
    var configuration = LivelineChartConfiguration()
    configuration.theme = theme
    configuration.window = 120
    configuration.grid = true
    configuration.fill = true
    configuration.badge = true
    configuration.pulse = true
    configuration.scrub = false
    configuration.showValue = true
    configuration.valueMomentumColor = true
    configuration.autoDetectMomentum = false
    configuration.momentum = .up
    configuration.lineWidth = 2.4
    configuration.fadeEffects = false
    configuration.padding = LivelinePadding(
        top: 26,
        right: mirrored ? 26 : 92,
        bottom: 26,
        left: mirrored ? 92 : 26
    )
    return configuration
}

/// The categorical charts have no time axis or live badge, so they start from a
/// quieter configuration than the line scenes.
func staticConfiguration(theme: LivelineThemeMode = .dark) -> LivelineChartConfiguration {
    var configuration = LivelineChartConfiguration()
    configuration.theme = theme
    configuration.grid = false
    configuration.badge = false
    configuration.pulse = false
    configuration.scrub = false
    configuration.showValue = false
    configuration.fadeEffects = false
    configuration.formatValue = { value in
        abs(value) >= 10_000
            ? String(format: "%.1fk", value / 1000)
            : String(format: "%.0f", value)
    }
    configuration.padding = LivelinePadding(top: 18, right: 18, bottom: 18, left: 18)
    return configuration
}

// MARK: - Rendering

enum ShotError: Error { case rasterizationFailed(String) }

var written: [(String, Int)] = []
var skipped: [(String, String)] = []

func writePNG(_ data: Data, named name: String) {
    if let filter = shotFilter, filter != name {
        skipped.append((name, "filtered out"))
        return
    }
    let url = outputDirectory.appendingPathComponent(name)
    do {
        try data.write(to: url)
        written.append((name, data.count))
        print("wrote \(name) — \(data.count) bytes")
    } catch {
        skipped.append((name, "write failed: \(error)"))
    }
}

/// The published exporter path: everything that is a plain `LivelineChart`.
@MainActor
func exportChart(_ chart: LivelineChart, named name: String, colorScheme: ColorScheme = .dark) {
    guard let data = chart.exportedPNGData(
        size: shotSize,
        scale: shotScale,
        elapsedTime: pinnedElapsedTime,
        backgroundColor: colorScheme == .dark ? darkBackground : lightBackground,
        colorScheme: colorScheme
    ) else {
        skipped.append((name, "LivelineChartImageExporter returned nil"))
        return
    }
    writePNG(data, named: name)
}

/// The `ImageRenderer` path, for scenes that need environment injection the
/// exporter does not expose (layout direction, Dynamic Type) or that compose the
/// chart with another view (the legend).
@MainActor
func renderView<Content: View>(_ content: Content, named name: String, colorScheme: ColorScheme = .dark) {
    let wrapped = AnyView(
        ZStack {
            (colorScheme == .dark ? darkBackground : lightBackground)
            content
        }
        .frame(width: shotSize.width, height: shotSize.height)
        .livelineSnapshotElapsedTime(pinnedElapsedTime)
        .environment(\.colorScheme, colorScheme)
    )
    let renderer = ImageRenderer(content: wrapped)
    renderer.proposedSize = ProposedViewSize(width: shotSize.width, height: shotSize.height)
    renderer.scale = shotScale
    renderer.isOpaque = true
    guard let cgImage = renderer.cgImage else {
        skipped.append((name, "ImageRenderer produced no bitmap"))
        return
    }
    let mutable = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        mutable as CFMutableData,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        skipped.append((name, "PNG destination could not be created"))
        return
    }
    CGImageDestinationAddImage(destination, cgImage, nil)
    guard CGImageDestinationFinalize(destination) else {
        skipped.append((name, "PNG encoding failed"))
        return
    }
    writePNG(mutable as Data, named: name)
}

// MARK: - Scenes

@MainActor
func revenueChart(theme: LivelineThemeMode, mirrored: Bool = false) -> LivelineChart {
    var configuration = baseConfiguration(theme: theme, mirrored: mirrored)
    configuration.formatValue = currency
    return LivelineChart(data: revenuePoints, value: revenueValue, color: blue, configuration: configuration)
}

@MainActor
func annotatedLatencyChart() -> LivelineChart {
    var configuration = baseConfiguration()
    configuration.formatValue = milliseconds
    configuration.fill = false
    configuration.referenceLines = [
        LivelineReferenceLine(value: 250, axis: .value, label: "SLO 250 ms", color: amber, dash: .dashed),
        LivelineReferenceLine(value: deployTime, axis: .time, label: "Deploy v2.4", color: violet, dash: .dotted),
    ]
    configuration.referenceBands = [
        LivelineReferenceBand(
            axis: .value,
            start: 150,
            end: 210,
            label: "Target band",
            color: green,
            opacity: 0.18
        ),
    ]
    return LivelineChart(
        data: latencyPoints,
        value: latencyPoints.last?.value ?? 0,
        color: cyan,
        configuration: configuration
    )
}

@MainActor
func run() {
    // A rendering service has to exist before ImageRenderer will rasterize.
    _ = NSApplication.shared

    try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

    // 1 + 2 — the same live revenue line in both themes.
    exportChart(revenueChart(theme: .dark), named: "line-dark.png", colorScheme: .dark)
    exportChart(revenueChart(theme: .automatic), named: "line-light.png", colorScheme: .light)

    // 3 — multiple reference lines on both axes plus a shaded band.
    exportChart(annotatedLatencyChart(), named: "annotations.png")

    // 4 — Freedman–Diaconis auto-binning over 500 normal samples.
    var histogramConfiguration = staticConfiguration()
    histogramConfiguration.grid = true
    histogramConfiguration.padding = LivelinePadding(top: 26, right: 60, bottom: 32, left: 26)
    exportChart(
        LivelineChart(
            histogram: latencySamples,
            color: violet,
            style: LivelineHistogramStyle(
                binning: .freedmanDiaconis,
                barSpacing: 1.5,
                cornerRadius: 2,
                fillOpacity: 0.88,
                showsBaseline: true,
                showsEdgeLabels: true,
                showsCounts: false
            ),
            configuration: histogramConfiguration
        ),
        named: "histogram.png"
    )

    // 5 — streamgraph: stacked areas anchored on the centred baseline.
    var streamConfiguration = staticConfiguration()
    streamConfiguration.window = 48 * 30
    streamConfiguration.padding = LivelinePadding(top: 24, right: 20, bottom: 26, left: 20)
    exportChart(
        LivelineChart(
            stackedAreas: streamPoints,
            color: blue,
            style: LivelineStackedAreaStyle(
                baseline: .centered,
                colors: [blue, cyan, violet, green, amber],
                fillOpacity: 0.72,
                boundaryLineWidth: 1
            ),
            configuration: streamConfiguration
        ),
        named: "streamgraph.png"
    )

    // 6 — bullet chart: three SLO rows sharing one band scale. The renderer
    // draws the caption, the measure and the band names, so only the target
    // tick needs a key; the band names ride on the first row alone.
    let bulletBands = [
        LivelineBulletRange(value: 99.0, label: "At risk", color: red),
        LivelineBulletRange(value: 99.7, label: "Acceptable", color: amber),
        LivelineBulletRange(value: 100, label: "Healthy", color: green),
    ]
    var bulletConfiguration = staticConfiguration()
    bulletConfiguration.formatValue = { String(format: "%.2f%%", $0) }
    bulletConfiguration.padding = LivelinePadding(top: 26, right: 64, bottom: 8, left: 8)

    func sloBullet(
        _ caption: String,
        measure: Double,
        target: Double,
        showsBandLabels: Bool
    ) -> some View {
        LivelineChart(
            bullet: LivelineBulletStyle(
                measure: measure,
                target: target,
                ranges: bulletBands,
                axisRange: 98.5...100,
                label: caption,
                barHeightRatio: 0.5,
                measureHeightRatio: 0.24,
                // The band-label row needs a taller frame, which would otherwise
                // stretch its track; the cap pins every row to one strip height.
                maximumBarHeight: 24,
                measureColor: cyan,
                targetColor: .white,
                bandOpacity: 0.34,
                showsValue: true,
                showsBandLabels: showsBandLabels
            ),
            color: cyan,
            configuration: bulletConfiguration
        )
        // Every row keeps the same frame so the tracks share a baseline rhythm;
        // the band-label row simply spends its lower half on the labels.
        .frame(height: 96)
    }

    renderView(
        VStack(spacing: 6) {
            sloBullet("Checkout availability", measure: 99.94, target: 99.90, showsBandLabels: false)
            sloBullet("API availability", measure: 99.62, target: 99.90, showsBandLabels: false)
            sloBullet("Webhook delivery", measure: 98.87, target: 99.50, showsBandLabels: true)

            LivelineLegend(
                items: [LivelineLegendItem(label: "Target", color: .white)],
                axis: .horizontal,
                swatch: .roundedSquare,
                theme: .dark
            )
            .padding(.top, 10)
        }
        .padding(.horizontal, 32),
        named: "bullet.png"
    )

    // 7 — treemap with a nested group.
    exportChart(
        LivelineChart(
            treemap: cloudSpend,
            color: blue,
            style: LivelineTreemapStyle(
                padding: 3,
                groupPadding: 4,
                cornerRadius: 4,
                fillOpacity: 0.9,
                showsLabels: true,
                showsValues: true
            ),
            configuration: staticConfiguration()
        ),
        named: "treemap.png"
    )

    // 8 — two-ring sunburst.
    exportChart(
        LivelineChart(
            sunburst: acquisition,
            color: blue,
            style: LivelineSunburstStyle(
                innerRadiusRatio: 0.26,
                innerRingRatio: 0.44,
                ringSpacing: 3,
                gapDegrees: 1.2,
                showsLabels: true,
                showsValues: false,
                minimumLabelDegrees: 14
            ),
            configuration: staticConfiguration()
        ),
        named: "sunburst.png"
    )

    // 9 — sankey across three columns.
    exportChart(
        LivelineChart(
            sankey: funnelLinks,
            color: blue,
            style: LivelineSankeyStyle(
                nodeWidth: 12,
                nodeSpacing: 14,
                linkOpacity: 0.42,
                cornerRadius: 3,
                showsLabels: true,
                showsValues: true
            ),
            configuration: staticConfiguration()
        ),
        named: "sankey.png"
    )

    // 10 — the revenue line mirrored right-to-left. The exporter has no
    // environment hook, so this drives ImageRenderer against the same view.
    renderView(
        revenueChart(theme: .dark)
            .environment(\.layoutDirection, .rightToLeft),
        named: "rtl.png"
    )

    // 11 — the revenue line at an accessibility Dynamic Type size; the chart
    // reads `dynamicTypeSize` from the environment and scales its canvas text.
    renderView(
        revenueChart(theme: .dark)
            .environment(\.dynamicTypeSize, .accessibility3),
        named: "dynamic-type.png"
    )

    // 12 — a donut composed with the standalone LivelineLegend view.
    var donutConfiguration = staticConfiguration()
    donutConfiguration.padding = LivelinePadding(top: 8, right: 8, bottom: 8, left: 8)
    let donutStyle = LivelineDonutStyle(
        innerRadiusRatio: 0.58,
        gapDegrees: 1.5,
        colors: [blue, violet, cyan, green, amber],
        showsLabels: false,
        showsValues: false
    )
    renderView(
        VStack(spacing: 14) {
            Text("Revenue by plan")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.86))
            LivelineChart(donut: planMix, color: blue, style: donutStyle, configuration: donutConfiguration)
                .frame(height: 288)
            LivelineLegend(
                items: LivelineLegendItem.items(donut: planMix, style: donutStyle),
                axis: .horizontal,
                swatch: .circle,
                theme: .dark
            )
        }
        .padding(20),
        named: "legend.png"
    )

    print("\n--- summary ---")
    for (name, size) in written { print("ok    \(name) \(size)") }
    for (name, reason) in skipped { print("SKIP  \(name): \(reason)") }
}

// MARK: - Frame sequences (live-chart footage for the release video)
//
// The still shots above pin one instant. The release video needs motion, so
// every clip below re-renders the *same* public export path once per video
// frame with the data advanced by one step — a real streaming chart captured
// through `LivelineChartImageExporter`, not a screen recording.

let clipsRoot = ProcessInfo.processInfo.environment["SHOTGEN_CLIPS_OUT"]
    .map { URL(fileURLWithPath: $0) }
    ?? repositoryRoot.appendingPathComponent("remotion/public/clips")
let clipSize = CGSize(width: 800, height: 450)
let clipScale: CGFloat = 2
let clipFilter = ProcessInfo.processInfo.environment["SHOTGEN_CLIPS_ONLY"]?
    .split(separator: ",").map(String.init)

/// A gentle deterministic oscillation used to keep categorical charts alive:
/// the same seeded values, breathing, so tiles and arcs actually move.
func wobble(_ frame: Int, phase: Double, amount: Double = 0.16, rate: Double = 0.055) -> Double {
    1 + amount * sin(Double(frame) * rate + phase)
}

// A 240-sample pool; each clip frame shows a 120-sample window sliding forward
// one sample per video frame, which is exactly what a live chart does.
let revenuePool: [LivelinePoint] = {
    var generator = SeededGenerator(seed: 20_260_803)
    var level = 41_500.0
    return (0..<240).map { index in
        let t = Double(index)
        let drift = 62 * sin(t * 0.09) + 34 * sin(t * 0.021 + 1.4)
        level += drift + generator.nextNormal(mean: 24, standardDeviation: 130)
        return LivelinePoint(time: baseTime - Double(239 - index), value: level)
    }
}()

func revenueWindow(_ frame: Int) -> [LivelinePoint] {
    let start = min(frame, revenuePool.count - 120)
    return Array(revenuePool[start..<(start + 120)])
}

/// The deploy step sits at pool index 119 so it enters at the right edge on the
/// first frame and scrolls left across the clip.
let deployPoolIndex = 119
let latencyPool: [LivelinePoint] = {
    var generator = SeededGenerator(seed: 771_003)
    return (0..<240).map { index in
        let base = index >= deployPoolIndex ? 186.0 : 268.0
        let wobbleTerm = 16 * sin(Double(index) * 0.31) + 9 * cos(Double(index) * 0.13)
        return LivelinePoint(
            time: baseTime - Double(239 - index),
            value: base + wobbleTerm + generator.nextNormal(mean: 0, standardDeviation: 7)
        )
    }
}()
let deployPoolTime = latencyPool[deployPoolIndex].time

func latencyWindow(_ frame: Int) -> [LivelinePoint] {
    let start = min(frame, latencyPool.count - 120)
    return Array(latencyPool[start..<(start + 120)])
}

let streamPool: [LivelineStackedPoint] = (0..<96).map { index in
    let t = Double(index)
    return LivelineStackedPoint(
        time: baseTime - Double(95 - index) * 30,
        values: [
            34 + 11 * sin(t * 0.18) + 5 * sin(t * 0.07 + 0.4),
            26 + 9 * cos(t * 0.15 + 0.9) + 4 * sin(t * 0.05),
            19 + 7 * sin(t * 0.23 + 1.8),
            14 + 6 * cos(t * 0.21 + 2.6) + 3 * sin(t * 0.09),
            8 + 4 * sin(t * 0.27 + 0.6),
        ]
    )
}

func streamWindow(_ frame: Int) -> [LivelineStackedPoint] {
    let start = min(frame, streamPool.count - 48)
    return Array(streamPool[start..<(start + 48)])
}

/// 500 seeded durations; the histogram fills from 160 to all of them so the
/// bins visibly build and the Freedman–Diaconis width re-solves live.
func histogramSamples(_ frame: Int, frames: Int) -> [Double] {
    let progress = frames <= 1 ? 1 : Double(frame) / Double(frames - 1)
    let count = Int(160 + progress * Double(latencySamples.count - 160))
    return Array(latencySamples.prefix(max(2, count)))
}

func breathingTreemap(_ frame: Int) -> [LivelineTreemapNode] {
    cloudSpend.enumerated().map { index, node in
        let factor = wobble(frame, phase: Double(index) * 0.9)
        if !node.children.isEmpty {
            return LivelineTreemapNode(
                label: node.label,
                color: node.color,
                children: node.children.enumerated().map { childIndex, child in
                    LivelineTreemapNode(
                        label: child.label,
                        value: child.value * wobble(frame, phase: Double(childIndex) * 1.7 + 2.1)
                    )
                }
            )
        }
        return LivelineTreemapNode(label: node.label, value: node.value * factor, color: node.color)
    }
}

func breathingSunburst(_ frame: Int) -> [LivelineSunburstNode] {
    acquisition.enumerated().map { index, node in
        LivelineSunburstNode(
            label: node.label,
            color: node.color,
            children: node.children.enumerated().map { childIndex, child in
                LivelineSunburstNode(
                    label: child.label,
                    value: child.value * wobble(frame, phase: Double(index) * 1.3 + Double(childIndex) * 2.4)
                )
            }
        )
    }
}

func breathingSankey(_ frame: Int) -> [LivelineSankeyLink] {
    funnelLinks.enumerated().map { index, link in
        LivelineSankeyLink(
            source: link.source,
            target: link.target,
            value: link.value * wobble(frame, phase: Double(index) * 0.8, amount: 0.13),
            color: link.color
        )
    }
}

func breathingPlanMix(_ frame: Int) -> [LivelineCategoryValue] {
    planMix.enumerated().map { index, entry in
        LivelineCategoryValue(
            id: entry.id,
            label: entry.label,
            value: entry.value * wobble(frame, phase: Double(index) * 1.1, amount: 0.14)
        )
    }
}

func encodePNG(_ image: CGImage) -> Data? {
    let mutable = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        mutable as CFMutableData,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else { return nil }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { return nil }
    return mutable as Data
}

var clipSummary: [(String, Int, Int)] = []

func shouldRenderClip(_ name: String) -> Bool {
    guard let clipFilter else { return true }
    return clipFilter.contains(name)
}

func writeClipFrame(_ data: Data, clip: URL, index: Int) -> Int {
    let url = clip.appendingPathComponent(String(format: "frame-%03d.png", index))
    do {
        try data.write(to: url)
        return data.count
    } catch {
        skipped.append(("\(clip.lastPathComponent)/\(index)", "write failed: \(error)"))
        return 0
    }
}

/// The published exporter path, once per video frame.
@MainActor
func renderClip(
    _ name: String,
    frames: Int,
    colorScheme: ColorScheme = .dark,
    chart: (Int) -> LivelineChart
) {
    guard shouldRenderClip(name) else { return }
    let directory = clipsRoot.appendingPathComponent(name)
    try? FileManager.default.removeItem(at: directory)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var bytes = 0
    var written = 0
    for frame in 0..<frames {
        guard let data = chart(frame).exportedPNGData(
            size: clipSize,
            scale: clipScale,
            // Past the entrance ramp, then advancing in real time so the pulse
            // and dither keep breathing across the clip.
            elapsedTime: pinnedElapsedTime + Double(frame) / 30.0,
            backgroundColor: colorScheme == .dark ? darkBackground : lightBackground,
            colorScheme: colorScheme
        ) else {
            skipped.append(("\(name)/\(frame)", "exporter returned nil"))
            continue
        }
        bytes += writeClipFrame(data, clip: directory, index: frame)
        written += 1
    }
    clipSummary.append((name, written, bytes))
    print("clip \(name): \(written) frames, \(bytes / 1024) KB")
}

/// The `ImageRenderer` path, for clips needing environment injection the
/// exporter does not expose (layout direction, Dynamic Type, composed legends).
@MainActor
func renderViewClip<Content: View>(
    _ name: String,
    frames: Int,
    colorScheme: ColorScheme = .dark,
    content: (Int) -> Content
) {
    guard shouldRenderClip(name) else { return }
    let directory = clipsRoot.appendingPathComponent(name)
    try? FileManager.default.removeItem(at: directory)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var bytes = 0
    var written = 0
    for frame in 0..<frames {
        let wrapped = AnyView(
            ZStack {
                (colorScheme == .dark ? darkBackground : lightBackground)
                content(frame)
            }
            .frame(width: clipSize.width, height: clipSize.height)
            .livelineSnapshotElapsedTime(pinnedElapsedTime + Double(frame) / 30.0)
            .environment(\.colorScheme, colorScheme)
        )
        let renderer = ImageRenderer(content: wrapped)
        renderer.proposedSize = ProposedViewSize(width: clipSize.width, height: clipSize.height)
        renderer.scale = clipScale
        renderer.isOpaque = true
        guard let cgImage = renderer.cgImage, let data = encodePNG(cgImage) else {
            skipped.append(("\(name)/\(frame)", "ImageRenderer produced no bitmap"))
            continue
        }
        bytes += writeClipFrame(data, clip: directory, index: frame)
        written += 1
    }
    clipSummary.append((name, written, bytes))
    print("clip \(name): \(written) frames, \(bytes / 1024) KB")
}

@MainActor
func runFrames() {
    _ = NSApplication.shared
    try? FileManager.default.createDirectory(at: clipsRoot, withIntermediateDirectories: true)

    // 1 — the live scrolling revenue line, light. The window slides one sample
    // per frame, which is also what exercises the new displayWindow smoothing.
    // The release video is a light-mode cut, so every clip below resolves
    // `.automatic` against a `.light` color scheme; only `line-dark` opts out,
    // because the theming scene needs something to cross-dissolve into.
    renderClip("line-live", frames: 120, colorScheme: .light) { frame in
        var configuration = baseConfiguration(theme: .automatic)
        configuration.formatValue = currency
        // The badge already carries the live reading; tinting the header by
        // momentum too puts a red number beside a green pill on dipping
        // windows, so the header stays neutral for the video.
        configuration.autoDetectMomentum = true
        configuration.valueMomentumColor = false
        let window = revenueWindow(frame)
        return LivelineChart(
            data: window,
            value: window.last?.value ?? 0,
            color: blue,
            configuration: configuration
        )
    }

    // 2 — the identical stream in the dark theme, for the theme crossfade. Same
    // window function as `line-live`, so the two clips land frame-for-frame on
    // the same curve and only the palette changes across the dissolve.
    renderClip("line-dark", frames: 90, colorScheme: .dark) { frame in
        var configuration = baseConfiguration(theme: .automatic)
        configuration.formatValue = currency
        configuration.autoDetectMomentum = true
        configuration.valueMomentumColor = false
        let window = revenueWindow(frame)
        return LivelineChart(
            data: window,
            value: window.last?.value ?? 0,
            color: blue,
            configuration: configuration
        )
    }

    // 3 — reference lines on both axes plus a shaded band; the deploy marker
    // enters at the right edge and scrolls away with the data.
    renderClip("annotations", frames: 120, colorScheme: .light) { frame in
        var configuration = baseConfiguration(theme: .automatic)
        configuration.formatValue = milliseconds
        configuration.autoDetectMomentum = true
        configuration.valueMomentumColor = false
        configuration.fill = false
        configuration.referenceLines = [
            LivelineReferenceLine(value: 250, axis: .value, label: "SLO 250 ms", color: amber, dash: .dashed),
            LivelineReferenceLine(value: deployPoolTime, axis: .time, label: "Deploy v2.4", color: violet, dash: .dotted),
        ]
        configuration.referenceBands = [
            LivelineReferenceBand(axis: .value, start: 150, end: 210, label: "Target band", color: green, opacity: 0.18),
        ]
        let window = latencyWindow(frame)
        return LivelineChart(
            data: window,
            value: window.last?.value ?? 0,
            color: cyan,
            configuration: configuration
        )
    }

    // 4 — histogram filling up, re-binning as the sample count grows.
    renderClip("histogram", frames: 90, colorScheme: .light) { frame in
        var configuration = staticConfiguration(theme: .automatic)
        configuration.grid = true
        configuration.padding = LivelinePadding(top: 26, right: 60, bottom: 32, left: 26)
        return LivelineChart(
            histogram: histogramSamples(frame, frames: 90),
            color: violet,
            style: LivelineHistogramStyle(
                binning: .freedmanDiaconis,
                barSpacing: 1.5,
                cornerRadius: 2,
                fillOpacity: 0.88,
                showsBaseline: true,
                showsEdgeLabels: true,
                showsCounts: false
            ),
            configuration: configuration
        )
    }

    // 5 — streamgraph scrolling across its centred baseline.
    renderClip("streamgraph", frames: 90, colorScheme: .light) { frame in
        var configuration = staticConfiguration(theme: .automatic)
        configuration.window = 48 * 30
        configuration.padding = LivelinePadding(top: 24, right: 20, bottom: 26, left: 20)
        return LivelineChart(
            stackedAreas: streamWindow(frame),
            color: blue,
            style: LivelineStackedAreaStyle(
                baseline: .centered,
                colors: [blue, cyan, violet, green, amber],
                fillOpacity: 0.72,
                boundaryLineWidth: 1
            ),
            configuration: configuration
        )
    }

    // 6 — treemap, squarified layout re-solving as the spend breathes.
    renderClip("treemap", frames: 75, colorScheme: .light) { frame in
        LivelineChart(
            treemap: breathingTreemap(frame),
            color: blue,
            style: LivelineTreemapStyle(
                padding: 3,
                groupPadding: 4,
                cornerRadius: 4,
                fillOpacity: 0.9,
                showsLabels: true,
                showsValues: true
            ),
            configuration: staticConfiguration(theme: .automatic)
        )
    }

    // 7 — two-ring sunburst with live segment shares.
    renderClip("sunburst", frames: 75, colorScheme: .light) { frame in
        LivelineChart(
            sunburst: breathingSunburst(frame),
            color: blue,
            style: LivelineSunburstStyle(
                innerRadiusRatio: 0.26,
                innerRingRatio: 0.44,
                ringSpacing: 3,
                gapDegrees: 1.2,
                showsLabels: true,
                showsValues: false,
                minimumLabelDegrees: 14
            ),
            configuration: staticConfiguration(theme: .automatic)
        )
    }

    // 8 — sankey funnel with live link widths.
    renderClip("sankey", frames: 75, colorScheme: .light) { frame in
        LivelineChart(
            sankey: breathingSankey(frame),
            color: blue,
            style: LivelineSankeyStyle(
                nodeWidth: 12,
                nodeSpacing: 14,
                linkOpacity: 0.42,
                cornerRadius: 3,
                showsLabels: true,
                showsValues: true
            ),
            configuration: staticConfiguration(theme: .automatic)
        )
    }

    // 9 — three live SLO bullets sharing one band scale.
    let bulletBands = [
        LivelineBulletRange(value: 99.0, label: "At risk", color: red),
        LivelineBulletRange(value: 99.7, label: "Acceptable", color: amber),
        LivelineBulletRange(value: 100, label: "Healthy", color: green),
    ]
    var bulletConfiguration = staticConfiguration(theme: .automatic)
    bulletConfiguration.formatValue = { String(format: "%.2f%%", $0) }
    bulletConfiguration.padding = LivelinePadding(top: 26, right: 64, bottom: 8, left: 8)

    func sloBullet(
        _ caption: String,
        measure: Double,
        target: Double,
        showsBandLabels: Bool
    ) -> some View {
        LivelineChart(
            bullet: LivelineBulletStyle(
                measure: measure,
                target: target,
                ranges: bulletBands,
                axisRange: 98.5...100,
                label: caption,
                barHeightRatio: 0.5,
                measureHeightRatio: 0.24,
                maximumBarHeight: 24,
                measureColor: cyan,
                // The target tick has to read against the band fills, which are
                // light-mode pastels here — white would disappear into them.
                targetColor: targetTick,
                bandOpacity: 0.34,
                showsValue: true,
                showsBandLabels: showsBandLabels
            ),
            color: cyan,
            configuration: bulletConfiguration
        )
        .frame(height: 96)
    }

    renderViewClip("bullet", frames: 60, colorScheme: .light) { frame in
        let t = Double(frame)
        return VStack(spacing: 6) {
            sloBullet(
                "Checkout availability",
                measure: 99.94 + 0.04 * sin(t * 0.09),
                target: 99.90,
                showsBandLabels: false
            )
            sloBullet(
                "API availability",
                measure: 99.62 + 0.16 * sin(t * 0.07 + 1.2),
                target: 99.90,
                showsBandLabels: false
            )
            sloBullet(
                "Webhook delivery",
                measure: 98.87 + 0.22 * sin(t * 0.06 + 2.4),
                target: 99.50,
                showsBandLabels: true
            )

            LivelineLegend(
                items: [LivelineLegendItem(label: "Target", color: targetTick)],
                axis: .horizontal,
                swatch: .roundedSquare,
                theme: .automatic
            )
            .padding(.top, 10)
        }
        .padding(.horizontal, 32)
    }

    // 10 — the same live revenue stream mirrored right-to-left.
    renderViewClip("rtl", frames: 60, colorScheme: .light) { frame in
        var configuration = baseConfiguration(theme: .automatic)
        configuration.formatValue = currency
        configuration.autoDetectMomentum = true
        configuration.valueMomentumColor = false
        let window = revenueWindow(frame)
        return LivelineChart(
            data: window,
            value: window.last?.value ?? 0,
            color: blue,
            configuration: configuration
        )
        .environment(\.layoutDirection, .rightToLeft)
    }

    // 11 — the same chart at an accessibility Dynamic Type size.
    renderViewClip("dynamic-type", frames: 45, colorScheme: .light) { frame in
        var configuration = baseConfiguration(theme: .automatic)
        configuration.formatValue = currency
        configuration.autoDetectMomentum = true
        configuration.valueMomentumColor = false
        configuration.padding = LivelinePadding(top: 30, right: 150, bottom: 34, left: 26)
        let window = revenueWindow(frame)
        return LivelineChart(
            data: window,
            value: window.last?.value ?? 0,
            color: blue,
            configuration: configuration
        )
        .environment(\.dynamicTypeSize, .accessibility3)
    }

    // 12 — a live donut composed with the standalone LivelineLegend.
    var donutConfiguration = staticConfiguration(theme: .automatic)
    donutConfiguration.padding = LivelinePadding(top: 8, right: 8, bottom: 8, left: 8)
    renderViewClip("legend", frames: 75, colorScheme: .light) { frame in
        let mix = breathingPlanMix(frame)
        let donutStyle = LivelineDonutStyle(
            innerRadiusRatio: 0.58,
            gapDegrees: 1.5,
            colors: [blue, violet, cyan, green, amber],
            showsLabels: false,
            showsValues: false
        )
        return VStack(spacing: 14) {
            Text("Revenue by plan")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(headingInk)
            LivelineChart(donut: mix, color: blue, style: donutStyle, configuration: donutConfiguration)
                .frame(height: 300)
            LivelineLegend(
                items: LivelineLegendItem.items(donut: mix, style: donutStyle),
                axis: .horizontal,
                swatch: .circle,
                theme: .automatic
            )
        }
        .padding(20)
    }

    print("\n--- clip summary ---")
    var total = 0
    for (name, count, bytes) in clipSummary {
        total += count
        print("ok    \(name) \(count) frames \(bytes / 1024) KB")
    }
    print("total frames: \(total)")
    for (name, reason) in skipped { print("SKIP  \(name): \(reason)") }
}

if ProcessInfo.processInfo.environment["SHOTGEN_MODE"] == "frames" {
    MainActor.assumeIsolated { runFrames() }
} else {
    MainActor.assumeIsolated { run() }
}
