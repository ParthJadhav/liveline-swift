# Release Checklist

## Repository Visibility

This checklist prepares tags, release notes, and package verification without changing GitHub repository visibility.

- Do not change the repository from private to public as part of release work.
- A GitHub release can be created while the repository remains private.
- Public SwiftPM access requires public repository visibility or explicit read access; keep that decision outside this checklist.

Confirm the current remote without mutating settings:

```bash
gh repo view ParthJadhav/liveline-swift --json visibility,latestRelease,url
```

Before creating a tag or GitHub release, require the local commit to be the
remote `main` tip and require that exact commit's `CI` workflow to have
completed successfully:

```bash
scripts/verify-release-ready.sh
```

The check ignores untracked files, but blocks a detached or non-`main` branch,
tracked changes, a local commit that is not the remote `main` tip, missing or
in-progress CI, and every non-successful CI conclusion. It is read-only: it
queries GitHub without rerunning workflows or changing repository state.

Confirm local build evidence:

```bash
swift test
swift build -c release
BASELINE_TAG=$(git describe --tags --abbrev=0 --match '[0-9]*')
swift package diagnose-api-breaking-changes "$BASELINE_TAG" --products Liveline
xcodebuild docbuild -scheme Liveline -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO OTHER_DOCC_FLAGS='--warnings-as-errors'
scripts/install-xcodegen.sh .build/tools/xcodegen
.build/tools/xcodegen/bin/xcodegen generate --spec Examples/LivelineDemo/project.yml
xcodebuild -scheme Liveline -destination 'generic/platform=macOS' build
xcodebuild -project Examples/LivelineDemo/LivelineDemo.xcodeproj -scheme LivelineDemo -destination 'generic/platform=iOS Simulator' build
scripts/capture-storybook.sh --chart-only
VISUAL_PARITY_EXCLUSIONS=line-show-value-windows,line-rounded-windows,line-text-windows,candle-mode-controls,multi-basic,multi-light,multi-compact,multi-two-series
scripts/diff-storybook.sh --exclude-scenarios "$VISUAL_PARITY_EXCLUSIONS" --fail-changed-pct 5 --fail-rms 12 --scenario-threshold line-orderbook:5.1:13
(cd remotion/tools/shotgen && SHOTGEN_MODE=frames SHOTGEN_CLIPS_ONLY=line-live,dynamic-type swift run ShotGen)
(cd remotion && bun install --frozen-lockfile && bunx tsc --noEmit && bun audit && bun run render:070)
ffprobe -v error -show_entries format=duration,size -show_entries stream=codec_name,width,height,r_frame_rate -of json Media/liveline-0-7-0-demo.mp4
```

The excluded upstream scenarios place controls inside the plot's layout. Liveline Swift deliberately gives controls their own space so chart geometry and placeholders remain centered in the remaining canvas; the strict parity thresholds still cover every upstream scenario without that structural difference.

When the optional platform SDK components are installed, also verify the declared package platforms:

```bash
xcodebuild -scheme Liveline -destination 'generic/platform=tvOS' build
xcodebuild -scheme Liveline -destination 'generic/platform=watchOS' build
xcodebuild -scheme Liveline -destination 'generic/platform=visionOS' build
```

## Tagging A Release

SwiftPM can consume a branch, but app teams usually prefer version tags.

Run `scripts/verify-release-ready.sh` immediately before tagging. Do not tag or
publish from a commit that fails the check.

```bash
VERSION=0.7.0
git tag "$VERSION"
git push origin "$VERSION"
```

Confirm that the tag commit is the intended release commit:

```bash
git show --stat --oneline "$VERSION"
```

Then depend on:

```swift
.package(url: "https://github.com/ParthJadhav/liveline-swift.git", from: "0.7.0")
```

## GitHub Release

A pushed tag is not the same thing as a GitHub release. Check existing releases before publishing:

```bash
gh release list --repo ParthJadhav/liveline-swift --limit 20
```

Create the release only after the tag points at the intended commit:

```bash
gh release create "$VERSION" --repo ParthJadhav/liveline-swift --title "$VERSION" --generate-notes
```

## Access

For private package installs, grant repository read access to each developer, CI bot, or deploy key that needs to resolve the package.

For public package installs, keep the repository public and confirm Swift Package Index can build the configured `Liveline` documentation target from `.spi.yml`.
