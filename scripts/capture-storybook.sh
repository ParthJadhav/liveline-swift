#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEMO_DIR="$ROOT_DIR/Examples/LivelineDemo"
DERIVED_DATA="$ROOT_DIR/.build/LivelineDemoStorybookDerivedData"
DEFAULT_MEDIA_DIR="$ROOT_DIR/Media/storybook"
CHART_ONLY=false
VALIDATE_ONLY=false
MANIFEST_TOOL="$ROOT_DIR/scripts/storybook_manifest.py"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --chart-only)
      CHART_ONLY=true
      DEFAULT_MEDIA_DIR="$ROOT_DIR/Media/storybook-chart-only"
      ;;
    --validate-only)
      VALIDATE_ONLY=true
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
  shift
done

MEDIA_DIR="${STORYBOOK_OUT_DIR:-$DEFAULT_MEDIA_DIR}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to read the Storybook manifest." >&2
  exit 1
fi

MANIFEST_SCENARIOS=()
while IFS= read -r scenario; do
  MANIFEST_SCENARIOS+=("$scenario")
done < <(python3 "$MANIFEST_TOOL" ids)

SCENARIOS=("${MANIFEST_SCENARIOS[@]}")
if [[ -n "${STORYBOOK_SCENARIOS:-}" ]]; then
  read -r -a SCENARIOS <<< "$STORYBOOK_SCENARIOS"
fi

scenario_is_known() {
  local requested="$1"
  local known
  for known in "${MANIFEST_SCENARIOS[@]}"; do
    if [[ "$known" == "$requested" ]]; then
      return 0
    fi
  done
  return 1
}

if [[ ${#SCENARIOS[@]} -eq 0 ]]; then
  echo "No Storybook scenarios were requested." >&2
  exit 1
fi

for scenario in "${SCENARIOS[@]}"; do
  if ! scenario_is_known "$scenario"; then
    echo "Unknown Storybook scenario ID '$scenario'. Check storybook-scenarios.json." >&2
    exit 1
  fi
done

if [[ "$VALIDATE_ONLY" == true ]]; then
  echo "Validated ${#SCENARIOS[@]} Storybook scenario ID(s)"
  exit 0
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

APP_DATA_DIR="$(xcrun simctl get_app_container "$DEVICE_ID" com.liveline.demo data)"
CAPTURE_STATUS_FILE="$APP_DATA_DIR/Library/Caches/liveline-storybook-capture-status.txt"

for scenario in "${SCENARIOS[@]}"; do
  xcrun simctl terminate "$DEVICE_ID" com.liveline.demo >/dev/null 2>&1 || true
  capture_wait="$(wait_seconds_for "$scenario")"
  capture_token="${scenario}-$$-${RANDOM}-${RANDOM}"
  launch_args=(--storybook-scenario "$scenario")
  if [[ "$CHART_ONLY" == true ]]; then
    launch_args+=(--storybook-chart-only)
  fi
  launch_args+=(--storybook-snapshot-elapsed "$capture_wait")
  launch_args+=(--storybook-capture-token "$capture_token")
  if [[ -n "${STORYBOOK_ORDERBOOK_RANDOM_SEED:-}" ]]; then
    launch_args+=(--storybook-orderbook-seed "$STORYBOOK_ORDERBOOK_RANDOM_SEED")
  fi
  launch_output="$(xcrun simctl launch "$DEVICE_ID" com.liveline.demo "${launch_args[@]}")"

  expected_status="${capture_token}|${scenario}"
  actual_status=""
  scenario_ready=false
  for ((attempt = 0; attempt < 100; attempt += 1)); do
    if [[ -f "$CAPTURE_STATUS_FILE" ]]; then
      actual_status="$(tr -d '\r\n' < "$CAPTURE_STATUS_FILE")"
      if [[ "$actual_status" == "$expected_status" ]]; then
        scenario_ready=true
        break
      fi
      if [[ "$actual_status" == "${capture_token}|ERROR:"* ]]; then
        break
      fi
    fi
    sleep 0.10
  done

  if [[ "$scenario_ready" != true ]]; then
    echo "Storybook scenario '$scenario' did not become ready." >&2
    echo "Launch result: $launch_output" >&2
    echo "App status: ${actual_status:-<none>}" >&2
    exit 1
  fi

  sleep "$(awk -v wait="$capture_wait" 'BEGIN { printf "%.2f", wait + 0.60 }')"
  xcrun simctl io "$DEVICE_ID" screenshot "$MEDIA_DIR/$scenario.png" >/dev/null
  echo "Captured $scenario"
done

echo "Storybook screenshots written to $MEDIA_DIR"
