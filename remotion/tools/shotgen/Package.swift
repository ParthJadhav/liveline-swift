// swift-tools-version: 5.9

import PackageDescription

// Generates the chart media this Remotion project plays: the still PNGs in
// Docs/pr-assets and the per-frame clip sequences in remotion/public/clips.
// Both come out of Liveline's own public `LivelineChartImageExporter`, so the
// video shows the shipping renderer rather than a recreation.
let package = Package(
    name: "ShotGen",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: "../../.."),
    ],
    targets: [
        .executableTarget(
            name: "ShotGen",
            dependencies: [.product(name: "Liveline", package: "liveline-swift")]
        ),
    ]
)
