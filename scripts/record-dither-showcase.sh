#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEMO_DIR="$ROOT_DIR/Examples/LivelineDemo"
DERIVED_DATA="$ROOT_DIR/.build/LivelineDemoDitherDerivedData"
BUILD_DIR="$ROOT_DIR/.build/dither-showcase"
MEDIA_DIR="$ROOT_DIR/Media/dither"
RAW_VIDEO="$BUILD_DIR/dither-showcase.mp4"
IMAGE_PATH="$MEDIA_DIR/dither-showcase.png"
GIF_PATH="$MEDIA_DIR/dither-showcase.gif"

mkdir -p "$BUILD_DIR" "$MEDIA_DIR"

if ! command -v xcodegen >/dev/null 2>&1 \
  && [[ -x "$ROOT_DIR/.build/tools/xcodegen/bin/xcodegen" ]]; then
  export PATH="$ROOT_DIR/.build/tools/xcodegen/bin:$PATH"
fi

for command in xcodegen ffmpeg; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required to record the dither showcase." >&2
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
  xcrun simctl boot "$DEVICE_ID"
fi
xcrun simctl bootstatus "$DEVICE_ID" -b

APP_PATH="$(find "$DERIVED_DATA/Build/Products/Debug-iphonesimulator" -name 'LivelineDemo.app' -print -quit)"
xcrun simctl install "$DEVICE_ID" "$APP_PATH"
xcrun simctl terminate "$DEVICE_ID" com.liveline.demo >/dev/null 2>&1 || true
xcrun simctl launch "$DEVICE_ID" com.liveline.demo --dither-showcase
sleep 2
xcrun simctl io "$DEVICE_ID" screenshot "$IMAGE_PATH"

rm -f "$RAW_VIDEO" "$GIF_PATH"
xcrun simctl io "$DEVICE_ID" recordVideo --codec=h264 --mask=ignored --force "$RAW_VIDEO" &
RECORD_PID=$!
sleep 5
kill -INT "$RECORD_PID" >/dev/null 2>&1 || true
wait "$RECORD_PID" || true

ffmpeg \
  -hide_banner \
  -loglevel error \
  -y \
  -i "$RAW_VIDEO" \
  -vf "fps=15,scale=585:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer" \
  "$GIF_PATH"

xcrun simctl terminate "$DEVICE_ID" com.liveline.demo >/dev/null 2>&1 || true
echo "Wrote $IMAGE_PATH"
echo "Wrote $GIF_PATH"
