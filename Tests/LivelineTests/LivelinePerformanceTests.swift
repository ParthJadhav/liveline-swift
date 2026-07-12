#if os(macOS)
import AppKit
import SwiftUI
import XCTest
@testable import Liveline

@MainActor
final class LivelinePerformanceTests: XCTestCase {
    private let size = CGSize(width: 320, height: 220)

    func testReleasePerformanceBenchmarks() throws {
        guard ProcessInfo.processInfo.environment["LIVELINE_RUN_BENCHMARKS"] == "1" else {
            throw XCTSkip("Run scripts/benchmark-performance.sh to execute performance benchmarks.")
        }

        let fixture = makeFixture()
        let layout = makeLayout()
        let style = LivelineDitherStyle(bloom: .low, cellSize: 2, sparkleDensity: 0.018)
        let geometryState = LivelineRenderState()
        let geometry = LivelineRenderer.ditherGeometry(state: geometryState, layout: layout, style: style)

        benchmark(name: "dither.sparkle-warm-frame", iterations: 1_000) { iteration in
            let paths = LivelineRenderer.ditherSparklePaths(
                geometry: geometry,
                style: style,
                timestamp: Double(iteration) / 60
            )
            return (paths.sparkles.isEmpty ? 0 : 1) + (paths.flares.isEmpty ? 0 : 1)
        }

        benchmark(name: "dither.geometry-cold", iterations: 30) { _ in
            let state = LivelineRenderState()
            return LivelineRenderer.ditherGeometry(state: state, layout: layout, style: style).sparkles.count
        }

        benchmark(name: "interaction.snapshot-idle", iterations: 2_000) { _ in
            let snapshot = LivelineInteractionBuilder.snapshot(
                content: fixture.content,
                prepared: fixture.prepared,
                layout: layout,
                palette: fixture.palette,
                configuration: fixture.configuration,
                hiddenSeries: [],
                behavior: .interpolated,
                includeTargets: false
            )
            return snapshot.points.count
        }

        benchmark(name: "interaction.snapshot-active", iterations: 200) { _ in
            let snapshot = LivelineInteractionBuilder.snapshot(
                content: fixture.content,
                prepared: fixture.prepared,
                layout: layout,
                palette: fixture.palette,
                configuration: fixture.configuration,
                hiddenSeries: [],
                behavior: .interpolated,
                includeTargets: true,
                targetLocation: CGPoint(x: layout.plotLeftX + layout.chartWidth / 2, y: layout.padding.top + 40)
            )
            return snapshot.targets.count
        }

        let frameState = LivelineRenderState()
        benchmark(name: "renderer.dither-warm-frame", iterations: 200) { iteration in
            let renderer = ImageRenderer(
                content: BenchmarkFrame(
                    state: frameState,
                    fixture: fixture,
                    timestamp: 1_000 + Double(iteration) / 60,
                    size: size
                )
            )
            renderer.proposedSize = ProposedViewSize(size)
            renderer.scale = 1
            return renderer.nsImage == nil ? 0 : 1
        }

        let activeFrameState = LivelineRenderState()
        benchmark(name: "renderer.dither-active-frame", iterations: 200) { iteration in
            let renderer = ImageRenderer(
                content: BenchmarkFrame(
                    state: activeFrameState,
                    fixture: fixture,
                    timestamp: 1_000 + Double(iteration) / 60,
                    size: size,
                    hoverLocation: CGPoint(x: 160, y: 100)
                )
            )
            renderer.proposedSize = ProposedViewSize(size)
            renderer.scale = 1
            return renderer.nsImage == nil ? 0 : 1
        }
    }

    private func benchmark(
        name: String,
        iterations: Int,
        samples: Int = 7,
        operation: (Int) -> Int
    ) {
        var warmup = 0
        for iteration in 0..<min(iterations, 20) {
            warmup &+= operation(iteration)
        }

        var measurements: [UInt64] = []
        var checksum = warmup
        for sample in 0..<samples {
            let start = DispatchTime.now().uptimeNanoseconds
            for iteration in 0..<iterations {
                checksum &+= operation(iteration + sample * iterations)
            }
            measurements.append(DispatchTime.now().uptimeNanoseconds - start)
        }

        measurements.sort()
        let median = measurements[measurements.count / 2]
        let milliseconds = Double(median) / 1_000_000
        let nanosecondsPerIteration = Double(median) / Double(iterations)
        let formattedMilliseconds = String(format: "%.3f", milliseconds)
        let formattedNanoseconds = String(format: "%.1f", nanosecondsPerIteration)
        print(
            "LIVELINE_BENCHMARK name=\(name) median_ms=\(formattedMilliseconds) "
                + "ns_per_iteration=\(formattedNanoseconds) "
                + "iterations=\(iterations) samples=\(samples) checksum=\(checksum)"
        )
    }

    private func makeFixture() -> BenchmarkFixture {
        let points = (0..<260).map { index in
            let time = 1_000 + Double(index)
            let value = 100 + sin(Double(index) * 0.1) * 4 + cos(Double(index) * 0.031) * 2
            return LivelinePoint(time: time, value: value)
        }
        let content = LivelineChartContent.line(data: points, value: points.last?.value ?? 0)
        let configuration = LivelineChartConfiguration(
            style: .dither(LivelineDitherStyle()),
            window: 240,
            badge: true,
            pulse: false,
            paused: false
        )
        let layout = makeLayout()
        return BenchmarkFixture(
            content: content,
            semantics: content.semantics(),
            prepared: LivelineChartPreparer.prepare(
                for: content,
                hiddenSeries: [],
                leftEdge: layout.leftEdge,
                rightEdge: layout.rightEdge,
                config: configuration
            ),
            configuration: configuration,
            palette: LivelinePalette.resolve(accent: .blue, mode: .dark, lineWidth: 2)
        )
    }

    private func makeLayout() -> LivelineLayout {
        LivelineLayout(
            size: size,
            padding: LivelineResolvedPadding(top: 20, right: 20, bottom: 20, left: 20),
            minValue: 90,
            maxValue: 110,
            leftEdge: 1_019,
            rightEdge: 1_259
        )
    }
}

private struct BenchmarkFixture {
    var content: LivelineChartContent
    var semantics: LivelineChartSemantics
    var prepared: LivelinePreparedChart
    var configuration: LivelineChartConfiguration
    var palette: LivelinePalette
}

private struct BenchmarkFrame: View {
    let state: LivelineRenderState
    let fixture: BenchmarkFixture
    let timestamp: TimeInterval
    let size: CGSize
    var hoverLocation: CGPoint? = nil

    var body: some View {
        Canvas { context, canvasSize in
            LivelineRenderer.draw(
                context: &context,
                state: state,
                input: LivelineRenderInput(
                    content: fixture.content,
                    semantics: fixture.semantics,
                    accent: .blue,
                    configuration: fixture.configuration,
                    motion: LivelineMotionPolicy(isPaused: false, requiresTimeline: true, settlesImmediately: false),
                    activeWindow: 240,
                    hiddenSeries: [],
                    hoverLocation: hoverLocation,
                    timestamp: timestamp,
                    size: canvasSize
                )
            )
        }
        .frame(width: size.width, height: size.height)
    }
}
#endif
