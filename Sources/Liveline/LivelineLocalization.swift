import Foundation

/// Every user-facing string Liveline can emit — VoiceOver phrasing, tooltip
/// row labels, control chrome, and the default empty-state text.
///
/// The package ships no string table of its own. Each entry pairs a stable key
/// with the English default, and `String(localized:defaultValue:bundle:)`
/// returns that default whenever the bundle has no translation for the key, so
/// English output is unchanged. Shipping a `Localizable` table in the package
/// bundle is all it takes to translate Liveline; no source change is needed.
///
/// Entries are `static let` so the bundle lookup happens once per process
/// rather than once per formatted datum — the accessibility model formats one
/// string per data point, and these labels sit directly in that loop. The cost
/// is that a language change is picked up on the next launch, which is how the
/// system delivers language changes to an app anyway.
enum LivelineStrings {

    // MARK: - Chart kinds

    static let chartKindLine = localized("chart.kind.line", "Line chart", "VoiceOver name for a line chart")
    static let chartKindBars = localized("chart.kind.bars", "Bar chart", "VoiceOver name for a bar chart")
    static let chartKindRange = localized("chart.kind.range", "Range chart", "VoiceOver name for a range chart")
    static let chartKindScatter = localized("chart.kind.scatter", "Scatter chart", "VoiceOver name for a scatter chart")
    static let chartKindSteps = localized("chart.kind.steps", "Step chart", "VoiceOver name for a step chart")
    static let chartKindLollipops = localized("chart.kind.lollipops", "Lollipop chart", "VoiceOver name for a lollipop chart")
    static let chartKindBubbles = localized("chart.kind.bubbles", "Bubble chart", "VoiceOver name for a bubble chart")
    static let chartKindBoxPlots = localized("chart.kind.boxPlots", "Box plot chart", "VoiceOver name for a box plot chart")
    static let chartKindWaterfall = localized("chart.kind.waterfall", "Waterfall chart", "VoiceOver name for a waterfall chart")
    static let chartKindErrorBars = localized("chart.kind.errorBars", "Error bar chart", "VoiceOver name for an error bar chart")
    static let chartKindDumbbells = localized("chart.kind.dumbbells", "Dumbbell chart", "VoiceOver name for a dumbbell chart")
    static let chartKindStackedBars = localized("chart.kind.stackedBars", "Stacked bar chart", "VoiceOver name for a stacked bar chart")
    static let chartKindStackedAreas = localized("chart.kind.stackedAreas", "Stacked area chart", "VoiceOver name for a stacked area chart")
    static let chartKindTimeline = localized("chart.kind.timeline", "Timeline chart", "VoiceOver name for a timeline chart")
    static let chartKindHeatmap = localized("chart.kind.heatmap", "Heatmap chart", "VoiceOver name for a heatmap chart")
    static let chartKindRadar = localized("chart.kind.radar", "Radar chart", "VoiceOver name for a radar chart")
    static let chartKindDonut = localized("chart.kind.donut", "Donut chart", "VoiceOver name for a donut chart")
    static let chartKindGauge = localized("chart.kind.gauge", "Gauge chart", "VoiceOver name for a gauge chart")
    static let chartKindFunnel = localized("chart.kind.funnel", "Funnel chart", "VoiceOver name for a funnel chart")
    static let chartKindHistogram = localized("chart.kind.histogram", "Histogram", "VoiceOver name for a histogram")
    static let chartKindBullet = localized("chart.kind.bullet", "Bullet chart", "VoiceOver name for a bullet chart")
    static let chartKindCandle = localized("chart.kind.candle", "Candlestick chart", "VoiceOver name for a candlestick chart")
    static let chartKindSeries = localized("chart.kind.series", "Multi-series chart", "VoiceOver name for a chart with several series")

    // MARK: - Shared labels
    //
    // Used both as tooltip row labels and as Audio Graph series names.

    static let labelValue = localized("label.value", "Value", "Label for a datum's primary value")
    static let labelLower = localized("label.lower", "Lower", "Label for the lower bound of a range")
    static let labelUpper = localized("label.upper", "Upper", "Label for the upper bound of a range")
    static let labelMagnitude = localized("label.magnitude", "Magnitude", "Label for a bubble's magnitude")
    static let labelMinimum = localized("label.minimum", "Minimum", "Label for the smallest value in a box plot")
    static let labelMaximum = localized("label.maximum", "Maximum", "Label for the largest value in a box plot")
    static let labelMedian = localized("label.median", "Median", "Label for the median of a box plot")
    static let labelLowerQuartile = localized("label.lowerQuartile", "Q1", "Short tooltip label for the first quartile")
    static let labelUpperQuartile = localized("label.upperQuartile", "Q3", "Short tooltip label for the third quartile")
    static let labelFirstQuartile = localized("label.firstQuartile", "First quartile", "Audio Graph series name for the first quartile")
    static let labelThirdQuartile = localized("label.thirdQuartile", "Third quartile", "Audio Graph series name for the third quartile")
    static let labelStart = localized("label.start", "Start", "Label for the starting value or moment of a datum")
    static let labelEnd = localized("label.end", "End", "Label for the ending value or moment of a datum")
    static let labelChange = localized("label.change", "Change", "Label for a waterfall step's delta")
    static let labelDuration = localized("label.duration", "Duration", "Label for the length of a timeline item")
    static let labelTotal = localized("label.total", "Total", "Label for the sum of the stacked values at one moment")
    static let labelShare = localized("label.share", "Share", "Label for a donut segment's percentage of the whole")
    static let labelTarget = localized("label.target", "Target", "Label for a gauge's target value")
    static let labelOpen = localized("label.open", "Open", "Label for a candle's opening price")
    static let labelHigh = localized("label.high", "High", "Label for a candle's highest price")
    static let labelLow = localized("label.low", "Low", "Label for a candle's lowest price")
    static let labelClose = localized("label.close", "Close", "Label for a candle's closing price")
    static let labelPrice = localized("label.price", "Price", "Audio Graph series name for a price series")
    static let labelTime = localized("label.time", "Time", "Audio Graph axis title for the time axis")
    static let labelCategory = localized("label.category", "Category", "Audio Graph axis title for a categorical axis")
    static let labelGauge = localized("label.gauge", "Gauge", "Tooltip heading for a gauge")
    static let labelCount = localized("label.count", "Count", "Label for the number of samples in a histogram bin")
    static let labelMeasure = localized("label.measure", "Measure", "Label for the value a bullet chart reports")
    static let labelBullet = localized("label.bullet", "Bullet", "Tooltip heading for a bullet chart")
    static let labelGaugeValue = localized("label.gaugeValue", "Gauge value", "Label for the value a gauge is showing")

    /// A histogram bin's value interval. `%1$@` is the lower bound, `%2$@` the
    /// upper bound.
    static let labelBinRangeFormat = localized("label.binRange.format", "%1$@ to %2$@", "Tooltip heading naming a histogram bin's value interval")

    /// Number of samples in a histogram bin. `%ld` is the count.
    static let labelSampleCountFormat = localized("label.sampleCount.format", "%ld values", "Tooltip and VoiceOver phrase for how many samples fell in a histogram bin; %ld is the count")

    /// Fallback name for a bullet band the caller did not label. `%ld` is the
    /// one-based band number.
    static let labelBandFormat = localized("label.band.format", "Band %ld", "Fallback name for an unlabelled bullet chart band; %ld is the band number")

    /// Fallback name for a heatmap row the caller did not label. `%ld` is the
    /// one-based row number.
    static let labelRowFormat = localized("label.row.format", "Row %ld", "Fallback name for an unlabelled heatmap row; %ld is the row number")

    /// Fallback name for a stacked or multi-series slot the caller did not
    /// label. `%ld` is the one-based series number.
    static let labelSeriesFormat = localized("label.series.format", "Series %ld", "Fallback name for an unlabelled series; %ld is the series number")

    // MARK: - Accessibility summary and hints

    static let accessibilityHintLoading = localized("accessibility.hint.loading", "Chart data is loading.", "VoiceOver hint while the chart is loading")
    static let accessibilityHintEmpty = localized("accessibility.hint.empty", "No chart data is available.", "VoiceOver hint when the chart has no data")
    static let accessibilityHintAdjustable = localized("accessibility.hint.adjustable", "Adjust to inspect data points.", "VoiceOver hint telling the user they can swipe through the data")
    static let accessibilitySummaryLoading = localized("accessibility.summary.loading", "Loading chart data", "VoiceOver summary while the chart is loading")

    static let accessibilityCountOne = localized("accessibility.count.one", "1 data point", "VoiceOver phrase for a chart holding a single datum")
    /// `%ld` is the number of data points, always two or more.
    static let accessibilityCountOtherFormat = localized("accessibility.count.other.format", "%ld data points", "VoiceOver phrase for a chart holding several data points; %ld is the count")

    /// `%1$@` is the chart summary, `%2$@` the data point count phrase.
    static let accessibilitySummaryWithCountFormat = localized("accessibility.summaryWithCount.format", "%1$@. %2$@", "Joins the VoiceOver chart summary with the data point count")

    /// `%1$@` is the entry label, `%2$@` its value, `%3$ld` the one-based
    /// position and `%4$ld` the total number of entries.
    static let accessibilityEntryFormat = localized("accessibility.entry.format", "%1$@, %2$@, %3$ld of %4$ld", "VoiceOver announcement for one datum and its position in the chart")

    /// `%@` is the formatted current value.
    static let accessibilityCurrentValueFormat = localized("accessibility.currentValue.format", "Current value %@", "VoiceOver summary for a chart with no clear trend")
    static let accessibilityCurrentValueUpFormat = localized("accessibility.currentValue.up.format", "Current value %@, trending up", "VoiceOver summary for a chart trending upwards")
    static let accessibilityCurrentValueDownFormat = localized("accessibility.currentValue.down.format", "Current value %@, trending down", "VoiceOver summary for a chart trending downwards")

    // MARK: - Accessibility entry values

    /// `%1$ld` is the one-based series number, `%2$@` its formatted value.
    static let accessibilityStackedSeriesFormat = localized("accessibility.stacked.series.format", "Series %1$ld %2$@", "VoiceOver phrase for one slot of a stacked datum")
    /// `%1$@` is the per-series phrase list, `%2$@` the formatted total.
    static let accessibilityStackedValueFormat = localized("accessibility.stacked.value.format", "%1$@, total %2$@", "VoiceOver value for a stacked datum")

    /// `%1$@` is the lower bound, `%2$@` the upper bound.
    static let accessibilityRangeValueFormat = localized("accessibility.range.value.format", "Lower %1$@, upper %2$@", "VoiceOver value for a range datum")

    /// `%1$@` is the value, `%2$@` the magnitude.
    static let accessibilityBubbleValueFormat = localized("accessibility.bubble.value.format", "Value %1$@, magnitude %2$@", "VoiceOver value for a bubble datum")

    static let accessibilityBoxMinimumFormat = localized("accessibility.box.minimum.format", "Minimum %@", "VoiceOver phrase for a box plot's smallest value")
    static let accessibilityBoxLowerQuartileFormat = localized("accessibility.box.lowerQuartile.format", "first quartile %@", "VoiceOver phrase for a box plot's first quartile, spoken mid-sentence")
    static let accessibilityBoxMedianFormat = localized("accessibility.box.median.format", "median %@", "VoiceOver phrase for a box plot's median, spoken mid-sentence")
    static let accessibilityBoxUpperQuartileFormat = localized("accessibility.box.upperQuartile.format", "third quartile %@", "VoiceOver phrase for a box plot's third quartile, spoken mid-sentence")
    static let accessibilityBoxMaximumFormat = localized("accessibility.box.maximum.format", "maximum %@", "VoiceOver phrase for a box plot's largest value, spoken mid-sentence")

    /// `%1$@` is the step's delta, `%2$@` the running total after it.
    static let accessibilityWaterfallValueFormat = localized("accessibility.waterfall.value.format", "Change %1$@, total %2$@", "VoiceOver value for a waterfall step")

    /// `%1$@` is the value, `%2$@` the lower bound, `%3$@` the upper bound.
    static let accessibilityErrorBarValueFormat = localized("accessibility.errorBar.value.format", "Value %1$@, lower %2$@, upper %3$@", "VoiceOver value for an error bar datum")

    /// `%1$@` is the starting value, `%2$@` the ending value.
    static let accessibilityDumbbellValueFormat = localized("accessibility.dumbbell.value.format", "Start %1$@, end %2$@", "VoiceOver value for a dumbbell datum")

    /// `%1$@` is the start time, `%2$@` the end time, `%3$@` the duration.
    static let accessibilityTimelineValueFormat = localized("accessibility.timeline.value.format", "Start %1$@, end %2$@, duration %3$@", "VoiceOver value for a timeline item")

    /// `%1$@` is the row name, `%2$@` the formatted time of the cell.
    static let accessibilityHeatmapLabelFormat = localized("accessibility.heatmap.label.format", "%1$@, %2$@", "VoiceOver label for a heatmap cell")

    /// `%1$@` is the formatted value, `%2$@` its share of the whole.
    static let accessibilityDonutValueFormat = localized("accessibility.donut.value.format", "%1$@, %2$@ percent", "VoiceOver value for a donut segment")

    /// `%1$@` is the formatted value, `%2$@` the target.
    static let accessibilityGaugeTargetFormat = localized("accessibility.gauge.target.format", "%1$@, target %2$@", "VoiceOver phrase adding a gauge's target to its value")

    /// `%1$@` is the value phrase, `%2$@` the range's lower bound, `%3$@` its
    /// upper bound.
    static let accessibilityGaugeValueFormat = localized("accessibility.gauge.value.format", "%1$@, range %2$@ to %3$@", "VoiceOver value for a gauge")

    /// `%1$@` is the measure, `%2$@` the band's upper bound.
    static let accessibilityBulletBandValueFormat = localized("accessibility.bullet.band.value.format", "Up to %1$@", "VoiceOver value for one qualitative band of a bullet chart; %1$@ is the band's upper bound")

    /// `%1$@` is the measure, `%2$@` the target.
    static let accessibilityBulletTargetFormat = localized("accessibility.bullet.target.format", "%1$@ of target %2$@", "VoiceOver phrase comparing a bullet chart's measure to its target")

    /// `%1$@` is the measure phrase, `%2$@` the name of the band it falls in.
    static let accessibilityBulletRangeFormat = localized("accessibility.bullet.range.format", "%1$@, in '%2$@' range", "VoiceOver phrase naming the band a bullet chart's measure falls in")

    /// `%1$@` open, `%2$@` high, `%3$@` low, `%4$@` close.
    static let accessibilityCandleValueFormat = localized("accessibility.candle.value.format", "Open %1$@, high %2$@, low %3$@, close %4$@", "VoiceOver value for a candle")

    // MARK: - Controls

    static let controlShowSummary = localized("control.action.showSummary", "Show chart summary", "VoiceOver custom action returning from a datum to the chart summary")
    static let controlSelected = localized("control.state.selected", "Selected", "VoiceOver value for the active window or mode button")
    static let controlNotSelected = localized("control.state.notSelected", "Not selected", "VoiceOver value for an inactive window or mode button")
    static let controlModeLine = localized("control.mode.line", "Line", "VoiceOver label for the line mode button")
    static let controlModeCandle = localized("control.mode.candle", "Candle", "VoiceOver label for the candle mode button")
    static let controlSeriesVisible = localized("control.series.visible", "Visible", "VoiceOver value for a shown series")
    static let controlSeriesVisibleRequired = localized("control.series.visibleRequired", "Visible, required", "VoiceOver value for the last remaining shown series")
    static let controlSeriesHidden = localized("control.series.hidden", "Hidden", "VoiceOver value for a hidden series")
    static let controlSeriesHintHide = localized("control.series.hint.hide", "Hides this series", "VoiceOver hint for the toggle of a shown series")
    static let controlSeriesHintShow = localized("control.series.hint.show", "Shows this series", "VoiceOver hint for the toggle of a hidden series")
    static let controlSeriesHintLocked = localized("control.series.hint.locked", "At least one series must remain visible", "VoiceOver hint for the toggle of the last remaining shown series")

    // MARK: - Configuration defaults

    /// Default `emptyText`, surfaced publicly by `LivelineLocalizedDefaults`.
    static let emptyChart = localized("configuration.emptyText.default", "No data to display", "Placeholder drawn in place of a chart that has no data")

    private static func localized(
        _ key: StaticString,
        _ defaultValue: String.LocalizationValue,
        _ comment: StaticString
    ) -> String {
        String(localized: key, defaultValue: defaultValue, bundle: .module, comment: comment)
    }
}

/// Namespace for the handful of localized strings that public API exposes as
/// default argument values. Default arguments are evaluated at the call site,
/// so they can only reference public declarations.
public enum LivelineLocalizedDefaults {
    /// The English default is `"No data to display"`.
    public static var emptyText: String { LivelineStrings.emptyChart }
}
