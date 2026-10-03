#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

SCENARIOS=(
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

SCREENSHOT_DIR="${ADVANCED_CHART_SCREENSHOT_DIR:-$PWD/Media/storybook-new-charts}"

python3 scripts/storybook_manifest.py validate

if [[ "${1:-}" == "--capture" ]]; then
  scenario_list="${SCENARIOS[*]}"
  STORYBOOK_SCENARIOS="$scenario_list" \
    STORYBOOK_CAPTURE_WAIT_SECONDS="${STORYBOOK_CAPTURE_WAIT_SECONDS:-2.2}" \
    STORYBOOK_OUT_DIR="$SCREENSHOT_DIR" \
    scripts/capture-storybook.sh --chart-only
elif [[ -n "${1:-}" ]]; then
  echo "Usage: scripts/verify-advanced-charts.sh [--capture]" >&2
  exit 2
fi

python3 scripts/chart_visual_quality.py \
  --directory "$SCREENSHOT_DIR" \
  --width "${ADVANCED_CHART_SCREENSHOT_WIDTH:-1206}" \
  --height "${ADVANCED_CHART_SCREENSHOT_HEIGHT:-2622}" \
  --scenarios "${SCENARIOS[@]}"

swift test
swift build -c release
swift build -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors

echo "Advanced chart quality gate passed."
