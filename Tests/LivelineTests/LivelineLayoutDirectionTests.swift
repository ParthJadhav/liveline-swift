import XCTest
@testable import Liveline

/// Right-to-left support is an explicit coordinate reflection inside
/// `LivelineLayout`, so most of it can be checked without ever drawing a frame.
final class LivelineLayoutDirectionTests: XCTestCase {
    private func layout(isRTL: Bool) -> LivelineLayout {
        LivelineLayout(
            size: CGSize(width: 320, height: 220),
            padding: LivelineResolvedPadding(top: 20, right: 54, bottom: 28, left: 12),
            minValue: 0,
            maxValue: 10,
            leftEdge: 0,
            rightEdge: 10,
            isRTL: isRTL
        )
    }

    func testTimeAxisMirrorsAcrossThePlotInRightToLeft() {
        let ltr = layout(isRTL: false)
        let rtl = layout(isRTL: true)

        for time in stride(from: 0.0, through: 10.0, by: 1.25) {
            let expected = rtl.rightX - (ltr.x(for: time) - ltr.plotLeftX)
            XCTAssertEqual(rtl.x(for: time), expected, accuracy: 0.0001)
        }

        // The newest sample hugs the reading start, the oldest the far edge.
        XCTAssertEqual(rtl.x(for: 10), rtl.plotLeftX, accuracy: 0.0001)
        XCTAssertEqual(rtl.x(for: 0), rtl.rightX, accuracy: 0.0001)
        XCTAssertEqual(rtl.liveEdgeX, rtl.plotLeftX)
        XCTAssertEqual(rtl.pastEdgeX, rtl.rightX)
        XCTAssertEqual(ltr.liveEdgeX, ltr.rightX)
        XCTAssertEqual(rtl.forwardXDirection, -1)
    }

    func testValueAxisIsUnaffectedByDirection() {
        let ltr = layout(isRTL: false)
        let rtl = layout(isRTL: true)
        for value in stride(from: 0.0, through: 10.0, by: 2.5) {
            XCTAssertEqual(rtl.y(for: value), ltr.y(for: value), accuracy: 1e-9)
        }
    }

    func testTimeRoundTripsThroughTheMirroredTransform() {
        let rtl = layout(isRTL: true)
        for time in stride(from: 0.0, through: 10.0, by: 0.75) {
            XCTAssertEqual(rtl.time(for: rtl.x(for: time)), time, accuracy: 1e-6)
        }
        // The reflection is an involution, so applying it twice is the identity.
        for x in stride(from: rtl.plotLeftX, through: rtl.rightX, by: 17) {
            XCTAssertEqual(rtl.mirrored(rtl.mirrored(x)), x, accuracy: 1e-9)
        }
    }

    func testMirroringIsTheIdentityInLeftToRight() {
        let ltr = layout(isRTL: false)
        XCTAssertEqual(ltr.mirrored(CGFloat(123)), 123)
        let rect = CGRect(x: 30, y: 10, width: 40, height: 12)
        XCTAssertEqual(ltr.mirrored(rect), rect)
        XCTAssertEqual(ltr.time(for: ltr.x(for: 4)), 4, accuracy: 1e-9)
    }

    func testResolvedPaddingAndLegendSideFollowTheReadingDirection() {
        let padding = LivelineResolvedPadding(top: 12, right: 54, bottom: 28, left: 12)
        let mirrored = padding.mirroredHorizontally()
        XCTAssertEqual(mirrored.left, padding.right)
        XCTAssertEqual(mirrored.right, padding.left)
        XCTAssertEqual(mirrored.top, padding.top)
        XCTAssertEqual(mirrored.bottom, padding.bottom)

        XCTAssertEqual(LivelineLegendSide.trailing.resolved(isRTL: true), .leading)
        XCTAssertEqual(LivelineLegendSide.leading.resolved(isRTL: true), .trailing)
        XCTAssertEqual(LivelineLegendSide.trailing.resolved(isRTL: false), .trailing)
    }

    func testHoverSelectsTheSameDatumUnderTheFingerInBothDirections() {
        let points = [
            LivelinePoint(time: 1, value: 4),
            LivelinePoint(time: 2, value: 7),
            LivelinePoint(time: 3, value: 5),
        ]
        let content = LivelineChartContent.bars(data: points, style: LivelineBarStyle())
        let configuration = LivelineChartConfiguration(window: 10, scrub: true, paused: true)
        let palette = LivelinePalette.resolve(accent: .blue, mode: .dark, lineWidth: 2)

        func snapshot(isRTL: Bool) -> LivelineInteractionSnapshot {
            let target = layout(isRTL: isRTL)
            let prepared = LivelineChartPreparer.prepare(
                for: content,
                hiddenSeries: [],
                leftEdge: target.leftEdge,
                rightEdge: target.rightEdge,
                config: configuration
            )
            return LivelineInteractionBuilder.snapshot(
                content: content,
                prepared: prepared,
                layout: target,
                palette: palette,
                configuration: configuration,
                hiddenSeries: [],
                behavior: content.semantics().capabilities.hoverBehavior
            )
        }

        for time in [1.0, 2.0, 3.0] {
            let ltrLayout = layout(isRTL: false)
            let rtlLayout = layout(isRTL: true)
            let ltrProbe = CGPoint(x: ltrLayout.x(for: time), y: ltrLayout.y(for: 5))
            let rtlProbe = CGPoint(x: rtlLayout.x(for: time), y: rtlLayout.y(for: 5))
            // The two probes are on opposite halves of the canvas...
            XCTAssertEqual(rtlProbe.x, rtlLayout.mirrored(ltrProbe.x), accuracy: 0.0001)

            // ...and still resolve to the same sample.
            let ltrHover = LivelineHoverResolver.resolveSelection(
                location: ltrProbe,
                snapshot: snapshot(isRTL: false)
            )
            let rtlHover = LivelineHoverResolver.resolveSelection(
                location: rtlProbe,
                snapshot: snapshot(isRTL: true)
            )
            XCTAssertEqual(ltrHover?.hover.time, time)
            XCTAssertEqual(rtlHover?.hover.time, ltrHover?.hover.time)
            XCTAssertEqual(rtlHover?.rows.map(\.value), ltrHover?.rows.map(\.value))
        }
    }

    func testHistogramAndBulletMirrorWhileRadialKindsDoNot() {
        let palette = LivelinePalette.resolve(accent: .blue, mode: .dark, lineWidth: 2)
        let bins = LivelineMath.histogramBins(values: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], binning: .count(4))

        func histogram(isRTL: Bool) -> LivelineHistogramGeometry {
            LivelineRenderer.histogramGeometry(
                bins: bins,
                style: LivelineHistogramStyle(),
                layout: layout(isRTL: isRTL),
                palette: palette,
                reveal: 1
            )
        }

        let ltrBars = histogram(isRTL: false).bars
        let rtlBars = histogram(isRTL: true).bars
        let rtlLayout = layout(isRTL: true)
        XCTAssertEqual(ltrBars.count, rtlBars.count)
        for (ltrBar, rtlBar) in zip(ltrBars, rtlBars) {
            // The lowest bin starts at the reading start, so bin order flips.
            XCTAssertEqual(rtlBar.rect.maxX, rtlLayout.mirrored(ltrBar.rect.minX), accuracy: 0.0001)
            XCTAssertEqual(rtlBar.rect.width, ltrBar.rect.width, accuracy: 0.0001)
            XCTAssertEqual(rtlBar.rect.minY, ltrBar.rect.minY, accuracy: 0.0001)
        }

        let bulletStyle = LivelineBulletStyle(measure: 72, target: 80, axisRange: 0...100)
        func bullet(isRTL: Bool) -> LivelineBulletGeometry {
            LivelineRenderer.bulletGeometry(
                style: bulletStyle,
                layout: layout(isRTL: isRTL),
                palette: palette,
                reveal: 1
            )
        }

        // The measure still starts at the axis' lower bound, now growing left.
        let rtlBullet = bullet(isRTL: true)
        XCTAssertTrue(rtlBullet.isRTL)
        XCTAssertEqual(rtlBullet.measureRect.maxX, rtlLayout.rightX, accuracy: 0.001)
        XCTAssertEqual(rtlBullet.measureRect.width, rtlLayout.chartWidth * 0.72, accuracy: 0.001)
        XCTAssertEqual(
            rtlBullet.targetX ?? 0,
            rtlLayout.rightX - rtlLayout.chartWidth * 0.8,
            accuracy: 0.001
        )
        XCTAssertEqual(bullet(isRTL: false).measureRect, LivelineRenderer.bulletGeometry(
            style: bulletStyle,
            layout: layout(isRTL: false),
            palette: palette,
            reveal: 1
        ).measureRect)

        // Radial kinds read the same in either direction: a donut is a donut.
        let donutData = [
            LivelineCategoryValue(id: "a", label: "Alpha", value: 6),
            LivelineCategoryValue(id: "b", label: "Beta", value: 4),
        ]
        func donut(isRTL: Bool) -> LivelineDonutGeometry {
            LivelineRenderer.donutGeometry(
                data: donutData,
                style: LivelineDonutStyle(),
                layout: layout(isRTL: isRTL),
                palette: palette,
                reveal: 1
            )
        }
        XCTAssertEqual(donut(isRTL: true).center, donut(isRTL: false).center)
        XCTAssertEqual(donut(isRTL: true).segments.map(\.startDegrees), donut(isRTL: false).segments.map(\.startDegrees))
    }
}
