import SwiftUI
import UIKit

struct ChartShowcaseView: View {
    private enum Phase {
        case intro
        case charts
        case outro
    }

    @State private var phase: Phase = .intro
    @State private var sceneIndex = 0
    @State private var reveal = 0.0
    @State private var introVisible = false
    @State private var outroVisible = false
    @State private var started = false

    private let scenes = ChartShowcaseScene.all

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ChartShowcaseBackdrop()

                Group {
                    switch phase {
                    case .intro:
                        intro
                    case .charts:
                        chartScene(in: proxy.size)
                    case .outro:
                        outro
                    }
                }
                .padding(.horizontal, 64)
                .padding(.vertical, 28)
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear(perform: requestLandscape)
        .task {
            guard !started else { return }
            started = true
            await playShowcase()
        }
    }

    private var intro: some View {
        HStack(spacing: 46) {
            VStack(alignment: .leading, spacing: 13) {
                Text("LIVELINE / SWIFTUI")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(2.2)
                    .foregroundStyle(.cyan)

                Text("18 new ways\nto see your data.")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineSpacing(-2)

                Text("Native Canvas renderers. Typed customization.\nBuilt for motion from the first frame.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineSpacing(4)
            }
            .frame(maxWidth: 390, alignment: .leading)
            .offset(x: introVisible ? 0 : -28)
            .opacity(introVisible ? 1 : 0)

            VStack(alignment: .leading, spacing: 10) {
                showcasePillRow(["BAR", "RANGE", "SCATTER", "STEP"])
                showcasePillRow(["LOLLIPOP", "BUBBLE", "BOX PLOT"])
                showcasePillRow(["WATERFALL", "ERROR BAR", "DUMBBELL"])
                showcasePillRow(["STACKS", "TIMELINE", "HEATMAP"])
                showcasePillRow(["RADAR", "DONUT", "GAUGE", "FUNNEL"])
            }
            .scaleEffect(introVisible ? 1 : 0.9, anchor: .leading)
            .opacity(introVisible ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func showcasePillRow(_ labels: [String]) -> some View {
        HStack(spacing: 8) {
            ForEach(labels, id: \.self) { label in
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.82))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(.white.opacity(0.07))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(.white.opacity(0.10), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private func chartScene(in size: CGSize) -> some View {
        let scene = scenes[sceneIndex]
        if let scenario = StorybookCatalog.scenario(id: scene.scenarioID) {
            HStack(spacing: 30) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(scene.accent)
                            .frame(width: 7, height: 7)
                        Text(String(format: "%02d / %02d", sceneIndex + 1, scenes.count))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(1.4)
                            .foregroundStyle(.white.opacity(0.48))
                    }

                    Text(scene.family)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.76)

                    Text(scenario.title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(scene.accent)

                    Text(scenario.detail)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 4)

                    Text(scene.caption)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(scene.accent.opacity(0.14))
                        .clipShape(Capsule())

                    HStack(spacing: 4) {
                        ForEach(scenes.indices, id: \.self) { index in
                            Capsule()
                                .fill(index == sceneIndex ? scene.accent : .white.opacity(0.12))
                                .frame(width: index == sceneIndex ? 18 : 5, height: 4)
                        }
                    }
                }
                .frame(width: min(250, size.width * 0.29), alignment: .leading)
                .padding(.vertical, 8)
                .offset(x: 18 * (1 - reveal))
                .opacity(0.35 + 0.65 * reveal)

                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(scene.accent)
                            .frame(width: 7, height: 7)
                        Text(scenario.id)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.50))
                        Spacer()
                        Text("LIVE CANVAS")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.34))
                    }
                    .padding(.horizontal, 15)
                    .frame(height: 34)
                    .background(.white.opacity(0.045))

                    ZStack {
                        scenario.background
                        scenario.makeView()
                            .id(scenario.id)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: min(322, size.height - 48))
                .background(Color(red: 10 / 255, green: 10 / 255, blue: 10 / 255))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.11), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.34), radius: 24, y: 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var outro: some View {
        VStack(spacing: 14) {
            Text("18 CHARTS / 36 VARIANTS")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.cyan)

            Text("One native SwiftUI canvas.")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Composable data models  ·  Custom styles  ·  Smooth motion")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))

            Text("LIVELINE SWIFT")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.74))
                .padding(.top, 20)
        }
        .scaleEffect(outroVisible ? 1 : 0.92)
        .opacity(outroVisible ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @MainActor
    private func playShowcase() async {
        await pause(1.65)
        withAnimation(.spring(response: 0.85, dampingFraction: 0.82)) {
            introVisible = true
        }
        await pause(2.2)

        withAnimation(.easeInOut(duration: 0.35)) {
            introVisible = false
        }
        await pause(0.35)
        phase = .charts

        for index in scenes.indices {
            sceneIndex = index
            reveal = 0
            await pause(0.12)
            withAnimation(.easeOut(duration: 0.72)) {
                reveal = 1
            }
            await pause(1.18)
            withAnimation(.easeIn(duration: 0.20)) {
                reveal = 0
            }
            await pause(0.24)
        }

        withAnimation(.easeInOut(duration: 0.36)) {
            phase = .outro
        }
        await pause(0.08)
        withAnimation(.spring(response: 0.8, dampingFraction: 0.84)) {
            outroVisible = true
        }
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    private func requestLandscape() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first
            else { return }

            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
        }
    }
}

private struct ChartShowcaseBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 7 / 255, green: 11 / 255, blue: 20 / 255),
                    Color(red: 10 / 255, green: 18 / 255, blue: 31 / 255),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Canvas { context, size in
                var grid = Path()
                for x in stride(from: 0.0, through: size.width, by: 44) {
                    grid.move(to: CGPoint(x: x, y: 0))
                    grid.addLine(to: CGPoint(x: x, y: size.height))
                }
                for y in stride(from: 0.0, through: size.height, by: 44) {
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(grid, with: .color(.white.opacity(0.025)), lineWidth: 0.5)
            }

            RadialGradient(
                colors: [.blue.opacity(0.14), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 430
            )
        }
    }
}

private struct ChartShowcaseScene {
    let family: String
    let scenarioID: String
    let caption: String
    let accent: Color

    static let all: [ChartShowcaseScene] = [
        .init(family: "Bar", scenarioID: "bar-basic", caption: "ROUNDED BUCKETS", accent: StorybookData.teal),
        .init(family: "Range Band", scenarioID: "range-basic", caption: "LOWER + UPPER", accent: StorybookData.indigo),
        .init(family: "Scatter", scenarioID: "scatter-basic", caption: "SYMBOLS + OUTLINES", accent: StorybookData.violet),
        .init(family: "Step", scenarioID: "step-basic", caption: "DISCRETE LEVELS", accent: StorybookData.cyan),
        .init(family: "Lollipop", scenarioID: "lollipop-basic", caption: "SIGNED EVENTS", accent: StorybookData.green),
        .init(family: "Bubble", scenarioID: "bubble-basic", caption: "MAGNITUDE SCALE", accent: StorybookData.violet),
        .init(family: "Box Plot", scenarioID: "boxplot-basic", caption: "FIVE-NUMBER SUMMARY", accent: StorybookData.indigo),
        .init(family: "Waterfall", scenarioID: "waterfall-basic", caption: "CUMULATIVE CHANGE", accent: StorybookData.green),
        .init(family: "Error Bar", scenarioID: "errorbar-basic", caption: "UNCERTAINTY BOUNDS", accent: StorybookData.cyan),
        .init(family: "Dumbbell", scenarioID: "dumbbell-basic", caption: "BEFORE + AFTER", accent: StorybookData.green),
        .init(family: "Stacked Bar", scenarioID: "stackedbar-basic", caption: "SEGMENT TOTALS", accent: StorybookData.blue),
        .init(family: "Stacked Area", scenarioID: "stackedarea-basic", caption: "LAYERED VOLUME", accent: StorybookData.blue),
        .init(family: "Timeline", scenarioID: "timeline-basic", caption: "MULTI-LANE INTERVALS", accent: StorybookData.cyan),
        .init(family: "Heatmap", scenarioID: "heatmap-basic", caption: "TIME × CATEGORY", accent: StorybookData.violet),
        .init(family: "Radar", scenarioID: "radar-basic", caption: "RADIAL PROFILE", accent: StorybookData.cyan),
        .init(family: "Donut", scenarioID: "donut-basic", caption: "CATEGORICAL MIX", accent: StorybookData.blue),
        .init(family: "Gauge", scenarioID: "gauge-basic", caption: "SWEEP + TARGETS", accent: StorybookData.green),
        .init(family: "Funnel", scenarioID: "funnel-basic", caption: "STAGE CONVERSION", accent: StorybookData.blue),
    ]
}
