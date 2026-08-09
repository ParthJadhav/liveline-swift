@_spi(LivelineSnapshotTesting) import Liveline
import SwiftUI
import UIKit

struct StorybookGalleryView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showsDitherExamples = false
    @State private var isScrolling = false
    @State private var scrollIdleTask: Task<Void, Never>?
    @State private var scrollPauseCount = 0
    @State private var query: String
    @State private var selectedGroup: String?

    var showsScrollDiagnostics = false

    init(showsScrollDiagnostics: Bool = false) {
        self.showsScrollDiagnostics = showsScrollDiagnostics
        _query = State(initialValue: StorybookLaunch.storybookQueryFromArguments() ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ditherControls
                if showsScrollDiagnostics {
                    scrollDiagnostics
                }
                galleryScroll
            }
            .navigationTitle("Storybook")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $query, prompt: "Charts, features, or scenario IDs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("All chart families") {
                            selectedGroup = nil
                        }
                        Divider()
                        ForEach(StorybookCatalog.groups, id: \.name) { group in
                            Button(group.name) {
                                selectedGroup = group.name
                            }
                        }
                    } label: {
                        Label(selectedGroup ?? "All families", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityIdentifier("storybook-family-filter")
                }
            }
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
        .onDisappear {
            scrollIdleTask?.cancel()
            scrollIdleTask = nil
            setScrolling(false)
        }
    }

    private var ditherControls: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Label("Dither style", systemImage: "sparkles")
                    .font(.subheadline.weight(.medium))
                Text("\(filteredScenarioCount) of \(StorybookCatalog.all.count) scenarios")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("Dither style", isOn: $showsDitherExamples)
                .labelsHidden()
                .accessibilityLabel("Dither style")
                .accessibilityIdentifier("storybook-dither-toggle")
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .background(.thinMaterial)
    }

    private var scrollDiagnostics: some View {
        HStack(spacing: 8) {
            Text(String(scrollPauseCount))
                .accessibilityIdentifier("storybook-scroll-pause-count")
            Text(isScrolling ? "true" : "false")
                .accessibilityIdentifier("storybook-scroll-active")
            Text(showsDitherExamples && !isScrolling ? "true" : "false")
                .accessibilityIdentifier("storybook-dither-animated")
        }
        .font(.caption2.monospacedDigit())
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, 8)
        .background(.thinMaterial)
        .allowsHitTesting(false)
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
                .simultaneousGesture(legacyScrollGesture)
        }
        #else
        scrollContent
            .simultaneousGesture(legacyScrollGesture)
        #endif
    }

    private var scrollContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                if filteredGroups.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No matching scenarios")
                            .font(.headline)
                        Text("Try another chart name, feature, or scenario ID.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 72)
                }
                ForEach(filteredGroups, id: \.name) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(group.name)
                            .font(.title3.weight(.semibold))
                            .padding(.horizontal, 16)

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .regular ? 340 : 280), spacing: 16)],
                            spacing: 16
                        ) {
                            ForEach(group.scenarios) { scenario in
                                NavigationLink {
                                    StorybookScenarioScreen(scenario: scenario)
                                } label: {
                                    StorybookCard(scenario: scenario)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .accessibilityIdentifier("storybook-scroll")
    }

    private var filteredGroups: [(name: String, scenarios: [StorybookScenario])] {
        StorybookCatalog.groups.compactMap { group in
            guard selectedGroup == nil || selectedGroup == group.name else { return nil }
            let scenarios = group.scenarios.filter { scenario in
                query.isEmpty || [scenario.title, scenario.detail, scenario.id, scenario.group]
                    .contains { $0.localizedCaseInsensitiveContains(query) }
            }
            return scenarios.isEmpty ? nil : (group.name, scenarios)
        }
    }

    private var filteredScenarioCount: Int {
        filteredGroups.reduce(0) { $0 + $1.scenarios.count }
    }

    private var legacyScrollGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { _ in
                setScrolling(true)
                scheduleLegacyScrollIdle(afterNanoseconds: 1_000_000_000)
            }
            .onEnded { _ in
                scheduleLegacyScrollIdle(afterNanoseconds: 500_000_000)
            }
    }

    private func scheduleLegacyScrollIdle(afterNanoseconds delay: UInt64) {
        scrollIdleTask?.cancel()
        scrollIdleTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            scrollIdleTask = nil
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

struct StorybookCard: View {
    let scenario: StorybookScenario

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(scenario.title)
                    .font(.headline)
                Spacer()
                Text(scenario.id)
                    .font(.caption2.weight(.medium).monospaced())
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }

            Text(scenario.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            scenario.makeView()
                .frame(height: 180)
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
                .background(scenario.background)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("storybook-card-\(scenario.id)")
        .accessibilityHint("Opens an interactive chart preview and Swift code")
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
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(scenario.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(scenario.id)
                    .font(.caption.weight(.medium).monospaced())
                    .foregroundStyle(.secondary)
            }

            chart

            Label(scenario.interactionSummary, systemImage: "hand.draw")
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("SwiftUI example")
                        .font(.headline)
                    Spacer()
                    ShareLink(item: scenario.codeSample) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityLabel("Share SwiftUI example")
                    Button {
                        UIPasteboard.general.string = scenario.codeSample
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityLabel("Copy SwiftUI example")
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    Text(scenario.codeSample)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .padding(14)
                }
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var chart: some View {
        scenario.makeView()
            .livelineSnapshotElapsedTime(StorybookLaunch.snapshotElapsedTimeFromArguments())
            .frame(height: scenario.height)
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
            .background(scenario.background)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityIdentifier("storybook-\(scenario.id)")
    }
}
