import SwiftUI

struct LivelineDitherGeometryKey: Equatable {
    var plotLeftX: CGFloat
    var plotTop: CGFloat
    var chartWidth: CGFloat
    var chartHeight: CGFloat
    var cellSize: CGFloat
    var intensity: Double
    var sparkleDensity: Double
    var variant: Int
}

struct LivelineDitherSparkle {
    var rect: CGRect
    var phase: Double
}

struct LivelineDitherGeometry {
    var key: LivelineDitherGeometryKey
    var cutouts: Path
    var sparkles: [LivelineDitherSparkle]
    var cellCount: Int
}

extension LivelineRenderer {
    /// Dither Kit's normalized 4x4 Bayer matrix. Keeping this exact ordering
    /// gives every chart kind the same recognizable ordered-pixel texture.
    static let ditherBayerThresholds: [Double] = [
        [0, 8, 2, 10],
        [12, 4, 14, 6],
        [3, 11, 1, 9],
        [15, 7, 13, 5],
    ].flatMap { row in row.map { (Double($0) + 0.5) / 16 } }

    static func drawDitherTexture(
        context: inout GraphicsContext,
        state: LivelineRenderState,
        layout: LivelineLayout,
        color: Color,
        style: LivelineDitherStyle,
        timestamp: TimeInterval
    ) {
        let geometry = ditherGeometry(state: state, layout: layout, style: style)
        if style.variant != .solid, style.intensity > 0 {
            context.blendMode = .destinationOut
            let removal: Double = style.variant == .gradient ? 0.6 * style.intensity : style.intensity
            context.fill(geometry.cutouts, with: .color(.black.opacity(removal)))
            context.blendMode = .normal
        }

        guard !geometry.sparkles.isEmpty else { return }
        var sparklePath = Path()
        var flarePath = Path()
        let motionTime = style.animated ? timestamp * style.animationSpeed : 0
        let cell = style.cellSize
        for sparkle in geometry.sparkles {
            let wink = style.animated ? (sin(motionTime * 3.5 + sparkle.phase) + 1) / 2 : 0.85
            guard wink > 0.55 else { continue }
            sparklePath.addRect(sparkle.rect)
            if wink > 0.92 {
                flarePath.addRect(sparkle.rect.insetBy(dx: -cell, dy: cell * 0.25))
                flarePath.addRect(sparkle.rect.insetBy(dx: cell * 0.25, dy: -cell))
            }
        }

        context.blendMode = .sourceAtop
        context.fill(sparklePath, with: .color(color.opacity(0.9)))
        context.fill(flarePath, with: .color(color.opacity(0.35)))
        context.blendMode = .normal
    }

    static func ditherGeometry(
        state: LivelineRenderState,
        layout: LivelineLayout,
        style: LivelineDitherStyle
    ) -> LivelineDitherGeometry {
        let key = LivelineDitherGeometryKey(
            plotLeftX: layout.plotLeftX,
            plotTop: layout.padding.top,
            chartWidth: layout.chartWidth,
            chartHeight: layout.chartHeight,
            cellSize: style.cellSize,
            intensity: style.intensity,
            sparkleDensity: style.sparkleDensity,
            variant: ditherVariantKey(style.variant)
        )
        if let cached = state.ditherGeometryCache, cached.key == key {
            return cached
        }

        let cell = style.cellSize
        let columns = max(1, Int(ceil(layout.chartWidth / cell)))
        let rows = max(1, Int(ceil(layout.chartHeight / cell)))
        var cutouts = Path()
        var sparkles: [LivelineDitherSparkle] = []
        sparkles.reserveCapacity(Int(Double(columns * rows) * style.sparkleDensity * 1.05))
        let densityLimit = UInt32(style.sparkleDensity * Double(UInt32.max))

        for row in 0..<rows {
            let density = Double(row) / Double(max(rows - 1, 1))
            for column in 0..<columns {
                let rect = CGRect(
                    x: layout.plotLeftX + CGFloat(column) * cell,
                    y: layout.padding.top + CGFloat(row) * cell,
                    width: cell,
                    height: cell
                )
                let threshold = ditherBayerThresholds[(row & 3) * 4 + (column & 3)]
                let shouldCut: Bool
                switch style.variant {
                case .gradient:
                    shouldCut = density <= threshold - 0.1 * style.intensity
                case .dotted:
                    shouldCut = density <= threshold + 0.12
                case .hatched:
                    shouldCut = ((column + row) & 3) >= 2
                case .solid:
                    shouldCut = false
                }
                if shouldCut { cutouts.addRect(rect) }

                guard style.sparkleDensity > 0 else { continue }
                let hash = ditherHash(column: column, row: row)
                guard hash <= densityLimit else { continue }
                sparkles.append(
                    LivelineDitherSparkle(
                        rect: rect,
                        phase: Double(hash & 0xFFFF) / Double(UInt16.max) * .pi * 2
                    )
                )
            }
        }

        let geometry = LivelineDitherGeometry(
            key: key,
            cutouts: cutouts,
            sparkles: sparkles,
            cellCount: columns * rows
        )
        state.ditherGeometryCache = geometry
        state.ditherGeometryBuildCount += 1
        return geometry
    }

    static func ditherVariantKey(_ variant: LivelineDitherVariant) -> Int {
        switch variant {
        case .gradient: 0
        case .dotted: 1
        case .hatched: 2
        case .solid: 3
        }
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
