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
    case standard
    case none
}

struct LivelineCandleOverlay {
    var lineModeProgress: Double
    var linePoints: [CGPoint]
    var smoothValue: Double
    var candles: [LivelineCandle]
    var candleWidth: TimeInterval
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
            drawTimeline(
                context: &context,
                layout: layout,
                palette: palette,
                items: data.filter { $0.end >= layout.leftEdge && $0.start <= layout.rightEdge },
                style: style,
                reveal: reveal,
                drawLabels: drawText
            )
            return .none

        case let .heatmap(data, style):
            drawHeatmap(
                context: &context,
                layout: layout,
                palette: palette,
                cells: data.livelineVisible(in: layout.leftEdge...layout.rightEdge),
                style: style,
                formatValue: config.formatValue,
                reveal: reveal,
                drawLabels: drawText
            )
            return .none

        case let .radar(data, style):
            drawRadar(context: &context, layout: layout, palette: palette, points: data, style: style, reveal: reveal, drawLabels: drawText)
            return .none

        case let .donut(data, style):
            drawDonut(context: &context, layout: layout, palette: palette, data: data, style: style, formatValue: config.formatValue, reveal: reveal, drawLabels: drawText)
            return .none

        case let .gauge(value, range, style):
            drawGauge(context: &context, layout: layout, palette: palette, value: value, range: range, style: style, formatValue: config.formatValue, reveal: reveal, drawLabels: drawText)
            return .none

        case let .funnel(data, style):
            drawFunnel(context: &context, layout: layout, palette: palette, data: data, style: style, formatValue: config.formatValue, reveal: reveal, drawLabels: drawText)
            return .none

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

        switch input.content {
        case .line:
            guard config.badge, case let .line(livePoint) = overlay, let livePoint else { return }
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
        case let .timeline(data, style):
            drawTimeline(
                context: &context,
                layout: layout,
                palette: palette,
                items: data.filter { $0.end >= layout.leftEdge && $0.start <= layout.rightEdge },
                style: style,
                reveal: reveal,
                drawMarks: false
            )
        case let .heatmap(data, style):
            drawHeatmap(
                context: &context,
                layout: layout,
                palette: palette,
                cells: data.livelineVisible(in: layout.leftEdge...layout.rightEdge),
                style: style,
                formatValue: config.formatValue,
                reveal: reveal,
                drawMarks: false
            )
        case let .radar(data, style):
            drawRadar(context: &context, layout: layout, palette: palette, points: data, style: style, reveal: reveal, drawMarks: false)
        case let .donut(data, style):
            drawDonut(context: &context, layout: layout, palette: palette, data: data, style: style, formatValue: config.formatValue, reveal: reveal, drawMarks: false)
        case let .gauge(value, range, style):
            drawGauge(context: &context, layout: layout, palette: palette, value: value, range: range, style: style, formatValue: config.formatValue, reveal: reveal, drawMarks: false)
        case let .funnel(data, style):
            drawFunnel(context: &context, layout: layout, palette: palette, data: data, style: style, formatValue: config.formatValue, reveal: reveal, drawMarks: false)
        case .series:
            guard case let .series(_, endpoints) = overlay else { return }
            drawSeriesEndpoints(
                context: &context,
                endpoints: endpoints,
                alpha: reveal,
                showPulse: false,
                timestamp: input.animationTimestamp,
                legendSide: config.seriesLegendSide,
                drawsDot: false
            )
        default:
            break
        }
    }

    static func drawContentOverlays(
        context: inout GraphicsContext,
        overlay: LivelineContentOverlay,
        layout: LivelineLayout,
        palette: LivelinePalette,
        prepared: LivelinePreparedChart,
        hiddenSeries: Set<String>,
        hover: LivelineHoverPoint?,
        scrubAmount: Double,
        configuration: LivelineChartConfiguration,
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
                    candles: candle.candles,
                    candleWidth: candle.candleWidth,
                    config: configuration,
                    alpha: scrubAmount
                )
            }

        case let .series(series, _):
            drawMultiCrosshair(
                context: &context,
                layout: layout,
                palette: palette,
                series: series,
                hiddenSeries: hiddenSeries,
                hover: hover,
                config: configuration,
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

        case .none:
            break
        }

        if case .none = overlay {
            return
        }
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
}
