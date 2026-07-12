import SwiftUI

extension LivelineRenderer {
    /// Dither Kit's normalized 4x4 Bayer matrix. Keeping this exact ordering
    /// gives every chart kind the same recognizable ordered-pixel texture.
    static let ditherBayerThresholds: [[Double]] = [
        [0, 8, 2, 10],
        [12, 4, 14, 6],
        [3, 11, 1, 9],
        [15, 7, 13, 5],
    ].map { row in row.map { (Double($0) + 0.5) / 16 } }

    static func drawDitherTexture(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        color: Color,
        style: LivelineDitherStyle,
        timestamp: TimeInterval
    ) {
        let cell = style.cellSize
        let columns = max(1, Int(ceil(layout.chartWidth / cell)))
        let rows = max(1, Int(ceil(layout.chartHeight / cell)))
        let intensity = style.intensity

        if style.variant != .solid, intensity > 0 {
            var cutouts = Path()
            for row in 0..<rows {
                let density = Double(row) / Double(max(rows - 1, 1))
                for column in 0..<columns {
                    let threshold = ditherBayerThresholds[row & 3][column & 3]
                    let shouldCut: Bool
                    switch style.variant {
                    case .gradient:
                        shouldCut = density <= threshold - 0.1 * intensity
                    case .dotted:
                        shouldCut = density <= threshold + 0.12
                    case .hatched:
                        shouldCut = ((column + row) & 3) >= 2
                    case .solid:
                        shouldCut = false
                    }
                    guard shouldCut else { continue }
                    cutouts.addRect(
                        CGRect(
                            x: layout.plotLeftX + CGFloat(column) * cell,
                            y: layout.padding.top + CGFloat(row) * cell,
                            width: cell,
                            height: cell
                        )
                    )
                }
            }

            context.blendMode = .destinationOut
            let removal: Double = style.variant == .gradient ? 0.6 * intensity : intensity
            context.fill(cutouts, with: .color(.black.opacity(removal)))
            context.blendMode = .normal
        }

        guard style.sparkleDensity > 0 else { return }
        var sparklePath = Path()
        var flarePath = Path()
        let motionTime = style.animated ? timestamp * style.animationSpeed : 0
        let densityLimit = UInt32(style.sparkleDensity * Double(UInt32.max))

        for row in 0..<rows {
            for column in 0..<columns {
                let hash = ditherHash(column: column, row: row)
                guard hash <= densityLimit else { continue }
                let phase = Double(hash & 0xFFFF) / Double(UInt16.max) * .pi * 2
                let wink = style.animated ? (sin(motionTime * 3.5 + phase) + 1) / 2 : 0.85
                guard wink > 0.55 else { continue }
                let rect = CGRect(
                    x: layout.plotLeftX + CGFloat(column) * cell,
                    y: layout.padding.top + CGFloat(row) * cell,
                    width: cell,
                    height: cell
                )
                sparklePath.addRect(rect)
                if wink > 0.92 {
                    flarePath.addRect(rect.insetBy(dx: -cell, dy: cell * 0.25))
                    flarePath.addRect(rect.insetBy(dx: cell * 0.25, dy: -cell))
                }
            }
        }

        context.blendMode = .sourceAtop
        context.fill(sparklePath, with: .color(color.opacity(0.9)))
        context.fill(flarePath, with: .color(color.opacity(0.35)))
        context.blendMode = .normal
    }

    static func ditherBloom(style: LivelineDitherStyle, timestamp: TimeInterval) -> (radius: CGFloat, opacity: Double)? {
        let preset: (CGFloat, Double)?
        switch style.bloom {
        case .off: preset = nil
        case .low: preset = (3, 0.30)
        case .high: preset = (5, 0.42)
        case .aura: preset = (15, 0.18)
        }
        guard let preset else { return nil }
        let pulse = style.animated
            ? 0.88 + 0.12 * (sin(timestamp * style.animationSpeed * 1.7) + 1) / 2
            : 1
        return (preset.0, preset.1 * style.intensity * pulse)
    }

    static func ditherHash(column: Int, row: Int) -> UInt32 {
        var value = UInt32(truncatingIfNeeded: column &* 0x45D9F3B)
        value ^= UInt32(truncatingIfNeeded: row &* 0x119DE1F3)
        value ^= value >> 16
        value &*= 0x7FEB352D
        value ^= value >> 15
        value &*= 0x846CA68B
        return value ^ (value >> 16)
    }
}
