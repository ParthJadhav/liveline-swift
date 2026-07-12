import Liveline
import SwiftUI

struct DitherShowcaseView: View {
    private let linePoints = StorybookData.points(.normal, count: 140)

    var body: some View {
        ZStack {
            StorybookData.darkBackground.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("DITHER / LIVELINE")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("One animated style · every native chart")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.52))
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    panel("LINE · GRADIENT") {
                        LivelineChart(
                            data: linePoints,
                            value: linePoints.last?.value ?? 0,
                            color: StorybookData.blue,
                            configuration: config(variant: .gradient, bloom: .aura, window: 100)
                        )
                    }

                    panel("BAR · HATCHED") {
                        LivelineChart(
                            bars: StorybookData.bars(signed: false),
                            color: StorybookData.violet,
                            configuration: config(variant: .hatched, bloom: .high, window: 180)
                        )
                    }

                    panel("DONUT · DOTTED") {
                        LivelineChart(
                            donut: StorybookData.categories,
                            color: StorybookData.orange,
                            style: LivelineDonutStyle(showsLabels: false),
                            configuration: config(variant: .dotted, bloom: .low, window: 30)
                        )
                    }

                    panel("RADAR · GRADIENT") {
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
        .preferredColorScheme(.dark)
    }

    private func config(
        variant: LivelineDitherVariant,
        bloom: LivelineDitherBloom,
        window: TimeInterval
    ) -> LivelineChartConfiguration {
        LivelineChartConfiguration(
            theme: .dark,
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
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.54))
            content()
                .frame(height: 196)
        }
        .padding(9)
        .background(Color.white.opacity(0.035))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
