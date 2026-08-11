#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/.build/LivelineDemoStorybookDerivedData"
LIGHT_ASSET_DIR="$ROOT_DIR/remotion/public/advanced-pr-light"
LIVE_ASSET_DIR="$LIGHT_ASSET_DIR/live"
DITHER_ASSET_DIR="$LIGHT_ASSET_DIR/dither"
RAW_DIR="$ROOT_DIR/.build/advanced-pr-dither-recordings"

SCENARIOS=(
  violin-basic
  ridgeline-basic
  calendar-heatmap-basic
  gantt-basic
  bump-basic
  horizon-basic
  chord-basic
  parallel-basic
  hexbin-basic
  network-basic
  contour-basic
  ternary-basic
  marimekko-basic
  polar-area-basic
  waffle-basic
  volume-profile-basic
  renko-basic
  heikin-ashi-basic
  market-depth-basic
  ohlc-volume-basic
  point-figure-basic
)

mkdir -p "$LIGHT_ASSET_DIR" "$LIVE_ASSET_DIR" "$DITHER_ASSET_DIR" "$RAW_DIR"

STORYBOOK_OUT_DIR="$LIGHT_ASSET_DIR" \
STORYBOOK_SCENARIOS="${SCENARIOS[*]}" \
STORYBOOK_DEMO_LIGHT=true \
  "$ROOT_DIR/scripts/capture-storybook.sh" --chart-only

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg is required to crop the advanced Dither recordings." >&2
  exit 1
fi

DEVICE_ID="${STORYBOOK_DEVICE_ID:-}"
if [[ -z "${DEVICE_ID:-}" ]]; then
  DEVICE_NAME="${STORYBOOK_DEVICE_NAME:-iPhone 17 Pro}"
  DEVICE_ID="$(xcrun simctl list devices available | awk -F '[()]' -v name="$DEVICE_NAME" '
    {
      candidate = $1
      sub(/^[[:space:]]+/, "", candidate)
      sub(/[[:space:]]+$/, "", candidate)
      if (candidate == name) {
        print $2
        exit
      }
    }
  ')"
fi

if [[ -z "${DEVICE_ID:-}" ]]; then
  echo "Could not resolve a simulator for advanced Dither recording." >&2
  exit 1
fi

APP_PATH="$(find "$DERIVED_DATA/Build/Products/Debug-iphonesimulator" -name 'LivelineDemo.app' -print -quit)"
if [[ -z "${APP_PATH:-}" ]]; then
  echo "Could not locate the Storybook app after capture." >&2
  exit 1
fi

xcrun simctl install "$DEVICE_ID" "$APP_PATH"

for scenario in "${SCENARIOS[@]}"; do
  raw_video="$RAW_DIR/$scenario-live-raw.mp4"
  output_video="$LIVE_ASSET_DIR/$scenario.mp4"

  xcrun simctl terminate "$DEVICE_ID" com.liveline.demo >/dev/null 2>&1 || true
  rm -f "$raw_video" "$output_video"
  xcrun simctl launch "$DEVICE_ID" com.liveline.demo \
    --storybook-scenario "$scenario" \
    --storybook-chart-only \
    --advanced-demo-light \
    --advanced-demo-live >/dev/null

  xcrun simctl io "$DEVICE_ID" recordVideo --codec=h264 --mask=ignored --force "$raw_video" &
  record_pid=$!
  sleep 3.2
  kill -INT "$record_pid" >/dev/null 2>&1 || true
  wait "$record_pid" || true

  ffmpeg \
    -hide_banner \
    -loglevel error \
    -y \
    -i "$raw_video" \
    -vf "crop=trunc(iw*0.94/2)*2:trunc(ih*0.32/2)*2:trunc(iw*0.03/2)*2:trunc(ih*0.065/2)*2,fps=30" \
    -an \
    -c:v libx264 \
    -crf 18 \
    -pix_fmt yuv420p \
    "$output_video"

  echo "Recorded native live $scenario"
done

DITHER_SPECS=(
  "violin-basic gradient"
  "chord-basic dotted"
  "contour-basic hatched"
  "market-depth-basic solid"
)

for spec in "${DITHER_SPECS[@]}"; do
  read -r scenario variant <<< "$spec"
  raw_video="$RAW_DIR/$scenario-$variant-raw.mp4"
  output_video="$DITHER_ASSET_DIR/$scenario-$variant.mp4"

  xcrun simctl terminate "$DEVICE_ID" com.liveline.demo >/dev/null 2>&1 || true
  rm -f "$raw_video" "$output_video"
  xcrun simctl launch "$DEVICE_ID" com.liveline.demo \
    --storybook-scenario "$scenario" \
    --storybook-chart-only \
    --advanced-demo-light \
    --advanced-demo-live \
    --advanced-demo-dither \
    --advanced-demo-dither-variant "$variant" >/dev/null
  sleep 1.25

  xcrun simctl io "$DEVICE_ID" recordVideo --codec=h264 --mask=ignored --force "$raw_video" &
  record_pid=$!
  sleep 3.2
  kill -INT "$record_pid" >/dev/null 2>&1 || true
  wait "$record_pid" || true

  ffmpeg \
    -hide_banner \
    -loglevel error \
    -y \
    -i "$raw_video" \
    -vf "crop=trunc(iw*0.94/2)*2:trunc(ih*0.32/2)*2:trunc(iw*0.03/2)*2:trunc(ih*0.065/2)*2,fps=30" \
    -an \
    -c:v libx264 \
    -crf 18 \
    -pix_fmt yuv420p \
    "$output_video"

  echo "Recorded $scenario with the $variant Dither variant"
done

xcrun simctl terminate "$DEVICE_ID" com.liveline.demo >/dev/null 2>&1 || true
echo "Advanced PR demo assets written to $LIGHT_ASSET_DIR"
