@_spi(LivelineSnapshotTesting) import Liveline
import SwiftUI

struct StorybookGalleryView: View {
    @State private var showsDitherExamples = false

    var body: some View {
        NavigationStack {
            Group {
                if showsDitherExamples {
                    DitherShowcaseView()
                        .transition(.opacity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 22) {
                            ForEach(StorybookCatalog.groups, id: \.name) { group in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(group.name)
                                        .font(.headline)
                                        .padding(.horizontal, 16)

                                    ForEach(group.scenarios) { scenario in
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
                        }
                        .padding(.vertical, 16)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showsDitherExamples)
            .navigationTitle(showsDitherExamples ? "Dither" : "Storybook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 6) {
                        Text("Dither")
                            .font(.caption.weight(.medium))
                        Toggle("Dither examples", isOn: $showsDitherExamples)
                            .labelsHidden()
                            .accessibilityIdentifier("storybook-dither-toggle")
                    }
                }
            }
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
