# Performance measurement

Liveline has an opt-in release benchmark suite for comparing rendering changes
on the same machine. It covers the costs that execute most often in animated
charts:

- warm animated sparkle path generation;
- cold dither geometry construction;
- idle and active interaction snapshot construction;
- advanced density, Renko, point-and-figure, and market-depth transforms;
- cold and cached warm-frame contour geometry; and
- end-to-end warm dither frame rendering through SwiftUI `ImageRenderer`.

Run it from the repository root:

```sh
scripts/benchmark-performance.sh
```

The command builds with optimization and prints one `LIVELINE_BENCHMARK` line
per scenario. Each result is the median of multiple samples. Compare
`ns_per_iteration` values on the same Mac, with other expensive applications
closed and Low Power Mode unchanged.

Normal `swift test` runs skip this suite so performance sampling does not add
noise or latency to correctness checks.

Advanced transform fixtures use 1,000 distribution samples, 5,000 price
samples, and 2,000 order-book levels. These cases guard the bounded KDE sample
count and the linear or sort-dominated financial transforms without pretending
that one Mac's absolute timings are a device-wide promise.

For an optimization change:

1. Run the benchmark on the base commit and save its output.
2. Run it again after the change on the same machine.
3. Report both medians and `(before - after) / before` for each affected case.
4. Confirm debug tests, release tests, and the iOS simulator build still pass.

Microbenchmarks explain where CPU time moved; the end-to-end frame result is the
gate for claiming an overall rendering improvement. Instruments Time Profiler
on a physical device remains the final check for app-specific workloads.

## Tooltip target result

The first benchmark-driven optimization used a 260-point line chart on an
Apple-silicon Mac. Before the change, every active pointer update formatted all
visible tooltip targets. Passing the current pointer location into the builder
allows dense line, candle-line, and multi-series charts to format only their
nearest structured target.

| Scenario | Before | After | Change |
| --- | ---: | ---: | ---: |
| Active interaction snapshot | 359,132 ns | 1,442 ns | -99.6% |

Idle snapshots remain lightweight, while continuous hover callbacks still use
the full prepared point series. End-to-end renderer timings are sampled with
more iterations because `ImageRenderer` has substantially more run-to-run
variance than the interaction microbenchmark.

## Geometry and transform pass results

A second benchmark-driven pass targeted the transform and geometry scenarios.
Numbers are per-scenario medians of three interleaved before/after suite runs
on the same Apple-silicon Mac (interleaving cancels thermal drift between
builds), in `ns_per_iteration`.

| Scenario | Before | After | Change |
| --- | ---: | ---: | ---: |
| visual.contour-9x9 | 3,173,315 | 233,410 | -92.6% |
| advanced.market-depth-2000 | 243,813 | 102,303 | -58.0% |
| advanced.density-1000 | 126,704 | 73,500 | -42.0% |
| dither.sparkle-warm-frame | 6,947 | 5,609 | -19.3% |
| renderer.dither-active-frame | 353,002 | 321,339 | -9.0% |
| renderer.dither-warm-frame | 231,045 | 213,370 | -7.7% |

What changed:

- The contour sampler stores its grid as a flat row-major array instead of a
  `Double`-pair-keyed dictionary, dense-grid construction passes precomputed
  cell indices instead of re-searching the coordinate arrays per node, and the
  marching-squares pass sweeps the cells once — visiting only the levels each
  cell's value range crosses — instead of re-walking the whole grid per level
  with five collection allocations per cell. Isoline stitching also seeds in
  segment order rather than `Set` hash order, so contour geometry is now
  deterministic across processes.
- Market depth merges its per-price accumulation into one dictionary, computes
  overflow rescale maxima only when a side actually overflowed, and derives
  both cumulative curves from the already-sorted merged levels — removing three
  redundant sorts per rebuild.
- The density profile sorts its observations once (quartiles reuse the sorted
  buffer instead of re-filtering and re-sorting three times) and each KDE
  sample sums only the observations within six bandwidths, located by binary
  search. Densities change by under 2e-8 of a kernel's mass.
- Dither sparkles store the sine and cosine of their wink phase, so an
  animation frame expands `sin(angle + phase)` with two multiplies per sparkle
  instead of a transcendental. Geometry construction pays those trig calls once
  per rebuild, which is why `dither.geometry-cold` reads a few percent higher;
  the trade repays itself within three animated frames.
- Warm frames stop repeating invariant work: the prepared-chart cache key snaps
  its edges to 1/1024 of the visible span so a live edge advancing sub-pixel
  amounts per frame no longer guarantees a miss. Cached preparation covers the
  snapped bucket's outward-rounded bounds, preventing a reused chart from
  omitting a point that becomes visible later in that bucket. Cached time bounds
  are checked against each exact caller window before reuse, so the wider bucket
  also cannot let a future outlier affect the current range early. The prepared
  chart carries its range-point min/max so the per-frame range computation is
  O(1), and the live badge's digit-template Core Text measurement is cached on
  the render state until the template or type scale changes. Pointer-identity
  caches retain their source arrays, ensuring an interior caller mutation takes
  Swift's copy-on-write path and invalidates the cached identity.

Building sparkle and cutout paths through `CGMutablePath.addRects` was tried
and rejected: constructing the path was faster, but filling a CGPath-backed
`Path` in `GraphicsContext` cost far more per frame than native `addRect`
construction saves. Keep rect paths native.

## Multi-chart Storybook workload

The Storybook gallery is also sampled as a whole-process workload in the iOS
Simulator. The gallery now flattens group headers and cards into direct
`LazyVStack` children, allowing off-screen charts to leave the view hierarchy.
Animated dither defaults to 30 FPS, and Storybook uses 20 FPS because several
charts animate simultaneously. Standard-style realtime line and candle data
retains its 60 FPS rendering policy.

For the same five-card viewport, sampled with `top` after warm-up:

| Dither schedule | Simulator process CPU |
| --- | ---: |
| 60 FPS | 37–40% |
| 30 FPS | 28–35% |
| Storybook 20 FPS | 21–29% |

The 20 FPS gallery setting averages roughly one-third less CPU than 60 FPS.
On iOS 18 and later, Storybook also suspends Dither animation while the scroll
view is tracking or decelerating, retaining the current static texture until
scrolling returns to idle.
