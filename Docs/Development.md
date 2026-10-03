# Development and Verification

Use [AGENTS.md](../AGENTS.md) for task routes and [Architecture](Architecture.md)
for the source flow. Run the commands below from the repository root unless the
working-directory column says otherwise. Workflow YAML is authoritative for CI;
[CI](CI.md) explains changed-path selection, full checks, and post-merge checks.

## Tool Setup

Swift builds and native captures require macOS and Xcode's selected command-line
tools. Demo builds and UI checks require the generated Xcode project:

```bash
scripts/install-xcodegen.sh .build/tools/xcodegen
.build/tools/xcodegen/bin/xcodegen generate --spec Examples/LivelineDemo/project.yml
export PATH="$PWD/.build/tools/xcodegen/bin:$PATH"
```

The export makes the pinned tool available to capture scripts that invoke
`xcodegen` by name. Native captures default to an iPhone 17 Pro simulator; the
UI-test runner selects an available iPhone runtime. Python 3 is required for
metadata and visual checks. Web-reference regeneration uses the pinned Node/npm
toolchain in `scripts/web-reference`; see the Visual Parity workflow for its version.

## Verification Matrix

| Change / purpose | Command or guide | Prerequisites | Working directory / output |
| --- | --- | --- | --- |
| Docs / scenario metadata | `python3 scripts/storybook_manifest.py validate` | Python 3 | Root; read-only, including marked current catalog counts |
| Validator logic | `python3 scripts/test_storybook_manifest.py` | Python 3 | Root; temporary fixtures |
| Package correctness | `swift test` | Xcode / Swift | Root; `.build`; host-platform proof only |
| Release build / concurrency | `swift build -c release`; `swift build -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors` | Xcode / Swift | Root; `.build` |
| Public API / DocC | API comparison and DocC commands in [Publishing](Publishing.md) | Baseline tag, Xcode | Root; build artifacts |
| Demo build | XcodeGen setup above, then `xcodebuild -project Examples/LivelineDemo/LivelineDemo.xcodeproj -scheme LivelineDemo -destination 'generic/platform=iOS Simulator' build` | Xcode, simulator SDK | Root; Xcode build artifacts |
| Committed visual contract | `scripts/verify-chart-visuals.sh` | Python 3 | Root; validates existing baselines, no capture |
| Candidate full visual capture | `scripts/verify-chart-visuals.sh --capture` | XcodeGen on PATH, simulator | Root; `.build/chart-visual-quality` by default |
| Focused renderer change | Focused capture below, then manual review | XcodeGen on PATH, simulator | Root; selected `.build` directory |
| Advanced chart gate | `scripts/verify-advanced-charts.sh` | Xcode / Swift, Python 3 | Root; screenshot contract, tests, release and strict-concurrency builds; no capture by default |
| Performance | `scripts/benchmark-performance.sh` | Xcode / Swift | Root; opt-in release measurements in stdout; [Performance](Performance.md) |
| iOS UI / gestures | `scripts/run-demo-ui-tests.sh latest .build/ui-checks navigation` | Generated demo, available iPhone simulator | Root; logs, destination, `.xcresult` in `.build/ui-checks` |
| Accepted upstream parity | `scripts/verify-visual-parity.sh` | Existing native/web captures, Python venv/pip | Root; `.build/storybook-diff`; thresholds/exclusions owned by wrapper |
| Deployment floors / platforms | Commands below and [Publishing](Publishing.md) | Corresponding Xcode SDKs | Root; type-checks and build artifacts |
| Full release acceptance | [Publishing](Publishing.md), `scripts/verify-release-ready.sh` | Remote main tip, successful exact-commit CI, full release evidence | Root; readiness check is read-only |

Catalog totals are <!-- catalog:scenarios -->92<!-- /catalog --> scenarios,
<!-- catalog:families -->47<!-- /catalog --> chart kinds, and
<!-- catalog:advanced -->21<!-- /catalog --> advanced families. Streamgraph is an
additional stacked-area style variant in the presentation catalog. The manifest tool
validates designated `catalog:` markers against the manifest and Swift enums;
it does not validate historical counts or completeness of API prose.

For a focused capture, select explicit scenarios and a disposable output:

```bash
STORYBOOK_SCENARIOS="line-basic-dark line-basic-light" \
  STORYBOOK_OUT_DIR=.build/focused-charts scripts/capture-storybook.sh --chart-only
python3 scripts/chart_visual_quality.py --directory .build/focused-charts \
  --scenarios line-basic-dark line-basic-light
```

Inspect each changed PNG at 100% and 200% before accepting it. Use
[Chart Quality](ChartQuality.md) for the rubric and [Chart Visual Audit](ChartVisualAudit.md)
for the recorded catalog. The advanced gate already includes package tests,
release build, and strict concurrency; do not duplicate those in the same run.
Full release, platform, and visual requirements remain in Publishing.

`WEB_REFERENCE_SCENARIOS` selects a space-separated parity subset, and
`WEB_REFERENCE_OUT_DIR`, `STORYBOOK_OUT_DIR`, and `VISUAL_DIFF_OUT_DIR` select
input/output directories. Full parity checks use the committed captures by
default. See [Parity Status](ParityStatus.md) for accepted differences and the
dated comparison record.

## Deployment Floor

`swift test` and `swift build` compile for host macOS and do not prove the
declared minimum OS versions. Type-check against each available SDK using a
shim for SwiftPM's generated `Bundle.module`:

```bash
shim=/tmp/liveline-bundle-shim.swift
printf 'import Foundation\nextension Bundle { static let module = Bundle.main }\n' > "$shim"
floor() { xcrun --sdk "$2" swiftc -typecheck -target "$1" Sources/Liveline/*.swift "$shim"; }
floor arm64-apple-ios15.0     iphoneos
floor arm64-apple-macosx12.0  macosx
floor arm64-apple-watchos8.0  watchos
floor arm64-apple-tvos16.0    appletvos
floor arm64-apple-xros1.0     xros
```

Gate newer APIs with `@available` or `if #available`; see [API](API.md) for
feature-specific floors. Record unavailable SDKs explicitly; host tests do not
replace those platform checks.

## Media Outputs and Producers

These commands refresh tracked evidence or presentation assets unless an output
override is supplied. Select them when intentionally updating those artifacts.

| Output | Producer | Purpose / replacement behavior |
| --- | --- | --- |
| `Media/storybook` | `scripts/capture-storybook.sh` | Full demo screenshots; replaces committed evidence by default |
| `Media/storybook-chart-only` | `scripts/capture-storybook.sh --chart-only` | Native parity / chart baselines; replaces committed evidence by default |
| `Media/web-reference` | `scripts/capture-web-references.sh` | Pinned upstream references; replaces committed evidence by default |
| `Media/storybook-dither` | `scripts/capture-dither-chart-media.sh` | Public light-mode Dither gallery |
| `Media/storybook-new-charts`, `Media/advanced-chart-review` | Same Dither workflow | Advanced documentation images and review boards; advanced gate's `--capture` refreshes screenshots |
| `Media/readme` | `python3 scripts/build-readme-media.py` | Public tiles; defaults to chart-only inputs, Dither workflow overrides the source |
| `.build/chart-review-board` | `scripts/build-chart-review-board.sh` | Disposable review boards; `--directory` / `--out-dir` choose inputs / output |
| `Media/liveline-demo.mp4` | `scripts/record-demo.sh` | Simulator recording |
| `Media/liveline-launch.mp4`, poster and GIF | `scripts/record-dither-showcase.sh` | Animated public showcase |
| Release and advanced PR videos | Commands in [remotion/README.md](../remotion/README.md), run from `remotion/` | Native footage, generated sequences, and SVG scenes have separate provenance; advanced cut contract in [ADVANCED_PR_DEMO.md](../remotion/ADVANCED_PR_DEMO.md) |

Capture scripts support `STORYBOOK_OUT_DIR` and `WEB_REFERENCE_OUT_DIR` for
disposable destinations. Native snapshots use deterministic timing. Keep changes
to public presentation media separate from acceptance of standard parity baselines.
