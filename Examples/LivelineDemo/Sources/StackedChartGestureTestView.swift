import Liveline
import SwiftUI

/// A deterministic, observable fixture for validating chart gesture
/// arbitration inside a vertical scroll view.
struct StackedChartGestureTestView: View {
    @State private var scrollOffset: CGFloat = 0
    @State private var hoverUpdateCount = 0
    @State private var hoverClearCount = 0
    @State private var hoverIsActive = false
    @State private var hoverDirectionViolationCount = 0
    @State private var lastHoverTime: TimeInterval?

    private let points: [LivelinePoint] = (0..<120).map { index in
        let progress = Double(index) / 12
        return LivelinePoint(
            time: TimeInterval(index),
            value: 50 + sin(progress) * 12 + Double(index) * 0.08
        )
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                LazyVStack(spacing: 24) {
                    ForEach(0..<5) { index in
                        chart(index: index)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .stackedChartLegacyScrollMetrics()
            }
            .accessibilityIdentifier("stacked-chart-scroll")
            .modifier(StackedChartScrollObserver { offset in
                scrollOffset = max(0, offset)
            })

            diagnostics
        }
        .background(Color(uiColor: .systemBackground))
    }

    private func chart(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chart \(index + 1)")
                .font(.headline)

            LivelineChart(
                data: points,
                value: points.last?.value ?? 0,
                color: index.isMultiple(of: 2) ? .blue : .orange,
                configuration: LivelineChartConfiguration(
                    theme: index.isMultiple(of: 2) ? .light : .dark,
                    window: 120,
                    showValue: false,
                    paused: true,
                    onHover: recordHover
                )
            )
            .frame(height: 220)
            .background(
                index.isMultiple(of: 2)
                    ? Color(uiColor: .secondarySystemBackground)
                    : Color(red: 10 / 255, green: 10 / 255, blue: 10 / 255)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Stacked chart \(index + 1)")
            .accessibilityIdentifier("stacked-chart-\(index)")
        }
    }

    private var diagnostics: some View {
        VStack(alignment: .trailing, spacing: 2) {
            diagnosticText(
                String(format: "%.1f", Double(scrollOffset)),
                identifier: "gesture-scroll-offset"
            )
            diagnosticText(
                String(hoverUpdateCount),
                identifier: "gesture-hover-updates"
            )
            diagnosticText(
                String(hoverClearCount),
                identifier: "gesture-hover-clears"
            )
            diagnosticText(
                hoverIsActive ? "true" : "false",
                identifier: "gesture-hover-active"
            )
            diagnosticText(
                String(hoverDirectionViolationCount),
                identifier: "gesture-hover-direction-violations"
            )
        }
        .font(.caption2.monospacedDigit())
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding(8)
        .allowsHitTesting(false)
    }

    private func diagnosticText(_ value: String, identifier: String) -> some View {
        Text(value)
            .accessibilityIdentifier(identifier)
    }

    private func recordHover(_ hover: LivelineHoverPoint?) {
        guard let hover else {
            if hoverIsActive {
                hoverClearCount += 1
            }
            hoverIsActive = false
            lastHoverTime = nil
            return
        }

        if let lastHoverTime, hover.time < lastHoverTime {
            hoverDirectionViolationCount += 1
        }
        hoverUpdateCount += 1
        hoverIsActive = true
        lastHoverTime = hover.time
    }
}

private struct StackedChartScrollObserver: ViewModifier {
    var onChange: (CGFloat) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.0)
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                onChange(max(0, offset))
            }
        } else {
            content
                .coordinateSpace(name: StackedChartScrollMetrics.coordinateSpace)
                .onPreferenceChange(StackedChartScrollOffsetPreferenceKey.self) { contentY in
                    onChange(max(0, -contentY))
                }
        }
        #else
        content
            .coordinateSpace(name: StackedChartScrollMetrics.coordinateSpace)
            .onPreferenceChange(StackedChartScrollOffsetPreferenceKey.self) { contentY in
                onChange(max(0, -contentY))
            }
        #endif
    }
}

private extension View {
    @ViewBuilder
    func stackedChartLegacyScrollMetrics() -> some View {
        if #available(iOS 18.0, *) {
            self
        } else {
            background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: StackedChartScrollOffsetPreferenceKey.self,
                        value: proxy.frame(
                            in: .named(StackedChartScrollMetrics.coordinateSpace)
                        ).minY
                    )
                }
            }
        }
    }
}

private struct StackedChartScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private enum StackedChartScrollMetrics {
    static let coordinateSpace = "stacked-chart-scroll-coordinate-space"
}
