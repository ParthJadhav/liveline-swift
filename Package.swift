// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Liveline",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16),
        .watchOS(.v9),
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
    ],
    swiftLanguageVersions: [.v5]
)
