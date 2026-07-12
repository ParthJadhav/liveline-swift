import Liveline
import SwiftUI

extension StorybookCatalog {
    static let stackedBarBasic = chart(
        id: .stackedbarBasic,
        group: "Stacked bar",
        title: "Traffic Mix",
        detail: "Absolute segment totals with rounded, separated stacks.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            stackedBars: StorybookData.stacked,
            color: StorybookData.blue,
            style: LivelineStackedBarStyle(
                widthRatio: 0.74,
                cornerRadius: 2,
                segmentSpacing: 1,
                colors: StorybookData.segmentColors
            ),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: " k")
        )
    }

    static let stackedBarNormalized = chart(
        id: .stackedbarNormalized,
        group: "Stacked bar",
        title: "Traffic Share",
        detail: "Each stack is normalized to 100 percent.",
        background: .white
    ) {
        LivelineChart(
            stackedBars: StorybookData.stacked,
            color: StorybookData.blue,
            style: LivelineStackedBarStyle(
                mode: .normalized,
                widthRatio: 0.88,
                cornerRadius: 0,
                segmentSpacing: 0,
                colors: StorybookData.segmentColors,
                showsBaseline: false
            ),
            configuration: StorybookData.normalizedSnapshotConfig(theme: .light, window: 180)
        )
    }

    static let stackedAreaBasic = chart(
        id: .stackedareaBasic,
        group: "Stacked area",
        title: "Service Volume",
        detail: "Layered absolute volumes with visible boundaries.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            stackedAreas: StorybookData.stackedArea,
            color: StorybookData.blue,
            style: LivelineStackedAreaStyle(colors: StorybookData.segmentColors, fillOpacity: 0.55, boundaryLineWidth: 1.25),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: " k")
        )
    }

    static let stackedAreaNormalized = chart(
        id: .stackedareaNormalized,
        group: "Stacked area",
        title: "Service Share",
        detail: "Normalized layers show composition rather than magnitude.",
        background: .white
    ) {
        LivelineChart(
            stackedAreas: StorybookData.stackedArea,
            color: StorybookData.blue,
            style: LivelineStackedAreaStyle(
                mode: .normalized,
                colors: StorybookData.segmentColors,
                fillOpacity: 0.72,
                boundaryLineWidth: 0,
                showsBaseline: false
            ),
            configuration: StorybookData.normalizedSnapshotConfig(theme: .light, window: 180)
        )
    }

    static let timelineBasic = chart(
        id: .timelineBasic,
        group: "Timeline",
        title: "Release Pipeline",
        detail: "Overlapping work intervals arranged across lanes.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            timeline: StorybookData.timeline,
            color: StorybookData.cyan,
            style: LivelineTimelineStyle(colors: StorybookData.segmentColors, showsLabels: true),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: "")
        )
    }

    static let timelineCompact = chart(
        id: .timelineCompact,
        group: "Timeline",
        title: "Compact Schedule",
        detail: "Slim square intervals without lane guides.",
        background: .white
    ) {
        LivelineChart(
            timeline: StorybookData.timeline,
            color: StorybookData.orange,
            style: LivelineTimelineStyle(barHeightRatio: 0.36, cornerRadius: 0, colors: [StorybookData.orange], showsLabels: false, showsLaneGuides: false),
            configuration: StorybookData.staticSnapshotConfig(theme: .light, window: 180, suffix: "")
        )
    }

    static let heatmapBasic = chart(
        id: .heatmapBasic,
        group: "Heatmap",
        title: "Regional Load",
        detail: "Color intensity tracks load across time and regions.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            heatmap: StorybookData.heatmap,
            color: StorybookData.violet,
            style: LivelineHeatmapStyle(rowLabels: ["US", "EU", "APAC", "LATAM"], color: StorybookData.violet),
            configuration: StorybookData.staticSnapshotConfig(
                theme: .dark,
                window: 180,
                suffix: "%",
                padding: LivelinePadding(left: 50)
            )
        )
    }

    static let heatmapValues = chart(
        id: .heatmapValues,
        group: "Heatmap",
        title: "Annotated Matrix",
        detail: "Wide cells display their rounded intensity values.",
        background: .white
    ) {
        LivelineChart(
            heatmap: StorybookData.heatmapSparse,
            color: StorybookData.teal,
            style: LivelineHeatmapStyle(
                rowLabels: ["API", "Jobs", "DB"],
                color: StorybookData.teal,
                minimumOpacity: 0.08,
                cellWidthRatio: 0.94,
                cellHeightRatio: 0.74,
                cornerRadius: 5,
                showsValues: true
            ),
            configuration: StorybookData.staticSnapshotConfig(
                theme: .light,
                window: 180,
                suffix: "%",
                padding: LivelinePadding(left: 50)
            )
        )
    }

    static let radarBasic = chart(
        id: .radarBasic,
        group: "Radar",
        title: "System Profile",
        detail: "Six labeled axes with filled performance coverage.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            radar: StorybookData.radar,
            color: StorybookData.cyan,
            style: LivelineRadarStyle(range: 0...100, gridLevels: 5, fillOpacity: 0.22, lineWidth: 2, pointSize: 5),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: "%")
        )
    }

    static let radarMinimal = chart(
        id: .radarMinimal,
        group: "Radar",
        title: "Minimal Profile",
        detail: "Three grid levels without labels or point markers.",
        background: .white
    ) {
        LivelineChart(
            radar: StorybookData.radar,
            color: StorybookData.orange,
            style: LivelineRadarStyle(range: 0...100, gridLevels: 3, fillOpacity: 0.10, lineWidth: 3, pointSize: 0, showsLabels: false),
            configuration: StorybookData.staticSnapshotConfig(theme: .light, window: 180, suffix: "%")
        )
    }

    static let donutBasic = chart(
        id: .donutBasic,
        group: "Donut",
        title: "Revenue Mix",
        detail: "Categorical composition with an aggregate center value.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            donut: StorybookData.categories,
            color: StorybookData.blue,
            style: LivelineDonutStyle(innerRadiusRatio: 0.58, gapDegrees: 3, colors: StorybookData.segmentColors),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: " k")
        )
    }

    static let donutThin = chart(
        id: .donutThin,
        group: "Donut",
        title: "Thin Ring Breakdown",
        detail: "A thin ring with value-bearing outside labels.",
        background: .white
    ) {
        LivelineChart(
            donut: StorybookData.categories,
            color: StorybookData.violet,
            style: LivelineDonutStyle(innerRadiusRatio: 0.78, gapDegrees: 1, colors: StorybookData.segmentColors, showsLabels: true, showsValues: true),
            configuration: StorybookData.staticSnapshotConfig(theme: .light, window: 180, suffix: " k")
        )
    }

    static let gaugeBasic = chart(
        id: .gaugeBasic,
        group: "Gauge",
        title: "Capacity",
        detail: "A 240-degree radial progress gauge with ticks.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            gauge: 72,
            range: 0...100,
            color: StorybookData.green,
            style: LivelineGaugeStyle(lineWidth: 20, trackOpacity: 0.18),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: "%")
        )
    }

    static let gaugeTarget = chart(
        id: .gaugeTarget,
        group: "Gauge",
        title: "SLA Target",
        detail: "A wide sweep with an explicit target marker.",
        background: .white
    ) {
        LivelineChart(
            gauge: 91.4,
            range: 0...100,
            color: StorybookData.blue,
            style: LivelineGaugeStyle(startAngleDegrees: 180, sweepDegrees: 180, lineWidth: 14, trackOpacity: 0.10, target: 95, showsTicks: false),
            configuration: StorybookData.staticSnapshotConfig(theme: .light, window: 180, suffix: "%")
        )
    }

    static let funnelBasic = chart(
        id: .funnelBasic,
        group: "Funnel",
        title: "Conversion Funnel",
        detail: "Stage widths preserve absolute conversion volume.",
        background: StorybookData.darkBackground
    ) {
        LivelineChart(
            funnel: StorybookData.funnel,
            color: StorybookData.blue,
            style: LivelineFunnelStyle(colors: StorybookData.segmentColors),
            configuration: StorybookData.staticSnapshotConfig(theme: .dark, window: 180, suffix: "")
        )
    }

    static let funnelCompact = chart(
        id: .funnelCompact,
        group: "Funnel",
        title: "Compact Stages",
        detail: "Tightly spaced square stages with labels only.",
        background: .white
    ) {
        LivelineChart(
            funnel: StorybookData.funnel,
            color: StorybookData.orange,
            style: LivelineFunnelStyle(
                maximumWidthRatio: 0.76,
                minimumWidthRatio: 0.24,
                spacing: 1,
                cornerRadius: 0,
                colors: [StorybookData.orange, StorybookData.red],
                showsLabels: true,
                showsValues: false
            ),
            configuration: StorybookData.staticSnapshotConfig(theme: .light, window: 180, suffix: "")
        )
    }
}
