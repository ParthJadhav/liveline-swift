import SwiftUI

/// One swatch-and-label row of a ``LivelineLegend``.
public struct LivelineLegendItem: Identifiable, Hashable {
    public var id: String
    public var label: String
    public var color: Color

    /// Creates an item with an explicit identity, which is what a series-backed
    /// legend uses so two series can share a display name.
    public init(id: String, label: String, color: Color) {
        self.id = id
        self.label = label
        self.color = color
    }

    /// Creates an item identified by its own label.
    public init(label: String, color: Color) {
        self.init(id: label, label: label, color: color)
    }
}

public extension LivelineLegendItem {
    /// The accent Liveline charts use when the caller does not pick one.
    static let defaultAccent = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255)

    /// Derives legend items from multi-series chart content.
    ///
    /// Each series keeps its own color, and falls back to its identifier when
    /// it carries no label — the same rule the chart's own endpoint labels use.
    static func items(series: [LivelineSeries]) -> [LivelineLegendItem] {
        series.map { entry in
            LivelineLegendItem(
                id: entry.id,
                label: entry.label ?? entry.id,
                color: entry.color
            )
        }
    }

    /// Derives legend items from donut chart content.
    ///
    /// Colors are resolved exactly as the donut renderer resolves them: the
    /// style's palette when it supplies one, otherwise the chart accent for the
    /// first slice and the built-in categorical palette for the rest.
    static func items(
        donut categories: [LivelineCategoryValue],
        style: LivelineDonutStyle = LivelineDonutStyle(),
        accent: Color = LivelineLegendItem.defaultAccent
    ) -> [LivelineLegendItem] {
        items(categories: categories, colors: style.colors, accent: accent)
    }

    /// Derives legend items from funnel chart content, resolving colors the way
    /// the funnel renderer does.
    static func items(
        funnel stages: [LivelineCategoryValue],
        style: LivelineFunnelStyle = LivelineFunnelStyle(),
        accent: Color = LivelineLegendItem.defaultAccent
    ) -> [LivelineLegendItem] {
        items(categories: stages, colors: style.colors, accent: accent)
    }

    /// Derives legend items for a stacked bar or area chart, whose data model
    /// carries values per slot but no slot names, so the labels come from the
    /// caller.
    static func items(
        stacked labels: [String],
        colors: [Color] = [],
        accent: Color = LivelineLegendItem.defaultAccent
    ) -> [LivelineLegendItem] {
        labels.enumerated().map { index, label in
            LivelineLegendItem(
                id: "\(index)-\(label)",
                label: label,
                color: resolvedColor(index: index, colors: colors, accent: accent)
            )
        }
    }

    private static func items(
        categories: [LivelineCategoryValue],
        colors: [Color],
        accent: Color
    ) -> [LivelineLegendItem] {
        categories.enumerated().map { index, category in
            LivelineLegendItem(
                id: category.id,
                label: category.label,
                color: resolvedColor(index: index, colors: colors, accent: accent)
            )
        }
    }

    private static func resolvedColor(index: Int, colors: [Color], accent: Color) -> Color {
        if !colors.isEmpty { return colors[index % colors.count] }
        if index == 0 { return accent }
        return LivelineRenderer.extendedDefaultColors[index % LivelineRenderer.extendedDefaultColors.count]
    }
}

/// The direction a ``LivelineLegend`` lays its rows out in.
public enum LivelineLegendAxis: String, CaseIterable, Sendable {
    /// Rows sit side by side, wrapping onto further lines when the legend runs
    /// out of width.
    case horizontal
    /// Rows stack top to bottom.
    case vertical
}

/// The shape of a ``LivelineLegend`` swatch.
public enum LivelineLegendSwatch: String, CaseIterable, Sendable {
    case circle
    case roundedSquare
    case line
}

/// A standalone key for the colors a chart draws with.
///
/// `LivelineChart` draws its own multi-series endpoint labels, but a dashboard
/// often wants one shared key beside — or beneath — several charts. The legend
/// is an ordinary SwiftUI view built from `Text` and `Shape`, so it picks up
/// Dynamic Type, and each row is a single accessibility element announcing its
/// label.
///
/// ```swift
/// VStack {
///     LivelineChart(series: series)
///     LivelineLegend(series: series)
/// }
/// ```
///
/// Colors follow the chart's own theme model: `.automatic` resolves against the
/// environment's `colorScheme`, and the explicit modes ignore it.
public struct LivelineLegend: View {
    private let items: [LivelineLegendItem]
    private let axis: LivelineLegendAxis
    private let swatch: LivelineLegendSwatch
    private let theme: LivelineThemeMode

    @Environment(\.colorScheme) private var colorScheme

    /// Creates a legend from explicit items.
    public init(
        items: [LivelineLegendItem],
        axis: LivelineLegendAxis = .horizontal,
        swatch: LivelineLegendSwatch = .circle,
        theme: LivelineThemeMode = .automatic
    ) {
        self.items = items
        self.axis = axis
        self.swatch = swatch
        self.theme = theme
    }

    /// Creates a legend from the same series content a multi-series
    /// ``LivelineChart`` takes.
    public init(
        series: [LivelineSeries],
        axis: LivelineLegendAxis = .horizontal,
        swatch: LivelineLegendSwatch = .circle,
        theme: LivelineThemeMode = .automatic
    ) {
        self.init(
            items: LivelineLegendItem.items(series: series),
            axis: axis,
            swatch: swatch,
            theme: theme
        )
    }

    /// Creates a legend from donut chart content.
    public init(
        donut categories: [LivelineCategoryValue],
        style: LivelineDonutStyle = LivelineDonutStyle(),
        accent: Color = LivelineLegendItem.defaultAccent,
        axis: LivelineLegendAxis = .vertical,
        swatch: LivelineLegendSwatch = .circle,
        theme: LivelineThemeMode = .automatic
    ) {
        self.init(
            items: LivelineLegendItem.items(donut: categories, style: style, accent: accent),
            axis: axis,
            swatch: swatch,
            theme: theme
        )
    }

    /// Creates a legend from funnel chart content.
    public init(
        funnel stages: [LivelineCategoryValue],
        style: LivelineFunnelStyle = LivelineFunnelStyle(),
        accent: Color = LivelineLegendItem.defaultAccent,
        axis: LivelineLegendAxis = .vertical,
        swatch: LivelineLegendSwatch = .circle,
        theme: LivelineThemeMode = .automatic
    ) {
        self.init(
            items: LivelineLegendItem.items(funnel: stages, style: style, accent: accent),
            axis: axis,
            swatch: swatch,
            theme: theme
        )
    }

    public var body: some View {
        let labelColor = resolvedLabelColor
        switch axis {
        case .horizontal:
            // A wrapping row keeps a wide key usable at accessibility type
            // sizes, where a fixed HStack would clip its trailing entries.
            LivelineLegendWrap(spacing: 14, rowSpacing: 6) {
                ForEach(items) { item in
                    row(item, labelColor: labelColor)
                }
            }
        case .vertical:
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items) { item in
                    row(item, labelColor: labelColor)
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ item: LivelineLegendItem, labelColor: Color) -> some View {
        HStack(spacing: 6) {
            swatchView(item.color)
            Text(item.label)
                .font(.caption)
                .foregroundColor(labelColor)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.label)
    }

    @ViewBuilder
    private func swatchView(_ color: Color) -> some View {
        switch swatch {
        case .circle:
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
        case .roundedSquare:
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 9, height: 9)
        case .line:
            Capsule()
                .fill(color)
                .frame(width: 14, height: 2.5)
        }
    }

    private var resolvedLabelColor: Color {
        let mode = theme.resolved(colorScheme: colorScheme)
        return LivelinePalette
            .resolve(accent: .clear, mode: mode, lineWidth: 1)
            .tooltipText
    }
}

/// Lays subviews out left to right, wrapping to a new line when the proposed
/// width runs out. `Layout` is available on every platform Liveline supports,
/// so no availability gate is needed.
private struct LivelineLegendWrap: Layout {
    var spacing: CGFloat
    var rowSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maximumWidth = proposal.width ?? .infinity
        let rows = arrange(subviews: subviews, maximumWidth: maximumWidth)
        guard !rows.isEmpty else { return .zero }
        let width = rows.map(\.width).max() ?? 0
        let height = rows.reduce(0) { $0 + $1.height } + rowSpacing * CGFloat(rows.count - 1)
        return CGSize(width: maximumWidth.isFinite ? min(width, maximumWidth) : width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews: subviews, maximumWidth: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for entry in row.entries {
                subviews[entry.index].place(
                    at: CGPoint(x: x, y: y + (row.height - entry.size.height) / 2),
                    proposal: ProposedViewSize(entry.size)
                )
                x += entry.size.width + spacing
            }
            y += row.height + rowSpacing
        }
    }

    private struct Row {
        var entries: [(index: Int, size: CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, maximumWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let advance = row.entries.isEmpty ? size.width : row.width + spacing + size.width
            if !row.entries.isEmpty, advance > maximumWidth {
                rows.append(row)
                row = Row()
            }
            row.entries.append((index, size))
            row.width = row.entries.count == 1 ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
        }
        if !row.entries.isEmpty { rows.append(row) }
        return rows
    }
}
