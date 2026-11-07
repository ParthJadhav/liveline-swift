#!/usr/bin/env bash
# The visual parity release gate. CI and the docs both run this script, so the
# excluded scenarios and the thresholds are defined only here. Extra arguments
# (such as --web-dir, --native-dir and --out-dir) are passed to the diff.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Upstream draws these scenarios' controls inside the plot; Liveline Swift gives
# them their own row, so their layouts differ by design (Docs/ParityStatus.md).
EXCLUSIONS=line-show-value-windows,line-rounded-windows,line-text-windows,candle-mode-controls,multi-basic,multi-light,multi-compact,multi-two-series

exec "$ROOT_DIR/scripts/diff-storybook.sh" \
  --exclude-scenarios "$EXCLUSIONS" \
  --fail-changed-pct 5 \
  --fail-rms 12 \
  --scenario-threshold line-orderbook:5.1:13 \
  "$@"
