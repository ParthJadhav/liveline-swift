import Foundation
import SwiftUI

extension LivelineRenderer {
    static func plotClip(_ layout: LivelineLayout) -> Path {
        Path(
            CGRect(
                x: layout.plotLeftX,
                y: layout.padding.top,
                width: layout.chartWidth,
                height: layout.chartHeight
            )
        )
    }

    /// Normalized samples arrive in ascending time order, so the tightest
    /// bucket is the smallest positive gap between neighbours. Walking the
    /// sequence once keeps this measurement off the per-frame allocation path;
    /// callers pass a lazy projection rather than materializing a time array.
    static func bucketWidth<Times: Sequence>(
        sortedTimes: Times,
        layout: LivelineLayout,
        ratio: CGFloat,
        minimum: CGFloat = 2,
        maximum: CGFloat
    ) -> CGFloat where Times.Element == TimeInterval {
        var count = 0
        var previous: TimeInterval?
        var smallestDelta: TimeInterval?
        for time in sortedTimes {
            count += 1
            if let previous {
                let delta = time - previous
                if delta > 0, delta < smallestDelta ?? .infinity {
                    smallestDelta = delta
                }
            }
            previous = time
        }
        let fallbackCount = max(count, 8)
        let bucket = smallestDelta
            ?? (layout.rightEdge - layout.leftEdge) / Double(fallbackCount)
        let width = CGFloat(
            bucket / max(layout.rightEdge - layout.leftEdge, 0.001)
        ) * layout.chartWidth
        return min(max(width * ratio, minimum), maximum)
    }

    static func drawBaseline(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        value: Double
    ) {
        let y = LivelineMath.clamp(
            layout.y(for: value),
            layout.padding.top,
            layout.bottomY
        )
        var path = Path()
        path.move(to: CGPoint(x: layout.plotLeftX, y: y))
        path.addLine(to: CGPoint(x: layout.rightX, y: y))
        context.stroke(
            path,
            with: .color(palette.referenceLine),
            style: StrokeStyle(lineWidth: 1, dash: [3, 4])
        )
    }
}
