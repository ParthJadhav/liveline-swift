# Development and Verification

## Demo Recording

A current simulator recording is available at [Media/liveline-demo.mp4](../Media/liveline-demo.mp4).

Regenerate it from the repository root:

```bash
scripts/record-demo.sh
```

## Verification

Run the package, demo, screenshot, and media checks from the repository root:

```bash
scripts/install-xcodegen.sh .build/tools/xcodegen
swift test
swift build -c release
xcodebuild -scheme Liveline -destination 'generic/platform=macOS' build
xcodebuild -project Examples/LivelineDemo/LivelineDemo.xcodeproj -scheme LivelineDemo -destination 'generic/platform=iOS Simulator' build
scripts/capture-storybook.sh
scripts/capture-storybook.sh --chart-only
python3 scripts/build-readme-media.py
scripts/capture-web-references.sh
VISUAL_PARITY_EXCLUSIONS=line-show-value-windows,line-rounded-windows,line-text-windows,candle-mode-controls,multi-basic,multi-light,multi-compact,multi-two-series
scripts/diff-storybook.sh --exclude-scenarios "$VISUAL_PARITY_EXCLUSIONS" --fail-changed-pct 5 --fail-rms 12
```

Use the chart-only capture plus web-reference diff when comparing the native renderer against the upstream React/canvas implementation. Native Storybook captures use deterministic snapshot timing and an iPhone 17 Pro simulator by default, README media is built from `Media/storybook-chart-only`, and diff panels are written to `Media/storybook-diff`. Set `STORYBOOK_OUT_DIR` and `WEB_REFERENCE_OUT_DIR` to capture into disposable directories without modifying checked-in media.

The normal CI workflow runs package tests, API compatibility, declared-platform builds, and the iOS demo build. Pull requests that affect rendering also run an eight-scenario visual smoke gate; the manually dispatched `Visual Parity` workflow can run either the smoke set or the full suite. XcodeGen, Node, npm dependencies, and the upstream Liveline revision are pinned by the repository.

See [Publishing](Publishing.md) for the release checklist and [Visual Parity Status](ParityStatus.md) for capture details and accepted layout differences.
