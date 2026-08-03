import SwiftUI
import XCTest
@testable import Liveline

final class LivelineLegendTests: XCTestCase {
    private let points = [
        LivelinePoint(time: 1, value: 4),
        LivelinePoint(time: 2, value: 7),
    ]

    func testSeriesItemsKeepIdentityColorAndFallBackToTheIdentifier() {
        let items = LivelineLegendItem.items(series: [
            LivelineSeries(id: "alpha", data: points, value: 7, color: .blue, label: "Alpha"),
            LivelineSeries(id: "beta", data: points, value: 7, color: .orange),
        ])

        XCTAssertEqual(items.map(\.id), ["alpha", "beta"])
        XCTAssertEqual(items.map(\.label), ["Alpha", "beta"])
        XCTAssertEqual(items.map(\.color), [.blue, .orange])
    }

    func testDonutItemsUseTheStylePaletteWhenOneIsSupplied() {
        let categories = [
            LivelineCategoryValue(id: "a", label: "Alpha", value: 6),
            LivelineCategoryValue(id: "b", label: "Beta", value: 4),
            LivelineCategoryValue(id: "c", label: "Gamma", value: 2),
        ]
        let items = LivelineLegendItem.items(
            donut: categories,
            style: LivelineDonutStyle(colors: [.red, .green])
        )

        XCTAssertEqual(items.map(\.id), ["a", "b", "c"])
        XCTAssertEqual(items.map(\.label), ["Alpha", "Beta", "Gamma"])
        // The palette wraps, exactly as the donut renderer wraps it.
        XCTAssertEqual(items.map(\.color), [.red, .green, .red])
    }

    func testDonutItemsFallBackToAccentThenTheBuiltInPalette() {
        let items = LivelineLegendItem.items(
            donut: [
                LivelineCategoryValue(id: "a", label: "Alpha", value: 6),
                LivelineCategoryValue(id: "b", label: "Beta", value: 4),
            ],
            accent: .purple
        )

        XCTAssertEqual(items.first?.color, .purple)
        XCTAssertEqual(items.last?.color, LivelineRenderer.extendedDefaultColors[1])
    }

    func testFunnelAndStackedItemsDeriveLabels() {
        let funnel = LivelineLegendItem.items(funnel: [
            LivelineCategoryValue(id: "visit", label: "Visits", value: 100),
            LivelineCategoryValue(id: "buy", label: "Purchases", value: 10),
        ])
        XCTAssertEqual(funnel.map(\.label), ["Visits", "Purchases"])

        let stacked = LivelineLegendItem.items(stacked: ["Cash", "Credit"], colors: [.mint, .pink])
        XCTAssertEqual(stacked.map(\.label), ["Cash", "Credit"])
        XCTAssertEqual(stacked.map(\.color), [.mint, .pink])
        XCTAssertEqual(Set(stacked.map(\.id)).count, 2)
    }

    func testItemIdentityDefaultsToTheLabel() {
        let item = LivelineLegendItem(label: "Alpha", color: .blue)
        XCTAssertEqual(item.id, "Alpha")
    }

    #if os(macOS)
    @MainActor
    func testLegendRendersInBothAxes() throws {
        let items = LivelineLegendItem.items(series: [
            LivelineSeries(id: "alpha", data: points, value: 7, color: .blue, label: "Alpha"),
            LivelineSeries(id: "beta", data: points, value: 7, color: .orange, label: "Beta"),
        ])

        for axis in LivelineLegendAxis.allCases {
            let legend = LivelineLegend(items: items, axis: axis, theme: .dark)
                .frame(width: 200, height: 80)
            let renderer = ImageRenderer(content: legend)
            renderer.proposedSize = ProposedViewSize(width: 200, height: 80)
            renderer.scale = 1
            let image = try XCTUnwrap(renderer.nsImage, "Failed to render \(axis) legend")
            XCTAssertGreaterThan(image.tiffRepresentation?.count ?? 0, 100)
        }
    }
    #endif
}
