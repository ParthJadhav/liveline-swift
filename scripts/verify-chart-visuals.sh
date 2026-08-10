#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CAPTURE=false
CAPTURE_DIR="${CHART_VISUAL_CAPTURE_DIR:-$ROOT_DIR/.build/chart-visual-quality}"

if [[ "$CAPTURE_DIR" != /* ]]; then
  CAPTURE_DIR="$ROOT_DIR/$CAPTURE_DIR"
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --capture)
      CAPTURE=true
      ;;
    *)
      echo "Usage: scripts/verify-chart-visuals.sh [--capture]" >&2
      exit 2
      ;;
  esac
  shift
done

cd "$ROOT_DIR"
python3 scripts/storybook_manifest.py validate

if [[ "$CAPTURE" == true ]]; then
  mkdir -p "$CAPTURE_DIR"
  STORYBOOK_OUT_DIR="$CAPTURE_DIR" scripts/capture-storybook.sh --chart-only
  python3 scripts/chart_visual_quality.py --directory "$CAPTURE_DIR"
else
  python3 scripts/chart_visual_quality.py
fi

echo "Chart visual screenshot contract passed."
