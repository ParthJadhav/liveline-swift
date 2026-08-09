# Liveline 0.7.0

Liveline 0.7.0 makes the package easier to read, explore, teach, and maintain
without changing its public API.

## A more accessible chart surface

- Canvas labels scale up to 1.8× at accessibility Dynamic Type sizes.
- Grid, reference, and time-axis labels have stronger light- and dark-mode
  contrast.
- Spanish chart names, control states, VoiceOver summaries, tooltips, and Audio
  Graph terminology are bundled with the package.
- Existing VoiceOver-adjustable inspection and Audio Graph support continue to
  cover every chart family.

## A useful native workbench

- The Live demo follows the system theme and becomes a two-column dashboard on
  iPad while remaining focused on iPhone.
- Storybook's 71 scenarios are searchable and filterable by chart family.
- Gallery previews are static, accessible navigation cards rather than nested
  interactive controls.
- Every scenario now explains its gestures and includes a selectable SwiftUI
  recipe with copy and share actions.
- The demo gains a custom Liveline app icon and a calmer all-chart showcase.
- The README gallery now shows every one of the 27 chart families.

## Easier to evolve

- The former monolithic chart view is split into definition and view-runtime
  files.
- Extended renderers are split into Cartesian, statistical, and hierarchy
  responsibilities.
- The AppKit scroll-wheel monitor is main-actor isolated and passes complete
  Swift concurrency checking under Xcode 26.
- Every production and demo Swift file remains below 1,000 lines.
- Package behavior and source compatibility are covered by the expanded unit,
  UI, release-build, DocC, platform-build, and API-diff gates.

The attached `liveline-0-7-0-demo.mp4` is a 26-second, 1080p Remotion film made
from authentic native chart frames and final iPhone/iPad screenshots.
