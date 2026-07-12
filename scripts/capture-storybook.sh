#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEMO_DIR="$ROOT_DIR/Examples/LivelineDemo"
DERIVED_DATA="$ROOT_DIR/.build/LivelineDemoStorybookDerivedData"
DEFAULT_MEDIA_DIR="$ROOT_DIR/Media/storybook"
CHART_ONLY=false
MANIFEST_TOOL="$ROOT_DIR/scripts/storybook_manifest.py"

if [[ "${1:-}" == "--chart-only" ]]; then
  CHART_ONLY=true
  DEFAULT_MEDIA_DIR="$ROOT_DIR/Media/storybook-chart-only"
fi

MEDIA_DIR="${STORYBOOK_OUT_DIR:-$DEFAULT_MEDIA_DIR}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to read the Storybook manifest." >&2
  exit 1
fi

SCENARIOS=()
while IFS= read -r scenario; do
  SCENARIOS+=("$scenario")
done < <(python3 "$MANIFEST_TOOL" ids)

if [[ -n "${STORYBOOK_SCENARIOS:-}" ]]; then
  read -r -a SCENARIOS <<< "$STORYBOOK_SCENARIOS"
fi

DEFAULT_CAPTURE_WAIT_SECONDS="${STORYBOOK_CAPTURE_WAIT_SECONDS:-2.2}"
if [[ -n "${STORYBOOK_SCENARIO_WAIT_OVERRIDES+x}" ]]; then
  SCENARIO_WAIT_OVERRIDES="$STORYBOOK_SCENARIO_WAIT_OVERRIDES"
elif [[ -n "${STORYBOOK_CAPTURE_WAIT_SECONDS+x}" ]]; then
  SCENARIO_WAIT_OVERRIDES=""
else
  SCENARIO_WAIT_OVERRIDES="line-orderbook=3.40 line-loading=2.80 line-empty=2.80 candle-loading=2.80"
fi

wait_seconds_for() {
  local scenario="$1"
  local override
  for override in $SCENARIO_WAIT_OVERRIDES; do
    if [[ "$override" == "$scenario="* ]]; then
      echo "${override#*=}"
      return
    fi
  done
  echo "$DEFAULT_CAPTURE_WAIT_SECONDS"
}

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

xcodebuild -quiet \
  -project "$DEMO_DIR/LivelineDemo.xcodeproj" \
  -scheme LivelineDemo \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA" \
  build

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
  if [[ -z "${DEVICE_ID:-}" ]]; then
    echo "Required Storybook simulator '$DEVICE_NAME' is unavailable. Set STORYBOOK_DEVICE_ID or STORYBOOK_DEVICE_NAME explicitly." >&2
    exit 1
  fi
fi

if ! xcrun simctl list devices available | grep -Fq "$DEVICE_ID"; then
  echo "Storybook simulator '$DEVICE_ID' is unavailable." >&2
  exit 1
fi

if ! xcrun simctl list devices booted | grep -Fq "$DEVICE_ID"; then
  xcrun simctl boot "$DEVICE_ID"
fi
xcrun simctl bootstatus "$DEVICE_ID" -b

APP_PATH="$(find "$DERIVED_DATA/Build/Products/Debug-iphonesimulator" -name 'LivelineDemo.app' -print -quit)"
if [[ -z "${APP_PATH:-}" ]]; then
  echo "Could not locate LivelineDemo.app in derived data." >&2
  exit 1
fi

xcrun simctl install "$DEVICE_ID" "$APP_PATH"

for scenario in "${SCENARIOS[@]}"; do
  xcrun simctl terminate "$DEVICE_ID" com.liveline.demo >/dev/null 2>&1 || true
  capture_wait="$(wait_seconds_for "$scenario")"
  launch_args=(--storybook-scenario "$scenario")
  if [[ "$CHART_ONLY" == true ]]; then
    launch_args+=(--storybook-chart-only)
  fi
  launch_args+=(--storybook-snapshot-elapsed "$capture_wait")
  if [[ -n "${STORYBOOK_ORDERBOOK_RANDOM_SEED:-}" ]]; then
    launch_args+=(--storybook-orderbook-seed "$STORYBOOK_ORDERBOOK_RANDOM_SEED")
  fi
  xcrun simctl launch "$DEVICE_ID" com.liveline.demo "${launch_args[@]}" >/dev/null
  sleep "$(awk -v wait="$capture_wait" 'BEGIN { printf "%.2f", wait + 0.60 }')"
  xcrun simctl io "$DEVICE_ID" screenshot "$MEDIA_DIR/$scenario.png" >/dev/null
  echo "Captured $scenario"
done

echo "Storybook screenshots written to $MEDIA_DIR"
