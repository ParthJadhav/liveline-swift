#!/usr/bin/env bash
# The visual parity release gate. CI and the docs both run this script, so the
# excluded scenarios and the thresholds are defined only here. Extra arguments
# (such as --web-dir, --native-dir and --out-dir) are passed to the diff.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Upstream draws these scenarios' controls inside the plot; Liveline Swift gives
# them their own row, so their layouts differ by design (Docs/ParityStatus.md).
EXCLUSIONS=line-show-value-windows,line-rounded-windows,line-text-windows,candle-mode-controls,multi-basic,multi-light,multi-compact,multi-two-series

args=(
  --exclude-scenarios "$EXCLUSIONS"
  --fail-changed-pct 5
  --fail-rms 12
)
# The diff rejects a threshold for a scenario it has no reference for, and the
# pull-request smoke suite (WEB_REFERENCE_SCENARIOS) leaves the orderbook out.
if [[ -z "${WEB_REFERENCE_SCENARIOS:-}" || " $WEB_REFERENCE_SCENARIOS " == *" line-orderbook "* ]]; then
  args+=(--scenario-threshold line-orderbook:5.1:13)
fi

exec "$ROOT_DIR/scripts/diff-storybook.sh" "${args[@]}" "$@"
