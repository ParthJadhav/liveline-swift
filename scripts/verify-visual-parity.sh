#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 0 ]]; then
  echo "Usage: scripts/verify-visual-parity.sh (configure directories and scenarios through environment variables)" >&2
  exit 2
fi

cd "$(dirname "$0")/.."

args=(
  --web-dir "${WEB_REFERENCE_OUT_DIR:-Media/web-reference}"
  --native-dir "${STORYBOOK_OUT_DIR:-Media/storybook-chart-only}"
  --out-dir "${VISUAL_DIFF_OUT_DIR:-.build/storybook-diff}"
  --exclude-scenarios line-show-value-windows,line-rounded-windows,line-text-windows,candle-mode-controls,multi-basic,multi-light,multi-compact,multi-two-series
  --fail-changed-pct 5
  --fail-rms 12
)
if [[ -z "${WEB_REFERENCE_SCENARIOS:-}" || " $WEB_REFERENCE_SCENARIOS " == *" line-orderbook "* ]]; then
  args+=(--scenario-threshold line-orderbook:5.1:13)
fi
if [[ -n "${WEB_REFERENCE_SCENARIOS:-}" ]]; then
  read -r -a scenarios <<< "$WEB_REFERENCE_SCENARIOS"
  args+=(--scenarios "${scenarios[@]}")
fi

scripts/diff-storybook.sh "${args[@]}"
