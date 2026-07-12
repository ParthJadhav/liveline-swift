#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "LIVELINE_BENCHMARK_CONTEXT commit=$(git rev-parse --short HEAD) os=$(sw_vers -productVersion) arch=$(uname -m)"

LIVELINE_RUN_BENCHMARKS=1 \
    swift test -c release --filter LivelinePerformanceTests/testReleasePerformanceBenchmarks
