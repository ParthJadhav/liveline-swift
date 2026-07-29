@_spi(LivelineSnapshotTesting) import Liveline
import SwiftUI

struct StorybookGalleryView: View {
    private static let legacyScrollCoordinateSpace = "storybook-gallery-scroll"

    @State private var showsDitherExamples = false
    @State private var isScrolling = false
    @State private var legacyScrollOffset: CGFloat?
    @State private var scrollIdleTask: Task<Void, Never>?
    @State private var scrollPauseCount = 0

    var showsScrollDiagnostics = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ditherControls
                galleryScroll
            }
            .navigationTitle("Storybook")
            .navigationBarTitleDisplayMode(.inline)
        }
        .livelineChartStyle(
            showsDitherExamples
                ? .dither(
                    LivelineDitherStyle(
                        maximumFramesPerSecond: 20,
                        animated: !isScrolling
                    )
                )
                : nil
        )
        .animation(.easeInOut(duration: 0.2), value: showsDitherExamples)
        .overlay(alignment: .topTrailing) {
            if showsScrollDiagnostics {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(scrollPauseCount))
                        .accessibilityIdentifier("storybook-scroll-pause-count")
                    Text(isScrolling ? "true" : "false")
                        .accessibilityIdentifier("storybook-scroll-active")
                    Text(showsDitherExamples && !isScrolling ? "true" : "false")
                        .accessibilityIdentifier("storybook-dither-animated")
                }
                .font(.caption2.monospacedDigit())
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(8)
                .allowsHitTesting(false)
            }
        }
        .onDisappear {
            scrollIdleTask?.cancel()
            scrollIdleTask = nil
            legacyScrollOffset = nil
            setScrolling(false)
        }
    }

    private var ditherControls: some View {
        HStack {
            Label("Dither style", systemImage: "sparkles")
                .font(.subheadline.weight(.medium))
                .accessibilityHidden(true)

            Spacer()

            Toggle("Dither style", isOn: $showsDitherExamples)
                .labelsHidden()
                .accessibilityLabel("Dither style")
                .accessibilityIdentifier("storybook-dither-toggle")
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(.thinMaterial)
    }

    @ViewBuilder
    private var galleryScroll: some View {
        #if compiler(>=6.0)
        if #available(iOS 18.0, *) {
            scrollContent
                .onScrollPhaseChange { _, phase in
                    setScrolling(phase.isScrolling)
                }
        } else {
            scrollContent
                .onPreferenceChange(StorybookScrollOffsetPreferenceKey.self) { offset in
                    legacyScrollOffsetDidChange(offset)
                }
        }
        #else
        scrollContent
            .onPreferenceChange(StorybookScrollOffsetPreferenceKey.self) { offset in
                legacyScrollOffsetDidChange(offset)
            }
        #endif
    }

    private var scrollContent: some View {
        ScrollView {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: StorybookScrollOffsetPreferenceKey.self,
                    value: proxy.frame(in: .named(Self.legacyScrollCoordinateSpace)).minY
                )
            }
            .frame(height: 0)

            LazyVStack(alignment: .leading, spacing: 22) {
                ForEach(StorybookGalleryItem.all) { item in
                    switch item {
                    case let .header(name):
                        Text(name)
                            .font(.headline)
                            .padding(.horizontal, 16)
                    case let .scenario(scenario):
                        NavigationLink {
                            StorybookScenarioScreen(scenario: scenario)
                        } label: {
                            StorybookCard(scenario: scenario)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .coordinateSpace(name: Self.legacyScrollCoordinateSpace)
        .accessibilityIdentifier("storybook-scroll")
    }

    private func legacyScrollOffsetDidChange(_ offset: CGFloat) {
        guard let previousOffset = legacyScrollOffset else {
            legacyScrollOffset = offset
            return
        }
        guard abs(offset - previousOffset) > 0.5 else { return }

        legacyScrollOffset = offset
        setScrolling(true)
        scrollIdleTask?.cancel()
        scrollIdleTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else { return }
            setScrolling(false)
        }
    }

    private func setScrolling(_ value: Bool) {
        if value, !isScrolling {
            scrollPauseCount += 1
        }
        isScrolling = value
    }
}

private struct StorybookScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private enum StorybookGalleryItem: Identifiable {
    case header(String)
    case scenario(StorybookScenario)

    static let all: [StorybookGalleryItem] = StorybookCatalog.groups.flatMap { group in
        [.header(group.name)] + group.scenarios.map(StorybookGalleryItem.scenario)
    }

    var id: String {
        switch self {
        case let .header(name): "header-\(name)"
        case let .scenario(scenario): "scenario-\(scenario.id)"
        }
    }
}

struct StorybookCard: View {
    let scenario: StorybookScenario

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(scenario.title)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text(scenario.id)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Text(scenario.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            scenario.makeView()
                .frame(height: 180)
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
                .background(scenario.background)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct StorybookScenarioScreen: View {
    let scenario: StorybookScenario
    var chrome = true
    var chartOnly = false

    var body: some View {
        Group {
            if chrome {
                ScrollView {
                    content
                        .padding(16)
                }
                .navigationTitle(scenario.title)
                .navigationBarTitleDisplayMode(.inline)
            } else if chartOnly {
                chart
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(Color(uiColor: .systemBackground))
            } else {
                content
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(Color(uiColor: .systemBackground))
            }
        }
        .onAppear {
            StorybookLaunch.recordScenarioReady(scenario.id)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(scenario.title)
                    .font(.system(size: 20, weight: .semibold))
                Text(scenario.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(scenario.id)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            chart
        }
    }

    private var chart: some View {
        scenario.makeView()
            .livelineSnapshotElapsedTime(StorybookLaunch.snapshotElapsedTimeFromArguments())
            .frame(height: scenario.height)
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
            .background(scenario.background)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .circular))
            .accessibilityIdentifier("storybook-\(scenario.id)")
    }
}
