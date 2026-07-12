import SwiftUI

extension LivelineRenderer {
    static func drawText(
        _ text: String,
        context: inout GraphicsContext,
        at point: CGPoint,
        anchor: UnitPoint,
        color: Color,
        font: Font
    ) {
        context.draw(Text(text).font(font).foregroundColor(color), at: point, anchor: anchor)
    }

    static func drawOutlinedText(
        _ text: String,
        context: inout GraphicsContext,
        at point: CGPoint,
        anchor: UnitPoint,
        fill: Color,
        outline: Color,
        font: Font
    ) {
        let radius: CGFloat = 2
        for offset in [
            CGPoint(x: -radius, y: 0),
            CGPoint(x: radius, y: 0),
            CGPoint(x: 0, y: -radius),
            CGPoint(x: 0, y: radius),
            CGPoint(x: -radius * 0.7, y: -radius * 0.7),
            CGPoint(x: radius * 0.7, y: -radius * 0.7),
            CGPoint(x: -radius * 0.7, y: radius * 0.7),
            CGPoint(x: radius * 0.7, y: radius * 0.7),
        ] {
            context.draw(
                Text(text).font(font).foregroundColor(outline),
                at: CGPoint(x: point.x + offset.x, y: point.y + offset.y),
                anchor: anchor
            )
        }
        context.draw(Text(text).font(font).foregroundColor(fill), at: point, anchor: anchor)
    }

    static func measureText(_ text: String, context: GraphicsContext, font: Font) -> CGSize {
        let resolved = context.resolve(Text(text).font(font))
        return resolved.measure(in: CGSize(width: 10_000, height: 10_000))
    }

}
