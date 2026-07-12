import Foundation
import SwiftUI

extension LivelineRenderer {
    static func drawOrderbook(
        context: inout GraphicsContext,
        layout: LivelineLayout,
        palette: LivelinePalette,
        state: LivelineRenderState,
        orderbook: LivelineOrderbookData,
        randomSeed: UInt32?,
        deltaTime: TimeInterval,
        swingMagnitude: Double,
        alpha: Double
    ) {
        guard alpha > 0.01, !orderbook.bids.isEmpty || !orderbook.asks.isEmpty else { return }

        let bidTotal = orderbook.bids.reduce(0) { $0 + $1.size }
        let askTotal = orderbook.asks.reduce(0) { $0 + $1.size }
        let previousTotal = state.previousBidTotal + state.previousAskTotal
        var churn = 0.0
        if previousTotal > 0 {
            churn = min((abs(bidTotal - state.previousBidTotal) + abs(askTotal - state.previousAskTotal)) / previousTotal, 1)
        }
        state.previousBidTotal = bidTotal
        state.previousAskTotal = askTotal
        state.churnRate += (churn - state.churnRate) * (churn > state.churnRate ? 0.3 : 0.05)

        let activity = max(min(swingMagnitude * 5, 1), state.churnRate)
        let targetSpeed = CGFloat(60 + activity * 100)
        state.orderbookSpeed = LivelineMath.lerpCGFloat(state.orderbookSpeed, targetSpeed, speed: 0.05, deltaTime: deltaTime)

        let dtSeconds = deltaTime / 1000
        state.orderbookSpawnTimer += deltaTime
        let bottomY = layout.bottomY - 6
        let topY = layout.padding.top
        let allLevels = orderbook.bids.map { ($0.size, true) } + orderbook.asks.map { ($0.size, false) }
        let maxSize = max(0.001, allLevels.map(\.0).max() ?? 1)
        let totalWeight = allLevels.reduce(0) { $0 + max(0, $1.0) }

        while state.orderbookSpawnTimer >= 40, state.orderbookLabels.count < 50, totalWeight > 0 {
            state.orderbookSpawnTimer -= 40
            if state.orderbookLabels.contains(where: { abs($0.y - bottomY) < 22 }) { break }
            let randomUnit = randomSeed.map { state.nextRandom(seed: $0) } ?? Double.random(in: 0..<1)
            var remaining = randomUnit * totalWeight
            var picked = allLevels[0]
            for level in allLevels {
                remaining -= max(0, level.0)
                if remaining <= 0 {
                    picked = level
                    break
                }
            }
            state.orderbookLabels.append(
                OrderbookLabel(
                    y: bottomY,
                    text: "+ \(formatOrderSize(picked.0))",
                    isBid: picked.1,
                    life: 6,
                    maxLife: 6,
                    intensity: 0.5 + min(picked.0 / maxSize, 1) * 0.5
                )
            )
        }

        for index in state.orderbookLabels.indices {
            let progress = (state.orderbookLabels[index].y - topY) / max(1, bottomY - topY)
            state.orderbookLabels[index].life -= dtSeconds
            state.orderbookLabels[index].y -= state.orderbookSpeed * (0.7 + 0.3 * progress) * CGFloat(dtSeconds)
        }
        state.orderbookLabels.removeAll { $0.life <= 0 || $0.y < topY - 14 }

        var layer = context
        layer.opacity *= alpha
        for label in state.orderbookLabels {
            let lifeRatio = label.life / label.maxLife
            let fadeIn = min((1 - lifeRatio) * 10, 1)
            let yRatio = Double((label.y - topY) / layout.chartHeight)
            let fadeOut = yRatio < 0.45 ? yRatio / 0.45 : 1
            let strength = label.intensity * fadeIn * fadeOut
            let baseColor = label.isBid
                ? LivelineRGBA(red: 34 / 255, green: 197 / 255, blue: 94 / 255, alpha: 1)
                : LivelineRGBA(red: 239 / 255, green: 68 / 255, blue: 68 / 255, alpha: 1)
            let fill = baseColor.blended(to: palette.backgroundRGB, t: 1 - strength)
            drawOrderbookText(
                label.text,
                context: &layer,
                at: CGPoint(x: layout.plotLeftX + 8, y: label.y),
                fill: fill,
                outline: palette.backgroundRGB
            )
        }
    }

    static func updateParticles(
        state: LivelineRenderState,
        origin: CGPoint,
        palette: LivelinePalette,
        momentum: LivelineMomentum,
        swingMagnitude: Double,
        options: LivelineDegenOptions,
        randomSeed: UInt32?,
        deltaTime: TimeInterval
    ) {
        let shouldSpawn = momentum == .up || (momentum == .down && options.downMomentum)
        if shouldSpawn, state.previousMomentum != momentum {
            let count = Int((8 + swingMagnitude * 14) * options.scale)
            for _ in 0..<count {
                let angle = randomCGFloat(
                    in: 0...(CGFloat.pi * 2),
                    state: state,
                    seed: randomSeed
                )
                let speed = randomCGFloat(
                    in: 35...120,
                    state: state,
                    seed: randomSeed
                ) * CGFloat(options.scale)
                let velocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
                let color = momentum == .up ? palette.dotUp : palette.dotDown
                let radius = randomCGFloat(
                    in: 1.5...3.5,
                    state: state,
                    seed: randomSeed
                )
                state.particles.append(
                    Particle(
                        position: origin,
                        velocity: velocity,
                        color: color,
                        radius: radius,
                        life: 0.55,
                        maxLife: 0.55
                    )
                )
            }
            state.shakeAmplitude = CGFloat(3 + swingMagnitude * 4)
        }
        state.previousMomentum = momentum
        _ = deltaTime
    }

    static func drawParticles(context: inout GraphicsContext, state: LivelineRenderState, deltaTime: TimeInterval) {
        let dt = deltaTime / 1000
        for index in state.particles.indices {
            state.particles[index].life -= dt
            state.particles[index].position.x += state.particles[index].velocity.dx * CGFloat(dt)
            state.particles[index].position.y += state.particles[index].velocity.dy * CGFloat(dt)
            state.particles[index].velocity.dy += 30 * CGFloat(dt)
        }
        state.particles.removeAll { $0.life <= 0 }

        for particle in state.particles {
            var layer = context
            layer.opacity *= particle.life / particle.maxLife
            layer.fill(Path(ellipseIn: CGRect(x: particle.position.x - particle.radius, y: particle.position.y - particle.radius, width: particle.radius * 2, height: particle.radius * 2)), with: .color(particle.color))
        }
    }

    static func formatOrderSize(_ size: Double) -> String {
        if size > Double(Int.max) { return String(format: "$%.2e", size) }
        if size >= 10 { return "$\(Int(size.rounded()))" }
        if size >= 1 { return String(format: "$%.1f", size) }
        return String(format: "$%.2f", size)
    }

    static func drawOrderbookText(
        _ text: String,
        context: inout GraphicsContext,
        at point: CGPoint,
        fill: LivelineRGBA,
        outline: LivelineRGBA
    ) {
        drawOutlinedText(
            text,
            context: &context,
            at: CGPoint(
                x: point.x + orderbookTextOffsetX,
                y: point.y + orderbookTextOffsetY
            ),
            anchor: .leading,
            fill: fill.color,
            outline: outline.color,
            font: .system(size: 13, weight: .semibold, design: .monospaced)
        )
    }

    static func drawLeftFade(context: inout GraphicsContext, layout: LivelineLayout) {
        var rect = Path()
        rect.addRect(CGRect(x: 0, y: 0, width: layout.plotLeftX + fadeEdgeWidth, height: layout.size.height))
        context.blendMode = .destinationOut
        context.fill(
            rect,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black.opacity(0), location: 1),
                ]),
                startPoint: CGPoint(x: layout.plotLeftX, y: 0),
                endPoint: CGPoint(x: layout.plotLeftX + fadeEdgeWidth, y: 0)
            )
        )
        context.blendMode = .normal
    }
}
