#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DITHER_DIR="$ROOT_DIR/Media/storybook-dither"
ADVANCED_DIR="$ROOT_DIR/Media/storybook-new-charts"
REVIEW_DIR="$ROOT_DIR/Media/advanced-chart-review"

CORE_SCENARIOS=(
  line-basic-dark
  candle-basic
  multi-basic
  bar-basic
  range-basic
  scatter-basic
  step-basic
  lollipop-basic
  bubble-basic
  boxplot-basic
  waterfall-basic
  errorbar-basic
  dumbbell-basic
  stackedbar-basic
  stackedarea-basic
  timeline-basic
  heatmap-basic
  radar-basic
  donut-basic
  gauge-basic
  funnel-basic
  stacked-area-stream
  histogram-basic
  bullet-basic
  treemap-basic
  sunburst-basic
  sankey-basic
)

ADVANCED_SCENARIOS=(
  violin-basic
  ridgeline-basic
  calendar-heatmap-basic
  gantt-basic
  chord-basic
  parallel-basic
  hexbin-basic
  bump-basic
  horizon-basic
  marimekko-basic
  polar-area-basic
  network-basic
  contour-basic
  ternary-basic
  waffle-basic
  volume-profile-basic
  renko-basic
  heikin-ashi-basic
  market-depth-basic
  ohlc-volume-basic
  point-figure-basic
)

SCENARIOS=("${CORE_SCENARIOS[@]}" "${ADVANCED_SCENARIOS[@]}")

# Use multiple ordered textures across the public gallery while keeping each
# scenario deterministic. Dither remains an interior fill treatment in every
# variant; readability-critical outlines and strokes stay solid.
DITHER_VARIANTS="\
line-basic-dark=gradient candle-basic=hatched multi-basic=gradient \
bar-basic=hatched range-basic=dotted scatter-basic=dotted step-basic=gradient \
lollipop-basic=dotted bubble-basic=dotted boxplot-basic=hatched \
waterfall-basic=hatched errorbar-basic=dotted dumbbell-basic=dotted \
stackedbar-basic=hatched stackedarea-basic=gradient timeline-basic=hatched \
heatmap-basic=dotted radar-basic=gradient donut-basic=dotted gauge-basic=hatched \
funnel-basic=gradient stacked-area-stream=gradient histogram-basic=hatched \
bullet-basic=hatched treemap-basic=dotted sunburst-basic=gradient sankey-basic=gradient \
violin-basic=gradient ridgeline-basic=gradient calendar-heatmap-basic=dotted \
gantt-basic=hatched chord-basic=dotted parallel-basic=gradient hexbin-basic=dotted \
bump-basic=gradient horizon-basic=gradient marimekko-basic=hatched \
polar-area-basic=dotted network-basic=dotted contour-basic=hatched \
ternary-basic=dotted waffle-basic=hatched volume-profile-basic=gradient \
renko-basic=hatched heikin-ashi-basic=hatched market-depth-basic=gradient \
ohlc-volume-basic=hatched point-figure-basic=dotted"

mkdir -p "$DITHER_DIR" "$ADVANCED_DIR" "$REVIEW_DIR"

STORYBOOK_OUT_DIR="$DITHER_DIR" \
STORYBOOK_SCENARIOS="${SCENARIOS[*]}" \
STORYBOOK_DEMO_LIGHT=true \
STORYBOOK_DEMO_DITHER=true \
STORYBOOK_DITHER_VARIANT_OVERRIDES="$DITHER_VARIANTS" \
  "$ROOT_DIR/scripts/capture-storybook.sh" --chart-only

python3 "$ROOT_DIR/scripts/chart_visual_quality.py" \
  --directory "$DITHER_DIR" \
  --scenarios "${SCENARIOS[@]}"

for scenario in "${ADVANCED_SCENARIOS[@]}"; do
  cp "$DITHER_DIR/$scenario.png" "$ADVANCED_DIR/$scenario.png"
done

README_CHART_SOURCE_DIR="$DITHER_DIR" python3 "$ROOT_DIR/scripts/build-readme-media.py"

"$ROOT_DIR/scripts/build-chart-review-board.sh" \
  --directory "$ADVANCED_DIR" \
  --out-dir "$REVIEW_DIR" \
  --columns 3 \
  --rows 4 \
  --scenarios "${ADVANCED_SCENARIOS[@]}"

echo "Captured 48 Dither chart families and rebuilt GitHub image galleries."
