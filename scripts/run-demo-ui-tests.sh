#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: scripts/run-demo-ui-tests.sh <runtime-major|latest> <artifact-dir> <artifact-name>" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/Examples/LivelineDemo/LivelineDemo.xcodeproj"
RUNTIME_MAJOR="$1"
ARTIFACT_DIR="$2"
ARTIFACT_NAME="$3"
TEMP_ROOT="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
DERIVED_DATA="$TEMP_ROOT/LivelineDemoUITestDerivedData-$ARTIFACT_NAME"

mkdir -p "$ARTIFACT_DIR"
xcrun simctl list devices available -j > "$ARTIFACT_DIR/devices.json"

python3 - \
  "$ARTIFACT_DIR/devices.json" \
  "$ARTIFACT_DIR/destination.txt" \
  "$RUNTIME_MAJOR" <<'PY'
import json
import pathlib
import re
import sys

source = pathlib.Path(sys.argv[1])
destination = pathlib.Path(sys.argv[2])
requested_major = sys.argv[3]
payload = json.loads(source.read_text())
candidates = []
for runtime_id, devices in payload.get("devices", {}).items():
    match = re.search(r"SimRuntime\.iOS-(\d+)(?:-(\d+))?", runtime_id)
    if not match:
        continue
    version = (int(match.group(1)), int(match.group(2) or 0))
    for device in devices:
        if device.get("isAvailable", True) and device.get("name", "").startswith("iPhone"):
            candidates.append(
                {
                    "version": version,
                    "name": device["name"],
                    "udid": device["udid"],
                    "runtime": runtime_id,
                }
            )

if requested_major != "latest":
    candidates = [
        candidate
        for candidate in candidates
        if candidate["version"][0] == int(requested_major)
    ]

if not candidates:
    raise SystemExit(f"No available iPhone simulator was found for runtime {requested_major}")


def device_score(candidate):
    name = candidate["name"]
    preferred_phone = 2 if "Pro" in name and "Max" not in name else 1
    return candidate["version"], preferred_phone, name


selected = max(candidates, key=device_score)
destination.write_text(
    f"{selected['udid']}|{selected['runtime']}|{selected['name']}\n"
)
PY

IFS='|' read -r device_id runtime_id device_name < "$ARTIFACT_DIR/destination.txt"
echo "Running LivelineDemoUITests on $device_name ($runtime_id)"

# Start simulator migration before compilation and let the two expensive setup
# operations overlap. The old workflow waited for a full boot, then compiled.
if ! xcrun simctl list devices booted | grep -Fq "$device_id"; then
  xcrun simctl boot "$device_id"
fi

build_log="$ARTIFACT_DIR/$ARTIFACT_NAME-build.log"
test_log="$ARTIFACT_DIR/$ARTIFACT_NAME-test.log"
result_bundle="$ARTIFACT_DIR/$ARTIFACT_NAME.xcresult"

set +e
set -o pipefail
xcodebuild -quiet build-for-testing \
  -project "$PROJECT" \
  -scheme LivelineDemo \
  -destination "platform=iOS Simulator,id=$device_id" \
  -derivedDataPath "$DERIVED_DATA" \
  -enableCodeCoverage NO \
  -parallel-testing-enabled NO \
  COMPILER_INDEX_STORE_ENABLE=NO \
  2>&1 | tee "$build_log"
build_status=${PIPESTATUS[0]}
set -e

if [[ $build_status -ne 0 ]]; then
  exit "$build_status"
fi

xcrun simctl bootstatus "$device_id" -b

set +e
set -o pipefail
xcodebuild -quiet test-without-building \
  -project "$PROJECT" \
  -scheme LivelineDemo \
  -destination "platform=iOS Simulator,id=$device_id" \
  -derivedDataPath "$DERIVED_DATA" \
  -resultBundlePath "$result_bundle" \
  -enableCodeCoverage NO \
  -parallel-testing-enabled NO \
  -only-testing:LivelineDemoUITests \
  2>&1 | tee "$test_log"
test_status=${PIPESTATUS[0]}
set -e

if [[ $test_status -ne 0 ]]; then
  xcrun simctl io "$device_id" screenshot \
    "$ARTIFACT_DIR/$ARTIFACT_NAME-failure.png" || true
  xcrun simctl spawn "$device_id" log show \
    --last 5m \
    --style compact \
    --predicate 'process == "LivelineDemo" OR process == "LivelineDemoUITests-Runner"' \
    > "$ARTIFACT_DIR/$ARTIFACT_NAME-simulator.log" 2>&1 || true
  exit "$test_status"
fi
