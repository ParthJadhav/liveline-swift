# Code Quality Remediation Plan

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

## Target Design

### Prepared chart module

`LivelinePreparedChart` is the internal seam used by the view, compositor, and tests. Its interface exposes only normalized content, current value and momentum, time/range inputs, capabilities, and chart identity. Preparation hides chart-family data conversion and validation.

```text
Public initializers
       |
       v
LivelineChartContent
       |
       v
LivelineChartPreparer.prepare(...)
       |
       v
LivelinePreparedChart
       |
       +----> Cartesian compositor (grid / time axis / hover / active point)
       |
       +----> Family mark renderer
```

The module is entirely in-process. Tests cross the same preparation interface as production; no adapter or mock seam is needed.

### Motion module

`LivelineMotionPolicy` resolves system Reduce Motion, caller pause, deterministic snapshot time, and whether the chart has active continuous effects. It produces the single effective frame delta and schedule decision consumed by every renderer subsystem.

- Paused means a zero animation delta everywhere.
- Reduce Motion completes reveals immediately, disables spatial/continuous effects, and retains static color/opacity feedback.
- Static charts use a plain Canvas.
- Animated charts use a timeline only while an animation or explicitly continuous effect is active.

### Interaction ownership

The chart remains source-compatible, but internal selection state is reconciled from a stable chart identity:

- configuration changes update window and mode state when the caller changes their requested values;
- hidden series IDs are intersected with current IDs;
- at least one series remains visible;
- hover is computed as immutable render output and delivered by the view after drawing.

### Configuration

The canonical initializer accepts typed groups for appearance, effects, viewport, interaction, motion, annotations, formatting, and callbacks. Existing flat properties and initializers forward to those groups for source compatibility. Screenshot timing moves to an internal environment value used by the demo rather than remaining part of ordinary renderer logic.

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

- [x] Unit and behavior tests: 53 tests pass, including all 21 chart kinds and extreme finite-value rendering.
- [x] Renderer/state coverage materially increased from the 0.22% audit baseline: package line coverage is 83.50%, `LivelineRenderer.swift` is 74.13%, and `LivelineRenderState.swift` is 89.24%.
- [x] Debug and release package builds.
- [x] Complete strict-concurrency diagnostics with warnings treated as errors.
- [x] API compatibility against `0.2.0`: no breaking changes detected.
- [x] iOS and macOS package builds.
- [x] tvOS, watchOS, and visionOS build commands verified as unavailable locally because those three SDK components are not installed; CI retains all three declared-platform jobs.
- [x] iOS demo generated with pinned XcodeGen and built successfully.
- [x] Full visual parity threshold gate: 64 native captures, 27 pinned upstream references, 19 strict comparisons passing, and eight documented layout exclusions.
- [x] No production, demo, or test Swift source file above 1,000 lines; the largest is 736 lines.
- [x] Manifest, shell syntax, generated metadata, npm audit, whitespace, and tracked-worktree scope checks.

User-owned untracked launch-media files were preserved and excluded from the remediation changes.
