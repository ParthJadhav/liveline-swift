#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEMO_DIR="$ROOT_DIR/Examples/LivelineDemo"
DERIVED_DATA="$ROOT_DIR/.build/LivelineDemoDerivedData"
MEDIA_DIR="$ROOT_DIR/Media"
VIDEO_PATH="$MEDIA_DIR/liveline-demo.mp4"

mkdir -p "$MEDIA_DIR"

if ! command -v xcodegen >/dev/null 2>&1 \
  && [[ -x "$ROOT_DIR/.build/tools/xcodegen/bin/xcodegen" ]]; then
  export PATH="$ROOT_DIR/.build/tools/xcodegen/bin:$PATH"
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is required. Install the pinned version with: scripts/install-xcodegen.sh .build/tools/xcodegen" >&2
  exit 1
fi

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
xcrun simctl launch "$DEVICE_ID" com.liveline.demo

rm -f "$VIDEO_PATH"
xcrun simctl io "$DEVICE_ID" recordVideo --codec=h264 --force "$VIDEO_PATH" &
REC_PID=$!
sleep 8
kill -INT "$REC_PID" || true
wait "$REC_PID" || true

echo "Recorded $VIDEO_PATH"
