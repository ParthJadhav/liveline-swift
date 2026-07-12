#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEMO_DIR="$ROOT_DIR/Examples/LivelineDemo"
DERIVED_DATA="$ROOT_DIR/.build/LivelineDemoShowcaseDerivedData"
BUILD_DIR="$ROOT_DIR/.build/chart-showcase"
MEDIA_DIR="$ROOT_DIR/Media"
RAW_VIDEO="$BUILD_DIR/liveline-chart-showcase-raw.mp4"
VIDEO_PATH="$MEDIA_DIR/liveline-chart-showcase.mp4"
POSTER_PATH="$MEDIA_DIR/liveline-chart-showcase-poster.png"
RECORD_SECONDS="${SHOWCASE_RECORD_SECONDS:-34.5}"
TRIM_START="${SHOWCASE_TRIM_START:-1.0}"

mkdir -p "$BUILD_DIR" "$MEDIA_DIR"

if ! command -v xcodegen >/dev/null 2>&1 \
  && [[ -x "$ROOT_DIR/.build/tools/xcodegen/bin/xcodegen" ]]; then
  export PATH="$ROOT_DIR/.build/tools/xcodegen/bin:$PATH"
fi

for command in xcodegen ffmpeg ffprobe; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to record the chart showcase." >&2
    exit 1
  fi
done

cd "$DEMO_DIR"
xcodegen generate

xcodebuild \
  -project "$DEMO_DIR/LivelineDemo.xcodeproj" \
  -scheme LivelineDemo \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA" \
  build

DEVICE_ID="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/ && /Booted/ { print $2; exit }')"
if [[ -z "${DEVICE_ID:-}" ]]; then
  DEVICE_ID="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/ && /Shutdown/ { print $2; exit }')"
  if [[ -z "${DEVICE_ID:-}" ]]; then
    echo "No available iPhone simulator found." >&2
    exit 1
  fi
  xcrun simctl boot "$DEVICE_ID"
fi
xcrun simctl bootstatus "$DEVICE_ID" -b

APP_PATH="$(find "$DERIVED_DATA/Build/Products/Debug-iphonesimulator" -name 'LivelineDemo.app' -print -quit)"
if [[ -z "${APP_PATH:-}" ]]; then
  echo "Could not locate LivelineDemo.app in derived data." >&2
  exit 1
fi

xcrun simctl install "$DEVICE_ID" "$APP_PATH"
xcrun simctl terminate "$DEVICE_ID" com.liveline.demo >/dev/null 2>&1 || true
xcrun simctl launch "$DEVICE_ID" com.liveline.demo --chart-showcase
sleep 1.2

rm -f "$RAW_VIDEO" "$VIDEO_PATH" "$POSTER_PATH"
xcrun simctl io "$DEVICE_ID" recordVideo --codec=h264 --mask=ignored --force "$RAW_VIDEO" &
RECORD_PID=$!

finish_recording() {
  if kill -0 "$RECORD_PID" >/dev/null 2>&1; then
    kill -INT "$RECORD_PID" >/dev/null 2>&1 || true
    wait "$RECORD_PID" || true
  fi
}

cleanup() {
  finish_recording
  xcrun simctl terminate "$DEVICE_ID" com.liveline.demo >/dev/null 2>&1 || true
}
trap cleanup EXIT

sleep "$RECORD_SECONDS"
finish_recording

ffmpeg \
  -hide_banner \
  -loglevel error \
  -y \
  -noautorotate \
  -i "$RAW_VIDEO" \
  -ss "$TRIM_START" \
  -vf "transpose=2,crop=iw-310:ih:155:0,fps=30,scale=1920:1080:force_original_aspect_ratio=decrease:flags=lanczos,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:color=0x070b14,format=yuv420p" \
  -an \
  -c:v libx264 \
  -preset slow \
  -crf 18 \
  -movflags +faststart \
  -metadata title="Liveline Swift — 18 Chart Showcase" \
  "$VIDEO_PATH"

ffmpeg \
  -hide_banner \
  -loglevel error \
  -y \
  -ss 27.8 \
  -i "$VIDEO_PATH" \
  -frames:v 1 \
  "$POSTER_PATH"

ffprobe \
  -v error \
  -show_entries format=duration,size:stream=codec_name,width,height,r_frame_rate,pix_fmt \
  -of default=noprint_wrappers=1 \
  "$VIDEO_PATH"

echo "Recorded $VIDEO_PATH"
echo "Wrote $POSTER_PATH"
