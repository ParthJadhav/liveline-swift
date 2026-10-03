# Code Quality Remediation Plan (historical)

This records the remediation at `62918564` (2026-07-12), amended for the 0.7.0
release at `2b57a29b` (2026-08-09). Verification numbers and local SDK availability
below belong to those revisions; they are not current release acceptance.
Use [Architecture](Architecture.md) for the current source map and
[Development](Development.md) for current checks.

## Objective

Restructure Liveline so new chart families can be added without enlarging a god renderer, scattering mode checks, weakening input invariants, or expanding always-on animation work. Preserve the current public behavior and source compatibility while making the canonical implementation smaller, testable, and platform-correct.

## Completion Criteria

- No production or demo Swift source file exceeds 1,000 lines.
- Chart-family semantics are prepared once behind a small internal interface instead of being recomputed by repeated `LivelineChartContent` switches.
- Shared Cartesian composition owns axes, hover, crosshairs, and active-point overlays once.
- Time-series input is normalized to finite, ascending, uniquely timed samples before binary search or rendering.
- Invalid public scalar inputs cannot create reversed ranges, negative loops, or non-finite layout state.
- View-owned controls reconcile when configuration or chart content changes.
- The Canvas drawing path is side-effect free; callbacks are delivered outside rendering and only when values change.
- One motion policy controls live animation, pause, deterministic snapshots, and Reduce Motion. Static charts do not redraw continuously.
- Per-frame work does not recreate date formatters or allocate platform bitmaps for orderbook text.
- Public configuration has a typed canonical interface. Compatibility properties and initializers only adapt to it and are deprecated where appropriate.
- The visual scenario catalog is split by responsibility and its scenario IDs have one machine-readable source of truth.
- Visual-reference dependencies and the upstream revision are pinned.
- Renderer, state, invalid-input, interaction, and platform-color behavior is covered by automated tests; a stable visual regression subset runs on pull requests.

## Architecture

The enduring implementation map is maintained in [Architecture](Architecture.md).

## Work Sequence

1. Add characterization tests for preparation, invalid inputs, pause/reduced motion, reconciliation, and callbacks.
2. Introduce normalized time-series and prepared-chart modules; move repeated semantic switches there.
3. Extract shared drawing primitives and split renderers by concern, keeping every file below 1,000 lines.
4. Collapse repeated axes/crosshair/active-point tails into the Cartesian compositor.
5. Introduce the motion policy and demand-driven Canvas scheduling; cache formatters and draw orderbook text without per-frame platform bitmaps.
6. Reconcile view state and move hover callback delivery out of Canvas drawing.
7. Add typed configuration groups and compatibility adapters; remove dead state and no-op behavior.
8. Split Storybook scenarios and fixtures, generate scenario lists from one manifest, and pin visual dependencies.
9. Add platform-color tests and replace the watchOS hard-coded accent fallback.
10. Run package tests with coverage, release and strict-concurrency builds, API compatibility checks, available platform builds, demo build, and visual parity.

## Compatibility Strategy

- Keep every existing `LivelineChart` initializer.
- Keep existing configuration call sites compiling while moving canonical storage to typed groups.
- Deprecate only redundant or test-only flat configuration members; do not silently change rendering defaults.
- Preserve snapshot images unless a deliberate correctness fix requires updating the baseline and is documented.

## Verification Record

The original July record reported 53 tests, 64 native captures, and a largest
Swift file of 736 lines. The August amendment updated test, capture, UI, and
file-size results below; unchanged coverage and SDK observations were carried
forward from July and were not separately dated in the original record.

- [x] Unit and behavior tests: 252 tests pass, including every chart kind and extreme finite-value rendering.
- [x] Renderer/state coverage materially increased from the 0.22% audit baseline: package line coverage is 83.50%, `LivelineRenderer.swift` is 74.13%, and `LivelineRenderState.swift` is 89.24%.
- [x] Debug and release package builds.
- [x] Complete strict-concurrency diagnostics with warnings treated as errors.
- [x] API compatibility against `0.2.0`: no breaking changes detected.
- [x] iOS and macOS package builds.
- [x] tvOS, watchOS, and visionOS build commands verified as unavailable locally because those three SDK components are not installed; CI retains all three declared-platform jobs.
- [x] iOS demo generated with pinned XcodeGen and built successfully.
- [x] All 12 iOS demo UI regressions pass serially, including stacked-chart gestures, accessibility sizing, both appearances, and Storybook search/navigation.
- [x] Full visual parity threshold gate: 71 native captures, 27 pinned upstream references, 19 strict comparisons passing, and eight documented layout exclusions.
- [x] No production or demo Swift source file above 1,000 lines; after the 0.7.0 runtime and renderer split, the largest is 994 lines.
- [x] Manifest, shell syntax, generated metadata, npm audit, whitespace, and tracked-worktree scope checks.

User-owned untracked launch-media files were preserved and excluded from the remediation changes.
