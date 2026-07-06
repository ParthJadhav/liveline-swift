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
    ],
    targets: [
        .target(
            name: "Liveline"
        ),
        .testTarget(
            name: "LivelineTests",
            dependencies: ["Liveline"]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
