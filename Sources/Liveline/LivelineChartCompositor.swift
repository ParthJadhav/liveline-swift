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
}

enum LivelineContentOverlay {
    case line(livePoint: CGPoint?)
    case candle(LivelineCandleOverlay)
    case series(
        entries: [LivelineSeries],
        endpoints: [(point: CGPoint, palette: LivelinePalette, label: String?, alpha: Double)]
    )
    case timeline(LivelineTimelineGeometry, LivelineTimelineStyle)
    case heatmap(LivelineHeatmapGeometry, LivelineHeatmapStyle)
    case radar(LivelineRadarGeometry, [LivelineRadarPoint], LivelineRadarStyle)
    case donut(LivelineDonutGeometry, LivelineDonutStyle)
    case gauge(LivelineGaugeRenderGeometry, LivelineGaugeStyle)
    case funnel(LivelineFunnelGeometry, LivelineFunnelStyle)
    case standard
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
                timestamp: input.animationTimestamp,
                deltaTime: input.deltaTime
            )
            return .line(livePoint: points.last)

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
                segments: LivelineMath.waterfallSegments(points: data, initialValue: style.resolvedInitialValue)
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
            let geometry = timelineGeometry(
                items: data.filter { $0.end >= layout.leftEdge && $0.start <= layout.rightEdge },
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
                drawLabels: drawText
            )
            return .timeline(geometry, style)

        case let .heatmap(data, style):
            let geometry = heatmapGeometry(
                cells: data.livelineVisible(in: layout.leftEdge...layout.rightEdge),
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
                drawLabels: drawText
            )
            return .heatmap(geometry, style)

        case let .radar(data, style):
            let geometry = radarGeometry(points: data, style: style, layout: layout, reveal: reveal)
            drawRadar(context: &context, palette: palette, geometry: geometry, points: data, style: style, drawLabels: drawText)
            return .radar(geometry, data, style)

        case let .donut(data, style):
            let geometry = donutGeometry(data: data, style: style, layout: layout, palette: palette, reveal: reveal)
            drawDonut(context: &context, palette: palette, geometry: geometry, style: style, formatValue: config.formatValue, drawLabels: drawText)
            return .donut(geometry, style)

        case let .gauge(value, range, style):
            let geometry = gaugeRenderGeometry(value: value, range: range, style: style, layout: layout, reveal: reveal)
            drawGauge(context: &context, palette: palette, geometry: geometry, style: style, formatValue: config.formatValue, drawLabels: drawText)
            return .gauge(geometry, style)

        case let .funnel(data, style):
            let geometry = funnelGeometry(data: data, style: style, layout: layout, palette: palette, reveal: reveal)
            drawFunnel(context: &context, geometry: geometry, style: style, formatValue: config.formatValue, drawLabels: drawText)
            return .funnel(geometry, style)

        case let .candle(_, _, candles, candleWidth, liveCandle, lineData, lineValue):
            return .candle(
                drawCandleMode(
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
                    smoothValue: input.smoothValue
                )
            )

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
                legendSide: config.seriesLegendSide,
                drawsLabel: drawText
            )
            return .series(entries: series, endpoints: endpoints)
        }
    }

    static func drawContentText(
        context: inout GraphicsContext,
        input: LivelineCompositorInput,
        overlay: LivelineContentOverlay
    ) {
        let config = input.configuration
        let layout = input.layout
        let palette = input.palette
        let reveal = input.reveal

        switch overlay {
        case let .line(livePoint):
            guard config.badge, let livePoint else { return }
            drawBadge(
                context: &context,
                layout: layout,
                palette: palette,
                value: input.smoothValue,
                momentum: resolvedMomentum(config: config, points: input.prepared.primaryVisible),
                y: livePoint.y,
                config: config,
                alpha: reveal
            )
        case let .timeline(geometry, style):
            drawTimelineLabels(
                context: &context,
                geometry: geometry,
                style: style
            )
        case let .heatmap(geometry, style):
            drawHeatmapLabels(
                context: &context,
                layout: layout,
                palette: palette,
                geometry: geometry,
                style: style,
                formatValue: config.formatValue
            )
        case let .radar(geometry, points, style):
            drawRadarLabels(context: &context, palette: palette, geometry: geometry, points: points, style: style)
        case let .donut(geometry, style):
            drawDonutLabels(context: &context, palette: palette, geometry: geometry, style: style, formatValue: config.formatValue)
        case let .gauge(geometry, style):
            drawGaugeLabel(context: &context, palette: palette, geometry: geometry, style: style, formatValue: config.formatValue)
        case let .funnel(geometry, style):
            drawFunnelLabels(context: &context, geometry: geometry, style: style, formatValue: config.formatValue)
        case let .series(_, endpoints):
            drawSeriesEndpoints(
                context: &context,
                endpoints: endpoints,
                alpha: reveal,
                showPulse: false,
                timestamp: input.animationTimestamp,
                legendSide: config.seriesLegendSide,
                drawsDot: false
            )
        case .candle, .standard:
            break
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
        reveal: Double,
        animationTimestamp: TimeInterval
    ) {
        switch overlay {
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

        case .standard:
            drawDiscreteCrosshair(
                context: &context,
                layout: layout,
                palette: palette,
                hover: hover,
                points: prepared.primaryVisible,
                config: configuration,
                alpha: scrubAmount
            )

        case .timeline, .heatmap, .radar, .donut, .gauge, .funnel:
            break
        }

        switch overlay {
        case .timeline, .heatmap, .radar, .donut, .gauge, .funnel:
            break
        default:
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
            alpha: scrubAmount
        )
    }
}
