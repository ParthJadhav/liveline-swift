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

    static func bucketWidth(
        times: [TimeInterval],
        layout: LivelineLayout,
        ratio: CGFloat,
        minimum: CGFloat = 2,
        maximum: CGFloat
    ) -> CGFloat {
        let sorted = Array(Set(times)).sorted()
        let deltas = zip(sorted, sorted.dropFirst())
            .map { $1 - $0 }
            .filter { $0 > 0 }
        let fallbackCount = max(sorted.count, 8)
        let bucket = deltas.min()
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
