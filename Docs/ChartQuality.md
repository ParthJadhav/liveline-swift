# Chart visual quality standard

Every chart family must pass the same semantic, pixel, accessibility, and
maintenance bar. A chart is not complete because it renders without crashing;
it is complete when its geometry is truthful, balanced, legible, and stable in
every supported rendering path.

## The five visual gates

### 1. Spacing and alignment

- Repeated gaps must be equal to within 0.5 device pixel at the reference size.
- Spacing belongs between siblings. It must not create an unrequested half-gap
  or full gap against the plot boundary.
- The final sibling absorbs floating-point remainder so cumulative rounding
  cannot leave a seam or move the outer edge.
- Marks, labels, hit targets, and reveal masks use one shared geometry source.
- Axes and direct labels receive separate gutters; neither may borrow space
  already reserved for the other.

### 2. Path continuity

- Continuous data uses a bounded curve that is visually traceable and does not
  overshoot its local values. Line caps and joins are round.
- Closed densities and scalar-field boundaries are stitched before smoothing;
  disconnected per-cell fragments are not acceptable output.
- Discrete encodings remain discrete. Steps, ranks, candles, Renko bricks,
  point-and-figure columns, market depth, and categorical polygons must not be
  smoothed merely to look softer.
- A curve may never imply extrema, time, rank, or continuity absent from the
  source data.

### 3. Edges, fills, and clipping

- Marks clip to the plot, not to an incidental intermediate rectangle.
- No stroke may expose a square cap, miter spike, torn boundary, or accidental
  flat edge unless that edge is part of the chart's encoding.
- Adjacent fills are composited without hairline cracks, alpha checkerboards,
  or overlap-darkened seams.
- The first and last marks remain fully visible unless overflow is an explicit
  design choice.

### 4. Labels and hierarchy

- Direct labels have at least 13 points of vertical separation at the standard
  text scale when the plot can physically provide it.
- Collision resolution moves labels, never data marks. A leader line preserves
  the connection when displacement is visible.
- Labels stay inside their reserved region, preserve reading order, and remain
  subordinate to the data in light and dark themes.
- Dynamic Type may reduce plot area but may not clip or overlap text.
- Grid, axes, and annotation guides remain quieter than primary marks.

### 5. Rendering and interaction parity

- Standard and Dither styles render the same geometry and semantics.
- Reveal animation clips settled geometry; it must not continuously reshape
  proportional marks.
- Drag, hover, tooltip, VoiceOver, and Audio Graph targets describe the exact
  visible mark.
- RTL mirrors placement and gutter ownership without reversing data meaning.

## Evaluation loop

Use the same loop for a one-pixel correction and a new chart family:

1. Classify the encoding as continuous, discrete, proportional, radial,
   hierarchical, matrix, or financial. Write down what may and may not move.
2. Add geometry invariants for bounds, gaps, ratios, continuity, collision
   spacing, clipping, and interaction parity as applicable.
3. Capture deterministic Storybook screenshots after the default 2.2-second
   settled time. Shorter captures are animation diagnostics, not baselines.
4. Inspect the raw 1206×2622 PNG at 100% and 200%. Check every outer edge,
   crossing, join, label cluster, low-contrast region, and first/last mark.
5. Compare representative light, dark, compact, Dynamic Type, RTL, standard,
   and Dither cases. Do not infer these from one theme.
6. Correct the shared renderer or geometry. Never patch the screenshot or tune
   only the Storybook fixture.
7. Repeat the focused capture, then inspect the complete 92-scenario catalog
   for collateral regressions.
8. Run package, release, strict-concurrency, demo, and performance gates.

## Automated evidence

Validate the checked-in baseline set:

```bash
scripts/verify-chart-visuals.sh
```

Capture all scenarios into a disposable review directory and validate them:

```bash
scripts/verify-chart-visuals.sh --capture
```

The gate requires exactly one screenshot for every manifest scenario, validates
the PNG structure and CRCs, rejects suspiciously empty captures, and enforces a
shared 1206×2622 reference size. It intentionally does not pronounce a valid
PNG beautiful; full-size human inspection remains an acceptance requirement.

Build labeled contact sheets for the catalog sweep:

```bash
scripts/build-chart-review-board.sh
```

For a focused loop, capture only the affected IDs without touching baselines:

```bash
STORYBOOK_SCENARIOS="horizon-basic marimekko-basic contour-basic" \
STORYBOOK_OUT_DIR=.build/chart-review \
scripts/capture-storybook.sh --chart-only
```

The 21 advanced chart families also have an end-to-end release gate:

```bash
scripts/verify-advanced-charts.sh --capture
```

## Non-visual requirements

- Unsafe, empty, non-finite, negative-without-meaning, reversed, and degenerate
  input resolves safely.
- Every family builds a meaningful tooltip target, localized VoiceOver model,
  and non-empty Audio Graph representation.
- Dense algorithms are bounded and expensive settled geometry is cached.
- Renderer smoke tests cover standard and Dither styles.
- The package builds with complete strict concurrency and warnings as errors.

## Definition of done

A chart can pass only when geometry tests, the screenshot contract, the
full-catalog inspection, adaptive-state checks, interaction/accessibility
checks, release builds, and performance review all agree. See
[Chart Visual Audit](ChartVisualAudit.md) for the current catalog-level record.
