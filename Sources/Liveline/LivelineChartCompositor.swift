import Foundation
import SwiftUI

struct LivelineCompositorInput {
    var content: LivelineChartContent
    var configuration: LivelineChartConfiguration
    var layout: LivelineLayout
    var palette: LivelinePalette
    var prepared: LivelinePreparedChart
    var hiddenSeries: Set<String>
    var hover: LivelineHoverPoint?
    var scrubAmount: Double
    var smoothValue: Double
    var swingMagnitude: Double
    var anchor: TimeInterval
    var leftEdge: TimeInterval
    var rightEdge: TimeInterval
    var reveal: Double
    var animationTimestamp: TimeInterval
    var deltaTime: TimeInterval
    var textScale: LivelineTextScale = .standard
}

/// What drawing a chart's marks leaves to the passes after it: which hover
/// guide fits those marks, and the text the dither style draws above its
/// texture instead of inside it.
struct LivelineContentOverlay {
    enum Crosshair {
        /// No hover guide and no active point.
        case none
        case discrete
        case line(livePoint: CGPoint?)
        case candle(LivelineCandleOverlay)
        case series
    }

    var crosshair: Crosshair = .discrete
    var deferredText: ((inout GraphicsContext) -> Void)?

    /// Charts without a hover guide have no time-and-value position for an
    /// active point either.
    var marksPoints: Bool {
        if case .none = crosshair { return false }
        return true
    }

    static let standard = LivelineContentOverlay()
}

struct LivelineCandleOverlay {
    var lineModeProgress: Double
    var linePoints: [CGPoint]
    var smoothValue: Double
    var reveal: Double
}

extension LivelineRenderer {
    /// Draws only chart-specific marks and endpoint decorations. Shared axes,
    /// crosshairs, and active-point overlays are composed by the caller once.
    static func drawContent(
        context: inout GraphicsContext,
        state: LivelineRenderState,
        input: LivelineCompositorInput,
        drawText: Bool = true
    ) -> LivelineContentOverlay {
        let config = input.configuration
        let layout = input.layout
        let palette = input.palette
        let reveal = input.reveal

        switch input.content {
        case .line:
            let momentum = resolvedMomentum(config: config, points: input.prepared.primaryVisible)
            let points = drawLine(
                context: &context,
                layout: layout,
                palette: palette,
                points: input.prepared.primaryVisible,
                smoothValue: input.smoothValue,
                now: input.anchor,
                showFill: config.fill,
                hoverX: input.hover?.x,
                scrubAmount: input.scrubAmount,
                reveal: reveal,
                timestamp: input.animationTimestamp,
                fadeEffects: config.fadeEffects
            )
            var decorationConfig = config
            if !drawText { decorationConfig.badge = false }
            drawLineDecorations(
                context: &context,
                state: state,
                layout: layout,
                palette: palette,
                points: points,
                momentum: momentum,
                config: decorationConfig,
                scrubAmount: input.scrubAmount,
                smoothValue: input.smoothValue,
                swingMagnitude: input.swingMagnitude,
                textScale: input.textScale,
                timestamp: input.animationTimestamp,
                deltaTime: input.deltaTime
            )
            let livePoint = points.last
            return LivelineContentOverlay(crosshair: .line(livePoint: livePoint)) { context in
                guard config.badge, let livePoint else { return }
                drawBadge(
                    context: &context,
                    layout: layout,
                    palette: palette,
                    value: input.smoothValue,
                    momentum: momentum,
                    y: livePoint.y,
                    config: config,
                    textScale: input.textScale,
                    alpha: reveal
                )
            }

        case let .bars(data, style):
            drawBars(
                context: &context,
                layout: layout,
                palette: palette,
                points: data.livelineVisible(in: layout.leftEdge...layout.rightEdge),
                style: style,
                reveal: reveal
            )
            return .standard

        case let .range(data, style):
            drawRangeBand(
                context: &context,
                layout: layout,
                palette: palette,
                points: data.livelineVisible(in: layout.leftEdge...layout.rightEdge),
                style: style,
                reveal: reveal
            )
            return .standard

        case let .scatter(data, _, style):
            drawScatter(
                context: &context,
                layout: layout,
                palette: palette,
                points: data.livelineVisible(in: layout.leftEdge...layout.rightEdge),
                style: style,
                reveal: reveal
            )
            return .standard

        case let .steps(data, _, style):
            drawSteps(
                context: &context,
                layout: layout,
                palette: palette,
                points: data.livelineVisible(in: layout.leftEdge...layout.rightEdge),
                style: style,
                reveal: reveal
            )
            return .standard

        case let .lollipops(data, style):
            drawLollipops(
                context: &context,
                layout: layout,
                palette: palette,
                points: data.livelineVisible(in: layout.leftEdge...layout.rightEdge),
                style: style,
                reveal: reveal
            )
            return .standard

        case let .bubbles(data, style):
            drawBubbles(
                context: &context,
                layout: layout,
                palette: palette,
                points: data.livelineVisible(in: layout.leftEdge...layout.rightEdge),
                style: style,
                reveal: reveal
            )
            return .standard

        case let .boxPlots(data, style):
            drawBoxPlots(
                context: &context,
                layout: layout,
                palette: palette,
                points: data.livelineVisible(in: layout.leftEdge...layout.rightEdge),
                style: style,
                reveal: reveal
            )
            return .standard

        case let .waterfall(data, style):
            drawWaterfall(
                context: &context,
                layout: layout,
                palette: palette,
                segments: LivelineMath.waterfallSegments(
                    points: data,
                    initialValue: style.resolvedInitialValue,
                    state: state
                )
                .livelineVisible(in: layout.leftEdge...layout.rightEdge),
                style: style,
                reveal: reveal
            )
            return .standard

        case let .errorBars(data, style):
            drawErrorBars(
                context: &context,
                layout: layout,
                palette: palette,
                points: data.livelineVisible(in: layout.leftEdge...layout.rightEdge),
                style: style,
                reveal: reveal
            )
            return .standard

        case let .dumbbells(data, style):
            drawDumbbells(
                context: &context,
                layout: layout,
                palette: palette,
                points: data.livelineVisible(in: layout.leftEdge...layout.rightEdge),
                style: style,
                reveal: reveal
            )
            return .standard

        case let .stackedBars(data, style):
            drawStackedBars(
                context: &context,
                layout: layout,
                palette: palette,
                points: data.livelineVisible(in: layout.leftEdge...layout.rightEdge),
                style: style,
                reveal: reveal
            )
            return .standard

        case let .stackedAreas(data, style):
            drawStackedAreas(
                context: &context,
                layout: layout,
                palette: palette,
                points: data.livelineVisible(in: layout.leftEdge...layout.rightEdge),
                style: style,
                reveal: reveal
            )
            return .standard

        case let .timeline(data, style):
            let visible = data.filter { $0.end >= layout.leftEdge && $0.start <= layout.rightEdge }
            let geometry = timelineGeometry(
                items: visible,
                totalLaneCount: max((data.map(\.lane).max() ?? 0) + 1, 1),
                style: style,
                layout: layout,
                palette: palette,
                reveal: reveal
            )
            drawTimeline(
                context: &context,
                layout: layout,
                palette: palette,
                geometry: geometry,
                style: style,
                textScale: input.textScale,
                drawLabels: drawText
            )
            return LivelineContentOverlay(crosshair: .none) { context in
                drawTimelineLabels(context: &context, geometry: geometry, style: style, textScale: input.textScale)
            }

        case let .heatmap(data, style):
            let visible = data.livelineVisible(in: layout.leftEdge...layout.rightEdge)
            let geometry = heatmapGeometry(
                cells: visible,
                totalRowCount: max((data.map(\.row).max() ?? 0) + 1, style.rowLabels.count, 1),
                style: style,
                layout: layout,
                palette: palette,
                reveal: reveal
            )
            drawHeatmap(
                context: &context,
                layout: layout,
                palette: palette,
                geometry: geometry,
                style: style,
                formatValue: config.formatValue,
                textScale: input.textScale,
                drawLabels: drawText
            )
            return LivelineContentOverlay(crosshair: .none) { context in
                drawHeatmapLabels(
                    context: &context,
                    layout: layout,
                    palette: palette,
                    geometry: geometry,
                    style: style,
                    formatValue: config.formatValue,
                    textScale: input.textScale
                )
            }

        case let .radar(data, style):
            let geometry = radarGeometry(points: data, style: style, layout: layout, reveal: reveal)
            drawRadar(context: &context, palette: palette, geometry: geometry, points: data, style: style, textScale: input.textScale, drawLabels: drawText)
            return LivelineContentOverlay(crosshair: .none) { context in
                drawRadarLabels(context: &context, palette: palette, geometry: geometry, points: data, style: style, textScale: input.textScale)
            }

        case let .donut(data, style):
            let geometry = donutGeometry(data: data, style: style, layout: layout, palette: palette, reveal: reveal)
            drawDonut(context: &context, palette: palette, geometry: geometry, style: style, formatValue: config.formatValue, textScale: input.textScale, drawLabels: drawText)
            return LivelineContentOverlay(crosshair: .none) { context in
                drawDonutLabels(context: &context, palette: palette, geometry: geometry, style: style, formatValue: config.formatValue, textScale: input.textScale)
            }

        case let .gauge(value, range, style):
            let geometry = gaugeRenderGeometry(value: value, range: range, style: style, layout: layout, reveal: reveal)
            drawGauge(context: &context, palette: palette, geometry: geometry, style: style, formatValue: config.formatValue, textScale: input.textScale, drawLabels: drawText)
            return LivelineContentOverlay(crosshair: .none) { context in
                drawGaugeLabel(context: &context, palette: palette, geometry: geometry, style: style, formatValue: config.formatValue, textScale: input.textScale)
            }

        case let .funnel(data, style):
            let geometry = funnelGeometry(data: data, style: style, layout: layout, palette: palette, reveal: reveal)
            drawFunnel(context: &context, geometry: geometry, style: style, formatValue: config.formatValue, textScale: input.textScale, drawLabels: drawText)
            return LivelineContentOverlay(crosshair: .none) { context in
                drawFunnelLabels(context: &context, geometry: geometry, style: style, formatValue: config.formatValue, textScale: input.textScale)
            }

        case let .histogram(values, style):
            let geometry = histogramGeometry(
                bins: state.histogramBins(values: values, binning: style.binning),
                style: style,
                layout: layout,
                palette: palette,
                reveal: reveal
            )
            drawHistogram(
                context: &context,
                layout: layout,
                palette: palette,
                geometry: geometry,
                style: style,
                formatValue: config.formatValue,
                textScale: input.textScale,
                drawLabels: drawText
            )
            return LivelineContentOverlay(crosshair: .none) { context in
                drawHistogramLabels(
                    context: &context,
                    layout: layout,
                    palette: palette,
                    geometry: geometry,
                    style: style,
                    formatValue: config.formatValue,
                    textScale: input.textScale
                )
            }

        case let .bullet(style):
            let geometry = bulletGeometry(style: style, layout: layout, palette: palette, reveal: reveal)
            drawBullet(
                context: &context,
                palette: palette,
                geometry: geometry,
                style: style,
                formatValue: config.formatValue,
                textScale: input.textScale,
                drawLabels: drawText
            )
            return LivelineContentOverlay(crosshair: .none) { context in
                drawBulletLabels(
                    context: &context,
                    palette: palette,
                    geometry: geometry,
                    style: style,
                    formatValue: config.formatValue,
                    textScale: input.textScale
                )
            }

        case let .treemap(nodes, style):
            let plotRect = CGRect(
                x: layout.plotLeftX,
                y: layout.padding.top,
                width: layout.chartWidth,
                height: layout.chartHeight
            )
            let geometry = treemapGeometry(
                nodes: nodes,
                tiling: state.treemapLayout(nodes: nodes, style: style, in: plotRect),
                style: style,
                layout: layout,
                palette: palette,
                reveal: reveal
            )
            drawTreemap(
                context: &context,
                layout: layout,
                geometry: geometry,
                style: style,
                formatValue: config.formatValue,
                textScale: input.textScale,
                drawLabels: drawText
            )
            return LivelineContentOverlay(crosshair: .none) { context in
                drawTreemapLabels(
                    context: &context,
                    layout: layout,
                    geometry: geometry,
                    style: style,
                    formatValue: config.formatValue,
                    textScale: input.textScale
                )
            }

        case let .sunburst(nodes, style):
            // Radial layout is pure trigonometry over the node values, cheap
            // enough to follow the donut's idiom and run in the draw pass.
            let geometry = sunburstGeometry(
                nodes: nodes,
                style: style,
                layout: layout,
                palette: palette,
                reveal: reveal
            )
            drawSunburst(
                context: &context,
                palette: palette,
                geometry: geometry,
                style: style,
                formatValue: config.formatValue,
                textScale: input.textScale,
                drawLabels: drawText
            )
            return LivelineContentOverlay(crosshair: .none) { context in
                drawSunburstLabels(
                    context: &context,
                    palette: palette,
                    geometry: geometry,
                    style: style,
                    formatValue: config.formatValue,
                    textScale: input.textScale
                )
            }

        case let .sankey(links, style):
            let geometry = sankeyGeometry(
                links: links,
                graph: state.sankeyGraph(links: links),
                style: style,
                layout: layout,
                palette: palette,
                reveal: reveal
            )
            drawSankey(
                context: &context,
                layout: layout,
                palette: palette,
                geometry: geometry,
                style: style,
                formatValue: config.formatValue,
                textScale: input.textScale,
                drawLabels: drawText
            )
            return LivelineContentOverlay(crosshair: .none) { context in
                drawSankeyLabels(
                    context: &context,
                    layout: layout,
                    palette: palette,
                    geometry: geometry,
                    style: style,
                    formatValue: config.formatValue,
                    textScale: input.textScale
                )
            }

        case let .candle(_, _, candles, candleWidth, liveCandle, lineData, lineValue):
            let candle = drawCandleMode(
                    context: &context,
                    state: state,
                    layout: layout,
                    palette: palette,
                    candles: candles,
                    candleWidth: candleWidth,
                    liveCandle: liveCandle,
                    lineData: lineData,
                    lineValue: lineValue,
                    config: config,
                    hover: input.hover,
                    scrubAmount: input.scrubAmount,
                    now: input.anchor,
                    leftEdge: input.leftEdge,
                    rightEdge: input.rightEdge,
                    reveal: reveal,
                    timestamp: input.animationTimestamp,
                    deltaTime: input.deltaTime,
                    smoothValue: input.smoothValue,
                    textScale: input.textScale
                )
            return LivelineContentOverlay(crosshair: .candle(candle))

        case let .series(series):
            let endpoints = drawSeries(
                context: &context,
                state: state,
                layout: layout,
                series: series,
                hiddenSeries: input.hiddenSeries,
                config: config,
                timestamp: input.animationTimestamp,
                now: input.anchor,
                hover: input.hover,
                deltaTime: input.deltaTime,
                alpha: reveal
            )
            drawSeriesEndpoints(
                context: &context,
                endpoints: endpoints,
                alpha: reveal,
                showPulse: config.pulse && reveal > 0.6 && state.pauseProgress < 0.5,
                timestamp: input.animationTimestamp,
                legendSide: config.seriesLegendSide.resolved(isRTL: layout.isRTL),
                textScale: input.textScale,
                drawsLabel: drawText
            )
            return LivelineContentOverlay(crosshair: .series) { context in
                drawSeriesEndpoints(
                    context: &context,
                    endpoints: endpoints,
                    alpha: reveal,
                    showPulse: false,
                    timestamp: input.animationTimestamp,
                    legendSide: config.seriesLegendSide.resolved(isRTL: layout.isRTL),
                    textScale: input.textScale,
                    drawsDot: false
                )
            }
        }
    }

    static func drawContentOverlays(
        context: inout GraphicsContext,
        overlay: LivelineContentOverlay,
        layout: LivelineLayout,
        palette: LivelinePalette,
        prepared: LivelinePreparedChart,
        hover: LivelineHoverPoint?,
        scrubAmount: Double,
        configuration: LivelineChartConfiguration,
        tooltipSelection: LivelineTooltipSelection?,
        textScale: LivelineTextScale,
        reveal: Double,
        animationTimestamp: TimeInterval
    ) {
        switch overlay.crosshair {
        case let .line(livePoint):
            if let hover, let livePoint {
                drawLineCrosshair(
                    context: &context,
                    layout: layout,
                    palette: palette,
                    hover: hover,
                    livePoint: livePoint,
                    config: configuration,
                    alpha: scrubAmount
                )
            }

        case let .candle(candle):
            guard candle.reveal > 0.7 else { break }
            if candle.lineModeProgress > 0.5 {
                if let hover {
                    drawLineCrosshair(
                        context: &context,
                        layout: layout,
                        palette: palette,
                        hover: hover,
                        livePoint: candle.linePoints.last ?? CGPoint(x: layout.rightX, y: layout.y(for: candle.smoothValue)),
                        config: configuration,
                        alpha: scrubAmount
                    )
                }
            } else {
                drawCandleCrosshair(
                    context: &context,
                    layout: layout,
                    palette: palette,
                    hover: hover,
                    alpha: scrubAmount
                )
            }

        case .series:
            drawMultiCrosshair(
                context: &context,
                layout: layout,
                palette: palette,
                hover: hover,
                alpha: scrubAmount
            )

        case .discrete:
            drawDiscreteCrosshair(
                context: &context,
                layout: layout,
                palette: palette,
                hover: hover,
                points: prepared.primaryVisible,
                config: configuration,
                alpha: scrubAmount
            )

        case .none:
            break
        }

        if overlay.marksPoints {
            drawActivePoint(
                context: &context,
                layout: layout,
                palette: palette,
                points: prepared.primaryVisible,
                activePoint: configuration.activePoint,
                alpha: reveal,
                timestamp: animationTimestamp
            )
        }

        drawTooltipSelection(
            context: &context,
            layout: layout,
            palette: palette,
            selection: tooltipSelection,
            configuration: configuration,
            textScale: textScale,
            alpha: scrubAmount
        )
    }
}
