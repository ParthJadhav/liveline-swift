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
    /// The wink phase, stored as its sine and cosine so each animation frame
    /// expands `sin(angle + phase)` with two multiplies instead of a `sin`.
    var sinPhase: Double
    var cosPhase: Double
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
        timestamp: TimeInterval,
        drawFillMask: (inout GraphicsContext) -> Void
    ) {
        let geometry = ditherGeometry(state: state, layout: layout, style: style)

        // Dither belongs inside broad filled marks, never on the strokes that
        // explain their shape. Turn every rendered mark into an opaque mask,
        // blur it, then keep only the high-coverage interior. Thin lines,
        // outlines, wicks, connectors, and marker borders disappear from this
        // mask while the center of a bar, area, sector, cell, or ribbon remains.
        // The ordered cutouts and sparkles below are therefore unable to break
        // readability-critical strokes even though all chart families share
        // this one renderer path.
        let interiorRadius = max(2, min(4, style.cellSize * 1.25))
        context.clipToLayer { mask in
            // GraphicsContext evaluates stacked filters from the last added
            // filter back to the first: normalize alpha, blur, then threshold.
            mask.addFilter(.alphaThreshold(min: 0.72, color: .white))
            mask.addFilter(.blur(radius: interiorRadius))
            mask.addFilter(.alphaThreshold(min: 0.01, color: .white))
            drawFillMask(&mask)
        }

        if style.variant != .solid, style.intensity > 0 {
            context.blendMode = .destinationOut
            let removal: Double = style.variant == .gradient ? 0.6 * style.intensity : style.intensity
            context.fill(geometry.cutouts, with: .color(.black.opacity(removal)))
            context.blendMode = .normal
        }

        guard !geometry.sparkles.isEmpty else { return }
        let paths = ditherSparklePaths(geometry: geometry, style: style, timestamp: timestamp)

        context.blendMode = .sourceAtop
        context.fill(paths.sparkles, with: .color(color.opacity(0.9)))
        context.fill(paths.flares, with: .color(color.opacity(0.35)))
        context.blendMode = .normal
    }

    static func ditherSparklePaths(
        geometry: LivelineDitherGeometry,
        style: LivelineDitherStyle,
        timestamp: TimeInterval
    ) -> (sparkles: Path, flares: Path) {
        let cell = style.cellSize
        var sparklePath = Path()
        var flarePath = Path()
        guard style.animated else {
            // The static texture shows every sparkle and never flares.
            for sparkle in geometry.sparkles {
                sparklePath.addRect(sparkle.rect)
            }
            return (sparklePath, flarePath)
        }

        // The wink for a sparkle is `(sin(angle + phase) + 1) / 2` gated at
        // 0.55 and 0.92; with each phase's sine and cosine precomputed at
        // geometry build, that reduces to comparing the expanded sine against
        // 0.1 and 0.84 — no transcendental per sparkle.
        let angle = timestamp * style.animationSpeed * 3.5
        let sinAngle = sin(angle)
        let cosAngle = cos(angle)
        for sparkle in geometry.sparkles {
            let sine = sinAngle * sparkle.cosPhase + cosAngle * sparkle.sinPhase
            guard sine > 0.1 else { continue }
            sparklePath.addRect(sparkle.rect)
            if sine > 0.84 {
                flarePath.addRect(sparkle.rect.insetBy(dx: -cell, dy: cell * 0.25))
                flarePath.addRect(sparkle.rect.insetBy(dx: cell * 0.25, dy: -cell))
            }
        }
        return (sparklePath, flarePath)
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
        sparkles.reserveCapacity(Int(Double(min(columns * rows, 65_536)) * style.sparkleDensity * 1.05))
        let densityLimit = UInt32(style.sparkleDensity * Double(UInt32.max))
        let hasSparkles = style.sparkleDensity > 0
        let plotLeftX = layout.plotLeftX
        let plotTop = layout.padding.top
        let gradientBias = 0.1 * style.intensity
        // A local copy keeps the per-cell threshold reads off the global's
        // lazy-initialization accessor.
        let thresholds = ditherBayerThresholds

        for row in 0..<rows {
            let density = Double(row) / Double(max(rows - 1, 1))
            let rowY = plotTop + CGFloat(row) * cell
            let thresholdBase = (row & 3) * 4
            for column in 0..<columns {
                let rect = CGRect(
                    x: plotLeftX + CGFloat(column) * cell,
                    y: rowY,
                    width: cell,
                    height: cell
                )
                let threshold = thresholds[thresholdBase + (column & 3)]
                let shouldCut: Bool
                switch style.variant {
                case .gradient:
                    shouldCut = density <= threshold - gradientBias
                case .dotted:
                    shouldCut = density <= threshold + 0.12
                case .hatched:
                    shouldCut = ((column + row) & 3) >= 2
                case .solid:
                    shouldCut = false
                }
                if shouldCut { cutouts.addRect(rect) }

                guard hasSparkles else { continue }
                let hash = ditherHash(column: column, row: row)
                guard hash <= densityLimit else { continue }
                let phase = Double(hash & 0xFFFF) / Double(UInt16.max) * .pi * 2
                sparkles.append(
                    LivelineDitherSparkle(rect: rect, sinPhase: sin(phase), cosPhase: cos(phase))
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
