import Liveline
import SwiftUI

struct ContentView: View {
    private let stackedGestureTests = CommandLine.arguments.contains("-stacked-gesture-tests")
    private let liveMarketTimerTests = CommandLine.arguments.contains("-live-market-timer-tests")
    private let storybookScrollTests = CommandLine.arguments.contains("-storybook-scroll-tests")
    private let ditherShowcase = StorybookLaunch.ditherShowcaseFromArguments()
    private let chartShowcase = StorybookLaunch.chartShowcaseFromArguments()
    private let scenarioLaunch = StorybookLaunch.scenarioLaunchFromArguments()
    private let chartOnly = StorybookLaunch.chartOnlyFromArguments()

    var body: some View {
        if stackedGestureTests {
            StackedChartGestureTestView()
        } else if liveMarketTimerTests {
            DemoMarketTimerTestView()
        } else if storybookScrollTests {
            StorybookGalleryView(showsScrollDiagnostics: true)
        } else if ditherShowcase {
            DitherShowcaseView()
        } else if chartShowcase {
            ChartShowcaseView()
        } else {
            switch scenarioLaunch {
            case .none:
                TabView {
                    LiveDemoView()
                        .tabItem {
                            Label("Live", systemImage: "chart.xyaxis.line")
                        }

                    StorybookGalleryView()
                        .tabItem {
                            Label("Storybook", systemImage: "square.grid.2x2")
                        }
                }
            case let .scenario(scenario):
                StorybookScenarioScreen(scenario: scenario, chrome: false, chartOnly: chartOnly)
            case let .invalid(message):
                StorybookLaunchErrorView(message: message)
            }
        }
    }
}

struct LiveDemoView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var market = DemoMarket()
    @State private var lineWindow: TimeInterval = 60
    @State private var candleLineMode = false
    @State private var isVisible = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    liveLine
                    candles
                    multiSeries
                }
                .padding(16)
            }
            .accessibilityIdentifier("live-demo-scroll")
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Liveline")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            isVisible = true
            if scenePhase == .active {
                market.start()
            }
        }
        .onDisappear {
            isVisible = false
            market.stop()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active, isVisible {
                market.start()
            } else {
                market.stop()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("$\(market.latest, specifier: "%.2f")")
                    .font(.system(size: 28, weight: .semibold, design: .monospaced))
                    .accessibilityIdentifier("live-market-price")
                    .accessibilityValue(Text("Update \(market.updateCount)"))
                Text("BTC-USD")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Date(), style: .time)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private var liveLine: some View {
        chartPanel(title: "Live", subtitle: "Line") {
            LivelineChart(
                data: market.ticks,
                value: market.latest,
                color: .blue,
                configuration: LivelineChartConfiguration(
                    theme: .dark,
                    window: lineWindow,
                    windows: [
                        LivelineWindowOption(label: "30s", seconds: 30),
                        LivelineWindowOption(label: "1m", seconds: 60),
                        LivelineWindowOption(label: "3m", seconds: 180),
                    ],
                    showValue: true,
                    valueMomentumColor: true,
                    degen: LivelineDegenOptions(scale: 0.8, downMomentum: true),
                    orderbook: market.orderbook,
                    referenceLine: LivelineReferenceLine(value: 42_000, label: "Open"),
                    formatValue: money,
                    onWindowChange: { lineWindow = $0 }
                )
            )
            .frame(height: 260)
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
            .background(Color(red: 10 / 255, green: 10 / 255, blue: 10 / 255))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var candles: some View {
        chartPanel(title: "OHLC", subtitle: candleLineMode ? "Line" : "Candles") {
            LivelineChart(
                data: market.ticks,
                value: market.latest,
                candles: market.candles,
                candleWidth: 30,
                liveCandle: market.liveCandle,
                lineData: market.ticks,
                lineValue: market.latest,
                color: Color(red: 247 / 255, green: 147 / 255, blue: 26 / 255),
                configuration: LivelineChartConfiguration(
                    theme: .dark,
                    window: 240,
                    windows: [
                        LivelineWindowOption(label: "2m", seconds: 120),
                        LivelineWindowOption(label: "4m", seconds: 240),
                        LivelineWindowOption(label: "8m", seconds: 480),
                    ],
                    showValue: true,
                    formatValue: money,
                    lineMode: candleLineMode,
                    onModeChange: { candleLineMode = $0 == .line }
                )
            )
            .frame(height: 280)
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
            .background(Color(red: 10 / 255, green: 10 / 255, blue: 10 / 255))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var multiSeries: some View {
        chartPanel(title: "Spread", subtitle: "3 series") {
            LivelineChart(
                series: market.spread,
                configuration: LivelineChartConfiguration(
                    theme: colorScheme == .dark ? .dark : .light,
                    window: 180,
                    windows: [
                        LivelineWindowOption(label: "1m", seconds: 60),
                        LivelineWindowOption(label: "3m", seconds: 180),
                        LivelineWindowOption(label: "5m", seconds: 300),
                    ],
                    lineWidth: 2,
                    formatValue: money
                )
            )
            .frame(height: 260)
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityIdentifier("live-spread-chart")
            .accessibilityValue(Text(colorScheme == .dark ? "Dark theme" : "Light theme"))
        }
    }

    private func chartPanel<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            content()
        }
    }

    private func money(_ value: Double) -> String {
        "$" + value.formatted(.number.precision(.fractionLength(2)))
    }
}
