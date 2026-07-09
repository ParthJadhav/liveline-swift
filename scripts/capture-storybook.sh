#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEMO_DIR="$ROOT_DIR/Examples/LivelineDemo"
DERIVED_DATA="$ROOT_DIR/.build/LivelineDemoStorybookDerivedData"
MEDIA_DIR="$ROOT_DIR/Media/storybook"
CHART_ONLY=false

if [[ "${1:-}" == "--chart-only" ]]; then
  CHART_ONLY=true
  MEDIA_DIR="$ROOT_DIR/Media/storybook-chart-only"
fi

SCENARIOS=(
  line-basic-dark
  line-basic-light
  line-no-grid-no-fill
  line-minimal-badge
  line-no-badge
  line-momentum-up
  line-momentum-down
  line-exaggerated
  line-show-value-windows
  line-rounded-windows
  line-text-windows
  line-reference
  line-orderbook
  line-degen
  line-loading
  line-empty
  candle-basic
  candle-light
  candle-line-mode
  candle-mode-controls
  candle-no-live
  candle-wide-window
  candle-loading
  multi-basic
  multi-light
  multi-compact
  multi-two-series
  bar-basic
  bar-signed
  range-basic
  range-center-line
  scatter-basic
  scatter-connected
  step-basic
  step-centered
  lollipop-basic
  lollipop-diamond
  bubble-basic
  bubble-diameter
  boxplot-basic
  boxplot-minimal
  waterfall-basic
  waterfall-no-connectors
)

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

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is required. Install it with: brew install xcodegen" >&2
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

DEVICE_ID="${STORYBOOK_DEVICE_ID:-}"
if [[ -z "${DEVICE_ID:-}" ]]; then
  DEVICE_ID="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/ && /Booted/ { print $2; exit }')"
fi
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
