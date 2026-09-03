# Continuous integration

Liveline's CI is organized around runner cost rather than maximum fan-out. The
fastest wall-clock workflow is not necessarily the workflow that consumes the
fewest runner-minutes.

## Measured baseline

The successful pull-request revision from 24 August 2026 used approximately
30.1 macOS runner-minutes in `CI` and 13.5 in `Visual Parity`. The latest 30
runs available during the audit totaled 887.1 runner-minutes for `CI` (29.6 per
run on average) and 341.8 for `Visual Parity` (11.4 per run on average).

The dominant causes were:

- nine macOS jobs on every pull-request revision, regardless of changed files;
- the complete UI suite running on both iOS 17.5 and the current runtime;
- five platform builds running as separate jobs, including macOS and iOS builds
  already covered by package tests, DocC, and the demo build;
- a separate demo build even though the UI suite built the same target;
- 23 native PR screenshots for only eight web reference scenarios;
- regeneration of a pinned upstream web reference on every visual run;
- no cancellation of superseded runs during rapid pushes; and
- successful UI runs uploading diagnostics that are only useful on failure.

The repository is currently public. GitHub reports zero billable duration for
these standard hosted-runner jobs, but the runner time still affects queueing,
feedback time, artifact storage, and any future private-repository budget.

## Execution model

`CI` always starts with one inexpensive Linux validation job. It validates the
manifest, committed visual evidence, capture arguments, and shell syntax, then
classifies the changed paths.

- Swift package tests run only for package or test changes.
- Release, API compatibility, and DocC checks run for source changes on pull
  requests and manual full runs.
- watchOS, tvOS, and visionOS build sequentially in one job. macOS is covered by
  `swift test`; iOS is covered by DocC and the demo UI build.
- The current iOS UI suite runs once for source or demo changes. Simulator boot
  overlaps compilation, and diagnostics upload only after failure.
- A push to `main` that landed through a pull request is a short post-merge
  package smoke test. A direct source push receives the full suite because it
  has no prior pull-request coverage.
- iOS 17.5 compatibility runs weekly and on demand in `Legacy Compatibility`,
  instead of once per pushed revision.

`Visual Parity` uses the eight reviewed PR smoke scenarios on both sides of the
diff. The pinned upstream web images are committed, so pull requests consume
them directly. A manual smoke or full run regenerates the upstream images when
the capture tool or upstream pin needs verification.

All workflows cancel an older in-progress run for the same pull request or
branch. Manual full runs remain available through the Actions UI.

## Updating CI dependencies

- XcodeGen is pinned and checksum-verified by `scripts/install-xcodegen.sh`.
- The visual diff's Pillow versions live in `scripts/visual-requirements.txt`.
- The legacy lane intentionally pins Xcode 15.4 and the iOS 17 runtime. Update
  that lane only when dropping or advancing compatibility coverage.
- When the upstream web implementation or pin changes, run `Visual Parity`
  manually and commit reviewed updates under `Media/web-reference`.
