# DripDrop price-range fork

Based on upstream commit `2b57a29bc13d9acb7029f12caa29d6d7ccfda80f`.

This fork removes fixed-dollar minimums from value-to-pixel mapping and candle/axis animation. Every finite positive value span is respected. Constant nonzero values use magnitude-relative padding (0.4%, or 0.04% with exaggeration); zero retains a finite fallback span. Time-axis and order-book quantity guards are unchanged.

The iOS consumer uses raw USD values and pins this fork by commit. Keep its overlay range calculation consistent with `LivelineMath.computeRange` when updating upstream.

Validation: `swift test` on macOS, including regression coverage for sub-cent and tiny prices, large prices, constant data, and degenerate ranges. No Xcode app build is required for these package tests.
