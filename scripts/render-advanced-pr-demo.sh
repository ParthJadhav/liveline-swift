#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "${ADVANCED_PR_CAPTURE_ASSETS:-false}" == true ]]; then
  "$ROOT_DIR/scripts/capture-advanced-pr-demo-assets.sh"
fi

if [[ "${ADVANCED_PR_REGENERATE_MUSIC:-false}" == true ]]; then
  python3 "$ROOT_DIR/remotion/tools/generate-advanced-pr-bgm.py"
fi

cd "$ROOT_DIR/remotion"
bun run verify:advanced-pr
bunx tsc --noEmit
bunx remotion compositions src/index.ts
bun run render:advanced-pr
bun run poster:advanced-pr

echo "Rendered Media/liveline-advanced-charts-pr.mp4 and its poster"
