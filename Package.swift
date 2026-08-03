// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Liveline",
    defaultLocalization: "en",
    platforms: [
        // Canvas, TimelineView, and GraphicsContext — the whole rendering
        // surface — are iOS 15 / macOS 12 / watchOS 8, so that is the floor.
        // The few newer APIs the library uses are individually gated:
        // ImageRenderer (chart image export), Layout (the wrapping horizontal
        // legend), and onContinuousHover (pointer inspection) are all
        // iOS 16 / macOS 13 / watchOS 9 behind `@available` or `if #available`.
        //
        // tvOS stays at 16 because `onTapGesture` — which is how the Siri
        // Remote enters and leaves chart inspection — is unavailable before it.
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v16),
        .watchOS(.v8),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "Liveline",
            targets: ["Liveline"]
        ),
        .executable(
            name: "liveline-render",
            targets: ["LivelineRender"]
        ),
    ],
    targets: [
        .target(
            name: "Liveline",
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        ),
        .testTarget(
            name: "LivelineTests",
            dependencies: ["Liveline"]
        ),
        .executableTarget(
            name: "LivelineRender",
            dependencies: ["Liveline"]
        ),
        .testTarget(
            name: "LivelineRenderTests",
            dependencies: ["LivelineRender"]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
