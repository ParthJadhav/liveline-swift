import Liveline
import SwiftUI

struct StorybookLaunch {
    static func ditherShowcaseFromArguments() -> Bool {
        ProcessInfo.processInfo.arguments.contains("--dither-showcase")
    }

    static func chartShowcaseFromArguments() -> Bool {
        ProcessInfo.processInfo.arguments.contains("--chart-showcase")
    }

    static func scenarioFromArguments() -> StorybookScenario? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--storybook-scenario"),
              arguments.indices.contains(index + 1)
        else {
            return nil
        }
        return StorybookCatalog.scenario(id: arguments[index + 1])
    }

    static func chartOnlyFromArguments() -> Bool {
        ProcessInfo.processInfo.arguments.contains("--storybook-chart-only")
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
}

struct StorybookScenario: Identifiable {
    let id: String
    let group: String
    let title: String
    let detail: String
    let background: Color
    let height: CGFloat
    let makeView: () -> AnyView
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
