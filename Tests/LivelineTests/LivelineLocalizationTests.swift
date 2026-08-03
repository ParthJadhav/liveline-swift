import Foundation
import XCTest
@testable import Liveline

final class LivelineLocalizationTests: XCTestCase {

    // MARK: - Deterministic formatters

    /// The `fixed` pair is what snapshot renders and the CLI depend on, so it
    /// is pinned against the exact expressions it replaced.
    func testFixedFormattersReproducePreviousOutputByteForByte() {
        let legacyFormatter = DateFormatter()
        legacyFormatter.locale = Locale(identifier: "en_US_POSIX")
        legacyFormatter.dateFormat = "HH:mm:ss"

        for value in [0, 1234.5678, -9876.54321, 0.005, -0.004, 1e9] as [Double] {
            XCTAssertEqual(
                LivelineFormatters.fixedValue(value),
                String(format: "%.2f", value)
            )
        }

        for time in [0, 1, 1_700_000_000, 1_700_086_399.75] as [TimeInterval] {
            XCTAssertEqual(
                LivelineFormatters.fixedTime(time),
                legacyFormatter.string(from: Date(timeIntervalSince1970: time))
            )
        }

        XCTAssertEqual(LivelineFormatters.fixedValue(1234.5678), "1234.57")
        XCTAssertFalse(LivelineFormatters.fixedValue(1_000_000).contains(","))
    }

    /// The public defaults must keep pointing at the deterministic pair, or
    /// every chart rendered on a non-US machine would drift.
    func testDefaultFormattersRemainTheFixedOnes() {
        for value in [0, 1234.5678, -9876.54321] as [Double] {
            XCTAssertEqual(LivelineFormatters.value(value), LivelineFormatters.fixedValue(value))
        }
        for time in [0, 1_700_000_000] as [TimeInterval] {
            XCTAssertEqual(LivelineFormatters.time(time), LivelineFormatters.fixedTime(time))
        }

        let configuration = LivelineChartConfiguration()
        XCTAssertEqual(configuration.formatValue(1234.5678), "1234.57")
        XCTAssertEqual(
            configuration.formatTime(1_700_000_000),
            LivelineFormatters.fixedTime(1_700_000_000)
        )
    }

    // MARK: - Locale-aware formatters

    func testLocalizedValueFollowsTheSuppliedLocale() {
        XCTAssertEqual(
            LivelineFormatters.localizedValue(1234.5678, locale: Locale(identifier: "en_US")),
            "1,234.57"
        )
        XCTAssertEqual(
            LivelineFormatters.localizedValue(1234.5678, locale: Locale(identifier: "de_DE")),
            "1.234,57"
        )
        XCTAssertEqual(
            LivelineFormatters.localizedValue(-0.5, locale: Locale(identifier: "de_DE")),
            "-0,50"
        )
    }

    func testLocalizedTimeFollowsTheLocaleHourCycle() {
        // 2023-11-14 22:13:20 UTC.
        let time: TimeInterval = 1_700_000_000
        let twentyFourHour = LivelineFormatters.localizedTime(time, locale: Locale(identifier: "en_GB"))
        let twelveHour = LivelineFormatters.localizedTime(time, locale: Locale(identifier: "en_US"))

        // Only the hour field differs between the two, so compare the parts
        // that the calendar fixes: minutes and seconds are stable everywhere.
        XCTAssertTrue(twentyFourHour.contains(":20"), twentyFourHour)
        XCTAssertTrue(twelveHour.contains(":20"), twelveHour)
        XCTAssertFalse(twentyFourHour.uppercased().contains("AM"), twentyFourHour)
        XCTAssertFalse(twentyFourHour.uppercased().contains("PM"), twentyFourHour)
        XCTAssertNotEqual(twentyFourHour, twelveHour)
        XCTAssertNotEqual(twelveHour, LivelineFormatters.fixedTime(time))
    }

    // MARK: - Orderbook currency

    func testOrderSizeKeepsDollarDefaultAndAcceptsAnOverride() {
        XCTAssertEqual(LivelineRenderer.formatOrderSize(12.4), "$12")
        XCTAssertEqual(LivelineRenderer.formatOrderSize(12.4, currencySymbol: "€"), "€12")
        XCTAssertEqual(LivelineRenderer.formatOrderSize(0.25, currencySymbol: "¥"), "¥0.25")
        XCTAssertEqual(
            LivelineFormatters.currencySymbol(for: Locale(identifier: "de_DE")),
            "€"
        )
    }

    // MARK: - Localized strings

    /// Liveline ships no translations, so every key must fall through to its
    /// English default. This is the guard that keeps the existing VoiceOver
    /// and tooltip expectations honest.
    func testEnglishStringsFallBackToTheirDefaults() {
        XCTAssertEqual(LivelineStrings.chartKindLine, "Line chart")
        XCTAssertEqual(LivelineStrings.chartKindSeries, "Multi-series chart")
        XCTAssertEqual(LivelineStrings.labelValue, "Value")
        XCTAssertEqual(LivelineStrings.labelGaugeValue, "Gauge value")
        XCTAssertEqual(LivelineStrings.accessibilityHintAdjustable, "Adjust to inspect data points.")
        XCTAssertEqual(LivelineStrings.controlSeriesHintLocked, "At least one series must remain visible")
        XCTAssertEqual(LivelineLocalizedDefaults.emptyText, "No data to display")
        XCTAssertEqual(LivelineChartConfiguration().emptyText, "No data to display")
    }

    /// Positional format strings are the part a translator can reorder, so the
    /// argument wiring is pinned rather than the English wording alone.
    func testFormatStringsSubstituteTheirArgumentsInOrder() {
        XCTAssertEqual(
            String(format: LivelineStrings.accessibilityEntryFormat, "T1", "10", 1, 2),
            "T1, 10, 1 of 2"
        )
        XCTAssertEqual(
            String(format: LivelineStrings.accessibilityCountOtherFormat, 2000),
            "2000 data points"
        )
        XCTAssertEqual(
            String(format: LivelineStrings.accessibilityGaugeValueFormat, "5", "0", "10"),
            "5, range 0 to 10"
        )
        XCTAssertEqual(
            String(format: LivelineStrings.accessibilityCandleValueFormat, "1", "2", "3", "4"),
            "Open 1, high 2, low 3, close 4"
        )
        XCTAssertEqual(String(format: LivelineStrings.labelRowFormat, 3), "Row 3")
        XCTAssertEqual(String(format: LivelineStrings.labelSeriesFormat, 2), "Series 2")
    }
}
