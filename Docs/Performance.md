# Performance measurement

Liveline has an opt-in release benchmark suite for comparing rendering changes
on the same machine. It covers the costs that execute most often in animated
charts:

- warm animated sparkle path generation;
- cold dither geometry construction;
- idle and active interaction snapshot construction; and
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
