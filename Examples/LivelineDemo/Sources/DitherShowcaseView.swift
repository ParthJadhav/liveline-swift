import Liveline
import SwiftUI

struct DitherShowcaseView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private let linePoints = StorybookData.points(.normal, count: 140)

    var body: some View {
        ZStack {
            Color(red: 248 / 255, green: 249 / 255, blue: 251 / 255)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("DITHER / LIVELINE")
                            .font(.title2.weight(.bold).monospaced())
                            .foregroundStyle(Color.black.opacity(0.88))
                        Text("Textured fills · crisp defining lines")
                            .font(.caption.weight(.medium).monospaced())
                            .foregroundStyle(Color.black.opacity(0.5))
                    }

                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 250, maximum: 520), spacing: 10),
                        ],
                        spacing: 10
                    ) {
                        panel("LINE · GRADIENT", id: "line") {
                            LivelineChart(
                                data: linePoints,
                                value: linePoints.last?.value ?? 0,
                                color: StorybookData.blue,
                                configuration: config(variant: .gradient, bloom: .aura, window: 100)
                            )
                        }

                        panel("BAR · HATCHED", id: "bar") {
                            LivelineChart(
                                bars: StorybookData.bars(signed: false),
                                color: StorybookData.violet,
                                configuration: config(variant: .hatched, bloom: .high, window: 180)
                            )
                        }

                        panel("DONUT · DOTTED", id: "donut") {
                            LivelineChart(
                                donut: StorybookData.categories,
                                color: StorybookData.orange,
                                style: LivelineDonutStyle(showsLabels: false),
                                configuration: config(variant: .dotted, bloom: .low, window: 30)
                            )
                        }

                        panel("RADAR · GRADIENT", id: "radar") {
                            LivelineChart(
                                radar: StorybookData.radar,
                                color: StorybookData.cyan,
                                configuration: config(variant: .gradient, bloom: .aura, window: 30)
                            )
                        }
                    }
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("dither-showcase-scroll")
        }
        .preferredColorScheme(.light)
    }

    private func config(
        variant: LivelineDitherVariant,
        bloom: LivelineDitherBloom,
        window: TimeInterval
    ) -> LivelineChartConfiguration {
        LivelineChartConfiguration(
            theme: .light,
            style: .dither(
                LivelineDitherStyle(
                    variant: variant,
                    bloom: bloom,
                    cellSize: 2,
                    sparkleDensity: 0.026
                )
            ),
            window: window,
            grid: false,
            badge: false,
            fill: true,
            pulse: false,
            endpointDecorations: false,
            fadeEffects: true,
            scrub: true,
            padding: LivelinePadding(top: 7, right: 7, bottom: 7, left: 7)
        )
    }

    private func panel<Content: View>(
        _ title: String,
        id: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2.weight(.semibold).monospaced())
                .foregroundStyle(Color.black.opacity(0.68))
                .accessibilityIdentifier("dither-panel-title-\(id)")
            content()
                .frame(height: verticalSizeClass == .compact ? 140 : 196)
        }
        .padding(9)
        .background(Color.white)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
